USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateGlovisMovesData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateGlovisMovesData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportICLR41 table variables
	@BatchID			int,
	@VehicleID			int,
	@RecordType			varchar(2),
	@TransmissionDateTime		datetime,
	@SCACCode			varchar(4),
	@SequenceNumber			int,
	@VIN				varchar(17),
	@RouteCode			varchar(9),
	@DealerCode			varchar(5),
	@PickupDateTime			datetime,
	@RailcarNumber			varchar(10),
	@TruckNumber			varchar(10),
	@DeliveryDateTime		datetime,
	@ShipmentAuthorizationCode	varchar(16),
	@Origin				varchar(5),
	@Destination			varchar(5),
	@WaybillNumber			varchar(6),
	@WaybillDate			datetime,
	@RailcarType			varchar(2),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@LocationSubType		varchar(20),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateGlovisMovesData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generate the Glovis Moves export data for	*
	*	vehicles that have been picked up or delivered.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/21/2006 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextGlovisMoveExportBatchID'
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
	DECLARE GlovisMoveCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, V.VIN, L.PickupDate, T.TruckNumber,
		V.CustomerIdentification, 
		ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ACES'+LEFT(V.Make,1)+'MA' +'LocationCode'
		AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5)),
		ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5))
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.PickupLocationID = V.PickupLocationID
		LEFT JOIN Run R ON L.RunID = R.RunID
		LEFT JOIN Truck T ON R.TruckID = T.TruckID
		LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
		WHERE V.CustomerID IN ((SELECT CONVERT(int,Value1) FROM Code WHERE CodeType = 'ACESCustomerCode'))
		AND V.VehicleStatus IN ('EnRoute','Delivered')
		AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportGlovisMoves WHERE RecordType = 'PU')
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN GlovisMoveCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextGlovisMoveExportBatchID'
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
	SELECT @RecordType = 'PU'
	SELECT @SCACCode = 'GDIV'
	
	FETCH GlovisMoveCursor INTO @VehicleID, @VIN, @PickupDateTime, @TruckNumber, 
	@ShipmentAuthorizationCode, @Origin, @Destination
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO ExportGlovisMoves(
			BatchID,
			VehicleID,
			RecordType,
			TransmissionDateTime,
			SCACCode,
			SequenceNumber,
			VIN,
			RouteCode,
			DealerCode,
			PickupDateTime,
			RailcarNumber,
			TruckNumber,
			DeliveryDateTime,
			ShipmentAuthorizationCode,
			Origin,
			Destination,
			WaybillNumber,
			WaybillDate,
			RailcarType,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@RecordType,
			@TransmissionDateTime,
			@SCACCode,
			@SequenceNumber,
			@VIN,
			@RouteCode,
			@DealerCode,
			@PickupDateTime,
			@RailcarNumber,
			@TruckNumber,
			@DeliveryDateTime,
			@ShipmentAuthorizationCode,
			@Origin,
			@Destination,
			@WaybillNumber,
			@WaybillDate,
			@RailcarType,
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
			
		FETCH GlovisMoveCursor INTO @VehicleID, @VIN, @PickupDateTime, @TruckNumber, 
		@ShipmentAuthorizationCode, @Origin, @Destination

	END --end of loop
	
	CLOSE GlovisMoveCursor
	DEALLOCATE GlovisMoveCursor
		
	--cursor for the delivery records
	DECLARE GlovisMoveCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		
		SELECT V.VehicleID, V.VIN, L.PickupDate, L.DropoffDate, T.TruckNumber,
		V.CustomerIdentification, 
		ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ACES'+LEFT(V.Make,1)+'MA' +'LocationCode'
		AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5)),
		ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5))
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.PickupLocationID = V.PickupLocationID
		LEFT JOIN Run R ON L.RunID = R.RunID
		LEFT JOIN Truck T ON R.TruckID = T.TruckID
		LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
		WHERE V.CustomerID IN ((SELECT CONVERT(int,Value1) FROM Code WHERE CodeType = 'ACESCustomerCode'))
		AND V.VehicleStatus ='Delivered'
		AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportGlovisMoves WHERE RecordType = 'DE')
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN GlovisMoveCursor

	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @RecordType = 'DE'
	SELECT @SCACCode = 'GDIV'
	
	FETCH GlovisMoveCursor INTO @VehicleID, @VIN, @PickupDateTime, @DeliveryDateTime, @TruckNumber, 
	@ShipmentAuthorizationCode, @Origin, @Destination
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @DealerCode = @Destination
		
		INSERT INTO ExportGlovisMoves(
			BatchID,
			VehicleID,
			RecordType,
			TransmissionDateTime,
			SCACCode,
			SequenceNumber,
			VIN,
			RouteCode,
			DealerCode,
			PickupDateTime,
			RailcarNumber,
			TruckNumber,
			DeliveryDateTime,
			ShipmentAuthorizationCode,
			Origin,
			Destination,
			WaybillNumber,
			WaybillDate,
			RailcarType,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@RecordType,
			@TransmissionDateTime,
			@SCACCode,
			@SequenceNumber,
			@VIN,
			@RouteCode,
			@DealerCode,
			@PickupDateTime,
			@RailcarNumber,
			@TruckNumber,
			@DeliveryDateTime,
			@ShipmentAuthorizationCode,
			@Origin,
			@Destination,
			@WaybillNumber,
			@WaybillDate,
			@RailcarType,
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
			
		FETCH GlovisMoveCursor INTO @VehicleID, @VIN, @PickupDateTime, @DeliveryDateTime, @TruckNumber, 
		@ShipmentAuthorizationCode, @Origin, @Destination

	END --end of loop


	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE GlovisMoveCursor
		DEALLOCATE GlovisMoveCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE GlovisMoveCursor
		DEALLOCATE GlovisMoveCursor
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
