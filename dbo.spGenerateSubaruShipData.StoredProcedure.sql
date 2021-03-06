USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateSubaruShipData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateSubaruShipData] (@LocationID int, @Origin varchar(6),@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--SubaruShipExport table variables
	@SubaruShipExportID		int,
	@RecordType			varchar(5),
	@LocationCode			varchar(6),
	@VehicleID			int,
	@CarrierCode			varchar(6),
	@Destination			varchar(6),
	@ReleaseDate			datetime,
	@ShipDate			datetime,
	@RailcarNumber			varchar(10),
	@InterchangeControlNumber	int,
	@SequenceNumber			int,
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
	*	spGenerateSubaruShipData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the vehicle ship export data for	*
	*	SOA vehicles that have been picked up.				*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	04/22/2005 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SOACustomerID'
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

	--get the next batch id from the setting table
	SELECT @InterchangeControlNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextSubaruInterchangeControlNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Interchange Control Number'
		GOTO Error_Encountered2
	END
	IF @InterchangeControlNumber IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Interchange Control Number Not Found'
		GOTO Error_Encountered2
	END

	SELECT @SequenceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextSubaruShipSequenceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Sequence Number'
		GOTO Error_Encountered2
	END
	IF @SequenceNumber IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Sequence Number Not Found'
		GOTO Error_Encountered2
	END

	DECLARE SubaruShipCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L2.CustomerLocationCode,
		V.AvailableForPickupDate, L.PickupDate, V.RailCarNumber
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.PickupLocationID = @LocationID
		LEFT JOIN Location L2 ON L.DropoffLocationID = L2.LocationID
		AND L.PickupLocationID = @LocationID
		WHERE V.PickupLocationID = @LocationID
		AND V.CustomerID = @CustomerID
		AND V.VehicleStatus IN ('Delivered', 'EnRoute')
		AND V.VehicleID NOT IN (SELECT VehicleID FROM SubaruShipExport)
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN SubaruShipCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @InterchangeControlNumber+1	
	WHERE ValueKey = 'NextSubaruInterchangeControlNumber'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting Interchange Control Number'
			GOTO Error_Encountered
	END

	UPDATE SettingTable
	SET ValueDescription = @SequenceNumber+1	
	WHERE ValueKey = 'NextSubaruShipSequenceNumber'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting Sequence Number'
			GOTO Error_Encountered
	END

	--set the default values
	SELECT @RecordType = 'CRSHP'
	SELECT @CarrierCode = '405000'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH SubaruShipCursor INTO @VehicleID, @Destination,
		@ReleaseDate, @ShipDate, @RailcarNumber
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @LocationCode = @Destination
	
		INSERT INTO SubaruShipExport(
			RecordType,
			LocationCode,
			VehicleID,
			Origin,
			CarrierCode,
			Destination,
			ReleaseDate,
			ShipDate,
			RailcarNumber,
			InterchangeControlNumber,
			SequenceNumber,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@RecordType,
			@LocationCode,
			@VehicleID,
			@Origin,
			@CarrierCode,
			@Destination,
			@ReleaseDate,
			@ShipDate,
			@RailcarNumber,
			@InterchangeControlNumber,
			@SequenceNumber,
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
			SELECT @Status = 'Error creating SubaruShipExport record'
			GOTO Error_Encountered
		END
			
		FETCH SubaruShipCursor INTO @VehicleID, @Destination,
			@ReleaseDate, @ShipDate, @RailcarNumber

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE SubaruShipCursor
		DEALLOCATE SubaruShipCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE SubaruShipCursor
		DEALLOCATE SubaruShipCursor
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
	
	RETURN
END
GO
