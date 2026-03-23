<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class NypostSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'nypost-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'nypost';
    protected $prefix  = 'NYP';

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
        $str = 'business,entertainment,fashion,living,media,metro,news,opinion,tech,sports,real-estate';

        $arr  = explode(',', $str);
        $data = [];

        foreach ($arr as $v) {
            $data[] = [
                'website'    => $this->website,
                'keyword'    => 'Taiwan',
                'begin_date' => '2016-01-01',
                'end_date'   => '2020-05-01',
                'other_word' => $v,
                'page'       => 1,
            ];
        }
        Config::insert($data);
    }

    protected function spiderList()
    {
        $configs = Config::where('website', $this->website)->where('had_spider', Config::NO)->get();

        $baseUrl = 'https://www.nypost.com/search/';
        $client  = new Client();

        foreach ($configs as $config) {
            $page = $config->page;

            $listUrl = $baseUrl . $config->keyword . '/page/%d';

            while (true) {
                $url = sprintf($listUrl, $page);
                $res = $client->request('GET', $url, [
                    'query'   => [
                        'section' => $config->other_word,
                    ],
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                        'User-Agent'      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36',
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => $baseUrl,
                    ],
                    // 'proxy'   => 'socks5h://127.0.0.1:1080',
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = $res->getBody()->getContents();
                    $ql       = QueryList::html($response);

                    $isNext = $ql->find('.decider__load-more')->html();

                    $lists = $ql->find('.article-loop .article-loop__article')->htmls();

                    foreach ($lists as $list) {
                        $listQl   = QueryList::html($list);
                        $dateline = str_replace('|', '-', $listQl->find('.entry-meta p:last')->html());
                        $date     = \DateTime::createFromFormat('M j, Y - g:ia', $dateline);

                        if ($date->format('Y-m-d') > $config->end_date) {
                            continue;
                        }

                        if ($date->format('Y-m-d') < $config->begin_date) {
                            $isNext = null;
                            continue;
                        }

                        $info['url']             = $listQl->find('.entry-header a')->attr('href');
                        $info['unique_id']       = md5($info['url']);
                        $info['date']            = $date->format('Y-m-d H:i:s');
                        $info['headline']        = str_replace(["\r\n", "\n", "\r", "\t"], [' '], $listQl->find('.entry-header>h3')->text());
                        $info['author']          = str_replace(["\r\n", "\n", "\r", "\t", 'By '], [' '], $listQl->find('.entry-meta .byline')->text());
                        $info['printed_edition'] = 'no';
                        $info['json_data']       = $list;
                        $info['keyword']         = $config->keyword;
                        $info['website']         = $this->website;
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
                    $this->info($url);
                }
            }
        }
    }

    protected function dealCrawlerList($lists)
    {
        foreach ($lists as $list) {
            if (!empty($list['html'])) {

                $ql = QueryList::html($list['html']);

                $backup    = $ql->find('.modal-enabled')->html();
                $section   = $ql->find('.article-header .section-tag')->text();
                $title     = $ql->find('.article-header>h1')->text();
                $texts     = $ql->find('.entry-content p')->texts();
                $headerImg = $ql->find('#featured-image-wrapper img')->attr('src');
                $images    = $ql->find('.entry-content img')->attrs('data-srcset');
                $bodyImgs  = [];
                foreach ($images as $image) {
                    $bodyImgs[] = current(explode(',', $image));
                }

                $content = '';
                $content .= $title ? $title . "\r\n\r\n" : '';
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= $headerImg ? '' : "\r\nhead_images: " . $headerImg;
                $content .= empty($bodyImgs) ? '' : "\r\nimages: " . implode("\r\n", $bodyImgs);

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);

                Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($backup)));

                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);

                    SpiderData::where('id', $list['id'])->update([
                        'has_spider' => SpiderData::YES,
                        'section'    => $section,
                    ]);
                }
            }
            // 跳过已经失效的网址
            if (isset($list['code']) && $list['code'] == 404) {
                SpiderData::where('id', $list['id'])->update([
                    'has_spider'   => SpiderData::YES,
                    'full_text_id' => 404,
                ]);
            }
        }
    }

}
