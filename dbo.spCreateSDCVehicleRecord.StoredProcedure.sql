USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spCreateSDCVehicleRecord]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spCreateSDCVehicleRecord](
	@VIN		varchar(20),
	@VehicleYear	varchar(6),
	@Make		varchar(50),
	@Model		varchar(50),
	@Bodystyle	varchar(50),
	@Color		varchar(20),
	@BayLocation	varchar(20),
	@CreatedBy	varchar(20)
	)
AS
BEGIN
	/************************************************************************
	*	spCreateSDCVehicleRecord					*
	*									*
	*	Description							*
	*	-----------							*
	*	Creates a basic vehicle and leg record for SDC (to allow	*
	*	vehicle inspections and bay locations to be entered into the 	*
	*	system before the release is received.			 	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	09/07/2005 CMK    Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@CustomerID	int,
		@OriginID	int,
		@VehicleID	int,
		@DecodedColor	varchar(20),
		@CreationDate		datetime,
		@ReturnCode		int,
		@ReturnMessage		varchar(50),
		@ReturnVehicleID	int,
		@ErrorID		int,
		@Msg			varchar(50)

	BEGIN TRAN
	
	SELECT @ErrorID = 0
			
	--get the customer id from the setting table
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SDCCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Getting CustomerID'
		GOTO Error_Encountered
	END
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Msg = 'CustomerID Not Found'
		GOTO Error_Encountered
	END
	
	--get the sdc dai location id
	SELECT @OriginID = CONVERT(int,Value1)
	FROM Code
	WHERE CodeType = 'SDCLocationCode'
	AND Code = 'DAI' --ALL SDC LOADS ORIGINATE FROM CHARLESTOWN
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'ERROR GETTING ORIGIN LOCATION'
		GOTO Error_Encountered
	END
	
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	SELECT @DecodedColor = CodeDescription
	FROM Code
	WHERE CodeType = 'SubaruColorCode'
	AND Code = @Color
	IF @DecodedColor IS NULL OR DATALENGTH(@DecodedColor)<1
	BEGIN
		SELECT @DecodedColor = @Color
	END
	
	INSERT VEHICLE(
		CustomerID,
		OrderID,
		VehicleYear,
		Make,
		Model,
		Bodystyle,
		VIN,
		Color,
		VehicleLength,
		VehicleWidth,
		VehicleHeight,
		PickupLocationID,
		DropoffLocationID,
		VehicleStatus,
		VehicleLocation,
		CustomerIdentification,
		SizeClass,
		BayLocation,
		RailCarNumber,
		PriorityInd,
		HaulType,
		AvailableForPickupDate,
		ShopWorkStartedInd,
		ShopWorkStartedDate,
		ShopWorkCompleteInd,
		ShopWorkCompleteDate,
		PaperworkReceivedDate,
		ICLAuditCode,
		ChargeRate,
		ChargeRateOverrideInd,
		BilledInd,
		DateBilled,
		VINDecodedInd,
		RecordStatus,
		CreationDate,
		CreatedBy,
		UpdatedDate,
		UpdatedBy,
		CreditHoldInd,
		PickupNotificationSentInd,
		STIDeliveryNotificationSentInd,
		BillOfLadingSentInd,
		DealerHoldOverrideInd,
		MiscellaneousAdditive,
		FuelSurcharge,
		AccessoriesCompleteInd,
		PDICompleteInd,
		FinalShipawayInspectionDoneInd
	)
	VALUES(
		@CustomerID,			--CustomerID,
		NULL,				--OrderID,
		@VehicleYear,			--VehicleYear,
		@Make,				--Make,
		@Model,				--Model,
		@Bodystyle,			--Bodystyle,
		@VIN,				--VIN,
		@DecodedColor,			--Color,
		NULL,				--VehicleLength
		NULL,				--VehicleWidth
		NULL,				--VehicleHeight
		@OriginID,			--PickupLocationID,
		NULL,				--DropoffLocationID,
		'Pending',			--VehicleStatus,
		'Pickup Point',			--VehicleLocation,
		NULL,				--CustomerIdentification,
		'A',				--SizeClass,
		NULL,				--BayLocation,
		NULL,				--RailCarNumber,
		0,				--PriorityInd
		NULL,				--HaulType,
		NULL,				--AvailableForPickupDate,-----------for now.
		0,				--ShopWorkStartedInd,
		NULL,				--ShopWorkStartedDate,
		0,				--ShopWorkCompleteInd,
		NULL,				--ShopWorkCompleteDate,
		NULL,				--PaperworkReceivedDate,
		NULL,				--ICLAuditCode,
		NULL,				--ChargeRate
		0,				--ChargeRateOverrideInd
		0,				--BilledInd
		NULL,				--DateBilled
		0,				--VINDecodedInd
		'Active',			--RecordStatus,
		@CreationDate,			--CreationDate
		@CreatedBy,			--CreatedBy
		NULL,				--UpdatedDate,
		NULL,				--UpdatedBy
		0,				--CreditHoldInd
		0,				--PickupNotificationSentInd
		0,				--STIDeliveryNotificationSentInd
		0,				--BillOfLadingSentInd
		0,				--DealerHoldOverrideInd
		0,				--MiscellaneousAdditive
		0,				--FuelSurcharge
		0,				--AccessoriesCompleteInd,
		0,				--PDICompleteInd
		0				--FinalShipawayInspectionDoneInd
	)
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'ERROR CREATING VEHICLE RECORD'
		GOTO Error_Encountered
	END
	
	SELECT @VehicleID = @@IDENTITY
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the identity value'
		GOTO Error_Encountered
	END
	
	-- now create the Legs record for the vehicle
	--have to create the legs record
	INSERT INTO Legs(
		VehicleID,
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
		CreationDate,
		CreatedBy,
		OutsideCarrierFuelSurchargeType
	)
	VALUES(
		@VehicleID,
		@OriginID,
		NULL,		--DestinationID
		0, 		--OutsideCarrierLegInd
		0, 		--OutsideCarrierPaymentMethod
		0, 		--OutsideCarrierPercentage
		0, 		--OutsideCarrierPay
		0,		--OutsideCarrierFuelSurchargePercentage
		0,		--OCFSPEstablishedInd
		1, 		--LegNumber
		1, 		--FinalLegInd
		'Pending',
		0,		--ShagUnitInd
		@CreationDate, 	--CreationDate
		@CreatedBy, 	--CreatedBy
		0		--OutsideCarrierFuelSurchargeType
	)
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'ERROR CREATING DEFAULT LEG'
		GOTO Error_Encountered
	END
	
	
	Error_Encountered:
	IF @ErrorID <> 0
	BEGIN
		ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Msg
		SELECT @ReturnVehicleID = 0
		
	END
	ELSE
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Vehicle Record Created Successfully'
		SELECT @ReturnVehicleID = @VehicleID
		
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM', @ReturnVehicleID  AS 'RVID'

	RETURN @ReturnCode
END

GO
