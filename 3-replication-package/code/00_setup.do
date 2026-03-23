
clear

set more off

// The following are user-written packages and are not included in Stata by default.
// These packages need to be installed manually by running the command below:
// If you have already installed these packages, please comment out the following seven lines
ssc install estout
ssc install coefplot
ssc install outreg2 
ssc install dataout 
ssc install balancetable
ssc install honestdid
ssc install ftools
ssc install labutil
ssc install reghdfe


// set the directories
// the replicators need to reset the root directory 

global  root  "/Users/lihan/Documents/work/Research/media/EJ replication/Media Replication Package/3-replication-package"
 
global  rawDir "$root/data/source data"

global tempDir "$root/data/temp data"

global anaDir  "$root/data/analysis data" 

global  OUT_main "$root/OUTPUT/main"

global  OUT_app "$root/OUTPUT/appendix"

global  auxDir "$root/OUTPUT/auxiliary"



