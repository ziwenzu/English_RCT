/* 
 * Create Figure A2: human validation
 */
 
 
 
 clear 
set more off, permanently 



import delimited "$rawDir/validation/random100.csv", clear 

sort full_text_id

save  "$anaDir/random100.csv", replace


import delimited "$rawDir/validation/validation result 4 rater.csv", clear 

sort full_text_id

joinby full_text_id using "$anaDir/random100.csv", _merge(merge_valid)


egen avg_rating = rowmean(rate1 rate2 rate3 rate4)


twoway (scatter score1new avg_rating) (lfit score1new avg_rating)

graph save "$tempDir/Figure_A2.gph" ,replace
graph export "$OUT_app/Figure_A2.pdf" ,replace

	graph close 

