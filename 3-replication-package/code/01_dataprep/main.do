/* 

 * master file for data processing 
 */
 
 
 
clear 
set more off, permanently 


cd "$root/code/01_dataprep"


** Process the original China data to produce the main work data
do "01_main data process.do"

** Process the topic model information 
do "02_LDA data processing.do"


** Combine the above two to generate the China news sample
do "03_China news sample.do"

** Process the original russia-iran data to produce the Russia-Iran news sample
do  "04_Russia Iran news sample.do"

