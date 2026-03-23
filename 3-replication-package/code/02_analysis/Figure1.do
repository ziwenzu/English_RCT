
/* Create Figure 1a and Figure 1b*/
 
clear 
set more off, permanently 



** Create Figure 1a

import delimited "$rawDir/Topic_index.csv"


gen ln1989 = log(s1989)
gen lnTradewar = log(trade_war)
gen lnXinjiang = log(xinjiang)
gen lnHK = log(hk)

sort num_yearmonth
egen monthorder = group(num_yearmonth)

			
	
line ln1989  lnHK lnTradewar lnXinjiang  monthorder , ///
 legend(label(1 "1989")    lab(2 "HK") lab(3 "Trade war") lab(4 "Xinjiang") ) ///
	        ytitle("Logged Baidu Search Index") xtitle("month") xtick(1(1)29) xline(17)
		
	graph save "$tempDir/Figure1a.gph", replace
graph export "$OUT_main/Figure1a.pdf", replace


** Export data for plotting Figure 1a 
export delimited using "$auxDir/Figure1a_data.csv", replace
	

	
	
*** Create Figure 1b	
		
use "$anaDir/china_news_sample", clear  


keep num_yearmonth press  xinjiang uyghur  hongkong hongkonger hongkongese tradewar tiananmen

** Caculate the mentions of some keywords

egen temp_xj =  rsum(xinjiang  uyghur)
egen temp_hk =  rsum(hongkong  hongkonger hongkongese)

egen monthtag = tag(num_yearmonth)
egen sum_xj = sum(temp_xj>0), by(num_yearmonth)
egen sum_hk = sum(temp_hk>0), by(num_yearmonth)
egen sum_tradewar = sum(tradewar>0), by(num_yearmonth)
egen sum_tam = sum(tiananmen>0), by(num_yearmonth)


keep if monthtag == 1 


keep num_yearmonth  sum_xj sum_hk   sum_tradewar sum_tam


gen log_xj = log(1+ sum_xj)
gen log_hk = log(1+ sum_hk)
gen log_tradewar = log(1 + sum_tradewar)
gen log_1989 = log(1+ sum_tam)

sort num_yearmonth
egen monthorder = group(num_yearmonth)
  

line log_1989  log_hk log_tradewar log_xj  monthorder , ///
 legend(label(1 "1989")    lab(2 "HK") lab(3 "Trade war") lab(4 "Xinjiang") ) ///
	        ytitle("Logged mentions") xtitle("month") xtick(1(1)29) ytick(1(1)10) xline(17)
			

graph save "$tempDir/Figure1b.gph", replace
graph export "$OUT_main/Figure1b.pdf", replace

graph close 

** Export data for plotting Figure 1b
export delimited using "$auxDir/Figure1b_data.csv", replace
			
