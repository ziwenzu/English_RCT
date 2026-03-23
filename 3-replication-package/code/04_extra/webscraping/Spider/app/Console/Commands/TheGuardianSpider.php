<?php

namespace App\Console\Commands;

use App\Config;
use App\SpiderData;
use GuzzleHttp\Client;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use Box\Spout\Writer\Common\Creator\WriterEntityFactory;

class TheGuardianSpider extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'the-guardian-spider {--step= : 运行步骤}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';
    protected $website     = 'guardian';
    protected $limit       = 100;

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
            case 'order':
                $this->orderData();
                break;
            case 'repeat':
                $this->dealRepeat();
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
                'page'       => 1,
            ];
        }
        Config::insert($data);
    }

    protected function spiderList()
    {
        // https://open-platform.theguardian.com/access/
        $configs = Config::where('website', $this->website)->where('had_spider', Config::NO)->get();

        $baseUrl = 'https://content.guardianapis.com/search';
        $client  = new Client();

        foreach ($configs as $config) {
            $page = $config->page;

            while (true) {
                $res = $client->request('GET', $baseUrl, [
                    'query'   => [
                        'from-date'     => $config->begin_date,
                        'to-date'       => $config->end_date,
                        'order-by'      => 'newest',
                        'use-date'      => 'published',
                        'show-elements' => 'image',
                        'show-fields'   => 'byline,thumbnail,shortUrl,bodyText,newspaperPageNumber',
                        'page'          => $page,
                        'page-size'     => 50,
                        'q'             => $config->keyword,
                        'api-key'       => 'fa4fdf17-3cb8-4429-8eec-38232e33c445',
                    ],
                    'headers' => [
                        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                        'User-Agent'      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36',
                        'Accept-Encoding' => 'gzip, deflate, br',
                        'Referer'         => $baseUrl,
                    ],
                    'proxy'   => 'socks5h://127.0.0.1:1080',
                    // 'debug'   => true,
                    'timeout' => 60,
                ]);

                $data = [];
                if ($res->getStatusCode() == 200) {

                    $response = json_decode($res->getBody()->getContents(), true);

                    foreach ($response['response']['results'] as $list) {

                        if (empty($list['fields']['bodyText'])) {
                            continue;
                        }

                        $info['headline']        = $list['webTitle'];
                        $info['author']          = $list['fields']['byline'] ?? '';
                        $info['url']             = $list['webUrl'];
                        $info['unique_id']       = md5($info['url']);
                        $info['date']            = date('Y-m-d H:i:s', strtotime($list['webPublicationDate']));
                        $info['printed_edition'] = isset($list['fields']['newspaperPageNumber']) ? 'yes' : 'no';
                        $info['section']         = $list['sectionName'];
                        $info['keyword']         = $config->keyword;
                        $info['website']         = $this->website;
                        $info['has_spider']      = SpiderData::YES;

                        $content = '';
                        $content .= $info['headline'] . "\r\n\r\n";
                        $content .= html_entity_decode($list['fields']['bodyText']) . "\r\n\r\n";

                        isset($list['fields']['thumbnail']) && $content .= 'images: ' . $list['fields']['thumbnail'];
                        // 去掉文章内容，避免表数据过大
                        unset($list['fields']['bodyText']);
                        $info['json_data'] = base64_encode(gzdeflate(json_encode($list)));

                        Storage::disk('local')->put($this->website . '/contents/' . $info['unique_id'] . '.txt', $content);

                        $data[] = $info;
                    }

                    SpiderData::insert($data);

                    if ($page >= $response['response']['pages']) {
                        $config->had_spider = Config::YES;
                        $config->save();
                        break;
                    }

                    $config->page = $page++;
                    $config->save();
                    $this->info($page);
                    // sleep(3);
                }
            }
        }
    }

    protected function orderData()
    {
        $baseQuery = SpiderData::select('id', 'headline', 'date', 'author', 'printed_edition', 'section', 'url', 'full_text_id', 'has_spider', 'order', 'unique_id')
            ->where('has_spider', SpiderData::YES)
            ->where('website', $this->website);

        $writer = WriterEntityFactory::createXLSXWriter();
        $path   = storage_path() . "/app/{$this->website}/{$this->website}.xlsx";
        $writer->openToFile($path);
        $row = WriterEntityFactory::createRowFromArray([
            'headline',
            'date',
            'author',
            'printed_edition',
            'section',
            'full_text_id',
            'url',
        ]);
        $writer->addRow($row);

        $disk   = Storage::disk('local');
        $order  = 1;
        $offset = 0;

        while (true) {
            $query  = clone $baseQuery;
            $models = $query
                ->orderBy('date', 'desc')
                ->skip($offset)
                ->limit($this->limit)
                ->get();

            if ($models->isEmpty()) {
                break;
            }

            foreach ($models as $model) {

                if ($model->full_text_id == 404) {
                    continue;
                }
                $textId  = 'TG' . str_pad($order++, 6, 0, STR_PAD_LEFT);
                $newFile = $this->website . '/content/' . $textId . '.txt';
                $oldFile = $this->website . '/contents/' . $model->unique_id . '.txt';
                if (!$disk->exists($oldFile)) {
                    continue;
                }
                $disk->copy($oldFile, $newFile);

                $model->fill([
                    'full_text_id' => $textId,
                    'order'        => $order,
                ])->save();

                $data = [
                    'headline'        => $model['headline'],
                    'date'            => $model['date'],
                    'author'          => $model['author'] ?: '',
                    'printed_edition' => $model['printed_edition'],
                    'section'         => $model['section'],
                    'full_text_id'    => $model['full_text_id'],
                    'url'             => $model['url'],
                ];
                $writer->addRow(WriterEntityFactory::createRowFromArray($data));

                $this->info($model->id);
            }

            $offset += $this->limit;
        }
        $writer->close();
    }
}
