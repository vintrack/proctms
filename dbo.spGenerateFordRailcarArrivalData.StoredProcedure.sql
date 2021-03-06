USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateFordRailcarArrivalData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateFordRailcarArrivalData] (@CreatedBy varchar(20))
AS
BEGIN
	DECLARE
	@ErrorID			int,
	--FordExportDelivery table variables
	@BatchID			int,
	@VehicleID			int,
	@InterchangeSenderID		varchar(15),
	@InterchangeReceiverID		varchar(15),
	@FunctionalID			varchar(2),
	@SenderCode			varchar(12),
	@ReceiverCode			varchar(12),
	@TransmissionDateTime		datetime,
	@InterchangeControlNumber	int,
	@ResponsibleAgencyCode		varchar(2),
	@VersionNumber			varchar(12),
	@TransactionSetControlNumber	varchar(9),
	@SCACCode			varchar(4),
	@RecordType			varchar(2),
	@ArrivalRampCode		varchar(2),
	@ActionDate			datetime,
	@RailcarIdentificationNumber	varchar(10),
	@OriginRampCode			varchar(2),
	@SwitchoutDate			datetime,
	@ActionIndicator		varchar(1),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	@UpdatedDate			datetime,
	@UpdatedBy			varchar(20),
	--processing variables
	@CustomerID			int,
	@LoopCounter			int,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateFordRailcarArrivalData				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the railcar arrival export data for	*
	*	Fords that have been arrived at the railhead.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	06/30/2010 CMK    Initial version				*
	*									*
	************************************************************************/
	
	set nocount on
	
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
	WHERE ValueKey = 'NextFordRailcarArrivalExportBatchID'
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
	
	--get the ford ramp code
	SELECT TOP 1 @ArrivalRampCode = Code
	FROM Code
	WHERE CodeType = 'FordLocationCode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting RampCode'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Error Getting RampCode'
		GOTO Error_Encountered2
	END
	
	SELECT @ErrorID = 0
	
	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextFordRailcarArrivalExportBatchID'
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
	SELECT @ExportedInd = 0
	SELECT @ExportedDate = NULL
	SELECT @ExportedBy = NULL
	SELECT @RecordStatus = 'Export Pending'
	SELECT @UpdatedDate = NULL
	SELECT @UpdatedBy = NULL
	SELECT @CreationDate = CURRENT_TIMESTAMP
		
	INSERT INTO FordExportRailcarArrival SELECT DISTINCT @BatchID,
		NULL, --VehicleID
		@InterchangeSenderID,
		@InterchangeReceiverID,
		@FunctionalID,
		@SenderCode,
		@ReceiverCode,
		@TransmissionDateTime,
		@InterchangeControlNumber,
		@ResponsibleAgencyCode,
		@VersionNumber,
		@TransactionSetControlNumber,
		@SCACCode,
		'2A', --RecordType
		C.Code, --ArrivalRampCode
		CONVERT(varchar(10),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate),101), --ActionDate
		V.RailcarNumber TheRailcar,
		FIRS.OriginRampCode, --OriginRampCode
		NULL, --SwitchoutDate
		'', --ActionIndicator
		@ExportedInd,
		@ExportedDate,
		@ExportedBy,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy
	FROM Vehicle V
	LEFT JOIN FordImportRailcarSwitchout FIRS ON V.VIN = FIRS.VIN
	LEFT JOIN Code C ON V.PickupLocationID = CONVERT(int,C.Value1)
	AND C.CodeType = 'FordLocationCode'
	WHERE V.CustomerID = @CustomerID
	AND FIRS.DestinationRampCode = C.Code
	AND V.PickupLocationID IN (SELECT CONVERT(int,C2.Value1) FROM Code C2 WHERE C2.CodeType = 'FordLocationCode') 
	AND ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate) >= DATEADD(day,-10,CONVERT(varchar(10),CURRENT_TIMESTAMP,101))					--WANT THIS IN PRODUCTION
	AND ISNULL(V.RailcarNumber,'') <> ''
	AND V.RailcarNumber NOT IN (SELECT FERA.RailcarIdentificationNumber 
					FROM FordExportRailcarArrival FERA 
					WHERE FERA.RailcarIdentificationNumber = V.RailcarNumber
					AND FERA.CreationDate > DATEADD(day,-10,CURRENT_TIMESTAMP)	--WANT THIS IN PRODUCTION
					)
	ORDER BY TheRailcar
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @BatchID AS BatchID
	
	RETURN
END
GO
