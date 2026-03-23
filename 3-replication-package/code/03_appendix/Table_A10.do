
** Create Table A11

clear 
set more off, permanently 




use "$anaDir/china_news_sample", clear  

  
global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"




gen post_covid = (num_yearmonth > 202001)
gen  post_covid_Chinese = post_covid*ChinesePlatform



global spec1 " score1new  post_covid_Chinese  post_covid ChinesePlatform $control  if num_yearmonth > 201906  , a(newcate) cluster(press)   "
global spec2 " score1new  post_covid_Chinese   $control  if num_yearmonth > 201906  , a($FElevel1) cluster(press)   "


forvalues i = 1(1)2{

reghdfe ${spec`i'}
estimates store covid_`i'

estadd local Controls Yes
estadd local Press Yes
estadd local Month Yes
estadd local Panel Yes
}



********** exporting  baseline 1 NEW VERSION *******************
esttab covid_1 covid_2       ///
  using "$OUT_app/Table_A10.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(post_covid  post_covid_Chinese ChinesePlatform )  b(%20.3f) se(%7.3f) label ///
stats(Controls Month Press Panel r2 N, fmt(%9.0fc  %9.0fc %9.0fc %9.0fc  %9.3fc %9.0fc) /// 
labels( "Controls" "Month FE" "Press FE" "Panel FE"  "R-Squared")) ///
booktabs page width(\hsize) ///
title(Table A10: COVID as a shock\label{baseline}) ///
note("Robust std. error, clustered at the press level.") ///
mtitles(  " main" "FE"   )



