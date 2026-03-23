clear 
set more off, permanently 



use "$anaDir/china_news_sample", clear  


** Generate week tag
egen press_week_tag = tag(press weeknum)



global control "logwordcount logkwchina logtaiwan "



gen topicname = ""
gen topicnum = .

gen score_beta = .
gen score_beta_se = . 
gen score_p = .
gen score_lr = .
gen score_ur = .

 forvalues i =1(1)12  {


qui egen temp75 = pctile(topic`i'), p(75)

qui reghdfe score1new  Tpost  $control  if topic`i' >= temp75  , a(newcate press num_yearmonth) cluster(press)
est store score_`i'

qui reghdfe score1new  Tpost  $control  if topic`i' >= temp75  , a(newcate press num_yearmonth) cluster(press)
local coeff=_b[Tpost]
local b_se = _se[Tpost]
local pval = (2 * ttail(e(df_r), abs(_b[Tpost] / _se[Tpost]) ) )

local score_lr = _b[Tpost] - invttail(e(df_r),0.025)*_se[Tpost]
local score_ur = _b[Tpost] + invttail(e(df_r),0.025)*_se[Tpost]

	
qui    replace score_beta=`coeff' in `i'
qui 	replace score_beta_se = `b_se' in `i'
qui 	replace score_p = `pval' in `i'
qui     replace score_lr = `score_lr' in `i'
qui     replace score_ur = `score_ur' in `i'


qui 	replace topicnum = `i' in `i'
qui    replace topicname = "`i'" in `i'
 
 	
qui drop temp*  
				
}

keep if  score_beta ~= .
keep topicnum topicname   score_beta score_beta_se score_p 


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

gen dark = (score_p <= 0.1)


** Export .csv file for plotting figure 6 in latex
save  "$auxDir/figure6data.dta", replace

 
* export delimited using "$OUT_main/Figure6.csv", replace


coefplot (score_1, rename(Tpost="c1") ciopts(lcolor(gs13))) ///
         (score_2,rename(Tpost="c2") ciopts(lcolor(gs13))) ///
         (score_3, rename(Tpost="c3") ciopts(lcolor(gs13))) ///
		 (score_4,rename(Tpost="c4") ciopts(lcolor(gs13))) ///
         (score_5, rename(Tpost="c5") ciopts(lcolor(gs13))) ///
		 (score_6,rename(Tpost="c6") ) ///
         (score_7, rename(Tpost="c7") ) ///
		 (score_8,rename(Tpost="c8") ) ///
         (score_9, rename(Tpost="c9") ) ///
		 (score_10,rename(Tpost="c10") ) ///
         (score_11, rename(Tpost="c11") ) ///
		 (score_12,rename(Tpost="c12") ) ///
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
		 
		 

graph save "$tempDir/Figure6.gph", replace
graph export "$OUT_main/Figure6.png", replace
	
* graph close 



