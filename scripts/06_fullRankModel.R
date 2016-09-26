#!/usr/bin/env Rscript

#generate and evaluate the
#full rank model

#deps
library(caret) 
library(dplyr)
library(data.table)
library(purrr)

# #set up parallel
library(foreach)
library(doMC)
registerDoMC(14)


#set up
work_dir<-"/import/transfer/user/ddgrap/PAC_submission/"


#trainning data omiting missing values
full_data<-fread(paste0(work_dir,"data/full.train.data.csv"),header=TRUE)  %>% 
  data.frame() %>%
  na.omit() 


#map characters to factors
full_data<- full_data %>% map_if(.,is.character,as.factor) %>% data.frame()

#Remove factors with>50 levels to not break RF
levs<-sapply(1:ncol(full_data), function(i){
  tryCatch(nlevels(full_data[,i]), error=function(e){0})
})
full_data<-full_data[,!levs==1 & !levs>=50]


#partition into train/test sets for validation
#maintain proportion of damage
set.seed(998)
inTraining <- createDataPartition(full_data$Y, p = .66, list = FALSE)
training <- full_data[ inTraining,]
testing  <- full_data[-inTraining,]

#package test/train data for easy access
.data<-list(train.data = training %>% select(-Y),
            train.y    = factor(training$Y),
            test.data  = testing %>% select(-Y),
            test.y     = factor(testing$Y))


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


save(mod,file=paste0(work_dir,'results/full_rank_model')) # 

