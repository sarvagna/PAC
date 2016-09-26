#AUC functions
library(pracma)
library(dplyr)

# AUC corrected for baseline to make it a relative AUC
#' @title get_AUC
#' @param vec vector to integrate over
get_AUC<-function(vec){
  base<-vec-vec[1]
  trapz(1:length(base),base)
}

#' @title get_AUC_mat
#' @param mat matrix with vectors to integrate over (order 1 to end) as rows
get_AUC_mat<-function(mat){
  sapply(1:nrow(mat),function(i) {get_AUC(mat[i,])})
}


#get rolling AUC across rows grouping columns
#' @title get_AUC_data
#' @param tmp.data data
#' @param vars variables to calculate AUC for
get_AUC_data<-function(tmp.data,vars){
  
  #get id for variable blocks by date
  full_names<-colnames(tmp.data) %>% strsplit(.,"Date") %>% do.call("rbind",.)
  
  #iterate over vars and get AUC
  AUC_list<-lapply(1:length(vars), function(i) {
    tmp<-tmp.data %>% select(contains(vars[i])) 
    tmp<-lapply(1:ncol(tmp),function(i){tmp[,i,drop=FALSE]}) #
    res<-Reduce("cbind", tmp, accumulate = TRUE) # create rolling groups
    auc<-lapply(res,function(x){
      get_AUC_mat(as.matrix(x))
    })
    
    auc<-do.call("cbind",auc)
    colnames(auc)<-paste0(vars[i],"_",1:ncol(auc),"_AUC")
    #drop AUC for one day
    auc[,-1]
  })
  
  do.call("cbind",AUC_list) 
}
