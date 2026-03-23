/*
 **  Topic Model related analysis 
 
 
 
 */
 
 
 
clear 
set more off, permanently 


use "$anaDir/china_news_sample", clear  


global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"



gen beta = .
gen beta_se = . 
gen p = .



 forvalues i =1(1)12  {

* the 75 percentile
egen temp_75 = pctile(topic`i'), p(75)
 
 
 
 qui reghdfe score1new  Tpost $control   if topic`i' >= temp_75 , a($FElevel1) cl(press )
qui estimates store topic_`i'
qui  estadd local Press Yes
qui estadd local Month Yes
qui estadd local Panel Yes


/*
 qui reghdfe score1new  Tpost $control  if topic`i' >= temp_75 , a($FElevel1) cl(press )

local coeff=_b[Tpost]
local b_se = _se[Tpost]
local pval = (2 * ttail(e(df_r), abs(_b[Tpost] / _se[Tpost]) ) )


qui    replace beta=`coeff' in `i'
qui 	replace beta_se = `b_se' in `i'
qui 	replace p = `pval' in `i'
*/

qui drop temp*   
					
}



  esttab topic_1 topic_2 topic_3 topic_4 topic_5  ///
using "$OUT_app/Table_A14.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(Tpost )  b(%20.3f) se(%7.3f) label ///
	stats(Controls Press Month Panel r2 N, fmt( %9.0fc %9.0fc %9.0fc %9.0fc %9.3fc %9.0fc) ///
	labels("Controls" "Press FE" "Month FE" "Panel FE" "R-Squared")) ///
booktabs  page width(\hsize) ///
 title(Table A14: Economic Topics ) ///
 note("Robust std. error, clustered at the press level.") ///
 mtitles("Market" "Trade" "Companies" "US" "COVID Report")


 
 
 esttab topic_6  topic_7 topic_8 topic_9 topic_10 topic_11 topic_12  ///
using "$OUT_app/Table_A15.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(Tpost )  b(%20.3f) se(%7.3f) label ///
	stats(Controls Press Month Panel  r2 N, fmt( %9.0fc %9.0fc %9.0fc %9.0fc %9.3fc %9.0fc) ///
	labels("Controls" "Press FE" "Month FE" "Panel FE"  "R-Squared")) ///
booktabs  page width(\hsize) ///
 title(Table A15: Politically Sensitive Topics) ///
 note("Robust std. error, clustered at the press level.") ///
 mtitles("Human Rights" "NK/TW/Russia" "Social" "HK" "Miscellaneous" "COVID Travel" "COVID Outbreak" )
  
  

 
