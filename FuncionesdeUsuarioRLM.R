library(car)
#Funcion colldiag de la libreria perturb actualmente no disponible en cran R
colldiag <- function(mod,scale=TRUE,center=FALSE,add.intercept=TRUE) {
  result <- NULL
  if (center) add.intercept<-FALSE
  if (is.matrix(mod)||is.data.frame(mod)) {
    X<-as.matrix(mod)
    nms<-colnames(mod)
  }
  else if (!is.null(mod$call$formula)) {
    X<-mod$model[,-1] # delete the dependent variable
  }
  X<-na.omit(X) # delete missing cases
  if (add.intercept) {
    X<-cbind(1,X) # add the intercept
    colnames(X)[1]<-"(Intercept)"
  }
  X<-scale(X,scale=scale,center=center)
  
  svdX<-svd(X)
  svdX$d
  condindx<-svdX$d[1]/svdX$d
  
  Phi=svdX$v%*%diag(1/svdX$d)
  Phi<-t(Phi^2)
  pi<-prop.table(Phi,2)
  
  dim(condindx)<-c(length(condindx),1)
  colnames(condindx)<-"Condition.Index"
  rownames(condindx)<-1:nrow(condindx)
  colnames(pi)<-colnames(X)
result=cbind(condindx,pi)
  class(result)<-"colldiag"
  result
}

#FUNCION PARA EXTRAER COEFICIENTES ESTIMADOS SUS IC DEL 95%, VIFs Y COEFICIENTES ESTANDARIZADOS
miscoeficientes=function(modeloreg){
coefi=coef(modeloreg)
datosreg=model.frame(modeloreg)
data=as.data.frame(scale(datosreg))
coef.std=c(0,coef(lm(update(formula(modeloreg),~.+0),data)))
limites=confint(modeloreg,level=0.95)
vifs=c(0,vif(modeloreg))
resul=data.frame(Estimacion=coefi,Limites=limites,Vif=vifs,Coef.Std=coef.std)
cat("Coeficientes estimados, sus I.C, Vifs y Coeficientes estimados estandarizados","\n")
resul
}

#funcion de usuario para multicolinealidad
#Requiere libreria olsrr
multicolin=function(modeloRLM,center=FALSE){
library(olsrr)
data=model.frame(modeloRLM)
if(center==FALSE){
res=data.frame(rbind(c(NA,NA),ols_coll_diag(modeloRLM)$vif_t[,-1]),ols_coll_diag(modeloRLM)$eig_cindex,row.names=names(coef(modeloRLM)))
}
if(center==TRUE){
Ind=colldiag(modeloRLM,center=TRUE)[,1:ncol(data)]
X=model.matrix(modeloRLM)[,-1]
eigenvalue=prcomp(X,center=TRUE,scale=TRUE)$sdev^2
res=data.frame(ols_coll_diag(modeloRLM)$vif_t[,2:3],Eigenvalue=eigenvalue,Ind,row.names=colnames(X))
}
res
}

#Funcion para analisis de puntos outliers, de balanceo y de influencia. Requiere librerias car y olsrr
diag_obs=function(model,plot.add=TRUE){
library(car)
library(olsrr)
data=model$model
win.graph()
infIndexPlot(model,cex.lab=1,cex=1.5,cex.axis=1)
cat("\n")
#cat("Results for Observations Labeled in the Bubble Plot: Studentized Residuals vs. Cook's D")
#cat("\n")
win.graph()
res0=influencePlot(model,xlim=c(0,1),cex.lab=1,ylim=c(min(rstudent(model))-0.2,max(rstudent(model))+0.2),cex.axis=1)
if(is.data.frame(res0)){
cat("Results for Observations Labeled in the Bubble Plot: Studentized Residuals vs. Cook's D")
cat("\n")
print(res0)
}
DFBetas=dfbetas(model)
namesdfbetas=c("dfbeta.0",paste0("dfbeta.",abbreviate(colnames(DFBetas)[-1])))
#Cotas en notas de clase
#Para los leverage (balanceo)
Critleverage=2*mean(hatvalues(model))
#Para la distancia de Cook
CritCook=4/(nrow(data)-length(coef(model)))
#Para los DFbeta
CritDFBetas=2/sqrt(nrow(data))
#Para |DFFIT|
CritDFFIT=2*sqrt(length(coef(model))/nrow(data))
CritRstudent=2
#para |COVRATIO-1|
CritCOVRATIO=3*length(coef(model))/nrow(data)
Cotas=data.frame(dfbeta=CritDFBetas,dffit=CritDFFIT,cov.r=CritCOVRATIO,Cook.d=CritCook,hat=Critleverage,StudRes=CritRstudent)
res1=cbind(abs(DFBetas)[,1L:ncol(DFBetas)]>CritDFBetas,dffit=abs(dffits(model))>CritDFFIT,cov.r=abs(covratio(model)-1)>CritCOVRATIO,cook.d=cooks.distance(model)>CritCook,hat=hatvalues(model)>Critleverage,StudRes=abs(rstudent(model))>CritRstudent)
colnames(res1)[1:ncol(DFBetas)]=namesdfbetas
res2=data.frame(ifelse(abs(DFBetas)[,1L:ncol(DFBetas)]>CritDFBetas,paste0(round(DFBetas,5),"_*"),round(DFBetas,5)),
dffits=ifelse(abs(dffits(model))>CritDFFIT,paste0(round(dffits(model),5),"_*"),round(dffits(model),5)),
cov.r=ifelse(abs(covratio(model)-1)>CritCOVRATIO,paste0(round(covratio(model),5),"_*"),round(covratio(model),5)),
cook.d=ifelse(cooks.distance(model)>CritCook,paste0(round(cooks.distance(model),5),"_*"),round(cooks.distance(model),5)),
hat=ifelse(hatvalues(model)>Critleverage,paste0(round(hatvalues(model),5),"_*"),round(hatvalues(model),5)),
StudRes=ifelse(abs(rstudent(model))>CritRstudent,paste0(round(rstudent(model),5),"_*"),round(rstudent(model),5)))
colnames(res2)=colnames(res1)
test=res2[apply(res1+0,1,sum)>0,]
if(nrow(test)!=0){
cat("\n")
cat("Potentially influential and/or leverage and/or outlier observations of")
cat("\n")
print(model$call)
cat("\n")
cat("Threshold values")
cat("\n")
print(Cotas)
cat("\n")
print(test)
res=test
} 
else if(nrow(test)==0){
print("There are no potentially influential and/or Leverage and/or outlier observations")
res="There are no potentially influential and/or Leverage and/or Outlier observations"
}
if(plot.add==TRUE){
win.graph()
ols_plot_dffits(model)
win.graph()
ols_plot_cooksd_chart(model,type=2)
win.graph()
ols_plot_resid_stand(model)
#win.graph()
ols_plot_dfbetas(model)
}
else if(plot.add==FALSE){
res=res
}
}

#Funcion para tabla ANOVA del MRLM requiere libreria rms
MiAnova=function(model){
library(rsm)
matrixX=data.frame(model.matrix(model)[,-1])
response=model$model[,1]
name_response=names(model$model)[1]
names(matrixX)=paste0("x",1:ncol(matrixX))
nombres=names(matrixX)
data=data.frame(response,matrixX)
names(data)=c(name_response,nombres)
miformula=as.formula(paste(name_response,"~",paste(paste("FO(",paste(nombres,sep="",collapse=","),sep=""),")",sep="")))
tablaAnova=anova(rsm(miformula,data=data))
rownames(tablaAnova)[1]="Model"
print(tablaAnova)
}


#Funcion para tabla ANOVA del modelo con test de carencia de ajuste, requiere libreria rms
anovLOF=function(mod){
library(rsm)
matrixX=data.frame(model.matrix(mod)[,-1])
names(matrixX)=paste0("x",1:ncol(matrixX))
fct=names(matrixX)
response=mod$model[,1]
rsp=names(attr(mod$terms, "dataClasses"))[1]
data=data.frame(response,matrixX)
names(data)=c(rsp,fct)
fml=as.formula(paste(rsp,"~",paste0("FO(",paste(fct,collapse = ","),")")))
tabla=summary(rsm(fml,data=data))$lof
rownames(tabla)[1]="Model"
print(tabla)
}


#Funcion que despliega correlaciones por pares sin repetir casos
correlaciones=function(data){
stopifnot(is.data.frame(data)|is.matrix(data))
if(is.data.frame(data)){
data=data[,sapply(data,is.numeric)]
}
else if(is.matrix(data)){
data=as.data.frame(data)
}
corre=cor(data)
names_var=names(data)
numvar=ncol(data)
resul1=c()
resul2=c()
for(i in 1:(numvar-1)){
for(j in (i+1):numvar){
resul1=append(resul1,paste(names_var[i],names_var[j],sep="-"))
resul2=append(resul2,corre[i,j])
}
}
res=data.frame(variables=resul1,corr=resul2)
res
}

#Funcion de usuario pruebaDW1() para evaluar el test Durbin-Watson para autocorrelacion de orden 1 en un MRLM
pruebaDW1=function(modelo){
dwneg=durbinWatsonTest(modelo,max.lag=1,method="normal",alternative="negative")
dwpos=durbinWatsonTest(modelo,max.lag=1,method="normal",alternative="positive")
res=data.frame(dwneg$r,dwneg$dw,dwpos$p,dwneg$p,row.names="Resultados")
names(res)=c("rho(1) estimado","Estadistico D-W","VP H1: rho(1)>0","VP H1: rho(1)<0")
res
}
