USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spDailySDCReport]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[spDailySDCReport] (@ScheduleDate datetime ,
@rReturnFileName	Varchar(400) = 0 OUTPUT -- 0 = return result set, otherwise don't 
)
AS
BEGIN
	set nocount on
	DECLARE
	@ReportName		varchar(100),
	@AppendString		varchar(1000),
	@PreviousTerminal 	varchar(100),
	@CommandString		varchar(1000),
	@DailySDCReportPath varchar(200),
	@ErrorID		int,
	@ErrorEncountered	varchar(5000),
	@LoopCounter		int,
	@ResultCode		int,
	@ReturnCode		int,
	@Status			varchar(100),
	@ReturnMessage		varchar(100),
	@Startdate		datetime,
	@ProcessDate		datetime,
	@UnitsShippedYesterday	int,
	@ShippedToday		int,
	@TenderedToday		int,
	@UnitsAvailable		int,
	@UnitsOver7Days 	int,
	@TotalActiveDrivers 	int,
	@TotalActiveBrokers 	int,
	@TotalExportUnits 	int,
	@TotalStorageUnits 	int,
	@TotalPipeLine 		int,
	@CustomerName		varchar(100),
	@TerminalName		varchar(100),
	@UnitsInPipeLine	int,
	@ToyotaLocationName	varchar(100),
	@ToyotaOnTimePercentage	decimal(19,2),
	@MercedesLocationName	varchar(100),
	@MercedesOnTimePercentageQuarter decimal(19,2),
	@MercedesOnTimePercentageMonth decimal(19,2),
	@MercedesOnTimePercentageWeek decimal(19,2),
	@HondaLocationName	varchar(100),
	@HondaOnTimePercentagePrevMonth	decimal(19,2),
	@HondaOnTimePercentageCurMonth	decimal(19,2),
	@HondaOver5DaysCount	decimal(19,2),
	@PeriodEndDate		datetime,
	@StandardUnSafeDriving	decimal(19,2),
	@StandardHOSCompliance	decimal(19,2),
	@StandardDriverFitness	decimal(19,2),
	@StandardVehicleMaintenance	decimal(19,2),
	@StandardCrashIndicator	decimal(19,2),
	@CurrentUnsafeDriving	decimal(19,2),
	@CurrentHOSCompliance	decimal(19,2),
	@CurrentDriverFitness	decimal(19,2),
	@CurrentVehicleMaintenance	decimal(19,2),
	@CurrentCrashIndicator	decimal(19,2),
	@PreviousUnsafeDriving	decimal(19,2),
	@PreviousHOSCompliance	decimal(19,2),
	@PreviousDriverFitness	decimal(19,2),
	@PreviousVehicleMaintenance	decimal(19,2),
	@PreviousCrashIndicator	decimal(19,2),
	@CurrentDay	varchar(100),
	@DayName	varchar(100),
	@PreviousDay	varchar(100),
	@TruckNumber	varchar(100),
	@DriverNumber	varchar(100),
	@DriverName	varchar(100),
	@MaintDay	varchar(100),
	@iDriverID	int,
	@VPCComplete	int,
	@VPCShipped	int,
	@CountPortStorage	int,
	@CountAutoportExport	int




	/************************************************************************
	*	spDailySDCReport					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the daily Exceutive Report 		*
	*									*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	11/06/2014 SS    Initial version				*
	*									*
	************************************************************************/

--------------------------Top querrries

	SELECT @StartDate = @ScheduleDate

	--1-Querry ok
	SELECT @UnitsShippedYesterday = Count(*) FROM Legs WHERE CONVERT(VARCHAR(10),PickupDate,101) = DATEADD(day,-1,CONVERT(VARCHAR(10),@StartDate,101))

	--DATEADD(day,-1,CONVERT(VARCHAR(10),CURRENT_TIMESTAMP,101))

	--2-Querry ok

	SELECT @ShippedToday = Count(*)  FROM Legs WHERE CONVERT(VARCHAR(10),PickupDate,101) = CONVERT(VARCHAR(10),@StartDate,101)

	--PickupDate > CONVERT(VARCHAR(10),CURRENT_TIMESTAMP,101)

	SELECT @TenderedToday = COUNT(*) FROM Legs WHERE CONVERT(VARCHAR(10),DateAvailable,101) = CONVERT(VARCHAR(10),@StartDate,101)
	-->=
	--CONVERT(VARCHAR(10),CURRENT_TIMESTAMP,101)

	SELECT @UnitsAvailable = COUNT(*) FROM Vehicle V LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
	LEFT JOIN Location L1 ON V.PickupLocationID = L1.LocationID
	WHERE AvailableForPickupDate IS NOT NULL
	AND V.VehicleStatus NOT IN ('EnRoute','Delivered')
	AND C.CustomerType = 'OEM'
	AND V.BilledInd=0

	SELECT @UnitsOver7Days = COUNT (*) FROM Customer C
	LEFT JOIN Vehicle V ON C.CustomerID =V.CustomerID
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	WHERE C.CustomerType = 'OEM'
	AND L.PickupDate IS NULL AND L.DateAvailable IS NOT NULL
	AND DATEDIFF(day,L.DateAvailable,@StartDate) >7
	--AND DATEDIFF(day,L.DateAvailable,CURRENT_TIMESTAMP) >7


	SELECT @TotalActiveDrivers = COUNT(Distinct(R.DriverID)) FROM Run R
	LEFT JOIN RunStops RS ON  R.RunID=RS.RunID
	WHERE CONVERT(VARCHAR(10), StopDate,101) = CONVERT(VARCHAR(10),@StartDate,101)
	--CONVERT(VARCHAR(10),CURRENT_TIMESTAMP,101)


	SELECT @TotalPipeLine = COUNT(*)FROM Vehicle V
	LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
	LEFT JOIN Location L ON V.PickupLocationID = L.LocationID
	WHERE V.AvailableForPickupDate IS NULL
	AND C.CustomerType = 'OEM'
	AND V.CreationDate >= DATEADD(day,-45,CURRENT_TIMESTAMP)
	AND L.LocationSubType IN ('Port','Railyard')



--------------------------------------------------------

	SELECT @ReportName = 'Daily Operation Report'

	
	SELECT  @DailySDCReportPath =ValueDescription+REPLACE(CONVERT(VARCHAR(10), @ScheduleDate, 3), '/', '')+ '.htm'
	FROM SettingTable
	WHERE ValueKey = 'DailySDCReportPath'
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Daily SDC Report Path'
		GOTO Error_Encountered2
	END


	IF DATALENGTH(ISNULL( @DailySDCReportPath,'')) < 1
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Status = 'Error Getting Daily SDC Report Path'
		GOTO Error_Encountered2
	END
	
	

SET @rReturnFileName = @DailySDCReportPath


	SELECT @ErrorID = 0
	SELECT @LoopCounter = 0
		

	--print 'cursor open'
			
	SELECT @CommandString = 'del '+@DailySDCReportPath
	EXEC master..xp_cmdshell @CommandString
	
	EXEC sp_AppendToFile @DailySDCReportPath, '<html>'
	EXEC sp_AppendToFile @DailySDCReportPath, '<style>'
	EXEC sp_AppendToFile @DailySDCReportPath, 'p            {font-family: Verdana, Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.ReportTitle   {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '              font-size: 11pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '              color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '              }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.URBBold     {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 10pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.URB         {font-family: Verdana, Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 10pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.Title       {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 15pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.ABBold      {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 10pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.AB          {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 10pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.VBHeader    {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 9pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.VB          {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 9pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.SBHeader    {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 12pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.SB          {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 10pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.SBFooter    {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 10pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.Disclosure  {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 9pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             text-decoration: underline;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.AucDisc     {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 9pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, '.CopyInd    {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-size: 12pt;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             color: black;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @DailySDCReportPath, '             }'
	EXEC sp_AppendToFile @DailySDCReportPath, 'table.gridtable {font-family: verdana,arial,sans-serif;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		 font-size:11px;'
	EXEC sp_AppendToFile @DailySDCReportPath, '	 	 color:#333333;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		 border-width: 1px;'
	EXEC sp_AppendToFile @DailySDCReportPath, ' 		 border-color: #666666;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		 border-collapse: collapse;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		}'
	EXEC sp_AppendToFile @DailySDCReportPath, '		table.gridtable th {'
	EXEC sp_AppendToFile @DailySDCReportPath, '		border-width: 1px;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		padding: 8px;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		border-style: solid;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		border-color: #666666;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		background-color: #dedede;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		}'
	EXEC sp_AppendToFile @DailySDCReportPath, '		table.gridtable td {'
	EXEC sp_AppendToFile @DailySDCReportPath, '		border-width: 1px;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		padding: 8px;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		border-style: solid;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		border-color: #666666;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		background-color: #ffffff;'
	EXEC sp_AppendToFile @DailySDCReportPath, '		}'
	EXEC sp_AppendToFile @DailySDCReportPath, '</style>'
	
	



	--Report Name
	SELECT @AppendString = '<p class="Title">' + @ReportName
	EXEC sp_AppendToFile @DailySDCReportPath, @AppendString
	--Business Date
	SELECT @AppendString = 'For Day Ending: ' + CONVERT(varchar(10),@ScheduleDate,101)
	EXEC sp_AppendToFile @DailySDCReportPath, @AppendString
	EXEC sp_AppendToFile @DailySDCReportPath, '</p>'
----------------------------------------------------------------	


--Units Status
--Pipeline Details
--Merceds Ontime Percentage
--Honda Ontime Percentage
--CSA Scores
--Truck Maintenance Service
--Truck Inspection Expiry


--table 1 opening (Units Status)
	EXEC sp_AppendToFile @DailySDCReportPath,'<table width =800 class="gridtable">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<col width=200> <col width=200><col width=200> <col width=200>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<caption><strong>Units Status</strong></caption>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Shipped Yesterday</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Shipped Today</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Tendered Today</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Units Available</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 


	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 

	SELECT @AppendString = '<td align=center>'+  CONVERT(varchar(10),@UnitsShippedYesterday) 
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
		

	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@ShippedToday)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'


	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@TenderedToday)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'


	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@UnitsAvailable)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'


	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 

	EXEC sp_AppendToFile @DailySDCReportPath, '</table>'

-- table 1 Closing


--table 2 opening (Unit Staus Part 2)


	EXEC sp_AppendToFile @DailySDCReportPath,'<table width =800 class="gridtable">'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Over 7 days</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Total Pipeline</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Active Drivers</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>'

	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 	

	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@UnitsOver7Days)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@TotalPipeLine)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'

	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@TotalActiveDrivers)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'

	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 


--table 2 Closing

	
	EXEC sp_AppendToFile @DailySDCReportPath, '</table>'

	EXEC sp_AppendToFile @DailySDCReportPath, '</p>'
	EXEC sp_AppendToFile @DailySDCReportPath, '</p>'


			
--PipeLine-----------------------------------------------------------------

	DECLARE DailyExceutiveReportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
	SELECT CASE WHEN DATALENGTH(C.ShortName) > 0 THEN C.ShortName ELSE C.CustomerName END TheCustomer,
		CASE WHEN DATALENGTH(L.LocationShortName) > 0 THEN L.LocationShortName ELSE L.LocationName END TheLocation,
		COUNT(*)FROM Vehicle V
		LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
		LEFT JOIN Location L ON V.PickupLocationID = L.LocationID
		WHERE V.AvailableForPickupDate IS NULL
		AND C.CustomerType = 'OEM'
		--AND V.CreationDate >= DATEADD(day,-45,CURRENT_TIMESTAMP)
		AND V.CreationDate >= DATEADD(day,-45,@StartDate)
		AND L.LocationSubType IN ('Port','Railyard')
		GROUP BY C.CustomerName, C.ShortName, L.LocationName,L.LocationShortName
		Having(Count(*))>10
		ORDER BY TheLocation,TheCustomer



	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN DailyExceutiveReportCursor
	
 BEGIN TRAN	
	
		
	--SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH DailyExceutiveReportCursor INTO @CustomerName,@TerminalName,@UnitsInPipeLine

--1
	EXEC sp_AppendToFile @DailySDCReportPath,'<table  width =800 class="gridtable">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<col width="200">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<caption><strong>Pipeline Details</strong></caption>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Terminal</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Customer</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Units</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>'
--1


	SELECT @PreviousTerminal = ''
	
	WHILE @@FETCH_STATUS = 0
	BEGIN


--2
	

	SELECT @LoopCounter = @LoopCounter + 1
	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 


	IF @TerminalName=@PreviousTerminal 
	BEGIN
	SELECT @AppendString = '<td>&nbsp'
	END

	IF  @TerminalName<>@PreviousTerminal 
	BEGIN
	SELECT @AppendString = '<td>'+@TerminalName
	END



	--SELECT @AppendString = '<td>'+@TerminalName
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	SELECT @AppendString = '<td>'+@CustomerName
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	SELECT @AppendString = '<td align=right>'+ CONVERT(varchar(10),@UnitsInPipeLine)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 
	

	SELECT @PreviousTerminal = @TerminalName


--2



		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating record'
			GOTO Error_Encountered
		END
		
		
		FETCH DailyExceutiveReportCursor INTO @CustomerName,@TerminalName,@UnitsInPipeLine
	
	END 
	
	
		CLOSE DailyExceutiveReportCursor
		DEALLOCATE DailyExceutiveReportCursor



	EXEC sp_AppendToFile @DailySDCReportPath, '</table>'



	EXEC sp_AppendToFile @DailySDCReportPath, '</p>'
	EXEC sp_AppendToFile @DailySDCReportPath, '</p>'




--2nd CURSOR--ToyotaPerformanceSummary

	DECLARE DailyExceutiveReportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
	SELECT  CASE WHEN DATALENGTH(L.LocationShortName) > 0 THEN L.LocationShortName ELSE L.LocationName END TheLocation,TPS.OnTimePercentage
	FROM ToyotaPerformanceSummary TPS
	LEFT JOIN Location L ON TPS.LocationID = L.LocationID
	WHERE TPS.LocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='ToyotaLocationCode' AND RecordStatus='Active')     
	AND  TPS.CreationDate IN (SELECT Top 1 CreationDate FROM ToyotaPerformanceSummary ORDER BY CreationDate DESC)	


	
	OPEN DailyExceutiveReportCursor

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	--new
	--SELECT @@ERROR = ''
	--NEW
	

	FETCH DailyExceutiveReportCursor INTO @ToyotaLocationName,@ToyotaOnTimePercentage


	--1
	EXEC sp_AppendToFile @DailySDCReportPath,'<table  width =800 class="gridtable">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<col width="200">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<caption><strong>Toyota Performance</strong></caption>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Location</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>On Time %</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>'
	--2





	WHILE @@FETCH_STATUS = 0

	BEGIN

	

	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 

	
	SELECT @AppendString = '<td>'+@ToyotaLocationName
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	

	SELECT @AppendString = '<td align=right>'+CONVERT(varchar(10),@ToyotaOnTimePercentage)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>'



		IF @@Error <> 0
		BEGIN

			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating  record'
			GOTO Error_Encountered
		END
			

	FETCH DailyExceutiveReportCursor INTO @ToyotaLocationName,@ToyotaOnTimePercentage
	
		

	END 



	EXEC sp_AppendToFile @DailySDCReportPath, '</table>'




	CLOSE DailyExceutiveReportCursor
	DEALLOCATE DailyExceutiveReportCursor


--END

	EXEC sp_AppendToFile @DailySDCReportPath, '</p>'
	EXEC sp_AppendToFile @DailySDCReportPath, '</p>'



--3rd CURSOR Mercedes
	DECLARE DailyExceutiveReportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
	SELECT TheLocation,ROUND(convert(decimal(19,2),Sum(StatCount))/COUNT(*)*100 ,2)
	FROM(SELECT L1.PickupLocationID,CASE WHEN DATALENGTH(L3.LocationShortName) > 0 THEN L3.LocationShortName ELSE L3.LocationName END TheLocation,
	CASE WHEN DATEDIFF(dy,L1.DateAvailable,L2.PickupDate)
	-(SELECT COUNT(*) FROM Calendar WHERE CalendarDate Between L1.DateAvailable AND L2.PickupDate AND DayName IN ('Saturday','Sunday'))
	- (SELECT Count(*) FROM Holiday H Where HolidayDate Between L1.DateAvailable AND L2.PickupDate) <= LPS.StandardDays  THEN 1 ELSE 0 END StatCount
	FROM Vehicle V
	LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
	AND L1.LegNumber = 1
	LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
	AND L2.FinalLegInd = 1
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'MercedesCustomerID' )
	AND V.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='MercedesLocationCode' AND RecordStatus='Active')
	AND (L1.PickupDate BETWEEN  DATEADD(qq,DATEDIFF(qq,0,@Startdate),0) AND  DATEADD(qq,DATEDIFF(qq,-1,@Startdate),-1))

	--AND (L1.PickupDate BETWEEN  DATEADD(qq,DATEDIFF(qq,0,current_timestamp),0) AND  DATEADD(qq,DATEDIFF(qq,-1,current_timestamp),-1))

	AND LPS.StandardDays IS NOT NULL)
	AS TempTable
	Group By TheLocation


	
	OPEN DailyExceutiveReportCursor

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	--new
	--SELECT @@ERROR = ''
	--NEW
	

	FETCH DailyExceutiveReportCursor INTO @MercedesLocationName,@MercedesOnTimePercentageQuarter


	--1
	EXEC sp_AppendToFile @DailySDCReportPath,'<table  width =800 class="gridtable">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<col width="200"><col width="200"><col width="200"><col width="200">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<caption><strong>Mercedes Performance</strong></caption>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Location</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Qtr</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Month</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Week</th>'
	
	
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>'
	--2





	WHILE @@FETCH_STATUS = 0

	BEGIN


--********************************************************************************
--current month

--TheLocation,
SELECT @MercedesOnTimePercentageMonth = ROUND(convert(decimal(19,2),Sum(StatCount))/COUNT(*)*100 ,2)
FROM(SELECT L1.PickupLocationID,CASE WHEN DATALENGTH(L3.LocationShortName) > 0 THEN L3.LocationShortName ELSE L3.LocationName END TheLocation,
CASE WHEN DATEDIFF(dy,L1.DateAvailable,L2.PickupDate)
-(SELECT COUNT(*) FROM Calendar WHERE CalendarDate Between L1.DateAvailable AND L2.PickupDate AND DayName IN ('Saturday','Sunday'))
- (SELECT Count(*) FROM Holiday H Where HolidayDate Between L1.DateAvailable AND L2.PickupDate) <= LPS.StandardDays  THEN 1 ELSE 0 END StatCount
FROM Vehicle V
LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
AND L1.LegNumber = 1
LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
AND L2.FinalLegInd = 1
LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
AND V.PickupLocationID = LPS.OriginID
AND V.DropoffLocationID = LPS.DestinationID
LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'MercedesCustomerID' )
AND V.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='MercedesLocationCode' AND RecordStatus='Active')
AND L1.PickupDate>= CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(@StartDate)-1),@StartDate),101)

--AND L1.PickupDate>= CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(current_timestamp)-1),current_timestamp),101)

AND LPS.StandardDays IS NOT NULL )
AS TempTable
Group By TheLocation
Having Thelocation =@MercedesLocationName

---Week

SELECT @MercedesOnTimePercentageWeek=ROUND(CONVERT(decimal(19,2),Sum(StatCount))/COUNT(*)*100 ,2)
FROM(SELECT L1.PickupLocationID,CASE WHEN DATALENGTH(L3.LocationShortName) > 0 THEN L3.LocationShortName ELSE L3.LocationName END TheLocation,
CASE WHEN DATEDIFF(dy,L1.DateAvailable,L2.PickupDate)
-(SELECT COUNT(*) FROM Calendar WHERE CalendarDate Between L1.DateAvailable AND L2.PickupDate AND DayName IN ('Saturday','Sunday'))
- (SELECT Count(*) FROM Holiday H Where HolidayDate Between L1.DateAvailable AND L2.PickupDate) <= LPS.StandardDays  THEN 1 ELSE 0 END StatCount
FROM Vehicle V
LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
AND L1.LegNumber = 1
LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
AND L2.FinalLegInd = 1
LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
AND V.PickupLocationID = LPS.OriginID
AND V.DropoffLocationID = LPS.DestinationID
LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'MercedesCustomerID' )
AND L1.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='MercedesLocationCode' AND RecordStatus='Active')
AND (L1.PickupDate BETWEEN CONVERT(varchar, DATEADD(dd, -(DATEPART(dw, @StartDate) - 1),  @StartDate), 101)
AND CONVERT(varchar, DATEADD(dd, (7 - DATEPART(dw,  @StartDate)),  @StartDate), 101))

--AND (L1.PickupDate BETWEEN CONVERT(varchar, DATEADD(dd, -(DATEPART(dw, CURRENT_TIMESTAMP) - 1), CURRENT_TIMESTAMP), 101)
--AND CONVERT(varchar, DATEADD(dd, (7 - DATEPART(dw, CURRENT_TIMESTAMP)), CURRENT_TIMESTAMP), 101))

AND LPS.StandardDays IS NOT NULL)
AS TempTable
Group By TheLocation
Having Thelocation =@MercedesLocationName
--***********************************************************************************


	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 

	
	SELECT @AppendString = '<td>'+@MercedesLocationName
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	

	SELECT @AppendString = '<td align=center>'+CONVERT(varchar(10),@MercedesOnTimePercentageQuarter)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
--***********
	SELECT @AppendString = '<td align=center>'+CONVERT(varchar(10),@MercedesOnTimePercentageMonth)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'


	SELECT @AppendString = '<td align=center>'+CONVERT(varchar(10),@MercedesOnTimePercentageWeek)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'

	
--**********

	
	
	
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>'



		IF @@Error <> 0
		BEGIN

			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating  record'
			GOTO Error_Encountered
		END
			

	FETCH DailyExceutiveReportCursor INTO @MercedesLocationName,@MercedesOnTimePercentageQuarter
--,@MercedesOnTimePercentageMonth,@MercedesOnTimePercentageWeek
	
		

	END 



	EXEC sp_AppendToFile @DailySDCReportPath, '</table>'



	CLOSE DailyExceutiveReportCursor
	DEALLOCATE DailyExceutiveReportCursor

---have to fixed data for month and year by nesting table


	EXEC sp_AppendToFile @DailySDCReportPath, '</p>'
	EXEC sp_AppendToFile @DailySDCReportPath, '</p>'




--4th CURSOR Honda
	DECLARE DailyExceutiveReportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
	SELECT CASE WHEN DATALENGTH(L3.LocationShortName) > 0 THEN L3.LocationShortName ELSE L3.LocationName END TheLocation,
	ROUND(CONVERT(decimal(19,2),(SUM (CASE WHEN
	DATEDIFF(hh,DATEADD(hh,30,CONVERT(VARCHAR(10),L1.DateAvailable,101)),L1.DropoffDate) <= LPS.StandardDays  THEN 1 ELSE 0 END)))/
	COUNT(*)*100 ,2) as OnTimePercentage
	FROM Vehicle V
	LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
	AND L1.LegNumber = 1
	LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
	AND L2.FinalLegInd = 1
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'HondaCustomerID' )
	AND L1.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='HondaLocationCode' AND RecordStatus='Active')
	AND (L2.DateAvailable BETWEEN DATEADD(MONTH, DATEDIFF(MONTH, 0, @StartDate)-1, 0)
	AND DATEADD(MONTH, DATEDIFF(MONTH, -1, @StartDate)-1, -1))
	--AND DATEADD(MONTH, DATEDIFF(MONTH, -1, current_timestamp)-1, -1))
	AND L2.DropOffDate IS NOT NULL
	AND LPS.StandardDays IS NOT NULL
	GROUP BY CASE WHEN DATALENGTH(L3.LocationShortName) > 0 THEN L3.LocationShortName ELSE L3.LocationName END


	
	OPEN DailyExceutiveReportCursor

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	--new
	--SELECT @@ERROR = ''
	--NEW
	

	FETCH DailyExceutiveReportCursor INTO @HondaLocationName,@HondaOnTimePercentagePrevMonth



	--1
	EXEC sp_AppendToFile @DailySDCReportPath,'<table  width =800 class="gridtable">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<col width="200"><col width="200"><col width="200"><col width="200">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<caption><strong>Honda Performance</strong></caption>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Location</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Prev-Month</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Cur-Month</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Over5Days</th>'
	
	
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>'
	--2




	WHILE @@FETCH_STATUS = 0

	BEGIN


	---current month
	
	SELECT 
	--CASE WHEN DATALENGTH(L3.LocationShortName) > 0 THEN L3.LocationShortName ELSE L3.LocationName END  TheLocation,
	@HondaOnTimePercentageCurMonth =
	ROUND(convert(decimal(19,2),(SUM (CASE WHEN
	DATEDIFF(hh,DATEADD(hh,30,CONVERT(VARCHAR(10),L1.DateAvailable,101)),L1.DropoffDate) <= LPS.StandardDays  THEN 1 ELSE 0 END)))/
	COUNT(*)*100 ,2) 
	--as OnTimePercentage
	FROM Vehicle V
	LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
	AND L1.LegNumber = 1
	LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
	AND L2.FinalLegInd = 1
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'HondaCustomerID' )
	AND L1.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='HondaLocationCode' AND RecordStatus='Active')
	--AND L2.DateAvailable>= CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(current_timestamp)-1),current_timestamp),101)
	AND L2.DateAvailable>= CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(@StartDate)-1),@StartDate),101)
	AND L2.DropOffDate IS NOT NULL
	AND LPS.StandardDays IS NOT NULL
	GROUP BY CASE WHEN DATALENGTH(L3.LocationShortName) > 0 THEN L3.LocationShortName ELSE L3.LocationName END
	HAVING CASE WHEN DATALENGTH(L3.LocationShortName) > 0 THEN L3.LocationShortName ELSE L3.LocationName END = @HondaLocationName

--='Brookfield'



--over 5 days count



	SELECT 
	--CASE WHEN DATALENGTH(L3.LocationShortName) > 0 THEN L3.LocationShortName ELSE L3.LocationName END TheLocation,
	@HondaOver5DaysCount=Count(*)
	--as Old5day
	FROM Vehicle V
	LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
	AND L1.LegNumber = 1
	LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
	AND L2.FinalLegInd = 1
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'HondaCustomerID' )
	AND V.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='HondaLocationCode' AND RecordStatus='Active')
	AND DATEDIFF(hh,DATEADD(hh,30,CONVERT(VARCHAR(10),L2.DateAvailable,101)),L2.DropoffDate)>=150
	AND L2.DropOffDate IS NOT NULL
	AND LPS.StandardDays IS NOT NULL
	--AND L2.DateAvailable>= CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(current_timestamp)-1),current_timestamp),101)
	AND L2.DateAvailable>= CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(@StartDate)-1),@StartDate),101)
	GROUP BY CASE WHEN DATALENGTH(L3.LocationShortName) > 0 THEN L3.LocationShortName ELSE L3.LocationName END
	Having CASE WHEN DATALENGTH(L3.LocationShortName) > 0 THEN L3.LocationShortName ELSE L3.LocationName END =@HondaLocationName


	

	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 

	
	SELECT @AppendString = '<td>'+@HondaLocationName
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	

	SELECT @AppendString = '<td align=center>'+CONVERT(varchar(10),@HondaOnTimePercentagePrevMonth)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	


	
	
	SELECT @AppendString = '<td align=center>'+CONVERT(varchar(10),@HondaOnTimePercentageCurMonth)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	



 
	SELECT @AppendString = '<td align=center>'+CONVERT(varchar(10),@HondaOver5DaysCount)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
	
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>'



		IF @@Error <> 0
		BEGIN

			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating  record'
			GOTO Error_Encountered
		END
			




	FETCH DailyExceutiveReportCursor INTO @HondaLocationName,@HondaOnTimePercentagePrevMonth
	
		

	END 



	EXEC sp_AppendToFile @DailySDCReportPath, '</table>'



		CLOSE DailyExceutiveReportCursor
		DEALLOCATE DailyExceutiveReportCursor

EXEC sp_AppendToFile @DailySDCReportPath, '</p>'
EXEC sp_AppendToFile @DailySDCReportPath, '</p>'





SELECT @StandardUnSafeDriving =ValueDescription FROM SettingTable WHERE ValueKey = 'UnsafeDriving'
SELECT @StandardHOSCompliance =ValueDescription FROM SettingTable WHERE ValueKey = 'HOSCompliance'
SELECT @StandardDriverFitness =ValueDescription FROM SettingTable WHERE ValueKey = 'DriverFitness'
SELECT @StandardVehicleMaintenance=ValueDescription FROM SettingTable WHERE ValueKey = 'VehicleMaintenance'
SELECT @StandardCrashIndicator=ValueDescription FROM SettingTable WHERE ValueKey = 'CrashIndicator'


SELECT TOP 1 @PeriodEndDate=PeriodEndDate,@CurrentUnsafeDriving=UnsafeDriving,@CurrentHOSCompliance=HOSCompliance,@CurrentDriverFitness=DriverFitness,@CurrentVehicleMaintenance=VehicleMaintenance,@CurrentCrashIndicator=CrashIndicator FROM CSAScore ORDER BY PeriodEndDate DESC


SELECT TOP 1 @PreviousUnsafeDriving=UnsafeDriving,@PreviousHOSCompliance=HOSCompliance,@PreviousDriverFitness=DriverFitness,@PreviousVehicleMaintenance=VehicleMaintenance,@PreviousCrashIndicator=CrashIndicator FROM CSAScore WHERE PeriodEndDate <@PeriodEndDate
ORDER BY PeriodEndDate DESC



--table opening
	EXEC sp_AppendToFile @DailySDCReportPath,'<table width =800 class="gridtable">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<col width="200"><col width="200"><col width="200"><col width="200">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<caption><strong>CSA SCORES</strong></caption>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<th></th>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<th>THRESHOLD</th>'
	SELECT @AppendString = '<th>CURRENT'+ '<br/>'+ '('+CONVERT(varchar(10),@PeriodEndDate,101) +')'
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>PREVIOUS</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 


	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 
	EXEC sp_AppendToFile @DailySDCReportPath,'<td>Unsafe Driving</td>'
	
	SELECT @AppendString = '<td align=center>'+  CONVERT(varchar(10),@StandardUnSafeDriving) 
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'

	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	SELECT @AppendString = '<td align=center>'+  CONVERT(varchar(10),@CurrentUnsafeDriving) 
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
		


	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@PreviousUnsafeDriving)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 
	



	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 

	EXEC sp_AppendToFile @DailySDCReportPath,'<td>HOSCompliance</td>'


	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@StandardHOSCompliance)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'


	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@CurrentHOSCompliance)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'


	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@PreviousHOSCompliance)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'


	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 
	
	
	
	
	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 
	
	

	EXEC sp_AppendToFile @DailySDCReportPath,'<td>Driver Fitness</td>'

	
	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@StandardDriverFitness)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
	
	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@CurrentDriverFitness)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
	
	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@PreviousDriverFitness)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
		
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 
	
	
	
	
	
	
	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 
		
		
	EXEC sp_AppendToFile @DailySDCReportPath,'<td>Vehicle Maint</td>'

		
	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@StandardVehicleMaintenance)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
		
		
	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@CurrentVehicleMaintenance)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
		
		
	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@PreviousVehicleMaintenance)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
		
			
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 
	
	
	
	
	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 
			
			
	EXEC sp_AppendToFile @DailySDCReportPath,'<td>Crash Indicator</td>'
	
			
	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@StandardCrashIndicator)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
			
			
	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@CurrentCrashIndicator)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
			
			
	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@PreviousCrashIndicator)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
			
				
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 


	EXEC sp_AppendToFile @DailySDCReportPath, '</table>'

-- table  Closing

EXEC sp_AppendToFile @DailySDCReportPath, '</p>'
EXEC sp_AppendToFile @DailySDCReportPath, '</p>'


---Cursor for truck maintenance service



DECLARE DailyExceutiveReportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR

--@stardate=?

	SELECT CONVERT(varchar(10),(DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE())+1,0))),101),ISNULL(CONVERT(VARCHAR(10),InspectionExpiryDate,101),CONVERT(varchar(10),(DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE())+1,0))),101)) as DayName,T.TruckNumber,
	CASE WHEN (U.LastName IS NULL AND U.FirstName IS NULL)  THEN 'Not Assigned'  Else U.LastName +' '+ U.FirstName  END as  DriverName
	FROM TRUCK T
	LEFT JOIN Driver D ON T.TruckID=D.CurrentTruckID
	AND D.RecordStatus = 'Active'
	AND D.OutsideCarrierInd = 0
	LEFT JOIN Users U ON D.UserID = U.UserID
	WHERE
	ISNULL(InspectionExpiryDate,CONVERT(varchar(10),(DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE())+1,0))),101))
	<=CONVERT(varchar(10),DATEADD(day,-(DATEPART(day,DATEADD(month,1,CURRENT_TIMESTAMP)))+1,DATEADD(month,1,CURRENT_TIMESTAMP)),101)
	AND T.RecordStatus = 'Active'
	AND T.TruckStatus NOT IN ('Retired','Sold')
	And T.OutsideCarrierTruckInd =0
	And T.TruckNumber Is NOT NULL
	ORDER BY T.TruckNumber



	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN DailyExceutiveReportCursor
	
		
	--SELECT @CreationDate = CURRENT_TIMESTAMP
	


	FETCH DailyExceutiveReportCursor INTO @CurrentDay,@DayName,@TruckNumber,@DriverName


--1
	EXEC sp_AppendToFile @DailySDCReportPath,'<table  width =800 class="gridtable">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<col width="200"><col width="200">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<caption><strong>Truck Maintenance Service</strong></caption>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Date</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Truck</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Driver</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>'
--1


	SELECT @PreviousDay = ''

	WHILE @@FETCH_STATUS = 0
	BEGIN


--2
	SELECT @LoopCounter = @LoopCounter + 1
	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 

	
	IF @DayName=@PreviousDay
	BEGIN
	SELECT @AppendString = '<td>&nbsp'
	END

	IF  @DayName<>@PreviousDay
	BEGIN
	SELECT @AppendString = '<td>'+@DayName
	END


	--SELECT @AppendString = '<td>'+@MaintDay
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
	SELECT @AppendString = '<td align=center>'+@TruckNumber
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
	SELECT @AppendString = '<td>'+ @DriverName
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 
	




	SELECT @PreviousDay = @DayName


--2



		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating record'
			GOTO Error_Encountered
		END
		
		
		FETCH DailyExceutiveReportCursor INTO @CurrentDay,@DayName,@TruckNumber,@DriverName

	
	END 
	
	
		CLOSE DailyExceutiveReportCursor
		DEALLOCATE DailyExceutiveReportCursor



	EXEC sp_AppendToFile @DailySDCReportPath, '</table>'






EXEC sp_AppendToFile @DailySDCReportPath, '</p>'
EXEC sp_AppendToFile @DailySDCReportPath, '</p>'

---Cursor for Inspection Expiry



DECLARE DailyExceutiveReportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR

--@startDate?

	SELECT  LEFT(DATENAME(dw , NotAvailableFromDate),3)+ '-'+  CONVERT(VARCHAR(5),NotAvailableFromDate,101) as DayName,T.TruckNumber,U.LastName +' '+ U.FirstName as DriverName,D.DriverID
	FROM DriverNotAvailableDates DN
	LEFT JOIN Driver D ON DN.DriverID = D.DriverID
	LEFT JOIN Truck T ON D.CurrentTruckID = T.TruckID
	LEFT JOIN Users U ON D.UserID = U.UserID
	WHERE NotavailableCode Like '%service%'
	AND(NotAvailableFromDate>=CONVERT(VARCHAR(10),CURRENT_TIMESTAMP,101)
	AND NotAvailableFromDate<DATEADD(day,7,CONVERT(VARCHAR(10),CURRENT_TIMESTAMP,101)))
	ORDER BY CONVERT(VARCHAR(10),NotAvailableFromDate,101)



	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN DailyExceutiveReportCursor
	
		
	


	FETCH DailyExceutiveReportCursor INTO @MaintDay,@TruckNumber,@DriverName,@iDriverID



--1
	EXEC sp_AppendToFile @DailySDCReportPath,'<table  width =800 class="gridtable">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<col width="200">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<caption><strong>Truck Inspection Expiry</strong></caption>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Truck</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Driver</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>'
--1


	--SELECT @PreviousDay = ''

	WHILE @@FETCH_STATUS = 0
	BEGIN


--2
	SELECT @LoopCounter = @LoopCounter + 1
	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 

	
	--IF @DayName=@PreviousDay
	--BEGIN
	--SELECT @AppendString = '<td>&nbsp'
	--END

	--IF  @DayName<>@PreviousDay
	--BEGIN
	--SELECT @AppendString = '<td>'+@DayName
	--END


	--SELECT @AppendString = '<td>'+@MaintDay
	--EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	--EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
	SELECT @AppendString = '<td>'+@TruckNumber
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
	SELECT @AppendString = '<td>'+ @DriverName
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 
	




	--SELECT @PreviousDay = @DayName


--2



		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating record'
			GOTO Error_Encountered
		END
		
		
		FETCH DailyExceutiveReportCursor INTO @MaintDay,@TruckNumber,@DriverName,@iDriverID


	
	END 
	
	
		--CLOSE DailyExceutiveReportCursor
		--DEALLOCATE DailyExceutiveReportCursor



	EXEC sp_AppendToFile @DailySDCReportPath, '</table>'



------**************

CLOSE DailyExceutiveReportCursor
DEALLOCATE DailyExceutiveReportCursor


EXEC sp_AppendToFile @DailySDCReportPath, '</p>'
EXEC sp_AppendToFile @DailySDCReportPath, '</p>'




---Cursor for Active Truck and Drivers



DECLARE DailyExceutiveReportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
	SELECT T.TruckNumber,CASE WHEN (D.DriverNumber IS NULL)  THEN 'Not Assigned'  Else D.DriverNumber  END as  DriverNumber,CASE WHEN (U.LastName IS NULL AND U.FirstName IS NULL)  THEN 'Not Assigned'  Else U.LastName +' '+ U.FirstName  END as  DriverName
	FROM TRUCK T
	LEFT JOIN Driver D ON T.TruckID=D.CurrentTruckID
	AND D.RecordStatus = 'Active'
	AND D.OutsideCarrierInd = 0
	LEFT JOIN Users U ON D.UserID = U.UserID
	WHERE
	T.RecordStatus = 'Active'
	AND T.TruckStatus NOT IN ('Retired','Sold')
	And T.OutsideCarrierTruckInd =0
	And T.TruckNumber IS NOT NULL
	And T.TruckNumber  <>'001'
	ORDER BY DriverName
	--T.TruckNumber



	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN DailyExceutiveReportCursor
	


	FETCH DailyExceutiveReportCursor INTO @TruckNumber,@DriverNumber,@DriverName



--1
	EXEC sp_AppendToFile @DailySDCReportPath,'<table  width =800 class="gridtable">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<col width="200"><col width="200">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<caption><strong>List Of Active Truck and Drivers</strong></caption>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Truck</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Driver Number</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Driver</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>'
--1


	--SELECT @PreviousDay = ''

	WHILE @@FETCH_STATUS = 0
	BEGIN


--2
	SELECT @LoopCounter = @LoopCounter + 1
	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 

	
	
	SELECT @AppendString = '<td>'+@TruckNumber
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	

	SELECT @AppendString = '<td>'+@DriverNumber
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'



	SELECT @AppendString = '<td>'+ @DriverName
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
	
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 
	




		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating record'
			GOTO Error_Encountered
		END
		
		
		FETCH DailyExceutiveReportCursor INTO @TruckNumber,@DriverNumber,@DriverName


	
	END 
	
	
		--CLOSE DailyExceutiveReportCursor
		--DEALLOCATE DailyExceutiveReportCursor



	EXEC sp_AppendToFile @DailySDCReportPath, '</table>'



---**************

EXEC sp_AppendToFile @DailySDCReportPath, '</p>'
EXEC sp_AppendToFile @DailySDCReportPath, '</p>'


-------VPC,Port and Export Counts


SELECT @VPCComplete=ISNULL(VPC.Complete,0),@VPCShipped=ISNULL(VPC.Shipped,0) FROM VPCProductionSchedule VPC WHERE VPC.ScheduleDate = CONVERT(VARCHAR(10),@StartDate,101)
--DATEADD(day,-0,CONVERT(VARCHAR(10),CURRENT_TIMESTAMP,101))

SELECT @CountPortStorage = COUNT(*) FROM PortStorageVehicles PSV WHERE PSV.Datein IS NOT NULL AND PSV.Dateout IS NULL

SELECT @CountAutoportExport= COUNT(*) FROM  AutoportExportVehicles AEV WHERE AEV.DateReceived IS NOT NULL AND DateShipped IS NULL


	
--Last table Opening (VPC Processed,VPC Shipped,Count Port and Count Exports)

	EXEC sp_AppendToFile @DailySDCReportPath,'<table width =800 class="gridtable">'
	EXEC sp_AppendToFile @DailySDCReportPath,'<col width=200> <col width=200><col width=200> <col width=200>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<caption><strong>VPC - Port Storage and Export Counts</strong></caption>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>'
 	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Subaru Processed</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Subaru Shipped</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Storage Count</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'<th>Export Count</th>'
	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 


	EXEC sp_AppendToFile @DailySDCReportPath,'<tr>' 





	--IF CONVERT(varchar(10),@VPCComplete) =''
	--BEGIN
	--SELECT @AppendString = '<td>&nbsp'
	--END
	--ELSE
	--SELECT @AppendString = '<td align=center>'+  CONVERT(varchar(10),@VPCComplete) 
	--IF  @VPCComplete<>''
	--BEGIN
	--SELECT @AppendString = '<td align=center>'+  CONVERT(varchar(10),@VPCComplete) 
	--END



	SELECT @AppendString = '<td align=center>'+  CONVERT(varchar(10),@VPCComplete) 
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'
		

	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@VPCShipped)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'


	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@CountPortStorage)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'


	SELECT @AppendString = '<td align=center>'+ CONVERT(varchar(10),@CountAutoportExport)
	EXEC sp_AppendToFile @DailySDCReportPath,@AppendString
	EXEC sp_AppendToFile @DailySDCReportPath,'</td>'


	EXEC sp_AppendToFile @DailySDCReportPath,'</tr>' 

	EXEC sp_AppendToFile @DailySDCReportPath, '</table>'




-------***-- Last table Closing





	EXEC sp_AppendToFile @DailySDCReportPath, '</html>'



	
	Error_Encountered:
	
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE DailyExceutiveReportCursor
		DEALLOCATE DailyExceutiveReportCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE DailyExceutiveReportCursor
		DEALLOCATE DailyExceutiveReportCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END
	
	Error_Encountered2:
	
	IF @ErrorID = 0
	BEGIN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END
	
	Do_Return:
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	SET @rReturnFileName = @rReturnFileName
	
	RETURN
END

GO
