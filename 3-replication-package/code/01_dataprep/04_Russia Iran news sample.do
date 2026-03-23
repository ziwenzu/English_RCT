/* 
 * Generate russia_iran_news_sample 
 */
 
 
 
use "$rawDir/russia_iran_data.dta", clear
 
 
** Generate key variables **



egen keywordrussiairan = rowtotal(russia russian  iran  iranian) 

egen keywordrussiaonly = rowtotal(russia russian)

egen keywordiranonly = rowtotal(iran iranian)


gen news_general = ( newcate=="World" | newcate=="Business" ///
              | newcate=="Politics" | newcate == "Asia" | newcate =="Energy" ///
			  | newcate == "Health" | newcate=="News"  | newcate=="Technology"    ///
			  | newcate=="Finance" | newcate== "Education" | newcate ==  "Science") 

			  

gen russia_news_sample = (keywordrussiaonly >= 3) & (news_general ==1) 
gen iran_news_sample = (keywordiranonly >= 3) & (news_general ==1) 



** Mark 6 Treatment media and Post period 

gen T = ( press=="BN" | press=="HP" | press=="washington-post" | press == "daily-mail" | press=="guardian" | press == "nbc-news")  
gen post = (num_yearmonth >= 201906)
gen Tpost = T*post
  
gen logwordcount = log(1+ wordcount1new)  

** Only keep data used in analysis later
keep if russia_news_sample == 1 | iran_news_sample == 1 

 
save "$anaDir/russia_iran_news_sample", replace 

