<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use GuzzleHttp\Psr7\Request;
use Illuminate\Support\Facades\Storage;

class StarTribuneSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'star-tribune-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'startribune';
    protected $prefix  = 'ST';

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

    protected function spiderList()
    {
        $configs = Config::where('website', 'startribune')->where('had_spider', Config::NO)->get();

        $baseUrl = 'https://www.startribune.com/search';
        $client  = new Client();

        foreach ($configs as $config) {
            $page = $config->page;

            while (true) {
                $res = $client->request('GET', $baseUrl, [
                    'query'   => [
                        'contentType' => 'Article',
                        'q'           => $config->keyword,
                        'page'        => $page,
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
                    $html     = str_replace('<p&#8230;< div="">', '</div>', $response);
                    $html     = str_replace('</p&#8230;<>', '', $html);
                    $html     = str_replace('<p class&#8230;<="" div="">', '</div>', $html);
                    $ql       = QueryList::html($html);

                    $isNext = $ql->find('.l-pagination .pagination-next')->html();
                    $lists  = $ql->find('.l-search-results .tease')->htmls();

                    foreach ($lists as $list) {
                        $listQl   = QueryList::html($list);
                        $dateline = $listQl->find('.article-dateline:first')->text();
                        $date     = \DateTime::createFromFormat('M j, Y — g:ia', $dateline);

                        if ($date->format('Y-m-d') < $config->begin_date || $date->format('Y-m-d') > $config->end_date) {
                            continue;
                        }

                        $info['url']             = $listQl->find('a')->attr('href');
                        $info['headline']        = $listQl->find('h3:first')->text();
                        $info['author']          = $listQl->find('.article-byline>strong')->html();
                        $info['unique_id']       = md5($info['url']);
                        $info['date']            = $date->format('Y-m-d H:i:s');
                        $info['printed_edition'] = 'no';
                        $info['keyword']         = $config->keyword;
                        $info['website']         = $this->website;
                        $info['json_data']       = base64_encode(gzdeflate($list));

                        $data[] = $info;
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
                }
            }
        }
    }

    protected function dealCrawlerList($lists)
    {
        foreach ($lists as $list) {
            $data = ['has_spider' => SpiderData::YES];

            if (isset($list['code']) && $list['code'] == 404) {
                $data = array_merge($data, [
                    'full_text_id' => 404,
                ]);
            } elseif (!empty($list['html'])) {
                $ql = QueryList::html($list['html']);

                $title   = $ql->find('.l-article-topper>h1')->text();
                $backUp  = $ql->find('.p402_premium')->html();
                $images  = $ql->find('.l-article-body img')->attr('src');
                $texts   = $ql->find('.article-body p')->texts();
                $section = $ql->find('.l-article-downpage-more-feed .block-label')->text();
                $section = str_replace('More From ', '', $section);

                $content = '';
                $content .= $title ? $title . "\r\n\r\n" : '';
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= empty($images) ? '' : "\r\nimages: " . $images;

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);

                Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($backUp)));
                $data['section'] = $section;
                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);
                }
            } else {
                continue;
            }

            SpiderData::where('id', $list['id'])->update($data);

            $this->info($list['id']);
        }
    }

    protected function batchRequest($urlInfos)
    {
        foreach ($urlInfos as $info) {
            $headers = [
                'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                'Accept-Language' => 'zh-CN,zh;q=0.9',
                'Referer'         => 'https://www.startribune.com/',
                'User-Agent'      => $this->getUserAgent(),
                'Accept-Encoding' => 'gzip, deflate',
            ];
            yield new Request('GET', $info['url'], $headers);
        }
    }
}
