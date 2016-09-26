#full rank model evaluation
#deps
library(caret) 
library(dplyr)


#set up
work_dir<-"/import/transfer/user/ddgrap/PAC_submission/"

#load data to use for evals


#get model information
obj<-dir(paste0(work_dir,"results")) %>% .[!grepl("1.",.)] #  exclude

best.mod<-lapply(1:length(obj), function(i){
  model<-gsub(" ","",obj[i]) #typo
  data.frame(model=model,file=paste0(work_dir,'results/',obj[i]),stringsAsFactors = FALSE)
}) %>% do.call("rbind",.) %>%
  filter(model!="model_selection")
  

#------------------------
#accesory functions
#------------------------
#collapse tune vars
list.to.vector<-function(obj,delim=","){
  tmp<-lapply(1:length(obj),function(i){
    paste0(names(obj)[i],"=",paste(obj[[i]],collapse=delim))
    
  })
  paste(unlist(tmp),collapse=";")
}

#make 2 class summary as a data.frame
twoClass_summary<-function(pred,obs,positive){
  ts.summary<-caret::confusionMatrix(table(pred,obs),positive = positive) 
  tmp<- ts.summary$overall %>% matrix(.,1) %>% data.frame(.) %>% setNames(.,nm=names(ts.summary$overall))
  tmp2<- ts.summary$byClass %>% matrix(.,1) %>% data.frame(.) %>% setNames(.,nm=names(ts.summary$byClass))
  cbind(tmp,tmp2)
}

#format time
frmt_time<-function(time,sig=3) {
  paste0(as.character(abs(signif(time,sig))), " ",attr(time,"units"))
}


#------------------------

#collect
perf_vars<-c("ROC","Sens","Spec")
#optimize on
opt_var<-"ROC"

#get performance metrics
mod.perf<-lapply(1:nrow(best.mod), function(i){
  out<-list()
  #get train error
  load(file=as.character(best.mod$file[i]))
  out$model<-mod
  
  #-------------------
  #train
  #-------------------
  fit<-out$model$fit
  print(fit)
  if(class(fit)=="character") return(NULL)
  best.tune<-list.to.vector(fit$best)
  train.perf<-fit$results  %>% dplyr::select(one_of(perf_vars)) %>% data.frame(.)
  
  #get best
  if(nrow(train.perf>1)) train.perf<-train.perf[which.max(train.perf[,opt_var]),,drop=FALSE]
  #test
  #if length==2 then it was a tie i.e. 50% propability for both, rounding makes it toxin (first column)
  
  #-------------------
  #Test
  #-------------------
  pred<-out$model$ts.pred
  obs<-out$model$data$test.y
  
  #not averaged for CV (fit is)
  ts.summary<-tryCatch(twoClass_summary(pred,obs,positive="yes"),error=function(e) {data.frame(summary=NA)})
  
  model.info<-data.frame(model=best.mod$model[i],
                         tr.time=frmt_time(out$model$time),
                         pred.time=frmt_time(out$model$pred.time),
                         total.time=frmt_time(out$model$pred.time+out$model$time))
  model<-data.frame(tune=best.tune,
                    train=data.frame(round(train.perf,3)),
                    test=data.frame(ts.summary))
  
  return(data.frame(model.info,model=model))
  
})

#collect parts and bind...because could have partial failures need an infill function
m<-function(...){merge(...,all=TRUE)}

write.csv(model_summary,file=paste0(work_dir,"/data/model_summary.csv"),row.names = FALSE)
