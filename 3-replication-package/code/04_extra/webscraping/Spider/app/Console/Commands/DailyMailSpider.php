<?php

namespace App\Console\Commands;

use DateTime;
use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class DailyMailSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'daily-mail-spider {--step= : 运行步骤}';

    protected $website = 'daily-mail';
    protected $prefix  = 'DM';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

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
        $host    = 'https://www.dailymail.co.uk';
        $baseUrl = 'https://www.dailymail.co.uk/home/search.html';
        $client  = new Client([
            'handler' => $this->stack(),
        ]);
        $size = 50;

        foreach ($configs as $config) {
            $page = $config->page;

            while (true) {
                $offset = $size * $page++;
                $res    = $client->request('GET', $baseUrl, [
                    'query'   => [
                        'offset'       => $offset,
                        'size'         => $size,
                        'sel'          => 'site',
                        'searchPhrase' => $config->keyword,
                        'sort'         => 'recent',
                        'type'         => 'article',
                        'days'         => 'all',
                    ],
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                        'User-Agent'      => $this->getUserAgent(),
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => $baseUrl,
                    ],
                    // 'proxy'   => 'socks5h://127.0.0.1:1080',
                    // 'debug'   => true,
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = $res->getBody()->getContents();

                    $ql = QueryList::html($response);

                    $lists  = $ql->find('.sch-results .sch-result')->htmls();
                    $isNext = $ql->find('.sch-results .paginationNext')->html();

                    foreach ($lists as $list) {
                        $listQl = QueryList::html($list);

                        $dateline = $listQl->find('.sch-res-content .sch-res-info')->text();
                        $dateArr  = explode('-', str_replace(["\r\n"], '', $dateline));
                        $date     = new DateTime(trim(array_pop($dateArr)));

                        if ($date->format('Y-m-d') > $config->end_date) {
                            continue;
                        }

                        if ($date->format('Y-m-d') < $config->begin_date) {
                            $isNext = '';
                            continue;
                        }

                        $info['headline']        = $listQl->find('.sch-res-content>h3')->text();
                        $info['url']             = $host . $listQl->find('.sch-res-content .sch-res-title a')->attr('href');
                        $info['unique_id']       = md5($info['url']);
                        $info['author']          = $listQl->find('.sch-res-content .sch-res-info a')->text();
                        $info['section']         = $listQl->find('.sch-res-content .sch-res-section a')->text();
                        $info['date']            = $date->format('Y-m-d H:i:s');
                        $info['printed_edition'] = 'no';
                        $info['website']         = $this->website;
                        $info['keyword']         = $config->keyword;
                        $info['json_data']       = base64_encode(gzdeflate($list));

                        $data[] = $info;

                    }

                    SpiderData::insert($data);

                    if (empty($isNext)) {
                        $config->had_spider = Config::YES;
                        $config->save();
                        break;
                    }

                    $config->page = $page;
                    $config->save();
                    $this->info($page);
                    sleep(3);
                }
            }
        }
    }

    protected function dealCrawlerList($lists)
    {
        foreach ($lists as $list) {
            if (!empty($list['html'])) {
                $ql = QueryList::html($list['html']);

                $backup  = $ql->find('#js-article-text')->html();
                $title   = $ql->find('#js-article-text h2')->text();
                $summary = $ql->find('#js-article-text .mol-bullets-with-font li')->texts();
                $images  = $ql->find('#js-article-text .image-wrap img')->attrs('data-src');
                $filter  = $ql->find('#js-article-text');
                $filter->find('.floatRHS')->remove();
                $filter->find('.artSplitter')->remove();
                $filter->find('.author-section')->remove();
                $filter->find('.byline-section')->remove();
                $texts = $filter->find('[itemprop="articleBody]')->find('p')->texts();

                $content = '';
                $content .= $title ? $title . "\r\n\r\n" : '';
                $content .= $summary->isEmpty() ? '' : $summary->implode("\r\n");
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= $images->isEmpty() ? '' : "\r\nimages: " . $images->implode("\r\n");

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);

                Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($backup)));

                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);

                    SpiderData::where('id', $list['id'])->update([
                        'has_spider' => SpiderData::YES,
                    ]);
                }
            }
        }
    }
}
