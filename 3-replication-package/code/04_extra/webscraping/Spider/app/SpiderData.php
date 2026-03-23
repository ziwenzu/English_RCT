<?php

namespace App;

class SpiderData extends Model
{
    protected $fillable = [
        'headline',
        'date',
        'author',
        'printed_edition',
        'section',
        'url',
        'full_text_id',
        'html',
        'json_data',
        'unique_id',
        'has_spider',
        'order',
    ];
}
