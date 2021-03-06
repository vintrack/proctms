USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spDashBoard]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[spDashBoard] (@ScheduleDate datetime,@LocationID int)
AS
BEGIN
	set nocount on
	DECLARE
	@ErrorID		int,
	@ErrorEncountered	varchar(5000),
	@LoopCounter		int,
	@ResultCode		int,
	@ReturnCode		int,
	@Status			varchar(100),
	@ReturnMessage		varchar(100),
	@Startdate		datetime,
	@UnitsShippedYesterday	int,
	@ShippedToday		int,
	@TenderedToday		int,
	@UnitsAvailable		int,
	@UnitsOver7Days 	int,
	@ActiveDrivers 		int,
	@TerminalUnitsShippedYesterday	int,
	@TerminalShippedToday		int,
	@TerminalTenderedToday		int,
	@TerminalUnitsAvailable		int,
	@TerminalUnitsOver7Days 	int,
	@TerminalTotalPipeLine 		int,
	@CustomerName		varchar(100),
	@TerminalName		varchar(100)




	/************************************************************************
	*	spDashBoard					        *
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure output the daily dash board  for terminal	*
	*									*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	06/01/2015 SS    Initial version				*
	*									*
	************************************************************************/



 	SELECT @ErrorID =0

	--BEGIN TRAN


	SELECT @StartDate = @ScheduleDate

	---Company Wide Data
	--1-5
	--SELECT @UnitsShippedYesterday = Count(*) FROM Legs WHERE CONVERT(VARCHAR(10),PickupDate,101) = DATEADD(day,-1,CONVERT(VARCHAR(10),@StartDate,101))
	--M
	SELECT @UnitsShippedYesterday = Count(*) FROM Legs WHERE PickupDate >= DATEADD(day,-1,@StartDate) AND  PickupDate <@StartDate


	--SELECT @ShippedToday =  COUNT(*) FROM Legs WHERE CONVERT(VARCHAR(10),PickupDate,101) = CONVERT(VARCHAR(10),@StartDate,101)
	--M
	SELECT @ShippedToday =  COUNT(*) FROM Legs WHERE PickupDate >=@StartDate AND PickupDate< DATEADD(day,1,@StartDate)
	


	--SELECT @TenderedToday = COUNT(*) FROM Legs WHERE CONVERT(VARCHAR(10),DateAvailable,101) = CONVERT(VARCHAR(10),@StartDate,101)
	--M

	SELECT @TenderedToday = COUNT(*) FROM Legs WHERE DateAvailable >=@StartDate AND DateAvailable <DATEADD(day,1,@StartDate)


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

	SELECT  @ActiveDrivers = 0
	--SELECT  @ActiveDrivers = COUNT(Distinct(R.DriverID)) FROM Run R
	--LEFT JOIN RunStops RS ON  R.RunID=RS.RunID
	--WHERE CONVERT(VARCHAR(10), StopDate,101) = CONVERT(VARCHAR(10),@StartDate,101)

---Terminal Data--1-5

	--SELECT @TerminalUnitsShippedYesterday = Count(*) FROM Legs 
	--WHERE CONVERT(VARCHAR(10),PickupDate,101) = DATEADD(day,-1,CONVERT(VARCHAR(10),@StartDate,101))
	--AND PickupLocationID = @LocationID     
	--M

	SELECT @TerminalUnitsShippedYesterday = Count(*) FROM Legs 
	WHERE PickupDate >= DATEADD(day,-1,@StartDate) AND  PickupDate <@StartDate
	AND PickupLocationID = @LocationID     


	--SELECT @TerminalShippedToday = Count(*)  FROM Legs WHERE 
	--CONVERT(VARCHAR(10),PickupDate,101) = CONVERT(VARCHAR(10),@StartDate,101)
	--AND PickupLocationID = @LocationID
	
	--M

	SELECT @TerminalShippedToday = Count(*)  FROM Legs WHERE 
	PickupDate >=@StartDate AND PickupDate< DATEADD(day,1,@StartDate)
	AND PickupLocationID = @LocationID



	--SELECT @TerminalTenderedToday = COUNT(*) FROM Legs WHERE 
	--CONVERT(VARCHAR(10),DateAvailable,101) = CONVERT(VARCHAR(10),@StartDate,101)
	--AND PickupLocationID = @LocationID

	--M

	SELECT @TerminalTenderedToday = COUNT(*) FROM Legs WHERE 
	DateAvailable >=@StartDate AND DateAvailable <DATEADD(day,1,@StartDate)
	AND PickupLocationID = @LocationID



	SELECT @TerminalUnitsAvailable = COUNT(*) FROM Vehicle V LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
	LEFT JOIN Location L1 ON V.PickupLocationID = L1.LocationID
	WHERE AvailableForPickupDate IS NOT NULL
	AND V.VehicleStatus NOT IN ('EnRoute','Delivered')
	AND C.CustomerType = 'OEM'
	AND V.BilledInd=0
	AND V.PickupLocationID = @LocationID


	SELECT @TerminalUnitsOver7Days = COUNT (*) FROM Customer C
	LEFT JOIN Vehicle V ON C.CustomerID =V.CustomerID
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	WHERE C.CustomerType = 'OEM'
	AND L.PickupDate IS NULL AND L.DateAvailable IS NOT NULL
	AND DATEDIFF(day,L.DateAvailable,@StartDate) >7
	AND L.PickupLocationID = @LocationID




	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error getting dashboard Record'
		GOTO Error_Encountered
	END


	
	Error_Encountered:
	
	IF @ErrorID = 0
	BEGIN
		--COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		--ROLLBACK TRAN
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
	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM',@UnitsShippedYesterday AS UnitsShippedYesterday,
	@ShippedToday AS ShippedToday,@TenderedToday AS TenderedToday,@UnitsAvailable  AS UnitsAvailable,
	@UnitsOver7Days AS UnitsOver7Days,@ActiveDrivers as ActiveDrivers,@TerminalUnitsShippedYesterday AS TerminalUnitsShippedYesterday,
	@TerminalShippedToday AS TerminalShippedToday,@TerminalTenderedToday AS TerminalTenderedToday,@TerminalUnitsAvailable  AS TerminalUnitsAvailable,
	@TerminalUnitsOver7Days AS TerminalUnitsOver7Days




	RETURN
END

GO
