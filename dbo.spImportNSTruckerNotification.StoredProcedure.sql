USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportNSTruckerNotification]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportNSTruckerNotification] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	@NSTruckerNotificationImportID	int,
	@NSRampCode			varchar(3),
	@NSCustomerCode			varchar(2), 
	@RailcarNumber			varchar(10),
	@ActionDate			datetime,
	@TransmitTime			varchar(10),
	@VIN				varchar(17),
	@DealerCode			varchar(6),
	@BayLocation			varchar(7),
	@VehicleYear			varchar(6),
	@Make				varchar(50),
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VINDecodedInd			int,
	@VINCOUNT			int,
	@DestinationID			int,
	@OriginID			int,
	@ChargeRate			decimal(19,2),
	@CustomerID			int,
	@OrderID			int,
	@CustomerCode			varchar(70),
	@PreviousOrigin			int,
	@PreviousDestination		int,
	@OrderNumber			int,
	@RecordStatus			varchar(100),
	@Status				varchar(100),
	@OrderNumberPlusOne		int,
	@VehicleID			int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@NeedsReviewInd			int,
	@TotalOrderUnits		int,
	@TotalOrderChargeRate		decimal(19,2),
	@LegsCount			int,
	@ImportError			int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@CreationDate			datetime,
	@VehicleCustomerID		int,
	@VehicleOriginID		int,
	@VehicleDestinationID		int,
	@VehicleSizeClass		varchar(10),
	@CustomerIdentification		varchar(20),
	@VehicleLoadID			int,
	@VehiclePoolID			int,
	@LegStatus			varchar(20),
	@VehicleStatus			varchar(20),
	@AssignedDealerInd		int,
	@VehicleChargeRate		decimal(19,2),
	@VINBodyType			varchar(1),
	@PlantCode			varchar(1),
	@VehicleType			varchar(1),
	@SizeClass			varchar(10),
	@DestinationName		varchar(50),
	@PoolRecordCount		int,
	@PoolID				int,
	@Reserved			int,
	@Available			int,
	@PoolSize			int,
	@OldLegStatus			varchar(20),
	@AvailableForPickupDate		datetime,
	@TierRateCode			varchar(2),
	@HondaCustomerID		int,
	@FordCustomerID			int,
	@MercedesCustomerID		int,
	@ToyotaCustomerID		int,
	@VolkswagenCustomerID		int,
	@VolvoCustomerID		int,
	@VWModelCode			varchar(20),
	@SDCCustomerID			int,
	@Count				int,
	@DealerETADate			datetime,
	@DateMadeAvailable		datetime
	
	/************************************************************************
	*	spImportNSTruckerNotification					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the NSTruckNotificatonImport	*
	*	table and updates the bay location and availability of the 	*
	*	vehicles.							*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	02/05/2010 CMK    Initial version				*
	*									*
	************************************************************************/
	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @NeedsReviewInd = 0
	
	--get the honda customer id from the setting table
	SELECT @HondaCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'HondaCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Honda CustomerID'
		GOTO Error_Encountered2
	END
	IF @HondaCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Honda CustomerID Not Found'
		GOTO Error_Encountered2
	END
			
	--get the ford customer id from the setting table
	SELECT @FordCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'FordCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Ford CustomerID'
		GOTO Error_Encountered2
	END
	IF @FordCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Ford CustomerID Not Found'
		GOTO Error_Encountered2
	END
			
	--get the mercedes customer id from the setting table
	SELECT @MercedesCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'MercedesCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Mercedes CustomerID'
		GOTO Error_Encountered2
	END
	IF @MercedesCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Mercedes CustomerID Not Found'
		GOTO Error_Encountered2
	END
			
	--get the toyota customer id from the setting table
	SELECT @ToyotaCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ToyotaCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Toyota CustomerID'
		GOTO Error_Encountered2
	END
	IF @ToyotaCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Toyota CustomerID Not Found'
		GOTO Error_Encountered2
	END
			
	--get the volkswagen customer id from the setting table
	SELECT @VolkswagenCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolkswagenCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Volkswagen CustomerID'
		GOTO Error_Encountered2
	END
	IF @VolkswagenCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Volkswagen CustomerID Not Found'
		GOTO Error_Encountered2
	END
			
	--get the volvo customer id from the setting table
	SELECT @VolvoCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolvoCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Volvo CustomerID'
		GOTO Error_Encountered2
	END
	IF @VolvoCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Volvo CustomerID Not Found'
		GOTO Error_Encountered2
	END
			
	--get the SDC customer id from the setting table
	SELECT @SDCCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SDCCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SDC CustomerID'
		GOTO Error_Encountered2
	END
	IF @SDCCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'SDC CustomerID Not Found'
		GOTO Error_Encountered2
	END
			
	DECLARE NSTruckNotificationCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT NSTruckerNotificationImportID, NSRampCode, NSCustomerCode, RailcarNumber,
		ActionDate,TransmitTime, VIN, DealerCode, BayLocation, VehicleYear, Make, Model,
		Bodystyle, VehicleLength, VehicleWidth, VehicleHeight, VINDecodedInd
		FROM NSTruckerNotificationImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY NSRampCode, DealerCode, NSTruckerNotificationImportID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN NSTruckNotificationCursor

	BEGIN TRAN

	FETCH NSTruckNotificationCursor INTO @NSTruckerNotificationImportID, @NSRampCode, @NSCustomerCode, @RailcarNumber,
		@ActionDate,@TransmitTime, @VIN, @DealerCode, @BayLocation, @VehicleYear, @Make, @Model,
		@Bodystyle, @VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @RecordStatus = 'Imported'
		SELECT @ImportedInd = 1
		SELECT @ImportedDate = GetDate()
		SELECT @ImportedBy = @UserCode
		SELECT @CustomerID = NULL
		SELECT @OriginID = NULL
		SELECT @DestinationID = NULL
		SELECT @AssignedDealerInd = NULL
		SELECT @ImportError = 0
		SELECT @DealerETADate = NULL
		
		--get the customer
		SELECT @CustomerID = CONVERT(int,Value1)
		FROM Code
		WHERE CodeType = 'NSCustomerCode'
		AND Code = @NSCustomerCode
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING CUSTOMER'
			GOTO Error_Encountered
		END
		IF @CustomerID IS NULL
		BEGIN
			SELECT @ImportError = 0
			SELECT @RecordStatus = 'Customer Code '+@NSCustomerCode+' Not Found'
			GOTO Update_Record_Status
		END
		--get the Origin.
		SELECT @OriginID = CONVERT(int,Value1)
		FROM Code
		WHERE CodeType = 'NSLocationCode'
		AND Code = @NSRampCode
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
			GOTO Error_Encountered
		END
		IF @OriginID IS NULL
		BEGIN
			SELECT @ImportError = 0
			SELECT @RecordStatus = 'Orig Cd '+@NSRampCode+' Not Found'
			GOTO Update_Record_Status
		END
		IF @CustomerID IS NULL
		BEGIN
			SELECT @ImportError = 0
			SELECT @RecordStatus = 'Orig Cd '+@NSRampCode+' Not Found'
			GOTO Update_Record_Status
		END
		
		IF @DealerCode = 'H00000' OR @DealerCode = 'V00000'
		BEGIN
			SELECT @DealerCode = ''
		END
		
		IF DATALENGTH(@DealerCode) > 0
		BEGIN
			IF @CustomerID = @SDCCustomerID AND @DealerCode = '200011'
			BEGIN
				SELECT @DestinationID = CONVERT(int,ValueDescription)
				FROM SettingTable
				WHERE ValueKey = 'SOADiversifiedLocationID'
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING DAI LOCATIONID'
					GOTO Error_Encountered
				END
				SELECT @AssignedDealerInd = 0
			END
			ELSE
			BEGIN
				--get the destination
				SELECT TOP 1 @DestinationID = LocationID,
				@AssignedDealerInd = AssignedDealerInd
				FROM Location
				WHERE ParentRecordID = @CustomerID
				AND ParentRecordTable = 'Customer'
				AND CustomerLocationCode = @DealerCode
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
					GOTO Error_Encountered
				END
			END
			
			IF @AssignedDealerInd = 0 AND @CustomerID = @HondaCustomerID
			BEGIN
				SELECT @RecordStatus = 'NOT AN ASSIGNED DEALER'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record_Status
			END
			ELSE IF @DestinationID IS NULL AND @CustomerID = @HondaCustomerID
			BEGIN
				SELECT @RecordStatus = 'DESTINATION '+@DealerCode+' NOT FOUND'
				SELECT @NeedsReviewInd = 1
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record_Status
			END
			ELSE IF @DestinationID IS NULL AND @CustomerID <> @HondaCustomerID
			BEGIN
				SELECT @Count = COUNT(*)
				FROM Location
				WHERE ParentRecordID = @CustomerID
				AND ParentRecordTable = 'Customer'
				AND SPLCCode+REPLICATE('0',9-DATALENGTH(SPLCCode)) = @DealerCode+REPLICATE('0',9-DATALENGTH(@DealerCode))
				AND DATALENGTH(SPLCCode) > 0
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
					GOTO Error_Encountered
				END
				
				IF @Count = 1
				BEGIN
					--check to see if we have the splc
					SELECT TOP 1 @DestinationID = LocationID,
					@AssignedDealerInd = AssignedDealerInd
					FROM Location
					WHERE ParentRecordID = @CustomerID
					AND ParentRecordTable = 'Customer'
					AND SPLCCode+REPLICATE('0',9-DATALENGTH(SPLCCode)) = @DealerCode+REPLICATE('0',9-DATALENGTH(@DealerCode))
					AND DATALENGTH(SPLCCode) > 0
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
						GOTO Error_Encountered
					END
				END
				ELSE IF @Count > 1
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'NO DEALER MATCH, MULTIPLE SPLC MATCHES'
				END
				
				IF @DestinationID IS NULL
				BEGIN
					--NEW DESTINATION, SO CREATE A NEW LOCATION RECORD
					INSERT INTO Location(
						ParentRecordID,
						ParentRecordTable,
						LocationType,
						LocationName,
						CustomerLocationCode,
						AuctionPayOverrideInd,
						AuctionPayRate,
						FlatDeliveryPayInd,
						FlatDeliveryPayRate,
						MileagePayBoostOverrideInd,
						MileagePayBoost,
						RecordStatus,
						CreationDate,
						CreatedBy,
						DeliveryHoldInd,
						NightDropAllowedInd,
						STIAllowedInd,
						AssignedDealerInd,
						ShagPayAllowedInd,
						ShortHaulPaySchedule,
						NYBridgeAdditiveEligibleInd,
						HotDealerInd,
						DisableLoadBuildingInd,
						LocationHasInspectorsInd
					)
					VALUES(
						@CustomerID,
						'Customer',
						'DropoffLocation',
						'NEED LOCATION NAME',
						@DealerCode,
						0,
						0,
						0,
						0,
						0,
						0,
						'Active',
						GetDate(),
						'NS IMPORT',
						0,
						0,
						0,
						0,
						0,
						'A',			--ShortHaulPaySchedule,
						0,			--NYBridgeAdditiveEligibleInd
						0,			--HotDealerInd
						0,			--DisableLoadBuildingInd
						0			--LocationHasInspectorsInd
					)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR CREATING DESTINATION LOCATION'
						GOTO Error_Encountered
					END
					SELECT @DestinationID = @@Identity
				END
			END
		END
		
		IF @CustomerID = @HondaCustomerID
		BEGIN
			SELECT @SizeClass = 'A'
		END
		ELSE IF @CustomerID = @MercedesCustomerID
		BEGIN
			IF LEFT(@Model,1) = 'G'
			BEGIN
				SELECT @SizeClass = 'C'
			END
			ELSE IF LEFT(@Model,1) IN ('M','R')
			BEGIN
				SELECT @SizeClass = 'B'
			END
			ELSE
			BEGIN
				SELECT @SizeClass = 'A'
			END
			
			SELECT @DealerETADate = DATEADD(hh,MercdsETA.ETAHOURS,CONVERT(varchar(10),@ActionDate,101)+' '+SUBSTRING(@TransmitTime,1,2)+':'+SUBSTRING(@TransmitTime,3,2) )   
			FROM MercedesETA MercdsETA
			WHERE MercdsETA.OriginID = @OriginID AND MercdsETA.DestinationID = @DestinationID
		END
		ELSE IF @CustomerID = @FordCustomerID
		BEGIN
			SELECT @SizeClass = ''
						
			SELECT @VINBodyType = SUBSTRING(@VIN,7,1)
			SELECT @PlantCode = SUBSTRING(@VIN,11,1)
			SELECT @VehicleType = SUBSTRING(@VIN,12,1)
							
			IF CHARINDEX(@VehicleType,'123456789') > 0
			BEGIN
				IF @PlantCode IN ('T','1')
				BEGIN
					SELECT @SizeClass = 'B'
				END
				ELSE
				BEGIN
					SELECT @SizeClass = 'A'
				END
			END
			ELSE
			BEGIN
				IF @PlantCode IN ('D','E','K')
				BEGIN
					IF @VINBodyType IN ('U', 'X')
					BEGIN
						SELECT @SizeClass = 'D'
					END
					ELSE IF SUBSTRING(@VIN,5,2) IN ('F1','W1','X1','S6','S7','E6','E7','S8','S9','E8','E9','J1','J2','J3','J4','J5','J6','J7','J8','J9')
						AND SUBSTRING(@VIN,5,3) NOT IN ('J2H','J2J','J3H','J3J','J2K','J2L','J3K','J3L','S6P','S8P','S9P','S6Z','S8Z','S9Z') --Navigator and Transit overlaps
					BEGIN
						SELECT @SizeClass = 'B'
					END
					ELSE
					BEGIN
						SELECT @SizeClass = 'C'
					END
				END
				ELSE
				BEGIN
					SELECT @SizeClass = 'B'
				END
			END
					
		
		END
		ELSE IF @CustomerID = @ToyotaCustomerID
		BEGIN
			SELECT @SizeClass = NULL
			
			SELECT TOP 1 @SizeClass = SizeClass
			FROM Vehicle
			WHERE VIN = @VIN
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING SIZE CLASS'
				GOTO Error_Encountered
			END
			
			IF @SizeClass IS NULL
			BEGIN
				SELECT @TierRateCode = NULL
				SELECT TOP 1 @TierRateCode = TIT.TierRateCode
				FROM ToyotaImportTender TIT
				WHERE SUBSTRING(@VIN,1,8)+SUBSTRING(@VIN,10,2) = SUBSTRING(TIT.VIN,1,8)+SUBSTRING(TIT.VIN,10,2)
				AND ISNULL(TIT.TierRateCode,'') <> ''
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING TIER RATE CODE'
					GOTO Error_Encountered
				END
				
				IF @TierRateCode = '01'
				BEGIN
					SELECT @SizeClass = 'A'
				END
				ELSE IF @TierRateCode = '02'
				BEGIN
					SELECT @SizeClass = 'B'
				END
				ELSE IF @TierRateCode = '03'
				BEGIN
					SELECT @SizeClass = 'C'
				END
				ELSE IF @TierRateCode = '04'
				BEGIN
					SELECT @SizeClass = 'D'
				END
				ELSE IF @TierRateCode = '05'
				BEGIN
					SELECT @SizeClass = 'E'
				END
				ELSE
				BEGIN
					SELECT @SizeClass = ''		--will have to fix after the fact
				END
			END
		END
		ELSE IF @CustomerID = @VolkswagenCustomerID
		BEGIN
			-- also update spImportVolkswagenAvailableVehicles, spImportNORADRelease, spCSXRailheadFeedUpdate, spImportI73 and spImportI95 when adding new model codes
			SELECT @VWModelCode = LEFT(@VIN,3)+ SUBSTRING(@VIN,7,2)
			IF @VWModelCode IN ('WVG7L','WA14L','WA1FE','WVGA9','2V4D1','2V4DX','WVGBP','2C4AG','2C4BG','2C4CG','2C4DG','WA1F7','1V2CA')
			BEGIN
				SELECT @SizeClass = 'B'
			END
			ELSE
			BEGIN
				SELECT @SizeClass = 'A'
			END
		END
		ELSE IF @CustomerID = @VolvoCustomerID
		BEGIN
			IF LEFT(@Model,2) = 'XC' --STILL WAITING TO HEAR IF SIZE CLASS IS INCLUDED IN 204 FILE
			BEGIN
				SELECT @SizeClass = 'B'
			END
			ELSE
			BEGIN
				SELECT @SizeClass = 'A'
			END
		END
		ELSE
		BEGIN
			SELECT @SizeClass = 'A'
		END
		
		/* moved below destination validation
		SELECT @ChargeRate = NULL
		--From these values we can get the financial information.
		SELECT @ChargeRate = Rate
		FROM ChargeRate
		WHERE StartLocationID = @OriginID
		AND EndLocationID = @DestinationID
		AND CustomerID = @CustomerID
		AND RateType = 'Size '+@SizeClass+' Rate'
		AND @ActionDate >= StartDate
		AND @ActionDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
		*/
		
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		AND CustomerID <> @SDCCustomerID
		AND PickupLocationID = @OriginID
		--AND CustomerID = @CustomerID
		--AND VehicleStatus <> 'Delivered'
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @VINCOUNT > 0
		BEGIN
			--see if there are any changes to the origin/destination
			SELECT TOP 1 @VehicleID = V.VehicleID,
			@VehicleCustomerID = V.CustomerID,
			@VehicleOriginID = V.PickupLocationID,
			@VehicleDestinationID = V.DropoffLocationID,
			@VehicleSizeClass = V.SizeClass,
			@VehicleLoadID = L.LoadID,
			@VehiclePoolID = L.PoolID,
			@OldLegStatus = LegStatus,
			@VehicleChargeRate = ChargeRate
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.LegNumber = 1
			WHERE V.VIN = @VIN
			AND CustomerID <> @SDCCustomerID
			AND V.PickupLocationID = @OriginID
			--AND V.CustomerID = @CustomerID
			ORDER BY V.VehicleID DESC	--want the most recent vehicle if multiples
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
				GOTO Error_Encountered
			END
						
			
			--SEE IF THERE IS AN EXISTING OPEN RailVehicleCreatedLog RECORD FOR THIS VEHICLE
			SELECT  @Count = COUNT(*)
			FROM RailVehicleCreatedLog
			WHERE VehicleID = @VehicleID
			AND ActionTaken = 'Open'
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE COUNT'
				GOTO Error_Encountered
			END
							
			IF @Count > 0
			BEGIN
				UPDATE Vehicle
				SET RailcarNumber = @RailcarNumber,
				BayLocation = @BayLocation,
				UpdatedBy = 'NS IMPORT',
				UpdatedDate = GetDate(),
				DateMadeAvailable = ISNULL(DateMadeAvailable,CONVERT(varchar(10),@ActionDate,101)+' '+SUBSTRING(@TransmitTime,1,2)+':'+SUBSTRING(@TransmitTime,3,2))
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
				SELECT @NeedsReviewInd = 1
				SELECT @ImportedInd = 1
				SELECT @RecordStatus = 'Open Rail Vehicle Created Record, Bay Updated'
				GOTO Update_Record_Status
			END
			
			IF @Bodystyle LIKE '%Hellcat%'
			BEGIN
				--TEMP CODE FOR HELLCAT UNITS NEEDING INSPECTION BEFORE SHIPPING
				UPDATE Vehicle
				SET RailcarNumber = @RailcarNumber,
				BayLocation = @BayLocation,
				UpdatedBy = 'NS IMPORT',
				UpdatedDate = GetDate()
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
											
				SELECT @Count = COUNT(*)
				FROM RailVehicleCreatedLog
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING VEHICLE COUNT'
					GOTO Error_Encountered
				END
							
				IF @Count = 0
				BEGIN
					--write to the RailVehicleCreatedLog
					INSERT INTO RailVehicleCreatedLog(
						CustomerID,
						VehicleID,
						RailCompany,
						VIN,
						OriginCode,
						DestinationCode,
						ActionTaken,
						CreationDate,
						CreatedBy
					)
					VALUES(
						@CustomerID,	--CustomerID,
						@VehicleID,	--VehicleID,
						'NS',		--RailCompany,
						@VIN,		--VIN,
						@NSRampCode,	--OriginCode,
						@DealerCode,	--DestinationCode,
						'Open',		--ActionTaken,
						GetDate(),	--CreationDate,
						'NS IMPORT'	--CreatedBy
					)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR CREATING LOG RECORD'
						GOTO Error_Encountered
					END
				END
							
				SELECT @NeedsReviewInd = 1
				SELECT @ImportedInd = 1
				SELECT @RecordStatus = 'Hellcat Unit Pending Inspection, Bay Location Updated'
				GOTO Update_Record_Status
			END
			
			--receiving bad headers, want to validate customer
			IF @VehicleCustomerID <> @CustomerID
			BEGIN
				SELECT @CustomerID = @VehicleCustomerID
				SELECT @OriginID = @VehicleOriginID
				SELECT @DestinationID = @VehicleDestinationID
				SELECT @SizeClass = @VehicleSizeClass
				SELECT @ChargeRate = @VehicleChargeRate
			END
			
			--if destination id not found still want to update vehicle
			IF @DestinationID IS NULL
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'CHECK DESTINATION, DEALER CODE '+@DealerCode+' NOT FOUND'
				SELECT @DestinationID = @VehicleDestinationID
				SELECT @ChargeRate = @VehicleChargeRate
			END
			ELSE IF DATALENGTH(@DealerCode) < 1
			BEGIN
				--if no dealer code passed in, set the origin id
				SELECT @DestinationID = @VehicleDestinationID
				SELECT @ChargeRate = @VehicleChargeRate
			END
			
			-- check the origin/destination/allocation number
			IF @OriginID = @VehicleOriginID 
				AND @DestinationID = @VehicleDestinationID
			BEGIN
				IF @OldLegStatus IN ('Complete','EnRoute')
				BEGIN
					SELECT @RecordStatus = 'ALREADY ENROUTE'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record_Status
				END
				ELSE IF @OldLegStatus = 'Delivered'
				BEGIN
					SELECT @RecordStatus = 'ALREADY DELIVERED'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record_Status
				END
			END
						
			IF @OldLegStatus <> 'Pending' --IN ('OnHold','PendingRepair')
			BEGIN
				UPDATE Vehicle
				SET RailcarNumber = @RailcarNumber,
				BayLocation = @BayLocation,
				UpdatedBy = 'NS IMPORT',
				UpdatedDate = GetDate()
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
				SELECT @RecordStatus = 'VEHICLE IS NOT PENDING'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record_Status
			END
			
			SELECT @AvailableForPickupDate = @ActionDate
			SELECT @LegStatus = 'Available'
			SELECT @VehicleStatus = 'Available'
			SELECT @DateMadeAvailable = CONVERT(varchar(10),@ActionDate,101)+' '+SUBSTRING(@TransmitTime,1,2)+':'+SUBSTRING(@TransmitTime,3,2)
			
			IF @OriginID <> @VehicleOriginID AND @DestinationID <> @VehicleDestinationID
			BEGIN
				IF @OldLegStatus IN ('Complete','EnRoute')
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'DEST. MISMATCH - ENROUTE'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record_Status
				END
				ELSE IF @OldLegStatus = 'Delivered'
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'DEST. MISMATCH - DELIVERED'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record_Status
				END
				ELSE IF @CustomerID = @FordCustomerID
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'DESTINATION MISMATCH'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record_Status
				END
				ELSE IF @VehicleLoadID IS NOT NULL
				BEGIN
					UPDATE Legs
					SET LoadID = NULL
					WHERE LoadID = @VehicleLoadID
					AND VehicleID = @VehicleID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING LEG RECORD'
						GOTO Error_Encountered
					END
							
					UPDATE Loads
					SET LoadSize = LoadSize - 1
					WHERE LoadsID = @VehicleLoadID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING LOAD RECORD'
						GOTO Error_Encountered
					END
									
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'ORIGIN & DEST CHANGED - REMOVED FROM LOAD'
							
				END
				ELSE
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'ORIGIN & DEST CHANGED'
				END
			END
			ELSE IF @OriginID <> @VehicleOriginID
			BEGIN
				-- first two cases should not happen, adding just to be safe
				IF @OldLegStatus IN ('Complete','EnRoute')
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'ORIGIN MISMATCH - ENROUTE'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record_Status
				END
				ELSE IF @OldLegStatus = 'Delivered'
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'ORIGIN MISMATCH - DELIVERED'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record_Status
				END
				ELSE IF @VehicleLoadID IS NOT NULL
				BEGIN
					UPDATE Legs
					SET LoadID = NULL
					WHERE LoadID = @VehicleLoadID
					AND VehicleID = @VehicleID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING LEG RECORD'
						GOTO Error_Encountered
					END
								
					UPDATE Loads
					SET LoadSize = LoadSize - 1
					WHERE LoadsID = @VehicleLoadID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING LOAD RECORD'
						GOTO Error_Encountered
					END
									
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'ORIGIN CHANGED - REMOVED FROM LOAD'
				END
				ELSE
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'ORIGIN CHANGED'
				END
			END
			ELSE IF @DestinationID <> @VehicleDestinationID
			BEGIN
				IF @OldLegStatus IN ('Complete','EnRoute')
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'DEST. MISMATCH - ENROUTE'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record_Status
				END
				ELSE IF @OldLegStatus = 'Delivered'
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'DEST. MISMATCH - DELIVERED'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record_Status
				END
				/*
				ELSE IF @CustomerID = @FordCustomerID
				BEGIN
					SELECT @RecordStatus = 'CHECK DESTINATION'
					SELECT @DestinationID = @VehicleDestinationID
					--SELECT @ImportedInd = 0
					--SELECT @ImportedDate = NULL
					--SELECT @ImportedBy = NULL
					--GOTO Update_Record_Status
				END
				*/
				ELSE IF @VehicleLoadID IS NOT NULL
				BEGIN
					UPDATE Legs
					SET LoadID = NULL
					WHERE LoadID = @VehicleLoadID
					AND VehicleID = @VehicleID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING LEG RECORD'
						GOTO Error_Encountered
					END
									
					UPDATE Loads
					SET LoadSize = LoadSize - 1
					WHERE LoadsID = @VehicleLoadID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING LOAD RECORD'
						GOTO Error_Encountered
					END
									
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'CHECK DESTINATION - REMOVED FROM LOAD'
					SELECT @DestinationID = @VehicleDestinationID
				END
				ELSE
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'CHECK DESTINATION'
					SELECT @DestinationID = @VehicleDestinationID
				END
			END
			
			SELECT @ChargeRate = NULL
			--From these values we can get the financial information.
			SELECT @ChargeRate = Rate
			FROM ChargeRate
			WHERE StartLocationID = @OriginID
			AND EndLocationID = @DestinationID
			AND CustomerID = @CustomerID
			AND RateType = 'Size '+@SizeClass+' Rate'
			AND @ActionDate >= StartDate
			AND @ActionDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
			
			--update logic here.
			IF @CustomerID = @ToyotaCustomerID
			BEGIN
				--toyotas are not automatically available
				UPDATE Vehicle
				SET PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				BayLocation = @BayLocation,
				RailcarNumber = @RailcarNumber,
				ChargeRate = @ChargeRate
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
			END
			ELSE IF  @CustomerID = @MercedesCustomerID
			BEGIN
				UPDATE Vehicle
				SET PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				BayLocation = @BayLocation,
				RailcarNumber = @RailcarNumber,
				ChargeRate = @ChargeRate,
				AvailableForPickupDate = @AvailableForPickupDate,
				VehicleStatus = @VehicleStatus,
				DealerETADate= @DealerETADate,
				DateMadeAvailable = ISNULL(DateMadeAvailable,@DateMadeAvailable)
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
			END
			ELSE
			BEGIN
				UPDATE Vehicle
				SET PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				BayLocation = @BayLocation,
				RailcarNumber = @RailcarNumber,
				ChargeRate = @ChargeRate,
				AvailableForPickupDate = @AvailableForPickupDate,
				VehicleStatus = @VehicleStatus,
				DateMadeAvailable = ISNULL(DateMadeAvailable,@DateMadeAvailable)
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
			END
			
			--update any legs records
			SELECT @LegsCount = 0
			SELECT @LegsCount = COUNT(*)
			FROM Legs
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting Legs count'
				GOTO Error_Encountered
			END
			
			IF @CustomerID = @ToyotaCustomerID
			BEGIN
				--have legs, so update them
				UPDATE Legs
				SET PickupLocationID = @OriginID
				WHERE VehicleID = @VehicleID
				AND LegNumber = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error updating starting leg'
					GOTO Error_Encountered
				END
				
				UPDATE Legs
				SET DropoffLocationID = @DestinationID
				WHERE VehicleID = @VehicleID
				AND FinalLegInd = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error updating ending leg'
					GOTO Error_Encountered
				END
			END
			ELSE
			BEGIN
				--have legs, so update them
				UPDATE Legs
				SET PickupLocationID = @OriginID,
				LegStatus = @LegStatus,
				DateAvailable = @AvailableForPickupDate
				WHERE VehicleID = @VehicleID
				AND LegNumber = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error updating starting leg'
					GOTO Error_Encountered
				END
				
				UPDATE Legs
				SET DropoffLocationID = @DestinationID
				WHERE VehicleID = @VehicleID
				AND FinalLegInd = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error updating ending leg'
					GOTO Error_Encountered
				END
				
				IF @VehiclePoolID IS NOT NULL
				BEGIN
					UPDATE VehiclePool
					SET PoolSize = PoolSize - 1,
					Available = Available - 1
					WHERE VehiclePoolID = @VehiclePoolID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING OLD POOL'
						GOTO Error_Encountered
					END
				END
							
				SELECT @PoolRecordCount = 0
				SELECT @PoolRecordCount = Count(*)
				FROM VehiclePool
				WHERE CustomerID = @CustomerID
				AND OriginID = @OriginID
				AND DestinationID = @DestinationID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING POOL RECORD COUNT'
					GOTO Error_Encountered
				END
				IF @PoolRecordCount = 0	
				BEGIN
					--don't have pool, so add one
					INSERT INTO VehiclePool(
						OriginID,
						DestinationID,
						CustomerID,
						PoolSize,
						Reserved,
						Available,
						CreationDate,
						CreatedBy
					)
					VALUES(
						@OriginID,
						@DestinationID,
						@CustomerID,
						0,		--PoolSize
						0,		--Reserved
						0,		--Available
						GetDate(),	--CreationDate
						'NS IMPORT'	--CreatedBy
					)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR CREATING POOL RECORD'
						GOTO Error_Encountered
					END
					SELECT @PoolID = @@Identity
					SELECT @Reserved = 0
					SELECT @Available = 0
					SELECT @PoolSize = 0
				END
				ELSE
				BEGIN
					SELECT @PoolID = VehiclePoolID,
					@PoolSize = PoolSize,
					@Reserved = Reserved,
					@Available = Available
					FROM VehiclePool
					WHERE CustomerID = @CustomerID
					AND OriginID = @OriginID
					AND DestinationID = @DestinationID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING POOL ID'
						GOTO Error_Encountered
					END
				END
				--add one to the pool
				UPDATE VehiclePool
				SET PoolSize = PoolSize + 1,
				Available = Available + 1
				WHERE VehiclePoolID = @PoolID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING POOL RECORD'
					GOTO Error_Encountered
				END
				
				UPDATE Legs
				SET PoolID = @PoolID
				WHERE VehicleID = @VehicleID
				AND LegNumber = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error updating starting leg'
					GOTO Error_Encountered
				END
			END
		END	
		ELSE
		BEGIN
			IF DATALENGTH(@DealerCode) < 1
			BEGIN
				SELECT @RecordStatus = 'NO DEALER CODE OR ASN'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record_Status	
			END
			IF @DestinationID IS NULL
			BEGIN
				SELECT @RecordStatus = 'DESTINATION '+@DealerCode+' NOT FOUND'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record_Status
			END
			
			SELECT @ChargeRate = NULL
			--From these values we can get the financial information.
			SELECT @ChargeRate = Rate
			FROM ChargeRate
			WHERE StartLocationID = @OriginID
			AND EndLocationID = @DestinationID
			AND CustomerID = @CustomerID
			AND RateType = 'Size '+@SizeClass+' Rate'
			AND @ActionDate >= StartDate
			AND @ActionDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
		
			--only insert an order record for the ones with different origin and destination values
			IF @OriginID <> @PreviousOrigin OR @DestinationID <> @PreviousDestination
			BEGIN

				--if @orderid is not null, then save the totals off to the order before creating the new one
				IF @OrderID IS NOT NULL
				BEGIN
					UPDATE Orders
					SET Units = @TotalOrderUnits,
					OrderChargeRate = @TotalOrderChargeRate
					WHERE OrdersID = @OrderID
				END
				SELECT @TotalOrderUnits = 0
				SELECT @TotalOrderChargeRate = 0
				--get the next available order number from the app constants table.
				Select @OrderNumber = NextOrderNumber from ApplicationConstants

				--add one to it, so it can be updated.
				Select @OrderNumberPlusOne = @OrderNumber + 1			

				--now update the app constants table with the number + 1
				UPDATE ApplicationConstants
				Set NextOrderNumber = @OrderNumberPlusOne
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING Application Constants'
					GOTO Error_Encountered
				END
				--logic for the insert of orders and vehicle
				INSERT ORDERS(
					CustomerID,
					OrderNumber,
					LoadType,
					CustomerChargeType,
					CarrierType,
					OutsideCarrierID,
					PricingInd,
					FixedChargeRateOverrideInd,
					FixedChargeRate,
					MileageChargeRateOverrideInd,
					MileageChargeRate,
					PerUnitChargeRate,
					OrderChargeRate,
					RequestedPickupDate,
					RequestedDeliveryDate,
					PickupLocation,
					DropoffLocation,
					Units,
					Mileage,
					SalespersonID,
					OutsideCarrierPaymentMethod,
					OutsideCarrierPercentage,
					OutsideCarrierPctOverrideInd,
					OutsideCarrierPay,
					PaymentMethod,
					InternalComment,
					DriverComment,
					PONumber,
					OrderStatus,
					CreationDate,
					CreatedBy,
					UpdatedDate,
					UpdatedBy
				)
				VALUES(
					@CustomerID,
					@OrderNumber,
					0,		--LoadType,
					0,		--CustomerChargeType,
					0,		--CarrierType,
					NULL,		--OutsideCarrierID,
					0,		--PricingInd,
					0,		--FixedChargeRateOverrideInd,
					0,		--FixedChargeRate,
					0,		--MileageChargeRateOverrideInd,
					0,		--MileageChargeRate,
					0,		--PerUnitChargeRate,
					0,		--OrderChargeRate,
					NULL,		--RequestedPickupDate,
					NULL,		--RequestedDeliveryDate,
					@OriginID,	--PickupLocation,
					@DestinationID,	--DropoffLocation,
					0,		--Units,
					0,		--Mileage,
					NULL,		--SalespersonID,
					0,		--OutsideCarrierPaymentMethod,
					0,		--OutsideCarrierPercentage,
					0,		--OutsideCarrierPctOverrideInd,
					0,		--OutsideCarrierPay,
					'Bill To Customer',	--PaymentMethod,
					NULL,		--InternalComment,
					NULL,		--DriverComment,
					NULL,		--PONumber,
					'Pending',	--OrderStatus,
					GetDate(),	--CreationDate,
					'NS IMPORT',	--CreatedBy,
					NULL,		--UpdatedDate,
					NULL		--UpdatedBy
				)

				--need to get the orderId key here, to insert into the vehicle record.			
				SELECT @OrderID = @@identity
			END

			--and now do the vehicle
			IF ISNULL(@VehicleYear,'') = ''
			BEGIN
				SELECT @VehicleYear = ''
			END
			IF ISNULL(@Make,'') = ''
			BEGIN
				IF @NSCustomerCode = 'FO'
				BEGIN
					SELECT @Make = 'Ford'
				END
				ELSE IF @NSCustomerCode = 'HN'
				BEGIN
					SELECT @Make = 'Honda'
				END
				ELSE IF @NSCustomerCode = 'MR'
				BEGIN
					SELECT @Make = 'Mercedes'
				END
				ELSE IF @NSCustomerCode = 'SU'
				BEGIN
					SELECT @Make = 'Subaru'
				END
				ELSE IF @NSCustomerCode = 'TO'
				BEGIN
					SELECT @Make = 'Toyota'
				END
				ELSE IF @NSCustomerCode = 'VO'
				BEGIN
					SELECT @Make = 'Volvo'
				END
				ELSE IF @NSCustomerCode = 'VW'
				BEGIN
					SELECT @Make = 'Volkswagen'
				END
			END
			IF ISNULL(@Model,'') = ''
			BEGIN
				SELECT @Model = ''
			END
			IF ISNULL(@Bodystyle,'') = ''
			BEGIN
				SELECT @Bodystyle = ''
			END
			IF ISNULL(@VehicleLength,'') = ''
			BEGIN
				SELECT @VehicleLength = ''
			END
			IF ISNULL(@VehicleWidth,'') = ''
			BEGIN
				SELECT @VehicleWidth = ''
			END
			IF ISNULL(@VehicleHeight,'') = ''
			BEGIN
				SELECT @VehicleHeight = ''
			END
			IF ISNULL(@VINDecodedInd,0) = 0
			BEGIN
				SELECT @VINDecodedInd = 0
			END
			/*
			IF @CustomerID = @ToyotaCustomerID
			BEGIN
				SELECT @AvailableForPickupDate = NULL
				SELECT @VehicleStatus = 'Pending'
				SELECT @LegStatus = 'Pending'
			END
			ELSE
			BEGIN
				SELECT @AvailableForPickupDate = @ActionDate
				SELECT @VehicleStatus = 'Available'
				SELECT @LegStatus = 'Available'
			END
			*/			
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
				FinalShipawayInspectionDoneInd,
				DealerETADate
			)
			VALUES(
				@CustomerID,			--CustomerID,
				@OrderID,			--OrderID,
				@VehicleYear,			--VehicleYear,
				@Make,				--Make,
				@Model,				--Model,
				@Bodystyle,			--Bodystyle,
				@VIN,				--VIN,
				NULL,				--Color,
				@VehicleLength,			--VehicleLength
				@VehicleWidth,			--VehicleWidth
				@VehicleHeight,			--VehicleHeight
				@OriginID,			--PickupLocationID,
				@DestinationID,			--DropoffLocationID,
				'Pending',			--VehicleStatus,
				'Pickup Point',			--VehicleLocation,
				NULL,				--CustomerIdentification,
				@SizeClass,			--SizeClass,
				@BayLocation,			--BayLocation,
				@RailcarNumber,			--RailCarNumber,
				0,				--PriorityInd
				NULL,				--HaulType,
				NULL,				--AvailableForPickupDate,
				0,				--ShopWorkStartedInd,
				NULL,				--ShopWorkStartedDate,
				0,				--ShopWorkCompleteInd,
				NULL,				--ShopWorkCompleteDate,
				NULL,				--PaperworkReceivedDate,
				NULL,				--ICLAuditCode,
				@ChargeRate,			--ChargeRate
				0,				--ChargeRateOverrideInd
				0,				--BilledInd
				NULL,				--DateBilled
				@VINDecodedInd,			--VINDecodedInd
				'Active',			--RecordStatus,
				GetDate(),			--CreationDate
				'NS IMPORT',			--CreatedBy
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
				0,				--FinalShipawayInspectionDoneInd
				@DealerETADate
			)
			IF @@Error <> 0
				BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR CREATING VEHICLE RECORD'
				GOTO Error_Encountered
			END

			SELECT @VehicleID = @@Identity
			SELECT @TotalOrderUnits = @TotalOrderUnits + 1
			SELECT @TotalOrderChargeRate = @TotalOrderChargeRate + @ChargeRate

			--need to save off the previous destination and orign.
			--get the destination.
			SELECT @PreviousDestination = @DestinationID

			--get the Origin.
			SELECT @PreviousOrigin = @OriginID
			/* -- 3/29/2012 - CMK - all created units are now pending
			IF @CustomerID = @ToyotaCustomerID
			BEGIN
				SELECT @PoolID = NULL
			END
			ELSE
			BEGIN
				--get the poolid
				SELECT @PoolRecordCount = 0
				SELECT @PoolRecordCount = Count(*)
				FROM VehiclePool
				WHERE CustomerID = @CustomerID
				AND OriginID = @OriginID
				AND DestinationID = @DestinationID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING POOL RECORD COUNT'
					GOTO Error_Encountered
				END
				IF @PoolRecordCount = 0	
				BEGIN
					--don't have pool, so add one
					INSERT INTO VehiclePool(
						OriginID,
						DestinationID,
						CustomerID,
						PoolSize,
						Reserved,
						Available,
						CreationDate,
						CreatedBy
					)
					VALUES(
						@OriginID,
						@DestinationID,
						@CustomerID,
						0,		--PoolSize
						0,		--Reserved
						0,		--Available
						GetDate(),	--CreationDate
						'NS IMPORT'	--CreatedBy
					)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR CREATING POOL RECORD'
						GOTO Error_Encountered
					END
					SELECT @PoolID = @@Identity
					SELECT @Reserved = 0
					SELECT @Available = 0
					SELECT @PoolSize = 0
				END
				ELSE
				BEGIN
					SELECT @PoolID = VehiclePoolID,
					@PoolSize = PoolSize,
					@Reserved = Reserved,
					@Available = Available
					FROM VehiclePool
					WHERE CustomerID = @CustomerID
					AND OriginID = @OriginID
					AND DestinationID = @DestinationID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING POOL ID'
						GOTO Error_Encountered
					END
				END
				--add one to the pool
				UPDATE VehiclePool
				SET PoolSize = PoolSize + 1,
				Available = Available + 1
				WHERE VehiclePoolID = @PoolID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING POOL RECORD'
					GOTO Error_Encountered
				END
			END
			*/
			-- now create the Legs record for the vehicle
			INSERT INTO Legs(
				VehicleID,
				PoolID,
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
				CreationDate,
				CreatedBy,
				OutsideCarrierFuelSurchargeType
			)
			VALUES(
				@VehicleID,
				NULL,
				NULL,
				@OriginID,
				@DestinationID,
				0, 		--OutsideCarrierLegInd
				0, 		--OutsideCarrierPaymentMethod
				0, 		--OutsideCarrierPercentage
				0, 		--OutsideCarrierPay
				0,		--OutsideCarrierFuelSurchargePercentage
				0,		--OCFSPEstablishedInd
				1, 		--LegNumber
				1, 		--FinalLegInd
				'Pending',	--LegStatus
				0,
				GetDate(), 	--CreationDate
				'NS IMPORT', 	--CreatedBy
				0		--OutsideCarrierFuelSurchargeType
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR CREATING DEFAULT LEG'
				GOTO Error_Encountered
			END
			--write to the RailVehicleCreatedLog
			INSERT INTO RailVehicleCreatedLog(
				CustomerID,
				VehicleID,
				RailCompany,
				VIN,
				OriginCode,
				DestinationCode,
				ActionTaken,
				CreationDate,
				CreatedBy
			)
			VALUES(
				@CustomerID,	--CustomerID,
				@VehicleID,	--VehicleID,
				'NS',		--RailCompany,
				@VIN,		--VIN,
				@NSRampCode,	--OriginCode,
				@DealerCode,	--DestinationCode,
				'Open',		--ActionTaken,
				GetDate(),	--CreationDate,
				'NS IMPORT'	--CreatedBy
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR CREATING LOG RECORD'
				GOTO Error_Encountered
			END
			IF @RecordStatus = 'Imported'
			BEGIN
				SELECT @RecordStatus = 'VEHICLE CREATED'
			END
		END

		--update logic here.
		Update_Record_Status:
		UPDATE NSTruckerNotificationImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy,
		CustomerID = @CustomerID
		WHERE NSTruckerNotificationImportID = @NSTruckerNotificationImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END
		
		FETCH NSTruckNotificationCursor INTO @NSTruckerNotificationImportID, @NSRampCode, @NSCustomerCode, @RailcarNumber,
			@ActionDate,@TransmitTime,@VIN, @DealerCode, @BayLocation, @VehicleYear, @Make, @Model,
			@Bodystyle, @VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd

	END --end of loop

	--save off the totals for the last order
	IF @OrderID IS NOT NULL
	BEGIN
		UPDATE Orders
		SET Units = @TotalOrderUnits,
		OrderChargeRate = @TotalOrderChargeRate
		WHERE OrdersID = @OrderID
	END

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE NSTruckNotificationCursor
		DEALLOCATE NSTruckNotificationCursor
		PRINT 'NS Trucker Notification Import Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE NSTruckNotificationCursor
		DEALLOCATE NSTruckNotificationCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'NS Trucker Notification Import Error_Encountered =' + STR(@ErrorID)
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @NeedsReviewInd AS NeedsReviewInd
	
	RETURN
END
GO
