# Call this guy
getAggregatedData <- function(days.data) {
  # Change these parameters
  timelines <- c(7,14,21,28)
  FUNS <- c(min, max, mean, sum, median)
  col.headers <- c("MIN", "MAX", "AVG", "TOTAL", "MEDIAN")
  
  aggregated.data <- days.data[,31:341]
  
  for (no.of.days in timelines) {
    for (i in 1:length(FUNS)) {
      aggregated.data <- cbind(aggregated.data, aggregateForDays(days.data, no.of.days, FUNS[[i]], col.headers[i]))
    }
  }
  
  write.csv(aggregated.data, row.names=F, file = "aggregatedWeather.csv")
  aggregated.data
}

#removing hardcoded limits
getAggregatedData2 <- function(days.data) {
  # Change these parameters
  timelines <- c(7,14,21,28)
  FUNS <- c(min, max, mean, sum, median)
  col.headers <- c("MIN", "MAX", "AVG", "TOTAL", "MEDIAN")
  
  aggregated.data <- days.data
  
  for (no.of.days in timelines) {
    for (i in 1:length(FUNS)) {
      aggregated.data <- cbind(aggregated.data, aggregateForDays(days.data, no.of.days, FUNS[[i]], col.headers[i]))
    }
  }
  
  write.csv(aggregated.data, row.names=F, file = "aggregatedWeather.csv")
  aggregated.data
}

#' Get aggregated data 
#'
#' @param days.data Data with days 
#' @param no.of.days How many days to aggregate
#' @param FUN Function to use for aggregation
#' @param col.header Name of the new column
#'
#' @return The original data frame with the added column
#' @export
#'
#' @examples
aggregateForDays <- function(days.data, no.of.days, FUN, col.header) {
  features <- names(days.data)
  fois <- c("MAXTEMP", "MINTEMP", "MAXRH", "MINRH", "PRECIP", "WINDSPEED", "SOLAR", "GDUBASE10C", "GDUBASE8C", "GDUBASE6C")
  names(days.data)[names(days.data) %in% fois] <- paste0(fois, "Date.1")
  
  aggregated.df <- list()
  
  for (foi in fois) {
    foi.columns <- paste0(foi, "Date.", 1:no.of.days)
    foi.fun <- paste0(foi, '.', no.of.days, 'days.', col.header)
    
    aggregated.df[[foi.fun]] <- apply(days.data[, foi.columns], 1, FUN=FUN)
    
  }
  
  as.data.frame(aggregated.df)
}
