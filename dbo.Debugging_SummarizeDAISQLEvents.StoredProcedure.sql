USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[Debugging_SummarizeDAISQLEvents]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Debugging_SummarizeDAISQLEvents]
@iLevel INT = 1,
@iDaysCount INT = 7,
@btYesterday BIT = 0
AS
BEGIN
	DECLARE @MinutesCount INT
	
	-- When @btYesterday is 1, the @iLevel and the @iDaysCount will be ignored.
	SET @MinutesCount = @iDaysCount * 1440

	IF (@btYesterday = 1)
	BEGIN
		-- Return yesterday's events
		
		/*
			More summarized: Single entry per spName (spParams shows as empty string)
		*/
		
		DECLARE @dtYesterdayStart DATETIME
		DECLARE @dtYesterdayEnd DATETIME
		
		SET @dtYesterdayStart = DATEADD(dd, DATEDIFF(dd, 1, getdate()), 0)
		SET @dtYesterdayEnd = DATEADD(dd, DATEDIFF(dd, 0, getdate()), 0)
		
		SELECT ev.spName, '' as spParams, RetryCount = COUNT(*)
		   , ev2.SuccessCount, ev3.DeadlockCount, ev4.TimeoutCount
		   , ev6.SQLErrorCount
		   , ev5.FirstRetryDate, ev5.LatestRetryDate
		   , ev7.OverAll_FirstRetryDate, ev7.OverAll_LatestRetryDate
		FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev
		OUTER APPLY 
		(
		 SELECT SuccessCount = COUNT(*)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev2
		 WHERE ev.spName = ev2.spName and ev2.errorType = 'Success' and ev2.createDate >= @dtYesterdayStart and ev2.createDate < @dtYesterdayEnd
		) ev2
		OUTER APPLY 
		(
		 SELECT DeadlockCount = COUNT(*)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev3
		 WHERE ev.spName = ev3.spName and ev3.errorType like '%deadlock%' and ev3.createDate >= @dtYesterdayStart and ev3.createDate < @dtYesterdayEnd
		) ev3
		OUTER APPLY 
		(
		 SELECT TimeoutCount = COUNT(*)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev4
		 WHERE ev.spName = ev4.spName and ev4.errorType like '%timeout%' and ev4.createDate >= @dtYesterdayStart and ev4.createDate < @dtYesterdayEnd
		) ev4
		OUTER APPLY 
		(
		 SELECT FirstRetryDate = MIN(createDate), LatestRetryDate = MAX(createDate)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev5
		 WHERE ev.spName = ev5.spName and ev5.createDate >= @dtYesterdayStart and ev5.createDate < @dtYesterdayEnd
		) ev5
		OUTER APPLY 
		(
		 SELECT SQLErrorCount = COUNT(*)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev6
		 WHERE ev.spName = ev6.spName and ev6.exceptionNumber <> -2 and ev6.exceptionNumber <> 1205 and ev6.exceptionNumber <> 0
		  and ev6.createDate >= @dtYesterdayStart and ev6.createDate < @dtYesterdayEnd
		) ev6
		OUTER APPLY 
		(
		 SELECT OverAll_FirstRetryDate = MIN(createDate), OverAll_LatestRetryDate = MAX(createDate)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev7
		 WHERE ev7.createDate >= @dtYesterdayStart and ev7.createDate < @dtYesterdayEnd
		) ev7
		WHERE ev.createDate >= @dtYesterdayStart and ev.createDate < @dtYesterdayEnd
		GROUP BY ev.spName, ev2.SuccessCount, ev3.DeadlockCount, ev4.TimeoutCount, ev5.FirstRetryDate, ev5.LatestRetryDate
		, ev6.SQLErrorCount, ev7.OverAll_FirstRetryDate, ev7.OverAll_LatestRetryDate
		ORDER BY ev5.FirstRetryDate ASC
	END
	ELSE
	IF (@iLevel = 1)
	BEGIN
		SELECT ev.spName, ev.spParams, RetryCount = COUNT(*)
		   , ev2.SuccessCount, ev3.DeadlockCount, ev4.TimeoutCount
		   , ev6.SQLErrorCount
		   , ev5.FirstRetryDate, ev5.LatestRetryDate
		   , ev7.OverAll_FirstRetryDate, ev7.OverAll_LatestRetryDate
		FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev
		OUTER APPLY 
		(
		 SELECT SuccessCount = COUNT(*)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev2
		 WHERE ev.spName = ev2.spName and ev.spParams = ev2.spParams and ev2.errorType = 'Success' and DATEDIFF(N, ev2.createDate, GETDATE()) < @MinutesCount
		) ev2
		OUTER APPLY 
		(
		 SELECT DeadlockCount = COUNT(*)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev3
		 WHERE ev.spName = ev3.spName and ev.spParams = ev3.spParams and ev3.errorType like '%deadlock%' and DATEDIFF(N, ev3.createDate, GETDATE()) < @MinutesCount
		) ev3
		OUTER APPLY 
		(
		 SELECT TimeoutCount = COUNT(*)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev4
		 WHERE ev.spName = ev4.spName and ev.spParams = ev4.spParams and ev4.errorType like '%timeout%' and DATEDIFF(N, ev4.createDate, GETDATE()) < @MinutesCount
		) ev4
		OUTER APPLY 
		(
		 SELECT FirstRetryDate = MIN(createDate), LatestRetryDate = MAX(createDate)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev5
		 WHERE ev.spName = ev5.spName and ev.spParams = ev5.spParams and DATEDIFF(N, ev5.createDate, GETDATE()) < @MinutesCount
		) ev5
		OUTER APPLY 
		(
		 SELECT SQLErrorCount = COUNT(*)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev6
		 WHERE ev.spName = ev6.spName and ev6.exceptionNumber <> -2 and ev6.exceptionNumber <> 1205 and ev6.exceptionNumber <> 0
		  and DATEDIFF(N, ev6.createDate, GETDATE()) < @MinutesCount
		) ev6
		OUTER APPLY 
		(
		 SELECT OverAll_FirstRetryDate = MIN(createDate), OverAll_LatestRetryDate = MAX(createDate)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev7
		 WHERE DATEDIFF(N, ev7.createDate, GETDATE()) < @MinutesCount
		) ev7
		WHERE  DATEDIFF(N, ev.createDate, GETDATE()) < @MinutesCount
		GROUP BY ev.spName, ev.spParams, ev2.SuccessCount, ev3.DeadlockCount, ev4.TimeoutCount, ev5.FirstRetryDate, ev5.LatestRetryDate
		, ev6.SQLErrorCount, ev7.OverAll_FirstRetryDate, ev7.OverAll_LatestRetryDate
		ORDER BY ev5.FirstRetryDate ASC
	END
	ELSE
	BEGIN
	
		/*
			More summarized: Single entry per spName (spParams shows as empty string)
		*/
		
		SELECT ev.spName, '' as spParams, RetryCount = COUNT(*)
		   , ev2.SuccessCount, ev3.DeadlockCount, ev4.TimeoutCount
		   , ev6.SQLErrorCount
		   , ev5.FirstRetryDate, ev5.LatestRetryDate
		   , ev7.OverAll_FirstRetryDate, ev7.OverAll_LatestRetryDate
		FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev
		OUTER APPLY 
		(
		 SELECT SuccessCount = COUNT(*)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev2
		 WHERE ev.spName = ev2.spName and ev2.errorType = 'Success' and DATEDIFF(N, ev2.createDate, GETDATE()) < @MinutesCount
		) ev2
		OUTER APPLY 
		(
		 SELECT DeadlockCount = COUNT(*)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev3
		 WHERE ev.spName = ev3.spName and ev3.errorType like '%deadlock%' and DATEDIFF(N, ev3.createDate, GETDATE()) < @MinutesCount
		) ev3
		OUTER APPLY 
		(
		 SELECT TimeoutCount = COUNT(*)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev4
		 WHERE ev.spName = ev4.spName and ev4.errorType like '%timeout%' and DATEDIFF(N, ev4.createDate, GETDATE()) < @MinutesCount
		) ev4
		OUTER APPLY 
		(
		 SELECT FirstRetryDate = MIN(createDate), LatestRetryDate = MAX(createDate)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev5
		 WHERE ev.spName = ev5.spName and DATEDIFF(N, ev5.createDate, GETDATE()) < @MinutesCount
		) ev5
		OUTER APPLY 
		(
		 SELECT SQLErrorCount = COUNT(*)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev6
		 WHERE ev.spName = ev6.spName and ev6.exceptionNumber <> -2 and ev6.exceptionNumber <> 1205 and ev6.exceptionNumber <> 0
		  and DATEDIFF(N, ev6.createDate, GETDATE()) < @MinutesCount
		) ev6
		OUTER APPLY 
		(
		 SELECT OverAll_FirstRetryDate = MIN(createDate), OverAll_LatestRetryDate = MAX(createDate)
		 FROM dbo.Debugging_DAISQLEvents (NOLOCK) ev7
		 WHERE DATEDIFF(N, ev7.createDate, GETDATE()) < @MinutesCount
		) ev7
		WHERE  DATEDIFF(N, ev.createDate, GETDATE()) < @MinutesCount
		GROUP BY ev.spName, ev2.SuccessCount, ev3.DeadlockCount, ev4.TimeoutCount, ev5.FirstRetryDate, ev5.LatestRetryDate
		, ev6.SQLErrorCount, ev7.OverAll_FirstRetryDate, ev7.OverAll_LatestRetryDate
		ORDER BY ev5.FirstRetryDate ASC
	END
END

GO
