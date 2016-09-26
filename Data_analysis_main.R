

#------------------------
# Trainning data preparation
# -----------------------
#functions used
source("scripts/01_DataIntegration.R")
source("scripts/02_aggregateForWeek.R")
source("scripts/03_weatherDataAggregate.R")

## Combine observations, weather, soil, planting date
days.data <- integrateWeather(weatherFile="./data/weather_data.txt", 
                              obsFile="./data/OBVS.csv", 
                              soilFile="./data/SoilData.csv",
                              threshold=25,numDays=30)

# generate aggregated (sum, min, max, median)weather features for required no of days from the observation date. It is hardcoded to caliculate the 7,14,21,28 days (Optional)
days.data.aggregated <- getAggregatedData(days.data) # using hard coded limits...needs to be generalized

# generate the weather signatures over 28 days (4 Weeks) Barcode
days.data.signatures <- aggregateForWeek(days.data, 28)

#save intermediate objects
write.csv(x = days.data, file = "data/weather30day.csv",row.names = F)
write.csv(x = days.data.signatures, file = "data/weatherSignatures.csv", row.names = F)

#Calculate variable area under the curve (AUC)
source('scripts/04_calculateAUC.R')
days.data<-read.csv(file = "data/weather30day.csv",header = TRUE)
tmp.data<-days.data
#variables integrate
vars<-c('MAXTEMP',
        'MINTEMP',
        'MAXRH',
        'MINRH',
        'PRECIP',
        'WINDSPEED',
        'SOLAR',
        'GDUBASE10C',
        'GDUBASE8C',
        'GDUBASE6C')

AUC.data<-get_AUC_data(tmp.data,vars)

#combine and clean
full.train.data<-data.frame(days.data.signatures,AUC.data)
#remove Dates and prepare Y
drop<-grepl('^Date',colnames(full.train.data))
full.train.data<-full.train.data[,!drop] %>%
  mutate(Y=factor(.$PLANTS_WITH_DAMAGE_3>20,levels=c("FALSE","TRUE"),labels=c("no","yes"))) %>%
  select(-PLANTS_WITH_DAMAGE_3)
#save
write.csv(full.train.data, file = "data/full.train.data.csv", row.names = F)

#------------------------
# Test data preparation
# -----------------------
#Combine obvs_eval.csv and weather_eval.csv along with soil and planting date
test.days.data <- integrateWeather(weatherFile = "data/weather_eval.csv", 
                                   obsFile = "data/OBVS_EVAL.csv", 
                                   soilFile = "data/SoilData.csv", threshold = 25, numDays = 30)

#impute missing values in weather data
#using date and geographical proximity
# to present data 
source('scripts/05_imputeData.R')
data<-test.days.data
#calculate geographical distances between all locations
gdist<-geoDist(data[,],lat="LAT",long="LON",cores=10)
#index for missing values to not use in the imputation
reference<-data %>% select(MAXTEMP) %>% is.na(.)
imputed_test.days.data<-geoDateImpute(data,gdist,prox=25,date="DATE",lat="LAT",lon="LON",reference,cores=15)

# Now call the aggregateForWeek function with  
# generate aggregated (sum, min, max, median)weather features for required no of days from the observation date. It is hardcoded to caliculate the 7,14,21,28 days (Optional)
to_aggregate<-imputed_test.days.data[,sapply(imputed_test.days.data,class) == "numeric"] %>%
  select(-LON,-LAT)
test.days.data.aggregated <- getAggregatedData2(to_aggregate)

# generate the weather signatures over 28 days (4 Weeks) Barcode
test.days.data.signatures <- aggregateForWeek(to_aggregate, 28)

#save intermediate objects
write.csv(imputed_test.days.data, file = "data/test_weather30day.csv",row.names = F)
write.csv(test.days.data.signatures, file = "data/test_weatherSignatures.csv", row.names = F)

#Calculate variable area under the curve (AUC)
tmp.data<-read.csv(file = "data/test_weather30day.csv",header = TRUE)

#variables integrate
vars<-c('MAXTEMP',
        'MINTEMP',
        'MAXRH',
        'MINRH',
        'PRECIP',
        'WINDSPEED',
        'SOLAR',
        'GDUBASE10C',
        'GDUBASE8C',
        'GDUBASE6C')

AUC.data<-get_AUC_data(tmp.data,vars)

#combine and clean
full.test.data<-data.frame(test.days.data.signatures,AUC.data)
#remove Dates and prepare Y
drop<-grepl('^Date',colnames(full.test.data))
full.test.data<-full.test.data[,!drop] 
#add meta data
meta<-c("DATE", "STAGE", "INSECT_SPECIES", "TECHNOLOGY_CODED", "SoilClass", 
        "PlantingDate", "LAT", "LON")
full.test.data <- data.frame(imputed_test.days.data %>% select(one_of(meta)),full.test.data)
#save
write.csv(full.test.data, file = "data/full.test.data.csv", row.names = F)


#------------------------
# Predictive Modeling
# -----------------------
#train and validate the full rank model
source('scripts/06_fullRankModel.R')

#carry out recursive feature selection
source('scripts/08_featureSelection.R')

#validate and compare full rank and selected models
source('scripts/07_evaluateFullRankModel.R')

#predict test data insect damage
source('scripts/09_predictTestData.R')

