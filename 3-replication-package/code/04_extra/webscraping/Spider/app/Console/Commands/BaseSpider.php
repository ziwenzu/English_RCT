<?php

namespace App\Console\Commands;

use App\Model;
use App\SpiderData;
use GuzzleHttp\Pool;
use GuzzleHttp\Client;
use GuzzleHttp\Middleware;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Psr7\Request;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use GuzzleHttp\Exception\ClientException;
use Box\Spout\Writer\Common\Creator\WriterEntityFactory;

abstract class BaseSpider extends Command
{
    protected $limit       = 100;
    protected $timeout     = 60;
    protected $concurrency = 100;

    /**
     * Create a new command instance.
     *
     * @return void
     */
    public function __construct()
    {
        parent::__construct();
    }

    protected function stack()
    {
        $stack = HandlerStack::create();
        $stack->push(Middleware::retry(
            function ($retries) {return $retries < 3;},
            function ($retries) {return pow(2, $retries - 1);}
        ));

        return $stack;
    }

    protected function crawler($lists)
    {
        ini_set('memory_limit', '512M');

        $client = new Client([
            // 'debug'       => true,
            'timeout'     => $this->timeout,
            'handler'     => $this->stack(),
            // 'proxy'       => 'socks5h://127.0.0.1:1080',  // 本地搭建sock5用于绕过gwf
            'http_errors' => true,
        ]);

        $pool = new Pool($client, $this->batchRequest($lists), [
            'concurrency' => $this->concurrency,
            'fulfilled'   => function ($response, $index) use (&$lists) {
                $contents = $response->getBody()->getContents();

                $lists[$index]['html'] = $contents;
            },
            'rejected'    => function ($reason, $index) use (&$lists) {
                // this is delivered each failed request
                if ($reason instanceof ClientException) {
                    $statusCode            = $reason->getResponse()->getStatusCode();
                    $lists[$index]['code'] = $statusCode;
                }
            },
        ]);

        $pool->promise()->wait();
        $this->dealCrawlerList($lists);

    }

    protected function batchRequest($urlInfos)
    {
        foreach ($urlInfos as $info) {
            $headers = [
                'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                'Accept-Language' => 'zh-CN,zh;q=0.9',
                'User-Agent'      => $this->getUserAgent(),
                'Accept-Encoding' => 'gzip, deflate, br',
            ];
            yield new Request('GET', $info['url'], $headers);
        }
    }

    protected function getUserAgent()
    {
        $userAgents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.138 Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.102 Safari/537.36 Edge/18.18362',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:68.0) Gecko/20100101 Firefox/68.0',
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36',
            'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36',
            'Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.71 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Safari/537.36',
            'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.83 Safari/537.1',
            'Mozilla/5.0 (Windows NT 5.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36',
            'Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36',
            'Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36',
            'Mozilla/5.0 (X11; OpenBSD i386) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.125 Safari/537.36',
            'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.84 Safari/537.36',
            'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.102 Safari/537.36',
            'Mozilla/5.0 (X11; Linux i686; rv:64.0) Gecko/20100101 Firefox/64.0',
            'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:64.0) Gecko/20100101 Firefox/64.0',
            'Mozilla/5.0 (X11; Linux i586; rv:63.0) Gecko/20100101 Firefox/63.0',
            'Mozilla/5.0 (Windows NT 6.2; WOW64; rv:63.0) Gecko/20100101 Firefox/63.0',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.89 Safari/537.36',
            'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1',
        ];

        return $userAgents[mt_rand(0, count($userAgents) - 1)];
    }

    protected function orderData($table, $keyName = 'id', $where = [], $website, $prefix)
    {
        $baseQuery = app($table)::select('id', 'headline', 'date', 'author', 'printed_edition', 'section', 'url', 'full_text_id', 'has_spider', 'order')
            ->where('has_spider', Model::YES)
            ->where($where);

        $disk = Storage::disk('local');

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

        $order  = 1;
        $offset = 0;

        while (true) {
            $query  = clone $baseQuery;
            $models = $query
                ->orderBy($keyName, 'desc')
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
                $textId  = $prefix . str_pad($order++, 6, 0, STR_PAD_LEFT);
                $oldId   = $prefix . str_pad($model['id'], 7, 0, STR_PAD_LEFT);
                $newFile = $website . '/content/' . $textId . '.txt';
                $oldFile = $website . '/contents/' . $oldId . '.txt';
                if (!$disk->exists($oldFile)) {
                    continue;
                }
                $disk->move($oldFile, $newFile);

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

    protected function spiderHtml($website, $sleep = 1)
    {
        if (empty($website)) {
            return 'required website';
        }

        $baseQuery = SpiderData::select('id', 'url', 'has_spider')
            ->where('website', $website)
            ->where('has_spider', SpiderData::NO);

        $limit  = 100;
        $lastId = 0;

        while (true) {
            $query = clone $baseQuery;

            $models = $query
                ->where('id', '>', $lastId)
                ->orderBy('id', 'asc')
                ->limit($limit)
                ->get();

            if ($models->isEmpty()) {
                break;
            }

            $this->crawler($models->toArray());

            $lastId = $models->last()->id;
            $this->info($lastId);
            sleep($sleep);
        }
    }

    protected function dealRepeat()
    {
        DB::table('temp')->truncate();
        DB::statement('insert into temp select min(id),unique_id from spider_data where website = ? group by unique_id having count(unique_id) > ?', [$this->website, 1]);
        DB::statement('delete from spider_data where website = ? and unique_id in (select unique_id from temp) and id not in (select id from temp)', [$this->website]);

        $this->info('finish');
    }

    abstract protected function dealCrawlerList($lists);
}
