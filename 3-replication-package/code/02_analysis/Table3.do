
***** Table 3: baseline ***********


clear 
set more off, permanently 



use "$anaDir/work_data", clear

*** keep only news sample and view samples that contain >= 3 China-related keywords

keep if keywordfreqchina >= 3 & press ~=  "chinadaily"
  

global control "logwordcount logkwchina logtaiwan"


global FElevel1 "newcate press num_yearmonth"



global spec1 " score1new   Tpost T post     if news_sample == 1   ,  cluster(press)  "
global spec2 " score1new   Tpost T post   $control if news_sample  == 1  , a(newcate) cluster(press )  "
global spec3 " score1new   Tpost  $control if news_sample  == 1 , a($FElevel1) cluster(press) "

global spec4 " score1new   Tpost T post    if views_sample == 1   , cluster(press)  "
global spec5 " score1new   Tpost T post   $control if views_sample == 1 ,  cluster(press)  "
global spec6 " score1new   Tpost $control if views_sample == 1 , a(num_yearmonth press) cluster(press)  "



qui reg $spec1
estimates store news_0

qui estadd local Controls No
qui estadd local Press No
qui estadd local Month No
qui estadd local Panel No


qui reghdfe $spec2
estimates store news_m

qui estadd local Controls Yes
qui estadd local Press No
qui estadd local Month No
qui estadd local Panel Yes

qui qui reghdfe $spec3
estimates store news_fe1

qui estadd local Controls Yes
qui estadd local Press Yes
qui estadd local Month Yes
qui estadd local Panel Yes



qui reg $spec4
estimates store views_0

qui estadd local Controls No
qui estadd local Press No
qui estadd local Month No
qui estadd local Panel No



qui reg $spec5
estimates store views_m

qui estadd local Controls Yes
qui estadd local Press No
qui estadd local Month No
qui estadd local Panel No

qui reghdfe $spec6
estimates store views_fe

qui estadd local Controls Yes
qui estadd local Press Yes
qui estadd local Month Yes
qui estadd local Panel No



********** exporting Table 3 *******************

esttab news_0 news_m news_fe1  views_0 views_m views_fe  ///
using "$OUT_main/table3.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(Tpost T post) label  b(%20.3f) se(%7.3f)  ///
stats(Controls Month Press Panel r2 N, fmt(%9.0fc  %9.0fc %9.0fc %9.0fc  %9.3fc %9.0fc) /// 
labels( "Controls" "Month FE" "Press FE" "Panel FE"  "R-Squared")) ///
booktabs page width(\hsize) ///
title(Table 3 Baseline DID\label{baseline}) ///
note("Robust std. error, clustered at the press level.") ///
mtitles("News" "News" "News" "Views" "Views" "Views")


