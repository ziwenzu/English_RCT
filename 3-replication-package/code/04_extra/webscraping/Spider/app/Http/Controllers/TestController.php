<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;

class TestController extends Controller
{
    /**
     * 显示应用程序中所有用户的列表
     *
     * @return Response
     */
    public function index()
    {
        $users = DB::table('baozhatu')
            ->whereIn('id', [1, 2, 3])
            ->get()
            ->pluck('id');
            var_dump($users);
    }
}