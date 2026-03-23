*** *** Create WBRI p-values for Table 3


clear
set more off, permanently

// --- Setup and Data Loading ---

use "$anaDir/work_data", clear

*** keep only news sample and view samples that contain >= 3 China-related keywords

keep if keywordfreqchina >= 3 & press ~=  "chinadaily"
keep if news_sample == 1 | views_sample == 1 



sort   press   num_yearmonth



gen fakefe = 1

// --- Global Macros Definitions ---
global control "logwordcount logkwchina logtaiwan "

global FElevel "fakefe"
global FElevel1 "newcate "
global FElevel2 "newcate press num_yearmonth"

// Original Specifications (Specs 1-6)
global spec1 " score1new T post Tpost       if news_sample == 1 ,  a($FElevel) cluster(press)  resid "
global spec2 " score1new T post Tpost $control   if news_sample == 1 , a($FElevel1) cluster(press) resid "
global spec3 " score1new Tpost $control   if news_sample == 1 , a($FElevel2) cluster(press) resid "
global spec4 " score1new T post Tpost     if views_sample == 1, a($FElevel) cluster(press) resid "
global spec5 " score1new T post Tpost $control if views_sample == 1 , a($FElevel) cluster(press) resid "
global spec6 " score1new Tpost $control    if views_sample == 1 , a($FElevel2) cluster(press) resid "

// Permutation/Bootstrap Specifications (Specs temp 1-6)
global spectemp1 " Ttemp post Ttemppost     if news_sample == 1, a($FElevel) cluster(press) resid "
global spectemp2 " Ttemp post Ttemppost $control if news_sample == 1 , a($FElevel1) cluster(press) resid "
global spectemp3 " Ttemppost $control      if news_sample == 1 , a($FElevel2) cluster(press) resid "
global spectemp4 " Ttemp post Ttemppost   if views_sample == 1 , a($FElevel) cluster(press) resid "
global spectemp5 " Ttemp post Ttemppost $control if views_sample == 1 , a($FElevel) cluster(press) resid "
global spectemp6 " Ttemppost $control  if views_sample == 1 , a($FElevel2) cluster(press) resid "

// --- Groups and Scalars ---
egen pressgroup = group(press)
egen presstag = tag(press)

scalar B = 29	 /* # iteration for wild bootstrap */
scalar G = 30	 /* # iterations for RI */
scalar S = 6	 /* # specifications for estimation */


local WBcluster "pressgroup"

mat pvals = J(1, S ,.)

// --- Main Loop for Specifications (s) ---
forvalues s = 1/`=scalar(S)' {
 
	local spec = "spec" +"`s'"
	reghdfe $`spec'
	global bhat_`s' = _b[Tpost]

	local t_hat = _b[Tpost]/_se[Tpost]
	local beta = _b[Tpost]
	mat T_hat_`s' = `t_hat'
	mat B_hat_`s' = `beta'
	
	qui predict temp_er_`s', resid 
	qui predict temp_xbr_`s', xb 
	
	qui gen temp_uni_`s' = . 
	qui gen temp_ernew_`s' = . 
	qui gen temp_pos_`s' = . 
	qui gen temp_ywild_`s' = .
	
	/* matrix to store bootstrap statistics */
	mat T_mw_`s' = J(B+1, G ,.)
  *	 mat B_mw_`s' = J(B+1, G,.)
	
			set seed  345

	forvalues r = 1/`=scalar(G)' {	

		qui gen Ttemp = 0
		qui gen rannum = runiform()
		qui replace rannum = . if presstag ==0
		qui egen rankran = rank(rannum)
		qui replace Ttemp = (rankran <= 6)
		
		qui egen TTtemp = sum(Ttemp), by(press)
		
		qui gen Ttemppost = TTtemp*post
		
		drop rannum rankran
		
		local spectemp = "spectemp" + "`s'"
		
		// ** 1. Outer Loop (RI) - Capture Block **
		capture reghdfe score1new ${`spectemp'}
		
		if _rc == 0 {
			// ** Access _b and _se ONLY IF regression succeeded **
			local t_star = _b[Ttemppost]/_se[Ttemppost] 
			
			mat T_mw_`s' [1,`r'] = `t_star'
	
			// --- Inner Loop for Wild Bootstrap (b) ---
			forvalues b = 1/`=scalar(B)' {		
				disp "`spec': r is " `r' " b count " `b'
				
				sort `WBcluster'
				qui by `WBcluster': replace temp_uni_`s' = uniform()	
				
				qui by `WBcluster': replace temp_pos_`s' = temp_uni_`s'[1]<.5	 /*cluster level rademacher indicator*/
				qui replace temp_ernew_`s' = (2*temp_pos_`s'-1)*temp_er_`s'	 /*transformed residuals */
				qui replace temp_ywild_`s' = temp_xbr_`s' + temp_ernew_`s'	
				
				qui replace temp_ywild_`s' = temp_xbr_`s' + temp_ernew_`s'	
					
				// ** 2. Inner Loop (WB) - Capture Block **
			qui	capture reghdfe temp_ywild_`s' ${`spectemp'}
				
				if _rc == 0 {
					/*store the t-stat*/
					// ** Access _b and _se ONLY IF regression succeeded **
					local t_star = _b[Ttemppost]/_se[Ttemppost]
			  *	 	local b_star = _b[Ttemppost]
					
					mat T_mw_`s' [`b'+1,`r'] = `t_star'
			  *	 	mat B_mw_`s' [`b'+1,`r'] = `b_star'
				}
				else {
					// Store missing value if inner regression fails
					mat T_mw_`s' [`b'+1,`r'] = .
					disp as error "Inner WB iteration failed (RC = `_rc'). Skipping."
				} // <<<--- CORRECTION HERE: Closing brace on its own line
			}
			// --- End of Wild Bootstrap Loop (b) ---
		}
		else {
			// Store missing values if outer regression fails
			mat T_mw_`s' [1,`r'] = .
			// Use r(N_row) from J(N_row, N_col, value)
			mat T_mw_`s' [2/`=scalar(B)'+1,`r'] = J(B, 1, .) 
			disp as error "Outer RI iteration failed (RC = `_rc'). Skipping."
		} // <<<--- CORRECTION HERE: Closing brace on its own line
		
		drop Ttemppost Ttemp TTtemp
	}
	// --- End of Randomization Loop (r) ---
	
	
	
	// 1. Convert the matrix to variables in the current dataset.
	// We use names(Tmw_`s') to create valid variable names (e.g., Tmw_11, Tmw_12)
	// and avoid the "invalid syntax" error caused by missing column names.
	svmat T_mw_`s', names(Tmw_`s')
	
	// 2. Save the current dataset (which now includes the matrix data) to a .dta file.
	// The use of `s' ensures a unique file name per specification.
	save "$tempDir/T_mw_spec`s'.dta", replace 			
	

	
	// Clean up temporary variables before the next iteration (if S > 1)
	cap drop temp_er_`s' temp_xbr_`s' temp_uni_`s' temp_ernew_`s' temp_pos_`s' temp_ywild_`s'
	
	
	/*calculate the p-values*/
	
	mat temp_rej_`s' = J(B+1, G ,.)

	qui scalar temp_sum_`s' = 0
	qui scalar countmiss_`s' = 0
	
	forvalues b = 1/`=scalar(B)+1'{
		forvalues r =1/`=scalar(G)'{
			// Check for missing values before comparison
			if ( T_mw_`s'[`b', `r'] != . ){
				if ( abs(T_hat_`s'[1,1]) <= abs(T_mw_`s'[`b', `r']) ){
					mat temp_rej_`s'[`b', `r'] = 1
					scalar temp_sum_`s' = temp_sum_`s'+ 1
				}
				else{
					mat temp_rej_`s'[`b', `r'] = 0	
				}		
			}
			else{
				// Count missing if the value is missing
				scalar countmiss_`s' = countmiss_`s' + 1
			}
		}
	}
	
	scalar mw_pt_fe_`s' = temp_sum_`s'/(((`=scalar(B)'+1)*`=scalar(G)') - countmiss_`s')
	mat pvals[1,`s'] = mw_pt_fe_`s'
	
	
	
	// --- Cleanup for next specification ---
	cap drop Tmw_`s'* // Drop the variables created from T_mw_`s'
 *	 cap drop Bmw_`s'* // Drop the variables created from B_mw_`s'
}
// --- End of Main Loop (s) ---

matrix list pvals
	
putexcel set "$OUT_main/table3_WB.xlsx", sheet("table3_WB") modify 
putexcel B1 = matrix(pvals)
putexcel A1 = "p"
