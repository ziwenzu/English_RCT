

clear 
set more off, permanently 



use "$anaDir/china_news_sample", clear  

  

global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"



drop if T == 1 



gen Tpseudo = (always_block == 0)

gen TpseuPost = Tpseudo*post


global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"



global spec1 " score1new  TpseuPost  $control , a($FElevel1) cluster(press) "
global spec2 " score_china4  TpseuPost  $control  , a($FElevel1) cluster(press) "
global spec3 " score_half_std  TpseuPost  $control  , a($FElevel1) cluster(press) "




reghdfe $spec1


forvalues i = 1/3 {
 qui   local spec = "spec" + "`i'"
    reghdfe  ${`spec'}
	estimates store tableA5_`i'

estadd local Controls Yes
estadd local Press Yes
estadd local Month Yes
estadd local Panel Yes
	}



esttab tableA5_1 tableA5_2 tableA5_3   ///
  using "$OUT_app/Table_A5.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(TpseuPost)  b(%20.3f) se(%7.3f) label ///
	stats(Controls Press Month Panel r2 N, fmt( %9.0fc %9.0fc %9.0fc %9.0fc %9.3fc %9.0fc) ///
	labels("Controls" "Press FE" "Month FE" "Panel FE" "R-Squared")) ///
booktabs  page width(\hsize) ///
 title(Table A5: Placebo \label{tableA5}) ///
 note("Robust std. error, clustered at the press level.") ///
 mtitles("Tone" "China" "NonNeutral"  )
	


