###
# ps.deriv is an array
# beta - logHR exposure effect
# gamma, a vector. logHRs of Z its length is the same as ncol(Z)
# ps - the usual probabilties matrix
# ps.deriv - array of derivatives of ps with respect to eta. First dim is for eta, second cor case number, third for observation.
# beta, w, wres, event,tm - as ususl
CalcVarParam <- function(theta, eta.g, eta.b, tm, event, Z, Q, ps, ps.deriv, w, w.res, fit.cox)
{
  n <- length(tm)
  n.theta <- length(theta) 
  eta.b <- fit.cox$b
  eta.g <- fit.cox$g
  hessian.eta <- fit.cox$Hessian
  order <- fit.cox$order
  knots <- fit.cox$knots
  n.eta <- length(eta.b) + length(eta.g)
  nabla.eta.Ubeta <- matrix(nr = n.theta, nc = n.eta, 0)
  for (i in 1:n.eta)
  {
    nabla.eta.Ubeta[1,i] <- CalcNablabeetaUbeta(theta = theta, tm = tm, event = event, ps = ps, Q = Q, psDeriv = t(ps.deriv[,i,]) )
    nabla.eta.Ubeta[2:n.theta,i] <- CalcNablabeetaUgamma(theta = theta, tm = tm, event = event, ps = ps, Q = Q, psDeriv = t(ps.deriv[,i,]))
  }
  nabla.eta.Ubeta <- nabla.eta.Ubeta/n
  ### Prep for calculating gradient of eta
  
  lr.for.fit.raw <- as.data.frame(FindIntervalCalibCPP(w = w, wres = w.res))
  Zinter <- Z[!(lr.for.fit.raw[,1]==0 & lr.for.fit.raw[,2]==Inf),]
  lr.for.fit <- lr.for.fit.raw[!(lr.for.fit.raw[,1]==0 & lr.for.fit.raw[,2]==Inf),]
  d1 <- lr.for.fit[,1]==0
  d3 <- lr.for.fit[,2]==Inf
  d2 <- 1 - d1 - d3
  
  ######
  grad.eta.pers.mat <- matrix(nr = n, nc = n.eta,0)
  grad.eta.pers.mat[!(lr.for.fit.raw[,1]==0 & lr.for.fit.raw[,2]==Inf),] <- CalcGradEtaPers(d1 = d1, d2 = d2, d3 = d3, Li = lr.for.fit[,1],
                                       Ri = lr.for.fit[,2], knots = knots, order = order, eta.g = eta.g, eta.b = eta.b, Z = Zinter)
  
  b.mat <- CalcbQ(theta = theta, tm = tm, event = event, ps = ps, Q = Q)
  r.mat <- b.mat - t(nabla.eta.Ubeta%*%ginv(hessian.eta)%*%t(grad.eta.pers.mat))
  MM <- array(dim = c(ncol(r.mat),ncol(r.mat),nrow(r.mat)),0)
  for (j in 1:nrow(r.mat))
  {
    MM[,,j] <- r.mat[j,]%*%t(r.mat[j,])
  } 
  meat <- apply(MM,c(1,2),mean)
  bread <- solve(CoxLogLikHess(theta = theta, tm = tm, event = event, ps = ps, Q = Q))
  v.hat <- n*bread%*%meat%*%bread
  if(max(v.hat)>1) {
    for (j in 1:nrow(b.mat))
    {
      MM[,,j] <- b.mat[j,]%*%t(b.mat[j,])
    } 
  }
  meat <- apply(MM,c(1,2),mean)
  v.hat <- n*bread%*%meat%*%bread
  return(v.hat)
}
CalcVarThetaWeib <- function(beta, etas, tm, event, ps, ps.deriv.shape, ps.deriv.scale, w, w.res)
{
  n <- length(tm)
  b.vec <- Calcb(beta = beta, tm = tm, event = event, ps = ps)
  nabla.eta.shape.Ubeta <- CalcUbetabeeta(beta = beta, tm = tm, event = event, ps = ps, psDeriv = ps.deriv.shape)
  nabla.eta.scale.Ubeta <- CalcUbetabeeta(beta = beta, tm = tm, event = event, ps = ps, psDeriv = ps.deriv.scale)
  nabla.eta.Ubeta <- c(nabla.eta.shape.Ubeta, nabla.eta.scale.Ubeta)/n
  hess.etas.l.v <- (hessian(func = ICweibLik, x = etas, w = w, w.res = w.res))
  grad.eta.pers <- ICweibGrad(etas = etas, w = w, w.res = w.res)
  r.vec <- b.vec - nabla.eta.Ubeta%*%solve(hess.etas.l.v)%*%t(grad.eta.pers)
  meat <- mean(r.vec^2)  # since beta is one-dimensional here 
  bread <- myFmyHess(beta, tm, event, ps)/n
  var.beta <- (meat/(bread^2))/n
  return(var.beta)
}

CalcVarThetaWeibRS <- function(beta, etas.matrix, tm, event, ps.rs, ps.deriv.shape.rs, ps.deriv.scale.rs, w, w.res)
{
  n <- length(tm)
  b.vec <- Calcb(beta = beta, tm = tm, event = event, ps = ps.rs)
  nabla.etas.shape.Ubeta <- CalcUbetabeetaRS(beta = beta, tm = tm, event = event, ps = ps.rs, psDeriv = ps.deriv.shape.rs)
  nabla.etas.scale.Ubeta <- CalcUbetabeetaRS(beta = beta, tm = tm, event = event, ps = ps.rs, psDeriv = ps.deriv.scale.rs)
  nabla.etas.Ubeta <- c(rbind(nabla.etas.shape.Ubeta, nabla.etas.scale.Ubeta))/n

  hess.eta.inv <- ICweibHessSolvedRS(etas.matrix = etas.matrix, w = w, w.res = w.res, tm = tm, event = event)
  grad.eta.pers <- ICweibGradRS(etas = etas.matrix, w = w, w.res = w.res,  tm = tm, event = event)
   r.vec <- b.vec - nabla.etas.Ubeta%*%hess.eta.inv%*%t(grad.eta.pers)
  meat <- mean(r.vec^2)  # since beta is one-dimensional here 
  bread <- myFmyHess(beta, tm, event, ps.rs)/n
  var.beta <- (meat/(bread^2))/n
  return(var.beta)
}
CalcVarEta <- function(etas,  w, w.res)
{
  n <- nrow(w)
  hess.etas.l.v <- (hessian(func = ICweibLik, x = etas, w = w, w.res = w.res))
  grad.eta.pers <- ICweibGrad(etas = etas, w = w, w.res = w.res)
  grad.eta <- 0
  for (j in 1:nrow(grad.eta.pers))
  {
    grad.eta <- grad.eta + grad.eta.pers[j,]%*%t(grad.eta.pers[j,])
  }    
  var.eta <-  solve(hess.etas.l.v)%*%(grad.eta)%*%solve(hess.etas.l.v)
    return(var.eta)
}
CalcVarNpmle <- function(tm, event, w, w.res, BS = 100, CI = T)
{
  n <- length(tm)
  beta.np.calib.bs <- vector(length = BS)
  for (j in 1:BS)
  {
  #  cat("j = ", j)
    indices <- sample.int(n = n, size = n, replace = T)
    tm.bs <- tm[indices]
    event.bs <- event[indices]
    case.times.bs <- tm.bs[event.bs==1]
    w.bs <- w[indices,]
    w.res.bs <- w.res[indices,]
    fit.npmle.bs <- FitCalibNpmle(w = w.bs, w.res = w.res.bs)
    px.np.bs <- t(sapply(case.times.bs, CalcNpmleCalibP, w = w.bs, w.res =  w.res.bs, fit.npmle = fit.npmle.bs))
    beta.np.calib.bs[j] <- optimize(f = myF,  tm = tm.bs, event = event.bs, ps = px.np.bs, 
                             interval = c(-50,50), maximum = T)$maximum
  }
  v.hat.npmle <- var(beta.np.calib.bs[beta.np.calib.bs< 5])
  if (CI ==T)
  {
    ci.l <- quantile(x = beta.np.calib.bs[beta.np.calib.bs< 5], probs = 0.025)
    ci.h <- quantile(x = beta.np.calib.bs[beta.np.calib.bs< 5], probs = 0.975)
    return(list(v = v.hat.npmle, ci = c(ci.l, ci.h)))
  } else{
    return(list(v = v.hat.npmle))
}}
CalcVarNpmleRS <- function(tm, event, w, w.res, BS = 100, CI =T)
{
  n <- length(tm)
  beta.np.calib.rs.bs <- vector(length = BS)
  for (j in 1:BS)
  {
    #  cat("j = ", j)
    indices <- sample.int(n = n, size = n, replace = T)
    tm.bs <- tm[indices]
    event.bs <- event[indices]
    case.times.bs <- tm.bs[event.bs==1]
    w.bs <- w[indices,]
    w.res.bs <- w.res[indices,]
    px.np.rs.bs <- t(sapply(case.times.bs, CalcNpmleRiskSetP, w = w.bs, w.res =  w.res.bs, obs.tm = tm.bs))
    beta.np.calib.rs.bs[j] <- optimize(f = myF,  tm = tm.bs, event = event.bs, ps = px.np.rs.bs, 
                                    interval = c(-50,50), maximum = T)$maximum
  }
  v.hat.npmle.rs <- var(beta.np.calib.rs.bs[beta.np.calib.rs.bs< 5])
  if (CI ==T)
  {
    ci.l <- quantile(x = beta.np.calib.rs.bs[beta.np.calib.rs.bs< 5], probs = 0.025)
    ci.h <- quantile(x = beta.np.calib.rs.bs[beta.np.calib.rs.bs< 5], probs = 0.975)
    return(list(v = v.hat.npmle.rs, ci = c(ci.l, ci.h)))
  } else{
    return(list(v = v.hat.npmle.rs))
}}

CalcVarThetaCox <- function(beta, etas, tm, event, ps, ps.deriv.shape, ps.deriv.scale, w, w.res)
{
  n <- length(tm)
  b.vec <- Calcb(beta = beta, tm = tm, event = event, ps = ps)
  nabla.eta.shape.Ubeta <- CalcUbetabeeta(beta = beta, tm = tm, event = event, ps = ps, psDeriv = ps.deriv.shape)
  nabla.eta.scale.Ubeta <- CalcUbetabeeta(beta = beta, tm = tm, event = event, ps = ps, psDeriv = ps.deriv.scale)
  nabla.eta.Ubeta <- c(nabla.eta.shape.Ubeta, nabla.eta.scale.Ubeta)/n
  hess.etas.l.v <- (hessian(func = ICweibLik, x = etas, w = w, w.res = w.res))
  grad.eta.pers <- ICweibGrad(etas = etas, w = w, w.res = w.res)
  r.vec <- b.vec - nabla.eta.Ubeta%*%solve(hess.etas.l.v)%*%t(grad.eta.pers)
  meat <- mean(r.vec^2)  # since beta is one-dimensional here 
  bread <- myFmyHess(beta, tm, event, ps)/n
  var.beta <- (meat/(bread^2))/n
  return(var.beta)
}

CalcVarThetaCoxRS <- function(beta, etas.matrix, tm, event, ps.rs, ps.deriv.shape.rs, ps.deriv.scale.rs, w, w.res)
{
  n <- length(tm)
  b.vec <- Calcb(beta = beta, tm = tm, event = event, ps = ps.rs)
  nabla.etas.shape.Ubeta <- CalcUbetabeetaRS(beta = beta, tm = tm, event = event, ps = ps.rs, psDeriv = ps.deriv.shape.rs)
  nabla.etas.scale.Ubeta <- CalcUbetabeetaRS(beta = beta, tm = tm, event = event, ps = ps.rs, psDeriv = ps.deriv.scale.rs)
  nabla.etas.Ubeta <- c(rbind(nabla.etas.shape.Ubeta, nabla.etas.scale.Ubeta))/n
  
  hess.eta.inv <- ICweibHessSolvedRS(etas.matrix = etas.matrix, w = w, w.res = w.res, tm = tm, event = event)
  grad.eta.pers <- ICweibGradRS(etas = etas.matrix, w = w, w.res = w.res,  tm = tm, event = event)
  r.vec <- b.vec - nabla.etas.Ubeta%*%hess.eta.inv%*%t(grad.eta.pers)
  meat <- mean(r.vec^2)  # since beta is one-dimensional here 
  bread <- myFmyHess(beta, tm, event, ps.rs)/n
  var.beta <- (meat/(bread^2))/n
  return(var.beta)
}