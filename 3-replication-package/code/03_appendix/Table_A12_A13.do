
/* Create Table A12 and A13*/


clear 
set more off, permanently 


use  "$anaDir/LDA_keywords_neworder.dta", clear



export excel topic1-topic6 using "$OUT_app/Table_A12.xlsx", sheetmodify firstrow(variables) 

export excel topic7-topic12 using "$OUT_app/Table_A13.xlsx", sheetmodify firstrow(variables) 
