
** Create Table A2

clear 
set more off, permanently 



use "$anaDir/work_data", clear  


drop if press == "chinadaily"
keep if keywordfreqchina >= 3 

drop if news_sample ==1 | views_sample == 1 


	
	 drop if newcate =="Othercountry"
	drop if newcate =="Editorial" | newcate =="Science"
	
	
	
global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"


global spec1 " score1new   Tpost  T post      ,  cluster(press)  "
global spec2 " score1new   Tpost  T post   $control   , a(newcate) cluster(press )  "
global spec3 " score1new   Tpost  $control  , a($FElevel1) cluster(press) "



reg $spec1
estimates store news_0

estadd local Controls No
estadd local Press No
estadd local Month No
estadd local Panel No


reghdfe $spec2
estimates store news_m

estadd local Controls Yes
estadd local Press No
estadd local Month No
estadd local Panel Yes

reghdfe $spec3
estimates store news_fe1

estadd local Controls Yes
estadd local Press Yes
estadd local Month Yes
estadd local Panel Yes

********** exporting  Table A2 *******************

esttab news_0 news_m news_fe1   ///
  using "$OUT_app/Table_A2.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(Tpost T post)  b(%20.3f) se(%7.3f) label ///
stats(Controls Month Press Panel r2 N, fmt(%9.0fc  %9.0fc %9.0fc %9.0fc  %9.3fc %9.0fc) /// 
labels( "Controls" "Month FE" "Press FE" "Panel FE"  "R-Squared")) ///
booktabs page width(\hsize) ///
title(Table A2 Placebo entertainment \label{TableA2}) ///
note("Robust std. error, clustered at the press level.") ///
mtitles("main" "main control" "FE")  



