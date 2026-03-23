******* Table 4 : Russia and Iran as additioanl Comparison



	
use "$anaDir/russia_iran_news_sample.dta", clear	
	
append using "$anaDir/china_news_sample" 



** gen dummy for china news sample 
gen Tchina = (news_sample == 1)

** gen interactions 
gen TchinaPost = Tchina*post

gen TTchinaPost = T*Tchina*post

gen TTchina = T*Tchina





** gen country dummies 

gen country = .
replace country = 1 if news_sample == 1
replace country = 2 if russia_news_sample == 1 
replace country = 3 if iran_news_sample == 1 
 
* replace country = 2 if  russia_news_sample == 1 &  iran_news_sample == 1 & keywordrussiaonly > keywordiranonly

** reorganize control variable # of relevant keywords

gen keywordrelevant = keywordfreqchina 
replace keywordrelevant = keywordrussiaonly  if russia_news_sample == 1 
replace keywordrelevant = keywordiranonly if iran_news_sample == 1


gen logkeywordrelevant = log(1+ keywordrelevant)

global  R_control "logkeywordrelevant logwordcount"



***** DID results: russia and iran as control group, only for treatment media

** DID with main effects 
qui  reghdfe score1new   TchinaPost  Tchina post $R_control if  T == 1 , a(newcate) cl(press)

qui  estimates store didmain
qui estadd local Controls Yes
qui estadd local Press No
qui estadd local Month No
qui estadd local Panel Yes
qui estadd local Country No





** DID with fixed effects
qui reghdfe score1new  TchinaPost  $R_control if  T == 1 , a(press country num_yearmonth newcate ) cl(press)
qui estimates store didfixed

qui estadd local Controls Yes
qui estadd local Press  Yes
qui estadd local Month  YEs
qui estadd local Panel  Yes
qui estadd local Country  Yes



****** DDD results 

** 3 countries with main effects 
qui reghdfe score1new Tchina T post TTchinaPost TchinaPost Tpost TTchina   $R_control , a(newcate ) cl(press)

qui estimates store dddmain
qui estadd local Controls Yes
qui estadd local Press No
qui estadd local Month No
qui estadd local Panel Yes
qui estadd local Country No





** 3 countries with fixed effects
reghdfe score1new TTchinaPost TchinaPost Tpost TTchina   $R_control , a(press country num_yearmonth newcate ) cl(press)
estimates store dddfixed

qui estadd local Controls Yes
qui estadd local Press  Yes
qui estadd local Month  Yes
qui estadd local Panel  Yes
qui estadd local Country Yes




*** Generate latex table: Table 4 *****
 
esttab didmain didfixed dddmain dddfixed  ///
using "$OUT_main/table4.tex", ///
replace star( * 0.10 ** 0.05 *** 0.01 ) nogaps compress ///
keep(TTchinaPost TchinaPost  TTchina  Tpost  Tchina T post )  b(%20.3f) se(%7.3f) label ///
stats(Controls Month Press Panel Country r2 N, fmt(%9.0fc  %9.0fc %9.0fc %9.0fc %9.0fc  %9.3f %9.0g "N") /// 
labels(  "R-Squared")) ///
booktabs page width(\hsize) ///
title(Table 4: Russia and Iran as Comparison ) ///
note("Robust std. error, clustered at the press level.") ///
mtitles("didmain" "did fe" "dddmain" "ddd fixed" )

