
*** 
*** Create RI p-values for Table 3


clear 
set more off, permanently 

set seed  34567


	
use "$anaDir/work_data", clear

*** keep only news sample and view samples that contain >= 3 China-related keywords

keep if keywordfreqchina >= 3 & press ~=  "chinadaily"
keep if news_sample == 1 | views_sample == 1 


sort press num_yearmonth  

global control "logwordcount logkwchina logtaiwan"

gen  fakeFE = 1

global FElevel1 "fakeFE"
global FElevel2 "newcate "
global FElevel3 "newcate press num_yearmonth"


global spec1 "  if news_sample == 1 , a($FElevel1) cluster(press)  "
global spec2 " $control if  news_sample == 1 , a($FElevel2) cluster(press) "
global spec3 " $control if  news_sample == 1 , a($FElevel3) cluster(press) "
global spec4 "  if views_sample == 1 , a($FElevel1) cluster(press)  "
global spec5 " $control if  views_sample == 1 , a($FElevel1) cluster(press)  "
global spec6 " $control if  views_sample == 1 , a($FElevel3) cluster(press)  "

 

gen treatment_group = T
sort press 
egen press_id = group(press)
egen presstag = tag(press)


egen treatment_original = total(treatment_group), by(press_id)


capture program drop did_estimate
/* preserve old code
program did_estimate, rclass
    args treatment_var  sample_use  fe_level
    tempname did_temp
	
    qui reghdfe score1new `treatment_var'## post  $control  if `sample_use' & $condition, a(`fe_level')  cl(press)
    scalar `did_temp' = _b[1.`treatment_var'#1.post]
    return scalar did = `did_temp'
end
*/

program did_estimate, rclass
    args treatment_var  cond
    tempname did_temp
	
    qui reghdfe score1new `treatment_var'## post   ${`cond'}
	    scalar `did_temp' = _b[1.`treatment_var'#1.post]
    return scalar did = `did_temp'
end


scalar S = 6

forvalues i = 1/`=scalar(S)'{
	

did_estimate  T   spec`i'
scalar did_original_`i' = r(did)


di did_original_`i'
}



capture program drop permute_group_treatment

program permute_group_treatment


qui gen  rannum = uniform()
qui replace rannum = . if presstag ==0
qui egen rankran = rank(rannum)
qui replace t_temp = (rankran <= 6)
qui egen tt_temp = sum(t_temp), by(press)

replace treatment_temp = tt_temp

drop  rannum rankran tt_temp

end



local num_permutations 500
gen t_temp = .
gen treatment_temp = .
* gen permuted_did = .

 local S `=scalar(S)'
  mat pvals = J(1, `S' ,.)
 
 forvalues s = 1/`=scalar(S)'{
 	gen permuted_did_`s' = .
}
 

forvalues i = 1/`num_permutations' {
    qui permute_group_treatment
	forvalues s = 1/`=scalar(S)' {
    qui did_estimate treatment_temp spec`s'
    qui replace permuted_did_`s' = r(did) in `i'
	}
}




forvalues s = 1/`=scalar(S)'{
local count = 0
forvalues i = 1/`num_permutations' {
    if (permuted_did_`s'[`i'] > did_original_`s') {
        local count = `count' + 1
    }
}

 		mat pvals[1,`s'] = 1 - (`count' / `num_permutations')

}


	

matrix list pvals
*	  matsave pvals_RI, replace saving dropall path("$resultpath/table3/" ) type(type) 

putexcel set "$OUT_main/table3_RI.xlsx", sheet("table3_RI") modify
putexcel B1 = matrix(pvals)
putexcel A1 = "p"

* putexcel save



