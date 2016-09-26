library(dplyr)
library(data.table)

#'integrate weather data to create feature set
#'
#' @param weatherFile path and file containing weather data 
#' @param obsFile insect incidence observation file
#' @param soilFile soil data file
#' @param threshold distance radius for estmating nearest coordinates
#' @param numDays number of days of weather data to add to feature set
#'
#' @return feature file with integrated weather data
#' @export 
#'
#' @examples featureSet <- integrateWeather("../data/weather_eval.txt",
#'                                          "../data/OBVS_EVAL.csv",
#'                                          "../data/SoilData.csv",
#'                                          threshold=25,numDays=30)
integrateWeather <- function(weatherFile="data/weather_data.txt", 
                             obsFile="data/OBVS.csv", 
                             soilFile="data/SoilData.csv",
                             threshold=25,numDays=3){
  weatherData <- readWeatherData(weatherFile)
  insectData <- readInsectData(obsFile)
  SoilData <- readSoilData(soilFile)
  
  soilCoords <- unique(SoilData[,.(LAT,LON,SoilClass)])
  es <- estimateCoOrdByGPS(insectData[,.(LAT,LON)],soilCoords,50)
  insectData$estLAT <- es$LAT
  insectData$estLON <- es$LON
  soilCoords<-rename(soilCoords,estLAT=LAT)
  soilCoords<-rename(soilCoords,estLON=LON)
  # insectData <- as.data.table(merge.data.frame(insectData, soilCoords,all.x=F,
  #                                by.x=c("estLAT","estLON"),
  #                                by.y=c("LAT","LON")))
  insectData <- plyr::join(insectData,soilCoords,by=c("estLAT","estLON"),type="left",match="first")
  
  #Integrate weather data
  weatherCoOrds <- unique(weatherData[,.(LAT,LON)])
  es <- estimateCoOrdByGPS(insectData[,.(LAT,LON)],weatherCoOrds,threshold)
  insectData$estLAT <- es$LAT
  insectData$estLON <- es$LON
  
  #Extraact # days weather parameters
  features <- extract.weather.features(insectData, weatherData, numDays)
  
  #Estimate planting date and month
  features$PlantingDate <- do.call(c,mapply(getPlantingDate, features$STAGE, features$DATE,SIMPLIFY = F))
  
  features <- features[, -c(grep("^Date-|^est", colnames(features)))]
  
  #Create Barcode of weather pattern
  #(Pushkers code to go in here)
  
  return(features)
}

#Get and clean PAC data

#' Read weather data and clean it up 
#'
#' @param file = filename(full path)
#'
#' @return clean data as data.table object
#' @export
#'
#' @examples weatherData <- readweatherdata("../data/weather.txt")
readWeatherData <-function(file=""){
  data<-read.table(file, header=TRUE, sep=",")
  cleandata <- cleanWeatherData(data)
  setkey(cleandata,NULL)
  unique(cleandata)
}

#' Clean weather data
#'
#' @param data frame of weather data
#'
#' @return cleaned weather
#' @export
#'
#' @examples
cleanWeatherData <- function(rawDf){
  rawDf$DATE <- as.Date(rawDf$DATE, format="%Y-%m-%d")
  
  #round off lat/long
  rawDf$LAT <- round(as.numeric(rawDf$LAT), digits=5)
  rawDf$LON <- round(as.numeric(rawDf$LON), digits=5)
  
  as.data.table(rawDf)
}

#' Read and clean insect data simultaneously
#'
#' @param path Path to the folder containing the insect data files.
#' @param unknownThreshold Observations without location_ids must be less than this distance (in miles) away from a farm in the supplemental info. Otherwise, they receive an "UNKNOWN" farm.
#' @return A data frame containing clean insect data
#' @examples
#' clean<-readInsectData('../PAC/tests/testthat/data')
#' @export
readInsectData <- function(file=""){
  cleandata <-as.data.table(cleanInsectData(file))
  setkey(cleandata,NULL)
  unique(cleandata)
}

cleanInsectData <- function(file=""){
  
  obvs<-read.csv(file, stringsAsFactors=FALSE)
  
  #convert obs dates to date format
  obvs$DATE <- as.Date(obvs$DATE, format="%m/%d/%Y")
  
  #extract lat/long
  obvs$LAT <- round(as.numeric(stringr::str_extract(obvs$GEOLOCATION,' [-]*[\\d.]+')), digits=5)
  obvs$LON <- round(as.numeric(stringr::str_extract(obvs$GEOLOCATION,'[-]*[\\d.]+')), digits=5)
  
  #Remove geolocation column
  obvs$GEOLOCATION <- NULL
  
  #update columns data types
  if("PLANTAS_COM_DANO_3" %in% colnames(obvs)){
    obvs$PLANTS_WITH_DAMAGE_3 <- as.integer(obvs$PLANTAS_COM_DANO_3)
    obvs$PLANTAS_COM_DANO_3 <- NULL
  } 
  obvs$INSECT_SPECIES <- as.factor(obvs$INSECT_SPECIES)
  if(exists("obvs$VISITA_CONSULTA")){
    obvs$VISITA_CONSULTA <- gsub(" ","",obvs$VISITA_CONSULTA)
    obvs$VISITA_CONSULTA <- as.factor(obvs$VISITA_CONSULTA)
  }
  obvs$TECHNOLOGY_CODED <- gsub(" ","",obvs$TECHNOLOGY_CODED)
  obvs$TECHNOLOGY_CODED <- as.factor(obvs$TECHNOLOGY_CODED)
  
  obvs$STAGE <- gsub(" ","",obvs$STAGE)
  obvs$STAGE <- as.factor(obvs$STAGE)
  
  # #remove Portuguese language titles
  # obvs <- obvs[,!(names(obvs) %in% c("GEOLOCATION","PLANTAS_COM_DANO_3"))]
  # names(locData)[2]<-"LOC_IDS"
  obvs
}

#' Title
#'
#' @param file 
#'
#' @return
#' @export
#'
#' @examples
readSoilData <- function(file=""){
  SoilData <- read.csv(file,header = T, stringsAsFactors = T)
  
  #Integrate soil data
  SoilData <- rename(SoilData, LAT = Lat)
  SoilData <- rename(SoilData, LON = Long)
  SoilData$SoilClass <- as.factor(SoilData$SoilClass)
  SoilData$LAT <- round(as.numeric(SoilData$LAT), digits=5)
  SoilData$LON <- round(as.numeric(SoilData$LON), digits=5)
  
  as.data.table(SoilData)
}

calcDist <- function(x1 = matrix(c(38.6550834, -90.4207194),ncol=2),
                     x2 = matrix(c(38.666815, -90.5602757),ncol=2)){
  fields::rdist.earth(x1,x2)
}

#Function to extract weather data as features
extract.weather.features <- function(insectData, weatherData, noofdays=3){
  
  weatherData$year <-NULL
  #setkey(weatherData,"DATE", "LAT", "LON")
  
  for(i in 1:noofdays){
    calcdate <- paste0("Date.",i)
    insectData[[calcdate]] <- as.Date(insectData$DATE)-i
  }
  
  for (i in 1:noofdays){
    calcdate <- paste0("Date.",i)
    #setkeyv(insectData, c(calcdate, "LATT", "LONG"))
    insectData <- merge.data.frame(insectData, weatherData, all.x=T, 
                                   by.x=c(calcdate,"estLAT","estLON"),by.y=c("DATE","LAT","LON"),
                                   suffixes = c("",calcdate),sort=FALSE)
  }
  
  return(insectData)
}

#Get the nearest GPS co-ordinates from available reference file
#' Title
#'
#' @param x 
#' @param supp 
#' @param threshold 
#'
#' @return
#' @export
#'
#' @examples
estimateCoOrdByGPS <- function(x, supp, threshold){
  
  #Calculate the distance between each observation GPS and each location in weather data file
  distanceMatrix <- calcDist(x,supp[,.(LAT,LON)])
  
  #If distance is greater than threshold value, replace with NA
  
  #return the co-ordinates of the location closest to each input GPS point
  indices <- apply(distanceMatrix, 1, which.min)
  estLocs<-supp[indices,.(LAT,LON)]
  
  minDist <- apply(distanceMatrix, 1, min)
  estLocs[minDist > threshold]<-c(NA,NA)
  estLocs
}

#' getPlantingDate
#' @title Get planting date based on developmental stage and observation date.
#' @author Rajasekhara Duvvuru Muni/Ravindra Pushker
#' @description Get planting date based on developmental stage and observation date.
#' @param dev.stage Developmental stage. A character object.
#' @param obs.date Observation date. A date class object.
#' @return Planting date
#' @export
#' @examples 
#' \dontrun{
#' planting("V1", "2015-02-01") #a Returns "2015-01-19"
#' }
getPlantingDate <- function(dev.stage, obs.date){
  offset <- switch(dev.stage, 
                   VE = 7,
                   V1  = 13,
                   V2  = 15,
                   V3  = 18,
                   V4  = 21,
                   V5  = 24,
                   V6  = 27,
                   V7  = 31,
                   V8  = 34,
                   V9  = 37,
                   V10 = 40,
                   V11 = 43,
                   V12 = 50,
                   VN = 55,
                   R1  = 76,
                   R2  = 83,
                   R3  = 92,
                   R4  = 103,
                   R5  = 116,
                   R6  = 125,
                   R7 = 130
  )
  return(as.Date(obs.date) - offset)
}

