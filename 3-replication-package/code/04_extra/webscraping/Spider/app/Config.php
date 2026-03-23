<?php

namespace App;

class Config extends Model
{
    protected $fillable = [
        'keyword',
        'begin_date',
        'end_date',
        'had_spider',
        'page',
        'other_word',
    ];

}
