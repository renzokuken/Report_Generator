rm(list=ls())

#Declare globals
pulldata <- 1

formatdata <- 1

publishdata_html <- 0

publishdata_png <- 0

data.path <<- paste("C:/Users/mhilton/Documents/R_Data/HTML_Reports/")
report.path <<- paste("C:/Users/mhilton/Documents/R_Graphs/HTML_Reports/")

library(RODBC)
library(ggplot2)
library(scales)
library(grid)
library(plyr)

#pull full list of schools
s <- odbcConnect("Schools_prod")
#pull current schools
school.query <- ("SELECT
             School_ID
            ,Display_Name
            FROM Schools.dbo.Schools
            WHERE Academic_Year_Closed IS NULL
            AND Year_Opened < 2012
            ")

school.list <- sqlQuery(s, school.query, stringsAsFactors=FALSE)
odbcCloseAll()

#clean up school names
school.list$Display_Name <- gsub(":","",school.list$Display_Name)
school.list$Display_Name <- gsub(",","",school.list$Display_Name)
school.list$Display_Name <- gsub("'","",school.list$Display_Name)
school.list$Display_Name <- gsub(".","",school.list$Display_Name)
school.list$Display_Name <- gsub(" ","_",school.list$Display_Name)

while(pulldata == 1) {
  
#Declare ODBC connections
  rc <- odbcConnect('Report_Card_prod')
  ss <- odbcConnect('State_Scores_prod')
  
#Declare SQL Queries
  quartile.query <- ("SELECT
                        *
                        FROM v_School_Quartile_current_2012
                        ")
    
  statescore.query <- ("SELECT
             State_Score_Header_ID
            ,State_ID
            ,AC_Year
            ,Grade
            ,School_ID
            ,Subtest_ID
            ,Subtest_Name
            ,Subtest_Cat_RC_ID
            ,Score_Grouping_Name
            ,Score_Grouping_Cat_ID
            ,State_Num_Tested
            ,State_Score_Percent
            ,District_Num_Tested
            ,District_Score_Percent
            ,School_Num_Tested
            ,School_Score_Percent
            FROM State_Scores.dbo.v_All_Scores
            WHERE AC_Year = 2012
            AND Score_Grouping_Cat_ID IN (2,3)
            ")
  
  demographics.query <- ("SELECT 
            School_ID
           ,Display_Name
           ,Male_Students_Percent
           ,Female_Students_Percent
           ,White_Students_Percent
           ,Black_Students_Percent
           ,Latino_Students_Percent
           ,Asian_Students_Percent
           ,Native_Students_Percent
           ,Pacific_Students_Percent
           ,TwoMoreRaces_Students_Percent
           ,Special_Needs_Percent
           ,F_and_R_Meals_Percent
           FROM Report_Card.dbo.v_Student_Demographics_all2012
           WHERE PP_ID = 32
           ")
  
  
  quartile.raw <- sqlQuery(rc, quartile.query, stringsAsFactors=FALSE)
  statescore.raw <- sqlQuery(ss, statescore.query, stringsAsFactors=FALSE)
  demographics.raw <- sqlQuery(rc, demographics.query, stringsAsFactors=FALSE)
  

  odbcClose(rc)
  odbcClose(ss)
  
dput(quartile.raw, paste(data.path,"quartile.raw.Rda", sep=""))
dput(statescore.raw, paste(data.path,"statescore.raw.Rda", sep=""))
dput(demographics.raw, paste(data.path,"demographics.raw.Rda", sep=""))
  
break
}

while(formatdata == 1){
dget(paste(data.path,"quartile.raw.Rda", sep=""))
dget(paste(data.path,"statescore.raw.Rda", sep=""))
dget(paste(data.path,"demographics.raw.Rda", sep=""))

#format quartile data
quartile.mod <- quartile.raw

#set graph values for percent_in_quartile
quartile.mod$Percent_Below_25_NPR <- (quartile.mod$Percent_Below_25_NPR * -1)
quartile.mod$Percent_At_25_Below_50_NPR <- (quartile.mod$Percent_At_25_Below_50_NPR * -1)

#reshape data wide to long
quartile.mod <- reshape(quartile.mod,
                    varying = c("Percent_Below_25_NPR", "Percent_At_25_Below_50_NPR", "Percent_At_50_Below_75_NPR", "Percent_At_Above_75_NPR"),
                    v.names = "percent_at_quartile",
                    timevar = "quartile",
                    times = c("Percent_Below_25_NPR", "Percent_At_25_Below_50_NPR", "Percent_At_50_Below_75_NPR", "Percent_At_Above_75_NPR"),
                    new.row.names = 1:5000,
                    direction = "long")

#generate order for bar stacking
quartile.mod$order <- ifelse(quartile.mod$quartile == "Percent_At_Above_75_NPR", 4, ifelse(quartile.mod$quartile == "Percent_At_50_Below_75_NPR", 3, ifelse(quartile.mod$quartile == "Percent_At_25_Below_50_NPR",1, 2)))

#generate order for bar sequence
quartile.mod$sequence <- paste(quartile.mod$Season, quartile.mod$Grade_When_Taken_int)
quartile.mod$Graph_Label <- reorder(quartile.mod$Graph_Label,quartile.mod$sequence)
#generate labels for graph
quartile.mod$label <- abs(quartile.mod$percent_at_quartile)

#format statescore data
statescore.mod <- statescore.raw
#transform from wide to long
statescore.mod <- reshape(statescore.mod,
                             varying = c("State_Score_Percent", "District_Score_Percent", "School_Score_Percent"),
                             v.names = "score",
                             timevar = "score_level",
                             times = c("State_Score_Percent", "District_Score_Percent", "School_Score_Percent"),
                             new.row.names = 1:5000,
                             direction = "long")

statescore.mod$order <- (ifelse(statescore.mod$score_level == "School_Score_Percent", 1, ifelse(statescore.mod$score_level == "District_Score_Percent", 2, 3)))
#set ordering for graphs
statescore.mod$order <- as.integer(paste(statescore.mod$order, statescore.mod$Score_Grouping_Cat_ID, sep=""))
#set labels for buckets
statescore.mod$score_stack <- paste(statescore.mod$score_level, statescore.mod$Score_Grouping_Name, sep= "_")
#replace underscores
statescore.mod$score_stack <- gsub("_"," ", statescore.mod$score_stack)
#remove "score" because it looks stupid :/
statescore.mod$score_stack <- gsub(" Score ", " ", statescore.mod$score_stack)
#cut trailing spaces
statescore.mod$Subtest_Name <- gsub("[[:space:]]*$","", statescore.mod$Subtest_Name)
#round floating point scores
statescore.mod$score <- round(statescore.mod$score, 0)

#format demographic data
demographics.mod <- demographics.raw

dput(quartile.mod, paste(data.path, "quartile.mod.RDa", sep=""))
dput(statescore.mod, paste(data.path,"statescore.mod.RDa", sep =""))
dput(demographics.mod, paste(data.path,"statescore.mod.RDa", sep=""))
break
}


while(publishdata_html == 1) {
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
break
}