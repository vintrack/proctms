USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddVinNotFoundv2]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spAddVinNotFoundv2](
		@pVIN				varchar(20) = '',
		@pCreatedBy			varchar(20) = '',
		@pDriverID			int = 0,
		@pPickupLocationID   int = -2
	)
AS
BEGIN
	/************************************************************************
	*	spAddVinNotFound
	*	
	*	Description
	*	-----------
	*	Inserts new Vehicle and Leg records for Vin Not Found
	*	Returns LegID
	*	
	*	CUSTOM ERRORS
	*	-------------
	*	<not yet used>
	*	
	*	
	*	Change History
	*	--------------
	*	Date       Init's Description
	*	---------- ------ ----------------------------------------
	*	08/10/2005 JEP    Initial version
	*	08/12/2005 JEP    Added @pDriverID param, set ReservedByDriverID 
	*						to prevent 'NotAssigned' exception
	*	09/09/2005 JEP    Added default value = 0 for:
	*						Vehicle.ShopWorkStartedInd
	*						Legs.PickupLocationID
	*						Legs.DropoffLocationID
	*	10/08/2005 JEP    Added default value = 0 for: 
	*						Vehicle.PickupLocationID
	*						Vehicle.DropoffLocationID
	*						Vehicle.VINDecodedInd
	*	10/08/2005 JEP    Changed default value to -1 for:
	*						Vehicle.PickupLocationID
	*						Vehicle.DropoffLocationID
	*						Legs.PickupLocationID
	*						Legs.DropoffLocationID
	*	10/19/2005 JEP    Changed default value to -2 for:
	*						Vehicle.PickupLocationID
	*						Legs.PickupLocationID
	*	10/24/2005 JEP    don't look for exising vehicle/leg records, just insert it !!!
	*	11/08/2005 JEP    initialize vehicle OrderID to -1
	*   
	************************************************************************/	

	SET nocount on

	DECLARE	
		-- key fields to locate existing records
		@VIN				varchar(17), 
		@VehicleID			int, 
		@LegsID				int,
		@PickupLocationID   int, 
		@CurrentDate		datetime,
		-- process vars
		@ReturnCode			int,
		@ReturnMessage		varchar(50),
		@ReturnRunID		int,
		@ErrorID			int,
		@Msg				varchar(50),
		@Count				int

	
	BEGIN TRAN

	set @VIN = RIGHT(RTRIM(@pVIN), 17)
	set @CurrentDate = getdate()
	set @VehicleID = 0
	set @LegsID = 0
	set @PickupLocationID = @pPickupLocationID
	
	/* commented out - don't look for existing records !!! 10
	-- look for existing @VehicleID
	SELECT @Count = count(*)
	FROM Vehicle
	WHERE VIN = @VIN
	IF @@ERROR <> 0
	  BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered looking for existing Vehicle'
		GOTO Error_Encountered
	  END
	IF @Count = 0 GOTO Do_Insert_Vehicle
	
	-- get existing @VehicleID
	SELECT top 1 @VehicleID = VehicleID
	FROM Vehicle
	WHERE VIN = @VIN
	IF @@ERROR <> 0
	  BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered retrieving existing Vehicle'
		GOTO Error_Encountered
	  END
	
	-- look for existing @LegsID
	SELECT @Count = count(*)
	FROM Legs
	WHERE VehicleID = @VehicleID
	IF @@ERROR <> 0
	  BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered looking for existing Legs record'
		GOTO Error_Encountered
	  END
	IF @Count = 0 GOTO Do_Insert_Leg
	
	-- get existing @LegsID
	SELECT top 1 @LegsID = LegsID
	FROM Legs
	WHERE VehicleID = @VehicleID
	IF @@ERROR <> 0
	  BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered retrieving existing Legs record'
		GOTO Error_Encountered
	  END
	GOTO Error_Encountered -- just return the existing legs record
	-- end of commented-out code
	*/
	
	Do_Insert_Vehicle:
	INSERT INTO Vehicle(
		VIN,
		PickupLocationID,
		DropoffLocationID,
		OrderID,
		VehicleStatus,
		VehicleLocation,
		PriorityInd,
		AvailableForPickupDate,
		ShopWorkStartedInd,
		ShopWorkCompleteInd,
		ChargeRateOverrideInd,
		BilledInd,
		VINDecodedInd,
		RecordStatus,
		CreationDate,
		CreatedBy,
		UpdatedDate,
		UpdatedBy
	)
	VALUES(
		@VIN,
		@PickupLocationID,
		-1, -- DropoffLocationID,
		-1, -- OrderID,
		'Available', -- VehicleStatus
		'Pickup Point', -- VehicleLocation
		0, -- PriorityInd
		@CurrentDate, -- AvailableForPickupDate
		0, --ShopWorkStartedInd
		0, -- ShopWorkCompleteInd
		0, -- ChargeRateOverrideInd
		0, -- BilledInd
		0, -- VINDecodedInd,
		'Active', -- RecordStatus
		@CurrentDate, -- CreationDate
		@pCreatedBy,  -- CreatedBy
		@CurrentDate, -- UpdatedDate
		@pCreatedBy  -- UpdatedBy
	)
	IF @@ERROR <> 0
	  BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating the Vehicle Record'
		GOTO Error_Encountered
	  END
	--get the record ID
	SELECT @VehicleID = @@Identity
	IF @@ERROR <> 0
	  BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Vehicle Record ID'
	  END


	Do_Insert_Leg:
	INSERT INTO LEGS (
		VehicleID,
		DateAvailable,
		PickupLocationID,
		DropoffLocationID,
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
		ReservedByDriverID,
		ExceptionInd,
		CreationDate,
		CreatedBy)
	VALUES (
		@VehicleID,
		@CurrentDate, -- @DateAvailable,
		@PickupLocationID,
		-1, -- DropoffLocationID,
		0, -- OutsideCarrierLegInd
		0, -- OutsideCarrierPaymentMethod
		0, -- OutsideCarrierPercentage
		0, -- OutsideCarrierPay
		0, -- OutsideCarrierFuelSurchargePercentage
		0, -- OCFSPEstablishedInd
		1, -- LegNumber
		1, -- FinalLegInd
		'Assigned', -- LegStatus
		0, -- ShagUnitInd
		1, -- ReservedByDriverInd
		@pDriverID, -- ReservedByDriverID
		0, -- ExceptionInd
		@CurrentDate, -- CreationDate,
		@pCreatedBy
	)
	IF @@ERROR <> 0
	  BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating the Legs Record'
		GOTO Error_Encountered
	  END
	--get the record ID
	SELECT @LegsID = @@Identity
	IF @@ERROR <> 0
	  BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Legs Record ID'
	  END


	Error_Encountered:
	IF @ErrorID <> 0
	BEGIN
		ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Msg
	END
	ELSE
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Vehicle and Legs records Created Successfully'
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM', @LegsID AS 'legID', @VehicleID AS 'VehicleID'

	RETURN @ReturnCode
END
GO
