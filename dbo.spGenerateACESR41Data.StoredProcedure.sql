USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateACESR41Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateACESR41Data] (@CustomerID int, @ACESCustomerCode varchar(5),@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportACESR41 table variables
	@BatchID			int,
	@VehicleID			int,
	@BillOfLadingNumber		varchar(15),
	@StatusDate			datetime,
	@StatusCode			varchar(3),
	@SPLCCode			varchar(10),
	@AARRampCode			varchar(7),
	@DestinationCode		varchar(7),
	@TruckType			varchar(1),
	@DamageIndicator		varchar(1),
	@ShipmentAuthorizationCode	varchar(12),
	@SPLCTransmissionFlag		varchar(1),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(20),
	@CreationDate			datetime,
	--processing variables
	@LocationSubType		varchar(20),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@ReturnBatchID			int

	/************************************************************************
	*	spGenerateACESR41Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the ACES R41 export data for vehicles	*
	*	(for the specified ACES customer) that have been picked up or	*
	*	delivered.							*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	02/02/2009 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextACES'+@ACESCustomerCode+'R41BatchID'
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

	--cursor for the pickup records
	DECLARE ACESR41Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L2.LoadNumber, L.PickupDate, LEFT(L4.Zip,5),
		CASE WHEN DATALENGTH(C2.Code) > 0 THEN C2.Code WHEN DATALENGTH(L4.CustomerLocationCode) > 0 THEN L4.CustomerLocationCode ELSE LEFT(L4.Zip,5) END TheOrigin,
		ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5)) TheDestination, CASE WHEN VI.DamageCodeCount > 0 THEN 'Y' ELSE 'N' END,
		V.CustomerIdentification, L4.LocationSubType
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.PickupLocationID = V.PickupLocationID
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
		LEFT JOIN Code C2 ON V.PickupLocationID = CONVERT(int,C2.Value1)
		AND C2.CodeType = 'ACES'+@ACESCustomerCode+'LocationCode'
		LEFT JOIN VehicleInspection VI ON L.VehicleID = VI.VehicleID
		AND VI.InspectionType = 2
		WHERE V.CustomerID = @CustomerID
		AND L.PickupDate >= '07/01/2009' -- ACES Start Date is 07/07/2009 just want to catch overlap
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND V.VehicleStatus IN ('EnRoute','Delivered')
		AND V.CustomerIdentification IS NOT NULL
		AND V.CustomerIdentification <> ''
		AND V.VehicleID NOT IN (SELECT VehicleID FROM ACESExportR41 WHERE StatusCode IN ('P01', 'P08'))
		--AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportICLR41 WHERE ICLStatusCode IN ('P01', 'P08'))
		ORDER BY TheOrigin, TheDestination

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ACESR41Cursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextACES'+@ACESCustomerCode+'R41BatchID'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting BatchID'
			GOTO Error_Encountered
	END

	--set the default values
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	--SELECT @ICLStatusCode = 'P08'
	SELECT @TruckType = 'O'
	SELECT @SPLCTransmissionFlag = 'F'
	
	FETCH ACESR41Cursor INTO @VehicleID, @BillOfLadingNumber, @StatusDate, @SPLCCode,
	@AARRampCode, @DestinationCode, @DamageIndicator, @ShipmentAuthorizationCode, @LocationSubType
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		/*
		IF @LocationSubType = 'Railyard'
		BEGIN
			SELECT @StatusCode = 'P08'
		END
		ELSE
		BEGIN
			SELECT @StatusCode = 'P01'
		END
		*/
		SELECT @StatusCode = 'P01'
		
		INSERT INTO ACESExportR41(
			BatchID,
			CustomerID,
			ACESCustomerCode,
			VehicleID,
			BillOfLadingNumber,
			StatusDate,
			StatusCode,
			SPLCCode,
			AARRampCode,
			DestinationCode,
			TruckType,
			DamageIndicator,
			ShipmentAuthorizationCode,
			SPLCTransmissionFlag,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@CustomerID,
			@ACESCustomerCode,
			@VehicleID,
			@BillOfLadingNumber,
			@StatusDate,
			@StatusCode,
			@SPLCCode,
			@AARRampCode,
			@DestinationCode,
			@TruckType,
			@DamageIndicator,
			@ShipmentAuthorizationCode,
			@SPLCTransmissionFlag,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
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
			
		FETCH ACESR41Cursor INTO @VehicleID, @BillOfLadingNumber, @StatusDate, @SPLCCode,
		@AARRampCode, @DestinationCode, @DamageIndicator, @ShipmentAuthorizationCode, @LocationSubType

	END --end of loop
	
	CLOSE ACESR41Cursor
	DEALLOCATE ACESR41Cursor
		
	--cursor for the delivery records
	DECLARE ACESR41Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		
		SELECT V.VehicleID, L2.LoadNumber, L.DropoffDate, LEFT(L3.Zip,5),
		CASE WHEN DATALENGTH(C2.Code) > 0 THEN C2.Code WHEN DATALENGTH(L4.CustomerLocationCode) > 0 THEN L4.CustomerLocationCode ELSE LEFT(L4.Zip,5) END TheOrigin,
		ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5)) TheDestination, CASE WHEN VI.DamageCodeCount > 0 THEN 'Y' ELSE 'N' END,
		V.CustomerIdentification
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.FinalLegInd = 1
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
		LEFT JOIN Code C2 ON V.PickupLocationID = CONVERT(int,C2.Value1)
		AND C2.CodeType = 'ACES'+@ACESCustomerCode+'LocationCode'
		LEFT JOIN VehicleInspection VI ON L.VehicleID = VI.VehicleID
		AND VI.InspectionType = 3
		WHERE V.CustomerID = @CustomerID
		AND V.VehicleStatus = 'Delivered'
		AND L.DropoffDate >= '07/01/2009' -- ACES Start Date is 07/07/2009 just want to catch overlap
		AND L.DropoffDate > L.PickupDate
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND V.CustomerIdentification IS NOT NULL
		AND V.CustomerIdentification <> ''
		AND V.VehicleID NOT IN (SELECT VehicleID FROM ACESExportR41 WHERE StatusCode = 'D09')
		--AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportICLR41 WHERE ICLStatusCode = 'D09')
		ORDER BY TheOrigin, TheDestination

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ACESR41Cursor

	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @StatusCode = 'D09'
	SELECT @TruckType = 'O'
	SELECT @SPLCTransmissionFlag = 'F'
	
	FETCH ACESR41Cursor INTO @VehicleID, @BillOfLadingNumber, @StatusDate, @SPLCCode,
	@AARRampCode, @DestinationCode, @DamageIndicator, @ShipmentAuthorizationCode
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO ACESExportR41(
			BatchID,
			CustomerID,
			ACESCustomerCode,
			VehicleID,
			BillOfLadingNumber,
			StatusDate,
			StatusCode,
			SPLCCode,
			AARRampCode,
			DestinationCode,
			TruckType,
			DamageIndicator,
			ShipmentAuthorizationCode,
			SPLCTransmissionFlag,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@CustomerID,
			@ACESCustomerCode,
			@VehicleID,
			@BillOfLadingNumber,
			@StatusDate,
			@StatusCode,
			@SPLCCode,
			@AARRampCode,
			@DestinationCode,
			@TruckType,
			@DamageIndicator,
			@ShipmentAuthorizationCode,
			@SPLCTransmissionFlag,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
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
			
		FETCH ACESR41Cursor INTO @VehicleID, @BillOfLadingNumber, @StatusDate, @SPLCCode,
		@AARRampCode, @DestinationCode, @DamageIndicator, @ShipmentAuthorizationCode

	END --end of loop


	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ACESR41Cursor
		DEALLOCATE ACESR41Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ACESR41Cursor
		DEALLOCATE ACESR41Cursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		SELECT @ReturnBatchID = NULL
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			SELECT @ReturnCode = 0
			SELECT @ReturnMessage = 'Processing Completed Successfully'
			SELECT @ReturnBatchID = @BatchID
			GOTO Do_Return
		END
		ELSE
		BEGIN
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
