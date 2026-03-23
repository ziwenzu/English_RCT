
/* EJ replication
 * Tables 3 
 */


clear 
set more off, permanently 


cd "$root/code/02_analysis"

 //produce  Tables for the main text

 
** Table 1 does not contain data  
 
do "Table2.do"

do "Table3.do"

do "Table4.do"


 //produce  Figures for the main text

do "Figure1"
* produce figure1a.pdf , figure1b.pdf 
** and export the corresponding data to the auxillary folder for figure plotting in latex
* the corresponding data for the plot
 

 do "Figure2"
* produce figure2.pdf 
** and export the corresponding data to the auxillary folder for figure plotting in latex
* the corresponding data for the plot

 
 do "Figure3"
* produce figure3a.pdf, figure3b.pdf, 
** and export the corresponding data to the auxillary folder for figure plotting in latex
* the corresponding data for the plot

 
 do "Figure4"
* produce figure4a.pdf and figure4b.pdf,  
** and export the corresponding data to the auxillary folder for figure plotting in latex




***** Topic Model Analysis ***********

** the subfigures in Figure 5 are generated using R code. 
** Please check the R folder for the word cloud figures.


do "Figure6"
** produce figure6.png
** and export the corresponding data to the auxillary folder for figure plotting in latex
* the corresponding data for the plot


do "Figure7"
** For figure 7, we export the .csv file for plotting figure 7 in latex
** and export the corresponding data to the auxillary folder for figure plotting in latex
* the corresponding data for the plot



***** Additional p values for Table 3 ***


// ** Generate WB-based p-values for estimates in Table 3
 ** Note: the running time for this program is 10-20 mins.

do "Table3_WB.do"



// ** Generate RI-based p-values for estimates in Table 3
 ** Note: the running time for this program is roughly 20 mins.

do "Table3_RI.do"


