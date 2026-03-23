<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class ChicagoTribuneSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'chicago-tribune-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'chicago-tribune';
    protected $prefix  = 'CT';

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
            'Hong+Kong',
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
        $baseUrl = 'https://www.chicagotribune.com/search/';
        $host    = 'https://www.chicagotribune.com';
        $client  = new Client([
            'handler' => $this->stack(),
        ]);

        foreach ($configs as $config) {
            $page = $config->page;
            while (true) {
                $url = sprintf($baseUrl . '%s/100-y/story/date/%d/', $config->keyword, $page);
                $res = $client->request('GET', $url, [
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
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
                    $ql       = QueryList::html($response);
                    $lists    = $ql->find('.pb-container ul .col-tablet-3')->htmls();
                    $isNext   = $ql->find('.pb-f-search-search-pagination .hddn-mble .button-slider-js:last')->attr('aria-disabled');

                    foreach ($lists as $list) {
                        $listQl   = QueryList::html($list);
                        $dateline = $listQl->find('.timestamp-wrapper')->text();
                        $date     = date('Y-m-d', strtotime($dateline));

                        if ($date > $config->end_date) {
                            continue;
                        }

                        if ($date < $config->begin_date) {
                            $isNext = true;
                            continue;
                        }

                        $author = str_replace("\n", ' and ', $listQl->find('.byline-wrapper .byline span')->text());

                        $info['headline']        = $listQl->find('.h7 a')->text();
                        $info['url']             = $host . $listQl->find('.h7 a')->attr('href');
                        $info['unique_id']       = md5($info['url']);
                        $info['section']         = $listQl->find('.tag-list-wrapper')->text();
                        $info['date']            = $date;
                        $info['author']          = $author;
                        $info['printed_edition'] = 'no';
                        $info['website']         = $this->website;
                        $info['keyword']         = $config->keyword;
                        $info['json_data']       = base64_encode(gzdeflate($list));

                        $data[] = $info;

                    }
                    SpiderData::insert($data);

                    if ($isNext) {
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

                $title    = $ql->find('#top .pb-f-article-header .card-content h1')->text();
                $dateline = $ql->find('.byline-container .timestamp-wrapper .timestamp-article')->text();
                $dateline = str_replace(["\n", 'at'], [''], $dateline);
                $date     = date('Y-m-d H:i:s', strtotime($dateline));
                $texts    = $ql->find('.artcl--m .artcl--sect-tmpl .crd--cnt p')->texts();
                $filter   = $ql->find('.artcl--m #left');
                $filter->find('.rcom--ctn')->remove();
                $headImg = $filter->find('.pb-f-utilities-lead-art img')->attr('src');
                $images  = $filter->find('.pb-f-article-body .img-container img')->attrs('data-src');
                $backup  = $filter->html();

                $content = '';
                $content .= $title ? $title . "\r\n\r\n" : '';
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= empty($headImg) ? '' : "\r\nhead_image: " . $headImg;
                $content .= $images->isEmpty() ? '' : "\r\nimages: " . $images->implode("\r\n");

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);
                // 仅作备份用途，用于生成内容不成功的时候不需要重复爬取，可以注释掉
                // Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($backup)));

                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);

                    SpiderData::where('id', $list['id'])->update([
                        'has_spider' => SpiderData::YES,
                        'date'       => $date,
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
