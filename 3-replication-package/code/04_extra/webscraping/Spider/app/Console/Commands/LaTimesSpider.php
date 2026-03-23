<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class LaTimesSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'la-times-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';
    protected $website     = 'la-times';
    protected $prefix      = 'LAT';

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
        $baseUrl = 'https://www.latimes.com/search';
        $client  = new Client([
            'handler' => $this->stack(),
        ]);
        $date = new \DateTime('now', new \DateTimeZone('PST8PDT'));

        foreach ($configs as $config) {
            $page = $config->page;

            while (true) {

                $res = $client->request('GET', $baseUrl, [
                    'query'   => [
                        'q'  => $config->keyword,
                        'f1' => '0000016a-ea2d-db5d-a57f-fb2dc8680000',
                        's'  => 1,
                        'p'  => $page,
                    ],
                    'headers' => [
                        'Accept'          => '*/*',
                        'User-Agent'      => $this->getUserAgent(),
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => $baseUrl,
                    ],
                    'proxy'   => 'socks5h://127.0.0.1:1080',
                    // 'debug'   => true,
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = $res->getBody()->getContents();

                    $ql = QueryList::html($response);

                    $lists  = $ql->find('.search-results-module-main .search-results-module-results-menu li')->htmls();
                    $isNext = $ql->find('.search-results-module-pagination .search-results-module-next-page')->text();

                    foreach ($lists as $list) {
                        $listQl = QueryList::html($list);

                        $url = $listQl->find('.promo-title-container .promo-title a')->attr('href');
                        if (empty($url)) {
                            continue;
                        }
                        $dateline = substr($listQl->find('.promo-content .promo-timestamp')->attr('data-timestamp'), 0, 10);
                        $date->setTimestamp($dateline);

                        if ($date->format('Y-m-d') > $config->end_date || $date->format('Y-m-d') < $config->begin_date) {
                            continue;
                        }

                        $info['headline']        = $listQl->find('.promo-title-container .promo-title')->text();
                        $info['url']             = $url;
                        $info['section']         = $listQl->find('.promo-title-container .promo-category')->text();
                        $info['date']            = $date->format('Y-m-d H:i:s');
                        $info['unique_id']       = md5($info['url']);
                        $info['printed_edition'] = 'no';
                        $info['website']         = $this->website;
                        $info['keyword']         = $config->keyword;
                        $info['json_data']       = base64_encode(gzdeflate(json_encode($list)));
                        $data[]                  = $info;
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

                $rule1 = [
                    'title'   => ['.page-content h1', 'text'],
                    'author'  => ['.byline .author-name span', 'text'],
                    'headImg' => ['.page-lead-media .figure img', 'attrs(src)'],
                    'images'  => ['.page-article-container .figure img', 'attrs(data-src)'],
                    'backup'  => ['.page-main-content', 'html'],
                ];

                $rule2 = [
                    'title'   => ['.page-lead-meta h1', 'text'],
                    'author'  => ['.byline .author-name span', 'text'],
                    'headImg' => ['.page-lead .figure img', 'attrs(src)'],
                    'images'  => ['.page-main .figure img', 'attrs(data-src)'],
                    'backup'  => ['#Start', 'html'],
                    'texts'   => ['.story-stack p', 'texts'],
                ];

                $rule3 = [
                    'title'   => ['.page-content h1', 'text'],
                    'author'  => ['.lb-card-bylines a', 'text'],
                    'headImg' => ['.page-lead-media .figure img', 'attrs(src)'],
                    'images'  => ['.lb-card .lb-image-size-large img', 'attrs(src)'],
                    'texts'   => ['.lb-card p', 'texts'],
                    'backup'  => ['.page-main-content', 'html'],
                ];

                $data   = $ql->rules($rule1)->queryData();
                $filter = $ql->find('.page-article-body');
                $filter->find('.enhancement')->remove();
                $texts = $filter->find('p')->texts();

                if (empty($data['title'])) {
                    $data  = $ql->rules($rule2)->queryData();
                    $texts = collect($data['texts']);
                }

                if ($texts->filter()->isEmpty()) {
                    $data  = $ql->rules($rule3)->queryData();
                    $texts = collect($data['texts']);
                }

                if ($texts->isEmpty()) {
                    $texts          = $ql->find('.widget-text p')->texts();
                    $data['author'] = $ql->find('.byline-text')->text();
                }

                $images = array_merge($this->dealImageUrl($data['headImg']),
                    $this->dealImageUrl($data['images']));

                $content = '';
                $content .= $data['title'] ? $data['title'] . "\r\n\r\n" : '';
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= empty($images) ? '' : "\r\nimages: " . implode("\r\n", $images);
                $author = trim(str_replace(['By', 'Staff Writer', 'Writer', "&nbsp;"], [''], $data['author']));

                $textId = $this->prefix . str_pad($list['id'], 6, 0, STR_PAD_LEFT);

                Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($data['backup'])));

                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);

                    SpiderData::where('id', $list['id'])->update([
                        'has_spider' => SpiderData::YES,
                        'author'     => $author,
                    ]);
                }
            }
        }
    }

    protected function dealImageUrl($urls)
    {
        $data = [];
        foreach ($urls as $url) {
            $urlPath = explode('?url=', $url);
            $data[]  = urldecode(end($urlPath));
        }
        return $data;
    }
}
