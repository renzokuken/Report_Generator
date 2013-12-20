###########################################################################################################
#Project FORGE: Fast and Optimized R-based Generator of Excellence                                        #
#Written By: Mike Hilton                                                                                  #
#Last Updated: 12-20-13                                                                                   #
###########################################################################################################
rm(list=ls())

#set directory
wd <- getwd()
if (wd != "C:/Users/mhilton/Documents/GitHub/Report_Generator/R") setwd("C:/Users/mhilton/Documents/GitHub/Report_Generator/R")
#Declare globals

pulldata <- 1

formatdata <- 1

publishdata_html <- 1

data.path <<- paste("C:/Users/mhilton/Documents/R_Data/HTML_Reports/")
report.path <<- paste("C:/Users/mhilton/Documents/R_Graphs/HTML_Reports/")
#data.path <<- paste("Z:/001_NEW_SNEETCH/Report_Card/2013/Data/")
#report.path <<- paste("Z:/001_NEW_SNEETCH/Report_Card/2013/Output/")


library(RODBC)
library(ggplot2)
library(scales)
library(grid)
library(plyr)
library(knitr)
library(xtable)
library(markdown)

while(pulldata == 1) {
  
#Declare ODBC connections
s <- odbcConnect('Schools_stage')
c <- odbcConnect('Clusters_stage')
rc <- odbcConnect('Report_Card_stage')
as <- odbcConnect('Attainment_stage')
ss <- odbcConnect('Report_Card_prod')
  
#Declare SQL Queries
school.query <- ("SELECT
             S.School_ID AS Site_ID
            ,S.Cluster_ID
            ,C.Name AS Region_Name
            ,S.Type
            ,Display_Name
            ,S.Web_URL
            ,S.Address_1
            ,S.Address_2
            ,S.City
            ,S.State
            ,S.Zipcode
            ,S.Telephone_1
            ,S.Grade_From
            ,S.Grade_Thru
            ,SP.Per_Pupil_Revenue
            FROM Schools.dbo.Schools S
            JOIN DP_Production.dbo.School_Profiles SP
            ON S.School_ID = SP.School_ID
            JOIN Clusters.dbo.Clusters C
            ON S.Cluster_ID = C.Cluster_ID
            WHERE Academic_Year_Closed IS NULL
            AND Year_Opened < 2013
            AND PP_ID = 36
            ORDER BY Site_ID
            ")

square.footage.query <- (
              "SELECT
               S.School_ID AS Site_ID
              ,S.Cluster_ID
              ,building_square_footage
              FROM Schools.dbo.Schools S
              JOIN DP_Production.dbo.School_Profiles SP
              ON S.School_ID = SP.School_ID
              JOIN DP_Production.dbo.Space_Information I
              ON SP.Profile_ID = I.Profile_ID
              WHERE Academic_Year_Closed IS NULL
              AND Year_Opened < 2013
              AND PP_ID = 39"
  )

region.query <- ("SELECT
              C.Cluster_ID AS Site_ID
             ,Name AS Region_Name
             ,Address_1
             ,Address_2
             ,City
             ,State
             ,Zip
             ,Website
             ,Phone_Office
             ,first_name
             ,last_name
             FROM Clusters.dbo.Clusters C
             LEFT JOIN Clusters.dbo.Xref_Regional_Leader XRL
             ON C.Cluster_ID = XRL.Cluster_ID
             LEFT JOIN Clusters.dbo.Regional_Leader RL 
             ON XRL.Regional_Leader_ID = RL.Regional_Leader_ID
             WHERE Inactive = 0
             AND Academic_Year_Opened < 2014
             AND (date_ended IS NULL
             OR C.Cluster_ID = 16)
             ORDER BY Site_ID
            ")

#NOTE: need a separate query to the schools database for cases where N School Leaders > 1
schoolleader.query <- ("SELECT
                     S.School_ID AS Site_ID
                    ,SL.school_leader_id
                    ,SL.first_name
                    ,SL.last_name
                    FROM Schools.dbo.Schools S
                    JOIN Schools.dbo.Xref_School_Leader XSL
                    ON S.School_ID = XSL.School_ID
                    JOIN Schools.dbo.School_Leader SL
                    ON XSL.School_Leader_ID = SL.School_Leader_ID
                    WHERE Academic_Year_Closed IS NULL
                    AND Year_Opened < 2013
                    AND XSL.date_ended IS NULL
                    ")

attrition.query <- ("SELECT
                          School_ID AS Site_ID
                          ,1 AS Site_Level
                          ,Attrition_Rate
                          FROM v_Report_Card_Attrition

                          UNION

                     SELECT
                          Cluster_ID AS Site_ID
                          ,2 AS Site_Level
                          ,Attrition_Rate
                          FROM v_Report_Card_Region_Attrition

                          ")

fte.query <- ("SELECT
                  School_ID AS Site_ID
                  ,Cluster_ID
                  ,FTE
                  ,REPORT_CARD_2013
                  FROM v_Teacher_Counts_By_Academic_Year_Region_RC2013
                  WHERE REPORT_CARD_2013 = 'INCLUDED'
                  AND FTE IS NOT NULL
                  ")

retention.query <- ("SELECT
                        Teacher_ID
                        --,School_ID AS Site_ID
                        ,Cluster_ID AS Site_ID
                        ,Teaching_Start_Date
                        ,Teaching_End_Date
                        ,Went_Id
                        ,Denominator
                        ,Retained_School
                        ,Retained_KIPP
                        FROM v_Teacher_Retention_2013
                        ")


##Note: I'm keeping this query on a separate file because it's FUCKING HUGE.
source("Alumni_R_query.R")

growth.query <- ("SELECT
                      *
                      FROM v_growth_NRT_RC2013_SL
                      ")

growth.region.query <- ("SELECT
                          *
                        FROM v_growth_NRT_RC2013_Type
                        ")

quartile.query <- ("SELECT
                     School_ID AS Site_ID
                    ,1 AS Site_Level
                    ,Sub_Test_Name
                    ,Season
                    ,Grade_When_Taken_int
                    ,Graph_Label
                    ,Percent_Below_25_NPR
                    ,Percent_At_25_Below_50_NPR
                    ,Percent_At_50_Below_75_NPR
                    ,Percent_At_Above_75_NPR
                    FROM Report_Card.dbo.v_School_Quartile_current_2013

                    UNION

                    SELECT
                     Region_ID AS Cluster_ID
                    ,2 AS Site_Level
                    ,Sub_Test_Name
                    ,Season
                    ,Grade_When_Taken_int
                    ,Graph_Label
                    ,Percent_Below_25_NPR
                    ,Percent_At_25_Below_50_NPR
                    ,Percent_At_50_Below_75_NPR
                    ,Percent_At_Above_75_NPR
                    FROM Report_Card.dbo.v_Region_Quartile_current_2013
                  ")
    
statescore.query <- ("SELECT
             State_ID
            ,1 AS Site_Level
            ,AC_Year
            ,Grade
            ,School_ID AS Site_ID
            ,Subtest_ID
            ,Subtest_Name
            ,Subtest_Cat_RC_ID
            ,Score_Grouping_Name
            ,Score_Grouping_Cat_ID
            ,State_Num_Tested
            ,State_Scores_Percent
            ,District_Num_Tested
            ,District_Scores_Percent
            ,School_Num_Tested
            ,School_Scores_Percent
            FROM Report_Card.dbo.v_State_Scores_RC_2013
            WHERE AC_Year = 2013
            AND Score_Grouping_Cat_ID IN (2,3)

            UNION

            SELECT
             State_ID
            ,2 AS Site_Level
            ,Academic_Year AS AC_Year
            ,Grade
            ,Cluster_ID AS Site_ID
            ,999 AS Subtest_ID
            ,'N/A' AS Subtest_Name
            ,Subtest_Cat_RC_ID
            ,Score_Grouping_Name
            ,Score_Grouping_Cat_ID
            ,State_Weighted_Num_Tested AS State_Num_Tested
            ,State_Weighted_Score_Percent AS State_Scores_Percent
            ,District_Weighted_Num_Tested AS District_Num_Tested
            ,District_Weighted_Score_Percent AS District_Scores_Percent
            ,Region_Num_Tested AS School_Num_Tested
            ,Region_Score_Percent AS School_Scores_Percent
            FROM Report_Card.dbo.v_Region_Weighted_State_Scores_Stacked_Graph_current
            WHERE Academic_Year = 2013
            AND Score_Grouping_Cat_ID IN (2,3)
            ")
  
demographics.query <- ("SELECT 
            School_ID AS Site_ID
           ,1 AS Site_Level
           ,Display_Name
           ,Total_Students_Num
           ,Male_Students_Percent
           ,Female_Students_Percent
           ,Black_Students_Percent
           ,Latino_Students_Percent
           ,Asian_Students_Percent
           ,White_Students_Percent
           ,Native_Students_Percent
           ,Pacific_Students_Percent
           ,TwoMoreRaces_Students_Percent
           ,Special_Needs_Percent
           ,F_and_R_Meals_Percent
           FROM Report_Card.dbo.v_Student_Demographics_all
           WHERE PP_ID = 36

           UNION

           SELECT
            Cluster_ID
           ,2 AS Site_Level
           ,Cluster_Name AS Display_Name
           ,Total_Students_Num 
           ,Male_Students_Percent
           ,Female_Students_Percent
           ,Black_Students_Percent
           ,Latino_Students_Percent
           ,Asian_Students_Percent
           ,White_Students_Percent
           ,Native_Students_Percent
           ,Pacific_Students_Percent
           ,TwoMoreRaces_Students_Percent
           ,Special_Needs_Percent
           ,F_and_R_Meals_Percent
           FROM Report_Card.dbo.v_Region_Student_Demographics_all
           WHERE PP_ID = 36
           ")
  
school.raw <- sqlQuery(s, school.query, stringsAsFactors=FALSE)
region.raw <- sqlQuery(c, region.query, stringsAsFactors=FALSE)
schoolleader.raw <- sqlQuery(s, schoolleader.query, stringsAsFactors = FALSE)
growth.raw <- sqlQuery(rc, growth.query, stringsAsFactors=FALSE)
growth.region.raw <- sqlQuery(rc, growth.region.query, stringsAsFactors=FALSE)
attrition.raw <- sqlQuery(rc, attrition.query, stringsAsFactors=FALSE)
squarefoot.raw <- sqlQuery(s, square.footage.query, stringsAsFactors=FALSE)
fte.raw <- sqlQuery(rc, fte.query, stringsAsFactors=FALSE)
retention.raw <- sqlQuery(rc, retention.query, stringsAsFactors=FALSE)
quartile.raw <- sqlQuery(rc, quartile.query, stringsAsFactors=FALSE)
statescore.raw <- sqlQuery(ss, statescore.query, stringsAsFactors=FALSE)
demographics.raw <- sqlQuery(rc, demographics.query, stringsAsFactors=FALSE)
footnotes.raw <- read.csv(paste(data.path,"footnotes.csv", sep=""), header=TRUE, stringsAsFactors=FALSE)
footnotes.region.raw <- read.csv(paste(data.path,"footnotes.region.csv", sep=""), header=TRUE, stringsAsFactors=FALSE)
staterating.raw <- read.csv(paste(data.path,"2012-13_state_ratings.csv", sep=""), header=TRUE, stringsAsFactors=FALSE)

odbcClose(s)
odbcClose(c)
odbcClose(rc)
odbcClose(as)
odbcClose(ss)


dput(school.raw, paste(data.path,"school.raw.Rda", sep=""))
dput(region.raw, paste(data.path,"region.raw.Rda", sep=""))
dput(schoolleader.raw, paste(data.path,"schoolleader.raw.Rda", sep=""))
dput(attrition.raw, paste(data.path,"attrition.raw.Rda", sep=""))
dput(squarefoot.raw , paste(data.path,"squarefoot.raw.Rda", sep=""))
dput(fte.raw, paste(data.path,"fte.raw.Rda", sep=""))
dput(retention.raw, paste(data.path,"retention.raw.Rda", sep=""))
dput(growth.raw, paste(data.path,"growth.raw.Rda", sep=""))
dput(growth.region.raw, paste(data.path,"growth.region.raw.Rda", sep=""))
dput(quartile.raw, paste(data.path,"quartile.raw.Rda", sep=""))
dput(statescore.raw, paste(data.path,"statescore.raw.Rda", sep=""))
dput(demographics.raw, paste(data.path,"demographics.raw.Rda", sep=""))
dput(footnotes.raw, paste(data.path,"footnotes.raw.Rda", sep=""))
dput(footnotes.region.raw, paste(data.path,"footnotes.region.raw.Rda", sep=""))
dput(staterating.raw, paste(data.path,"staterating.raw.Rda", sep=""))
dput(attainment.region.raw, paste(data.path,"attainment.region.raw.Rda", sep=""))
dput(assessment.region.raw, paste(data.path,"assessment.region.raw.Rda", sep=""))
dput(assessment.school.raw, paste(data.path,"assessment.school.raw.Rda", sep=""))

#write.csv(statescore.raw, file = 'statescore_raw.csv')
  
break
}

while(formatdata == 1){
  
#get data
school.raw <- dget(paste(data.path,"school.raw.Rda", sep=""))
region.raw <- dget(paste(data.path,"region.raw.Rda", sep=""))
schoolleader.raw <- dget(paste(data.path,"schoolleader.raw.Rda", sep=""))
attrition.raw <- dget(paste(data.path,"attrition.raw.Rda", sep=""))
squarefoot.raw <- dget(paste(data.path,"squarefoot.raw.Rda", sep=""))
fte.raw <- dget(paste(data.path,"fte.raw.Rda", sep=""))
retention.raw <- dget(paste(data.path,"retention.raw.Rda", sep=""))
growth.raw <- dget(paste(data.path,"growth.raw.Rda", sep=""))
growth.region.raw <- dget(paste(data.path,"growth.region.raw.Rda", sep=""))
quartile.raw <- dget(paste(data.path,"quartile.raw.Rda", sep=""))
statescore.raw <- dget(paste(data.path,"statescore.raw.Rda", sep=""))
demographics.raw <- dget(paste(data.path,"demographics.raw.Rda", sep=""))
footnotes.raw <- dget(paste(data.path,"footnotes.raw.Rda", sep=""))
footnotes.region.raw <- dget(paste(data.path,"footnotes.region.raw.Rda", sep=""))
staterating.raw <- dget(paste(data.path,"staterating.raw.Rda", sep=""))
attainment.region.raw <- dget(paste(data.path,"attainment.region.raw.Rda", sep=""))
assessment.region.raw <- dget(paste(data.path,"assessment.region.raw.Rda", sep=""))
assessment.school.raw <- dget(paste(data.path,"assessment.school.raw.Rda", sep=""))


###########################################format school data########################################
school.mod <- school.raw
#clean up school names
school.mod$graph_name <- gsub(":","",school.mod$Display_Name)
school.mod$graph_name <- gsub(",","",school.mod$graph_name)
school.mod$graph_name <- gsub(" ","_",school.mod$graph_name)
school.mod$graph_name <- gsub("&", "and",school.mod$graph_name)
#format mailing address
school.mod$address <- paste(school.mod$Address_1," ", school.mod$Address_2," ", school.mod$City,", ", school.mod$State," ", as.character(school.mod$Zipcode), sep="")
school.mod$grade_range <- paste(school.mod$Grade_From,"-",school.mod$Grade_Thru, sep="")

###########################################format region data########################################
region.mod <- region.raw
#clean up region names
region.mod$graph_name <- gsub(":","",region.mod$Region_Name)
region.mod$graph_name <- gsub(",","",region.mod$graph_name)
region.mod$graph_name <- gsub(" ","_",region.mod$graph_name)
#format mailing address
region.mod$address <- paste(region.mod$Address_1," ",region.mod$Address_2," ", region.mod$City,", ", region.mod$State," ", as.character(region.mod$Zip), sep="")
region.mod$leader_name <- paste(region.mod$first_name, " ", region.mod$last_name)

############################################format school leader data################################
schoolleader.mod <- schoolleader.raw
schoolleader.mod$leader_name <- paste(schoolleader.mod$first_name, " ", schoolleader.mod$last_name)
schoolleader.mod$count <- sapply(1:length(schoolleader.mod$Site_ID), function(i)sum(schoolleader.mod$Site_ID[i]==schoolleader.mod$Site_ID[1:i]))
schoolleader.mod <- reshape(schoolleader.mod, timevar = "count", 
                                              idvar = c("Site_ID"), 
                                              direction = "wide")
schoolleader.mod$leader_name <- paste(schoolleader.mod$leader_name.1, " & ", schoolleader.mod$leader_name.2, sep="")
schoolleader.mod$leader_name <- gsub(" & NA","", schoolleader.mod$leader_name)


############################################format attrition data####################################
attrition.mod <- attrition.raw
attrition.mod$Attrition_Rate <- round(attrition.mod$Attrition_Rate, digits = 0)
attrition.mod$attrition_print <- paste(as.character(attrition.mod$Attrition_Rate), "%", sep="")

#############################################format square footage data##############################
squarefoot.mod <- squarefoot.raw
squarefoot.mod$squarefoot_print <- paste(as.character(squarefoot.mod$building_square_footage), " sq ft.", sep="")

############################################format fte data##########################################
fte.mod <- fte.raw
fte.mod <- ddply(fte.mod, .(Site_ID), summarize, teachers = sum(FTE))
fte.mod$teachers <- round(fte.mod$teachers, 0)

fte.region.mod <- fte.raw
fte.region.mod <- ddply(fte.region.mod, .(Cluster_ID), summarize, teachers = sum(FTE))
fte.region.mod$teachers <- round(fte.region.mod$teachers, 0)

############################################format retention data####################################
retention.mod <- retention.raw
#I update the SQL view to calculate this stuff, so I probably don't need to do any categorization
retention.mod <- subset(retention.mod, select=-c(Teacher_ID, Teaching_Start_Date, Teaching_End_Date, Went_Id))
retention.mod <- aggregate(x = retention.mod[, 2:4], by = list(Site_ID = retention.mod$Site_ID), FUN = sum)
retention.mod$Retained_KIPP <- (retention.mod$Retained_School + retention.mod$Retained_KIPP)
retention.mod <- reshape(retention.mod,
                  varying = c("Retained_School", "Retained_KIPP"),
                  v.names = "count",
                  timevar = "retention_type",
                  times = c("Retained_School", "Retained_KIPP"),
                  new.row.names = 1:1000,
                  direction = "long")

retention.mod$percent <- retention.mod$count / retention.mod$Denominator
retention.mod$percent <- retention.mod$percent * 100
retention.mod$percent <- round(retention.mod$percent, 0)
retention.mod$print <- paste(retention.mod$percent, "%", sep="")


############################################format footnotes if needed###############################
footnotes.mod <- footnotes.raw
footnotes.region.mod <- footnotes.region.raw

############################################formate state rating data################################
staterating.mod <- staterating.raw
#removes sites where there is no state rating.
staterating.mod <- staterating.mod[staterating.mod$Rating.System != "N/A",]

########################################format Alumni Salesforce stuff###############################
attainment.region.mod <- attainment.region.raw
assessment.region.mod <-assessment.region.raw
assessment.school.mod <- assessment.school.raw

#remove data for NOLA
attainment.region.mod <- attainment.region.mod[attainment.region.mod$Region_ID != 10,]
#separate single sites for attainment
attainment.region.mod$level <- ifelse(attainment.region.mod$Region_ID > 1000,  1,  2)
attainment.region.mod$Region_ID <- ifelse(attainment.region.mod$level == 1, attainment.region.mod$Region_ID / 100, attainment.region.mod$Region_ID)
#format graduation rates
attainment.region.mod$grad_print <- (attainment.region.mod$Grad_Rate * 100)
attainment.region.mod$grad_print <- paste(attainment.region.mod$grad_print, "%", sep="")
attainment.region.mod$grad_count <- paste(attainment.region.mod$Graduated, "/", attainment.region.mod$Denominator, sep="")
#format matriculation rates
attainment.region.mod$matric_print <- (attainment.region.mod$Matric_Rate * 100)
attainment.region.mod$matric_print <- paste(attainment.region.mod$matric_print, "%", sep="")
attainment.region.mod$matric_count <- paste(attainment.region.mod$Matriculated, "/", attainment.region.mod$Denominator, sep="")



#region assessment
assessment.region.mod$level <- 2
#format ACT participation
assessment.region.mod$act_pct <- (round((assessment.region.mod$N_ACT / assessment.region.mod$N_Students),2) * 100)
assessment.region.mod$act_pct <- paste(assessment.region.mod$act_pct, "%", sep="")
assessment.region.mod$act_count <- paste(assessment.region.mod$N_ACT, "/", assessment.region.mod$N_Students, sep="")
#format SAT participation
assessment.region.mod$sat_pct <- (round((assessment.region.mod$N_SAT / assessment.region.mod$N_Students),2) * 100)
assessment.region.mod$sat_pct <- paste(assessment.region.mod$sat_pct, "%", sep="")
assessment.region.mod$sat_count <- paste(assessment.region.mod$N_SAT, "/", assessment.region.mod$N_Students, sep="")
#format AP passing rate
assessment.region.mod$ap_print1 <- (assessment.region.mod$Passing_AP * 100)
assessment.region.mod$ap_print1 <- paste(assessment.region.mod$ap_print1, "%", sep="")
assessment.region.mod$ap_print2 <- (assessment.region.mod$Passing_AP_2 * 100)
assessment.region.mod$ap_print2 <- paste(assessment.region.mod$ap_print2, "%", sep="")
assessment.region.mod$ap_count <- paste(assessment.region.mod$N_AP, "/", assessment.region.mod$N_Students, sep="")

#school assessment
assessment.school.mod$level <- 1
#format ACT participation
assessment.school.mod$act_pct <- (round((assessment.school.mod$N_ACT / assessment.school.mod$N_Students),2) * 100)
assessment.school.mod$act_pct <- paste(assessment.school.mod$act_pct, "%", sep="")
assessment.school.mod$act_count <- paste(assessment.school.mod$N_ACT, "/", assessment.school.mod$N_Students, sep="")
#format SAT participation
assessment.school.mod$sat_pct <- (round((assessment.school.mod$N_SAT / assessment.school.mod$N_Students),2) * 100)
assessment.school.mod$sat_pct <- paste(assessment.school.mod$sat_pct, "%", sep="")
assessment.school.mod$sat_count <- paste(assessment.school.mod$N_SAT, "/", assessment.school.mod$N_Students, sep="")
#format AP passing rate
assessment.school.mod$ap_print1 <- (assessment.school.mod$Passing_AP * 100)
assessment.school.mod$ap_print1 <- paste(assessment.school.mod$ap_print1, "%", sep="")
assessment.school.mod$ap_print2 <- (assessment.school.mod$Passing_AP_2 * 100)
assessment.school.mod$ap_print2 <- paste(assessment.school.mod$ap_print2, "%", sep="")
assessment.school.mod$ap_count <- paste(assessment.school.mod$N_AP, "/", assessment.school.mod$N_Students, sep="")

############################################format growth data#######################################
growth.mod <- growth.raw
growth.mod$Percent_Met_Growth_Target <- paste(as.character(growth.mod$Percent_Met_Growth_Target), "%", sep="")

growth.region.mod <- growth.region.raw
growth.region.mod$Percent_Met_Growth_Target <- paste(as.character(growth.region.mod$Percent_Met_Growth_Target), "%", sep="")

###########################################format quartile data######################################
quartile.mod <- quartile.raw
#hardcode TECH Valley's numbers
quartile.mod <- rbind(quartile.mod,list(46,1,"Mathematics","FALL2",5,"Fall 5th (13)",20,60,20,0))
quartile.mod <- rbind(quartile.mod,list(46,1,"Mathematics","FALL2",6,"Fall 6th (13)",13,32,38,17))
quartile.mod <- rbind(quartile.mod,list(46,1,"Mathematics","FALL2",7,"Fall 7th (13)",17,38,35,10))
quartile.mod <- rbind(quartile.mod,list(46,1,"Mathematics","FALL2",8,"Fall 8th (13)",7,14,58,21))
quartile.mod <- rbind(quartile.mod,list(46,1,"Reading","FALL2",5,"Fall 5th (13)",80,20,0,0))
quartile.mod <- rbind(quartile.mod,list(46,1,"Reading","FALL2",6,"Fall 6th (13)",30,43,20,9))
quartile.mod <- rbind(quartile.mod,list(46,1,"Reading","FALL2",7,"Fall 7th (13)",13,38,36,14))
quartile.mod <- rbind(quartile.mod,list(46,1,"Reading","FALL2",8,"Fall 8th (13)",0,19,47,35))


#set graph values for percent_in_quartile
quartile.mod$Percent_Below_25_NPR <- (quartile.mod$Percent_Below_25_NPR * -1)
quartile.mod$Percent_At_25_Below_50_NPR <- (quartile.mod$Percent_At_25_Below_50_NPR* -1)

#reshape data wide to long
quartile.mod <- reshape(quartile.mod,
                    varying = c("Percent_Below_25_NPR", "Percent_At_25_Below_50_NPR", "Percent_At_50_Below_75_NPR", "Percent_At_Above_75_NPR"),
                    v.names = "percent_at_quartile",
                    timevar = "quartile",
                    times = c("Percent_Below_25_NPR", "Percent_At_25_Below_50_NPR", "Percent_At_50_Below_75_NPR", "Percent_At_Above_75_NPR"),
                    new.row.names = 1:10000,
                    direction = "long")



#generate order for bar stacking
quartile.mod$order <- ifelse(quartile.mod$quartile == "Percent_At_Above_75_NPR", 4, ifelse(quartile.mod$quartile == "Percent_At_50_Below_75_NPR", 3, ifelse(quartile.mod$quartile == "Percent_At_25_Below_50_NPR",1, 2)))

#generate facet order
quartile.mod$Sub_Test_Name <- factor(quartile.mod$Sub_Test_Name,
                                    levels = c("Mathematics", "Reading"))


#generate order for bar sequence
quartile.mod$sequence <- paste(quartile.mod$Grade_When_Taken_int, quartile.mod$Season)

#Create section labels with proper order.
quartile.mod <- subset(quartile.mod, select=-c(id))
attach(quartile.mod)
quartile.mod <- quartile.mod[order(Site_Level,Site_ID,Sub_Test_Name,sequence),] 
detach(quartile.mod)


#generate labels for graph
quartile.mod$label <- abs(quartile.mod$percent_at_quartile)

#############################################format statescore data####################################################
statescore.mod <- statescore.raw
#transform from wide to long
statescore.mod <- reshape(statescore.mod,
                             varying = c("State_Scores_Percent", "District_Scores_Percent", "School_Scores_Percent"),
                             v.names = "score",
                             timevar = "score_level",
                             times = c("State_Scores_Percent", "District_Scores_Percent", "School_Scores_Percent"),
                             new.row.names = 1:10000,
                             direction = "long")

#multiply percentage
statescore.mod$score <- (statescore.mod$score * 100)
#relabel school and district for ordering
statescore.mod$score_level <- gsub("School", "KIPP", statescore.mod$score_level)
statescore.mod$score_level <- gsub("District", "Local_District", statescore.mod$score_level)
#set column order
statescore.mod$order <- (ifelse(statescore.mod$score_level == "KIPP_Scores_Percent", 1, ifelse(statescore.mod$score_level == "Local_District_Scores_Percent", 2, 3)))
#set ordering for graphs
statescore.mod$order <- as.integer(paste(statescore.mod$order, statescore.mod$Score_Grouping_Cat_ID, sep=""))
#fix Texas labels
statescore.mod$Score_Grouping_Name <- gsub("Met the standard", "Level II", statescore.mod$Score_Grouping_Name)
statescore.mod$Score_Grouping_Name <- gsub("Commended Performance", "Level III", statescore.mod$Score_Grouping_Name)
#set labels for buckets
statescore.mod$score_stack <- paste(statescore.mod$score_level, statescore.mod$Score_Grouping_Name, sep= "_")
#replace underscores
statescore.mod$score_stack <- gsub("_"," ", statescore.mod$score_stack)
#remove "score" because it looks stupid :/
statescore.mod$score_stack <- gsub(" Scores Percent ", " ", statescore.mod$score_stack)
#make order discrete for graphing
statescore.mod$order <- as.character(statescore.mod$order)
#cut trailing spaces
statescore.mod$Subtest_Name <- gsub("[[:space:]]*$","", statescore.mod$Subtest_Name)
#save integer grade
statescore.mod$grade_int <- statescore.mod$Grade
#rename grade to sub if applicable
statescore.mod$grade_label <- as.character(statescore.mod$Grade)
statescore.mod$grade_label[statescore.mod$grade_label=="99" & statescore.mod$Site_Level==2] <- "EOC"
 #footnote.1 <- footnotes.mod[footnotes.mod$School_ID== s & footnotes.mod$Footnote_Number == 1,]
statescore.mod$grade_label[statescore.mod$grade_label=="99" & statescore.mod$Site_Level==1] <- statescore.mod$Subtest_Name[statescore.mod$grade_label=="99"]
#fix labeling for CA schools
statescore.mod$grade_label[statescore.mod$Site_ID ==58 & statescore.mod$Site_Level==1] <- paste(statescore.mod$Subtest_Name[statescore.mod$Site_ID == 58 & statescore.mod$Site_Level==1], statescore.mod$grade_label[statescore.mod$Site_ID == 58 & statescore.mod$Site_Level==1], sep = " ")
statescore.mod$grade_label[statescore.mod$Site_ID ==73 & statescore.mod$Site_Level==1] <- paste(statescore.mod$Subtest_Name[statescore.mod$Site_ID == 73 & statescore.mod$Site_Level==1], statescore.mod$grade_label[statescore.mod$Site_ID == 73 & statescore.mod$Site_Level==1], sep = " ")
statescore.mod$grade_label[statescore.mod$Site_ID ==37 & statescore.mod$Site_Level==1] <- paste(statescore.mod$Subtest_Name[statescore.mod$Site_ID == 37 & statescore.mod$Site_Level==1], statescore.mod$grade_label[statescore.mod$Site_ID == 37 & statescore.mod$Site_Level==1], sep = " ")

#reorder(levels(statescore.mod$grade_label), c(8,9,10,1,2,3,4,5,6,7,11,12,13,15,16,14,17,18,19,20,21,22,28,29,23,24,25,26,27,30,31,32,33,34,35,37,36,38,39,40,41,43,42,44,45,46,47,48))
#statescore.mod$grade_label_order <- factor(statescore.mod$grade_label, levels=c(reorder(levels(statescore.mod$grade_label), c(8,9,10,1,2,3,4,5,6,7,11,12,13,15,16,14,17,18,19,20,21,22,28,29,23,24,25,26,27,30,31,32,33,34,35,37,36,38,39,40,41,43,42,44,45,46,47,48))))



#truncate long names >_<
statescore.mod$grade_label <- gsub("English Language Arts", "ELA", statescore.mod$grade_label)
statescore.mod$grade_label <- gsub("Literature & Composition", "Lit. & Comp.", statescore.mod$grade_label)
statescore.mod$grade_label <- gsub("Global History & Geography", "Global Hist. & Geog.", statescore.mod$grade_label)
statescore.mod$grade_label <- gsub("Comprehensive English", "Comp. Eng.", statescore.mod$grade_label)
statescore.mod$grade_label <- gsub("Living Environment", "Living Env.", statescore.mod$grade_label)
statescore.mod$grade_label <- gsub("English I Reading", "Eng I Read.", statescore.mod$grade_label)
statescore.mod$grade_label <- gsub("English II Reading", "Eng II Read", statescore.mod$grade_label)
statescore.mod$grade_label <- gsub("English III Reading", "Eng III Read.", statescore.mod$grade_label)
statescore.mod$grade_label <- gsub("English I Writing", "Eng I Write", statescore.mod$grade_label)
statescore.mod$grade_label <- gsub("English II Writing", "Eng II Write", statescore.mod$grade_label)
statescore.mod$grade_label <- gsub("English III Writing", "Eng III Write", statescore.mod$grade_label)
statescore.mod$grade_label <- gsub("World History", "W. Hist.", statescore.mod$grade_label)
statescore.mod$grade_label <- gsub("World Geography", "W. Geog.", statescore.mod$grade_label)

#fix facet ordering
statescore.mod$grade_label <- factor(statescore.mod$grade_label)
order.value <- levels(statescore.mod$grade_label)
order.value <- as.data.frame(order.value)
order.lookup <- c(8,9,0,1,2,3,4,5,6,7,11,12,13,15,16,14,17,18,19,20,21,22,28,29,23,24,25,26,27,30,31,32,33,34,35,37,36,38,39,40,41,43,42,44,45,46,47,48)
order.lookup <- as.data.frame(order.lookup)
statescore.order <- cbind(order.value, order.lookup)
statescore.order$order.value <- as.character(statescore.order$order.value)
statescore.order$order.lookup <- as.integer(statescore.order$order.lookup)

#round floating point scores
statescore.mod$score <- round(statescore.mod$score, 0)

#WHY IS SORTING THIS HARD.
statescore.mod <- subset(statescore.mod, select=-c(id))
attach(statescore.mod)
statescore.mod <- statescore.mod[order(Site_Level,State_ID,Site_ID,grade_label,Subtest_Cat_RC_ID,order),] 
detach(statescore.mod)

################################################format demographic data#################################################
demographics.mod <- demographics.raw
#process demographic rates
demographics.mod <- ddply(demographics.mod, .(Site_ID, Site_Level, Display_Name), transform, other_percent = (sum(Native_Students_Percent,
                                                                                                        Pacific_Students_Percent,
                                                                                                        TwoMoreRaces_Students_Percent
                                                                                                        )))
demographics.mod <- subset(demographics.mod, select=-c(Native_Students_Percent,
                                                       Pacific_Students_Percent,
                                                       TwoMoreRaces_Students_Percent
                                                       ))



demographics.mod <- rename(demographics.mod, replace=c("Male_Students_Percent" = "Percent Male",
                                                       "Female_Students_Percent" = "Percent Female",
                                                       "White_Students_Percent" = "Percent White",
                                                       "Black_Students_Percent" = "Percent Black",
                                                       "Latino_Students_Percent" = "Percent Latino",
                                                       "Asian_Students_Percent" = "Percent Asian",
                                                       "other_percent" = "Percent Other",
                                                       "Special_Needs_Percent" = "Percent Special Needs",
                                                       "F_and_R_Meals_Percent" = "Percent Free and Reduced Price Lunch",
                                                       "Total_Students_Num" = "Total Students"
                                                 ))
demographics.mod <- demographics.mod[,c(1,2,3,4,5,6,7,8,9,13,12,10,11)]



#save data
dput(school.mod, paste(data.path, "school.mod.Rda", sep=""))
dput(region.mod, paste(data.path, "region.mod.Rda", sep=""))
dput(schoolleader.mod, paste(data.path, "schoolleader.mod.Rda", sep=""))
dput(attrition.mod, paste(data.path, "attrition.mod.Rda", sep=""))
dput(squarefoot.mod ,paste(data.path, "squarefoot.mod.Rda", sep=""))
dput(fte.mod, paste(data.path, "fte.mod.Rda", sep=""))
dput(fte.region.mod, paste(data.path, "fte.region.mod.Rda", sep=""))
dput(retention.mod, paste(data.path, "retention.mod.Rda", sep=""))
dput(growth.mod, paste(data.path, "growth.mod.Rda", sep=""))
dput(growth.region.mod, paste(data.path, "growth.region.mod.Rda", sep=""))
dput(quartile.mod, paste(data.path, "quartile.mod.Rda", sep=""))
dput(statescore.mod, paste(data.path,"statescore.mod.Rda", sep =""))
dput(demographics.mod, paste(data.path,"demographics.mod.Rda", sep=""))
dput(footnotes.mod, paste(data.path,"footnotes.mod.Rda", sep=""))
dput(footnotes.region.mod, paste(data.path,"footnotes.region.mod.Rda", sep=""))
dput(staterating.mod, paste(data.path,"staterating.mod.Rda", sep=""))
dput(attainment.region.mod, paste(data.path,"attainment.region.mod.Rda", sep=""))
dput(assessment.region.mod, paste(data.path,"assessment.region.mod.Rda", sep=""))
dput(assessment.school.mod, paste(data.path,"assessment.school.mod.Rda", sep=""))

#write.csv(statescore.mod, file = 'statescores_mod.csv')
break
}

#########################################Generate site-level HTML reports###################################
while(publishdata_html == 1) {    

#get data
school.mod <- dget(paste(data.path,"school.mod.Rda", sep=""))
region.mod <- dget(paste(data.path,"region.mod.Rda", sep=""))
schoolleader.mod <- dget(paste(data.path,"schoolleader.mod.Rda", sep=""))
attrition.mod <- dget(paste(data.path,"attrition.mod.Rda", sep=""))
squarefoot.mod <- dget(paste(data.path,"squarefoot.mod.Rda", sep=""))
fte.mod <- dget(paste(data.path, "fte.mod.Rda", sep=""))
fte.region.mod <- dget(paste(data.path, "fte.region.mod.Rda", sep=""))
retention.mod <- dget(paste(data.path, "retention.mod.Rda", sep=""))
growth.mod <- dget(paste(data.path,"growth.mod.Rda", sep=""))
growth.region.mod <- dget(paste(data.path,"growth.region.mod.Rda", sep=""))
quartile.mod <- dget(paste(data.path,"quartile.mod.Rda", sep=""))
statescore.mod <- dget(paste(data.path,"statescore.mod.Rda", sep=""))
demographics.mod <- dget(paste(data.path,"demographics.mod.Rda", sep=""))
footnotes.mod <- dget(paste(data.path,"footnotes.mod.Rda", sep=""))
footnotes.region.mod <- dget(paste(data.path,"footnotes.region.mod.Rda", sep=""))
staterating.mod <- dget(paste(data.path,"staterating.mod.Rda", sep=""))
attainment.region.mod <- dget(paste(data.path,"attainment.region.mod.Rda", sep=""))
assessment.region.mod <- dget(paste(data.path,"assessment.region.mod.Rda", sep=""))
assessment.school.mod <- dget(paste(data.path,"assessment.school.mod.Rda", sep=""))

#set color palettes
quartile.palette <- c( "#CFCCC1", "#FEBC11","#F7941E", "#E6E6E6") 
statescore.palette <- c("#BED75A", "#6EB441", "#E6D2C8", "#C3B4A5", "#E6E6E6", "#B9B9B9")
race.palette <- c("#2479F2", "#004CD2", "#A8D9FF", "#82FFFF", "#D2D2D2")
pie.palette <- c("#D2D2D2", "#2479F2")

for(level in c(2)){


if(level == 1){
#x <- school.mod$Site_ID
#x <- c(24)
x <- c(63)
}
else if(level == 2){
x <- region.mod$Site_ID
#x <- c(4)
}

for(s in x){
  if(level == 1){
  n <- school.mod[school.mod$Site_ID == s,]
  n <- n$graph_name
  f <- school.mod[school.mod$Site_ID == s,]
  f$Region_Name <- gsub(" ","_",f$Region_Name)
  f$Region_Name <- gsub(",","",f$Region_Name)
  f$Region_Name <- gsub("[[:space:]]*$","", f$Region_Name)
  f <- f$Region_Name
  d <- school.mod[school.mod$Site_ID== s,]
  d <- d$Display_Name
  t <- school.mod[school.mod$Site_ID== s,]
  t <- t$Type
  grade_range <- school.mod[school.mod$Site_ID== s,]
  grade_range <- grade_range$grade_range
  sq <- squarefoot.mod[squarefoot.mod$Site_ID == s,]
  sq <- sq$squarefoot_print
  state.rating <- staterating.mod[staterating.mod$School_ID == s,]
  state.rating.label <- state.rating$Rating.System
  state.rating.value <- state.rating$Rating

  ppf <- school.mod[school.mod$Site_ID== s,]
  ppf <- ppf$Per_Pupil_Revenue
  site.leader <- schoolleader.mod[schoolleader.mod$Site_ID== s,]
  if(s==46){site.leader <- "Don Applyrs"} else{site.leader <- site.leader$leader_name}
  site.address <- school.mod[school.mod$Site_ID== s,]
  site.address <- site.address$address
  site.url <- school.mod[school.mod$Site_ID== s,]
  site.url <- site.url$Web_URL
  phone <- school.mod[school.mod$Site_ID == s,]
  phone <- phone$Telephone_1
  fte <- fte.mod[fte.mod$Site_ID== s,]
  fte <- fte$teachers
  footnote.1 <- footnotes.mod[footnotes.mod$School_ID== s & footnotes.mod$Footnote_Number == 1,]
  footnote.1 <- footnote.1$Text
  footnote.2 <- footnotes.mod[footnotes.mod$School_ID== s & footnotes.mod$Footnote_Number == 2,]
  footnote.2 <- footnote.2$Text
  footnote.3 <- footnotes.mod[footnotes.mod$School_ID== s & footnotes.mod$Footnote_Number == 3,]
  footnote.3 <- footnote.3$Text

  hs_scores <- assessment.school.mod[assessment.school.mod$School_ID == s,]
  sat_score <- hs_scores$AVG_SAT
  sat_count <-hs_scores$sat_count
  act_score <- hs_scores$AVG_ACT
  act_count <- hs_scores$act_count
  ap_score1 <- hs_scores$ap_print1
  ap_score2 <- hs_scores$ap_print2
  ap_count <- hs_scores$ap_count
  attainment <- attainment.region.mod[attainment.region.mod$Region_ID == s & attainment.region.mod$level==1,]
  grad_print <- attainment$grad_print
  grad_count <- attainment$grad_count
  matric_print <- attainment$matric_print
  matric_count <- attainment$matric_count
} else if(level == 2){
  n <- region.mod[region.mod$Site_ID == s,]
  n <- n$graph_name
  f <- n
  #f$Region_Name <- gsub(",","",f$Region_Name)
  #f$Region_Name <- gsub("[[:space:]]*$","", f$Region_Name)
  #f <- f$Region_Name
  d <- region.mod[region.mod$Site_ID== s,]
  d <- d$Region_Name
  site.leader <- region.mod[region.mod$Site_ID== s,]
  site.leader <- site.leader$leader_name
  site.address <- region.mod[region.mod$Site_ID== s,]
  site.address <- site.address$address
  site.url <- region.mod[region.mod$Site_ID== s,]
  site.url <- site.url$Website
  phone <- region.mod[region.mod$Site_ID == s,]
  phone <- phone$Phone_Office
  fte <- fte.region.mod[fte.region.mod$Cluster_ID== s,]
  fte <- fte$teachers
  retention.site <- retention.mod[retention.mod$Site_ID ==s & retention.mod$retention_type == "Retained_School",]
  retention.site <- retention.site$print
  retention.kipp <- retention.mod[retention.mod$Site_ID ==s & retention.mod$retention_type == "Retained_KIPP",]
  retention.kipp <- retention.kipp$print

  hs_scores <- assessment.region.mod[assessment.region.mod$Region_ID == s,]
  sat_score <- hs_scores$AVG_SAT
  sat_count <-hs_scores$sat_count
  act_score <- hs_scores$AVG_ACT
  act_count <- hs_scores$act_count
  ap_score1 <- hs_scores$ap_print1
  ap_score2 <- hs_scores$ap_print2
  ap_count <- hs_scores$ap_count
  attainment <- attainment.region.mod[attainment.region.mod$Region_ID == s & attainment.region.mod$level==2,]
  grad_print <- attainment$grad_print
  grad_count <- attainment$grad_count
  matric_print <- attainment$matric_print
  matric_count <- attainment$matric_count
}
  print(s)
  print(n)
#############################################subset attrition data###################################
attrition.print <- subset(attrition.mod$attrition_print, (attrition.mod$Site_ID== s) & (attrition.mod$Site_Level == level))

#############################################subset growth metrics###################################
if(level==1){
  if(s==46){
  growth.Mathematics <- "73%"
  growth.Reading <- "42%"
  }else{
growth.Mathematics <- subset(growth.mod$Percent_Met_Growth_Target, (growth.mod$School_ID== s) & (growth.mod$Sub_Test_Name == "Mathematics"))
growth.Reading <- subset(growth.mod$Percent_Met_Growth_Target, (growth.mod$School_ID== s) & (growth.mod$Sub_Test_Name == "Reading"))
}
}else if(level==2){
growth.region.Mathematics.Middle <- subset(growth.region.mod$Percent_Met_Growth_Target, (growth.region.mod$Region_ID == s) & (growth.region.mod$Sub_Test_Name == "Mathematics") & (growth.region.mod$Type == "M"))
growth.region.Mathematics.Elementary <- subset(growth.region.mod$Percent_Met_Growth_Target, (growth.region.mod$Region_ID == s) & (growth.region.mod$Sub_Test_Name == "Mathematics") & (growth.region.mod$Type == "E"))
growth.region.Reading.Middle <- subset(growth.region.mod$Percent_Met_Growth_Target, (growth.region.mod$Region_ID == s) & (growth.region.mod$Sub_Test_Name == "Reading") & (growth.region.mod$Type == "M"))
growth.region.Reading.Elementary <- subset(growth.region.mod$Percent_Met_Growth_Target, (growth.region.mod$Region_ID == s) & (growth.region.mod$Sub_Test_Name == "Reading") & (growth.region.mod$Type == "E"))
}
#############################################set quartile plot#######################################

#Ideally this would be solved by changing the levels order of the Graph_Label to the alphabetical order of sequence...
#Fuck it. 
#Please note that the order here assigns order based on WHEN THE VALUE SHOWS UP. Not on the order you want each level to be.
ordered_labels <- reorder(unique(quartile.mod$Graph_Label), c(9, 10, 11, 12, 13, 3, 4, 5, 6, 8, 14, 15, 16, 17, 7, 1, 2))
#calculates vertical position for bar labels
quartile.graph <- subset(quartile.mod, (Site_ID== s) & (Site_Level==level))

#calculate label placement for stacked bars
quartile.graph <- ddply(quartile.graph, .(Graph_Label, Sub_Test_Name), transform, pos = (((cumsum(label)) - 0.5*label)))
quartile.graph <- ddply(quartile.graph, .(Graph_Label, Sub_Test_Name), transform, neg = sum(ifelse(order %in% c(1,2), label, 0)))
quartile.graph$pos <- (quartile.graph$pos - quartile.graph$neg)
quartile.graph$Sub_Test_Name <- factor(quartile.graph$Sub_Test_Name, levels = c("Reading", "Mathematics"))

quartile.graph$label <- as.character(quartile.graph$label)
quartile.graph$label[as.integer(quartile.graph$label) < 5] <- ""

x_labels <- subset(ordered_labels, ordered_labels %in% unique(quartile.graph$Graph_Label))
x_labels <- factor(x_labels)

#calculates bar spacing
#max <- 6 #NOTE TO SELF: find a way to make this dynamic...
#bar <- nrow(e) / 8
#max <- ((max * 2) - 1)
#gap <- (1 / ((max - bar) / 2))

#separate positive and negative values for stacked bars
q1 <- subset(quartile.graph, quartile %in% c("Percent_Below_25_NPR", "Percent_At_25_Below_50_NPR"))
q2 <- subset(quartile.graph, quartile %in% c("Percent_At_50_Below_75_NPR", "Percent_At_Above_75_NPR"))

q1$quartile <- q1$quartile <- gsub("_"," ", q1$quartile)
q2$quartile <- q2$quartile <- gsub("_"," ", q2$quartile)

q1$quartile <- factor(q1$quartile,levels = rev(q1$quartile[order(q1$order)]),ordered = TRUE)
q2$quartile <- factor(q2$quartile,levels = rev(q2$quartile[order(q2$order)]),ordered = TRUE)

#plot graph
quartile.plot <- ggplot(quartile.graph)
quartile.plot <- quartile.plot + geom_bar(data = q1, 
                                          aes(x=sequence, 
                                              y=percent_at_quartile, 
                                              fill=quartile, 
                                              order=order), 
                                              stat="identity", 
                                              width=0.5)
quartile.plot <- quartile.plot + geom_bar(data = q2, 
                                          aes(x=sequence, 
                                              y=percent_at_quartile, 
                                              fill=quartile, 
                                              order=order), 
                                              stat="identity", 
                                              width=0.5)
quartile.plot <- quartile.plot + scale_fill_manual(values = quartile.palette, 
                                                   breaks = c("Percent At Above 75 NPR",
                                                              "Percent At 50 Below 75 NPR",
                                                              "Percent At 25 Below 50 NPR",
                                                              "Percent Below 25 NPR"))
quartile.plot <- quartile.plot + facet_grid(~ Sub_Test_Name)
quartile.plot <- quartile.plot + xlab('Season')
quartile.plot <- quartile.plot + geom_hline(yintercept=0)
quartile.plot <- quartile.plot + theme(axis.title.x = element_text(size = rel(1.8)),
                                       axis.ticks.x = element_blank(),
                                       axis.text.x = element_text(size = rel(1.8), angle=30, color = "#333333"), 
                                       strip.text.x = element_text(size = rel(2.5), face='bold', color = "#333333"),
                                       axis.title.y = element_blank(), 
                                       axis.ticks.y = element_blank(),
                                       strip.text.y = element_blank(),
                                       axis.text.y=element_blank(),
                                       legend.background = element_rect(),
                                       legend.margin = unit(1, "cm"),
                                       legend.title = element_blank(),
                                       legend.text = element_text(size = 12, face='bold'),
                                       legend.position = "bottom",
                                       plot.background = element_blank(), 
                                       strip.background = element_blank(),
                                       panel.background = element_blank(),
                                       panel.margin = unit(3, "cm"),
                                       panel.grid.major = element_blank(),
                                       panel.grid.minor = element_blank())

quartile.plot <- quartile.plot + scale_x_discrete("Season", labels = levels(x_labels))
quartile.plot <- quartile.plot + geom_text(aes(x=sequence, order = sequence, y=pos, label = label), size = 8)
quartile.plot <- quartile.plot + guides(fill = guide_legend(nrow = 2))

#################################set state score plot################################################

statescore.graph <- subset(statescore.mod, (Site_ID == s) & (Site_Level == level))
if(level==1){
statescore.graph <- ddply(statescore.graph, .(grade_label, Subtest_Name, score_level), transform, detail_pos = (((cumsum(score)) - 0.5*score)))
statescore.graph <- ddply(statescore.graph, .(grade_label, Subtest_Name, score_level), transform, label = sum(score))
statescore.graph <- ddply(statescore.graph, .(grade_label, Subtest_Name, score_level), transform, pos = (cumsum(score) + 15))
}
else if(level==2){
statescore.graph <- ddply(statescore.graph, .(grade_label, Subtest_Cat_RC_ID, score_level), transform, detail_pos = (((cumsum(score)) - 0.5*score)))
statescore.graph <- ddply(statescore.graph, .(grade_label, Subtest_Cat_RC_ID, score_level), transform, label = sum(score))
statescore.graph <- ddply(statescore.graph, .(grade_label, Subtest_Cat_RC_ID, score_level), transform, pos = (cumsum(score) + 15))
}

#statescore.graph$score_stack <- factor(statescore.graph$score_stack)
#statescore.graph$score_stack <- reorder(levels(statescore.graph$score_stack), c(2,1,4,3,6,5))

 sublist <- unique(unlist(statescore.graph$Subtest_Cat_RC_ID, use.names = FALSE))
#This loop creates a plot for each CRT umbrella category.
for (sub in sublist){
                      statescore.graph.loop <- subset(statescore.graph, Subtest_Cat_RC_ID == sub)
                      statescore.graph.loop$grade_label <- as.character(statescore.graph.loop$grade_label)

                      statescore.order.loop <- subset(statescore.order, order.value %in% unique(statescore.graph.loop$grade_label))
                      #statescore.graph.loop$grade_label <- factor(statescore.graph.loop$grade_label)
                      statescore.order.loop$list <- rank(statescore.order.loop$order.lookup)
                      statescore.order.loop <- arrange(statescore.order.loop,list)
                      levels <- as.vector(statescore.order.loop$order.value)
                      statescore.graph.loop$grade_label <- factor(statescore.graph.loop$grade_label, levels=levels)
                      assign(paste("statescore.graph.", sub, sep = ""), statescore.graph.loop)
                      #grade_labelOrdered <- c(unique(statescore.graph.loop$grade_label_int))

                      #statescore.graph.loop[with(statescore.graph.loop, order(grade_label, as.integer(factor(grade_label_int, grade_labelOrdered)))), ]

                      #statescore.graph.loop$grade_label = reorder(statescore.graph.loop$grade_label_int)

                      statescore.graph.loop$label <- ifelse(statescore.graph.loop$Score_Grouping_Cat_ID == 2, "", statescore.graph.loop$label)

                      #statescore.graph$score_stack <- factor(statescore.graph$score_stack)
                      #statescore.graph$score_stack <- reorder(statescore.graph$score_stack, statescore.graph$order)
                      #statescore_legend <- levels(statescore.graph$score_stack)

                      label_wrap <- function(width = 100) {
                                                           function(variable, value) {
                                                                                      inter <- lapply(strwrap(as.character(value), width=width, simplify=FALSE), 
                                                                                      paste, collapse="\n")
                                                                                      inter <- gsub(paste0("(.{",width,"})"), "\\1\n",inter)
                                                                                     }
                                                          }

                      statescore.plot <- ggplot(statescore.graph.loop, aes(x=reorder(score_level, order), y=score, fill=order))
                      statescore.plot <- statescore.plot + geom_bar(stat="identity", width=1, order=order)
                      statescore.plot <- statescore.plot + scale_fill_manual(values = statescore.palette, breaks = c(unique(statescore.graph.loop$order)), labels = c(unique(statescore.graph.loop$score_stack)))
                      #if(statescore.graph.loop$State_ID=='CA'){
                      #statescore.plot <- statescore.plot + facet_grid(grade_label_int ~ grade_label, labeller = label_wrap(width=15))
                      statescore.plot <- statescore.plot + facet_grid(. ~ grade_label, labeller = label_wrap(width=13))
                      statescore.plot <- statescore.plot + coord_equal(ratio = 0.07)
                      statescore.plot <- statescore.plot + scale_y_continuous(limits = c(0, 120))
                      #statescore.plot <- statescore.plot + coord_fixed(ratio = 0.05)
                      statescore.plot <- statescore.plot + xlab('Grade/Subject')
                      statescore.plot <- statescore.plot + ylab('Percent at Level')
                      statescore.plot <- statescore.plot + theme(axis.title.x = element_blank(),
                                                                 axis.ticks.x = element_blank(),
                                                                 axis.text.x = element_blank(),
                                                                 strip.text.x = element_text(size = 16, face = 'bold', color = "#333333"),
                                                                 axis.title.y = element_blank(),
                                                                 axis.text.y = element_blank(),
                                                                 axis.ticks.y = element_blank(),
                                                                 strip.text.y = element_blank(),
                                                                 #if(statescore.graph.loop$State_ID == 'CA'){strip.text.y = element_text(size = 12, face = 'bold', color = "#4F4F4F")}else {strip.text.y = element_blank()},
                                                                 legend.background = element_rect(),
                                                                 legend.margin = unit(1, "cm"),
                                                                 legend.position = "bottom",
                                                                 legend.title = element_blank(), 
                                                                 legend.text = element_text(size = 12, face = 'bold'),
                                                                 strip.background = element_blank(),
                                                                 plot.background = element_blank(),
                                                                 strip.background = element_blank(),
                                                                 panel.background = element_blank(),
                                                                 panel.margin = unit(0.75, "cm"),
                                                                 panel.grid.major = element_blank(), 
                                                                 panel.grid.minor = element_blank())
                      statescore.plot <- statescore.plot + geom_text(aes(label = label, y = pos), size = 4.8, fontface = 'bold.italic')
                      statescore.plot <- statescore.plot + geom_text(aes(label = score, y = detail_pos), size = 4.1)
                      statescore.plot <- statescore.plot + guides(fill = guide_legend(nrow = 2))  

                      assign(paste("statescore.plot.", sub, sep = ""), statescore.plot)
                      rm(statescore.graph.loop)
                      rm(statescore.order.loop)
                      rm(levels)
                    }

#####################################Subset Demographics#############################################
  
demographics.graph <- subset(demographics.mod, (Site_ID == s) & (Site_Level == level))
#demographics.table <- subset(demographics.graph, select=-c(Site_ID, Site_Level, Display_Name))
#split out demographics
demographics.table <- demographics.graph[-c(2,1,3,11,13)]
demographics.table <- t(demographics.table)
  

#####################################Plot Demographics because why not##############################

#Race Graph
race.graph <- subset(demographics.graph, select=c("Percent Black", "Percent Latino", "Percent Asian", "Percent White", "Percent Other"))
race.graph <- reshape(race.graph,
                      varying = c("Percent Black", "Percent Latino", "Percent Asian", "Percent White", "Percent Other"),
                      v.names = "race",
                      timevar = "bucket",
                      times = c("Percent Black", "Percent Latino", "Percent Asian", "Percent White", "Percent Other"),
                      new.row.names = 1:5000,
                      direction = "long")
race.graph$race_print <- paste(as.character(race.graph$race), "%", sep="")
race.max <- max(race.graph$race_print)
race.graph$fraction = race.graph$race / sum(race.graph$race)
race.graph <- race.graph[order(race.graph$fraction, decreasing=TRUE), ]
race.graph$ymax <- cumsum(race.graph$fraction)
race.graph$ymin <- c(0, head(race.graph$ymax, n=-1))
#begin ggplot
race.plot <- ggplot(race.graph, aes(fill=bucket, ymax=ymax, ymin=ymin, xmax=4, xmin=3))
race.plot <- race.plot + geom_text(data=NULL, x = 0, y = 0, label = race.max, colour="#333333", size = 42)
race.plot <- race.plot + scale_fill_manual(values = race.palette, breaks=c("Percent Black", "Percent Latino", "Percent Asian", "Percent White", "Percent Other"))
race.plot <- race.plot + geom_rect()
race.plot <- race.plot + coord_polar(theta="y")
race.plot <- race.plot + xlim(c(0, 4))
race.plot <- race.plot + labs(title="Race/Ethnicity")
race.plot <- race.plot + theme(axis.ticks.x = element_blank(),
                                         axis.text.x = element_blank(),
                                         strip.text.x = element_blank(),
                                         axis.text.y = element_blank(),
                                         axis.ticks.y = element_blank(),
                                         strip.text.y = element_blank(),
                                         legend.position = "none",
                                         strip.background = element_blank(),
                                         plot.background = element_blank(),
                                         plot.title = element_text(size = 42, face='bold', color = "#333333"),
                                         strip.background = element_blank(),
                                         panel.background = element_blank(),
                                         panel.grid.major = element_blank(),
                                         panel.grid.minor = element_blank())

#FRL Graph
frl.graph <- subset(demographics.graph, select=c("Percent Free and Reduced Price Lunch"))
frl.graph$anti <- (100 - frl.graph$"Percent Free and Reduced Price Lunch")
frl.graph <- reshape(frl.graph,
                      varying = c("Percent Free and Reduced Price Lunch", "anti"),
                      v.names = "frl",
                      timevar = "bucket",
                      times = c("Percent Free and Reduced Price Lunch", "anti"),
                      new.row.names = 1:5000,
                      direction = "long")
frl.graph$frl_print <- paste(as.character(frl.graph$frl), "%", sep="")
frl.print <- subset(frl.graph$frl_print, (frl.graph$bucket) == "Percent Free and Reduced Price Lunch")
frl.graph$fraction = frl.graph$frl / sum(frl.graph$frl)
frl.graph <- frl.graph[order(frl.graph$fraction, decreasing=TRUE), ]
frl.graph$ymax <- cumsum(frl.graph$fraction)
frl.graph$ymin <- c(0, head(frl.graph$ymax, n=-1))
#begin ggplot
frl.plot <- ggplot(frl.graph, aes(fill=bucket, ymax=ymax, ymin=ymin, xmax=4, xmin=3))
frl.plot <- frl.plot + geom_text(data=NULL, x = 0, y = 0, label = frl.print, colour="#333333", size = 42)
frl.plot <- frl.plot + scale_fill_manual(values = pie.palette, breaks=c("Percent Free and Reduced Price Lunch", "anti"))
frl.plot <- frl.plot + geom_rect()
frl.plot <- frl.plot + coord_polar(theta="y")
frl.plot <- frl.plot + xlim(c(0, 4))
frl.plot <- frl.plot + labs(title="FRL Rate")
frl.plot <- frl.plot + theme(axis.ticks.x = element_blank(),
                                         axis.text.x = element_blank(),
                                         strip.text.x = element_blank(),
                                         axis.text.y = element_blank(),
                                         axis.ticks.y = element_blank(),
                                         strip.text.y = element_blank(),
                                         legend.position = "none",
                                         strip.background = element_blank(),
                                         plot.background = element_blank(),
                                         plot.title = element_text(size = 64, face='bold', color = "#333333"),
                                         strip.background = element_blank(),
                                         panel.background = element_blank(),
                                         panel.grid.major = element_blank(),
                                         panel.grid.minor = element_blank())

#Attrition Graph
attrition.graph <- subset(attrition.mod, (Site_ID == s) & (Site_Level == level))

attrition.graph$anti <- (100 - attrition.graph$Attrition_Rate)
attrition.graph <- reshape(attrition.graph,
                      varying = c("Attrition_Rate", "anti"),
                      v.names = "attrition",
                      timevar = "bucket",
                      times = c("Attrition_Rate", "anti"),
                      new.row.names = 1:5000,
                      direction = "long")
attrition.graph$fraction = attrition.graph$attrition / sum(attrition.graph$attrition)
attrition.graph <- attrition.graph[order(attrition.graph$fraction), ]
attrition.graph$ymax <- cumsum(attrition.graph$fraction)
attrition.graph$ymin <- c(0, head(attrition.graph$ymax, n=-1))
#begin ggplot
attrition.plot <- ggplot(attrition.graph, aes(fill=bucket, ymax=ymax, ymin=ymin, xmax=4, xmin=3))
attrition.plot <- attrition.plot + geom_text(data=NULL, x = 0, y = 0, label = attrition.print, colour="#333333", size = 42)
attrition.plot <- attrition.plot + scale_fill_manual(values = pie.palette, breaks=c("Attrition_Rate", "anti"))
attrition.plot <- attrition.plot + geom_rect()
attrition.plot <- attrition.plot + coord_polar(theta="y")
attrition.plot <- attrition.plot + xlim(c(0, 4))
attrition.plot <- attrition.plot + ggtitle("Attrition")
attrition.plot <- attrition.plot + theme(axis.ticks.x = element_blank(),
                                         axis.text.x = element_blank(),
                                         axis.text = element_blank(),
                                         strip.text.x = element_blank(),
                                         axis.text.y = element_blank(),
                                         axis.ticks.y = element_blank(),
                                         strip.text.y = element_blank(),
                                         legend.position = "none",
                                         strip.background = element_blank(),
                                         plot.background = element_blank(),
                                         plot.title = element_text(size = 64, face='bold', color = "#333333"),
                                         strip.background = element_blank(),
                                         panel.background = element_blank(),
                                         panel.border = element_blank(),
                                         panel.grid.major = element_blank(),
                                         panel.grid.minor = element_blank(),
                                         strip.text = element_blank())

#SPED Graph
sped.graph <- subset(demographics.graph, select=c("Percent Special Needs"))
sped.graph$anti <- (100 - sped.graph$"Percent Special Needs")
sped.graph <- reshape(sped.graph,
                      varying = c("Percent Special Needs", "anti"),
                      v.names = "sped",
                      timevar = "bucket",
                      times = c("Percent Special Needs", "anti"),
                      new.row.names = 1:5000,
                      direction = "long")
sped.graph$sped_print <- paste(as.character(sped.graph$sped), "%", sep="")
sped.print <- subset(sped.graph$sped_print, (sped.graph$bucket) == "Percent Special Needs")
sped.graph$fraction = sped.graph$sped / sum(sped.graph$sped)
sped.graph <- sped.graph[order(sped.graph$fraction), ]
sped.graph$ymax <- cumsum(sped.graph$fraction)
sped.graph$ymin <- c(0, head(sped.graph$ymax, n=-1))
#begin ggplot
sped.plot <- ggplot(sped.graph, aes(fill=bucket, ymax=ymax, ymin=ymin, xmax=4, xmin=3))
sped.plot <- sped.plot + geom_text(data=NULL, x = 0, y = 0, label = sped.print, colour="#333333", size = 42)
sped.plot <- sped.plot + scale_fill_manual(values = pie.palette, breaks=c("Percent Special Needs", "anti"))
sped.plot <- sped.plot + geom_rect()
sped.plot <- sped.plot + coord_polar(theta="y")
sped.plot <- sped.plot + xlim(c(0, 4))
sped.plot <- sped.plot + labs(title="Special Ed. Rate")
sped.plot <- sped.plot + theme(axis.ticks.x = element_blank(),
                                         axis.text.x = element_blank(),
                                         strip.text.x = element_blank(),
                                         axis.text.y = element_blank(),
                                         axis.ticks.y = element_blank(),
                                         strip.text.y = element_blank(),
                                         legend.position = "none",
                                         strip.background = element_blank(),
                                         plot.background = element_blank(),
                                         plot.title = element_text(size = 64, face='bold', color = "#333333"),
                                         strip.background = element_blank(),
                                         panel.background = element_blank(),
                                         panel.grid.major = element_blank(),
                                         panel.grid.minor = element_blank())

#
#####################################Knit to HTML Template###########################################



if(level==1){
knit("C:/Users/mhilton/Documents/GitHub/Report_Generator/HTML/school_template.Rhtml")
#hatersgonnahate.jpg
file.rename(from="C:/Users/mhilton/Documents/GitHub/Report_Generator/R/school_template.html",to=paste(report.path,"HTML_Reports/",f,"/",n,".html", sep=""))

}else if(level==2){
knit("C:/Users/mhilton/Documents/GitHub/Report_Generator/HTML/region_template.Rhtml")
#hatersgonnahate.jpg
file.rename(from="C:/Users/mhilton/Documents/GitHub/Report_Generator/R/region_template.html",to=paste(report.path,"HTML_Reports/",f,"/",n,".html", sep=""))
}
#I am a terrible programmer. -MH  
if(!exists("statescore.graph.1")) {cat()} else if(nrow(statescore.graph.1) > 0) {rm(statescore.graph.1)} else {cat()}
if(!exists("statescore.graph.2")) {cat()} else if(nrow(statescore.graph.2) > 0) {rm(statescore.graph.2)} else {cat()}
if(!exists("statescore.graph.3")) {cat()} else if(nrow(statescore.graph.3) > 0) {rm(statescore.graph.3)} else {cat()}
if(!exists("statescore.graph.4")) {cat()} else if(nrow(statescore.graph.4) > 0) {rm(statescore.graph.4)} else {cat()}
if(!exists("statescore.graph.5")) {cat()} else if(nrow(statescore.graph.5) > 0) {rm(statescore.graph.5)} else {cat()}
if(!exists("gradeOrdered")) {cat()} else {rm(gradeOrdered)}
if(!exists("footnote.1")) {cat()} else {rm(footnote.1)}
if(!exists("footnote.2")) {cat()} else {rm(footnote.2)}
if(!exists("footnote.3")) {cat()} else {rm(footnote.3)}
if(!exists("grad_print")) {cat()} else {rm(grad_print)}
if(!exists("grad_count")) {cat()} else {rm(grad_count)}
if(!exists("matric_print")) {cat()} else {rm(matric_print)}
if(!exists("matric_count")) {cat()} else {rm(matric_count)}
if(!exists("act_pct")) {cat()} else {rm(act_pct)}
if(!exists("act_count")) {cat()} else {rm(act_count)}
if(!exists("sat_pct")) {cat()} else {rm(sat_pct)}
if(!exists("sat_count")) {cat()} else {rm(sat_count)}
if(!exists("ap_pct1")) {cat()} else {rm(ap_pct1)}
if(!exists("ap_count1")) {cat()} else {rm(ap_count1)}
if(!exists("ap_pct2")) {cat()} else {rm(ap_pct2)}
if(!exists("ap_count2")) {cat()} else {rm(ap_count2)}

######################################Convert HTML to PDF#############################################
#set I/O variables
input <- paste(report.path,"HTML_Reports/",f,"/",n,".html", sep="")
output <- paste(report.path,"PDF_Reports/",f,"/",n,".pdf", sep="")

#updates Batch file. NOTE: This file lives in the wkhtmltopdf directory.
fileConn<-file("C:/Program Files (x86)/wkhtmltopdf/pdf_send.bat")
writeLines(paste("wkhtmltopdf -T 0in -B 0in -L 0in -R 0in --page-width 940px --disable-smart-shrinking"," ",input," ",output, sep=""), fileConn)
close(fileConn)  

#call batch file for command line conversion
system("C:/Users/mhilton/Documents/GitHub/Report_Generator/BAT/pdf_convert.bat")
}
}
break
}

