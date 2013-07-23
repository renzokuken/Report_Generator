rm(list=ls())

pulldata <- 1

formatdata <- 1

graphdata <- 1

library(RODBC)
library(ggplot2)
library(scales)
library(plyr)

while(pulldata == 1) {
  x <- odbcConnect('Report_Card_prod')
  
  quartile_query <- ("SELECT
                        *
                        FROM v_School_Quartile_current_2012
                        ")
  
quartile <- sqlQuery(x, quartile_query, stringsAsFactors=FALSE)
  
odbcClose(x)
break
}


while(formatdata == 1) {

#set graph values for percent_in_quartile
quartile$Percent_Below_25_NPR <- (quartile$Percent_Below_25_NPR * -1)
quartile$Percent_At_25_Below_50_NPR <- (quartile$Percent_At_25_Below_50_NPR * -1)

#reshape data wide to long
quartile <- reshape(quartile,
        varying = c("Percent_Below_25_NPR", "Percent_At_25_Below_50_NPR", "Percent_At_50_Below_75_NPR", "Percent_At_Above_75_NPR"),
        v.names = "percent_at_quartile",
        timevar = "quartile",
        times = c("Percent_Below_25_NPR", "Percent_At_25_Below_50_NPR", "Percent_At_50_Below_75_NPR", "Percent_At_Above_75_NPR"),
        new.row.names = 1:5000,
        direction = "long")

#generate order for bar stacking
quartile$order <- ifelse(quartile$quartile == "Percent_At_Above_75_NPR", 4, ifelse(quartile$quartile == "Percent_At_50_Below_75_NPR", 3, ifelse(quartile$quartile == "Percent_At_25_Below_50_NPR",1, 2)))
#generate order for bar sequence
quartile$sequence <- paste(quartile$Season, quartile$Grade_When_Taken_int)
quartile$Graph_Label <- reorder(quartile$Graph_Label,quartile$sequence)
#generate labels for graph
quartile$label <- abs(quartile$percent_at_quartile)

break
}

while(graphdata == 1) {

#set color palette
palette <- c( "#CFCCC1", "#FEBC11","#F7941E", "#E6E6E6")

#loop for all schools
#school <- factor(quartile$School_ID)
#school <- levels(school)

#subset data for PoC...
#d <-subset(quartile, School_ID == 5 | School_ID == 15 | School_ID == 38 | School_ID == 68, drop = TRUE)
#school <- factor(d$School_ID)
#school <- levels(school)

for(s in x){
#for(s in school){

#calculates vertical position for bar labels
e <- subset(quartile, School_ID == s)

#calculate label placement for stacked bars
e <- ddply(e, .(Graph_Label, Sub_Test_Name), transform, pos = (((cumsum(label)) - 0.5*label)))
e <- ddply(e, .(Graph_Label, Sub_Test_Name), transform, neg = sum(ifelse(order %in% c(1,2), label, 0)))
e$pos <- (e$pos - e$neg)

#calculates bar spacing
#max <- 6 #NOTE TO SELF: find a way to make this dynamic...
#bar <- nrow(e) / 8
#max <- ((max * 2) - 1)
#gap <- (1 / ((max - bar) / 2))

#separate positive and negative values for stacked bars
e1 <- subset(e, quartile %in% c("Percent_Below_25_NPR", "Percent_At_25_Below_50_NPR"))
e2 <- subset(e, quartile %in% c("Percent_At_50_Below_75_NPR", "Percent_At_Above_75_NPR"))

e1$quartile <- e1$quartile <- gsub("_"," ", e1$quartile)
e2$quartile <- e2$quartile <- gsub("_"," ", e2$quartile)

#plot graph
q <- ggplot(e)
q <- q + geom_bar(data = e1, aes(x=Graph_Label, y=percent_at_quartile, fill=quartile, order=order), stat="identity", width=0.5)
q <- q + geom_bar(data = e2, aes(x=Graph_Label, y=percent_at_quartile, fill=quartile, order=order), stat="identity", width=0.5)
q <- q + scale_fill_manual(values = palette)
q <- q + facet_grid(~ Sub_Test_Name)
q <- q + xlab('Season')
q <- q + theme(axis.title.x = element_text(size = rel(1.8)), axis.text.x  = element_text(size = rel(1.8), angle=45), strip.text.x = element_text(size = rel(2.5), face='bold'))
q <- q + ylab('Quartile Distribution')

q <- q + theme(axis.title.y = element_text(size = rel(1.8)), axis.text.y  = element_text(size = rel(1.8)), strip.text.y = element_text(size = rel(2.5), face='bold'))
q <- q + geom_text(aes(x=Graph_Label, y=pos, label = label), size = 8)
q <- q + theme(axis.text.y=element_blank(), panel.grid.major = element_blank(), plot.background = element_blank(), panel.background = element_blank(), panel.grid.minor = element_blank())

#will eventually build in export functionality...
#plot(q)
}
break
}