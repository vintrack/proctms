USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateFordVehicleDeliveryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateFordVehicleDeliveryData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	--FordExportVehicleDelivery table variables
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
	*	spGenerateFordVehicleDeliveryData				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the vehicle delivery export data for	*
	*	Fords that have been delivered to the dealer.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/16/2010 CMK    Initial version				*
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
	WHERE ValueKey = 'NextFordVehicleDeliveryExportBatchID'
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
	WHERE ValueKey = 'NextFordVehicleDeliveryExportBatchID'
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
	SELECT @TransactionType = '630'
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
	
	INSERT INTO FordExportVehicleDelivery(
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
		CASE WHEN DATALENGTH(L2.CustomerLocationCode) > 0 THEN 'D' ELSE 'S' END LocationType,
		CASE WHEN DATALENGTH(L2.CustomerLocationCode) > 0 THEN L2.CustomerLocationCode ELSE L2.SPLCCode END,
		L.DropoffDate EventDate,
		@TransactionType,
		@ConveyanceID,
		@ConveyanceType,
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
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	AND L.FinalLegInd = 1
	LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
	WHERE V.CustomerID = @CustomerID
	AND V.AvailableForPickupDate IS NOT NULL
	AND L.DropoffDate IS NOT NULL
	AND L.PickupDate >= V.AvailableForPickupDate
	AND L.DropoffDate >= L.PickupDate
	AND V.VehicleID NOT IN (SELECT FEVD.VehicleID FROM FordExportVehicleDelivery FEVD WHERE FEVD.VehicleID = V.VehicleID)
	ORDER BY LocationType, L2.CustomerLocationCode, EventDate, V.VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating FordExportVehicleDelivery record'
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
