#!/usr/bin/env Rscript

#recursive feature elimination

#deps
library(caret) 
library(dplyr)

#set up parallel
library(foreach)
library(doMC)
registerDoMC(15)



#set up
work_dir<-"/import/transfer/user/ddgrap/PAC_submission/"


load(paste0(work_dir,"results/full_rank_model")) # models
.data<-mod$data

#caret RFE using
subsets <- c(2:50, seq(25,ncol(.data$train.data),by=200))

#remove farm and LOC id due to too many levels for RFE

#should know mtry  to be used
set.seed(10)
ctrl <- rfeControl(functions = rfFuncs,
                   method = "repeatedcv",
                   number=3,
                   repeats = 3,
                   verbose = TRUE,
                   saveDetails = TRUE)

rfvars <- rfe(.data$train.data, .data$train.y,
              sizes = subsets,
              rfeControl = ctrl)

#use selected variables to predict test set
save(rfvars,file=paste0(work_dir,"results/model_selection"))


# #Remake model
# #with selected variables
# #validate
# #-------------
selected_vars<-rfvars$optVariables

# #package test/train data for easy access
.data$train.data<-.data$train.data %>% dplyr::select(one_of(selected_vars))
.data$test.data<-.data$test.data %>% dplyr::select(one_of(selected_vars))

#same script as used in full rank model
#trainning CV
set.seed(3456)
fitControl <- trainControl(method = "repeatedcv",
                           number = 7,
                           repeats = 3,
                           ## Estimate class probabilities
                           classProbs = TRUE,
                           verboseIter=TRUE,
                           allowParallel=TRUE,
                           savePredictions = TRUE,
                           summaryFunction = twoClassSummary
)


this.model<-"rf" 
tuneLength<-10

#create model
start<-Sys.time()

#---------------------------------------
fit <- tryCatch(
  train(unlist(.data$train.y) ~ ., 
        data=.data$train.data,
        method=this.model,
        trControl=fitControl,
        tuneLength=tuneLength,
        metric = "ROC"), 
  error = function(e) {as.character(e)})
end.t<-start-Sys.time()

#make predictions for test set evaluation
tr.pred<-tryCatch(predict(fit,newdata=.data$train.data),error = function(e) {as.character(e)})

start<-Sys.time()
ts.pred<-tryCatch(predict(fit, newdata = .data$test.data),error = function(e) {as.character(e)})
end.p<-start-Sys.time()

mod<-list(fit=fit,tr.pred=tr.pred,
          ts.pred=ts.pred,
          time=end.t,pred.time=end.p,data=.data)


save(mod,file=paste0(work_dir,'results/selected_model')) # 