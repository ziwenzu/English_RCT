
clear 
set more off, permanently 


cd "$root/code/03_appendix"


 
  //produce  Figures for the appendix
  
  
  do "Figure_A1.do"
	
  do "Figure_A2.do"
* save Figure_A2.pdf
  
  do "Figure_A3.do"
* save Figure_A3a.png and Figure_A3b.png

  do "Figure_A4.do"
* save Figure_A4.pdf and corresponding data for plotting

 
 
 //produce  Tables for the appendix
 
 do "Table_A1.do"
 * Generate Table_A1_part1.xls and  Table_A1_part2.xls; 
 * The two parts are combined to create Table 1

 do "Table_A2.do"

 do "Table_A3.do" 

 do "Table_A4.do" 

 do "Table_A5.do" 

 do "Table_A6.do" 

 do "Table_A7.do" 

 do "Table_A8.do" 
* Generate Table_A8_part1.xls and  Table_A8_part2.xls; 
 * The two parts are combined to create Table 8
 
 
  do "Table_A9.do" 

  do "Table_A10.do" 

  do "Table_A11.do" 
	
  do "Table_A12_A13.do" 

  do "Table_A14_A15.do" 

  do "Table_A16.do"
	
  do "Table_A17.do"
	
  do "Table_A18_A19.do" 

 
