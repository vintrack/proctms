USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddVPCVehicleRecord]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[spAddVPCVehicleRecord](
	@VehicleID		int,
	@CreatedBy		varchar(20)
	)
AS
BEGIN
	/************************************************************************
	*	spAddVPCVehicleRecord						*
	*									*
	*	Description							*
	*	-----------							*
	*	Creates a VPCVehicle record for any SDC Vehicle created 	*
	*	through the vehicle window.				 	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	10/11/2012 CMK    Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@VPCVehicleID			int,
		@SDCDiversifiedLocationID	int,
		@VehicleYear			varchar(6),
		@ModelDescription		varchar(50),
		@VIN				varchar(17),
		@ExteriorColor			varchar(20),
		@PickupLocationID		int,
		@DestinationDealerCode		varchar(20),
		@DateAvailable			datetime,
		@PriorityInd			int,
		@RecordStatus			varchar(20),
		@CreationDate			datetime,
		@DH_VehicleID			int,
		@ReturnCode			int,
		@ReturnMessage			varchar(100),
		@ErrorID			int,
		@Msg				varchar(100),
		@Count				int

	SELECT @ErrorID = 0
			
	BEGIN TRAN
	
	--set the default values
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	--get the vehicle details
	SELECT TOP 1 @VehicleYear = VehicleYear,
	@ModelDescription = Model,
	@VIN = VIN,
	@ExteriorColor = Color,
	@PickupLocationID = V.PickupLocationID,
	@DestinationDealerCode = L.CustomerLocationCode,
	@DateAvailable = V.AvailableForPickupDate,
	@PriorityInd = PriorityInd
	FROM Vehicle V
	LEFT JOIN Location L ON V.DropoffLocationID = L.LocationID
	WHERE V.VehicleID = @VehicleID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' Encountered Getting Vehicle Details'
		GOTO Error_Encountered
	END
	
	--get the SDC Diversified Location ID
	SELECT @SDCDiversifiedLocationID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SDCDiversifiedLocationID'
	IF @@ERROR <> 0
	BEGIN
		print 'in get chrysler customer id error'
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting Chrysler Customer ID'
		GOTO Error_Encountered
	END
	IF @SDCDiversifiedLocationID IS NULL
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Msg = 'Error Getting SDC DAI LocationID'
		GOTO Error_Encountered
	END
		
	IF @PickupLocationID <> @SDCDiversifiedLocationID
	BEGIN
		SELECT @ErrorID = 0
		SELECT @Msg = 'Not A VPC Vehicle'
		GOTO Error_Encountered
	END
		
	--see if there is already a VPCVehicleRecord
	SELECT @Count = NULL
	SELECT @Count = COUNT(*)
	FROM VPCVehicle
	WHERE FullVIN = @VIN
	AND DateOut IS NULL
	AND SDCVehicleID IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Getting VPC Vehicle Count'
		GOTO Error_Encountered
	END
	
	IF @Count = 1
	BEGIN
		SELECT @VPCVehicleID = VPCVehicleID
		FROM VPCVehicle
		WHERE FullVIN = @VIN
		AND DateOut IS NULL
		AND SDCVehicleID IS NULL
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting VPC Vehicle ID'
			GOTO Error_Encountered
		END
	END
	ELSE IF @Count > 1
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Msg = 'Multiple Open VPC Vehicle Records'
		GOTO Error_Encountered
	END
	
	IF @VPCVehicleID IS NOT NULL
	BEGIN
		--update the VPCVehicle record
		--(going to assume it has the most recent data)
		UPDATE VPCVehicle
		SET SDCVehicleID = @VehicleID,
		UpdatedDate = @CreationDate,
		UpdatedBy = @CreatedBy
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Updating VPC Vehicle Record'
			GOTO Error_Encountered
		END
	END
	ELSE
	BEGIN
		--try to get the DH_VehicleID
		SELECT @Count = NULL
		
		SELECT @Count = COUNT(*)
		FROM VPCVehicle
		WHERE FullVIN = @VIN
		AND DH_VehicleID IS NOT NULL
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting DH_VehicleID Count'
			GOTO Error_Encountered
		END
		
		IF @Count > 0
		BEGIN
			SELECT TOP 1 @DH_VehicleID = DH_VehicleID
			FROM VPCVehicle
			WHERE FullVIN = @VIN
			AND DH_VehicleID IS NOT NULL
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Getting DH_VehicleID'
				GOTO Error_Encountered
			END
		END
		
		--insert the VPCVehicle record
		--print 'inserting the vehicle hold record'
		INSERT INTO VPCVehicle(
			VINNumber,
			VINKey,
			FullVIN,
			VehicleYear,
			ModelDescription,
			ExteriorColor,
			DestinationDealerCode,
			DateIn,
			ReleaseDate,
			ShopWorkStartedInd,
			AccessoriesCompleteInd,
			PDICompleteInd,
			ShopWorkCompleteInd,
			FinalShipawayInspectionDoneInd,
			PriorityInd,
			VehicleStatus,
			SDCVehicleID,
			CreationDate,
			CreatedBy,
			DH_VehicleID		
		)
		VALUES(
			LEFT(@VIN,9),
			RIGHT(@VIN,8),
			@VIN,
			@VehicleYear,
			@ModelDescription,
			@ExteriorColor,
			@DestinationDealerCode,
			@DateAvailable,	--DateIn
			@DateAvailable,	--ReleaseDate
			0,		--ShopWorkStartedInd
			0,		--AccessoriesCompleteInd
			0,		--PDICompleteInd
			0,		--ShopWorkCompleteInd
			0,		--FinalShipawayInspectionDoneIndDH_VehicleID
			@PriorityInd,
			'Released',	--VehicleStatus,
			@VehicleID,
			@CreationDate,
			@CreatedBy,
			@DH_VehicleID
		)
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered adding VPCVehicle Record'
			GOTO Error_Encountered
		END
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
		SELECT @ReturnMessage = 'VPC Vehicle Record Created Successfully'
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM'

	RETURN @ReturnCode
END

GO
