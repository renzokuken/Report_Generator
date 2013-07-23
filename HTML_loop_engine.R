rm(list=ls())
#setwd("R_loop")

data_path <<- paste("C:\Users\mhilton\Documents\R_Data\HTML_Reports")
report_path <<- paste("C:\Users\mhilton\Documents\R_Graphs\HTML_Reports")

library(RODBC)
library(ggplot2)
library(scales)
library(grid)
library(plyr)


#pull full list of schools
x <- odbcConnect("Schools_prod")
#pull current schools
school_query <- ("SELECT
             School_ID
            ,Display_Name
            FROM Schools.dbo.Schools
            WHERE Academic_Year_Closed IS NULL
            AND Year_Opened < 2012
            ")

school_list <- sqlQuery(x, school_query, stringsAsFactors=FALSE)
odbcCloseAll()

#clean up school names
school_list$Display_Name <- gsub(":","",school_list$Display_Name)
school_list$Display_Name <- gsub(",","",school_list$Display_Name)
school_list$Display_Name <- gsub("'","",school_list$Display_Name)
school_list$Display_Name <- gsub(".","",school_list$Display_Name)
school_list$Display_Name <- gsub(" ","_",school_list$Display_Name)

#x <- c(5, 3)
for(s in school_list$School_ID){
  #for(s in x){
  n <- school_list[school_list$School_ID == s,]
  n <- n$Display_Name
  
  print(s)
  print(n)
  
  source("loop_quartile_graph.R")
  #ggsave(paste(s,"_",n,"_quartile.png", sep=""), width=12, height=12)
  #dev.off()

}