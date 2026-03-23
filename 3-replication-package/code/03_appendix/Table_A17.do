



clear 
set more off, permanently 

use "$anaDir/china_news_sample", clear  


keep press full_text_id  num_yearmonth weeknum  topic*   T


gen num = .

egen press_week_tag = tag(press weeknum)


forvalues i = 1(1)12{

egen temp = pctile(topic`i'), p(75)
gen  intopic = (topic`i'>=temp)

egen count_topic`i' = sum(intopic), by(press weeknum)

drop temp intopic
}


keep if press_week_tag == 1 

drop topic* full_text_id


gen T1 = T 
replace T1 = . if T == 0


gen T0 = 1- T 
replace T0 = . if T == 1 

forvalues i = 1(1)12{

egen T_mean`i' = mean(count_topic`i'*T1) 
egen T_sd`i' = sd(count_topic`i'*T1) 

egen C_mean`i' = mean(count_topic`i'*T0) 
egen C_sd`i' = sd(count_topic`i'*T0) 

}

keep T_* C_*  num

keep in 1


reshape long T_mean T_sd C_mean C_sd, i(num)  j(topic)

drop num

rename topic topicnum

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

 

 dataout, save("$OUT_app/Table_A17.tex")  tex   replace  dec(2)

 * dataout, save("$OUT_app/Table_A17.tex")  tex  replace 



