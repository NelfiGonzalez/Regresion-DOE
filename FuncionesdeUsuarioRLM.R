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
#Version mejorada de "miscoeficientes()" no necesita ingresar el data.frame con datos de la regresion
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
#Version mejorada de "multicolin()", no necesita ingresar el data.frame con datos de la regresion. Requiere libreria olsrr
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

#Funcion para analisis de puntos outliers, de balanceo y de influencia. Requiere libreria car
diaganalysis=function(modelo){
cat("Resultados de la Funcion influence.measures")
cat("\n")
res1=summary(influence.measures(modelo))
win.graph()
infIndexPlot(modelo,cex.lab=1.5,cex=1.5,cex.axis=1.5)
win.graph()
cat("\n")
cat("Resultados adicionales para figura de burbujas")
cat("\n")
res2=influencePlot(modelo,xlim=c(0,1),cex.lab=1.5,ylim=c(min(rstudent(modelo))-0.2,max(rstudent(modelo))+0.2),cex.axis=2)
print(res2)
res=list(res1=res1,res2=res2)  
}


#Funcion para tabla ANOVA del MRLM requiere libreria rms
MiAnova=function(model){
library(rsm)
name_response=names(model$model)[1]
nombres=names(model$model)[-1]
miformula=as.formula(paste(name_response,"~",paste(paste("FO(",paste(nombres,sep="",collapse=","),sep=""),")",sep="")))
tablaAnova=anova(rsm(miformula))
rownames(tablaAnova)[1]="Model"
print(tablaAnova)
}

#Funcion paratabla ANOVA del modelo con test de carencia de ajuste, requiere libreria rms
anovLOF=function(mod){
library(rsm)
rsp=names(attr(mod$terms, "dataClasses"))[1]
fct=names(attr(mod$terms, "dataClasses"))[-1]
fml=as.formula(paste(rsp,"~",paste0("FO(",paste(fct,collapse = ","),")")))
tabla=summary(rsm(fml))$lof
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
