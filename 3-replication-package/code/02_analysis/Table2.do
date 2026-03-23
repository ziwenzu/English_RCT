

clear 
set more off, permanently 


use "$anaDir/work_data", clear

* Restrict to news and views sample with # china-related keywords >=3
drop if press == "chinadaily"
drop if keywordfreqchina <3
keep if news_sample == 1 | views_sample == 1   

 

gen temp1 = (T== 0)
gen temp2 = (T== 1)

gen  total_count = 	_N
egen sub_count_control = sum(temp1), by(newcate)
gen  sub_pct_control =  sub_count_control/total_count

egen sub_count_treat = sum(temp2), by(newcate)
gen  sub_pct_treat =  sub_count_treat/total_count

egen sub_count_total = count(temp1), by(newcate)
gen sub_pct_total = sub_count_total/total_count 

	
collapse (mean) n_control = sub_count_control  (mean) pct_control = sub_pct_control ///
 (mean) n_treat = sub_count_treat (mean) pct_treat = sub_pct_treat (mean) count_total = sub_count_total ///
 (mean) pct_total = sub_pct_total , by(newcate)

gen news = (newcate ~= "Opinions")	



set obs `=_N+2'

replace newcate = "News_subtotal" in 13	

replace newcate = "Total" in 14



foreach var of varlist n_control  pct_control n_treat pct_treat count_total pct_total {
 egen temp1 = sum(`var'*(news==1))
 egen temp2 = sum(`var'*(news~=.))
 
 replace `var' = temp1 in 13
  replace `var' = temp2 in 14
  drop temp*

 }
	
	
	replace news = 0.5 if newcate == "News_subtotal"
	replace news = -1 if newcate == "Total"
	gsort - news newcate
	
	* change unit to percentage 
	
	foreach var of varlist pct_control pct_treat pct_total{
	replace `var' =  round(`var'*100, 0.1)
	format `var' %12.2f
*	gen  str_`var' = "("+string(`var')+"\%)"
	}
	
	
	drop news
	
export excel using "$OUT_main/table2.xlsx", replace

