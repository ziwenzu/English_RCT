<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class BreitbartSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'breitbart-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'breitbart';
    protected $prefix  = 'BN';

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
                'page'       => 0,
            ];
        }
        Config::insert($data);
    }

    protected function spiderList()
    {
        $configs = Config::where('website', $this->website)->where('had_spider', Config::NO)->get();

        $baseUrl = 'https://www.breitbart.com';
        $client  = new Client();

        foreach ($configs as $config) {
            $page = $config->page;

            while (true) {
                $url = sprintf('%s/tag/%s/page/%d', $baseUrl, $config->keyword, $page);
                $res = $client->request('GET', $url, [
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                        'User-Agent'      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36',
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => $baseUrl,
                    ],
                    // 'proxy'   => 'socks5h://127.0.0.1:1080', // 本地搭建sock5用于绕过gwf
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {
                    $response = $res->getBody()->getContents();
                    $ql       = QueryList::html($response);
                    $lists    = $ql->find('#MainW .aList article')->htmls();
                    $isNext   = $ql->find('#MainW .pagination a:first')->attr('rel');

                    foreach ($lists as $list) {
                        $listQl = QueryList::html($list);

                        $dateline = $listQl->find('.header_byline time')->attr('datetime');
                        $date     = new \DateTime($dateline);

                        if ($date->format('Y-m-d') > $config->end_date) {
                            continue;
                        }

                        if ($date->format('Y-m-d') < $config->begin_date) {
                            $isNext = 'prev';
                            continue;
                        }

                        $info['headline']        = $listQl->find('.tC>h2')->text();
                        $info['url']             = $baseUrl . $listQl->find('.tC a')->attr('href');
                        $info['unique_id']       = md5($info['url']);
                        $info['author']          = $listQl->find('.header_byline address a')->text();
                        $info['date']            = $date->format('Y-m-d H:i:s');
                        $info['printed_edition'] = 'no';
                        $info['website']         = $this->website;
                        $info['keyword']         = $config->keyword;
                        $info['json_data']       = base64_encode(gzdeflate($list));
                        $data[]                  = $info;
                    }

                    SpiderData::insert($data);

                    if ($isNext == 'prev') {
                        $config->had_spider = Config::YES;
                        $config->save();
                        break;
                    }

                    $config->page = $page++;
                    $config->save();
                    $this->info($page);
                }
            }
        }
    }

    protected function dealCrawlerList($lists)
    {
        foreach ($lists as $list) {
            if (!empty($list['html'])) {
                $ql = QueryList::html($list['html']);

                $title  = $ql->find('#MainW header>h1')->text();
                $images = $ql->find('#MainW img')->attrs('src');
                $backup = $ql->find('#MainW .entry-content')->html();

                $textQl = $ql->find('#MainW .entry-content');
                $textQl->find('.wp-caption')->remove();
                $texts   = $textQl->find('p')->texts();
                $section = explode('/', substr($list['url'], 26))[0];

                $content = '';
                $content .= $title ? $title . "\r\n\r\n" : '';
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= $images->isEmpty() ? '' : "\r\nhead_images: " . $images->implode("\r\n");

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);
                // 仅作备份用途，用于生成内容不成功的时候不需要重复爬取，可以注释掉
                // Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($backup)));

                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);

                    SpiderData::where('id', $list['id'])->update([
                        'has_spider' => SpiderData::YES,
                        'section'    => $section,
                    ]);
                }
            }
        }
    }
}
