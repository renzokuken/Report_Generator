###########################################################################################################
#Project DONUT: Fast and Optimized R-based Generator of Excellence                                        #
#Written By: Mike Hilton                                                                                  #
#Last Updated: 2-28-14                                                                                    #
###########################################################################################################
rm(list=ls())

#set directory
wd <- getwd()
if (wd != "C:/Users/mhilton/Documents/GitHub/Report_Generator/R") setwd("C:/Users/mhilton/Documents/GitHub/Report_Generator/R")
#Declare globals

pulldata <- 1

formatdata <- 1

publishdata <- 1

#global file paths
data.path <<- paste("Z:/001_NEW_SNEETCH/Report_Card/2013/Data/")
graph.path <<- paste("Z:/001_NEW_SNEETCH/Report_Card/2013/Output/Print/")


library(RODBC)
library(ggplot2)
library(scales)
library(grid)
library(plyr)
library(knitr)
library(xtable)
library(markdown)
library(Cairo)

while(pulldata == 1) {
  
#Declare ODBC connections
s <- odbcConnect('Schools_stage')
c <- odbcConnect('Clusters_stage')
rc <- odbcConnect('Report_Card_stage')
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
             AND Academic_Year_Opened < 2015
             AND (date_ended IS NULL
             OR C.Cluster_ID = 16)
             ORDER BY Site_ID
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
attrition.raw <- sqlQuery(rc, attrition.query, stringsAsFactors=FALSE)
demographics.raw <- sqlQuery(rc, demographics.query, stringsAsFactors=FALSE)


odbcClose(s)
odbcClose(c)
odbcClose(rc)
odbcClose(ss)


dput(school.raw, paste(data.path,"school.raw.Rda", sep=""))
dput(region.raw, paste(data.path,"region.raw.Rda", sep=""))
dput(attrition.raw, paste(data.path,"attrition.raw.Rda", sep=""))
dput(demographics.raw, paste(data.path,"demographics.raw.Rda", sep=""))
  
break
}

while(formatdata == 1){
  
#get data
school.raw <- dget(paste(data.path,"school.raw.Rda", sep=""))
region.raw <- dget(paste(data.path,"region.raw.Rda", sep=""))
attrition.raw <- dget(paste(data.path,"attrition.raw.Rda", sep=""))
demographics.raw <- dget(paste(data.path,"demographics.raw.Rda", sep=""))



###########################################format school data########################################
school.mod <- school.raw
#clean up school names
school.mod$graph_name <- gsub(":","",school.mod$Display_Name)
school.mod$graph_name <- gsub(",","",school.mod$graph_name)
school.mod$graph_name <- gsub(" ","_",school.mod$graph_name)
school.mod$graph_name <- gsub("&", "and",school.mod$graph_name)
#The file structure for the graphs uses a different naming convention. Ideally these would be merged, but in the meantime I'm using a dirty fix. D:
school.mod$file_name <- gsub("_","",school.mod$graph_name)
school.mod$file_name <- gsub("and", "and", school.mod$file_name)
#format mailing address
school.mod$address <- paste(school.mod$Address_1," ", school.mod$Address_2," ", school.mod$City,", ", school.mod$State," ", as.character(school.mod$Zipcode), sep="")
school.mod$grade_range <- paste(school.mod$Grade_From,"-",school.mod$Grade_Thru, sep="")

###########################################format region data########################################
region.mod <- region.raw
#clean up region names
region.mod$graph_name <- gsub(":","",region.mod$Region_Name)
region.mod$graph_name <- gsub(",","",region.mod$graph_name)
region.mod$graph_name <- gsub(" ","_",region.mod$graph_name)
#The file structure for the graphs uses a different naming convention. Ideally these would be merged, but in the meantime I'm using a dirty fix. D:
region.mod$file_name <- gsub("_","",region.mod$graph_name)
#format mailing address
region.mod$address <- paste(region.mod$Address_1," ",region.mod$Address_2," ", region.mod$City,", ", region.mod$State," ", as.character(region.mod$Zip), sep="")
region.mod$leader_name <- paste(region.mod$first_name, " ", region.mod$last_name)

############################################format attrition data####################################
attrition.mod <- attrition.raw
attrition.mod$Attrition_Rate <- round(attrition.mod$Attrition_Rate, digits = 0)
attrition.mod$attrition_print <- paste(as.character(attrition.mod$Attrition_Rate), "%", sep="")

############################################format demographic data##################################
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
dput(attrition.mod, paste(data.path, "attrition.mod.Rda", sep=""))
dput(demographics.mod, paste(data.path,"demographics.mod.Rda", sep=""))

break
}

#########################################Generate site-level HTML reports###################################
while(publishdata == 1) {    

#get data
school.mod <- dget(paste(data.path,"school.mod.Rda", sep=""))
region.mod <- dget(paste(data.path,"region.mod.Rda", sep=""))
attrition.mod <- dget(paste(data.path,"attrition.mod.Rda", sep=""))
demographics.mod <- dget(paste(data.path,"demographics.mod.Rda", sep=""))

#set color palettes
race.palette <- c("#2479F2", "#004CD2", "#A8D9FF", "#82FFFF", "#D2D2D2")
pie.palette <- c("#D2D2D2", "#2479F2")

for(level in c(1,2)){


if(level == 1){
#x <- school.mod$Site_ID
#x <- c(12, 67, 89, 99, 138, 163, 168)
x <- c(2, 87, 131)
}
else if(level == 2){
x <- region.mod$Site_ID
x <- c(3,19)
}

for(s in x){
  if(level == 1){
  n <- school.mod[school.mod$Site_ID == s,]
  if(s == 62){n <- "KIPP_Charlotte_School_Level"
  }else {n <- n$graph_name}
  f <- school.mod[school.mod$Site_ID == s,]
  f$Region_Name <- gsub(" ","_",f$Region_Name)
  f$Region_Name <- gsub(",","",f$Region_Name)
  f$Region_Name <- gsub("[[:space:]]*$","", f$Region_Name)
  f <- f$Region_Name
  d <- school.mod[school.mod$Site_ID== s,]
  d <- d$Display_Name
  #graph name for export
  png.name <- school.mod[school.mod$Site_ID == s,]
  png.name <- png.name$file_name
  file.name <- paste("S.", png.name, sep = "")

  } else if(level == 2){
  n <- region.mod[region.mod$Site_ID == s,]
  #change name for Charlotte since the school has the same name
  n <- n$graph_name
  f <- n
  d <- region.mod[region.mod$Site_ID== s,]
  d <- d$Region_Name

  #graph name for export
  png.name <- region.mod[region.mod$Site_ID == s,]
  png.name <- png.name$file_name
  file.name <- paste("R.", png.name, sep = "")
}
  print(s)
  print(n)
#############################################subset attrition data###################################
attrition.print <- subset(attrition.mod$attrition_print, (attrition.mod$Site_ID== s) & (attrition.mod$Site_Level == level))


#####################################Subset Demographics#############################################
  
demographics.graph <- subset(demographics.mod, (Site_ID == s) & (Site_Level == level))
#demographics.table <- subset(demographics.graph, select=-c(Site_ID, Site_Level, Display_Name))
#split out reported demographics
demographics.table <- demographics.graph[-c(2,1,3,11,13)]
#transpose data for table placement
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
attrition.plot <- attrition.plot + scale_fill_manual(values = pie.palette, breaks=c("Attrition_Rate", "anti"))
attrition.plot <- attrition.plot + geom_rect()
attrition.plot <- attrition.plot + coord_polar(theta = "y")
attrition.plot <- attrition.plot + xlim(c(0, 4))
#attrition.plot <- attrition.plot + ggtitle("Attrition Rate")
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
attrition.plot <- attrition.plot + geom_text(data=NULL, x = 0, y = 0, label = attrition.print, colour="#333333", size = 60)
attrition.plot <- attrition.plot + geom_text(data=NULL, x = 0, y = 0, vjust=4.2, colour = "#333333", size = 20, label = "Attrition Rate")

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


######################################Export Doughnut Charts to PNG#######################################

graph_path <- paste(graph.path,file.name, "/", sep="")
 #ggsave(filename = paste(graph_path,png.name,"_race_pie.png", sep = ""),plot = race.plot, width=20, height = 20, dpi=300)
 #ggsave(filename = paste(graph_path,png.name,"_frl_pie.png", sep = ""),plot = frl.plot, width=20, height = 20, dpi=300)
 ggsave(filename = paste(graph_path,png.name,"_attrition_pie.png", sep = ""),plot = attrition.plot, width=20, height = 20, dpi=300)
 #ggsave(filename = paste(graph_path,png.name,"_sped_pie.png", sep=""),plot = sped.plot, width=20, height = 20, dpi=300)
}
}
break
}
