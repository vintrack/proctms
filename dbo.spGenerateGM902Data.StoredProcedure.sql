USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateGM902Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateGM902Data] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--GMExport902 table variables
	@BatchID			int,
	@VehicleID			int,
	@ActionCode			varchar(1),
	@CDLCode			varchar(2),
	@DispatchingSCAC		varchar(4),
	@LoadNumber			varchar(9),
	@TractorIdentifier		varchar(10),
	@TrailerIdentifier		varchar(10),
	@DispatchDateTime		datetime,
	@TotalVehicles			int,
	@TotalGMAssignedVehicles	int,
	@SCACCode			varchar(4),
	@PayDeliveringCarrierIndicator	varchar(1),
	@VIN				varchar(17),
	@DestinationCDL			varchar(2),
	@SellingDivision		varchar(2),
	@DealerCode			varchar(5),
	@CarrierConvenienceDestination	varchar(7),
	@FreightBillNumber		varchar(10),
	@CarrierRouteOverrideIndicator	varchar(1),
	@ExportedInd			int,
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@GMCustomerID			int,
	@LoadNumberCounter		int,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@ReturnBatchID			int

	/************************************************************************
	*	spGenerateGM902Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the GM 902 (Truck Dispatcth) export	*
	*	GM vehicles that have been put in a load and assigned to a 	*
	*	driver.								*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	10/24/2013 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextGM902ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'BatchID Not Found'
		GOTO Error_Encountered2
	END
	--print 'batchid = '+convert(varchar(20),@batchid)
	
	--get the GM Customer ID
	SELECT @GMCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'GMCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting GMCustomerID'
		GOTO Error_Encountered2
	END
	IF @GMCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'GMCustomerID Not Found'
		GOTO Error_Encountered2
	END
	--print 'gm customerid = '+convert(varchar(20),@gmcustomerid)
	
	BEGIN TRAN
	
	--set the default values
	SELECT @ActionCode = 'A'
	SELECT @DispatchingSCAC = 'DVAI'
	SELECT @SCACCode = 'DVAI'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	DECLARE GM902Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT DISTINCT V.VehicleID, C.Code CDLCode, L2.LoadNumber, ISNULL(T.TruckNumber,'NA'), ISNULL(T2.TrailerNumber,'NA'),
		(SELECT TOP 1 L5.PickupDate FROM Legs L5 WHERE L5.LoadID = L2.LoadsID AND L5.PickupLocationID = V.PickupLocationID AND L5.PickupDate IS NOT NULL ORDER BY L5.PickupDate),
		--PER BILL WHITE, SENDING UNITS AS 1 CAR LOADS TO GM
		1, --(SELECT COUNT(*) FROM Legs L6 WHERE L6.LoadID = L2.LoadsID),
		1, --(SELECT COUNT(*) FROM Legs L7 LEFT JOIN Vehicle V2 ON L7.VehicleID = V2.VehicleID WHERE L7.LoadID = L2.LoadsID AND V2.CustomerID = V.CustomerID),
		'' PayDeliveringCarrierIndicator, V.VIN, C2.Code DestinationCDL,
		CASE WHEN DATALENGTH(L4.CustomerLocationCode) > 0 THEN LEFT(V.CustomerIdentification,2) ELSE '' END,
		CASE WHEN DATALENGTH(L4.CustomerLocationCode) > 0 THEN CASE WHEN CHARINDEX('-',L4.CustomerLocationCode) > 0 THEN SUBSTRING(L4.CustomerLocationCode,CHARINDEX('-',L4.CustomerLocationCode)+1,DATALENGTH(L4.CustomerLocationCode) - CHARINDEX('-',L4.CustomerLocationCode)) ELSE L4.CustomerLocationCode END ELSE '' END,
		'' CarrierConvenienceDestination,
		'' FreightBillNumber,
		CASE WHEN ISNULL(V.SpotBuyUnitInd,0) = 1 THEN 'Y' ELSE '' END CarrierRouteOverrideIndicator
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.LegNumber = 1
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
		LEFT JOIN Code C ON V.PickupLocationID = CONVERT(int,C.Value1)
		AND C.CodeType = 'GMLocationCode'
		LEFT JOIN Code C2 ON V.DropoffLocationID = CONVERT(int,C2.Value1)
		AND C2.CodeType = 'GMLocationCode'
		LEFT JOIN Driver D ON L2.DriverID = D.DriverID
		LEFT JOIN Truck T ON D.CurrentTruckID = T.TruckID
		LEFT JOIN Trailer T2 ON T.CurrentTrailerID = T2.TrailerID
		WHERE V.CustomerID = @GMCustomerID
		AND V.PickupLocationID IN (SELECT CONVERT(int,C2.Value1) FROM Code C2 WHERE C2.CodeType = 'GMLocationCode')
		AND V.VehicleID NOT IN (SELECT E.VehicleID FROM GMExport902 E WHERE E.VehicleID = V.VehicleID)
		AND L.PickupDate >= L.DateAvailable
		AND CHARINDEX('/',V.CustomerIdentification) = 3	--want to make sure that the selling division is set up correctly
		ORDER BY L2.LoadNumber, V.VIN
	
	--print 'cursor declared'
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN GM902Cursor
	--print 'cursor opened'
	
		
	FETCH GM902Cursor INTO @VehicleID, @CDLCode, @LoadNumber, @TractorIdentifier, @TrailerIdentifier,
		@DispatchDateTime, @TotalVehicles, @TotalGMAssignedVehicles, @PayDeliveringCarrierIndicator,
		@VIN, @DestinationCDL, @SellingDivision, @DealerCode, @CarrierConvenienceDestination,
		@FreightBillNumber,@CarrierRouteOverrideIndicator
			
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @LoadNumberCounter = NULL
		SELECT TOP 1 @LoadNumberCounter = CONVERT(int,RIGHT(LoadNumber,2))
		FROM GMExport902
		WHERE LEFT(LoadNumber,7) = RIGHT(@LoadNumber,7)
		ORDER BY LoadNumber DESC
		
		IF @LoadNumberCounter IS NULL
		BEGIN
			SELECT @LoadNumberCounter = 1
		END
		ELSE
		BEGIN
			SELECT @LoadNumberCounter = @LoadNumberCounter + 1
		END

		SELECT @LoadNumber = RIGHT(@LoadNumber,7)+REPLICATE('0',2-DATALENGTH(CONVERT(varchar(10),@LoadNumberCounter)))+CONVERT(varchar(10),@LoadNumberCounter)--print 'in loop'
		
		INSERT INTO GMExport902(
			BatchID,
			VehicleID,
			ActionCode,
			CDLCode,
			DispatchingSCAC,
			LoadNumber,
			TractorIdentifier,
			TrailerIdentifier,
			DispatchDateTime,
			TotalVehicles,
			TotalGMAssignedVehicles,
			SCACCode,
			PayDeliveringCarrierIndicator,
			VIN,
			DestinationCDL,
			SellingDivision,
			DealerCode,
			CarrierConvenienceDestination,
			FreightBillNumber,
			CarrierRouteOverrideIndicator,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@ActionCode,
			@CDLCode,
			@DispatchingSCAC,
			@LoadNumber,
			@TractorIdentifier,
			@TrailerIdentifier,
			@DispatchDateTime,
			@TotalVehicles,
			@TotalGMAssignedVehicles,
			@SCACCode,
			@PayDeliveringCarrierIndicator,
			@VIN,
			@DestinationCDL,
			@SellingDivision,
			@DealerCode,
			@CarrierConvenienceDestination,
			@FreightBillNumber,
			@CarrierRouteOverrideIndicator,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating R41 record'
			GOTO Error_Encountered
		END
					
		FETCH GM902Cursor INTO @VehicleID, @CDLCode, @LoadNumber, @TractorIdentifier, @TrailerIdentifier,
			@DispatchDateTime, @TotalVehicles, @TotalGMAssignedVehicles, @PayDeliveringCarrierIndicator,
			@VIN, @DestinationCDL, @SellingDivision, @DealerCode, @CarrierConvenienceDestination,
			@FreightBillNumber,@CarrierRouteOverrideIndicator
		
	END --end of loop
			
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextGM902ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting BatchID'
			GOTO Error_Encountered
	END
	--print 'batchid set'
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		--print 'error encountered = 0'
		COMMIT TRAN
		CLOSE GM902Cursor
		DEALLOCATE GM902Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return
	END
	ELSE
	BEGIN
		--print 'error encountered = '+convert(varchar(20),@Errorid)
		ROLLBACK TRAN
		CLOSE GM902Cursor
		DEALLOCATE GM902Cursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		SELECT @ReturnBatchID = NULL
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		--print 'error encountered2 = 0'
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return
	END
	ELSE
	BEGIN
		--print 'error encountered2 = '+convert(varchar(20),@Errorid)
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		SELECT @ReturnBatchID = NULL
		GOTO Do_Return
	END
	
	Do_Return:
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @ReturnBatchID AS ReturnBatchID
	
	RETURN
END
GO
