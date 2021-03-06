USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetDashBoardPipeLineDetails]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGetDashBoardPipeLineDetails] (@LocationID int)
AS
BEGIN
	set nocount on
	
	DECLARE
	@Customer		varchar(100),
	@PipeLineCount		int,
	@ErrorID		int,
	@ErrorEncountered	varchar(5000),
	@LoopCounter		int,
	@ResultCode		int,
	@ReturnCode		int,
	@Status			varchar(100),
	@ReturnMessage		varchar(100),
	@CreationDate		datetime

	/************************************************************************
	*	spGetDashBoardPipeLineDetails					*
	*									*
	* Note : have to generalize for main dashboard				*
	*									*
	* Description								*
	* -----------								*
	* This procedure output the daily dash board pipeline for terminal	*
	*									*
	* Change History							*
	* --------------							*
	* Date       Init's Description						*
	* ---------- ------ --------------------------------------------	*
	* 05/29/2015 SS     Initial version					*
	* 07/24/2017 CMK    Added extra filtering for Chrysler Release Code	*
	************************************************************************/

	SELECT @ErrorID =0 
	BEGIN TRAN

	--PipeLine Data

	--Generalization for main dashboard :Pending
	IF (@locationID =0)
	BEGIN
		SELECT CASE WHEN DATALENGTH(C.ShortName) > 0 THEN C.ShortName ELSE C.CustomerName END Customer,
		CASE WHEN DATALENGTH(L.LocationShortName) > 0 THEN L.LocationShortName ELSE L.LocationName END Location,
		COUNT(*)as PipeLineCount
		INTO #TerminalPipeLine1
		FROM Vehicle V
		LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
		LEFT JOIN Location L ON V.PickupLocationID = L.LocationID
		WHERE V.AvailableForPickupDate IS NULL
		AND C.CustomerType = 'OEM'
		AND V.CreationDate >= DATEADD(day,-45,CURRENT_TIMESTAMP)
		AND L.LocationSubType IN ('Port','Railyard')
		AND ISNULL(V.ReleaseCode,'') NOT IN ('D1','E','I','J')	--07/24/2017 - CMK
		GROUP BY C.CustomerName, C.ShortName, L.LocationName,L.LocationShortName
		ORDER BY Location,Customer
	END
	ELSE
	BEGIN
		SELECT CASE WHEN DATALENGTH(C.ShortName) > 0 THEN C.ShortName ELSE C.CustomerName END Customer,
		COUNT(*) as PipeLineCount
		INTO #TerminalPipeLine
		FROM Vehicle V
		LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
		LEFT JOIN Location L ON V.PickupLocationID = L.LocationID
		WHERE V.AvailableForPickupDate IS NULL
		AND C.CustomerType = 'OEM'
		AND V.CreationDate >= DATEADD(day,-45,CURRENT_TIMESTAMP)
		AND L.LocationSubType IN ('Port','Railyard')
		AND V.PickupLocationID = @LocationID
		AND ISNULL(V.ReleaseCode,'') NOT IN ('D1','E','I','J')	--07/24/2017 - CMK
		GROUP BY C.CustomerName,C.ShortName
		ORDER BY Customer
	END
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating PipeLine record'
		GOTO Error_Encountered
	END

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
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
	--SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	IF (@locationID =0)
	BEGIN
		SELECT Customer,Location,PipeLineCount FROM #TerminalPipeLine1
	END
	ELSE
	BEGIN
		SELECT Customer,PipeLineCount FROM #TerminalPipeLine
	END

	RETURN
END
GO
