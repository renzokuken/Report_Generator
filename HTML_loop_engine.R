
rm(list=ls())

#set directory
wd <- getwd()
if (wd != "C:/Users/mhilton/Documents/GitHub/Report_Generator") setwd("C:/Users/mhilton/Documents/GitHub/Report_Generator")
#Declare globals

pulldata <- 1

formatdata <- 1

publishdata_html <- 1

publishdata_pdf <- 1

data.path <<- paste("C:/Users/mhilton/Documents/R_Data/HTML_Reports/")
report.path <<- paste("C:/Users/mhilton/Documents/R_Graphs/HTML_Reports/")


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
s <- odbcConnect('Schools_prod')
rc <- odbcConnect('Report_Card_prod')
as <- odbcConnect('Attainment_stage')
ss <- odbcConnect('State_Scores_prod')
  
#Declare SQL Queries
school.query <- ("SELECT
             S.School_ID
            ,Type
            ,Display_Name
            ,Web_URL
            ,Address_1
            ,Address_2
            ,City
            ,State
            ,Zipcode
            ,SP.Per_Pupil_Revenue
            FROM Schools.dbo.Schools S
            JOIN DP_Production.dbo.School_Profiles SP
            ON S.School_ID = SP.School_ID
            WHERE Academic_Year_Closed IS NULL
            AND Year_Opened < 2012
            AND PP_ID = 32
            ")

#NOTE: need a separate query to the schools database for cases where N School Leaders > 1
schoolleader.query <- ("SELECT
                     S.School_ID
                    ,SL.school_leader_id
                    ,SL.first_name
                    ,SL.last_name
                    FROM Schools.dbo.Schools S
                    JOIN Schools.dbo.Xref_School_Leader XSL
                    ON S.School_ID = XSL.School_ID
                    JOIN Schools.dbo.School_Leader SL
                    ON XSL.School_Leader_ID = SL.School_Leader_ID
                    WHERE Academic_Year_Closed IS NULL
                    AND Year_Opened < 2012
                    AND XSL.date_ended IS NULL
                    ")

attrition.query <- ("SELECT
                          School_ID
                          ,Attrition_Rate
                          FROM v_Report_Card_Attrition
                          ")

fte.query <- ("SELECT
                  School_ID
                  ,Cluster_ID
                  ,FTE
                  ,REPORT_CARD_2012
                  FROM v_Teacher_Counts_By_Academic_Year_Region_RC2012
                  ")

retention.query <- ("SELECT
                        Teacher_ID
                        ,School_ID
                        ,Cluster_ID
                        ,Teaching_Start_Date
                        ,Teaching_End_Date
                        ,Went_Id
                        FROM v_Teacher_Retention_2012
                        ")

##Note I kept this query on a separate file because it's FUCKING HUGE.
#source("Attainment_query")

growth.query <- ("SELECT
                      *
                      FROM v_growth_NRT_RC2012_SL
                      ")

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
            ,State_Scores_Percent
            ,District_Num_Tested
            ,District_Scores_Percent
            ,School_Num_Tested
            ,School_Scores_Percent
            FROM Report_Card.dbo.v_State_Scores_RC_2012
            WHERE AC_Year = 2012
            AND Score_Grouping_Cat_ID IN (2,3)
            ")
  
demographics.query <- ("SELECT 
            School_ID
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
           FROM Report_Card.dbo.v_Student_Demographics_all2012
           WHERE PP_ID = 32
           ")
  
school.raw <- sqlQuery(s, school.query, stringsAsFactors=FALSE)  
schoolleader.raw <- sqlQuery(s, schoolleader.query, stringsAsFactors = FALSE)
growth.raw <- sqlQuery(rc, growth.query, stringsAsFactors=FALSE)
attrition.raw <- sqlQuery(rc, attrition.query, stringsAsFactors=FALSE)
fte.raw <- sqlQuery(rc, fte.query, stringsAsFactors=FALSE)
retention.raw <- sqlQuery(rc, retention.query, stringsAsFactors=FALSE)
quartile.raw <- sqlQuery(rc, quartile.query, stringsAsFactors=FALSE)
statescore.raw <- sqlQuery(rc, statescore.query, stringsAsFactors=FALSE)
demographics.raw <- sqlQuery(rc, demographics.query, stringsAsFactors=FALSE)


odbcClose(s)
odbcClose(rc)
odbcClose(ss)


dput(school.raw, paste(data.path,"school.raw.Rda", sep=""))
dput(schoolleader.raw, paste(data.path,"schoolleader.raw.Rda", sep=""))
dput(attrition.raw, paste(data.path,"attrition.raw.Rda", sep=""))
dput(fte.raw, paste(data.path,"fte.raw.Rda", sep=""))
dput(retention.raw, paste(data.path,"retention.raw.Rda", sep=""))
dput(growth.raw, paste(data.path,"growth.raw.Rda", sep=""))
dput(quartile.raw, paste(data.path,"quartile.raw.Rda", sep=""))
dput(statescore.raw, paste(data.path,"statescore.raw.Rda", sep=""))
dput(demographics.raw, paste(data.path,"demographics.raw.Rda", sep=""))
  
break
}

while(formatdata == 1){
  
#get data
school.raw <- dget(paste(data.path,"school.raw.Rda", sep=""))
schoolleader.raw <- dget(paste(data.path,"schoolleader.raw.Rda", sep=""))
attrition.raw <- dget(paste(data.path,"attrition.raw.Rda", sep=""))
fte.raw <- dget(paste(data.path,"fte.raw.Rda", sep=""))
retention.raw <- dget(paste(data.path,"retention.raw.Rda", sep=""))
growth.raw <- dget(paste(data.path,"growth.raw.Rda", sep=""))
quartile.raw <- dget(paste(data.path,"quartile.raw.Rda", sep=""))
statescore.raw <- dget(paste(data.path,"statescore.raw.Rda", sep=""))
demographics.raw <- dget(paste(data.path,"demographics.raw.Rda", sep=""))

###########################################format school data########################################
school.mod <- school.raw
#clean up school names
school.mod$Display_Name <- gsub(":","",school.mod$Display_Name)
school.mod$Display_Name <- gsub(",","",school.mod$Display_Name)
school.mod$graph_name <- gsub(" ","_",school.mod$Display_Name)
#format mailing address
school.mod$address <- paste(school.mod$Address_1," ", school.mod$Address_2," ", school.mod$City,", ", school.mod$State," ", as.character(school.mod$Zipcode), sep="")



############################################format school leader data################################
schoolleader.mod <- schoolleader.raw



############################################format attrition data####################################
attrition.mod <- attrition.raw
attrition.mod$Attrition_Rate <- round(attrition.mod$Attrition_Rate, digits = 0)
attrition.mod$attrition_print <- paste(as.character(attrition.mod$Attrition_Rate), "%", sep="")



############################################format growth data#######################################
growth.mod <- growth.raw
growth.mod$Percent_Met_Growth_Target <- paste(as.character(growth.mod$Percent_Met_Growth_Target), "%", sep="")

###########################################format quartile data######################################
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

#generate facet order
quartile.mod$Sub_Test_Name <- factor(quartile.mod$Sub_Test_Name,
                                    levels = c("Mathematics", "Reading"))


#generate order for bar sequence
quartile.mod$sequence <- paste(quartile.mod$Grade_When_Taken_int, quartile.mod$Season)

#Create section labels with proper order.
#Ideally this would be solved by changing the levels order of the Graph_Label to the alphabetical order of sequence...
#F*ck it.
ordered_labels <- reorder(unique(quartile.mod$Graph_Label), c(10, 11, 12, 13, 14, 6, 7, 9, 8, 1, 2, 4, 5, 3))

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
                             new.row.names = 1:5000,
                             direction = "long")

#multiply percentage
statescore.mod$score <- (statescore.mod$score * 100)
#set column order
statescore.mod$order <- (ifelse(statescore.mod$score_level == "School_Scores_Percent", 1, ifelse(statescore.mod$score_level == "District_Scores_Percent", 2, 3)))
#set ordering for graphs
statescore.mod$order <- as.integer(paste(statescore.mod$order, statescore.mod$Score_Grouping_Cat_ID, sep=""))
#set labels for buckets
statescore.mod$score_stack <- paste(statescore.mod$score_level, statescore.mod$Score_Grouping_Name, sep= "_")
#replace underscores
statescore.mod$score_stack <- gsub("_"," ", statescore.mod$score_stack)
#remove "score" because it looks stupid :/
statescore.mod$score_stack <- gsub(" Scores ", " ", statescore.mod$score_stack)
#cut trailing spaces
statescore.mod$Subtest_Name <- gsub("[[:space:]]*$","", statescore.mod$Subtest_Name)
#rename grade to sub if applicable
statescore.mod$Grade <- as.character(statescore.mod$Grade)
statescore.mod$Grade[statescore.mod$Grade=="99"] <- statescore.mod$Subtest_Name[statescore.mod$Grade=="99"]
#round floating point scores
statescore.mod$score <- round(statescore.mod$score, 0)

################################################format demographic data#################################################
demographics.mod <- demographics.raw
#process demographic rates
demographics.mod <- ddply(demographics.mod, .(School_ID, Display_Name), transform, other_percent = (sum(Native_Students_Percent,
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
                                                       "F_and_R_Meals_Percent" = "Percent Free and Reduced Price Lunch"
                                                 ))
demographics.mod <- demographics.mod[,c(1,2,3,4,5,6,7,8,11,9,10)]
                                                                                                                         
                                      

#save data
dput(school.mod, paste(data.path, "school.mod.Rda", sep=""))
dput(schoolleader.mod, paste(data.path, "schoolleader.mod.Rda", sep=""))
dput(attrition.mod, paste(data.path, "attrition.mod.Rda", sep=""))
dput(growth.mod, paste(data.path, "growth.mod.Rda", sep=""))
dput(quartile.mod, paste(data.path, "quartile.mod.Rda", sep=""))
dput(statescore.mod, paste(data.path,"statescore.mod.Rda", sep =""))
dput(demographics.mod, paste(data.path,"demographics.mod.Rda", sep=""))
break
}

#########################################Generate site-level HTML reports###################################
while(publishdata_html == 1) {    
  
#get data
school.mod <- dget(paste(data.path,"school.mod.Rda", sep=""))
schoolleader.mod <- dget(paste(data.path,"schoolleader.mod.Rda", sep=""))
attrition.mod <- dget(paste(data.path,"attrition.mod.Rda", sep=""))
growth.mod <- dget(paste(data.path,"growth.mod.Rda", sep=""))
quartile.mod <- dget(paste(data.path,"quartile.mod.Rda", sep=""))
statescore.mod <- dget(paste(data.path,"statescore.mod.Rda", sep=""))
demographics.mod <- dget(paste(data.path,"demographics.mod.Rda", sep=""))

#set color palettes
quartile.palette <- c( "#CFCCC1", "#FEBC11","#F7941E", "#E6E6E6") 
statescore.palette <- c("#E6D2C8", "#C3B4A5", "#6EB441", "#BED75A", "#E6E6E6", "#B9B9B9")
  
#x <- c(94)
x <- c(3, 5, 52, 86)
for(s in x){
#for(s in school.mod$School_ID){
  n <- school.mod[school.mod$School_ID == s,]
  n <- n$graph_name
  d <- school.mod[school.mod$School_ID == s,]
  d <- d$Display_Name
  t <- school.mod[school.mod$School_ID == s,]
  t <- t$Type
  ppf <- school.mod[school.mod$School_ID == s,]
  ppf <- ppf$Per_Pupil_Revenue
  school.address <- school.mod[school.mod$School_ID == s,]
  school.address <- school.address$address
  school.url <- school.mod[school.mod$School_ID == s,]
  school.url <- school.url$Web_URL
  
  print(s)
  print(n)
#############################################subset attrition data###################################
attrition.print <- subset(attrition.mod$attrition_print, (attrition.mod$School_ID == s))

#############################################subset growth metrics###################################

growth.Mathematics <- subset(growth.mod$Percent_Met_Growth_Target, (growth.mod$School_ID == s) & (growth.mod$Sub_Test_Name == "Mathematics"))
growth.Reading <- subset(growth.mod$Percent_Met_Growth_Target, (growth.mod$School_ID == s) & (growth.mod$Sub_Test_Name == "Reading"))

#############################################set quartile plot#######################################
#calculates vertical position for bar labels
quartile.graph <- subset(quartile.mod, School_ID == s)

#calculate label placement for stacked bars
quartile.graph <- ddply(quartile.graph, .(Graph_Label, Sub_Test_Name), transform, pos = (((cumsum(label)) - 0.5*label)))
quartile.graph <- ddply(quartile.graph, .(Graph_Label, Sub_Test_Name), transform, neg = sum(ifelse(order %in% c(1,2), label, 0)))
quartile.graph$pos <- (quartile.graph$pos - quartile.graph$neg)

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
quartile.plot <- quartile.plot + ylab('Quartile Distribution')
quartile.plot <- quartile.plot + theme(axis.title.x = element_text(size = rel(1.8)),
                                       axis.ticks.x = element_blank(),
                                       axis.text.x = element_text(size = rel(1.8), angle=30), 
                                       strip.text.x = element_text(size = rel(2.5), face='bold', color = "#FEBC11"),
                                       axis.title.y = element_text(size = rel(1.8)), 
                                       axis.ticks.y = element_blank(),
                                       strip.text.y = element_text(size = rel(2.5), face='bold'),
                                       axis.text.y=element_blank(),
                                       legend.background = element_rect(),
                                       legend.margin = unit(1, "cm"),
                                       legend.title = element_blank(),
                                       legend.text = element_text(size = rel(1.2), face='bold'),
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

statescore.graph <- subset(statescore.mod, School_ID == s)
statescore.graph <- ddply(statescore.graph, .(Grade, Subtest_Name, score_level), transform, label = sum(score))
statescore.graph <- ddply(statescore.graph, .(Grade, Subtest_Name, score_level), transform, pos = (cumsum(score) + 15))

 sublist <- unique(unlist(statescore.graph$Subtest_Cat_RC_ID, use.names = FALSE))
for (sub in sublist){
                      statescore.graph.loop <- assign(paste("statescore.graph.", sub, sep = ""),subset(statescore.graph, Subtest_Cat_RC_ID == sub))

                      statescore.graph.loop$label <- ifelse(statescore.graph.loop$Score_Grouping_Cat_ID == 2, "", statescore.graph.loop$label)
  
                      statescore.plot <- ggplot(statescore.graph.loop, aes(x=reorder(score_level, order), y=score, fill=score_stack))
                      statescore.plot <- statescore.plot + geom_bar(stat="identity", width=1, order=order)
                      #statescore.plot <- statescore.plot + scale_fill_manual(values = statescore.palette, breaks = c("School Percent Advanced", "School Percent Proficient", "District Percent Advanced", "District Percent Proficient", "State Percent Advanced", "State Percent Proficient"))
                      statescore.plot <- statescore.plot + scale_fill_manual(values = statescore.palette, breaks = c(unique(statescore.graph.loop$score_stack)))
#I may need to break this out by subject...
#swap formatting for high school CRT tests
#if(t=="H")  statescore.plot <- statescore.plot + facet_wrap(Subtest_Name ~ Grade, ncol = 4) else statescore.plot <- statescore.plot + facet_grid(~ Subtest_Name ~ Grade)
                      statescore.plot <- statescore.plot + facet_grid(Subtest_Cat_RC_ID ~ Grade)

                      statescore.plot <- statescore.plot + coord_equal(ratio = 0.07)
                      statescore.plot <- statescore.plot + scale_y_continuous(limits = c(0, 120))
                      #statescore.plot <- statescore.plot + coord_fixed(ratio = 0.05)
                      statescore.plot <- statescore.plot + xlab('Grade')
                      statescore.plot <- statescore.plot + ylab('Percent at Level')
                      statescore.plot <- statescore.plot + theme(axis.title.x = element_blank(),
                                                                 axis.ticks.x = element_blank(),
                                                                 axis.text.x = element_blank(),
                                                                 strip.text.x = element_text(size = rel(2.2), face = 'bold', color = "#616161"),
                                                                 axis.title.y = element_blank(),
                                                                 axis.text.y = element_blank(),
                                                                 axis.ticks.y = element_blank(),
                                                                 strip.text.y = element_blank(),
                                                                 legend.background = element_rect(),
                                                                 legend.margin = unit(1, "cm"),
                                                                 legend.position = "bottom",
                                                                 legend.title = element_blank(), 
                                                                 legend.text = element_text(size = rel(0.8), face = 'bold'),
                                                                 strip.background = element_blank(),
                                                                 plot.background = element_blank(),
                                                                 strip.background = element_blank(),
                                                                 panel.background = element_blank(),
                                                                 panel.margin = unit(0.75, "cm"),
                                                                 panel.grid.major = element_blank(), 
                                                                 panel.grid.minor = element_blank())
                      statescore.plot <- statescore.plot + geom_text(aes(label = label, y = pos), size = 5.1)
                      statescore.plot <- statescore.plot + guides(fill = guide_legend(nrow = 2))  

                      assign(paste("statescore.plot.", sub, sep = ""), statescore.plot)
                      rm(statescore.graph.loop)
                    }

#####################################Subset Demographics#############################################
  
demographics.graph <- subset(demographics.mod, School_ID == s)
demographics.graph <- subset(demographics.graph, select=-c(School_ID, Display_Name))
demographics.graph <- t(demographics.graph)
  

#####################################Plot Demographics because why not##############################
#
#gender.variables <- names(demographics.graph) %in% c("Percent Male", "Percent Female")
#demographics.variables <- names(demographics.graph) %in% c("Percent Black", "Percent Latino", "Percent Asian", "Percent White", "Percent Other")
#gender.graph <- subset(demographics.graph, select=gender.variables)
#race.graph <- subset(demographics.graph, select=demographics.variables)
#frl.graph <- subset(demographics.graph, select=c("Percent Free and Reduced Price Lunch"))
#attrition.graph <- subset(demographics.graph, select=c("Percent Attrition"))
#sped.graph <- subset(demographics.graph, select=c("Percent Special Needs"))
#sped.graph$Anti <- (100 - sped.graph$Percent Special Needs)
#
#####################################Knit to HTML Template###########################################

knit2html("HTML_template.Rhtml")
#hatersgonnahate.jpg
filename <- paste(report.path,n,"_HTML_Template", sep="")
file.rename(from="HTML_template.html",to=paste(report.path,n,"_HTML_Template.html", sep=""))

#I am a terrible programmer. -MH  
if(!exists("statescore.graph.1")) {cat()} else if(nrow(statescore.graph.1) > 0) {rm(statescore.graph.1)} else {cat()}
if(!exists("statescore.graph.2")) {cat()} else if(nrow(statescore.graph.2) > 0) {rm(statescore.graph.2)} else {cat()}
if(!exists("statescore.graph.3")) {cat()} else if(nrow(statescore.graph.3) > 0) {rm(statescore.graph.3)} else {cat()}
if(!exists("statescore.graph.4")) {cat()} else if(nrow(statescore.graph.4) > 0) {rm(statescore.graph.4)} else {cat()}
if(!exists("statescore.graph.5")) {cat()} else if(nrow(statescore.graph.5) > 0) {rm(statescore.graph.5)} else {cat()}

#####################################Convert HTML to PDF#############################################
#while(publishdata_pdf == 1) {
#set I/O variables
input <- paste(report.path,n,"_HTML_Template.html", sep="")
output <- paste(report.path,n,"_HTML_Template.pdf", sep="")

#updates Batch file. NOTE: This file lives in the wkhtmltopdf directory.
fileConn<-file("C:/Program Files (x86)/wkhtmltopdf/pdf_send.bat")
writeLines(paste("wkhtmltopdf"," ",input," ",output, sep=""), fileConn)
close(fileConn)  

#call batch file for command line conversion
system("pdf_convert.bat")
}
break
}