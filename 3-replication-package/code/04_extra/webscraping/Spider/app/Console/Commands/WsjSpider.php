<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use GuzzleHttp\Psr7\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class WsjSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'wsj-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'The Wall Street Journal';

    protected $website = 'wsj';

    protected $prefix = 'WSJ';

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
        // 最多只能查时间范围4年内的，要进行分割
        $yearSplits = [
            ['begin_date' => '2016/01/01', 'end_date' => '2019/01/01'],
            ['begin_date' => '2019/01/01', 'end_date' => '2020/05/01'],
        ];

        $data = [];

        foreach ($keywords as $keyword) {
            foreach ($yearSplits as $yearSplit) {

                $data[] = [
                    'website'    => $this->website,
                    'keyword'    => $keyword,
                    'begin_date' => $yearSplit['begin_date'],
                    'end_date'   => $yearSplit['end_date'],
                    'page'       => 1,
                ];
            }
        }
        Config::insert($data);
    }

    protected function spiderList()
    {
        start:
        $configs = Config::where('website', $this->website)->where('had_spider', Config::NO)->orderBy('id', 'asc')->get();
        $baseUrl = 'https://www.wsj.com/search/term.html';
        $host    = 'https://www.wsj.com';
        $client  = new Client([
            'handler' => $this->stack(),
        ]);

        foreach ($configs as $config) {
            $page = $config->page;
            while (true) {
                $res = $client->request('GET', $baseUrl, [
                    'query'   => [
                        'KEYWORDS'   => $config->keyword,
                        'min-date'   => $config->begin_date,
                        'max-date'   => $config->end_date,
                        'isAdvanced' => true,
                        'daysback'   => '4y',
                        'sort'       => 'date-desc',
                        'source'     => 'wsjarticle,wsjpro',
                        'page'       => $page,
                    ],
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                        'User-Agent'      => $this->getUserAgent(),
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Accept-Language' => 'zh-CN,zh;q=0.9',
                    ],
                    'proxy'   => 'socks5h://127.0.0.1:1080',
                    // 'debug'   => true,
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {
                    $response = $res->getBody()->getContents();
                    $ql       = QueryList::html($response);
                    $lists    = $ql->find('#search-results .zonedModule .hedSumm .item-container')->htmls();
                    if (($lists->count() === 1 && strpos($lists->first(), 'No articles or videos')) || $lists->isEmpty()) {
                        goto start;
                    }
                    $data = [];
                    try {

                        foreach ($lists as $list) {
                            $listQl = QueryList::html($list);

                            $author   = str_replace('By ', '', $listQl->find('.article-info .byline')->text());
                            $dateline = $listQl->find('.article-info .date-stamp-container')->text();
                            $date     = \DateTime::createFromFormat('M? j, Y g:i a ?T', trim($dateline));
                            $url      = explode('?mod', $listQl->find('.headline a')->attr('href'))[0];

                            $info['headline']        = $listQl->find('.headline')->text();
                            $info['section']         = $listQl->find('.category')->text();
                            $info['url']             = $host . $url;
                            $info['unique_id']       = md5($info['url']);
                            $info['author']          = $author;
                            $info['printed_edition'] = empty($listQl->find('.printheadline')->text()) ? 'no' : 'yes';
                            $info['website']         = $this->website;
                            $info['keyword']         = $config->keyword;
                            $info['date']            = $date->format('Y-m-d H:i:s');
                            $info['json_data']       = base64_encode(gzdeflate($list));

                            $data[] = $info;
                        }
                    } catch (\Error $e) {
                        Storage::put($config->keyword . $config->id . $page . '.html', $response);
                        break;
                    }

                    SpiderData::insert($data);

                    $isNext = $ql->find('.results-menu-wrapper .results .next-page')->text();
                    if (empty($isNext)) {
                        $config->had_spider = Config::YES;
                        $config->page       = $page;
                        $config->save();
                        Storage::put($config->keyword . $config->id . $page . '.html', $response);
                        break;
                    }

                    $config->page = $page++;
                    $config->save();
                    $this->info($config->page);
                    sleep(2);
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
                    'backup' => ['#main', 'html'],
                    'title'  => ['#main .article_header .wsj-article-headline-wrap h1', 'text'],
                    'images' => ['#wsj-article-wrap .image-container img', 'attrs(src)'],
                ];

                $rule2 = [
                    'backup' => ['article', 'html'],
                    'title'  => ['#ncTitleArea .wsj-article-headline-wrap h1', 'text'],
                    'images' => ['#wsj-article-wrap .image-container img', 'attrs(src)'],
                    'texts'  => ['.nc-exp-article p', 'texts'],
                ];

                $data   = $ql->rules($rule1)->queryData();
                $filter = $ql->find('.article-content');
                $filter->find('.type-InsetRichText')->remove();
                $filter->find('.printheadline')->remove();
                $data['texts'] = $filter->find('p')->texts()->toArray();

                if (empty($data['title'])) {
                    $data = $ql->rules($rule2)->queryData();
                }

                $isPhoto = $ql->find('.WSJTheme--slideshow-num-slides-goJcVIiX2ExxnXt90Dsfy')->text();

                if ((!empty($isPhoto) && empty($ql->find('.nc-exp-article')->text())) || stripos($data['title'], 'Photos of the Week') !== false) {
                    SpiderData::where('id', $list['id'])->update([
                        'full_text_id' => 'photos',
                    ]);
                    continue;
                }

                $texts = [];
                if (!empty($data['texts'])) {
                    $texts = array_map(function ($item) {
                        // 删除最后无用的网站声明或内容
                        if (stripos($item, 'More in a series') !== false || stripos($item, 'Copyright ©2020 Dow Jones') !== false) {
                            $item = '';
                        }
                        // 去掉多余的换行//
                        return preg_replace(['/\n/', '/\s{2,}/'], ['', ' '], $item);
                    }, $data['texts']);
                } else {
                    Log::info('contents is empty:' . $list['id']);
                }

                $content = '';
                $content .= $data['title'] ? $data['title'] . "\r\n\r\n" : '';
                $contents = implode("\r\n", $texts);
                $content .= $contents ?? '';
                $content .= empty($data['images']) ? '' : "\r\nimages: " . implode("\r\n", $data['images']);

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

    public function batchRequest($urlInfos)
    {
        foreach ($urlInfos as $info) {
            $headers = [
                'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                'Accept-Language' => 'zh-CN,zh;q=0.9',
                'User-Agent'      => $this->getUserAgent(),
                'Accept-Encoding' => 'gzip, deflate, br',
                'cookie'          => 'wsjregion=na%2Cus; gdprApplies=false; ccpaApplies=false; ab_uuid=4b9cf5f4-147e-4d5c-99c3-54030104f1f1; usr_bkt=ixi4E5ylqa; cX_P=ke5abt2uox1502j9; cX_S=ke5abt33z733tft2; djvideovol=1; AMCVS_CB68E4BA55144CAA0A4C98A5%40AdobeOrg=1; AMCV_CB68E4BA55144CAA0A4C98A5%40AdobeOrg=1585540135%7CMCIDTS%7C18497%7CMCMID%7C61379580714613013994186305701286045829%7CMCAID%7CNONE%7CMCOPTOUT-1598085115s%7CNONE%7CMCAAMLH-1598682715%7C11%7CMCAAMB-1598682715%7Cj8Odv6LonN4r3an7LhD3WZrU1bUpAkFkkiY1ncBR96t2PTI%7CMCSYNCSOP%7C411-18504%7CvVersion%7C4.4.0; MicrosoftApplicationsTelemetryDeviceId=723bf148-7540-7ba3-6600-0f5d3ac85643; MicrosoftApplicationsTelemetryFirstLaunchTime=1598077923633; djcs_route=aff29e3d-46e8-41cf-af78-5e2f6f8380cc; GED_PLAYLIST_ACTIVITY=W3sidSI6ImVHN2ciLCJ0c2wiOjE1OTgwNzc5MjksIm52IjoxLCJ1cHQiOjE1OTgwNzc5MTAsImx0IjoxNTk4MDc3OTI4fV0.; TR=V2-8a09c893cf7fff498c3ca65c1bd2f217f23fd61f00055b45eca7cab8482de03c; djcs_auto=M1598043824%2FSDEUIviBzo%2BBP0D6j%2BnrsxMV044xs8LSN7gBRDie4Sky0SOGfqqe%2BMrsXYeAF%2BfCxfQ3e3bhTGh3NfxbNrlOwFaxAP%2FURdlyyTxeazVpy5CActcDajHNWP6cTr3f8UhuWwT5BUvZvO%2BtjD9UbuYITho%2FKkhnBV8JOV%2FuIdm%2Fu72OLPKddV807tPzsQbc8dfieZlG9zoiCMRAy65BCf7IvWjRKv9kCDcnZwPXYlHRDTrS0hCoW9a%2B%2FfBezBGC7GkiDg4g5z3tjoe9dHGESQnLpNNYiW6Q4pJTsb2yKb47kPv3AbSHk8tlF48J57D4cCstpNuY%2Bv13cQKQ2%2FlVQTHC7nKSGFWkfFdNamOqImztkXfI2wx1wREg2BfSIa9gUQKqVXMVNlTpbjyB%2BFOxtJj0hQ%3D%3DG; djcs_session=M1598071428%2F3HBCbo5CazHaSl1MtK90NFdNk%2BzZ8Nsr0KbEZMlOcU4UEsDqDImr0O3J0rNFD%2Bs2OyQUxnrvKMvU4LZLV005wgZ51gLI%2B8H1yasljw%2BK1dUUTVZ1G%2FPYoxBeeOD3d4QFDuaBCtE3QdKd1N8SpryWu7uBqzaY78b6XK5g%2B9zQrY42idaCgPcORlghqhiXeyK2uedLq38yBwSFmONe2rS0mo%2F4GG3XMubsQdyvUt3YrA227Be%2BKM9Ry1N5yaDqkG9SBCIcxSnzweoeOiioKGMoyVBJDNHyHWpv4WOJ5KB%2BNhYdNEKI%2BO0s7wBbxHDuMrlfJQcj0sllJmPlG8ShomMEXQkF%2BQqk8wxX79whVKjfgsTG00Q6yhq6%2Bmd0F0cvhMRlv3%2BWEBgy5KsSDkxlvehnB3MlVk1lzYpMqCZcR8Do0rqURAlHDaYHGtXLpWoTMxgHIoYDlTnX0dmkTjTiYNdKNIK2VxkoyNoaDpqQ56vM0Ho%3DG; usr_prof_v2=eyJjcCI6eyJlYyI6Ik5vIEhpc3RvcnkiLCJwYyI6MC4wNDk5NiwicHNyIjowLjMwNzY5LCJ0ZCI6MiwiYWQiOjEsInFjIjo4MCwicW8iOjc4LCJzY2VuIjp7ImNoZSI6MC4wNTk5NywiY2huIjowLjA1NTA4LCJjaGEiOjAuMDI4MDUsImNocCI6MC4wNTI2OH19LCJpYyI6NH0%3D; ResponsiveConditional_initialBreakpoint=md; s_cc=true',
            ];
            yield new Request('GET', $info['url'], $headers);
        }
    }
}
