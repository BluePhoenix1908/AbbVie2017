library(zoo)
library(reshape2)
library(ggplot2)  
library(plyr)

trendComparisonByDay <- function (dataset1,dataset2,dataset3, keyword1, keyword2, keyword3){
  
  ##original test:
  # dataset.day1 <- dataset1
  #dataset.day1$time <- format(dataset.day1$time, format="%m-%d") # only select dany and month
  #dataset.day1<- ddply( dataset.day1, 'time', function(x) c(count1=nrow(x)))
  #dataset.day1 <- dataset.day1[order(as.Date(as.character( dataset.day1$time),"%m-%d")),] 
  #dataset.day1$time <- factor(dataset.day1$time, levels=unique(as.character(dataset.day1$time)) ) #order the dates
  
  #dataset.day2 <- dataset2
  #dataset.day2$time <- format(dataset.day2$time, format="%m-%d") # only select dany and month
  #dataset.day2<- ddply( dataset.day2, 'time', function(x) c(count2=nrow(x)))
  #dataset.day2 <- dataset.day2[order(as.Date(as.character( dataset.day2$time),"%m-%d")),] 
  #dataset.day2$time <- factor(dataset.day2$time, levels=unique(as.character(dataset.day2$time)) ) #order the dates
  
  
  getFrequencyByDay<- function(dataset,n){
    datasetFreq<- dataset
    datasetFreq$time <- format(datasetFreq$time, format="%m-%d") # only select dany and month
    datasetFreq<- ddply( datasetFreq, 'time', function(x) c(count=nrow(x)))
    datasetFreq <- datasetFreq[order(as.Date(as.character( datasetFreq$time),"%m-%d")),] 
    datasetFreq$time <- factor(datasetFreq$time, levels=unique(as.character(datasetFreq$time)) ) #order the dates
    #names(datasetFreq)<- paste('datasetFreq',n, sep = "")
    return(datasetFreq)
  }
  
  getFrequencyByDay1<- getFrequencyByDay(dataset1, 1)
  colnames(getFrequencyByDay1)[2]<- 'count1'
  
  getFrequencyByDay2<- getFrequencyByDay(dataset2, 2)
  colnames(getFrequencyByDay2)[2]<- 'count2'
  
  getFrequencyByDay3<- getFrequencyByDay(dataset3, 3)
  colnames(getFrequencyByDay3)[2]<- 'count3'
  
  timefinal<- merge(x=getFrequencyByDay1, y=getFrequencyByDay2, by="time", all=TRUE)
  timefinal<- merge(x=timefinal,y=getFrequencyByDay3, by='time', all=TRUE)
  timefinal <-  timefinal[order(as.Date(as.character( timefinal$time),"%m-%d")),] 
  timefinal$time <- factor(timefinal$time, levels=unique(as.character(timefinal$time)) ) #order the dates
  timefinal[is.na(timefinal)]<-0
  
  
  comparison.day.plot<- ggplot(data= timefinal, aes(time, group = 1, stat="identity"))+
    geom_line(aes(y=count1, colour = keyword1))+ 
    geom_line(aes(y=count2, colour = keyword2))+
    geom_line(aes(y=count3, colour = keyword3))+
    
    #geom_line(aes(y=count1, colour=keyword1),colour="red")+
    #geom_line(aes(y=count2, colour=keyword2),colour="blue")+
    #geom_line(aes(y=count3, colour=keyword3),colour="green")+
    
    labs(x = "Month-Day", y = "Post Count", 
         title = paste("Trend comparison between", keyword1, ",", keyword2, "and", keyword3, sep = " "))
  
  return(comparison.day.plot)
  
}

#example
trendComparisonByDay(topic_abbv_201704,topic_amgn_201704,topic_bmy_201704,'ABBV','AMGN','BMY')

