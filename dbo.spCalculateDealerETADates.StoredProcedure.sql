USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spCalculateDealerETADates]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spCalculateDealerETADates] (@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	@ChryslerCustomerID		int,
	@FordCustomerID			int,
	@GMCustomerID			int,
	@HondaCustomerID		int,
	@HyundaiCustomerID		int,
	@KiaCustomerID			int,
	@SDCCustomerID			int,
	@SOACustomerID			int,
	@VolvoCustomerID		int,
	@VWCustomerID			int,
	@DeliveryStandardDays		int,
	@ReturnCode			int,
	@Status				varchar(100),
	@ReturnMessage			varchar(100)	
					
	/************************************************************************
	*	spCalculateDealerETADates					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure updates OEM Vehicle records with a DealerETADate	*
	*	to be used for aging in the Work In Process window.		*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	09/13/2017 CMK    Initial version				*
	*									*
	************************************************************************/
	
	SELECT @ErrorID = 0
	
	--get the customer ids from the setting table
	SELECT @ChryslerCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ChryslerCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting ChryslerCustomerID'
		GOTO Error_Encountered2
	END
	IF @ChryslerCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'ChryslerCustomerID Not Found'
		GOTO Error_Encountered2
	END
	
	SELECT @FordCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'FordCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting FordCustomerID'
		GOTO Error_Encountered2
	END
	IF @FordCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'FordCustomerID Not Found'
		GOTO Error_Encountered2
	END

	SELECT @GMCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'GMCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting GMCustomerID'
		GOTO Error_Encountered2
	END
	IF @GMCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Status = 'GMCustomerID Not Found'
		GOTO Error_Encountered2
	END
	
	SELECT @HondaCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'HondaCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting HondaCustomerID'
		GOTO Error_Encountered2
	END
	IF @HondaCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100004
		SELECT @Status = 'HondaCustomerID Not Found'
		GOTO Error_Encountered2
	END

	SELECT @HyundaiCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'HyundaiCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting HyundaiCustomerID'
		GOTO Error_Encountered2
	END
	IF @HyundaiCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100005
		SELECT @Status = 'HyundaiCustomerID Not Found'
		GOTO Error_Encountered2
	END
	
	SELECT @KiaCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'KiaCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting KiaCustomerID'
		GOTO Error_Encountered2
	END
	IF @KiaCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100006
		SELECT @Status = 'KiaCustomerID Not Found'
		GOTO Error_Encountered2
	END

	SELECT @SDCCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SDCCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SDCCustomerID'
		GOTO Error_Encountered2
	END
	IF @SDCCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100007
		SELECT @Status = 'SDCCustomerID Not Found'
		GOTO Error_Encountered2
	END
	
	SELECT @SOACustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SOACustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SOACustomerID'
		GOTO Error_Encountered2
	END
	IF @SOACustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100008
		SELECT @Status = 'SOACustomerID Not Found'
		GOTO Error_Encountered2
	END

	SELECT @VolvoCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolvoCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting VolvoCustomerID'
		GOTO Error_Encountered2
	END
	IF @VolvoCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100009
		SELECT @Status = 'VolvoCustomerID Not Found'
		GOTO Error_Encountered2
	END

	SELECT @VWCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolkswagenCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting VWCustomerID'
		GOTO Error_Encountered2
	END
	IF @VWCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100009
		SELECT @Status = 'VWCustomerID Not Found'
		GOTO Error_Encountered2
	END

	--update Chrysler units, no delivery standards so use 2 days
	SELECT @DeliveryStandardDays = 2
	
	UPDATE Vehicle
	SET DealerETADate = DATEADD(day,@DeliveryStandardDays,AvailableForPickupDate)
	WHERE CustomerID = @ChryslerCustomerID
	AND AvailableForPickupDate IS NOT NULL
	AND VehicleStatus = 'Available'
	AND DealerETADate IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error updating Chrysler units'
		GOTO Error_Encountered
	END
	
	--update Ford units, no delivery standards so use 3 days
	SELECT @DeliveryStandardDays = 3
	
	UPDATE Vehicle
	SET DealerETADate = DATEADD(day,@DeliveryStandardDays,AvailableForPickupDate)
	WHERE CustomerID = @FordCustomerID
	AND AvailableForPickupDate IS NOT NULL
	AND VehicleStatus = 'Available'
	AND DealerETADate IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error updating Ford units'
		GOTO Error_Encountered
	END
	
	--update GM units, using the delivery standards
	
	UPDATE Vehicle
	SET DealerETADate = DATEADD(day,ISNULL(LPS.StandardDays,3),V.AvailableForPickupDate)
	FROM Vehicle V
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	WHERE V.CustomerID = @GMCustomerID
	AND V.AvailableForPickupDate IS NOT NULL
	AND V.VehicleStatus = 'Available'
	AND V.DealerETADate IS NULL
	--AND LPS.StandardDays IS NOT NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error updating GM units'
		GOTO Error_Encountered
	END
	
	--update Honda units, using the delivery standards
	
	UPDATE Vehicle
	SET DealerETADate = DATEADD(hour,ISNULL(LPS.StandardDays,60),V.AvailableForPickupDate)
	FROM Vehicle V
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	WHERE V.CustomerID = @HondaCustomerID
	AND V.AvailableForPickupDate IS NOT NULL
	AND V.VehicleStatus = 'Available'
	AND V.DealerETADate IS NULL
	--AND LPS.StandardDays IS NOT NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error updating Honda units'
		GOTO Error_Encountered
	END
	
	--update Hyundai units, no delivery standards so use 3 days
	SELECT @DeliveryStandardDays = 3
	
	UPDATE Vehicle
	SET DealerETADate = DATEADD(day,@DeliveryStandardDays,AvailableForPickupDate)
	WHERE CustomerID = @HyundaiCustomerID
	AND AvailableForPickupDate IS NOT NULL
	AND VehicleStatus = 'Available'
	AND DealerETADate IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error updating Hyundai units'
		GOTO Error_Encountered
	END
	
	--update Kia units, no delivery standards so use 3 days
	SELECT @DeliveryStandardDays = 3
	
	UPDATE Vehicle
	SET DealerETADate = DATEADD(day,@DeliveryStandardDays,AvailableForPickupDate)
	WHERE CustomerID = @KiaCustomerID
	AND AvailableForPickupDate IS NOT NULL
	AND VehicleStatus = 'Available'
	AND DealerETADate IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error updating Kia units'
		GOTO Error_Encountered
	END
	
	--update SOA units, no delivery standards so use 3 days
	SELECT @DeliveryStandardDays = 3
	
	UPDATE Vehicle
	SET DealerETADate = DATEADD(day,@DeliveryStandardDays,AvailableForPickupDate)
	WHERE CustomerID = @SOACustomerID
	AND AvailableForPickupDate IS NOT NULL
	AND VehicleStatus = 'Available'
	AND DealerETADate IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error updating SOA units'
		GOTO Error_Encountered
	END
	
	--update SDC units, no delivery standards so use 7 days
	SELECT @DeliveryStandardDays = 7
	
	UPDATE Vehicle
	SET DealerETADate = DATEADD(day,@DeliveryStandardDays,AvailableForPickupDate)
	WHERE CustomerID = @SDCCustomerID
	AND AvailableForPickupDate IS NOT NULL
	AND VehicleStatus = 'Available'
	AND DealerETADate IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error updating SDC units'
		GOTO Error_Encountered
	END
	
	--update Volvo units, no delivery standards so use 2 days
	SELECT @DeliveryStandardDays = 2
	
	UPDATE Vehicle
	SET DealerETADate = DATEADD(day,@DeliveryStandardDays,AvailableForPickupDate)
	WHERE CustomerID = @VolvoCustomerID
	AND AvailableForPickupDate IS NOT NULL
	AND VehicleStatus = 'Available'
	AND DealerETADate IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error updating Volvo units'
		GOTO Error_Encountered
	END
	
	--update VW units, no delivery standards so use 3 days
	SELECT @DeliveryStandardDays = 3
	
	UPDATE Vehicle
	SET DealerETADate = DATEADD(day,@DeliveryStandardDays,AvailableForPickupDate)
	WHERE CustomerID = @VWCustomerID
	AND AvailableForPickupDate IS NOT NULL
	AND VehicleStatus = 'Available'
	AND DealerETADate IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error updating VW units'
		GOTO Error_Encountered
	END
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		--COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		--ROLLBACK TRAN
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
