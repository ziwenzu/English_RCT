 
/*Create table A16 */ 
 
 
clear 
set more off, permanently 



use "$anaDir/china_news_sample", clear  


global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"



gen topicname = ""
gen topicnum = .

gen topic = ""
gen beta = .
gen beta_se = . 
gen p = .


local j = 1
 forvalues i =1(1)12  {

 * non-COVID issues 
 
 if (`i'~=5 &  `i'~=11 & `i'~=12) {
 
 
* the 75 percentile
egen temp_75 = pctile(topic`i'), p(75)
 


 qui reghdfe score1new  Tpost $control  if topic`i' < temp_75 , a($FElevel1) cl(press )

local coeff=_b[Tpost]
local b_se = _se[Tpost]
local pval = (2 * ttail(e(df_r), abs(_b[Tpost] / _se[Tpost]) ) )


qui    replace beta=`coeff' in `j'
qui 	replace beta_se = `b_se' in `j'
qui 	replace p = `pval' in `j' 
qui     replace topic = "topic`i'" in `j'


qui 	replace topicnum = `i' in `j'
qui    replace topicname = "`i'" in `j'


qui drop temp*   
local ++j

}
					
}

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

** COVID topics **

qui reghdfe score1new  Tpost $control  if num_yearmonth <202001 , a($FElevel1) cl(press )
local coeff=_b[Tpost]
local b_se = _se[Tpost]
local pval = (2 * ttail(e(df_r), abs(_b[Tpost] / _se[Tpost]) ) )


qui    replace beta=`coeff' in 10
qui 	replace beta_se = `b_se' in 10
qui 	replace p = `pval' in 10
qui     replace topic_theme = "COVID" in 10
  
  
  
keep if beta ~=. 
keep   topic_theme beta beta_se p  




gen  coeff = round(beta, 0.001)
gen  se = round(beta_se, 0.001)
gen  p_values = round(p, 0.001) 

drop beta beta_se p 

 dataout, save("$OUT_app/Table_A16.tex")  tex  replace dec(3)




