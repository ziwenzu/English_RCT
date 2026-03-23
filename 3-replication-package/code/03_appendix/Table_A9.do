
** Table A9

clear 
set more off, permanently 





use "$anaDir/china_news_sample", clear  

  

global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"



gen  postChinesePlatform = post*ChinesePlatform
gen  TChinesePlatform = T*ChinesePlatform
gen  TpostChinesePlatform = Tpost*ChinesePlatform


gen ln_baidu_all = ln(all_press_baidu + 1)
gen ln_google_all = ln(all_press_google + 1) 


egen  mean_baidu = mean(ln_baidu_all)
gen highbaidu = (ln_baidu_all > mean_baidu)

gen T_highbaidu = T*highbaidu
gen post_highbaidu = post*highbaidu
gen Tpost_highbaidu = Tpost*highbaidu

	  


global spec1 " score1new   Tpost   TChinesePlatform postChinesePlatform TpostChinesePlatform   $control   , a($FElevel1) cluster(press)   "
global spec2 " score1new    Tpost   T_highbaidu post_highbaidu Tpost_highbaidu   $control   , a($FElevel1)  cluster(press)   "




reghdfe $spec1
estimates store news_1

estadd local Controls Yes
estadd local Press Yes
estadd local Month Yes
estadd local Panel Yes



reghdfe $spec2
estimates store news_2

estadd local Controls Yes
estadd local Press Yes
estadd local Month Yes
estadd local Panel Yes





********** exporting  baseline 1 NEW VERSION *******************
esttab news_1 news_2     ///
  using "$OUT_app/Table_A9.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep( Tpost  postChinesePlatform TpostChinesePlatform  post_highbaidu Tpost_highbaidu )  b(%20.3f) se(%7.3f) label ///
stats(Controls Month Press Panel r2 N, fmt(%9.0fc  %9.0fc %9.0fc %9.0fc  %9.3fc %9.0fc) /// 
labels( "Controls" "Month FE" "Press FE" "Panel FE"  "R-Squared")) ///
booktabs page width(\hsize) ///
title(Table A9: Journalistic resources\label{baseline}) ///
note("Robust std. error, clustered at the press level.") ///
mtitles( "Chinese Platform"  "Chinese Influence" )




