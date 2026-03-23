 
clear 
set more off, permanently 



 use "$anaDir/china_news_sample", clear  

** Generate week tag
egen press_week_tag = tag(press weeknum)



** Compute the weekly count of China-related articles
egen  count_by_week = sum((score1new~=.)), by(press weeknum)
gen  count_by_week2  =  count_by_week^2 


 forvalues i =1(1)12  {

qui egen temp75 = pctile(topic`i'), p(75)
qui gen  temp1 = (topic`i'>= temp75)
qui egen count_by_topic25_w = sum(temp1), by(press weeknum)

qui reghdfe  count_by_topic25_w Tpost  count_by_week  count_by_week2   if press_week_tag == 1 , a(press weeknum) cluster(press)
 
 estimates store  count_`i'
  qui estadd local Control Yes
 qui estadd local Press Yes
 qui estadd local Week Yes
 
 	
qui drop temp*  count_by_topic* 
				
}



 esttab count_1 count_2 count_3 count_4 count_5  ///
using "$OUT_app/Table_A18.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(Tpost)  b(%20.3f) se(%7.3f) label ///
	stats(Controls Press Week  r2 N, fmt( %9.0fc %9.0fc %9.0fc  %9.3fc %9.0fc) ///
	labels("Controls" "Press FE" "Week FE"  "R-Squared")) ///
booktabs  page width(\hsize) ///
 title(Table A18 ) ///
 note("Robust std. error, clustered at the press level.") ///
 mtitles("Market" "Trade" "Companies" "US" "COVID/Report")

 
 
 esttab count_6  count_7 count_8 count_9 count_10 count_11 count_12  ///
using "$OUT_app/Table_A19.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(Tpost)  b(%20.3f) se(%7.3f) label ///
	stats(Controls Press Week  r2 N, fmt( %9.0fc %9.0fc %9.0fc  %9.3fc %9.0fc) ///
	labels("Controls" "Press FE" "Week FE"  "R-Squared")) ///
booktabs  page width(\hsize) /// 
 title(Table A19 ) ///
 note("Robust std. error, clustered at the press level.") ///
 mtitles("Human Rights" "NK/TW/Russia" "Social" "HK"  ///
 "Miscell." "COVID/Travel" "COVID/Outbreak" )

 
 
 
