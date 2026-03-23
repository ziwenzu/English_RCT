<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class SfchronicleSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'sfchronicle-spider {--step= : 运行步骤}';

    protected $website = 'sfchronicle';
    protected $prefix  = 'SFC';

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

        $types = [
            'Article',
            'Blog+Post',
        ];

        $data = [];

        foreach ($keywords as $keyword) {
            foreach ($types as $type) {
                $data[] = [
                    'website'    => $this->website,
                    'keyword'    => $keyword,
                    'begin_date' => '2016-01-01',
                    'end_date'   => '2020-05-01',
                    'page'       => 1,
                    'other_word' => $type,
                ];
            }
        }
        Config::insert($data);
    }

    protected function spiderList()
    {
        $configs = Config::where('website', $this->website)->where('had_spider', Config::NO)->get();
        $baseUrl = 'https://www.sfchronicle.com/search/';
        $host    = 'https://www.sfchronicle.com';
        $client  = new Client([
            'handler' => $this->stack(),
        ]);

        foreach ($configs as $config) {
            $page = $config->page;

            static $count = 0;

            while (true) {
                $res = $client->request('GET', $baseUrl, [
                    'query'   => [
                        'action'      => 'search',
                        'searchindex' => 'solr',
                        'query'       => $config->keyword,
                        'sort'        => 'date',
                        'facet_type'  => $config->other_word,
                        'page'        => $page,
                        'subView'     => 'extra',
                    ],
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                        'User-Agent'      => $this->getUserAgent(),
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => $baseUrl,
                        'Accept-Language' => 'zh-CN,zh;q=0.9',
                    ],
                    'proxy'   => 'socks5h://127.0.0.1:1080',
                    // 'debug'   => true,
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = $res->getBody()->getContents();

                    $ql    = QueryList::html($response);
                    $lists = $ql->find('.gsa-item')->htmls();
                    $data  = [];

                    foreach ($lists as $list) {
                        $listQl   = QueryList::html($list);
                        $dateline = strtotime($listQl->find('.gsa-item-meta .timestamp')->text());

                        $date = date('Y-m-d', $dateline);

                        if ($date > $config->end_date) {
                            continue;
                        }

                        if ($date < $config->begin_date) {
                            $count++;
                            continue;
                        }

                        $url  = $listQl->find('.gsa-item-meta .byline')->text();
                        $path = explode('/', $url);

                        $info['headline']        = $listQl->find('h2')->text();
                        $info['url']             = $listQl->find('.headline a')->attr('href');
                        $info['author']          = $host . $url;
                        $info['date']            = date('Y-m-d H:i:s', $dateline);
                        $info['unique_id']       = md5($url);
                        $info['section']         = $path[1];
                        $info['printed_edition'] = 'no';
                        $info['website']         = $this->website;
                        $info['keyword']         = $config->keyword;
                        $info['json_data']       = base64_encode(gzdeflate(json_encode($list)));

                        $data[] = $info;

                    }

                    SpiderData::insert($data);
                    if ($count > 50 || empty($response)) {
                        $config->had_spider = Config::YES;
                        $config->page       = $page;
                        $config->save();
                        $count = 0;
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

                $isPhoto = $ql->find('.gallery__indicators')->html();

                if (!empty($isPhoto)) {
                    SpiderData::where('id', $list['id'])->update([
                        'full_text_id' => 'photo',
                    ]);
                    continue;
                }

                $rule1 = [
                    'backup' => ['.article', 'html'],
                    'title'  => ['.article .article--header h1', 'text'],
                    'texts'  => ['.article .main .body p', 'texts'],
                ];

                $rule2 = [
                    'backup' => ['article', 'html'],
                    'title'  => ['.article-title  h1', 'text'],
                    'texts'  => ['.article-body p', 'texts'],
                    'images' => ['.article-body .asset_photo  img', 'attrs(src)'],
                ];

                $rule3 = [
                    'backup' => ['#content', 'html'],
                    'title'  => ['.article-head h2', 'text'],
                    'texts'  => ['.article-text p', 'texts'],
                    'images' => ['.article-text .asset_photo  img', 'attrs(src)'],
                ];

                $rule4 = [
                    'backup' => ['#mainbar', 'html'],
                    'title'  => ['.article .header h1', 'text'],
                    'texts'  => ['.article p', 'texts'],
                    'images' => ['.article img', 'attrs(src)'],
                ];

                $data   = $ql->rules($rule1)->queryData();
                $filter = $ql->find('.article');
                $filter->find('.relatedStories')->remove();
                $filter->find('.footer')->remove();
                $images = $filter->find('.main img')->attrs('data-src');

                if (empty($data['title'])) {
                    $data   = $ql->rules($rule2)->queryData();
                    $filter = $ql->find('article');
                    $filter->find('.asset_factbox')->remove();
                    $data['texts'] = $filter->find('.article-body p')->texts()->toArray();
                    $images        = collect($data['images']);
                }

                if (empty($data['title'])) {
                    $data   = $ql->rules($rule3)->queryData();
                    $images = collect($data['images']);
                }

                if (empty($data['title'])) {
                    $data   = $ql->rules($rule4)->queryData();
                    $images = collect($data['images']);
                }

                $content = '';
                $content .= $data['title'] ? $data['title'] . "\r\n\r\n" : '';
                $contents = implode("\r\n", $data['texts']);
                $content .= $contents ?? '';
                $content .= $images->isEmpty() ? '' : "\r\nimages: " . $images->implode("\r\n");

                $textId = $this->prefix . str_pad($list['id'], 6, 0, STR_PAD_LEFT);
                // 仅作备份用途，用于生成内容不成功的时候不需要重复爬取，可以注释掉
                // Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($data['backup'])));

                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);

                    SpiderData::where('id', $list['id'])->update([
                        'has_spider' => SpiderData::YES,
                    ]);
                }
            }
            if (!empty($list['code'])) {
                SpiderData::where('id', $list['id'])->update([
                    'full_text_id' => $list['code'],
                ]);
            }
        }
    }
}
