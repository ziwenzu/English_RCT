
clear 
set more off, permanently 





use "$anaDir/china_news_sample", clear  

  

global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"



gen ln_baidu_all = ln(all_press_baidu + 1)
gen ln_google_all = ln(all_press_google + 1) 

gen postbaidu = post*ln_baidu_all
gen postgoogle = post*ln_google_all




global spec1 " score1new   T post Tpost  ln_baidu_all ln_google_all   $control   , a($FElevel1)   cluster(press)   "
global spec2 " score1new    T post Tpost  ln_baidu_all ln_google_all  postbaidu  postgoogle $control    , a($FElevel1)  cluster(press)  "




qui reghdfe $spec1
qui estimates store tableA11_1

qui estadd local Controls Yes
qui estadd local Press Yes
qui estadd local Month Yes
qui estadd local Panel Yes



reghdfe $spec2
qui estimates store tableA11_2
qui estadd local Controls Yes
qui estadd local Press Yes
qui estadd local Month Yes
qui estadd local Panel Yes




esttab tableA11_1 tableA11_2 ///
  using "$OUT_app/Table_A11.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(Tpost ln_baidu_all ln_google_all postbaidu postgoogle )  b(%20.3f) se(%7.3f) label ///
stats(Controls Month Press Panel r2 N, fmt(%9.0fc  %9.0fc %9.0fc %9.0fc  %9.3fc %9.0fc) /// 
labels( "Controls" "Month FE" "Press FE" "Panel FE"  "R-Squared")) ///
booktabs page width(\hsize) ///
title(Table A11 audience attention\label{tableA11}) ///
note("Robust std. error, clustered at the press level.") ///
mtitles("1"  "2" )



