#impute missing values in the test data
library(dplyr)
library(purrr)


#function to calculate pairwise distances
geoDist<-function(data,lat,long,cores=NULL) {
  
  lat<-data %>% select(one_of(lat)) %>% matrix() %>% unlist()
  long<-data %>% select(one_of(long)) %>% matrix() %>% unlist()
  
  
  #create factor based on geographical proximity
  # Calculates the geodesic distance between two points specified by radian latitude/longitude using the
  # Spherical Law of Cosines (slc) # http://www.r-bloggers.com/great-circle-distance-calculations-in-r/
  gcd.slc <- function(long1, lat1, long2, lat2) {
    R <- 6371 # Earth mean radius [km]
    d <- acos(sin(lat1)*sin(lat2) + cos(lat1)*cos(lat2) * cos(long2-long1)) * R
    return(d) # Distance in km
  }
  
  fxn<-purrr::safely(gcd.slc)
  #TODO:to speed up calculation get all non-redundant pairs
  #then cast into a symmetric matrix 
  if(is.null(cores)){
    
    dist<-lapply(1:length(lat), function(i){
      start<-c(lat=lat[i],long=long[i])
      fxn(long1=start['long'], lat1=start['lat'], long2=long, lat2=lat)$result
    }) %>% do.call("cbind",.)
    
    dimnames(dist)<-list(1:length(lat),1:length(lat))
    
  } else {
    #parallel code goes here
    library(doMC)
    library(foreach)
    registerDoMC(cores=cores)
    dist<-foreach(i = 1:length(lat),.combine = cbind) %dopar% {
      start<-c(lat=lat[i],long=long[i])
      fxn(long1=start['long'], lat1=start['lat'], long2=long, lat2=lat)$result
    }
    
    dimnames(dist)<-list(1:length(lat),1:length(lat))
  }
  #replace diag with NA
  diag(dist)<-NA
  return(dist)
}

#get closests within some proximity
get_proximal<-function(dist,prox=25,reference=NULL,force=TRUE){
  if(is.null(reference)){ reference<-rep(TRUE,nrow(dist)) %>% as.logical()}
  lapply(1:nrow(dist),function(i){
    #need to exclude NAs in nearest mapping
    obj<-na.omit(dist[i,ref]) #diag has NA
    out<-obj[obj<=prox] %>% names(.)
    if(force & length(out)==0 ){
      out<-obj[which.min(obj)] %>% names(.)
    }
    return(out)
  }) 
}


#' @title geoDateImpute
#' @param data
#' @param gdist geographic distance matrix
#' @param prox km for locations to include to take median for imputations 
#' @param date name of date variable
#' @param lon name of longitude variable # legacy should remove
#' @param lat name of latitude variable # legacy should remove
#' @param reference logical for missing values to not use in imputation
#' @param cores number of cores for parallel calculations
#' @details imputation based on closest date/location for numeric data
geoDateImpute<-function(data,gdist,prox,date,lat,lon,reference,cores){
  #get all within 25 km or single closest
  #need to constrain on the same date
  library(doMC)
  library(foreach)
  registerDoMC(cores=cores)
  proximals<-foreach(i = 1:nrow(data)) %dopar% {
    .date<-data %>% select(one_of(date)) %>% .[i,] %>% as.character()
    ref<-data %>% select(one_of(date)) == .date & !reference
    get_proximal(dist=gdist,prox=prox,reference = ref,force=TRUE)[[i]]
  }
  
  #variables to impute
  is.num<-colnames(data)[sapply(data,class)=="numeric"]
  to_impute<-data %>% select(one_of(is.num),-one_of(lat),-one_of(lon)) 
  
  imputed_data<-foreach(i = 1:nrow(to_impute)) %dopar% {
    if(all(is.na(to_impute[i,,drop=FALSE]))) {
      vals<-to_impute[proximals[[i]] %>% as.numeric(),,drop=FALSE]
      if(nrow(vals)>1){
        out<-data.frame(apply(vals,2,median)%>% matrix(.,1,ncol(to_impute)))
        colnames(out)<-colnames(to_impute)
        out
      } else {
        vals
      }
      
    } else {
      to_impute[i,,drop=FALSE]
    }
  } %>% do.call("rbind",.) 
  
  
  data.frame(data %>% select(-one_of(is.num)),
                           data %>% select(one_of(lat),one_of(lon)),
                           imputed_data)
}


# #visualize lat long..seems reasonable?
# library(ggplot2)
# tmp.data<-data.frame(data %>% select(LAT,LON,DATE),missing=factor(na_ref),var=imputed_data$MAXTEMP)
# ggplot(tmp.data, aes(x=LAT,y=LON,color=var,color=DATE)) + geom_point(alpha=.5) +
#   geom_jitter(position = position_jitter(height = 3, width =3)) +facet_grid(missing~.) +
#   theme_bw()

