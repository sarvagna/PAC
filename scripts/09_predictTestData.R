#deps
library(caret) 
library(dplyr)

#set up
work_dir<-"/import/transfer/user/ddgrap/PAC_submission/"

#predict test data
load(file=paste0(work_dir,'results/selected_model')) # mod
model<-mod$fit

#variables
load(file=paste0(work_dir,"results/model_selection")) # rfvars
selected_vars<-rfvars$optVariables

#test data
test.data<-read.csv(file = "data/full.test.data.csv", header=TRUE)


#create an index to map predictions back
#to the originally supplied test data
# #need to map to original test data order
#-----------------------------------------
org<-read.csv( "data/OBVS_EVAL.csv",header=TRUE)

#format input to match working data
library(stringr)
library(chron)
lct <- Sys.getlocale("LC_TIME"); Sys.setlocale("LC_TIME", "C")
date<-format(str_trim(as.character(org$DATE),"both"),format="%m/%d/%Y") %>% dates() %>%
  as.Date() %>%
  format(.,format="%Y-%m-%d")

#need stringr_1.0.0 for this to work
LAT <- round(as.numeric(stringr::str_extract(as.character(org$GEOLOCATION),' [-]*[\\d.]+')), digits=5)
LON <- round(as.numeric(stringr::str_extract(org$GEOLOCATION,'[-]*[\\d.]+')), digits=5)

#common key
id.test<-data.frame(date,LAT,LON,org %>% select(STAGE,INSECT_SPECIES,TECHNOLOGY_CODED) %>% as.matrix()) %>%
  apply(.,1,paste,collapse="_") %>%as.character()
#compare
test<-data.frame(DATE=date,org,ID=id.test,stringsAsFactors = FALSE)

#pred common key
# pred.test<-pred.test %>% mutate(LAT=round(.$LON,5),LON=round(.$LAT,5))
id.pred<-data.frame(test.data %>% select(DATE,LAT,LON,STAGE,INSECT_SPECIES,TECHNOLOGY_CODED) %>% as.matrix()) %>%
  apply(.,1,paste,collapse="_") %>% as.character()

#compare
pred<-data.frame(test.data,ID=id.pred,stringsAsFactors = FALSE,mergeID=1:nrow(test.data))

#join
joined<-left_join(test,pred,by='ID')
mergeID<-joined$mergeID


#incompatible stage betwen train and test data
#need to be mapped to most similiar in train data
test.stage<-test.data %>% select(STAGE) %>% unique() %>% unlist() %>%as.character()
train.stage<-mod$data$train.data %>% select(STAGE) %>% unique() %>% unlist() %>% as.character()
test.stage[!test.stage %in% train.stage]

#remap all except VN which is more intelligently(?) imputed
tmp<-as.character(test.data$STAGE)
tmp[tmp=="V1"]<-"V2"
tmp[tmp=="R7"]<-"R6"
tmp[tmp=="VE"]<-"V2"

#impute VN
source("scripts/10_imputeSTAGE.R")
imputed<-read.csv(file="data/technology_imputedTestData.csv")
#overview
obj<-cbind(tmp,as.character(imputed$STAGE))[tmp=="VN",]
save(obj,file="results/STAGE imputation")
tmp[tmp=="VN"]<-obj[,2]

test.data$STAGE<-factor(tmp)

# select optimal vars
selected.test.data<-test.data %>% dplyr::select(one_of(selected_vars))

#predict test data
#make predictions for test set evaluation
test.damage<-predict(model,newdata=selected.test.data)
#save
pred.test<-test.data[,1:8] %>% 
  mutate(PREDICTIONS=toupper(test.damage))

write.csv(pred.test,file="results/test.data.predictions.csv")
# pred.test<-read.csv(file="results/test.data.predictions.csv",header=TRUE)

# map predictions to the original data
#-----------------------------------------
final_predictions<-data.frame(org,pred.test[mergeID,] %>% select(PREDICTIONS))
write.csv(final_predictions,"results/final_predicted_data.csv")
