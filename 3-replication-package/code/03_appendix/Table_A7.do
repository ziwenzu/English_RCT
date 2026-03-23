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



global spec1 " score1new  Tpost  $control if keywordfreqchina >= 3 &  headline_chinagroup3_otheronly ~=1 , a($FElevel1) cluster(press) "
global spec2 " score1new  Tpost  $control if keywordfreqchina >= 3 | newcate == "China", a($FElevel1) cluster(press) "
global spec3 " score1new  Tpost  $control if keywordfreqchina >= 3 | headline_chinagroup3_chinaonly ==1  , a($FElevel1) cluster(press) "



reghdfe $spec1


forvalues i = 1/3 {
 qui   local spec = "spec" + "`i'"
    reghdfe  ${`spec'}
	estimates store TableA7_`i'

estadd local Controls Yes
estadd local Press Yes
estadd local Month Yes
estadd local Panel Yes

	}



esttab  TableA7_1  TableA7_2  TableA7_3  ///
  using "$OUT_app/Table_A7.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(Tpost)  b(%20.3f) se(%7.3f) label ///
	stats(Controls Press Month Panel r2 N, fmt( %9.0fc %9.0fc %9.0fc %9.0fc %9.3fc %9.0fc) ///
	labels("Controls" "Press FE" "Month FE" "Panel FE" "R-Squared")) ///
booktabs  page width(\hsize) ///
 title(Table A7: Alternative sample construction  \label{tableA7}) ///
 note("Robust std. error, clustered at the press level.") ///
 mtitles(  "China only" "kw3 or china category" "kw3 or china headline")
	
