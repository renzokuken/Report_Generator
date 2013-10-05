

rm(list=ls())

wd <- getwd()
if (wd != "C:/Users/mhilton/Documents/GitHub/Report_Generator") setwd("C:/Users/mhilton/Documents/GitHub/Report_Generator")

library(RODBC)

as <- odbcConnect('Attainment_stage')

attainment.query <- ("

/**********Declare Globals*************************/

DECLARE @Universal_Cohort AS INT
SET @Universal_Cohort = 2016

--Create region lookup to crosswalk datasets.
CREATE TABLE #tt_Region_Lookup (
 Region_ID INT
,Salesforce_ID VARCHAR(255)
,Region_Name VARCHAR(255)
)
/********Create Regional Lookup Table************/
--Need to see if there's an easier way to do this...-MH
INSERT INTO #tt_Region_Lookup (Region_ID, Salesforce_ID, Region_Name)
 VALUES (4 ,'0018000000etIHIAA2','TEAM Schools')
,(1800 ,'0018000000etIHJAA2','KIPP Reach')
,(16 ,'0018000000etIDUAA2','KIPP Baltimore')
,(26 ,'0018000000eKkINAA0','KIPP DFW')
,(19 ,'0018000000esCKBAA2','KIPP Colorado')
,(21 ,'0018000000etIHFAA2','KIPP Memphis')
,(15 ,'0018000000eKk9ZAAS','KIPP Philadelphia')
,(10 ,'0018000000eKkjZAAS','KIPP New Orleans')
,(33 ,'0018000000etIHBAA2','KIPP Indianapolis')
,(2 ,'0018000000Zuh1bAAB','KIPP NYC')
,(3 ,'0018000000ZuUh5AAF','KIPP Houston')
,(27 ,'0018000000etIHEAA2','KIPP Mass')
,(13 ,'0018000000etIHDAA2','KIPP LA')
,(3600 ,'0018000000etIHMAA2','KIPP Adelante')
,(22 ,'0018000000eKkibAAC','KIPP Chicago')
,(18 ,'0018000000etIHLAA2','KIPP San Antonio')
,(12 ,'0018000000etIDTAA2','KIPP Austin')
,(1 ,'0018000000etIHKAA2','KIPP Bay Area')
,(6 ,'0018000000eKkIcAAK','KIPP DC')
,(11 ,'0018000000esCKGAA2','KIPP Delta')
,(32 ,'0018000000etIHAAA2','KIPP Gaston')
,(9 ,'0018000000etIDSAA2','KIPP Metro Atlanta')
,(4700,'0018000000etIHOAA2','KIPP Tulsa')
,(31,'0018000000etIHHAA2','KIPP Nashville')
,(6200,'0018000000etIH8AAM','KIPP Charlotte')
,(6100,'0018000000etIHCAA2','KIPP Kansas City')
,(4600,'0018000000etIDRAA2','KIPP Albany')
,(7500,'0018000000etIHGAA2','KIPP Minneapolis')
,(17,'0018000000etIH9AAM','KIPP Central Ohio')


/*******Pulls in Middle School Completers********/
SELECT C.Id
  ,L.Region_ID
  ,L.Region_Name
  ,C.Name AS Contact_Name
  ,E.Name AS Enrollment_Name
  ,A.Name AS Account_Name
  ,E.Student_HS_Cohort__c
  ,C.Birthdate
  ,C.Cumulative_GPA__c
  ,C.YTD_GPA__c
  ,C.Highest_ACT_Score__c
  ,C.Highest_SAT_Score__c
  ,(CASE WHEN (C.Birthdate IS NOT NULL)
    THEN 1
    ELSE 0
    END) AS N_Birthdate
  --,(CASE WHEN (C.Cumulative_GPA__c IS NOT NULL OR YTD_GPA__c IS NOT NULL)
  --  THEN 1
  --  ELSE 0
  --  END) AS N_GPA
  ,(CASE WHEN (C.Highest_SAT_Score__c IS NOT NULL OR C.Highest_ACT_Score__c IS NOT NULL)
    THEN 1
    ELSE 0
    END) AS N_HS_Assessment
  --  ,(CASE WHEN ((C.Cumulative_GPA__c IS NOT NULL OR YTD_GPA__c IS NOT NULL) AND (C.Highest_SAT_Score__c IS NOT NULL OR C.Highest_ACT_Score__c IS NOT NULL))
    --THEN 1
    --ELSE 0
    --END) AS N_GPA_and_Assessment
  ,E.Status__c
  ,C.EFC_from_FAFSA__c
  ,(CASE WHEN C.EFC_from_FAFSA__c IS NOT NULL
    THEN 1
    ELSE 0
    END) AS N_FAFSA
  ,C.EFC_from_FAFSA4caster__c
  ,(CASE WHEN C.EFC_from_FAFSA4caster__c IS NOT NULL
    THEN 1
    ELSE 0
    END) AS N_FAFSA4caster
  ,'8th Grade Completer' AS Alumni_Type
  
  INTO #tt_8th_Grade_Cohort 
  FROM Attainment.dbo.Contact C
  JOIN Attainment.dbo.Enrollment__c E
  ON C.Id = E.Student__c
  JOIN Attainment.dbo.Account A
  ON E.School__c = A.Id
  LEFT JOIN #tt_Region_Lookup L
  ON A.ParentId = L.Salesforce_ID
  WHERE E.Student_HS_Cohort__c  <= (@Universal_Cohort)
  AND A.Name LIKE '%KIPP%'
  AND A.RecordTypeId = '01280000000BRFEAA4'
  AND E.Status__c = 'Graduated'
  AND C.OwnerId <> '00580000003U34WAAS'
  
  --SELECT * FROM #tt_8th_Grade_Cohort
  --DROP TABLE #tt_8th_Grade_Cohort
  --DROP TABLE #tt_Region_Lookup
  
  
  /***************Pulls in 9th Grade Starters*******************/
  
  SELECT C.Id
  ,L.Region_ID
  ,L.Region_Name
  ,C.Name AS Contact_Name
  ,E.Name AS Enrollment_Name
  ,A.Name AS Account_Name
  ,1 AS KIPP_HS
  ,E.Student_HS_Cohort__c
  ,C.Birthdate
  ,C.Cumulative_GPA__c
  ,C.YTD_GPA__c
  ,E.Final_GPA__c
  ,C.Highest_ACT_Score__c
  ,C.Highest_SAT_Score__c
  ,(CASE WHEN (C.Birthdate IS NOT NULL)
    THEN 1
    ELSE 0
    END) AS N_Birthdate
    ,(CASE WHEN (C.Cumulative_GPA__c IS NOT NULL OR YTD_GPA__c IS NOT NULL OR Final_GPA__c IS NOT NULL)
    THEN 1
    ELSE 0
    END) AS N_GPA
  ,(CASE WHEN (C.Highest_SAT_Score__c IS NOT NULL OR C.Highest_ACT_Score__c IS NOT NULL)
    THEN 1
    ELSE 0
    END) AS N_HS_Assessment
    ,(CASE WHEN ((C.Cumulative_GPA__c IS NOT NULL OR YTD_GPA__c IS NOT NULL) AND (C.Highest_SAT_Score__c IS NOT NULL OR C.Highest_ACT_Score__c IS NOT NULL))
    THEN 1
    ELSE 0
    END) AS N_GPA_and_Assessment
  ,E.Status__c
  ,C.EFC_from_FAFSA__c
  ,(CASE WHEN C.EFC_from_FAFSA__c IS NOT NULL
    THEN 1
    ELSE 0
    END) AS N_FAFSA
  ,C.EFC_from_FAFSA4caster__c
  ,(CASE WHEN C.EFC_from_FAFSA4caster__c IS NOT NULL
    THEN 1
    ELSE 0
    END) AS N_FAFSA4caster
  ,'High School Starter' AS Alumni_Type
  
  INTO #tt_9th_Grade_Starters 
  FROM Attainment.dbo.Contact C
  JOIN Attainment.dbo.Enrollment__c E
  ON C.Id = E.Student__c
  JOIN Attainment.dbo.Account A
  ON E.School__c = A.Id
  JOIN #tt_Region_Lookup L
  ON A.ParentId = L.Salesforce_ID
  WHERE E.Student_HS_Cohort__c <= (@Universal_Cohort)
  AND A.Name LIKE '%KIPP%'
  AND C.OwnerId <> '00580000003U34WAAS'
  AND A.RecordTypeId = '01280000000BQEjAAO'
  --AND E.Status__c NOT IN ('Withdrawn', 'Transferred out')
  AND C.Id NOT IN (
  SELECT Id --Removes all students previously identified as 8th grade completers.
  FROM #tt_8th_Grade_Cohort
  )
  
  --SELECT * FROM #tt_9th_Grade_Starters
  
  
  /***************Scrub Data as Needed************************/
  --Transfers NOW students over to KIPP Houston
  UPDATE #tt_8th_Grade_Cohort
  SET Region_ID = 3
  , Region_Name = 'KIPP Houston'
  WHERE Id IN ('0038000000y6FnvAAE', '0038000000n07mrAAA')
  
  /*****************Pull in most recent HS enrollment**********/
    SELECT
     E.Student__c
    ,E.Name
    ,E.Final_GPA__c 
    ,School__c
    INTO #tt_Max_HS_Enrollment
    FROM Attainment.dbo.Enrollment__c E
    JOIN Attainment.dbo.Account A
    ON E.School__c = A.Id
    JOIN (
    SELECT
  Student__c
  ,MAX(Start_Date__c) AS Time_Stamp
  FROM Attainment.dbo.Enrollment__c
  LEFT JOIN Attainment.dbo.Account
  ON Enrollment__c.School__c = Account.Id
  WHERE Account.RecordTypeId = '01280000000BQEjAAO'
  AND Student__c IN (
  SELECT Student__c
  FROM #tt_8th_Grade_Cohort
  )
  GROUP BY Student__c) AS T
  ON E.Start_Date__c = T.Time_Stamp
  AND E.Student__c = T.Student__c
  WHERE Status__c NOT IN  ('Withdrawn', 'Transferred Out')
  
  /****************Join in 8th Grade Alum High School Data*********/
  SELECT G.Id
  ,G.Region_ID  
  ,G.Region_Name
  ,G.Contact_Name
  ,E.Name AS HS_Enroll_Name
  ,A.Name AS HS_Name
  ,(CASE WHEN E.Name LIKE '%KIPP%' 
    THEN 1
    WHEN E.Name IS NULL 
    THEN 0 
    ELSE 0 END) AS KIPP_HS
  ,G.Student_HS_Cohort__c
  ,G.Birthdate
  ,G.Cumulative_GPA__c
  ,G.YTD_GPA__c
  ,E.Final_GPA__c
  ,G.Highest_ACT_Score__c
  ,G.Highest_SAT_Score__c
  ,G.N_Birthdate
  ,(CASE WHEN (G.Cumulative_GPA__c IS NOT NULL OR G.YTD_GPA__c IS NOT NULL OR E.Final_GPA__c IS NOT NULL)
    THEN 1
    ELSE 0
    END) AS N_GPA
  ,G.N_HS_Assessment
  ,(CASE WHEN ((G.Cumulative_GPA__c IS NOT NULL OR G.YTD_GPA__c IS NOT NULL OR E.Final_GPA__c IS NOT NULL) AND (G.Highest_SAT_Score__c IS NOT NULL OR G.Highest_ACT_Score__c IS NOT NULL))
     THEN 1
     ELSE 0
     END) AS N_GPA_and_Assessment
  ,G.Status__c
  ,G.Alumni_Type
  ,G.EFC_from_FAFSA__c
  ,G.EFC_from_FAFSA4caster__c
  INTO #tt_8th_Grade_Mod
  FROM #tt_8th_Grade_Cohort G
  LEFT JOIN #tt_Max_HS_Enrollment E
  ON G.Id = E.Student__c
  LEFT JOIN Attainment.dbo.Account A
  ON E.School__c = A.Id
    
  --SELECT * FROM #tt_8th_Grade_Mod
  
  /***************Create Union Table of Alumni Types************************/
   
  SELECT * 
  INTO #tt_All_Alums 
  FROM( 
  SELECT
   Id
  ,Region_ID
  ,Region_Name
  ,Contact_Name
  ,HS_Enroll_Name
  ,HS_Name
  ,KIPP_HS
  ,Birthdate
  ,Student_HS_Cohort__c
  ,Highest_ACT_Score__c
  ,Highest_SAT_Score__c
  ,N_Birthdate
  ,N_HS_Assessment
  ,N_GPA_and_Assessment
  ,Cumulative_GPA__c
  ,YTD_GPA__c
  ,Alumni_Type
  ,EFC_from_FAFSA__c
  ,EFC_from_FAFSA4caster__c
  ,N_GPA
  FROM #tt_8th_Grade_Mod
  
  UNION
  
  SELECT
   Id
  ,Region_ID
  ,Region_Name
  ,Contact_Name
  ,Enrollment_Name AS HS_Enroll_Name
  ,Account_Name AS HS_Name
  ,KIPP_HS
  ,Birthdate
  ,Student_HS_Cohort__c
  ,Highest_ACT_Score__c
  ,Highest_SAT_Score__c
  ,N_Birthdate
  ,N_HS_Assessment
  ,N_GPA_and_Assessment
  ,Cumulative_GPA__c
  ,YTD_GPA__c
  ,Alumni_Type
  ,EFC_from_FAFSA__c
  ,EFC_from_FAFSA4caster__c
  ,N_GPA
  FROM #tt_9th_Grade_Starters
  ) AS A
  
  --SELECT * FROM #tt_All_Alums

  
  /***************Summarizes student academic data by region*****************/
 
 SELECT
   Region_ID
  ,Region_Name
  ,Student_HS_Cohort__c
  ,KIPP_HS
  ,Alumni_Type
  ,COUNT(Id) AS N_Students
  ,SUM(N_Birthdate) AS N_Birthdate
  ,SUM(N_GPA) AS N_GPA
  ,SUM(N_HS_Assessment) AS N_HS_Assessment
  ,SUM(N_GPA_and_Assessment) AS N_GPA_and_Assessment
  ,CASE WHEN (CAST((SUM(N_Birthdate) * 100) / (COUNT(Id) + 0.0) AS DEC(5,2)) = 0) 
   THEN NULL
   ELSE CAST((SUM(N_Birthdate) * 100) / (COUNT(Id) + 0.0) AS DEC(5,2)) END AS PCT_DOB
  ,CASE WHEN (CAST((SUM(N_GPA) * 100) / (COUNT(Id) + 0.0) AS DEC(5,2)) = 0) 
   THEN NULL
   ELSE CAST((SUM(N_GPA) * 100) / (COUNT(Id) + 0.0) AS DEC(5,2)) END AS PCT_GPA  
  ,CASE WHEN (CAST((SUM(N_HS_Assessment) * 100) / (COUNT(Id) + 0.0) AS DEC(5,2)) = 0)
   THEN NULL
   ELSE CAST((SUM(N_HS_Assessment) * 100) / (COUNT(Id) + 0.0) AS DEC(5,2)) END AS PCT_Assessment
  ,CASE WHEN (CAST((SUM(N_GPA_and_Assessment) * 100) / (COUNT(Id) + 0.0) AS DEC(5,2)) = 0)
   THEN NULL
   ELSE CAST((SUM(N_GPA_and_Assessment) * 100) / (COUNT(Id) + 0.0) AS DEC(5,2)) END AS PCT_GPA_and_Assessment
  FROM #tt_All_Alums
  
  GROUP BY
   Region_ID
  ,Region_Name
  ,Student_HS_Cohort__c
  ,KIPP_HS
  ,Alumni_Type
  
  ORDER BY 
   Region_Name
  ,Student_HS_Cohort__c
  ,KIPP_HS
  ,Alumni_Type

  DROP TABLE #tt_Region_Lookup
  DROP TABLE #tt_8th_Grade_Cohort
  DROP TABLE #tt_8th_Grade_Mod
  DROP TABLE #tt_Max_HS_Enrollment
  DROP TABLE #tt_9th_Grade_Starters
  DROP TABLE #tt_All_Alums
 
 
")

attainment.raw <- sqlQuery(as, attainment.query, stringsAsFactors=FALSE)