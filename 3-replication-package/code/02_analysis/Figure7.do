clear 
set more off, permanently 


use "$anaDir/china_news_sample", clear  

** Generate week tag
egen press_week_tag = tag(press weeknum)


** Compute the weekly count of China-related articles
egen  count_by_week = sum((score1new~=.)), by(press weeknum)
gen  count_by_week2  =  count_by_week*count_by_week



gen topicname = ""
gen topicnum = .
gen w_beta = .
gen w_beta_se = . 
gen w_p = .
gen w_lr = .
gen w_ur = .


 forvalues i =1(1)12  {


qui egen temp75 = pctile(topic`i'), p(75)

qui egen count_by_topic25_w = sum((topic`i'>=temp75)), by(press weeknum)

qui reghdfe  count_by_topic25_w Tpost  count_by_week  count_by_week2  if press_week_tag == 1 , a(press weeknum) cluster(press)
qui est store  count_`i'


qui reghdfe  count_by_topic25_w Tpost  count_by_week  count_by_week2  if press_week_tag == 1 , a(press weeknum) cluster(press)
 
local coeff=_b[Tpost]
local b_se = _se[Tpost]

local pval = (2 * ttail(e(df_r), abs(_b[Tpost] / _se[Tpost]) ) )

local w_lr = _b[Tpost] - invttail(e(df_r),0.025)*_se[Tpost]
local w_ur = _b[Tpost] + invttail(e(df_r),0.025)*_se[Tpost]



qui 	replace topicnum = `i' in `i'
qui    replace topicname = "`i'" in `i'

qui    replace w_beta=`coeff' in `i'
qui 	replace w_beta_se = `b_se' in `i'
qui 	replace w_p = `pval' in `i'
qui     replace w_lr = `w_lr' in `i'
qui     replace w_ur = `w_ur' in `i'

 
 	
qui drop temp*  count_by_topic* 
				
}

keep if  w_beta ~= .

keep topicnum topicname   w_beta w_beta_se w_p 


gen topic_theme = ""
replace topic_theme = "Market"  if topicnum == 1 
replace topic_theme = "Trade"  if topicnum == 2 
replace topic_theme = "Companies"  if topicnum == 3
replace topic_theme = "US" if topicnum == 4
replace topic_theme = "COVID Report"  if topicnum == 5
replace topic_theme = "Human rights"  if topicnum == 6 
replace topic_theme = "NK/Taiwan/Russia"  if topicnum == 7 
replace topic_theme = "Social"  if topicnum == 8 
replace topic_theme = "HK"  if topicnum == 9
replace topic_theme = "Miscellaneous"  if topicnum == 10 
replace topic_theme = "COVID Travel" if topicnum == 11 
replace topic_theme = "COVID Outbreak"  if topicnum == 12 


drop topicname 

gen dark = (w_p <= 0.1)


** Export data file for plotting figure 7 
 save  "$auxDir/figure7data.dta", replace

 
** Export .csv file for plotting figure 7 
*  export delimited using "$OUT_main/Figure7.csv", replace


** Coefficient Plot


coefplot (count_1, rename(Tpost="c1") ciopts(lcolor(gs13))) ///
         (count_2,rename(Tpost="c2") ciopts(lcolor(gs13))) ///
         (count_3, rename(Tpost="c3") ciopts(lcolor(gs13))) ///
		 (count_4,rename(Tpost="c4") ) ///
         (count_5, rename(Tpost="c5") ciopts(lcolor(gs13))) ///
		 (count_6,rename(Tpost="c6") ) ///
         (count_7, rename(Tpost="c7") ciopts(lcolor(gs13))) ///
		 (count_8,rename(Tpost="c8") ciopts(lcolor(gs13))) ///
         (count_9, rename(Tpost="c9") ) ///
		 (count_10,rename(Tpost="c10") ) ///
         (count_11, rename(Tpost="c11") ciopts(lcolor(gs13))) ///
		 (count_12,rename(Tpost="c12") ciopts(lcolor(gs13))) ///
	  ,  keep(Tpost) ci(95) horizontal recast(connect) ///
	  grid(glpattern(solid) glcolor(white)) ///
            xlabel(, labsize(small)) yline(0, ) ///
			coeflabel(c1="Market" c2="Trade" c3="Companies" c4="US" ///
			   c5="COVID/report" c6="Human Rights" c7="NK/TW/Russia"  ///
			   c8="Social" c9="HK" c10="Misc." c11="Covid/travel" ///
			   c12="Covid/outbreak") ///
		   ciopts(lcolor(black) lpattern(solid)) graphregion(color(white) ) ///  
		    xline(0, lcolor(gray) lpattern(dot) lwidth(medium)) ///
			xtitle(Estimates) ytitle(Topic) ///
			mlabel mlabcolor(black) mlabsize(vsmall) format(%4.3f) mlabposition(12) ///
			 legend(off) mcolor(black) 
		 
		 

graph save "$tempDir/Figure7.gph", replace
graph export "$OUT_main/Figure7.png", replace
	
 graph close 

	
	
