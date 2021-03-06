% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/OrdinaryCalibration.R
\name{FitCalibNpmle}
\alias{FitCalibNpmle}
\title{Fitting Nonparametric Calibration Models}
\usage{
FitCalibNpmle(w, w.res)
}
\arguments{
\item{w}{A matrix of time points when measurements on the binary covariate were obtained.}

\item{w.res}{A matrix of measurement results of the binary covariate. It corresponds to the time points in \code{w}}
}
\value{
The result of NPMLE model fitting for interval-censored data, as obtained by \code{icenReg::ic_np}
}
\description{
Fits a Weibull calibration model for time-to-exposure from interval-censored data. The exposure is a binary covariate measured
in intermittent times.
}
\examples{
# Simulate data set
sim.data <- ICcalib:::SimCoxIntervalCensSingle(n.sample = 200, lambda = 0.1, 
                                               alpha = 0.25, beta0 = log(0.5), 
                                               mu = 0.2, n.points = 2, 
                                               weib.shape = 1, weib.scale = 2)
# Calcualte the NPMLE for a nonparametric calibration model for the covariate 
# starting-time distribution
npmle.fit <- ICcalib::FitCalibNpmle(w = sim.data$w, w.res = sim.data$w.res)
# Plot the estimated survival function
plot(npmle.fit)
}
\seealso{
\code{\link[icenReg]{ic_np}}
}
