<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class CreateSpiderTables extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('configs', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->string('website', 56)->nullable()->comment('搜索网站');
            $table->string('keyword', 16)->nullable()->comment('搜索关键词');
            $table->string('begin_date', 20)->comment('开始时间');
            $table->string('end_date', 20)->comment('结束时间');
            $table->string('other_word', 255)->nullable()->comment('其它辅助搜索词');
            $table->unsignedTinyInteger('had_spider')->default(0)->comment('是否已经爬取');
            $table->unsignedSmallInteger('page')->default(0)->comment('页数');

            $table->timestamp('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));
            $table->timestamp('updated_at')->default(DB::raw('CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP'));
        });

        Schema::create('spider_data', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->string('website', 64)->comment('网站');
            $table->string('headline', 512)->comment('标题');
            $table->dateTimeTz('date')->comment('发布时间');
            $table->string('author', 2048)->nullable()->comment('作者');
            $table->string('printed_edition', '8')->nullable()->default('no')->comment('是否纸质版');
            $table->string('section', 255)->nullable()->comment('分类');
            $table->string('url', 1024)->comment('url');
            $table->string('full_text_id', 16)->nullable()->comment('文本id');
            $table->string('keyword', 20)->comment('关键字');
            $table->string('unique_id', '256')->comment('数据hash值');
            $table->unsignedInteger('order')->default(0)->comment('排序');
            $table->longText('json_data')->nullable()->comment('列表爬取数据');
            $table->unsignedTinyInteger('has_spider')->default(0)->comment('是否已爬取');

            $table->timestamp('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));
            $table->timestamp('updated_at')->default(DB::raw('CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP'));

            $table->index('unique_id');
        });

        Schema::create('temp', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->string('unique_id')->comment('数据hash值');

            $table->index('unique_id');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('configs');
        Schema::dropIfExists('spider_data');
        Schema::dropIfExists('temp');
    }
}
