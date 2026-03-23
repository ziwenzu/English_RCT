<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class NewsDaySpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'news-day-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'news-day';
    protected $prefix  = 'ND';

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
        $data    = [];
        $years   = [2016, 2017, 2018, 2019, 2020];

        foreach ($years as $year) {
            for ($month = 1; $month <= 12; $month++) {
                $month = str_pad($month, 2, 0, STR_PAD_LEFT);

                $date = $year . '-' . $month;

                if ($year == 2020 && $month === '05') {
                    $data[] = [
                        'website'    => $this->website,
                        'keyword'    => $keyword,
                        'begin_date' => $date,
                        'end_date'   => $date,
                        'page'       => 1,
                    ];
                    break 2;
                }

                $data[] = [
                    'website'    => $this->website,
                    'keyword'    => $keyword,
                    'begin_date' => $date,
                    'end_date'   => $date,
                    'page'       => 1,
                ];
            }
        }
        Config::insert($data);
    }

    protected function spiderList()
    {
        $configs = Config::where('website', $this->website)->where('had_spider', Config::NO)->get();
        $baseUrl = 'https://www.newsday.com/sitemaps';
        $client  = new Client([
            'handler' => $this->stack(),
        ]);

        foreach ($configs as $config) {
            list($year, $month) = explode('-', $config->begin_date);

            $res = $client->request('GET', $baseUrl, [
                'query'   => [
                    'type'  => 'article',
                    'year'  => $year,
                    'month' => $month,
                ],
                'headers' => [
                    'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                    'User-Agent'      => $this->getUserAgent(),
                    'Accept-Encoding' => 'gzip, deflate, br',
                    'Accept-Language' => 'zh-CN,zh;q=0.9',
                ],
                // 'proxy'   => 'socks5h://127.0.0.1:1080',
                'timeout' => 60,
            ]);

            $data = [];
            if ($res->getStatusCode() == 200) {
                $response = $res->getBody()->getContents();

                $ql    = QueryList::html($response);
                $lists = $ql->find('.container article .articles li')->htmls();
                $data  = [];

                foreach ($lists as $list) {
                    $listQl = QueryList::html($list);

                    $info['headline'] = trim($listQl->find('a')->text(), '"');

                    if (empty($info['headline'])) {
                        continue;
                    }

                    $info['url']             = $listQl->find('a')->attr('href');
                    $info['unique_id']       = md5($info['url']);
                    $info['website']         = $this->website;
                    $info['keyword']         = $config->keyword;
                    $info['printed_edition'] = 'no';
                    $info['date']            = date('Y-m-d H:i:s', strtotime($config->begin_date));
                    $info['json_data']       = base64_encode(gzdeflate($list));

                    $data[] = $info;
                }

                SpiderData::insert($data);

                $this->info($config->begin_date);
                $config->had_spider = Config::YES;
                $config->save();
                // sleep(3);
            }
        }
    }

    protected function dealCrawlerList($lists)
    {
        foreach ($lists as $list) {
            if (!empty($list['html'])) {
                $ql = QueryList::html($list['html']);

                $rule = [
                    'title'   => ['.sticky header>h1', 'text'],
                    'date'    => ['.gut .contentWell time', 'attr(datetime)'],
                    'author'  => ['.gut .contentWell .byline:first strong', 'text'],
                    'author1' => ['.full .byline:first strong', 'text'],
                ];

                $rule1 = [
                    'title'  => ['.topper .vcent>h1', 'text'],
                    'date'   => ['.full .entryHead .byline time', 'attr(datetime)'],
                    'author' => ['.full .entryHead .byline strong', 'text'],
                ];

                $data = $ql->rules($rule)->queryData();
                if (empty($data['title'])) {
                    $data = $ql->rules($rule1)->queryData();
                }

                $backup = $ql->find('.container')->html();
                $filter = $ql->find('.container');
                $filter->find('.bot')->remove();
                $filter->find('.newsletterSignup')->remove();
                $texts  = $filter->find('.gut .contentWell #contentAccess p')->texts();
                $images = $filter->find('.gut .contentWell picture img')->attrs('src');
                $author = $data['author'];

                //  作者获取的方式有几种，处理作者
                empty($data['author']) && $author = $data['author1'];
                if (empty($author)) {
                    $data   = $ql->rules($rule1)->queryData();
                    $author = $data['author'];
                }
                $author = str_replace('By ', '', $author);

                $content = '';
                $content .= $data['title'] ? $data['title'] . "\r\n\r\n" : '';
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= $images->isEmpty() ? '' : "\r\nimages: " . $images->implode("\r\n");

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);

                Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($backup)));
                $hasKeyword = false;

                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);
                    foreach ($this->keywords as $value) {
                        if (stripos($contents, $value) !== false || stripos($data['title'], $value) !== false) {
                            $hasKeyword = true;
                            $keyword    = $value;
                            break;
                        }
                    }

                    if ($hasKeyword) {
                        $url     = str_replace(['https://www.newsday.com/', 'http://www.newsday.com/'], [''], $list['url']);
                        $urlPath = explode('/', $url);
                        array_pop($urlPath);

                        if (!empty($data['date'])) {
                            $update['date'] = date('Y-m-d H:i:s', strtotime($data['date']));
                        }

                        $update = [
                            'has_spider' => SpiderData::YES,
                            'author'     => $author,
                            'section'    => end($urlPath),
                            'keyword'    => $keyword,
                            'headline'   => $data['title'],
                        ];

                        if (!empty($data['date'])) {
                            $update['date'] = date('Y-m-d H:i:s', strtotime($data['date']));
                        }

                        if (!empty($data['title'])) {
                            $update['headline'] = $data['title'];
                        }

                        SpiderData::where('id', $list['id'])->update($update);
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
}
