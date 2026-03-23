<?php

namespace App\Console\Commands;

use App\Config;
use QL\QueryList;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Storage;

class NytimeSpider extends BaseSpider
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'nytime-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    protected $website = 'nytime';
    protected $prefix  = 'NYT';

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

    // api限制了最大返回的数量，一般来说一个月的间隔可以满足，但是有些月份的数据特别多，需要看情况将时间间隔再分割成15天或者更小的维度
    protected function generateConfig()
    {
        $data   = [];
        $years  = [2016, 2017, 2018, 2019, 2020];
        $months = [
            'january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december',
        ];
        $keywords = [
            'China',
            'Taiwan',
            'Hong Kong',
            'Russia',
            'Russian',
            'Iran',
            'Iranian',
        ];

        foreach ($keywords as $keyword) {
            foreach ($years as $year) {
                foreach ($months as $month) {

                    $beginDate = date('Y-m-d', strtotime('first day of' . $month . ' ' . $year));
                    $endDate   = date('Y-m-d', strtotime('last day of' . $month . ' ' . $year));
                    if ($year == 2020 && $month == 'april') {
                        $endDate = date('Y-m-d', strtotime('first day of may' . $year));
                    }

                    if ($year == 2020 && $month == 'may') {
                        break 3;
                    }

                    $data[] = [
                        'website'    => $this->website,
                        'keyword'    => $keyword,
                        'begin_date' => $beginDate,
                        'end_date'   => $endDate,
                    ];
                }
            }
        }

        Config::insert($data);
    }

    protected function spiderList()
    {
        $client  = new Client();
        $baseUrl = 'https://api.nytimes.com/svc/search/v2/articlesearch.json';
        $key     = 'YozfclgKkvSV7pr3qIhtOq9tyF1LPEqA'; // 可以去nytime申请，一个key容易被限制访问次数

        $configs = Config::where('website', $this->website)->where('had_spider', Config::NO)->get();

        foreach ($configs as $config) {

            if ($config['had_spider'] == Config::NO) {
                $page = $config['page'];

                while (true) {

                    $res = $client->request('GET', $baseUrl, [
                        'query'   => [
                            'begin_date' => $config['begin_date'],
                            'end_date'   => $config['end_date'],
                            'api-key'    => $key,
                            'q'          => $config['keyword'],
                            'page'       => $page,
                        ],
                        // 'proxy'   => 'socks5h://127.0.0.1:1080',
                        'timeout' => 60,
                        'headers' => [
                            'User-Agent'      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36',
                            'Accept-Encoding' => 'gzip, deflate, br',
                            'Host'            => 'api.nytimes.com',
                            'Sec-Fetch-Dest'  => 'empty',
                            'Sec-Fetch-Mode'  => 'cors',
                            'Sec-Fetch-Site'  => 'cross-site',
                            'Content-Type'    => 'application/json;charset=utf-8',
                        ],
                    ]);

                    if ($res->getStatusCode() == 200) {
                        $response = json_decode($res->getBody(), true)['response'];

                        $data = [];
                        foreach ($response['docs'] as $doc) {
                            $printedEdition = isset($doc['print_section']) ? 'yes' : 'no';
                            $section        = $doc['subsection_name'] ?? ($doc['section_name'] ?? '');
                            $date           = new \DateTime($doc['pub_date']);
                            $pubDate        = $date->format('Y-m-d H:i:s');

                            $data[] = [
                                'headline'        => $doc['headline']['main'],
                                'date'            => $pubDate,
                                'author'          => $doc['byline']['original'] ? substr($doc['byline']['original'], 3) : null,
                                'printed_edition' => $printedEdition,
                                'section'         => $section,
                                'url'             => $doc['web_url'],
                                'json_data'       => base64_encode(gzdeflate(json_encode($doc))),
                                'keyword'         => $config['keyword'],
                                'unique_id'       => $doc['_id'],
                                'website'         => $this->website,
                            ];

                        }
                        SpiderData::insert($data);

                        if ($response['meta']['offset'] > $response['meta']['hits']) {
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
    }

    protected function dealCrawlerList($lists)
    {
        foreach ($lists as $list) {
            if (!empty($list['html'])) {
                $rules = [
                    'title'   => ['.css-1vkm6nb>h1', 'text'],
                    'summary' => ['#article-summary', 'text'],
                ];

                $ql        = QueryList::html($list['html']);
                $data      = $ql->rules($rules)->query()->getData();
                $texts     = $ql->find('.meteredContent p')->texts();
                $headerImg = $ql->find('header img')->attrs('src');
                $bodyImgs  = $ql->find('.meteredContent img')->attrs('src');

                $content = '';
                $content .= $data['title'] ? $data['title'] . "\r\n\r\n" : '';
                $content .= $data['summary'] ? 'summary:' . $data['summary'] . "\r\n\r\n" : '';
                $contents = $texts->implode("\r\n");
                $content .= $contents ?? '';
                $content .= $headerImg->isEmpty() ? '' : "\r\nhead_images: " . $headerImg->implode("\r\n");
                $content .= $bodyImgs->isEmpty() ? '' : "\r\nimages: " . $bodyImgs->implode("\r\n");

                $textId = $this->prefix . str_pad($list['id'], 7, 0, STR_PAD_LEFT);

                Storage::disk('local')->put($this->website . '/backup/' . $textId . '.txt', base64_encode(gzdeflate($list['html'])));

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
