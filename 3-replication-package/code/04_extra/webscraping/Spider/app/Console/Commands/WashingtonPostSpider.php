<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class WashingtonPostSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'washington-post-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'washington-post';
    protected $prefix  = 'WST';

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
        $baseUrl = 'https://sitesearchapp.washingtonpost.com/sitesearch-api/v2/search.json';
        $client  = new Client([
            'handler' => $this->stack(),
        ]);
        $date = new \DateTime('now');
        $size = 100;

        foreach ($configs as $config) {
            $page = $config->page;

            while (true) {
                $startAt = $size * $page++;
                $res     = $client->request('GET', $baseUrl, [
                    'query'   => [
                        'count'      => $size,
                        'datefilter' => 'displaydatetime:[* TO NOW/DAY+1DAY]',
                        'filter'     => '{!tag=include}contenttype:("Article" OR "Discussion" OR "Live_discussion" OR "BlogStory" OR "Blog")',
                        'query'      => $config->keyword,
                        'sort'       => 'displaydatetime desc',
                        'startat'    => $startAt,
                    ],
                    'headers' => [
                        'Accept'          => '*/*',
                        'User-Agent'      => $this->getUserAgent(),
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => $baseUrl,
                        'Host'            => 'sitesearchapp.washingtonpost.com',
                    ],
                    'proxy'   => 'socks5h://127.0.0.1:1080',
                    // 'debug'   => true,
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {
                    $response = json_decode($res->getBody()->getContents(), true);
                    $isEnd    = false;

                    foreach ($response['results']['documents'] as $list) {
                        if (empty($list['contenturl'])) {
                            continue;
                        }
                        $dateline = substr($list['displaydatetime'], 0, 10);
                        $date->setTimestamp($dateline);

                        if ($date->format('Y-m-d') > $config->end_date) {
                            continue;
                        }

                        if ($date->format('Y-m-d') < $config->begin_date) {
                            $isEnd = true;
                            continue;
                        }

                        $info['headline']        = $list['headline'];
                        $info['author']          = $list['byline'] ?? null;
                        $info['url']             = $list['contenturl'];
                        $info['unique_id']       = md5($info['headline']);
                        $info['date']            = $date->format('Y-m-d H:i:s');
                        $info['printed_edition'] = 'no';
                        $info['website']         = $this->website;
                        $info['keyword']         = $config->keyword;
                        $info['json_data']       = base64_encode(gzdeflate(json_encode($list)));

                        $data[] = $info;
                    }

                    SpiderData::insert($data);

                    if ($response['searchParams']['startat'] + $size >= $response['results']['total'] || $isEnd) {
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

                $rule = [
                    'title'   => ['.topper-headline>h1', 'text'],
                    'section' => ['.headline-kicker', 'text'],
                    'images'  => ['#article-body .inline-photo img', 'attrs(src)'],
                    'texts'   => ['.article-body p', 'texts'],
                    'backup'  => ['#article-standard-content', 'html'],
                ];

                $rule1 = [
                    'title'   => ['.relative .w-100>h1', 'text'],
                    'section' => ['.relative  header .kicker a:first', 'text'],
                    'images'  => ['.relative article figure img', 'attrs(src)'],
                    'texts'   => ['.article-body p', 'texts'],
                    'backup'  => ['.relative', 'html'],
                ];

                $rule2 = [
                    'title'   => ['.headlinebox>h1', 'text'],
                    'section' => ['.headline-kicker a:first', 'text'],
                    'images'  => ['#vf-wrapper .main-column img', 'attrs(src)'],
                    'texts'   => ['#vf-wrapper .main-column p', 'texts'],
                    'backup'  => ['#vf-wrapper', 'html'],
                ];

                $rule3 = [
                    'title'   => ['.ent-topper-standard .title-wrapper>h1', 'text'],
                    'section' => ['.ent-topper-standard .title-wrapper .et_posterlabel', 'text'],
                    'images'  => ['#ent-pb-main .ent-article-body .ent-photo img', 'attrs(src)'],
                    'texts'   => ['#ent-pb-main .ent-article-body p', 'texts'],
                    'backup'  => ['#pb-root', 'html'],
                ];

                $data = $ql->rules($rule)->queryData();
                if (empty($data['title'])) {
                    $data = $ql->rules($rule1)->queryData();
                }

                if (empty($data['title'])) {
                    $data = $ql->rules($rule2)->queryData();
                }

                if (empty($data['title'])) {
                    $data = $ql->rules($rule3)->queryData();
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
                    $section = $data['section'];
                    SpiderData::where('id', $list['id'])->update([
                        'has_spider' => SpiderData::YES,
                        'section'    => $section,
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
