USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateINLHAIDVData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateINLHAIDVData] ( --@CustomerID int, @INLCustomerCode varchar(2),
	@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportINLHAIDV table variables
	@BatchID			int,
	@CustomerID			int,
	@VehicleID			int,
	@TransactionType		varchar(10),
	@SenderCode			varchar(15),
	@ReceiverCode			varchar(15),
	@TransmissionDateTime		datetime,
	@InterchangeControlNumber	int,
	@RecordType			varchar(3),
	@VIN				varchar(17),
	@DeliveringCarrierSCAC		varchar(4),
	@PickupLocationCode		varchar(2),
	@Blank1				varchar(7),
	@PickupDateTime			datetime,
	@ShipToDealerCode		varchar(5),
	@Blank2				varchar(4),
	@DeliveryDateTime		datetime,
	@TruckLoadNumber		varchar(12),
	@TractorID			varchar(10),
	@TrailerID			varchar(10),
	@Blank3				varchar(11),
	@ShipperCode			varchar(1),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(20),
	@CreationDate			datetime,
	--processing variables
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@ReturnBatchID			int

	/************************************************************************
	*	spGenerateINLHAIDVData						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the INL HAIDV export data for vehicles	*
	*	(for the specified INL customer) that have been picked up or	*
	*	delivered.							*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	02/28/2007 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--REMOVE THIS NEXT BLOCK IF MULTIPLE CUSTOMERS FOR INL AND USE PARAMETER
	--get the customer id from the setting table
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ChryslerCustomerID'
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
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	--WHERE ValueKey = 'NextINL'+@INLCustomerCode+'HAIDVBatchID'
	WHERE ValueKey = 'NextINLHAIDVBatchID'
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
	DECLARE INLHAIDVCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, V.VIN, 
		--(SELECT C.Code FROM Code C WHERE C.CodeType = 'INL'+@INLCustomerCode+'LocationCode'
		(SELECT C.Code FROM Code C WHERE C.CodeType = 'INLLocationCode'
		AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),
		L1.PickupDate, L5.CustomerLocationCode, L2.DropoffDate
		FROM Vehicle V
		LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
		AND L1.LegNumber = 1
		LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
		AND L2.FinalLegInd = 1
		LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
		LEFT JOIN Location L5 ON V.DropoffLocationID = L5.LocationID
		WHERE V.CustomerID = @CustomerID
		AND L1.PickupDate >= CONVERT(varchar(10),L1.DateAvailable,101)
		AND L2.DropoffDate >= L1.PickupDate
		AND V.VehicleStatus = 'Delivered'
		AND V.VehicleID NOT IN (SELECT EIH.VehicleID FROM ExportINLHAIDV EIH WHERE EIH.VehicleID = V.VehicleID)
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN INLHAIDVCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	--WHERE ValueKey = 'NextINL'+@INLCustomerCode+'HAIDVBatchID'
	WHERE ValueKey = 'NextINLHAIDVBatchID'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting BatchID'
			GOTO Error_Encountered
	END

	--set the default values
	SELECT @TransactionType = 'HAIDV'
	SELECT @SenderCode ='DVAI'
	SELECT @ReceiverCode ='ADIMS'
	SELECT @TransmissionDateTime = NULL	--populated when exported
	SELECT @InterchangeControlNumber = NULL	--populated when exported
	SELECT @RecordType = 'IDV'
	SELECT @TruckLoadNumber = ''
	SELECT @DeliveringCarrierSCAC = 'DVAI'
	SELECT @Blank1 = ''
	SELECT @Blank2 = ''
	SELECT @TractorID = ''
	SELECT @TrailerID = ''
	SELECT @Blank3 = ''
	SELECT @ShipperCode = 'C'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
		
	FETCH INLHAIDVCursor INTO @VehicleID, @VIN, @PickupLocationCode, @PickupDateTime,
		@ShipToDealerCode, @DeliveryDateTime
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @ShipToDealerCode IS NULL OR @ShipToDealerCode = ''
		BEGIN
			GOTO End_Of_Loop
		END
		
		INSERT INTO ExportINLHAIDV(
			BatchID,
			CustomerID,
			VehicleID,
			TransactionType,
			SenderCode,
			ReceiverCode,
			TransmissionDateTime,
			InterchangeControlNumber,
			RecordType,
			VIN,
			DeliveringCarrierSCAC,
			PickupLocationCode,
			Blank1,
			PickupDateTime,
			ShipToDealerCode,
			Blank2,
			DeliveryDateTime,
			TruckLoadNumber,
			TractorID,
			TrailerID,
			Blank3,
			ShipperCode,
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
			@VehicleID,
			@TransactionType,
			@SenderCode,
			@ReceiverCode,
			@TransmissionDateTime,
			@InterchangeControlNumber,
			@RecordType,
			@VIN,
			@DeliveringCarrierSCAC,
			@PickupLocationCode,
			@Blank1,
			@PickupDateTime,
			@ShipToDealerCode,
			@Blank2,
			@DeliveryDateTime,
			@TruckLoadNumber,
			@TractorID,
			@TrailerID,
			@Blank3,
			@ShipperCode,
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
			
		End_Of_Loop:
		FETCH INLHAIDVCursor INTO @VehicleID, @VIN, @PickupLocationCode, @PickupDateTime,
			@ShipToDealerCode, @DeliveryDateTime

	END --end of loop
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE INLHAIDVCursor
		DEALLOCATE INLHAIDVCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE INLHAIDVCursor
		DEALLOCATE INLHAIDVCursor
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
