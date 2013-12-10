############################################################
#Project: Automated Alumni Pull                            #
#Written By: Mike Hilton                                   # 
#Last Updated: 12-3-13                                     #
############################################################

create1 <- ("
CREATE TABLE #tt_Region_Lookup (
	Region_ID INT
	,Salesforce_ID VARCHAR(255)
	,Region_Name VARCHAR(255)
)
")
create2 <- ("
CREATE TABLE #tt_HS_Lookup (
	School_ID INT
	,School_Name VARCHAR(255)
)
")

insert1 <- ("
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
")
insert2 <- ("
INSERT INTO #tt_HS_Lookup (School_ID, School_Name)		
  VALUES (67,'KIPP Austin Collegiate')
		,(90,'KIPP DC: College Preparatory')
		,(66,'KIPP Delta Collegiate')
		,(87,'KIPP Denver Collegiate High School')
		,(104,'KIPP DuBois Collegiate Academy')
		,(19,'KIPP Houston High School')
		,(58,'KIPP King Collegiate High School')
		,(94,'KIPP New York City College Prep')
		,(45,'KIPP Pride High School')
		,(73,'KIPP San Jose Collegiate')
		,(81,'KIPP University Prep High School')
		,(63,'Newark Collegiate Academy, a KIPP school')
 ")

agg1 <- ("
/*****************Pull in most HS Grad Indicator**********/
  SELECT E.Student__c as Id
	  ,School__c
	  ,CASE WHEN Pursuing_Degree_Type__c is NULL
			THEN 'Unknown'
			ELSE Pursuing_Degree_Type__c
			END AS HS_Degree
	  ,Name
  INTO #tt_HS_Grad
  FROM Enrollment__c E
  WHERE Status__c = 'Graduated'
	AND (Type__c = 'High School' 
		OR Pursuing_Degree_Type__c = 'High School Diploma'
		OR Pursuing_Degree_Type__c ='GED')
	AND IsDeleted = 0
")

agg2 <- ("
/*******Pulls in Middle School Completers********/
SELECT C.Id
	,L.Region_ID
	,L.Region_Name
	,C.Name AS Contact_Name
	,E.Name AS Enrollment_Name
	,A.Name AS Account_Name
	,C.KIPP_HS_Class__c
	,C.KIPP_HS_Graduate__c
	,E.Status__c
	,'8th Grade Completer' AS Alumni_Type
	,  [Middle_School_Attended__c] AS Middle_Name
	,C.Actual_HS_Graduation_Date__c AS HS_Grad_Date
	,[Actual_College_Graduation_Date__c] AS Coll_Grad_Date
	INTO #tt_8th_Grade_Cohort	
  FROM Contact C
  JOIN Enrollment__c E
	ON C.Id = E.Student__c
  JOIN Account A
	ON E.School__c = A.Id
  LEFT JOIN #tt_Region_Lookup L
	ON A.ParentId = L.Salesforce_ID
  WHERE 	C.KIPP_HS_Class__c  <= 2014
	AND A.Name LIKE '%KIPP%'
	AND A.RecordTypeId = '01280000000BRFEAA4'
	AND E.Status__c = 'Graduated'
	AND C.OwnerId <> '00580000003U34WAAS'
	AND E.IsDeleted = 0
")

agg3 <- (" 
/*****************Pull in most recent HS enrollment**********/
    SELECT
		 E.Student__c
		,E.Name
		,School__c
		,status__c as HS_Status
    INTO #tt_Max_HS_Enrollment
    FROM Enrollment__c E
    JOIN Account A
	 ON E.School__c = A.Id
    JOIN (
		SELECT
			Student__c
			,MAX(Start_Date__c) AS Time_Stamp
		FROM Enrollment__c
   LEFT JOIN Account
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
	AND E.IsDeleted = 0
	AND Type__c = 'High School'
")

agg4 <- ("
 /***************Pulls in 9th Grade Starters*******************/
  
  SELECT C.Id
	,L.Region_ID
	,L.Region_Name
	,C.Name AS Contact_Name
	,E.Name AS Enrollment_Name
	,A.Name AS Account_Name
	,1 AS KIPP_HS
	,[Middle_School_Attended__c] AS Middle_Name
	,C.KIPP_HS_Class__c 
	,C.KIPP_HS_Graduate__c
	,C.Actual_HS_Graduation_Date__c AS HS_Grad_Date
		,[Actual_College_Graduation_Date__c] AS Coll_Grad_Date
	,'High School Starter' AS Alumni_Type
	,HS_Degree
		,status__c as HS_Status
	INTO #tt_9th_Grade_Starters	
  FROM Contact C
  JOIN Enrollment__c E
	ON C.Id = E.Student__c
  JOIN Account A
	ON E.School__c = A.Id
  JOIN #tt_Region_Lookup L
	ON A.ParentId = L.Salesforce_ID
  LEFT JOIN #tt_HS_Grad HG
	ON HG.Id = C.Id
  WHERE C.KIPP_HS_Class__c  <= 2014
	AND A.Name LIKE '%KIPP%'
	AND C.OwnerId <> '00580000003U34WAAS'
	AND A.RecordTypeId = '01280000000BQEjAAO'
	AND E.Status__c NOT IN ('Withdrawn', 'Transferred out')
	AND E.IsDeleted = 0
	AND C.Id NOT IN (
  SELECT Id --Removes all students previously identified as 8th grade completers.
	FROM #tt_8th_Grade_Cohort
  ) 
")

agg5 <- ("
  /****************Join in 8th Grade Alum High School Data*********/
  
  SELECT G.Id
	,G.Region_ID	
	,G.Region_Name
	,G.Contact_Name
	,Middle_Name
	,E.Name AS HS_Enroll_Name
	,A.Name AS HS_Name
	,(CASE WHEN E.Name LIKE '%KIPP%' 
				THEN 1
			WHEN E.Name IS NULL 
				THEN 0 
			ELSE 0 END) AS KIPP_HS
	 ,G.KIPP_HS_Class__c
	 ,G.KIPP_HS_Graduate__c
	 ,G.Status__c
	 ,G.Alumni_Type
	 ,HS_Grad_Date
	 ,HS_Degree
	 ,HS_Status
	 ,Coll_Grad_Date
  INTO #tt_8th_Grade_Mod
  FROM #tt_8th_Grade_Cohort G
  LEFT JOIN #tt_Max_HS_Enrollment E
	ON G.Id = E.Student__c
  LEFT JOIN Account A
	ON E.School__c = A.Id
  LEFT JOIN #tt_HS_Grad HG
	ON HG.Id = G.Id
  WHERE G.KIPP_HS_Class__c <= 2014
")

agg6 <- ("
/***************Create Union Table of Alumni Types************************/

SELECT * 
  INTO #tt_All_Alums 
  FROM( 
		SELECT
		  Id
			,Region_ID
			,Region_Name
			,Contact_Name
			,Middle_Name
			,HS_Enroll_Name
			,HS_Name
			,KIPP_HS
			,KIPP_HS_Class__c 
			,KIPP_HS_Graduate__c
			,HS_Grad_Date
			,HS_Degree
			, Case WHEN HS_Degree is NULL OR HS_Degree = 'Certificate'
				THEN 0
			  WHEN HS_Degree in ('GED', 'High School Diploma', 'Unknown')
				THEN 1
			  END
			 AS HS_GRAD
			,Alumni_Type
			,HS_Status
			,Coll_Grad_Date
  FROM #tt_8th_Grade_Mod
  WHERE KIPP_HS_Class__c <= 2014
  
  UNION
  
  SELECT
	 Id
	,Region_ID
	,Region_Name
	,Contact_Name
	,Middle_Name
	,Enrollment_Name AS HS_Enroll_Name
	,Account_Name AS HS_Name
	,KIPP_HS
  	,KIPP_HS_Class__c 
  	,KIPP_HS_Graduate__c
	,HS_Grad_Date
	,HS_Degree
	, Case WHEN HS_Degree is NULL OR HS_Degree = 'Certificate'
		   THEN 0
		WHEN HS_Degree in ('GED', 'High School Diploma', 'Unknown')
			THEN 1
		END
		AS HS_GRAD
	,Alumni_Type
	,HS_Status
	,Coll_Grad_Date
  FROM #tt_9th_Grade_Starters
    WHERE KIPP_HS_Class__c <= 2014
  ) AS A
")


#--------------------------------------------
#--Matric (#5)
#--------------------------------------------

agg7 <- ("
-- Determine 1st Date to College
SELECT
   Al.Id
  , MIN(Start_Date__c) as Start_Coll
    INTO #tt_First_Col_Date
  FROM Enrollment__c E
    JOIN #tt_All_Alums Al
		ON E.Student__c= Al.Id
  WHERE Type__c = 'College'
	AND Status__c  NOT IN  ('Matriculated')
	AND E.IsDeleted = 0
	-- ensure we exclude folks that are not pursueing an AA/BA.  If they are NULL, we assume AA/BA.  
	AND (E.Pursuing_Degree_Type__c  NOT IN ('Certificate', 'High School Diploma', 'GED') OR E.Pursuing_Degree_Type__c is NULL)
 GROUP By Al.Id
 ")

agg8 <- ("
-- Determine 6yr AA/Hisp Grad rate at first college
-- This is used for projected completion calculations
 SELECT 
	D.Id
	, A.Name as College_Name
	, Start_Coll
	, Type
	, CASE WHEN A.Name = 'Montgomery College - Takoma Park'
		THEN 14.4
	  WHEN A.Name= 'Community College of the District of Columbia'
		THEN 8.2
	  ELSE 	Adjusted_6_year_minority_graduation_rate__c
	  END	as adj_grad_min
	 , CASE WHEN Competitiveness_Ranking__c in ('Most Competitive', 'Most Competitive+')
			THEN 'Most Competitive'
		  WHEN Competitiveness_Ranking__c like '%2%' OR a.name= 'Montgomery College - Takoma Park' OR Type like '%2%'
			THEN '2 Year'
		  WHEN Competitiveness_Ranking__c = 'Noncompetitive'
			THEN 'Non-Competitive'
		ELSE Competitiveness_Ranking__c 
	   END
	   As Comp_Band
 INTO #tt_First_Col_Enrollment
 FROM #tt_First_Col_Date D
	JOIN [Attainment].[dbo].[Enrollment__c] E
		 ON D.Id = E.Student__c
	AND D.Start_Coll= E.Start_Date__c
	JOIN  [Attainment].[dbo].[Account] A
		ON E.School__c = A.Id
 WHERE E.Type__c = 'College'
  AND Status__c  NOT IN  ('Matriculated')
 AND E.IsDeleted = 0
	AND (E.Pursuing_Degree_Type__c  NOT IN ('Certificate', 'High School Diploma', 'GED') OR E.Pursuing_Degree_Type__c is NULL)
 AND A.RecordTypeId = '01280000000BQEkAAO'
 AND E.IsDeleted = 0
 ")

agg9 <- (" 
/*****************Pull in College Grad Indicator**********/
  SELECT
	  E.Student__c as Id
	 ,School__c
	,CASE WHEN Pursuing_Degree_Type__c is NULL
		THEN 'Unknown'
		ELSE Pursuing_Degree_Type__c
		END as College_Degree
	,Name AS Coll_Grad_Name
    INTO #tt_Coll_Grad
    FROM Enrollment__c E
  WHERE Status__c = 'Graduated'
	AND Type__c = 'College' 
		AND( Pursuing_Degree_Type__c like '%Bachelor%'
		OR Pursuing_Degree_Type__c like '%Associate%') 
	AND IsDeleted = 0
")

agg10 <- ("
/****************  Determine students getting advanced degrees *******/
  SELECT
	  E.Student__c as Id
	 ,School__c AS Adv_Degree_Name
	, Pursuing_Degree_Type__c 
     INTO #tt_Adv_Degree
    FROM Enrollment__c E
  WHERE (Type__c = 'College'  OR Type__c ='Grad School')
		AND Pursuing_Degree_Type__c IN (
			'MBA'
			, 'Master''s'
			, 'Graduate Degree'
			,'JD'
			,'Ph.D'
			, 'Ed.D')
	AND IsDeleted = 0
")

agg11 <- ("
/****************  Determine students persisting *******/
  SELECT
	  E.Student__c as Id
	 ,School__c AS Persist_Name
	 ,Pursuing_Degree_Type__c 
	 , A.Type as Persist_Type
    INTO #tt_Persist
    FROM Enrollment__c E
     JOIN  [Attainment].[dbo].[Account] A
		ON E.School__c = A.Id
  WHERE Type__c = 'College'
		AND Status__c = 'Attending'
	AND E.IsDeleted = 0
	AND Start_Date__c <= '10-1-13'
	AND (
			Actual_End_Date__c is NULL
		OR 
			Actual_End_Date__c >= '10-1-13'
		)
	AND (E.Pursuing_Degree_Type__c  NOT IN ('Certificate', 'High School Diploma', 'GED') OR E.Pursuing_Degree_Type__c is NULL)
		AND (Pursuing_Degree_Type__c NOT IN (
			'MBA'
			, 'Graduate Degree'
			, 'Master''s'
			,'JD'
			,'Ph.D'
			, 'Ed.D') OR Pursuing_Degree_Type__c is NULL)
")

agg12 <- ("
SELECT
  A.Id
 ,ROW_NUMBER() OVER(PARTITION BY A.Id ORDER BY A.Id) AS Row_Count
 ,Region_ID
 ,Region_Name
 ,Contact_Name
 ,Middle_Name
 ,HS_Enroll_Name
 ,HS_Name
 ,KIPP_HS
 ,KIPP_HS_Class__c 
 ,KIPP_HS_Graduate__c
 ,HS_Grad_Date
 ,HS_Degree
, HS_GRAD
 ,Alumni_Type
,HS_Status
,College_Name
, Start_Coll
,TYPE as College_Type
,adj_grad_min
, Comp_Band
,Case WHEN College_Name IS NULL then 0
	ELSE 1
	END
	AS College_Matric
,	Coll_Grad_Date
, Coll_Grad_Name
,College_Degree
, Case WHEN College_Degree IS NULL THEN 0
		ELSE 1
	END
	AS Coll_Grad
, Case WHEN Persist_Name IS Not NULL
		THEN 1
		ELSE 0	
	END
	AS Persisting 
	, Persist_Type
, Adv_Degree_Name
INTO #tt_Attain_Update
FROM #tt_All_Alums A
LEFT JOIN #tt_First_Col_Enrollment C
	ON A.Id = C.id
LEFT JOIN #tt_Coll_Grad G
	ON A.Id = G.Id
LEFT JOIN #tt_Adv_Degree Adv
    ON Adv.ID = A.id
LEFT JOIN #tt_Persist P
	ON P.Id = A.Id

--SELECT * FROM #tt_Attain_Update
")

attainment1 <- ("
/********Aggregate Regional Attainment Number********/
SELECT Region_ID
	,Region_Name
	,COUNT(Id) AS Denominator
	,SUM(HS_GRAD) AS Graduated
	,SUM(College_Matric) AS Matriculated
	,CAST((SUM(HS_Grad) / (Count(Id) + 0.0)) AS DEC(5,2)) AS Grad_Rate
	,CAST((SUM(College_Matric) / (Count(Id) + 0.0)) AS DEC(5,2)) AS Matric_Rate

FROM  #tt_Attain_Update
WHERE Row_Count = 1
AND Alumni_Type = '8th Grade Completer'
AND KIPP_HS_Class__c <= 2013
AND Region_ID IS NOT NULL

GROUP BY Region_ID
		,Region_Name
")

agg13 <- ("
/**************Aggregate High School Assessment numbers***************/
SELECT Id
	,Row_Count
	,Region_ID
	,Region_Name
	,Contact_Name
	,Middle_Name
	,HS_Enroll_Name
	,HS_Name
	,KIPP_HS
	,KIPP_HS_Class__c 
	,KIPP_HS_Graduate__c
	,HS_Grad_Date
	,HS_Degree
	,HS_GRAD
	,Alumni_Type
	,HS_Status
	,College_Name
	,Start_Coll
	,College_Type
	,adj_grad_min
	,Comp_Band
	,College_Matric
	,Coll_Grad_Date
	,Coll_Grad_Name
	,College_Degree
	,Coll_Grad
	,Persisting
	,Persist_Type
	,Adv_Degree_Name
INTO #tt_High_School_RC
FROM #tt_Attain_Update
WHERE (KIPP_HS_Class__c = 2013 OR YEAR(HS_Grad_Date) = 2013)
AND KIPP_HS = 1
AND HS_GRAD = 1

--SELECT * FROM #tt_High_School_RC
")

agg14 <- ("
/*******Subset HS Assessments************/
SELECT Id
      ,IsDeleted
      ,Name
      ,Contact__c
      ,ACT_English__c
      ,ACT_Math__c
      ,ACT_Reading__c
      ,ACT_Science__c
      ,Date__c
      ,Overall_Score__c
      ,SAT_Math__c
      ,SAT_Verbal__c
      ,SAT_Writing__c
      ,Subject__c
      ,Test_Type__c
      ,ACT_Composite__c
      ,AP__c
      ,ACT_Writing__c
  INTO #tt_HS_Assessment
  FROM Attainment.dbo.Standardized_Test__c
  WHERE IsDeleted = 0
  AND RecordTypeId IN (
   '01280000000BQ2ZAAW' --SAT
  ,'01280000000BQ2UAAW' --ACT
  ,'01280000000LonYAAS' --AP
  )
  AND Contact__c IN (
  SELECT Id 
  FROM #tt_High_School_RC
  )
")

agg15 <- ("
/*********Pull highest scores***********/
--SAT
SELECT Contact__c
	,COUNT(Overall_Score__c) AS N_Test
	,MAX(Overall_Score__c) AS SAT_Score
INTO #tt_SAT
FROM #tt_HS_Assessment
WHERE Overall_Score__c IS NOT NULL
AND Overall_Score__c <> ACT_Composite__c --This is stupid.
GROUP BY Contact__c
")

agg16 <- ("
--ACT
SELECT Contact__c
	,COUNT(ACT_Composite__c) AS N_Test
	,MAX(ACT_Composite__c) AS ACT_Score
INTO #tt_ACT
FROM #tt_HS_Assessment
WHERE ACT_Composite__c IS NOT NULL
GROUP BY Contact__c
")

agg17 <- ("
--AP
SELECT Contact__c
	,COUNT(AP__c) AS N_Test
	,MAX(AP__c) AS Highest_AP
	,CASE WHEN MAX(AP__c) >= 3 THEN 1 ELSE 0 END AS Passing_AP
INTO #tt_AP
FROM #tt_HS_Assessment
WHERE AP__c IS NOT NULL
GROUP BY Contact__c

--SELECT * FROM #tt_SAT S
--JOIN #tt_High_School_RC H
--ON S.Contact__c = H.Id
--WHERE H.Region_ID = 11
--SELECT * FROM #tt_ACT
--JOIN #tt_High_School_RC H
--ON S.Contact__c = H.Id
--WHERE H.Region_ID = 11
--SELECT * FROM #tt_AP S
--JOIN #tt_High_School_RC H
--ON S.Contact__c = H.Id
--WHERE H.Region_ID = 11
")

agg18 <- ("
/**********Link scores to students*************/
	 
SELECT Id
	,H.Row_Count
	,H.Region_ID
	,H.Region_Name
	,H.Contact_Name
	,H.Middle_Name
	,H.HS_Enroll_Name
	,H.HS_Name
	,H.KIPP_HS
	,H.KIPP_HS_Class__c 
	,H.KIPP_HS_Graduate__c
	,H.HS_Grad_Date
	,H.HS_Degree
	,H.HS_GRAD
	,H.Alumni_Type
	,H.HS_Status
	,H.College_Name
	,H.Start_Coll
	,H.College_Type
	,H.adj_grad_min
	,H.Comp_Band
	,H.College_Matric
	,H.Coll_Grad_Date
	,H.Coll_Grad_Name
	,H.College_Degree
	,H.Coll_Grad
	,H.Persisting
	,H.Persist_Type
	,H.Adv_Degree_Name
	,CASE WHEN S.SAT_Score = A.ACT_Score AND H.Region_ID <> 11 THEN NULL ELSE S.SAT_Score END AS SAT_Score
	,CASE WHEN A.ACT_Score = 0 THEN NULL ELSE A.ACT_Score END AS ACT_Score
	,P.Highest_AP
	,P.Passing_AP
INTO #tt_Score_Join
FROM #tt_High_School_RC H
LEFT JOIN #tt_SAT S
ON H.Id = S.Contact__c
LEFT JOIN #tt_ACT A
ON H.Id = A.Contact__c
LEFT JOIN #tt_AP P
ON H.Id = P.Contact__c

--SELECT * FROM #tt_Score_Join
--WHERE Region_ID = 11
")

hs.assessment1 <- ("
/************Aggregate HS Assessment Results**************/
SELECT Region_ID
	,Region_Name
	,COUNT(Id) AS N_Students
	,COUNT(SAT_Score) AS N_SAT
	,AVG(SAT_Score) AS AVG_SAT
	,COUNT(ACT_Score) AS N_ACT
	,AVG(ACT_Score) AS AVG_ACT
	,COUNT(Highest_AP) AS N_AP
	,CAST(SUM(Passing_AP) / (COUNT(Highest_AP) + 0.0) AS DEC(5,2)) AS Passing_AP
FROM #tt_Score_Join
WHERE Region_ID <> 15
GROUP BY Region_ID
		,Region_Name
ORDER BY Region_ID
")

hs.assessment2 <- ("
SELECT School_ID
	,School_Name
	,COUNT(Id) AS N_Students
	,COUNT(SAT_Score) AS N_SAT
	,AVG(SAT_Score) AS AVG_SAT
	,COUNT(ACT_Score) AS N_ACT
	,AVG(ACT_Score) AS AVG_ACT
	,COUNT(Highest_AP) AS N_AP
	,CAST(SUM(Passing_AP) / (COUNT(Highest_AP) + 0.0) AS DEC(5,2)) AS Passing_AP
FROM #tt_Score_Join S
JOIN #tt_HS_Lookup H
ON S.HS_Name = H.School_Name
WHERE School_ID <> 104
GROUP BY School_ID
		,School_Name
ORDER BY School_ID
")

drop1 <- ("
DROP TABLE #tt_Region_Lookup
")
drop2 <- ("
DROP TABLE #tt_HS_Lookup
")
drop3 <- ("
DROP TABLE #tt_8th_Grade_Cohort
")
drop4 <- ("
DROP TABLE #tt_9th_Grade_Starters	
")
drop5 <- ("
DROP TABLE #tt_All_Alums 
")
drop6 <- ("
DROP TABLE #tt_Max_HS_Enrollment
")
drop7 <- ("
DROP TABLE #tt_8th_Grade_Mod
")
drop8 <- ("
DROP TABLE #tt_First_Col_Enrollment
")
drop9 <- ("
DROP TABLE #tt_First_Col_Date
")
drop10 <- ("
DROP TABLE #tt_HS_Grad
")
drop11 <- ("
DROP TABLE #tt_Coll_Grad
")
drop12 <- ("
DROP TABLE #tt_Attain_Update
")
drop13 <- ("
DROP TABLE #tt_Adv_Degree
")
drop14 <- ("
DROP TABLE #tt_Persist
")
drop15 <- ("
DROP TABLE #tt_High_School_RC
")
drop16 <- ("
DROP TABLE #tt_HS_Assessment
")
drop17 <- ("
DROP TABLE #tt_SAT
")
drop18 <- ("
DROP TABLE #tt_ACT
")
drop19 <- ("
DROP TABLE #tt_AP
")
drop20 <- ("
DROP TABLE #tt_Score_Join
")

sqlQuery(as, create1)
sqlQuery(as, create2)
sqlQuery(as, insert1)
sqlQuery(as, insert2)
sqlQuery(as, agg1)
sqlQuery(as, agg2)
sqlQuery(as, agg3)
sqlQuery(as, agg4)
sqlQuery(as, agg5)
sqlQuery(as, agg6)
sqlQuery(as, agg7)
sqlQuery(as, agg8)
sqlQuery(as, agg9)
sqlQuery(as, agg10)
sqlQuery(as, agg11)
sqlQuery(as, agg12)
attainment.region.raw <- sqlQuery(as, attainment1, stringsAsFactors = FALSE)
sqlQuery(as, agg13)
sqlQuery(as, agg14)
sqlQuery(as, agg15)
sqlQuery(as, agg16)
sqlQuery(as, agg17)
sqlQuery(as, agg18)
assessment.region.raw <- sqlQuery(as, hs.assessment1, stringsAsFactors = FALSE)
assessment.school.raw <- sqlQuery(as, hs.assessment2, stringsAsFactors = FALSE)
sqlQuery(as, drop1)
sqlQuery(as, drop2)
sqlQuery(as, drop3)
sqlQuery(as, drop4)
sqlQuery(as, drop5)
sqlQuery(as, drop6)
sqlQuery(as, drop7)
sqlQuery(as, drop8)
sqlQuery(as, drop9)
sqlQuery(as, drop10)
sqlQuery(as, drop11)
sqlQuery(as, drop12)
sqlQuery(as, drop13)
sqlQuery(as, drop14)
sqlQuery(as, drop15)
sqlQuery(as, drop16)
sqlQuery(as, drop17)
sqlQuery(as, drop18)
sqlQuery(as, drop19)
sqlQuery(as, drop20)