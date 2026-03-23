
** Figure 2


 
clear 
set more off, permanently 




use "$anaDir/china_news_sample", clear  




egen temppressmonthtag = tag(press num_yearmonth)
keep if temppressmonthtag == 1 



keep blockgroup press num_yearmonth  all_press_baidu  


egen new_baidu_group = mean(all_press_baidu) , by(blockgroup num_yearmonth)


egen tempgrouptag = tag(blockgroup num_yearmonth)

keep if tempgrouptag == 1 

keep blockgroup new_baidu_group num_yearmonth

reshape wide  new_baidu_group, i(num_yearmonth) j(blockgroup)	


rename new_baidu_group0 Baidu_Treated
rename new_baidu_group1 Baidu_Always_blocked
rename new_baidu_group2 Baidu_Never_blocked


gen log_baidu_treated = log(1+Baidu_Treated)
gen log_baidu_always = log(1+ Baidu_Always_blocked)
gen log_baidu_never = log(1+Baidu_Never_blocked)


egen monthorder = group(num_yearmonth)

gen  monthname = string(num_yearmonth)

labmask monthorder, values(monthname)

	
line log_baidu_treated log_baidu_always log_baidu_never  monthorder, legend(label(1 "Treated")  lab(2 "Always blocked") lab(3 "Never blocked") ) ///
	        ytitle("Log(Baidu Search Index)") xtitle("Media by Group") xtick(1(1)29) xline(18) ytick(4(1)10)  lp("l" "-" "." )

			
** Export Figure 2 
graph save "$tempDir/Figure2.gph" ,replace
graph export "$OUT_main/Figure2.pdf" ,replace

graph close 

** Export data for plotting Figure 2 
export delimited using "$auxDir/Figure2_data.csv", replace

		
