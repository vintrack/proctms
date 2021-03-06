USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateRailDeliveryDamageData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateRailDeliveryDamageData] (@LocationID int, @CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@loopcounter		int,
	--MercedesDeliveryExport table variables
	@BatchID		int,
	@VehicleID		int,
	@VehicleDamageDetailID	int,
	@ExportedInd		int,
	@ExportedDate		datetime,
	@ExportedBy		varchar(20),
	@RecordStatus		varchar(20),
	@CreationDate		datetime,
	--processing variables
	@Status			varchar(100),
	@ReturnCode		int,
	@ReturnMessage		varchar(100)	

	/************************************************************************
	*	spGenerateRailDeliveryDamageData				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the vehicle delivery damage data for	*
	*	vehicles that have been picked up from the specified railhead.	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	06/15/2009 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextRailDeliveryDamageExportBatchID'
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

	DECLARE RailDeliveryDamageCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, VDD.VehicleDamageDetailID
		FROM Vehicle V
		LEFT JOIN VehicleInspection VI ON V.VehicleID = VI.VehicleID
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		WHERE V.PickupLocationID = @LocationID
		AND V.VehicleStatus = 'Delivered'
		AND VI.InspectionType IN (3) --,6)
		AND VDD.DamageCode IS NOT NULL
		AND VDD.DamageCode <> ''
		AND VDD.CreationDate >= '06/14/2009'
		AND VDD.VehicleDamageDetailID NOT IN (SELECT ERD.VehicleDamageDetailID FROM ExportRailDeliveryDamage ERD WHERE ERD.VehicleID = V.VehicleID)
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN RailDeliveryDamageCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextRailDeliveryDamageExportBatchID'
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
	
	FETCH RailDeliveryDamageCursor INTO @VehicleID, @VehicleDamageDetailID
	
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		INSERT INTO ExportRailDeliveryDamage(
			BatchID,
			PickupLocationID,
			VehicleID,
			VehicleDamageDetailID,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@LocationID,
			@VehicleID,
			@VehicleDamageDetailID,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating ExportRailDeliveryDamage record'
			GOTO Error_Encountered
		END
			
		FETCH RailDeliveryDamageCursor INTO @VehicleID, @VehicleDamageDetailID
	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE RailDeliveryDamageCursor
		DEALLOCATE RailDeliveryDamageCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE RailDeliveryDamageCursor
		DEALLOCATE RailDeliveryDamageCursor
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
