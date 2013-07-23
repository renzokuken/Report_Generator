rm(list=ls())

pulldata <- 1

formatdata <- 1

graphdata <- 1

library(RODBC)
library(ggplot2)
library(scales)
library(grid)
library(plyr)

while(pulldata == 1) {
x <- odbcConnect('State_Scores_prod')

state_score_query <- ("SELECT
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

state_scores <- sqlQuery(x, state_score_query, stringsAsFactors=FALSE)

odbcClose(x)
break
}

while(formatdata == 1) {
  
state_scores_long <- reshape(state_scores,
                             varying = c("State_Score_Percent", "District_Score_Percent", "School_Score_Percent"),
                             v.names = "score",
                             timevar = "score_level",
                             times = c("State_Score_Percent", "District_Score_Percent", "School_Score_Percent"),
                             new.row.names = 1:5000,
                             direction = "long")

state_scores_long$order <- (ifelse(state_scores_long$score_level == "School_Score_Percent", 1, ifelse(state_scores_long$score_level == "District_Score_Percent", 2, 3)))
#set ordering for graphs
state_scores_long$order <- as.integer(paste(state_scores_long$order, state_scores_long$Score_Grouping_Cat_ID, sep=""))
#set labels for buckets
state_scores_long$score_stack <- paste(state_scores_long$score_level, state_scores_long$Score_Grouping_Name, sep= "_")
#replace underscores
state_scores_long$score_stack <- gsub("_"," ", state_scores_long$score_stack)
#remove "score" because it looks stupid :/
state_scores_long$score_stack <- gsub(" Score ", " ", state_scores_long$score_stack)
#cut trailing spaces
state_scores_long$Subtest_Name <- gsub("[[:space:]]*$","", state_scores_long$Subtest_Name)
#round floating point scores
state_scores_long$score <- round(state_scores_long$score, 0)

break
}

while(graphdata == 1) {
palette <- c("#E6D2C8", "#C3B4A5", "#6EB441", "#BED75A", "#E6E6E6", "#B9B9B9")

#s <- factor(state_scores_long$School_ID)
d <-subset(state_scores_long, School_ID == 5 | School_ID == 15 | School_ID == 38, drop = TRUE)
#d <-subset(state_scores_long, School_ID == 5)
school <- factor(d$School_ID)
school <- levels(school)

for(s in school) {

e <- subset(state_scores_long, School_ID == s)
e <- ddply(e, .(Grade, Subtest_Name, score_level), transform, label = sum(score))
e <- ddply(e, .(Grade, Subtest_Name, score_level), transform, pos = (cumsum(score) + 15))

e$label <- ifelse(e$Score_Grouping_Cat_ID == 2, "", e$label)

b <- ggplot(e, aes(x=reorder(score_level, order), y=score, fill=score_stack))
b <- b + geom_bar(stat="identity", width=1, order=order)
b <- b + scale_fill_manual(values = palette, breaks = c("School Percent Advanced", "School Percent Proficient", "District Percent Advanced", "District Percent Proficient", "State Percent Advanced", "State Percent Proficient"))
b <- b + facet_grid(Subtest_Name ~ Grade)
b <- b + coord_equal(ratio = 0.07)
b <- b + theme(panel.margin = unit(0.7, "cm"))
b <- b + theme(legend.title = element_blank(), legend.position = "bottom", legend.text = element_text(face='bold'))
b <- b + theme(strip.text.y = element_text(angle = 45), strip.background = element_blank())
b <- b + xlab('Grade')
b <- b + theme(axis.title.x = element_text(size = rel(1.8)), axis.text.x  = element_blank(), strip.text.x = element_text(size = rel(2.5)))
b <- b + ylab('Percent at Level')
b <- b + scale_y_continuous(limits = c(0, 120))
b <- b + theme(axis.title.y = element_text(size = rel(1.8)), axis.text.y  = element_text(size = rel(0.8)), strip.text.y = element_text(size = rel(1.2), angle = 45, face='bold'), strip.background = element_blank())
b <- b + theme(axis.text.y=element_blank(), plot.background = element_blank(), panel.background=element_blank() , panel.grid.major = element_blank(), panel.grid.minor = element_blank())
b <- b + geom_text(aes(label = label, y = pos), size = 6.8)
b <- b + guides(fill = guide_legend(nrow = 2))
print(b)
#ggsave("export_test.pdf",height=25, width=16.26, dpi=4800)
}
break
}