# These functions will generate the signatures/barcodes. Just call function "aggregateForWeek". 28 is total no. of days you want to divide into weeks. 28 means it will give data for 4 weeks.

aggregateForWeek <- function(days.data, no.of.days) {
    features <- names(days.data)
    fois <- c("MAXTEMP", "MINTEMP", "MAXRH", "MINRH", "PRECIP",
              "WINDSPEED", "SOLAR", "GDUBASE10C", "GDUBASE8C", "GDUBASE6C")
    names(days.data)[names(days.data) %in% fois] <- paste0(fois, "Date.1")
    
    no.of.weeks <- no.of.days/7
    
    for (foi in fois) {
      foi.columns <- paste0(foi, "Date.", 1:no.of.days)
      
      foi.q1 <- paste0(foi, ".Q1")
      foi.q3 <- paste0(foi, ".Q3")
      
      for (i in 1:no.of.weeks) {
        week.start <- 7 * (i - 1) + 1
        week.end <- 7 * i
        week.columns <- paste0(foi, "Date.", week.start:week.end)
        week.q1 <- paste0(foi, ".Week", i, ".Q1")
        week.q3 <- paste0(foi, ".Week", i, ".Q3")
        
        days.data[[week.q1]] <- apply(days.data[, week.columns], 1,
                                      FUN=function(x) {quantile(x, c(0.25), na.rm=T)[["25%"]]})
        days.data[[week.q3]] <- apply(days.data[, week.columns], 1,
                                      FUN=function(x) {quantile(x, c(0.75), na.rm=T)[["75%"]]})
        
        temp <- data.frame(N=1:nrow(days.data))
        for (week.column in week.columns) {
          temp[[week.column]] <- apply(days.data[,c(week.column,
                                                    week.q1, week.q3)], 1, FUN=getLevel)
        }
        
        days.data[[paste0(foi, ".Week", i)]] <- apply(temp[,
                                                           week.columns], 1, FUN=function(x){paste(x, collapse="")})
      }
      
    }
    
    # Order column names
    #col.ordered <- names(days.data)
    #col.ordered <- col.ordered[order(col.ordered)]
    #days.data[,col.ordered]
    
    days.data
  }

getLevel <- function(x) {
  ifelse(x[1] < x[2], "L", ifelse(x[1] > x[3], "H", "M"))
}