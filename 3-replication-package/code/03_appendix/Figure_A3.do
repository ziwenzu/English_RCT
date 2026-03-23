


 
clear 
set more off, permanently 



** create Figure A3a

use "$anaDir/china_news_sample", clear  


global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"



sort num_yearmonth
egen month_index = group(num_yearmonth)
egen press_index = group(press)
gen press_month_index = press_index*100+month_index



quietly sum month_index if num_yearmonth == 201906
local changetime = r(min)

display "blockage occurred at month" `changetime'       /*  */

gen   changetime =  `changetime'
gen   time_to_treat =  month_index - changetime
gen   t_treat = month_index - changetime
replace time_to_treat = 0 if  T == 0 

gen  treat = T



summ time_to_treat
g shifted_ttt = time_to_treat - r(min)
summ shifted_ttt if time_to_treat == -1
local true_neg1 = r(mean)


reghdfe score1new  ib`true_neg1'.shifted_ttt $control , a(newcate press num_yearmonth) vce(cluseter press) 
matrix list e(b)


 local plotopts xtitle(M) ytitle(90% Robust CI)
 honestdid, pre(1/16) post(18/28) mvec(0(0.02)0.1) delta(sd) omit coefplot `plotopts' alpha(0.1)



graph save "$tempDir/Figure_A3a.gph", replace
graph export "$OUT_app/Figure_A3a.pdf", replace


graph close 

	
*** Create Figure A3b

use "$anaDir/china_news_sample", clear  

keep if T == 1 | always_block == 1 
 


sort num_yearmonth
egen month_index = group(num_yearmonth)
egen cate_index = group(newcate)
egen press_index = group(press)
gen  press_month_index = press_index*100 + month_index

quietly sum month_index if num_yearmonth == 201906
local changetime = r(min)

di `changetime'

display "blockage occurred at month" `changetime'       /*  */

gen   changetime =  `changetime'
gen   time_to_treat =  month_index - changetime
gen   t_treat = month_index - changetime
replace time_to_treat = 0 if  T == 0 

gen  treat = T



summ time_to_treat
g shifted_ttt = time_to_treat - r(min)
summ shifted_ttt if time_to_treat == -1
local true_neg1 = r(mean)

** sigma not full rank if clustered at higher level
 reghdfe score1new  ib`true_neg1'.shifted_ttt $control , a(newcate press num_yearmonth) cl(press_month_index) 
 
 
 matrix list e(b)

 local plotopts xtitle(M) ytitle(90% Robust CI)
 honestdid, pre(1/16) post(18/28) mvec(0(0.02)0.1) delta(sd) omit coefplot `plotopts' alpha(0.1)



graph save "$tempDir/Figure_A3b.gph", replace
graph export "$OUT_app/Figure_A3b.pdf", replace
	
graph close 

