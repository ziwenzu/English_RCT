<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use GuzzleHttp\Psr7\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class UsaTodaySpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'usa-today-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'usa-today';
    protected $prefix  = 'UT';

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
        $keyword = 'china';

        $data = [];

        $years  = [2016, 2017, 2018, 2019, 2020];
        $months = [
            'january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december',
        ];

        foreach ($years as $year) {
            foreach ($months as $month) {

                $beginDate = date('Y-F-j', strtotime('first day of' . $month . ' ' . $year));
                $endDate   = date('Y-F-j', strtotime('last day of' . $month . ' ' . $year));

                if ($year == 2020 && $month == 'may') {
                    $data[] = [
                        'website'    => $this->website,
                        'keyword'    => $keyword,
                        'begin_date' => $beginDate,
                        'end_date'   => $beginDate,
                        'other_word' => 1,
                        'page'       => 1,
                    ];
                    break 2;
                }

                $data[] = [
                    'website'    => $this->website,
                    'keyword'    => $keyword,
                    'begin_date' => $beginDate,
                    'end_date'   => $endDate,
                    'other_word' => 1,
                    'page'       => 1,
                ];
            }
        }
        Config::insert($data);
    }

    protected function spiderList()
    {
        $configs = Config::where('website', $this->website)->where('had_spider', Config::NO)->get();
        $baseUrl = 'https://www.usatoday.com/sitemap/%d/%s/%d/';
        $client  = new Client([
            'handler' => $this->stack(),
        ]);

        foreach ($configs as $config) {
            $page      = $config->page;
            $day       = $config->other_word;
            $beginDate = explode('-', $config->begin_date);
            $endDate   = explode('-', $config->end_date);

            while (true) {

                $url = sprintf($baseUrl, $beginDate[0], $beginDate[1], $day);
                $res = $client->request('GET', $url, [
                    'query'   => [
                        'page' => $page,
                    ],
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                        'User-Agent'      => $this->getUserAgent(),
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => 'https://www.usatoday.com/sitemap/',
                        'Accept-Language' => 'zh-CN,zh;q=0.9',
                    ],
                    'proxy'   => 'socks5h://127.0.0.1:1080',
                    // 'debug'   => true,
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = $res->getBody()->getContents();

                    $ql = QueryList::html($response);

                    $pagination = $ql->find('.sitemap-column-wrapper .sitemap-pagination .sitemap-list-item:last')->text();
                    $filter     = $ql->find('.sitemap-column-wrapper');
                    $filter->find('.sitemap-pagination')->remove();
                    $lists = $filter->find('.sitemap-list .sitemap-list-item')->htmls();
                    $data  = [];
                    $date  = date('Y-m-d H:i:s', strtotime($day . $beginDate[1] . $beginDate[0]));

                    foreach ($lists as $list) {
                        $listQl      = QueryList::html($list);
                        $info['url'] = $listQl->find('a')->attr('href');
                        if (stripos($info['url'], 'www.usatoday.com') === false ||
                            stripos($info['url'], '/videos/') !== false ||
                            stripos($info['url'], '/picture-gallery/') !== false ||
                            stripos($info['url'], '/pages/') !== false ||
                            stripos($info['url'], '/topic/') !== false
                        ) {
                            continue;
                        }
                        $info['headline']        = $listQl->find('a')->text();
                        $info['unique_id']       = md5($info['url']);
                        $info['date']            = $date;
                        $info['printed_edition'] = 'no';
                        $info['website']         = $this->website;
                        $info['keyword']         = $config->keyword;
                        $info['json_data']       = base64_encode(gzdeflate(json_encode($list)));

                        $data[] = $info;
                    }

                    SpiderData::insert($data);

                    if ($page >= $pagination) {
                        $day++;
                        $page               = 1;
                        $config->other_word = $day;
                    }

                    if ($day >= $endDate[2] && $page >= $pagination) {
                        $config->had_spider = Config::YES;
                        $config->save();
                        break;
                    }

                    $config->page = $page++;
                    $config->save();
                    $this->info($config->page);
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

                $title    = $ql->find('.gnt_cw .gnt_pr>h1')->text();
                $dateline = $ql->find('.gnt_cw .gnt_ar_dt')->attr('aria-label');

                if (!empty($dateline)) {
                    $dateArr   = explode('Updated:', $dateline);
                    $published = str_replace(['Published: ', 'Published '], ['', ''], $dateArr[0]);

                    $date = \DateTime::createFromFormat('g:i a ?T M? j, Y', trim($published));
                    if (empty($date)) {
                        Log::error($list['id'] . ' -- ' . $dateline);
                        continue;
                    }
                    $pubDate = $date->format('Y-m-d H:i:s');

                }

                $author  = $ql->find('.gnt_ar_by')->text();
                $images  = $ql->find('.gnt_pr .gnt_ar_b figure img')->attrs('data-gl-src');
                $texts   = $ql->find('.gnt_pr .gnt_ar_b p')->texts();
                $section = $ql->find('.gnt_cw .gnt_ar_lbl a')->text();
                $backup  = $ql->find('.gnt_cw')->html();
                if (empty($section)) {
                    $section = $ql->find('.gnt_cw .gnt_ar_lbl')->attr('aria-label');
                }

                $content = '';
                $content .= $title ? $title . "\r\n\r\n" : '';
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= $images->isEmpty() ? '' : "\r\nimages: " . $images->implode("\r\n");

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);

                Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($backup)));
                $hasKeyword = false;

                if (!empty($title) && empty($contents)) {
                    SpiderData::where('id', $list['id'])->update([
                        'has_spider' => SpiderData::YES,
                        'author'     => $author,
                        'section'    => $section,
                        'keyword'    => 'content is null',
                    ]);
                }

                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);
                    foreach ($this->keywords as $value) {
                        if (stripos($contents, $value) !== false) {
                            $hasKeyword = true;
                            $keyword    = $value;
                            break;
                        }
                    }

                    if ($hasKeyword) {
                        $data = [
                            'has_spider' => SpiderData::YES,
                            'author'     => $author,
                            'section'    => $section,
                            'keyword'    => $keyword,
                        ];
                        if (!empty($pubDate)) {
                            $data['date'] = $pubDate;
                        } else {
                            Log::info('dateline:' . $list['id']);
                        }
                        SpiderData::where('id', $list['id'])->update($data);
                    } else {
                        SpiderData::where('id', $list['id'])->delete();
                    }
                }
            }
            if (!empty($list['code']) && $list['code'] != 200) {
                SpiderData::where('id', $list['id'])->update([
                    'author' => $list['code'],
                ]);
            }
        }
    }

    protected function batchRequest($urlInfos)
    {
        foreach ($urlInfos as $info) {
            $headers = [
                'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                'Accept-Language' => 'zh-CN,zh;q=0.9',
                'User-Agent'      => $this->getUserAgent(),
                'Accept-Encoding' => 'gzip, deflate',
            ];
            yield new Request('GET', $info['url'], $headers);
        }
    }

    protected function getUserAgent()
    {
        $userAgents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.138 Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.102 Safari/537.36 Edge/18.18362',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:68.0) Gecko/20100101 Firefox/68.0',
            'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36',
            'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.89 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:78.0) Gecko/20100101 Firefox/78.0',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.102 Safari/537.36 Edge/18.19041',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.61 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987 Safari/537.36',
        ];

        return $userAgents[mt_rand(0, count($userAgents) - 1)];
    }
}
