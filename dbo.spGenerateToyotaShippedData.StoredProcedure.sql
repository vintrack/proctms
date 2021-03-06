USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateToyotaShippedData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateToyotaShippedData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ToyotaExportShipped table variables
	@BatchID			int,
	@VehicleID			int,
	@CarrierCode			varchar(2),
	@GroupNumber			varchar(6),
	@ShipmentID			varchar(10),
	@ShipDate			datetime,
	@ShipToDealerCode		varchar(5),
	@OriginCode			varchar(2),
	@DestinationCode		varchar(2),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(20),
	@CreationDate			datetime,
	--processing variables
	@CustomerID			int,
	@DamageCode			varchar(5),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateToyotaShippedData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generate the shipped vehicle data for Toyotas	*
	*	that have been picked up.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/15/2008 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ToyotaCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CustomerID'
		GOTO Error_Encountered2
	END
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered2
	END

	--get the carrier code
	SELECT @CarrierCode = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'ToyotaCarrierCode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	
	--get the next batch id from the setting table
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextToyotaShippedExportBatchID'
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

	DECLARE ToyotaShippedCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID,
		CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,1,CHARINDEX('/',V.CustomerIdentification)-1) WHEN DATALENGTH(V.CustomerIdentification) < 7 THEN V.CustomerIdentification ELSE '' END,
		CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)+1,DATALENGTH(V.CustomerIdentification)-CHARINDEX('/',V.CustomerIdentification)) WHEN DATALENGTH(V.CustomerIdentification) > 6 THEN V.CustomerIdentification ELSE '' END,
		L.PickupDate, L2.CustomerLocationCode,
		(SELECT C.Value2 FROM Code C WHERE C.CodeType = 'ToyotaLocationCode' AND CONVERT(int,C.Value1) = V.PickupLocationID),
		'DL'
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.LegNumber = 1
		LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
		WHERE V.CustomerID = @CustomerID
		AND V.VehicleStatus IN ('Delivered', 'EnRoute')
		AND ISNULL(V.CustomerIdentification,'') <> ''
		AND V.CustomerIdentification NOT LIKE 'Dev%'
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND V.VehicleID NOT IN (SELECT VehicleID FROM ToyotaExportShipped)
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ToyotaShippedCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextToyotaShippedExportBatchID'
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
	
	FETCH ToyotaShippedCursor INTO @VehicleID, @GroupNumber, @ShipmentID, @ShipDate, @ShipToDealerCode, @OriginCode, @DestinationCode
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO ToyotaExportShipped(
			BatchID,
			VehicleID,
			CarrierCode,
			FileCode,
			RecordType,
			ShipDate,
			ShipToDealer,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy,
			GroupNumber,
			ShipmentID,
			OriginCode,
			DestinationCode
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@CarrierCode,
			'2',
			'1',
			@ShipDate,
			@ShipToDealerCode,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
			@RecordStatus,
			@CreationDate,
			@CreatedBy,
			@GroupNumber,
			@ShipmentID,
			@OriginCode,
			@DestinationCode
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating ToyotaExportShipped record'
			GOTO Error_Encountered
		END
			
		FETCH ToyotaShippedCursor INTO @VehicleID, @GroupNumber, @ShipmentID, @ShipDate, @ShipToDealerCode, @OriginCode, @DestinationCode

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ToyotaShippedCursor
		DEALLOCATE ToyotaShippedCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ToyotaShippedCursor
		DEALLOCATE ToyotaShippedCursor
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @BatchID AS BatchID
	
	RETURN
END
GO
