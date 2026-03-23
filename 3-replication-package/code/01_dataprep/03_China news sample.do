/* 
 * Generate china_news_sample 
 */
 
 
 
use "$anaDir/work_data.dta", clear
 
drop if press == "chinadaily"

keep if news_sample == 1

drop if keywordfreqchina < 3 

joinby full_text_id using  "$anaDir/LDA_frac_neworder.dta", _merge(merge_LDA)


save "$anaDir/china_news_sample", replace 

