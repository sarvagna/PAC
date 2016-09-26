test.data<-read.csv(file = "data/full.test.data.csv", header=TRUE)
#identify closest date/location for VN test data in train data
test<- test.data %>% select(STAGE,DATE,LAT,LON,TECHNOLOGY_CODED) %>%
  data.frame(ID=1:nrow(.),type='test',.)

train<-read.csv(paste0(work_dir,"data/full.train.data.csv"),header=TRUE)  %>%
  select(STAGE,DATE,LAT,LON,TECHNOLOGY_CODED) %>%
  data.frame(ID=1:nrow(.),type='train',.)

#adding train doen's seem to help
full<-rbind(test,train)

#split date into intervals
date.int<-format(as.character(full$DATE),format="%Y-%d-%m") %>% as.Date() %>%
  format(.,format='%m/%d/%y') %>% dates() %>%
  cut(.,include.lowest=FALSE,breaks='weeks')

fct<-full %>% select(LAT,LON) %>% round(.,0) %>% 
  apply(.,1,paste, collapse="_") %>%
  data.frame(.,date.int) %>%
  apply(.,1,paste, collapse="_") 
big.l<-split(full,fct)

#groupping by by week
is.VN<-lapply(big.l, function(x) any(x$STAGE=="VN")) %>% unlist()
vn.l<-big.l[is.VN]
#take non VN stage matching technology code
res1<-lapply(seq_along(vn.l),function(i){
  tmp<-vn.l[[i]] %>% droplevels()
  obj<-split(tmp,tmp$TECHNOLOGY_CODED)
  lapply(seq_along(obj),function(i) {
    tbl<-table(obj[[i]]$STAGE) %>% 
      data.frame() %>%
      filter(Var1 !='VN')
    out<-as.character(obj[[i]]$STAGE)
    if(nrow(tbl)>0) {
      out[out=='VN']<-as.character(tbl$Var1[which.max(tbl$Freq)[1]])
    } 
    tmp2<-as.matrix(obj[[i]]) %>% data.frame()
    tmp2$STAGE<-out
    tmp2
  }) %>% do.call("rbind",.)
}) %>% do.call("rbind",.) %>% filter(type=="test") 

#alter imputed
tmp.test<- test %>%
  mutate(STAGE = as.character(.$STAGE))
id<-as.numeric(as.character(res1$ID))
tmp.test$STAGE[id]<-res1$STAGE

#repeat binning by months
#identify closest date/location for VN test data in train data
test<- tmp.test

#adding train doen's seem to help
full<-rbind(test,train)

#split date into intervals
date.int<-format(as.character(full$DATE),format="%Y-%d-%m") %>% as.Date() %>%
  format(.,format='%m/%d/%y') %>% dates() %>%
  cut(.,include.lowest=FALSE,breaks='months')

fct<-full %>% select(LAT,LON) %>% round(.,0) %>% 
  apply(.,1,paste, collapse="_") %>%
  data.frame(.,date.int) %>%
  apply(.,1,paste, collapse="_") 
big.l<-split(full,fct)

#groupping by by month
is.VN<-lapply(big.l, function(x) any(x$STAGE=="VN")) %>% unlist()
vn.l<-big.l[is.VN]
#take non VN stage matching technology code
res1<-lapply(seq_along(vn.l),function(i){
  tmp<-vn.l[[i]] %>% droplevels()
  obj<-split(tmp,tmp$TECHNOLOGY_CODED)
  lapply(seq_along(obj),function(i) {
    tbl<-table(obj[[i]]$STAGE) %>% 
      data.frame() %>%
      filter(Var1 !='VN')
    out<-as.character(obj[[i]]$STAGE)
    if(nrow(tbl)>0) {
      out[out=='VN']<-as.character(tbl$Var1[which.max(tbl$Freq)[1]])
    } 
    tmp2<-as.matrix(obj[[i]]) %>% data.frame()
    tmp2$STAGE<-out
    tmp2
  }) %>% do.call("rbind",.)
}) %>% do.call("rbind",.) %>% filter(type=="test")

#alter imputed
tmp.test<- test %>%
  mutate(STAGE = as.character(.$STAGE))
id<-as.numeric(as.character(res1$ID))
tmp.test$STAGE[id]<-res1$STAGE

#repeate ignoring the TECHNOLOGY_CODED gives VN ==V1, ignore and set VN to
# variable most imputed with
tmp.test$STAGE[tmp.test$STAGE=="VN"]<-"V6"
write.csv(tmp.test,file="data/technology_imputedTestData.csv")

