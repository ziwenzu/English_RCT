
/* Main Data Processing
 * Generate variables used in analysis
 * Create sample for analysis
 */


clear 
set more off, permanently 



use "$rawDir/raw_article_data.dta" , clear 
 
 
cls

** Key Variables Construction 

egen  keywordfreqchina = rowtotal(china chinese) 
egen  keywordfreqHK = rowtotal(hongkong hongkonger hongkongese) 
egen  keywordtw = rowtotal(taiwan  taiwanese) 

 
gen  logwordcount = log(1+ wordcount1new)
gen  logkwchina = log(1+ keywordfreqchina)
gen  logtaiwan = log(1+keywordtw)
gen  logHK = log(1+ keywordfreqHK)

** define news sample 
gen news_general = (keywordfreqchina >= 1) & ( newcate=="World" | newcate=="Business" ///
              | newcate=="Politics" | newcate == "Asia" | newcate =="Energy" ///
			  | newcate=="China" | newcate == "Health" | newcate=="News"     ///
			  | newcate=="Technology" | newcate=="Finance" | newcate== "Education") 


gen news_sample = (press ~= "chinadaily") & (news_general ==1) 

** define views sample 
gen views_general =  (keywordfreqchina >= 1) & (newcate == "Opinions") 

gen views_sample =   (press ~= "chinadaily") & (views_general ==1)


** Mark 6 Treatment media and Post period 

gen T = ( press=="BN" | press=="HP" | press=="washington-post" | press == "daily-mail" | press=="guardian" | press == "nbc-news")  
gen post = (num_yearmonth >= 201906)
gen Tpost = T*post


** Mark always blocked media and never blocked media

gen always_block = (press == "NYT" | press == "wsj" | press == "the_times" | press == "financial_times" )

gen never_block = (T== 0 & always_block == 0)

gen blockgroup = (always_block==1)   
replace  blockgroup = 2 if never_block == 1 
** blockgroup: 0 treatment;    1 always_blocked;  2 never blocked


** Mark press outlets with Chinese platform or formal Chinese translation outlets
gen  ChinesePlatform = (press == "NYT" | press == "bbc"  | press == "financial_times"  ///
      | press == "washington-post" | press == "wsj" | press == "guardian" )

	  
	  
** Create Week number 
* Note: 01/01/2018 is Monday.

gen num_date = (num_yearmonth - 200000)*100 + day

sort num_date
egen temp = group(num_date)
* create the order of the dates for calculation

gen  weeknum = floor((temp-1)/7) + 1
drop temp* num_date  


save "$anaDir/work_data.dta", replace 
	
	
	
