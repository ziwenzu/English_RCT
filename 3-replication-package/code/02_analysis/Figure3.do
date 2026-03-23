

**** Figure 3a 

use "$anaDir/work_data", clear


** keep only those with china-related keyword >=3
drop if keywordfreqchina < 3 

** keep only news sample for the sample media and China daily
keep if news_general == 1 

collapse (mean) meanscore = score1new  (sd) sdscore = score1new  (count) n= score1new (mean) dark = T, by(press)


gen   hiscore = meanscore + invttail(n-1, 0.025)*(sdscore/ sqrt(n))
gen   loscore = meanscore - invttail(n-1, 0.025)*(sdscore/ sqrt(n))


gsort - meanscore

gen pressnum = _n

label values pressnum press

graph twoway (bar meanscore pressnum) (rcap hiscore loscore pressnum)



graph save "$tempDir/Figure3a.gph", replace
graph export "$OUT_main/Figure3a.pdf", replace

graph close 


save  "$auxDir/Figure3a_data.dta", replace






********* Figure 3b

use "$anaDir/work_data", clear

drop if keywordfreqchina < 3 

** keep only news sample for the sample media and China daily
keep if news_general == 1 


kdensity score1new if news_sample ==1, n(100) kernel(epanechnikov) nograph generate(x sample_news_d)

kdensity score1new if press == "chinadaily" , n(100)  kernel(epanechnikov) nograph generate(x2 china_daily_d)


label var china_daily_d "china_daily_d "
label var sample_news_d "sample_news_d "

twoway(line sample_news_d x) (line china_daily_d x2)

keep x sample_news_d x2 china_daily_d




graph save "$tempDir/Figure3b.gph", replace
graph export "$OUT_main/Figure3b.pdf", replace

graph close 

save  "$auxDir/Figure3b_data.dta", replace

