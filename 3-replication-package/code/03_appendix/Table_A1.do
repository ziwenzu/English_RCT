
*****  Create Table A1
  ** Summary statistics for news and views sample: 
  ** Table_A1_part1.xls  and Table_A1_part2.xls



clear 
set more off, permanently 



use "$anaDir/work_data", clear  


drop if press == "chinadaily"
keep if keywordfreqchina >= 3 

keep if news_sample ==1 | views_sample == 1 

egen  pressnum = group(press)

global control "logwordcount logkwchina logtaiwan "
global FElevel1 "newcate press num_yearmonth"



global sumvars "score1new score_china4 score_one_std logwordcount"

	
label var score1new "Default score"
label var score_china4  "China_based score"
label var score_half_std "Score excluding 0.5 std"
label var logwordcount "Logged Wordcount"

 
 
balancetable (mean if T==1) (mean if T==0) (diff T)  $sumvars ///
	   using "$OUT_app/Table_A1_part1.xls" ///
	   if news_sample == 1 ,  ///
       vce(cluster pressnum) replace format(%4.2f) nostars

		
		
balancetable (mean if T==1) (mean if T==0) (diff T)  $sumvars ///
	   using "$OUT_app/Table_A1_part2.xls" ///
	   if views_sample == 1 , ///
       vce(cluster pressnum) replace format(%4.2f) nostars

 
