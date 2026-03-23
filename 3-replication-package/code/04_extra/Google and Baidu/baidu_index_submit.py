import requests
import pandas as pd
import time
import random
# ----------------------------- AUTHENTICATION -----------------------------
# Your personal BDUSS cookie (login on https://index.baidu.com/baidu-index-mobile/index.html#/ and access the BDUSS cookie)
cookie = 'BDUSS=FhZVTNxZlJUWmVmbW01U1R0NUk4QklkcnBJd3JUZy0zfndVTTlkMkdrMko1R05vRVFBQUFBJCQAAAAAAAAAAAEAAAAPAm3mzfV6aGFveGlhyrG0-gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIlXPGiJVzxoZ'
CITY_CODE = [0]

KEYWORDS = [
    'Breitbart News', '布赖特巴特新闻',
    'Daily Mail', '每日邮报',
    'The Guardian', '卫报',
    'Huffington Post', '哈芬顿邮报',
    'NBC News', '美国全国广播公司新闻',
    'The Washington Post', '华盛顿邮报',
    'The New York Times', '纽约时报',
    'The Times', '泰晤士报',
    'The Wall Street Journal', '华尔街日报',
    'Financial Times', '金融时报',
    'Independent', '独立报',
    'The Boston Globe', '波士顿环球报',
    'Chicago Tribune', '芝加哥论坛报',
    'The Dallas Morning News', '达拉斯晨报',
    'Los Angeles Times', '洛杉矶时报',
    'Miami Herald', '迈阿密先驱报',
    'Newsday', '新闻日报',
    'New York Post', '纽约邮报',
    'San Francisco Chronicle', '旧金山纪事报',
    'Star Tribune', '明星论坛报',
    'USA Today', '今日美国',
    'BBC News', '英国广播公司',
    'Telegraph', '每日电讯报',
    'Daily Mirror', '镜报'
]


start_date = pd.to_datetime('2018-01-01')
end_date = pd.to_datetime('2020-06-01')


date_ranges = []

# Iterate over the date range in 3-month intervals
while start_date < end_date:
    interval_end = start_date + pd.DateOffset(months=3) - pd.DateOffset(days=1)
    if interval_end >= end_date:
        interval_end = end_date - pd.DateOffset(days=1)
    date_ranges.append((start_date.strftime('%Y-%m-%d'), interval_end.strftime('%Y-%m-%d')))
    start_date = interval_end + pd.DateOffset(days=1)

day_ls = date_ranges

df_t = pd.DataFrame()
df_t_t = pd.DataFrame()

# -------------------------------------------------------------------------
# Main loop: query Baidu Index once per keyword
# -------------------------------------------------------------------------
for date in day_ls:
    df_t = pd.DataFrame()

    for key in KEYWORDS:
        search_param = {
            'area': 0,
            'word': '[[{"name":"'+ key + '","wordType": 1}]]',
            "startDate": date[0],
            "endDate": date[1]
        }

        search_url = 'https://index.baidu.com/api/SearchApi/index?'

        headers = {
            'Accept': 'application/json, text/plain, */*',
            'Accept-Encoding': 'gzip, deflate, br, zstd',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
            'Cipher-Text': '1726830256097_1726915102646_fUOaLwMpaluCOfqFhMAwHRCT/du1p6kj92r6Nd/mWoJMqkrpacVm7p7HTOJhhV5tsnaKlzaHjnS5XGogI3QpjeK2PL4AfmV/NDj0dnyBlErdkV1IrgGtypfO03/X0gZYEWcaD90aQfAwPPlLIEu219gz52sqlBtc822YVREcBjS+mVNlGHVXA5Ltb1ycqBUBdfVP7XKjjQKCdNAlf8pUX3M7dtJJzxejTyZ1Pay+JfHqrsT6Z+EdhQr4cJif2yMbpTI3nj4YSJXNXCfRHx0QplM9gpaiZv0+I4WEnOAKDsEjLrFB+l1e2JoN9qUEZJJkYsyLqrLjtbrXD0PfY+bAuKX+bRVUjxwPNtQ7yG8X69c//lmI87RR7JZWDY2fE9/+4jUQ6lSRJCJau01uf8ciCxh6T4grCYqM+WS7/VjIbJrABHmBoW+L6QdeIqY0HH1v+xap27YTMH0kn9y4ffSN3g==',
            'Connection': 'keep-alive',
            'Cookie': cookie,
            'Host': 'index.baidu.com',
            'Referer': 'https://index.baidu.com/v2/main/index.html',
            'Sec-CH-UA': '"Chromium";v="128", "Not;A=Brand";v="24", "Microsoft Edge";v="128"',
            'Sec-CH-UA-Mobile': '?0',
            'Sec-CH-UA-Platform': '"Windows"',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
            'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36 Edg/127.0.0.0'
        }

        response = requests.get(search_url, params=search_param, headers=headers)
        print(f"keywords: {key}")
        time.sleep(random.uniform(3,10))

        encrypted_data = response.json()['data']

        if (not encrypted_data) or (not encrypted_data.get('userIndexes')):
            print(f"[No data]  {key}  {date} —— skip")
            continue

        uniqid = encrypted_data['uniqid']

        ptbk_url = f'http://index.baidu.com/Interface/ptbk?uniqid={uniqid}'
        ptbk_response = requests.get(ptbk_url, headers=headers)
        ptbk = ptbk_response.json()['data']

        def decrypt(ptbk, encrypted_data):
            if not ptbk:
                return ""
            ptbk_chars = list(ptbk)
            encrypted_chars = list(encrypted_data)
            mapping = {ptbk_chars[i]: ptbk_chars[i + len(ptbk_chars) // 2] for i in range(len(ptbk_chars) // 2)}
            decrypted_chars = [mapping.get(char, char) for char in encrypted_chars]
            return ''.join(decrypted_chars)

        def fill_zero(data):
            return 0 if data == '' else int(data)

        for userIndexes_data in encrypted_data['userIndexes']:
            word = userIndexes_data['word'][0]['name']
            start_date = userIndexes_data['all']['startDate']
            end_date = userIndexes_data['all']['endDate']
            timestamp_list = pd.date_range(start_date, end_date).to_list()
            date_list = [timestamp.strftime('%Y-%m-%d') for timestamp in timestamp_list]

            decrypted_data_all = [fill_zero(data) for data in decrypt(ptbk, userIndexes_data['all']['data']).split(',')]



            max_length = max(len(date_list), len(decrypted_data_all))

            decrypted_data_all.extend([0] * (max_length - len(decrypted_data_all)))

            df = pd.DataFrame({
                'date': date_list,
                word: decrypted_data_all
            })

            if df_t.empty:
                df_t = df.copy()
            else:
                df_t = df_t.merge(df, on = 'date', how = 'left')

    df_t_t = pd.concat([df_t_t, df_t])
    print(date)

df_t_t['date'] = pd.to_datetime(df_t_t['date'])
df_t_t_week = df_t_t.resample('W-Mon', on='date').mean()
df_t_t_month = df_t_t.groupby([df_t_t.date.dt.year, df_t_t.date.dt.month]).mean()
df_t_t.to_csv('baiduIndex_data_day.csv', index=True, encoding = 'utf-8-sig')
df_t_t_week.to_csv('baiduIndex_data_week.csv', index=True, encoding = 'utf-8-sig')
df_t_t_month.to_csv('baiduIndex_data_month.csv', index=True, encoding = 'utf-8-sig')