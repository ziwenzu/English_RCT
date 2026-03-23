/* 

 ** Reorganize the LDA keyword data and LDA fraction data
 ** Generate newly ordered data sets: 
 *  LDA_keywords_neworder.dta   and  LDA_frac_neworder.dta
 
 */



clear 
set more off, permanently 




**** Import the LDA keyword data and LDA frac data
** label each topic based on its theme
** reorder the topics 

foreach word in "keywords" "frac"{

 import delimited using "$rawDir/LDA_`word'.csv", varnames(1) encoding(utf8) clear 

 import delimited using "$rawDir/LDA_`word'.csv", varnames(1) asfloat clear 

 

** label topics 

label   var  topic1  "COVID/Report"             /* neworder 5 */
label   var  topic2  "Market"             /* neworder 1 */
label   var  topic3  "Miscellaneous"              /* neworder 10 */ 
label   var  topic4 "US Affairs"                   /* neworder 4 */
label   var  topic5 "Social Issues"              /* neworder 8 */
label   var  topic6 "COVID/Travel"                 /* new order 11*/
label   var  topic7  "Human Rights"            /* neworder 6 */
label   var  topic8  "Companies"          /* neworder 3 */  
label   var  topic9    "HK"                  /* neworder 9 */
label   var  topic10   "Trade"          /* neworder 2 */  
label   var  topic11  "COVID/Outbreak"                /* new order 12*/
label   var  topic12  "NK/TW/Russia"           /* neworder 7 */ 


** Reorder the topics so that economics topics are listed before politically sensitive topics
 
clonevar   new_topic1 = topic2
clonevar  new_topic2 = topic10 
clonevar  new_topic3 = topic8
clonevar  new_topic4 = topic4
clonevar  new_topic5 = topic1
clonevar  new_topic6 = topic7  
clonevar  new_topic7 = topic12
clonevar  new_topic8 = topic5
clonevar  new_topic9 = topic9
clonevar  new_topic10 = topic3
clonevar  new_topic11 = topic6
clonevar  new_topic12 = topic11

drop topic*

rename new_topic* topic*

save  "$anaDir/LDA_`word'_neworder.dta", replace

}


