
/* 
 * Create Table A4
 */

 
clear 
set more off, permanently 




use "$anaDir/china_news_sample", clear  

  

global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"


global condition_1  "tradewar == 0"
global condition_2  "tiananmen == 0"
global condition_3  "keywordfreqHK == 0 "


forvalues i = 1(1)3 {

 local combined_condition = "condition_" + "`i'"
 
 
qui reghdfe score1new   Tpost  $control if $`combined_condition', a($FElevel1) cluster(press) 
qui estimates store tableA4_`i'

qui estadd local Controls Yes
qui estadd local Press Yes
qui estadd local Month Yes
qui estadd local Panel Yes
}


esttab tableA4_1   tableA4_2  tableA4_3  ///
  using "$OUT_app/Table_A4.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(Tpost )  b(%20.3f) se(%7.3f) label ///
stats(Controls Month Press Panel r2 N, fmt(%9.0fc  %9.0fc %9.0fc %9.0fc  %9.3fc %9.0fc) /// 
labels( "Controls" "Month FE" "Press FE" "Panel FE"  "R-Squared")) ///
booktabs page width(\hsize) ///
title(Table A4 excluding suspected triggers \label{tableA4}) ///
note("Robust std. error, clustered at the press level.") ///
mtitles("Trade war"   "TAM"  "HK"  )



