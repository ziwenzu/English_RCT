


clear 
set more off, permanently 




use "$anaDir/china_news_sample", clear  



global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"


 

 egen temp5_95 = pctile(topic5), p(95)  /* covid1*/

 egen temp11_95 = pctile(topic11), p(95)  /*covid2*/

 egen temp12_95 = pctile(topic12), p(95)  /*covid3*/

 drop if topic5 >=  temp5_95  |  topic11 >=  temp11_95 | topic12 >=  temp12_95


 


global control "logwordcount logkwchina logtaiwan "


sort num_yearmonth
egen month_index = group(num_yearmonth)

quietly sum month_index if num_yearmonth == 201906
local changetime = r(min)

display "blockage occurred at month" `changetime'       /*  */




gen   changetime =  `changetime'
gen   time_to_treat =  month_index - changetime


* drop if T == 1 

**** redefine the treatment group as the never-bl
gen  treat =  T

replace time_to_treat = 0 if  treat == 0 





summ time_to_treat
g shifted_ttt = time_to_treat - r(min)
summ shifted_ttt if time_to_treat == -1
local true_neg1 = r(mean)


reghdfe score1new ib`true_neg1'.shifted_ttt $control , a(newcate press num_yearmonth) cl(press)


* Pull out the coefficients and SEs
g coef = .
g se = .
levelsof shifted_ttt, l(times)
foreach t in `times' {
	replace coef = _b[`t'.shifted_ttt] if shifted_ttt == `t'
	replace se = _se[`t'.shifted_ttt] if shifted_ttt == `t'
}

* Make confidence intervals
g ci_top = coef+ invnorm(0.975)*se
g ci_bottom = coef - invnorm(0.975)*se


* Limit ourselves to one observation per quarter
* now switch back to time_to_treat to get original timing
keep time_to_treat coef se ci_*
duplicates drop

sort time_to_treat

* Create connected scatterplot of coefficients
* with CIs included with rcap
* and a line at 0 both horizontally and vertically
summ ci_top
local top_range = r(max)
summ ci_bottom
local bottom_range = r(min)


twoway (sc coef time_to_treat, connect(line) mlab("")) ///
	(rcap ci_top ci_bottom time_to_treat)	///
	(function y = 0, range(time_to_treat))  ///
	(function y = 0, range(`bottom_range' `top_range') horiz), ///
	xtitle("Time to Treatment") caption("No COVID") xtick(-1, add) xlabel(-1, add)

		graph save "$tempDir/Figure_A4.gph", replace

	graph export "$OUT_app/Figure_A4.pdf", replace

	graph close 
	
keep coef time_to_treat ci_top ci_bottom
export delimited "$auxDir/Figure_A4.csv", replace

	
