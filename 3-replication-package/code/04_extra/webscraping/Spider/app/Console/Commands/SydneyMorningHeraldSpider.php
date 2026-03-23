<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class SydneyMorningHeraldSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'smh-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'smh';
    protected $prefix  = 'SMH';

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

        $baseUrl = 'https://api.smh.com.au/graphql';
        $host    = 'https://www.smh.com.au';
        $client  = new Client();

        foreach ($configs as $config) {
            $page = $config->page;

            while (true) {
                $variables = sprintf('{"brand":"smh","offset":%d,"query":"%s","pageSize":20}', $page * 20, $config->keyword);

                $res = $client->request('GET', $baseUrl, [
                    'query'   => [
                        'query'     => 'query SearchResultRecencyMoreQuery( $query: String! $brand: String! $offset: Int! $pageSize: Int! ) { assetsConnection: publicSearch(query: $query, brand: $brand, offset: $offset, pageSize: $pageSize) { ...AssetsConnectionFragment_showMoreOffsetData } } fragment AssetsConnectionFragment_showMoreOffsetData on AssetsConnection { assets { ...AssetFragmentFragment_assetDataWithTag id } pageInfo { endOffset hasNextPage } totalCount } fragment AssetFragmentFragment_assetDataWithTag on Asset { ...AssetFragmentFragment_assetData tags { primaryTag { ...AssetFragment_tagFragment } } } fragment AssetFragmentFragment_assetData on Asset { id asset { about byline duration headlines { headline } live totalImages } label urls { canonical { path brand } external } assetType dates { modified published } sponsor { name } } fragment AssetFragment_tagFragment on AssetTagDetails { displayName urls { published { brisbanetimes { path } canberratimes { path } smh { path } theage { path } watoday { path } } } }',
                        'variables' => $variables,
                    ],
                    'headers' => [
                        'Accept'          => 'application/json',
                        'User-Agent'      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36',
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => 'https://www.smh.com.au/search?text=' . $config->keyword,
                        'Origin'          => 'https://www.smh.com.au',
                        'Content-Type'    => 'application/json',
                    ],
                    // 'proxy'   => 'socks5h://127.0.0.1:1080',
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = json_decode($res->getBody()->getContents(), true);

                    foreach ($response['data']['assetsConnection']['assets'] as $list) {

                        $dateline = substr($list['dates']['published'], 0, 19);
                        $date     = new \DateTime($dateline);

                        if ($list['assetType'] == 'video' || $date->format('Y-m-d') > $config->end_date || $date->format('Y-m-d') < $config->begin_date) {
                            continue;
                        }

                        if (empty($list['urls']['external'])) {
                            if (empty($list['urls']['canonical']['path'])) {
                                continue;
                            }
                            $url     = $host . $list['urls']['canonical']['path'];
                            $section = explode('/', $list['urls']['canonical']['path'])[1];
                        } else {
                            $url     = $list['urls']['external'];
                            $section = null;
                        }

                        $info['url']             = $url;
                        $info['unique_id']       = $list['id'];
                        $info['date']            = $date->format('Y-m-d H:i:s');
                        $info['headline']        = $list['asset']['headlines']['headline'];
                        $info['author']          = $list['asset']['byline'];
                        $info['section']         = $section;
                        $info['keyword']         = $config->keyword;
                        $info['printed_edition'] = 'no';
                        $info['json_data']       = base64_encode(gzdeflate(json_encode($list)));
                        $info['website']         = $this->website;

                        $data[] = $info;
                    }
                    SpiderData::insert($data);

                    if ($response['data']['assetsConnection']['pageInfo']['hasNextPage'] === false || $response['data']['assetsConnection']['pageInfo']['endOffset'] == 9999) {
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

                $backup = $ql->find('#content article')->html();
                $title  = $ql->find('#content header h1')->text();

                $filter = $ql->find('#content article ._1665V');
                $filter->find('.ymInT')->remove();
                $filter->find('._3nhoI')->remove();
                $images = $filter->find('img')->attrs('src');
                $filter->find('figure')->remove();
                $texts = $filter->find('p')->texts();

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
                    ]);
                }
            }
        }
    }
}
