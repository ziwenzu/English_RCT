

*** Created in April 2023: adding 4 English media
******* Table A3: basic results

clear 
set more off, permanently 




use "$anaDir/china_news_sample", clear  

  

global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"



egen presstag =tag(press)
egen pressnum = group(press)



gen beta = .
gen beta_se = . 
gen p = .
gen excluding = .
gen excluding_press = ""


*  reghdfe score1new   Tpost   $control if USpressnum ~= 1 , a($FElevel) cluster(press) 



forvalues i =1(1)24  {

qui   reghdfe score1new   Tpost   $control if pressnum ~= `i' , a($FElevel1) cluster(press) 

local coeff=_b[Tpost]
local b_se = _se[Tpost]
local pval = (2 * ttail(e(df_r), abs(_b[Tpost] / _se[Tpost]) ) )

qui levelsof press if pressnum == `i', local(press_name)
    
    //Store the beta values//
qui    replace beta=`coeff' in `i'
qui 	replace beta_se = `b_se' in `i'
qui 	replace p = `pval' in `i'
qui 	replace excluding = `i' in `i'
qui     replace excluding_press = `press_name'  in `i'    
}


keep if beta ~=. 
keep  excluding_press beta beta_se p  


 dataout, save("$OUT_app/Table_A3.tex")  tex  replace



