<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class HuffpostSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'huffpost-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'huffpost';
    protected $prefix  = 'HP';

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
            case 3:
            case 'other_list':
                $this->spiderListSearch(); // 另外一种搜索列表的方法,执行前需要重新执行步骤1
                break;
            case 4:
            case 'repeat':
                $this->dealRepeat(); // 不同关键词会获取相同的新闻，用于去重
                break;
            case 5:
            case 'html':
                $this->spiderHtml($this->website, 3);
                break;
            case 6:
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

        $baseUrl = 'https://www.huffpost.com/api/topic/';
        $client  = new Client();

        foreach ($configs as $config) {
            $page = $config->page;

            $url = $baseUrl . $config->keyword . '/cards';

            while (true) {

                $res = $client->request('GET', $url, [
                    'query'   => [
                        'page'  => $page,
                        'limit' => 50,
                    ],
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                        'User-Agent'      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36',
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => $baseUrl,
                    ],
                    // 'proxy'   => 'socks5h://127.0.0.1:1080', // 本地搭建sock5用于绕过gwf
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = json_decode($res->getBody()->getContents(), true);

                    foreach ($response['cards'] as $list) {

                        $date = new \DateTime($list['headlines'][0]['published_date']);

                        if ($date->format('Y-m-d') > $config->end_date || $list['headlines'][0]['section_alias'] == 'video') {
                            continue;
                        }

                        if ($date->format('Y-m-d') < $config->begin_date) {
                            $config->had_spider = Config::YES;
                            $config->save();
                            break 2;
                        }

                        $author = $list['headlines'][0]['storyType']['type'] === 'standard'
                            ? $list['headlines'][0]['authors'][0]['fullName']
                            : $list['headlines'][0]['storyType']['sourceAuthor'];

                        $info['website']         = $this->website;
                        $info['url']             = $list['headlines'][0]['url'];
                        $info['unique_id']       = md5($info['url']);
                        $info['date']            = $date->format('Y-m-d H:i:s');
                        $info['headline']        = $list['headlines'][0]['text'];
                        $info['author']          = $author;
                        $info['printed_edition'] = 'no';
                        $info['section']         = $list['headlines'][0]['section_alias'];
                        $info['json_data']       = base64_encode(gzdeflate(json_encode($list)));
                        $info['keyword']         = $config->keyword;
                        $data[]                  = $info;
                    }

                    SpiderData::insert($data);

                    if ($response['meta']['nextPage'] === false) {
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

                $rules1 = [
                    'backup'  => ['#main article', 'html'],
                    'title'   => ['.js-headline>h1', 'text'],
                    'summary' => ['.js-headline .headline__subtitle', 'text'],
                    'texts'   => ['.js-entry-body p', 'texts'],
                    'images'  => ['#main figure img', 'attrs(src)'],
                    'date'    => ['.timestamp .timestamp__date--published', 'text'],
                ];
                $rules2 = [
                    'backup'  => ['#main article', 'html'],
                    'title'   => ['.entry__header>h1', 'text'],
                    'summary' => ['.entry__header .dek', 'text'],
                    'texts'   => ['.js-entry-content p', 'texts'],
                    'images'  => ['#main .cli img', 'attrs(src)'],
                    'date'    => ['.timestamp span:first', 'text'],
                ];

                $data  = $ql->rules($rules1)->queryData();
                $data2 = $ql->rules($rules2)->queryData();

                if (empty($data['title'])) {
                    $data = $data2;
                }
                if (!empty($data['date'])) {
                    $date = date('Y-m-d H:i:s', strtotime(str_replace('ET', 'EDT', $data['date'])));
                } else {
                    $date = date('Y-m-d H:i:s');
                }

                if (!empty($date) || $date > '2015-12-30') {
                    $updateData['date'] = $date;
                }

                $content = '';
                $content .= $data['title'] ? $data['title'] . "\r\n\r\n" : '';
                $content .= $data['summary'] ? $data['summary'] . "\r\n\r\n" : '';
                $contents = implode("\r\n", $data['texts']);
                $content .= $contents ?? '';
                $content .= empty($data['images']) ? '' : "\r\nimages: " . implode("\r\n", $data['images']);

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);

                Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($data['backup'])));

                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);
                    $updateData['has_spider'] = SpiderData::YES;
                    SpiderData::where('id', $list['id'])->update($updateData);
                }
            }
        }
    }

    protected function spiderListSearch()
    {
        $configs = Config::where('website', $this->website)->where('had_spider', Config::NO)->get();

        $baseUrl = 'https://search.huffpost.com/search;_ylt=AwrgDdxSYPNe8McAv1psBmVH;_ylu=X3oDMTEza3NiY3RnBGNvbG8DZ3ExBHBvcwMxBHZ0aWQDBHNlYwNwYWdpbmF0aW9u';
        $client  = new Client();

        foreach ($configs as $config) {
            $page = $config->page;

            while (true) {
                $b   = $page . 1;
                $res = $client->request('GET', $baseUrl, [
                    'query'   => [
                        'p'     => $config->keyword,
                        'pz'    => 10,
                        'fr'    => 'huffpost',
                        'fr2'   => 'sb-top',
                        'bct'   => 0,
                        'b'     => $b,
                        'pz'    => 10,
                        'bct'   => 0,
                        'xargs' => 0,
                    ],
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                        'User-Agent'      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36',
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'cookie'          => 'BX=79pcki1ff6mhl&b=3&s=vs; rxx=xsbcja3908.1z14fdph&v=1; A1=d=AQABBDVa814CEIJWtWVzQSQv7Ws9Nd2tZd0FEgEBAQGr9F79XgAAAAAA_SMAAAcINVrzXpCU5XQ&S=AQAAAraKfFXk-egMaIuAvFpdOos; GUC=AQEBAQFe9Kte_UIeUQSM; A3=d=AQABBDVa814CEIJWtWVzQSQv7Ws9Nd2tZd0FEgEBAQGr9F79XgAAAAAA_SMAAAcINVrzXpCU5XQ&S=AQAAAraKfFXk-egMaIuAvFpdOos; GUCS=Ab1vzZ_5; spotim_visitId={%22visitId%22:%22ba205c05-224d-4c35-9d9c-f70052ba01a9%22%2C%22creationDate%22:%222020-06-24T15:50:48.104Z%22%2C%22duration%22:365}; A1S=d=AQABBDVa814CEIJWtWVzQSQv7Ws9Nd2tZd0FEgEBAQGr9F79XgAAAAAA_SMAAAcINVrzXpCU5XQ&S=AQAAAraKfFXk-egMaIuAvFpdOos&j=CCPA',
                    ],
                    // 'proxy'   => 'socks5h://127.0.0.1:1080', // 本地搭建sock5用于绕过gwf
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = $res->getBody()->getContents();

                    $ql = QueryList::html($response);

                    $isNext = $ql->find('.compPagination .next')->html();
                    $lists  = $ql->find('.compArticleList .bt-dbdbdb')->htmls();
                    $data   = [];

                    foreach ($lists as $list) {
                        $listQl = QueryList::html($list);

                        $publishDate = $listQl->find('.bl-1-666')->text();
                        $date        = new \DateTime($publishDate);

                        if ($date->format('Y-m-d') > $config->end_date || $date->format('Y-m-d') < $config->begin_date) {
                            continue;
                        }

                        $url = urldecode($listQl->find('h4 a')->attr('href'));
                        if (strpos($url, 'https://www.huffpost.com') > 0) {
                            $url = explode('/RK=2', explode('/RU=', $url)[1])[0];
                        }

                        $info['section']         = $listQl->find('.d-ib')->text();
                        $info['headline']        = $listQl->find('h4')->text();
                        $info['author']          = str_replace('By ', '', $listQl->find('.csub .fc-f83371')->text());
                        $info['url']             = $url;
                        $info['unique_id']       = md5($info['url']);
                        $info['website']         = $this->website;
                        $info['printed_edition'] = 'no';
                        $info['json_data']       = base64_encode(gzdeflate(json_encode($list)));
                        $info['keyword']         = $config->keyword;
                        $info['date']            = $date->format('Y-m-d H:i:s');
                        $data[]                  = $info;
                    }

                    SpiderData::insert($data);

                    if (empty($isNext) || $page >= 99) {
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
}
