USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateFordDeliveryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateFordDeliveryData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID				int,
	--FordExportDelivery table variables
	@BatchID				int,
	@VehicleID				int,
	@InterchangeSenderID			varchar(15),
	@InterchangeReceiverID			varchar(15),
	@FunctionalID				varchar(2),
	@SenderCode				varchar(12),
	@ReceiverCode				varchar(12),
	@TransmissionDateTime			datetime,
	@InterchangeControlNumber		int,
	@ResponsibleAgencyCode			varchar(2),
	@VersionNumber				varchar(12),
	@SCACCode				varchar(4),
	@RecordType				varchar(2),
	@RampCode				varchar(2),
	@ActionDate				datetime,
	@DeliveryStatus				varchar(1),
	@OriginType				varchar(1),
	@Origin					varchar(6),
	@Destination				varchar(6),
	@DestinationType			varchar(1),
	@LoadTypeCharged			varchar(1),
	@LoadRatio				varchar(2),
	@ExceptionCode				varchar(2),
	@ExceptionAuthorization			varchar(7),
	@ChargeToCode				varchar(12),
	@TransactionSetControlNumber		varchar(9),
	@SequenceNumber				varchar(1),
	@ExportedInd				int,
	@ExportedDate				datetime,
	@ExportedBy				varchar(20),
	@RecordStatus				varchar(100),
	@CreationDate				datetime,
	@UpdatedDate				datetime,
	@UpdatedBy				varchar(20),
	--processing variables
	@CustomerID				int,
	@LegsID					int,
	@CustomerIdentification			varchar(25),
	@LoopCounter				int,
	@Status					varchar(100),
	@ReturnCode				int,
	@ReturnMessage				varchar(100)	

	/************************************************************************
	*	spGenerateFordDeliveryData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the delivery export data for Fords	*
	*	that have been delivered.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	06/24/2010 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'FordCustomerID'
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
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextFordDeliveryExportBatchID'
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
	
	/*
	--get the next batch id from the setting table
	SELECT TOP 1 @RampCode = Code
	FROM Code
	WHERE CodeType = 'FordLocationCode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting RampCode'
		GOTO Error_Encountered2
	END
	IF @RampCode IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Error Getting RampCode'
		GOTO Error_Encountered2
	END
	*/
	
	SELECT @ErrorID = 0
	
	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextFordDeliveryExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--set the default values
	SELECT @LoopCounter = 0
	SELECT @InterchangeSenderID = 'GCXXA'
	SELECT @InterchangeReceiverID = 'F159B'
	SELECT @FunctionalID = 'FT'
	SELECT @SenderCode = 'GCXXA'
	SELECT @ReceiverCode = 'F159B'
	SELECT @TransmissionDateTime = NULL --value set during export
	SELECT @InterchangeControlNumber = NULL --value set during export
	SELECT @ResponsibleAgencyCode = 'X'
	SELECT @VersionNumber = '003030'
	SELECT @TransactionSetControlNumber = NULL --value set during export
	SELECT @SCACCode = 'DVAI'
	SELECT @SequenceNumber = ''
	SELECT @ExportedInd = 0
	SELECT @ExportedDate = NULL
	SELECT @ExportedBy = NULL
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @UpdatedDate = NULL
	SELECT @UpdatedBy = NULL
	
	INSERT INTO FordExportDelivery SELECT @BatchID, V.VehicleID, @InterchangeSenderID,
	@InterchangeReceiverID, @FunctionalID, @SenderCode, @ReceiverCode, @TransmissionDateTime,
	@InterchangeControlNumber, @ResponsibleAgencyCode, @VersionNumber, @TransactionSetControlNumber,
	@SCACCode,
	CASE WHEN DATALENGTH(V.CustomerIdentification) > 0 THEN '3B' ELSE '3A' END, --@RampCode,
	--start new ramp code code
	CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT Code FROM Code WHERE CodeType = 'FordLocationCode'
	AND Value1 = CONVERT(varchar(10),L3.LocationID)) ELSE '' END,
	--end new ramp code code
	CONVERT(varchar(10),L.DropoffDate,101), 'F', -- F = Final Delivery
	CASE WHEN L3.ParentRecordTable = 'Common' THEN '' WHEN DATALENGTH(L3.CustomerLocationCode) > 0 THEN 'D'
		WHEN DATALENGTH(L3.SPLCCode) > 0 THEN 'Y' END, --Origin Type
	CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT Code FROM Code WHERE CodeType = 'FordLocationCode'
	AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(L3.CustomerLocationCode) > 0 THEN L3.CustomerLocationCode
		WHEN DATALENGTH(L3.SPLCCode) > 0 THEN L3.SPLCCode END, -- Origin Code
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT Code FROM Code WHERE CodeType = 'FordLocationCode'
	AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(L4.CustomerLocationCode) > 0 THEN L4.CustomerLocationCode
		WHEN DATALENGTH(L4.SPLCCode) > 0 THEN L4.SPLCCode END, -- Destination Code
	CASE WHEN L4.ParentRecordTable = 'Common' THEN 'R' WHEN DATALENGTH(L4.CustomerLocationCode) > 0 THEN 'D'
		WHEN DATALENGTH(L4.SPLCCode) > 0 THEN 'Y' END,	-- Destination Type
	'', (SELECT COUNT(*) FROM Legs L5 WHERE L5.LoadID = L2.LoadsID AND L5.PickupLocationID = L3.LocationID), 
	CASE WHEN DATALENGTH(V.CustomerIdentification) > 0 THEN LEFT(V.CustomerIdentification,2) ELSE '' END,
	CASE WHEN DATALENGTH(V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,3,7) ELSE '' END,
	CASE WHEN DATALENGTH(V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,10,12) ELSE '' END,
	@SequenceNumber, @ExportedInd, @ExportedDate, @ExportedBy, @RecordStatus, @CreationDate, @CreatedBy,
	@UpdatedDate, @UpdatedBy
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	WHERE V.CustomerID = @CustomerID
	AND V.VehicleStatus = 'Delivered'
	AND L.FinalLegInd = 1
	AND L.DropoffDate > L.PickupDate
	AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
	AND V.VehicleID NOT IN (SELECT FED.VehicleID FROM FordExportDelivery FED WHERE FED.VehicleID = V.VehicleID)
	ORDER BY V.VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Chrysler record'
		GOTO Error_Encountered
	END
			
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		--CLOSE FordDeliveryExportCursor
		--DEALLOCATE FordDeliveryExportCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		--CLOSE FordDeliveryExportCursor
		--DEALLOCATE FordDeliveryExportCursor
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
