#include <Rcpp.h>
using namespace Rcpp;

// This is a simple example of exporting a C++ function to R. You can
// source this function into an R session using the Rcpp::sourceCpp 
// function (or via the Source button on the editor toolbar). Learn
// more about Rcpp at:
//
//   http://www.rcpp.org/
//   http://adv-r.had.co.nz/Rcpp.html
//   http://gallery.rcpp.org/
//
// tm - event time
// event - censoring indicator (1 event 0 no event)
// ps - probabilities
// beta- a value

//data is not assumed to be sorted by time
// [[Rcpp::export]]
double myFmyHess(double beta, NumericVector tm, LogicalVector event, NumericMatrix ps) {
  int n = tm.size();
  double all=0;
  double FirstTerm=0;
  double SecondTerm=0;
  double FirstSumType=0;
  double SecondSumtype=0;
  int iCaseNum=-1;
  NumericMatrix contribPbeta= ps*exp(beta);
//  NumericMatrix contribPbetaMinusP= (1-ps)*ps*exp(beta); Not working!!
  NumericMatrix contribDenom= 1 + ps*(exp(beta)-1);
  for (int i = 0; i < n; ++i)
  {
    if (event[i]) {
      iCaseNum += 1;
      FirstTerm += (1-ps(iCaseNum,i))*contribPbeta(iCaseNum,i)/(contribDenom(iCaseNum,i)*contribDenom(iCaseNum,i));
      FirstSumType = contribPbeta(iCaseNum,i);
      SecondSumtype = contribDenom(iCaseNum,i);
      for(int j = 0; j < n; ++j) {
       if (tm[j]>tm[i]) {
         FirstSumType += contribPbeta(iCaseNum,j);
         SecondSumtype += contribDenom(iCaseNum,j);
        }
        }
     SecondTerm += FirstSumType*(SecondSumtype-FirstSumType)/(SecondSumtype*SecondSumtype);
    }
    }
 all = FirstTerm - SecondTerm; 
  
//NumericVector contrib=ps*exp(beta)+1-ps;
//List aa; aa["logLik"] = logLik;
//  return aa;
    return all;
  }


// You can include R code blocks in C++ files processed with sourceCpp
// (useful for testing and development). The R code will be automatically 
// run after the compilation.
//

// /*** R
// timesTwo(42)
// */
