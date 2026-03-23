<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class StraitsTimesSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'straits-times-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'straits-times';
    protected $prefix  = 'TST';

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
        $baseUrl = 'https://api.queryly.com/json.aspx';
        $client  = new Client([
            'handler' => $this->stack(),
        ]);
        $size = 100;

        foreach ($configs as $config) {
            $page = $config->page;

            while (true) {
                $endIndex = $size * $page++;
                $res      = $client->request('GET', $baseUrl, [
                    'query'   => [
                        'queryly_key' => 'a7dbcffb18bb41eb',
                        'query'       => $config->keyword,
                        'endindex'    => $endIndex,
                        'batchsize'   => $size,
                    ],
                    'headers' => [
                        'Accept'          => '*/*',
                        'User-Agent'      => $this->getUserAgent(),
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => $baseUrl,
                        'Host'            => 'api.queryly.com',
                    ],
                    // 'proxy'   => 'socks5h://127.0.0.1:1080',
                    // 'debug'   => true,
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = json_decode($res->getBody()->getContents(), true);

                    foreach ($response['items'] as $list) {
                        $date    = date('Y-m-d', $list['pubdateunix']);
                        $section = explode('/', $list['url'])[3];

                        if ($date > $config->end_date || $date < $config->begin_date || $section == 'videos') {
                            continue;
                        }

                        $info['headline']        = $list['title'];
                        $info['url']             = $list['link'];
                        $info['unique_id']       = $list['_id'];
                        $info['date']            = date('Y-m-d H:i:s', $list['pubdateunix']);
                        $info['section']         = $section;
                        $info['printed_edition'] = 'no';
                        $info['website']         = $this->website;
                        $info['keyword']         = $config->keyword;
                        $info['json_data']       = base64_encode(gzdeflate(json_encode($list)));
                        $data[]                  = $info;
                    }
                    SpiderData::insert($data);

                    if ($response['metadata']['endindex'] >= $response['metadata']['total']) {
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

                $backup = $ql->find('.col-md-8')->html();
                $title  = $ql->find('.node-header h1')->text();
                $author = $ql->find('.field-byline .author-name')->text();
                $texts  = $ql->find('.field-name-body .field-items p')->texts();
                $filter = $ql->find('.col-md-8');
                $filter->find('.token-insert-entity-token .node-article')->remove();
                $images = $filter->find('img')->attrs('src');

                $content = '';
                $content .= $title ? $title . "\r\n\r\n" : '';
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= $images->isEmpty() ? '' : "\r\nimages: " . $images->implode("\r\n");

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);

                Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($backup)));

                if (!empty($contents)) {
                    Storage::disk('local')->put($this->website . '/contents/' . $textId . '.txt', $content);

                    SpiderData::where('id', $list['id'])->update([
                        'has_spider' => SpiderData::YES,
                        'author'     => $author,
                        'section'    => explode('/', $list['url'])[3],
                    ]);
                }
            }
            if (!empty($list['code'])) {
                SpiderData::where('id', $list['id'])->update([
                    'author' => $list['code'],
                ]);
            }
        }
    }
}
