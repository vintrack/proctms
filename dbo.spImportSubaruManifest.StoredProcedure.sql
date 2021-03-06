USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportSubaruManifest]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROC [dbo].[spImportSubaruManifest] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@loopcounter		int,
	--SubaruManifestImport table variables
	@SubaruManifestImportID	int,
	@ShipNumber		varchar(10),
	@VINKey			varchar(8),
	@CaseNumber		varchar(11),
	@FHIModelCode		varchar(14),
	@FHIExteriorColorCode	varchar(23),
	@SerialNumber		varchar(13),
	@KeyNumber		varchar(10),
	@VehicleYear		varchar(6), 
	@Make			varchar(50), 
	@Model			varchar(50),
	@Bodystyle		varchar(50),
	@VehicleLength		varchar(10),
	@VehicleWidth		varchar(10),
	@VehicleHeight		varchar(10),
	--Processing Variables
	@Count			int,
	@VPCVehicleID		int,
	@SDCCustomerID		int,
	@SDCVehicleID		int,
	@ReturnCode		int,
	@ReturnMessage		varchar(100),
	@ImportedInd		int,
	@ImportedDate		datetime,
	@ImportedBy		varchar(20),
	@RecordStatus		varchar(100),
	@Status			varchar(100),
	@Result			int,
	@CreationDate		datetime,
	@CreatedBy		varchar(20)
			
	
	/************************************************************************
	*	spImportSubaruManifest						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the SubaruManifestImport 	*
	*	table and Updates or Creates the VPCVehicle records.		*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	10/12/2012 CMK    Initial version				*
	*									*
	************************************************************************/
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @UserCode

	--get the sdccustomer id from the setting table
	Select @SDCCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SDCCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CustomerID'
		GOTO Error_Encountered2
	END
	IF @SDCCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered2
	END

	DECLARE SubaruManifestCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT SubaruManifestImportID, ShipNumber,
		VINKey, CaseNumber, FHIModelCode, FHIExteriorColorCode,
		SerialNumber, KeyNumber, VehicleYear, Make, Model,
		Bodystyle, VehicleLength, VehicleWidth, VehicleHeight
		FROM SubaruManifestImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY SubaruManifestImportID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN SubaruManifestCursor

	BEGIN TRAN

	FETCH SubaruManifestCursor INTO @SubaruManifestImportID, @ShipNumber,
		@VINKey, @CaseNumber, @FHIModelCode, @FHIExteriorColorCode,
		@SerialNumber, @KeyNumber, @VehicleYear, @Make, @Model,
		@Bodystyle, @VehicleLength, @VehicleWidth, @VehicleHeight
	

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @ImportedInd = 0
		SELECT @ImportedDate = NULL
		SELECT @ImportedBy = NULL
		SELECT @RecordStatus = 'Import Pending'
		
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @Count = COUNT(*)
		FROM VPCVehicle
		WHERE FullVIN = @VINKey + @SerialNumber
		AND DateOut IS NULL
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @Count > 0
		BEGIN
			--see if there are any changes to the origin/destination
			SELECT TOP 1 @VPCVehicleID = V.VPCVehicleID
			FROM VPCVehicle V
			WHERE FullVIN = @VINKey + @SerialNumber
			AND DateOut IS NULL
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
				GOTO Error_Encountered
			END
			
			--update logic here.
			UPDATE VPCVehicle
			SET ShipNumber = @ShipNumber,
			CaseNumber = @CaseNumber,
			UpdatedDate = @CreationDate,
			UpdatedBy = @CreatedBy
			WHERE VPCVehicleID = @VPCVehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
			END
			
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = @CreationDate
			SELECT @ImportedBy = @CreatedBy
			SELECT @RecordStatus = 'Imported'
		END
		ELSE
		BEGIN
			--see if the vehicle already exists in the vehicle table
			SELECT @Count = NULL
			SELECT @Count = COUNT(*)
			FROM Vehicle
			WHERE CustomerID = @SDCCustomerID
			AND VIN = @VinKey + @SerialNumber
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE COUNT'
				GOTO Error_Encountered
			END
			
			IF @Count = 0
			BEGIN
				--just need skeleton vehicle record, release will populate missing data
				INSERT INTO Vehicle(
					CustomerID,
					VIN,
					VehicleYear,
					Make,
					Model,
					Bodystyle,
					VehicleLength,
					VehicleWidth,
					VehicleHeight,
					VehicleStatus,
					VehicleLocation,
					PriorityInd,
					ShopWorkStartedInd,
					ShopWorkCompleteInd,
					ChargeRateOverrideInd,
					BilledInd,
					VINDecodedInd,
					RecordStatus,
					CreationDate,
					CreatedBy,
					CreditHoldInd,
					PickupNotificationSentInd,
					STIDeliveryNotificationSentInd,
					BillOfLadingSentInd,
					DealerHoldOverrideInd,
					AccessoriesCompleteInd,
					PDICompleteInd,
					FinalShipawayInspectionDoneInd
				)
				VALUES(
					@SDCCustomerID,
					@SerialNumber + @VINKey,
					@VehicleYear,
					@Make,
					@Model,
					@Bodystyle,
					@VehicleLength,
					@VehicleWidth,
					@VehicleHeight,
					'Pending',	--VehicleStatus
					'Pickup Point',	--VehicleLocation
					0,		--PriorityInd
					0,		--ShopWorkStartedInd
					0,		--ShopWorkCompleteInd
					0,		--ChargeRateOverrideInd
					0,		--BilledInd
					0,		--VINDecodedInd
					'Active',	--RecordStatus
					@CreationDate,
					@CreatedBy,
					0,		--CreditHoldInd
					0,		--PickupNotificationSentInd
					0,		--STIDeliveryNotificationSentInd
					0,		--BillOfLadingSentInd
					0,		--DealerHoldOverrideInd
					0,		--AccessoriesCompleteInd
					0,		--PDICompleteInd
					0		--FinalShipawayInspectionDoneInd
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR INSERTING VEHICLE RECROD'
					GOTO Error_Encountered
				END
								
				SELECT @SDCVehicleID = @@Identity		
				
				INSERT INTO Legs(
					VehicleID,
					OutsideCarrierLegInd,
					OutsideCarrierPaymentMethod,
					OutsideCarrierPercentage, 
					OutsideCarrierPay,
					OutsideCarrierFuelSurchargePercentage,
					OCFSPEstablishedInd,
					LegNumber,
					FinalLegInd,
					LegStatus,
					ShagUnitInd,
					ReservedByDriverInd,
					ExceptionInd,
					CreationDate,
					CreatedBy
				)
				VALUES(
					@SDCVehicleID,	--VehicleID
					0,		--OutsideCarrierLegInd
					0,		--OutsideCarrierPaymentMethod
					0,		--OutsideCarrierPercentage
					0,		--OutsideCarrierPay
					0,		--OutsideCarrierFuelSurchargePercentage
					0,		--OCFSPEstablishedInd
					1,		--LegNumber
					1,		--FinalLegInd
					'Pending',	--LegStatus
					0,		--ShagUnitInd
					0,		--ReservedByDriverInd
					0,		--ExceptionInd
					@CreationDate,
					@CreatedBy
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR INSERTING LEGS RECORD'
					GOTO Error_Encountered
				END				
			END
			
			--add the vpcvehicle record
			INSERT VPCVehicle(
				VINNumber,
				VINKey,
				FullVIN,
				VehicleYear,
				ModelCode,
				ModelDescription,
				ExteriorColor,
				ShipNumber,
				CaseNumber,
				KeyNumber,
				ShopWorkStartedInd,
				AccessoriesCompleteInd,
				PDICompleteInd,
				ShopWorkCompleteInd,
				FinalShipawayInspectionDoneInd,
				PriorityInd,
				VehicleStatus,
				SDCVehicleID,
				CreationDate,
				CreatedBy
			)
			VALUES(
				@SerialNumber,		--VINNumber
				@VINKey,
				@SerialNumber + @VINKey,--FullVIN
				@VehicleYear,
				@FHIModelCode,		--ModelCode
				@Model,			--ModelDescription
				@FHIExteriorColorCode,	--ExteriorColor
				@ShipNumber,
				@CaseNumber,
				@KeyNumber,
				0,			--ShopWorkStartedInd
				0,			--AccessoriesCompleteInd
				0,			--PDICompleteInd
				0,			--ShopWorkCompleteInd
				0,			--FinalShipawayInspectionDoneInd
				0,			--PriorityInd
				'Pending',		--VehicleStatus
				@SDCVehicleID,
				@CreationDate,
				@CreatedBy
				)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR CREATING VEHICLE RECORD'
				GOTO Error_Encountered
			END
			
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = @CreationDate
			SELECT @ImportedBy = @CreatedBy
			SELECT @RecordStatus = 'VPC VEHICLE CREATED'
		END
		print 'at update import record'
		--update logic here.
		Update_Import_Record:
		UPDATE SubaruManifestImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE SubaruManifestImportID = @SubaruManifestImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END
		
		FETCH SubaruManifestCursor INTO @SubaruManifestImportID, @ShipNumber,
		@VINKey, @CaseNumber, @FHIModelCode, @FHIExteriorColorCode,
		@SerialNumber, @KeyNumber, @VehicleYear, @Make, @Model,
		@Bodystyle, @VehicleLength, @VehicleWidth, @VehicleHeight

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE SubaruManifestCursor
		DEALLOCATE SubaruManifestCursor
		PRINT 'ImportSubaruMoves Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE SubaruManifestCursor
		DEALLOCATE SubaruManifestCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		PRINT 'ImportSubaruManifest Error_Encountered =' + STR(@ErrorID)
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
