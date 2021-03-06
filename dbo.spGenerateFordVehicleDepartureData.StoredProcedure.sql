USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateFordVehicleDepartureData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateFordVehicleDepartureData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	--FordExportVehicleDeparture table variables
	@BatchID		int,
	@VehicleID		int,
	@AuthorizationID	varchar(4),
	@TransmissionDateTime	datetime,
	@BODID			varchar(40),
	@CarrierCode		varchar(4),
	@LocationType		varchar(2),
	@LocationCode		varchar(10),
	@EventDateTime		datetime,
	@TransactionType	varchar(10),
	@ConveyanceID		varchar(20),
	@ConveyanceType		varchar(20),
	@NextLocationType	varchar(2),
	@NextLocationCode	varchar(10),
	@CorrectionIdentifier	varchar(1),
	@ExportedInd		int,
	@ExportedDate		datetime,
	@ExportedBy		varchar(20),
	@RecordStatus		varchar(100),
	@CreationDate		datetime,
	@UpdatedDate		datetime,
	@UpdatedBy		varchar(20),
	--processing variables
	@CustomerID		int,
	@LegsID			int,
	@CustomerIdentification	varchar(25),
	@LoopCounter		int,
	@Status			varchar(100),
	@ReturnCode		int,
	@ReturnMessage		varchar(100)	

	/************************************************************************
	*	spGenerateFordVehicleDepartureData				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the vehicle receipt export data for	*
	*	Fords that have been picked up at the railhead.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/02/2010 CMK    Initial version				*
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
	WHERE ValueKey = 'NextFordVehicleDepartureExportBatchID'
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
	
	SELECT @ErrorID = 0
	
	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextFordVehicleDepartureExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--set the default values
	SELECT @LoopCounter = 0
	SELECT @AuthorizationID = 'DVAI'
	SELECT @TransmissionDateTime = NULL --value set during export
	SELECT @BODID = NULL --value set during export
	SELECT @CarrierCode = 'DVAI'
	SELECT @TransactionType = '332'
	SELECT @ConveyanceID = ''
	SELECT @ConveyanceType = 'Convoy'
	SELECT @CorrectionIdentifier = ''
	SELECT @ExportedInd = 0
	SELECT @ExportedDate = NULL
	SELECT @ExportedBy = NULL
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @UpdatedDate = NULL
	SELECT @UpdatedBy = NULL
	
	INSERT INTO FordExportVehicleDeparture(
		BatchID,
		VehicleID,
		AuthorizationID,
		TransmissionDateTime,
		BODID,
		CarrierCode,
		LocationType,
		LocationCode,
		EventDateTime,
		TransactionType,
		ConveyanceID,
		ConveyanceType,
		NextLocationType,
		NextLocationCode,
		CorrectionIdentifier,
		ExportedInd,
		ExportedDate,
		ExportedBy,
		RecordStatus,
		CreationDate,
		CreatedBy,
		UpdatedDate,
		UpdatedBy
	)
	SELECT 
		@BatchID,
		V.VehicleID,
		@AuthorizationID,
		@TransmissionDateTime,
		@BODID,
		@CarrierCode,
		'R' LocationType,
		C.Code,
		L.PickupDate EventDate,
		@TransactionType,
		@ConveyanceID,
		@ConveyanceType,
		CASE WHEN DATALENGTH(L2.CustomerLocationCode) > 0 THEN 'D' ELSE 'S' END NextLocationType,
		CASE WHEN DATALENGTH(L2.CustomerLocationCode) > 0 THEN L2.CustomerLocationCode ELSE L2.SPLCCode END,
		@CorrectionIdentifier,
		@ExportedInd,
		@ExportedDate,
		@ExportedBy,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy
	FROM Vehicle V
	LEFT JOIN Code C ON V.PickupLocationID = CONVERT(int,C.Value1)
	AND C.CodeType = 'FordLocationCode'
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	AND L.LegNumber = 1
	LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
	WHERE V.CustomerID = @CustomerID
	AND V.AvailableForPickupDate IS NOT NULL
	AND L.PickupDate IS NOT NULL
	AND L.PickupDate >= V.AvailableForPickupDate
	AND CONVERT(int,C.Value1) IS NOT NULL
	AND V.VehicleID NOT IN (SELECT FEVD.VehicleID FROM FordExportVehicleDeparture FEVD WHERE FEVD.VehicleID = V.VehicleID)
	ORDER BY LocationType,C.Code,EventDate, V.VehicleID
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
