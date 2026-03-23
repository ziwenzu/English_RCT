/* 
 * Create Table A5
 */
 
 
 
	
use "$anaDir/russia_iran_news_sample.dta", clear	
	


global sumvars "score1new wordcount1new keywordrussiaonly keywordiranonly"

* global iransumvars "score1new score_select score_half_std score_one_std score_wikipedia preclean_wordcount keywordfreqiranonly"


label var score1new "Default score"
label var wordcount1new "Wordcount"
label var  keywordrussiaonly "Freq. Russia \& Russian"
label var  keywordiranonly "Freq. Iran \& Iranian"



 
balancetable (mean if T==1) (mean if T==0) (diff T)  $sumvars ///
	   using "$OUT_app/Table_A8_part1.xls" ///
	   if russia_news_sample == 1 ,  ///
       vce(cluster press) replace format(%4.2f) nostars

		
		
balancetable (mean if T==1) (mean if T==0) (diff T)  $sumvars ///
	   using "$OUT_app/Table_A8_part2.xls" ///
	   if iran_news_sample == 1  & russia_news_sample ~=1, ///
       vce(cluster press) replace format(%4.2f) nostars
