<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use GuzzleHttp\Psr7\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class ReutersSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'reuters-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'reuters';
    protected $prefix  = 'RS';
    protected $deny    = 0;

    protected $keywords = [
        'China',
        'Taiwan',
        'Hong Kong',
        'Russia',
        'Russian',
        'Iran',
        'Iranian',
    ];

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
            case 'html':
                $this->spiderHtml($this->website, 3);
                break;
            case '4':
            case 'repeat':
                $this->dealRepeat();
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
        $keyword = 'china';

        $data = [];

        $years  = [2016, 2017, 2018, 2019, 2020];
        $months = [
            'january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december',
        ];

        foreach ($years as $year) {
            foreach ($months as $month) {

                $beginDate = date('Ymd', strtotime('first day of' . $month . ' ' . $year));
                $endDate   = date('Ymd', strtotime('last day of' . $month . ' ' . $year));

                if ($year == 2020 && $month == 'may') {
                    $data[] = [
                        'website'    => $this->website,
                        'keyword'    => $keyword,
                        'begin_date' => $beginDate,
                        'end_date'   => $beginDate,
                        'other_word' => $beginDate,
                        'page'       => 1,
                    ];
                    break 2;
                }

                $data[] = [
                    'website'    => $this->website,
                    'keyword'    => $keyword,
                    'begin_date' => $beginDate,
                    'end_date'   => $endDate,
                    'other_word' => $beginDate,
                    'page'       => 1,
                ];
            }
        }

        Config::insert($data);
    }

    protected function spiderList()
    {
        $configs = Config::where('website', $this->website)->where('had_spider', Config::NO)->get();
        $baseUrl = 'https://www.reuters.com/sitemap_%s-%s.xml';
        $client  = new Client([
            'handler' => $this->stack(),
        ]);
        date_default_timezone_set('UTC');

        foreach ($configs as $config) {
            $today    = $config->other_word;
            $tomorrow = date('Ymd', strtotime($today . '+1 day'));

            while (true) {
                $url = sprintf($baseUrl, $today, $tomorrow);
                $res = $client->request('GET', $url, [
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                        'User-Agent'      => $this->getUserAgent(),
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => 'https://www.reuters.com/sitemap_index.xml',
                        'Accept-Language' => 'zh-CN,zh;q=0.9',
                    ],
                    'proxy'   => 'socks5h://127.0.0.1:1080',
                    // 'debug'   => true,
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = $res->getBody()->getContents();

                    $lists = new \SimpleXMLElement($response);

                    foreach ($lists as $list) {
                        $info['url']             = (string) $list->loc;
                        $urlPath                 = explode('/', $info['url']);
                        $info['headline']        = explode('-id', end($urlPath))[0];
                        $info['date']            = date('Y-m-d H:i:s', strtotime($list->lastmod));
                        $info['unique_id']       = md5($info['url']);
                        $info['printed_edition'] = 'no';
                        $info['website']         = $this->website;
                        $info['keyword']         = $config->keyword;
                        $info['json_data']       = base64_encode(gzdeflate(json_encode($list)));

                        $data[] = $info;
                    }

                    SpiderData::insert($data);

                    if ($today >= $config->end_date) {
                        $config->had_spider = Config::YES;
                        $config->save();
                        break;
                    }

                    $config->other_word = $tomorrow;
                    $config->save();

                    $today    = $tomorrow;
                    $tomorrow = date('Ymd', strtotime($today . '+1 day'));

                    $this->info($config->other_word);
                    sleep(1);
                }
            }
        }
    }

    // 使用dealCrawlerList爬取，爬取剩下的部分数据时，将这个dealCrawlerLis2改成dealCrawlerList
    protected function dealCrawlerList2($lists)
    {
        foreach ($lists as $list) {
            if (!empty($list['html'])) {
                $ql = QueryList::html($list['html']);

                $backup  = $ql->find('#__next')->html();
                $title   = $ql->find('.ArticlePage-article-header-23J2O h1')->text();
                $section = $ql->find('.ArticleHeader-info-container-3-6YG a')->text();
                $images  = $ql->find('.ArticleBodyWrapper figure img')->attrs('src');

                $author = $ql->find('.Byline-byline-1sVmo span')->text();

                if ($author == 'Reuters Staff') {
                    $author = $ql->find('.Attribution-attribution-Y5JpY p')->text();
                }

                $filter = $ql->find('.ArticleBodyWrapper');
                $filter->find('.ArticleBody-byline-container-3H6dy')->remove();
                $filter->find('.Attribution-attribution-Y5JpY')->remove();
                $filter->find('.TrustBadge-trust-badge-20GM8')->remove();

                $texts   = $filter->find('p')->texts();
                $authors = explode('Reporting by', $author);
                $author  = end($authors);
                $author  = trim(str_replace("\n", ' ', $author));

                $content = '';
                $content .= $title ? $title . "\r\n\r\n" : '';
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= $images->isEmpty() ? '' : "\r\nimages: " . $images->implode("\r\n");
                $hasKeyword = false;

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);

                Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($backup)));

                if (!empty($contents)) {
                    foreach ($this->keywords as $value) {
                        if (stripos($contents, $value) !== false || stripos($title, $value) !== false) {
                            $hasKeyword = true;
                            $keyword    = $value;
                            break;
                        }
                    }

                    if ($hasKeyword) {
                        Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);
                        SpiderData::where('id', $list['id'])->update([
                            'has_spider' => SpiderData::YES,
                            'author'     => $author,
                            'section'    => $section,
                            'keyword'    => $keyword,
                            'headline'   => $title,
                            'unique_id'  => md5($title),
                        ]);
                    } else {
                        SpiderData::where('id', $list['id'])->delete();
                    }
                }
            }
        }
    }

    // 先使用这个进行接口的爬取，爬取剩下的部分数据将这个函数名改成其它的，比如dealCrawlerList1，再使用上面的dealCrawlerLis2改成dealCrawlerList
    protected function dealCrawlerList($lists)
    {
        foreach ($lists as $list) {
            if (!empty($list['html'])) {

                $response = json_decode($list['html'], true);
                if (empty($response['wireitems'])) {
                    $path = explode('id', $list['url']);
                    Log::info('wireitems is empty: ' . end($path));
                    SpiderData::where('id', $list['id'])->delete();
                    continue;
                }
                $data   = $response['wireitems'][0]['templates'][0];
                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);

                Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate(json_encode($response))));

                if (empty($data['story'])) {
                    $path = explode('id', $list['url']);
                    Log::channel('single')->info('story is empty: ' . end($path));
                    SpiderData::where('id', $list['id'])->delete();
                    continue;
                }

                $title   = $data['story']['hed'];
                $section = $data['story']['channel']['name'];
                $images  = implode("\r\n", array_column($data['story']['images'], 'url'));
                $body    = str_replace("\n", ' ', $data['story']['body']);

                $ql = QueryList::html($body);

                $texts  = $ql->find('p')->texts();
                $author = '';
                if (!empty($data['story']['authors'])) {
                    $author = implode(',', array_column($data['story']['authors'], 'name'));
                }

                $texts->transform(function ($item) use (&$author) {
                    $item = trim($item);

                    if (empty($author) && stripos($item, 'By') === 0 && preg_match('/^By [a-zA-Z\s,]+\n?/', $item, $matches)) {
                        $author = $matches[0];
                    }

                    if (empty($author) && stripos($item, '(Reporting by') !== false) {
                        $items = explode('(Reporting by', $item);

                        if (count($items) > 1) {
                            $author = trim(array_pop($items), " \t\n\r\0\x0B)");
                        }
                        $item = $items[0];
                    }

                    if (stripos($item, '(adds details') === false && !empty($item)) {
                        return $item;
                    }
                });

                if (empty($author)) {
                    $author = $data['story']['attribution']['content'];
                }

                $authors = explode('Reporting by', $author);
                $author  = end($authors);
                $author  = trim(str_replace("\n", ' ', $author));

                $content = '';
                $content .= $title ? $title . "\r\n\r\n" : '';
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= empty($images) ? '' : "\r\nimages: " . $images;
                $hasKeyword = false;

                if (!empty($contents)) {
                    foreach ($this->keywords as $value) {
                        if (stripos($contents, $value) !== false || stripos($title, $value) !== false) {
                            $hasKeyword = true;
                            $keyword    = $value;
                            break;
                        }
                    }

                    if ($hasKeyword) {
                        Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);
                        SpiderData::where('id', $list['id'])->update([
                            'has_spider' => SpiderData::YES,
                            'author'     => $author,
                            'section'    => $section,
                            'keyword'    => $keyword,
                            'headline'   => $title,
                            'unique_id'  => md5($title),
                        ]);
                    } else {
                        SpiderData::where('id', $list['id'])->delete();
                    }
                } else {
                    $path = explode('id', $list['url']);
                    Log::channel('single')->info('body is empty: ' . end($path));
                    SpiderData::where('id', $list['id'])->delete();
                    continue;
                }

            }
            if (!empty($list['code']) && $list['code'] == 403) {
                $this->deny++;

                if ($this->deny >= 100) {
                    $this->deny = 0;
                    sleep(120);
                }
            }
        }
    }

    // // dealCrawlerList爬取时候取消注释
    // protected function batchRequest($urlInfos)
    // {
    //     $baseUrl = 'https://wireapi.reuters.com/v7/feed/rapp/us/article/news:';
    //     foreach ($urlInfos as $info) {
    //         $headers = [
    //             'Accept'          => 'application/json',
    //             'User-Agent'      => 'okhttp/3.11.0',
    //             'Accept-Encoding' => 'gzip',
    //             'Content-Type'    => 'text/plain',
    //             'Host'            => 'wireapi.reuters.com',
    //         ];
    //         $path = explode('id', $info['url']);
    //         $url  = $baseUrl . end($path);
    //         yield new Request('GET', $url, $headers);
    //     }
    // }
}
