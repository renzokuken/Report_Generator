rm(list=ls())

#Declare globals
pulldata <- 0

formatdata <- 0

publishdata_html <- 1

publishdata_png <- 0

data.path <<- paste("C:/Users/mhilton/Documents/R_Data/HTML_Reports/")
report.path <<- paste("C:/Users/mhilton/Documents/R_Graphs/HTML_Reports/")

library(RODBC)
library(ggplot2)
library(scales)
library(grid)
library(plyr)
library(knitr)

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

#clean up school names
school.list$Display_Name <- gsub(":","",school.list$Display_Name)
school.list$Display_Name <- gsub(",","",school.list$Display_Name)
school.list$Display_Name <- gsub(" ","_",school.list$Display_Name)

odbcClose(s)

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
  
#get data
dget(paste(data.path,"quartile.raw.Rda", sep=""))
dget(paste(data.path,"statescore.raw.Rda", sep=""))
dget(paste(data.path,"demographics.raw.Rda", sep=""))

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

#generate order for bar sequence
quartile.mod$sequence <- paste(quartile.mod$Season, quartile.mod$Grade_When_Taken_int)
quartile.mod$Graph_Label <- reorder(quartile.mod$Graph_Label,quartile.mod$sequence)
#generate labels for graph
quartile.mod$label <- abs(quartile.mod$percent_at_quartile)

#############################################format statescore data####################################################
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

#save data
dput(quartile.mod, paste(data.path, "quartile.mod.RDa", sep=""))
dput(statescore.mod, paste(data.path,"statescore.mod.RDa", sep =""))
dput(demographics.mod, paste(data.path,"demographics.mod.RDa", sep=""))
break
}

#########################################Generate HTML reports :D###################################
while(publishdata_html == 1) {  

#get data
quartile.mod <- dget(paste(data.path,"quartile.mod.Rda", sep=""))
statescore.mod <- dget(paste(data.path,"statescore.mod.Rda", sep=""))
demographics.mod <- dget(paste(data.path,"demographics.mod.Rda", sep=""))

#set color palettes
quartile.palette <- c( "#CFCCC1", "#FEBC11","#F7941E", "#E6E6E6") 
statescore.palette <- c("#E6D2C8", "#C3B4A5", "#6EB441", "#BED75A", "#E6E6E6", "#B9B9B9")
  
x <- c(5, 3, 105, 138)
for(s in x){
#for(s in school.list$School_ID){
  n <- school.list[school.list$School_ID == s,]
  n <- n$Display_Name
  
  print(s)
  print(n)
  
#############################################set quartile plot#######################################
#calculates vertical position for bar labels
quartile.graph <- subset(quartile.mod, School_ID == s)

#calculate label placement for stacked bars
quartile.graph <- ddply(quartile.graph, .(Graph_Label, Sub_Test_Name), transform, pos = (((cumsum(label)) - 0.5*label)))
quartile.graph <- ddply(quartile.graph, .(Graph_Label, Sub_Test_Name), transform, neg = sum(ifelse(order %in% c(1,2), label, 0)))
quartile.graph$pos <- (quartile.graph$pos - quartile.graph$neg)

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
quartile.plot <- quartile.plot + geom_bar(data = q1, aes(x=Graph_Label, y=percent_at_quartile, fill=quartile, order=order), stat="identity", width=0.5)
quartile.plot <- quartile.plot + geom_bar(data = q2, aes(x=Graph_Label, y=percent_at_quartile, fill=quartile, order=order), stat="identity", width=0.5)
quartile.plot <- quartile.plot + scale_fill_manual(values = quartile.palette, breaks = c("Percent At Above 75 NPR","Percent At 50 Below 75 NPR","Percent At 25 Below 50 NPR","Percent Below 25 NPR"))
quartile.plot <- quartile.plot + facet_grid(~ Sub_Test_Name)
quartile.plot <- quartile.plot + xlab('Season')
quartile.plot <- quartile.plot + theme(axis.title.x = element_text(size = rel(1.8)), axis.text.x  = element_text(size = rel(1.8), angle=45), strip.text.x = element_text(size = rel(2.5), face='bold'))
quartile.plot <- quartile.plot + ylab('Quartile Distribution')
quartile.plot <- quartile.plot + theme(axis.title.y = element_text(size = rel(1.8)), axis.text.y  = element_text(size = rel(1.8)), strip.text.y = element_text(size = rel(2.5), face='bold'))
quartile.plot <- quartile.plot + geom_text(aes(x=Graph_Label, y=pos, label = label), size = 8)
quartile.plot <- quartile.plot + theme(axis.text.y=element_blank(), panel.grid.major = element_blank(), plot.background = element_blank(), panel.background = element_blank(), panel.grid.minor = element_blank())
 
#################################set state score plot################################################
statescore.graph <- subset(statescore.mod, School_ID == s)
statescore.graph <- ddply(statescore.graph, .(Grade, Subtest_Name, score_level), transform, label = sum(score))
statescore.graph <- ddply(statescore.graph, .(Grade, Subtest_Name, score_level), transform, pos = (cumsum(score) + 15))
  
statescore.graph$label <- ifelse(statescore.graph$Score_Grouping_Cat_ID == 2, "", statescore.graph$label)
  
statescore.plot <- ggplot(statescore.graph, aes(x=reorder(score_level, order), y=score, fill=score_stack))
statescore.plot <- statescore.plot + geom_bar(stat="identity", width=1, order=order)
statescore.plot <- statescore.plot + scale_fill_manual(values = statescore.palette, breaks = c("School Percent Advanced", "School Percent Proficient", "District Percent Advanced", "District Percent Proficient", "State Percent Advanced", "State Percent Proficient"))
statescore.plot <- statescore.plot + facet_grid(Subtest_Name ~ Grade)
statescore.plot <- statescore.plot + coord_equal(ratio = 0.07)
statescore.plot <- statescore.plot + theme(panel.margin = unit(0.7, "cm"))
statescore.plot <- statescore.plot + theme(legend.title = element_blank(), legend.position = "bottom", legend.text = element_text(face='bold'))
statescore.plot <- statescore.plot + theme(strip.text.y = element_text(angle = 45), strip.background = element_blank())
statescore.plot <- statescore.plot + xlab('Grade')
statescore.plot <- statescore.plot + theme(axis.title.x = element_text(size = rel(1.8)), axis.text.x  = element_blank(), strip.text.x = element_text(size = rel(2.5)))
statescore.plot <- statescore.plot + ylab('Percent at Level')
statescore.plot <- statescore.plot + scale_y_continuous(limits = c(0, 120))
statescore.plot <- statescore.plot + theme(axis.title.y = element_text(size = rel(1.8)), axis.text.y  = element_text(size = rel(0.8)), strip.text.y = element_text(size = rel(1.2), angle = 45, face='bold'), strip.background = element_blank())
statescore.plot <- statescore.plot + theme(axis.text.y=element_blank(), plot.background = element_blank(), panel.background=element_blank() , panel.grid.major = element_blank(), panel.grid.minor = element_blank())
statescore.plot <- statescore.plot + geom_text(aes(label = label, y = pos), size = 6.8)
statescore.plot <- statescore.plot + guides(fill = guide_legend(nrow = 2))  
  
#####################################Knit to HTML Template###########################################

knit2html("HTML_template.Rhtml")
#hatersgonnahate.jpg
file.rename(from="HTML_template.html",to=paste(report.path,n,"_HTML_Template.html", sep=""))
}
break
}