/* 
 * Create Table A4
 */

 
clear 
set more off, permanently 




use "$anaDir/work_data", clear  

drop if press == "chinadaily"
keep if news_sample == 1
  

global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"



global spec1 " score_china4  Tpost  $control if keywordfreqchina >= 3 , a($FElevel1) cluster(press) "
global spec2 " score_half_std  Tpost  $control if keywordfreqchina >= 3 , a($FElevel1) cluster(press) "
global spec3 " score1new  Tpost   if keywordfreqchina >= 5 , a($FElevel1) cluster(press) "
global spec4 " score1new  Tpost   if keywordfreqchina >= 1 , a($FElevel1) cluster(press) "





forvalues i = 1/4 {
 qui   local spec = "spec" + "`i'"
 qui   reghdfe  ${`spec'}
 qui	estimates store tableA6_`i'

qui estadd local Controls Yes
qui estadd local Press Yes
qui estadd local Month Yes
qui estadd local Panel Yes
	}



esttab tableA6_1 tableA6_2 tableA6_3  tableA6_4  ///
  using "$OUT_app/Table_A6.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(Tpost)  b(%20.3f) se(%7.3f) label ///
	stats(Controls Press Month Panel r2 N, fmt( %9.0fc %9.0fc %9.0fc %9.0fc %9.3fc %9.0fc) ///
	labels("Controls" "Press FE" "Month FE" "Panel FE" "R-Squared")) ///
booktabs  page width(\hsize) ///
 title(Table A6: Robustness  \label{tableA6}) ///
 note("Robust std. error, clustered at the press level.") ///
 mtitles( "China" "NonNeutral" "keyword $\geq$ 5" "keyword $\geq$ 1" )
	

