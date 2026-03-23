<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class TelegraphSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'telegraph-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'telegraph';
    protected $prefix  = 'DT';

    /**
     * Create a new command instance.
     *
     * @return void
     */
    public function __construct()
    {
        parent::__construct();
    }

    /**
     * Execute the console command.
     *
     * @return mixed
     */
    public function handle()
    {
        $step = $this->option('step');

        switch ($step) {
            case '1':
            case 'config':
                $this->generateConfig();
                break;
            case '2':
            case 'list':
                $this->spiderList();
                break;
            case '3':
            case 'repeat':
                $this->dealRepeat(); // 不同关键词会获取相同的新闻，用于去重
                break;
            case '4':
            case 'html':
                $this->spiderHtml($this->website, 3);
                break;
            case '5':
            case 'order':
                $this->orderData('App\SpiderData', 'date', ['website' => $this->website], $this->website, $this->prefix);
                break;
            default:
                break;
        }
    }

    protected function generateConfig()
    {
        $keywords = [
            'China',
            'Taiwan',
            'Hong Kong',
            'Russia',
            'Russian',
            'Iran',
            'Iranian',
        ];

        $data = [];

        foreach ($keywords as $keyword) {
            $data[] = [
                'website'    => $this->website,
                'keyword'    => $keyword,
                'begin_date' => '2016-01-01',
                'end_date'   => '2020-05-01',
                'page'       => 1,
            ];
        }
        Config::insert($data);
    }

    protected function spiderList()
    {
        $configs = Config::where('website', $this->website)->where('had_spider', Config::NO)->get();

        $baseUrl = 'https://www.telegraph.co.uk';
        $client  = new Client();

        foreach ($configs as $config) {
            $page = $config->page;

            while (true) {
                $url = sprintf('%s/%s/page-%d', $baseUrl, $config->keyword, $page);
                $res = $client->request('GET', $url, [
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                        'User-Agent'      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36',
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => $baseUrl,
                    ],
                    // 'proxy'   => 'socks5h://127.0.0.1:1080',
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = $res->getBody()->getContents();

                    $ql = QueryList::html($response);

                    $isNext = $ql->find('.pagination__list .pagination__link--next')->attr('href');

                    $lists = $ql->find('.article-list .article-list__list li')->htmls();

                    foreach ($lists as $list) {
                        $listQl   = QueryList::html($list);
                        $dateline = $listQl->find('.card__meta-wrapper .card__date')->attr('datetime');

                        $date = new \DateTime($dateline);

                        if ($date->format('Y-m-d') > $config->end_date) {
                            continue;
                        }

                        if ($date->format('Y-m-d') < $config->begin_date) {
                            $isNext = '';
                            continue;
                        }

                        $info['headline']        = $listQl->find('.card__content>h3')->text();
                        $info['author']          = $listQl->find('.e-byline__author')->text();
                        $info['url']             = $baseUrl . $listQl->find('.card__content>h3 a')->attr('href');
                        $info['unique_id']       = md5($info['url']);
                        $info['date']            = $date->format('Y-m-d H:i:s');
                        $info['printed_edition'] = 'no';
                        $info['json_data']       = base64_encode(gzdeflate($list));
                        $info['keyword']         = $config->keyword;
                        $info['website']         = $this->website;

                        $data[] = $info;
                    }

                    SpiderData::insert($data);

                    if (empty($isNext)) {
                        $config->had_spider = Config::YES;
                        $config->save();
                        break;
                    }

                    $config->page = $page++;
                    $config->save();
                    $this->info($page);
                    // sleep(3);
                }
            }
        }
    }

    protected function dealCrawlerList($lists)
    {
        foreach ($lists as $list) {
            if (!empty($list['html'])) {
                $ql = QueryList::html($list['html']);

                if (!empty($ql->find('.premium-paywall')->html())) {
                    continue;
                }

                $rule1 = [
                    'backup' => ['.js-article-inner', 'html'],
                    'title'  => ['.article__body .headline h1', 'text'],
                    'texts'  => ['.article__content article p', 'texts'],
                    'images' => ['.article__content .section figure img', 'attrs(src)'],
                ];

                $rule2 = [
                    'backup' => ['.article .grid', 'html'],
                    'title'  => ['.article .grid h1', 'text'],
                    'texts'  => ['.grid .article-body-text p', 'texts'],
                    'images' => ['.article-body-image img', 'attrs(src)'],
                ];

                $data = $ql->rules($rule1)->queryData();

                if (empty($data['title'])) {
                    $data = $ql->rules($rule2)->queryData();
                }

                $content = '';
                $content .= $data['title'] ? $data['title'] . "\r\n\r\n" : '';
                $contents = implode("\r\n", $data['texts']);
                $content .= $contents ?? '';
                $content .= empty($data['images']) ? '' : "\r\nimages: " . implode("\r\n", $data['images']);

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);

                Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($data['backup'])));

                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);
                    $section = explode('/', substr($list['url'], 28))[0];
                    SpiderData::where('id', $list['id'])->update([
                        'has_spider' => SpiderData::YES,
                        'section'    => $section,
                    ]);
                }
            }
        }
    }
}
