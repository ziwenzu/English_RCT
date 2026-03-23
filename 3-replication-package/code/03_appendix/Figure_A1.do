/* Create Figure A1 */




 import delimited "$rawDir/word_score_dist.csv", clear


 gen bin_width = bins[_n+1] -bins
 replace bin_width = bin_width[_N-1] if _n == _N 
 
 gen lower_limit = midpoints - (bin_width / 2)
 gen upper_limit = midpoints + (bin_width / 2)
 
 local bin_width = bin_width[_N]
 
 twoway bar frequency lower_limit, ///
      barwidth(`bin_width') base(0) bstyle(histogram) vertical 
 
 
 graph save "$tempDir/Figure_A1.gph", replace
  graph export "$OUT_app/Figure_A1.pdf", replace
  
 graph close
