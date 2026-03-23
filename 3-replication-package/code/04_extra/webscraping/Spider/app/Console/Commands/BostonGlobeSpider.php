<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class BostonGlobeSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'boston-globe-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';
    protected $website     = 'boston-globe';
    protected $prefix      = 'BG';

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
        $baseUrl = 'https://search.arcpublishing.com/search/';
        $host    = 'https://www.bostonglobe.com';
        $client  = new Client([
            'handler' => $this->stack(),
        ]);
        $perPage      = 100;
        static $count = 0;

        foreach ($configs as $config) {
            $page = $config->page;
            while (true) {
                $res = $client->request('GET', $baseUrl, [
                    'query'   => [
                        'q'        => $config->keyword,
                        'per_page' => $perPage,
                        'page'     => $page,
                        'key'      => 'bW34vNWHls3McYLGmaBRf8Th7Au8AZyN5djpxg2T',
                        's'        => 'date',
                    ],
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                        'User-Agent'      => $this->getUserAgent(),
                        'Accept-Encoding' => 'gzip, deflate',
                        'Accept-Language' => 'zh-CN,zh;q=0.9',
                    ],
                    'proxy'   => 'socks5h://127.0.0.1:1080',
                    // 'debug'   => true,
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = json_decode($res->getBody()->getContents(), true);

                    foreach ($response['data'] as $list) {
                        $date        = $list['display_date'];
                        $publishDate = strtotime($date);
                        $createDate  = date('Y-m-d', $publishDate);
                        if ($createDate > $config->end_date) {
                            continue;
                        }

                        if ($createDate < $config->begin_date) {
                            $count++;
                            Log::Info("date is early:{$list['_id']} -- {$date},page:{$page}");
                            continue;
                        }

                        $authors = [];
                        if (!empty($list['credits']['by'])) {
                            $authors = array_map(function ($data) {
                                if ($data['type'] === 'author') {
                                    return $data['name'];
                                }
                            }, $list['credits']['by']);
                        }

                        if ($list['type'] !== 'story') {
                            Log::info("type:{$list['_id']} -- {$list['type']}");
                        }

                        if (empty($list['canonical_url'])) {
                            Log::info("url empty:{$list['_id']}");
                            $list['canonical_url'] = '/empty';
                        }

                        $info['author']          = implode(',', $authors);
                        $info['date']            = date('Y-m-d H:i:s', $publishDate);
                        $info['headline']        = $list['headlines']['basic'];
                        $info['url']             = $host . $list['canonical_url'];
                        $info['section']         = $list['websites']['bostonglobe']['website_section']['name'] ?? '';
                        $info['unique_id']       = $list['_id'];
                        $info['website']         = $this->website;
                        $info['keyword']         = $config->keyword;
                        $info['printed_edition'] = 'no';
                        $info['json_data']       = base64_encode(gzdeflate(json_encode($list)));

                        $data[] = $info;
                    }

                    SpiderData::insert($data);

                    if ($page * $perPage >= $response['metadata']['total_hits'] || $count > 5) {
                        $config->had_spider = Config::YES;
                        $config->save();
                        $count = 0;
                        break;
                    }

                    $config->page = $page++;
                    $config->save();
                    $this->info($config->page);
                    sleep(1);
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
                    'backup' => ['#article-right-rail article', 'html'],
                    'title'  => ['#header-container h1', 'text'],
                    'images' => ['#article-right-rail article .image figure img', 'attrs(src)'],
                ];

                $rule2 = [
                    'backup' => ['#page-body', 'html'],
                    'title'  => ['#header-container h1', 'text'],
                    'images' => ['#page-body .image figure img', 'attrs(src)'],
                ];

                $rule3 = [
                    'backup' => ['.article', 'html'],
                    'title'  => ['.article .article-header h1', 'text'],
                    'images' => ['.article figure img', 'attrs(srcset)'],
                    'texts'  => ['.article .content-text p', 'texts'],
                ];

                $data = $ql->rules($rule1)->queryData();
                if (empty($data['backup'])) {
                    $data = $ql->rules($rule2)->queryData();
                }

                $filter = $ql->find('#article-body');
                $filter->find('.arc_ad')->remove();
                $texts  = $filter->find('p')->texts();
                $images = [];
                if (empty($data['images'])) {
                    $images = array_map(function ($item) {
                        $arr = explode('/20x0/', $item);
                        return end($arr);
                    }, $data['images']);
                }

                if (empty($data['backup'])) {
                    $data  = $ql->rules($rule3)->queryData();
                    $texts = collect($data['texts']);

                    if (empty($data['images'])) {
                        $images = array_map(function ($item) {
                            $arr = explode(' ', $item);
                            return current($arr);
                        }, $data['images']);
                    }
                }

                $content = '';
                $content .= $data['title'] ? $data['title'] . "\r\n\r\n" : '';
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= empty($images) ? '' : "\r\nimages: " . implode("\r\n", $images);

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);
                // 仅作备份用途，用于生成内容不成功的时候不需要重复爬取，可以注释掉
                // Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($data['backup'])));

                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);

                    SpiderData::where('id', $list['id'])->update([
                        'has_spider' => SpiderData::YES,
                    ]);
                }
            }
            if (!empty($list['code']) && $list['code'] != 200) {
                SpiderData::where('id', $list['id'])->update([
                    'full_text_id' => $list['code'],
                ]);
            }
        }
    }
}
