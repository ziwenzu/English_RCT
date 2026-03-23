from pytrends.request import TrendReq
import pandas as pd
import time

# Initialize pytrends
pytrends = TrendReq(hl='en-US', tz=360)

# Define the keyword and time period
keyword_ls = [
    "Breitbart News",
    "Daily Mail",
    "The Guardian",
    "Huffington Post",
    "NBC News",
    "The Washington Post",
    "The New York Times",
    "The Times",
    "The Wall Street Journal",
    "Financial Times",
    "Independent",
    "The Boston Globe",
    "Chicago Tribune",
    "The Dallas Morning News",
    "Los Angeles Times",
    "Miami Herald",
    "Newsday",
    "New York Post",
    "San Francisco Chronicle",
    "Star Tribune",
    "USA Today",
    "BBC News",
    "Telegraph",
    "Daily Mirror"
]

keyword = 'China'  # Replace with your keyword
timeframe = '2018-01-01 2020-06-01'  # Example time period

df = pd.DataFrame()
for keyword in keyword_ls:
    pytrends.build_payload([keyword], cat=0, timeframe=timeframe, geo='', gprop='')
    df = pytrends.interest_over_time()
    df.reset_index(inplace=True)
    if 'isPartial' in df.columns:
        df = df.drop(columns=['isPartial'])
    else:
        continue

    if keyword == keyword_ls[0]:
        df_t = df
    else:
        df_t = df_t.merge(df, on = 'date', how = 'left')
    print(len(df))
    print(keyword)

    time.sleep(5)


df_t_month = df_t.groupby([df_t.date.dt.year, df_t.date.dt.month]).mean()
df_t_month.to_csv('googleTrends_data_month.csv', index=True)
df_t.to_csv('googleTrends_data_week.csv', index=True)
