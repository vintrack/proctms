USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportI73]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportI73] (@BatchID int, @CustomerCode varchar(20),
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@ErrorEncountered	varchar(5000),
	@loopcounter		int,
	@ImportI73ID		int,
	@VIN			varchar(17),
	@AllocationDealer	varchar(7),
	@DropShipFlag		varchar(1),
	@RailVendor		varchar(5),
	@RailRamp		varchar(5),
	@PortReleaseDate	varchar(50),
	@ExteriorColorCode	varchar(4),
	@USPortofEntry		varchar(5),
	@DealerAllocationNumber	varchar(12),
	@RouteCode		varchar(20),
	@Header			varchar(20),
	@VINCOUNT		int,
	@DestinationID		int,
	@OriginID		int,
	@ChargeRate		decimal(19,2),
	@CustomerID		int,
	@OrderID		int,
	@PreviousOrigin		int,
	@PreviousDestination	int,
	@OrderNumber		int,
	@Status			varchar(50),
	@OrderNumberPlusOne	int,
	@VehicleID		int,
	@ReturnCode		int,
	@ReturnMessage		varchar(100),
	@NeedsReviewInd		int,
	@TotalOrderUnits	int,
	@TotalOrderChargeRate	decimal(19,2),
	@LegsCount		int,
	@VehicleYear		varchar(6), 
	@Make			varchar(50), 
	@Model			varchar(50),
	@Bodystyle		varchar(50),
	@VehicleLength		varchar(10),
	@VehicleWidth		varchar(10),
	@VehicleHeight		varchar(10),
	@VINDecodedInd		int,
	@LocationCode		varchar(10),
	@AvailableInd		int,
	@AvailableForPickupDate	datetime,
	@LegStatus		varchar(20),
	@OldLegStatus		varchar(20),
	@PoolRecordCount	int,
	@LoadID			int,
	@VehicleDestinationID	int,
	@VehicleLoadID		int,
	@VehiclePoolID		int,
	@PoolID			int,
	@Reserved		int,
	@Available		int,
	@PoolSize		int,
	@VehicleOriginID	int,
	--@VehicleDestinationID	int,
	@CreationDate		datetime,
	@DateAvailable		datetime,
	@CustomerIdentification	varchar(20),
	@VWModelCode		varchar(20),
	@Count			int,
	@VehicleStatus		varchar	(20),
	@RecordStatus		varchar(100),
	@ImportedInd		int,
	@ImportedDate		datetime,
	@ImportedBy		varchar(20),
	@VolkswagenCustomerID	int,
	@SizeClass		varchar(10),
	@DateMadeAvailable	datetime

	/************************************************************************
	*	spImportI73							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ImportI73 table and 	*
	*	creates the new orders and vehicle records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/20/2004 CMK    Initial version				*
	*	11/10/2004 CMK    Moved ShagUnitInd from Vehicle to Leg		*
	*	08/19/2005 CMK    Added lookup for vehicle record added by phone*
	*	12/02/2005 CMK    Changed VIN found code to update status and 	*
	*	                  not update any vehicle, leg or pool records	*
	*									*
	************************************************************************/
	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @NeedsReviewInd = 0
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,Value1)
	FROM Code
	WHERE CodeType = 'ICLCustomerCode'
	AND Code = @CustomerCode
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
	
	DECLARE ImportI73 CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT ImportI73ID, VIN, AllocationDealer, DropShipFlag, RailVendor, RailRamp, PortReleaseDate, 
		ExteriorColorCode, USPortofEntry, DealerAllocationNumber, RouteCode, Header,
		VehicleYear, Make, Model, Bodystyle, VehicleLength, VehicleWidth,
		VehicleHeight, VINDecodedInd
		FROM ImportI73
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		AND Header = @CustomerCode
		ORDER BY RailVendor, AllocationDealer

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ImportI73

	BEGIN TRAN

	FETCH ImportI73 into @ImportI73ID, @VIN, @AllocationDealer, @DropShipFlag, @RailVendor, @RailRamp,
		@PortReleaseDate, @ExteriorColorCode, @USPortofEntry, @DealerAllocationNumber,
		@RouteCode, @Header,
		@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
		@VehicleHeight, @VINDecodedInd

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		PRINT 'Inside the while loop first time through'

		SELECT @DestinationID = NULL
		SELECT @OriginID = NULL

		--get the destination.
		SELECT @DestinationID = LocationID
		FROM Location
		WHERE ParentRecordID = @CustomerID
		AND ParentRecordTable = 'Customer'
		AND CustomerLocationCode = @AllocationDealer
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
			GOTO Error_Encountered
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
				@AllocationDealer,
				0,
				0,
				0,
				0,
				0,
				0,
				'Active',
				GetDate(),
				'IMPORT',
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

		--get the Origin.

		/*
		SELECT @OriginID = LocationID
		FROM Location
		WHERE ParentRecordID = @CustomerID
		AND ParentRecordTable = 'Customer'
		AND CustomerLocationCode = @RailRamp
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
			GOTO Error_Encountered
		END
		*/
		IF DATALENGTH(@RailRamp)>0
		BEGIN
			SELECT @LocationCode = @RailRamp
		END
		ELSE IF DATALENGTH(@USPortofEntry)>0
		BEGIN
			SELECT @LocationCode = @USPortofEntry
		END
		ELSE
		BEGIN
			print 'ramp and port empty'
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING ORIGIN LOCATION RailRamp and PortOfEntry Blank'
			GOTO Error_Encountered
		END
		--print '@LocationCode ='+@LocationCode
		SELECT @OriginID = convert(int,value1),
		@AvailableInd = CONVERT(int,ISNULL(Value2,'0'))
		FROM Code
		WHERE CodeType = 'ICL'+@CustomerCode+'LocationCode'
		AND Code = @LocationCode
		IF @@Error <> 0
		BEGIN
			print 'in origin error'
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
			GOTO Error_Encountered
		END

		IF @OriginID IS NULL
		BEGIN
			--NEW ORIGIN, SO CREATE A NEW LOCATION RECORD
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
				'PickupLocation',
				'NEED LOCATION NAME',
				@RailRamp,
				0,
				0,
				0,
				0,
				0,
				0,
				'Active',
				GetDate(),
				'IMPORT',
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
				SELECT @Status = 'ERROR CREATING ORIGIN LOCATION'
				GOTO Error_Encountered
			END
			SELECT @OriginID = @@Identity
		END

		IF @CustomerID = @VolkswagenCustomerID --vw is only icl customer with B rate
		BEGIN
			-- also update spImportVolkswagenAvailableVehicles, spImportI95, spImportNSTrukerNotification, spCSXRailheadFeedUpdate and spImportNORADRelease when adding new model codes
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
		ELSE
		BEGIN
			SELECT @SizeClass = 'A'
		END
		
		SELECT @ChargeRate = NULL
		--From these values we can get the financial information.
		--Need to add logic to check size class. not in this particular file.
		SELECT @ChargeRate = Rate
		FROM ChargeRate
		WHERE StartLocationID = @OriginID
		AND EndLocationID = @DestinationID
		AND CustomerID = @CustomerID
		AND RateType = 'Size '+@SizeClass+' Rate'
		AND @CreationDate >= StartDate
		AND @CreationDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
		
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		AND CustomerID = @CustomerID
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
			@VehicleOriginID = V.PickupLocationID,
			@VehicleDestinationID = V.DropoffLocationID,
			@CustomerIdentification = V.CustomerIdentification,
			@VehicleLoadID = L.LoadID,
			@VehiclePoolID = L.PoolID,
			@OldLegStatus = LegStatus
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.LegNumber = 1
			WHERE V.VIN = @VIN
			AND V.CustomerID = @CustomerID
			ORDER BY V.VehicleID DESC	--want the most recent vehicle if multiples
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
				GOTO Error_Encountered
			END
			
			--start of latest mods
			-- check the origin/destination/allocation number
			IF @OriginID = @VehicleOriginID 
				AND @DestinationID = @VehicleDestinationID
				AND @CustomerIdentification = @DealerAllocationNumber
			BEGIN
				IF @OldLegStatus IN ('Complete','EnRoute')
				BEGIN
					SELECT @RecordStatus = 'ALREADY ENROUTE'
				END
				ELSE IF @OldLegStatus = 'Delivered'
				BEGIN
					SELECT @RecordStatus = 'ALREADY DELIVERED'
				END
				ELSE
				BEGIN
					SELECT @RecordStatus = 'VIN ALREADY EXISTS'
				END
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record_Status
			END
			
			-- if we are seeing the vehicle again, want to see if it should be available or not
			SELECT @AvailableForPickupDate = NULL
			
			SELECT @Count = COUNT(*)
			FROM CSXRailheadFeedImport
			WHERE VIN = @VIN
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING CSX COUNT'
				GOTO Error_Encountered
			END
			
			IF @Count > 0
			BEGIN
				SELECT TOP 1 @AvailableForPickupDate = UnloadDate
				FROM CSXRailheadFeedImport
				WHERE VIN = @VIN
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING CSX COUNT'
					GOTO Error_Encountered
				END
			END
			
			IF @AvailableForPickupDate IS NULL -- next check the i07 table
			BEGIN
				SELECT @Count = COUNT(*)
				FROM ImportI07
				WHERE VIN = @VIN
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING CSX COUNT'
					GOTO Error_Encountered
				END
				
				IF @Count > 0
				BEGIN
					SELECT TOP 1 @AvailableForPickupDate = TenderDate
					FROM ImportI07
					WHERE VIN = @VIN
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING CSX COUNT'
						GOTO Error_Encountered
					END
				END
			END
			
			IF @AvailableForPickupDate IS NULL -- next check the ns trucker notification import table
			BEGIN
				SELECT @Count = COUNT(*)
				FROM NSTruckerNotificationImport
				WHERE VIN = @VIN
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING NS TRUCKER NOTIFICATION COUNT'
					GOTO Error_Encountered
				END
				
				IF @Count > 0
				BEGIN
					SELECT TOP 1 @AvailableForPickupDate = ActionDate
					FROM NSTruckerNotificationImport
					WHERE VIN = @VIN
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING NS TRUCKER NOTIFICATION COUNT'
						GOTO Error_Encountered
					END
				END
			END
			
			IF @AvailableForPickupDate IS NULL
			BEGIN
				SELECT @LegStatus = 'Pending'
				SELECT @VehicleStatus = 'Pending'
				SELECT @DateMadeAvailable = NULL
			END
			ELSE
			BEGIN
				SELECT @LegStatus = 'Available'
				SELECT @VehicleStatus = 'Available'
				SELECT @DateMadeAvailable = CURRENT_TIMESTAMP
			END	
			IF @OriginID = @VehicleOriginID 
				AND @DestinationID = @VehicleDestinationID
			BEGIN
				UPDATE Vehicle
				SET CustomerIdentification = @DealerAllocationNumber
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
				SELECT @RecordStatus = 'ALLOC. NUMBER UPDATED'
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record_Status
			END
			ELSE IF @OriginID <> @VehicleOriginID AND @DestinationID <> @VehicleDestinationID
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
					SELECT @RecordStatus = 'DESTINATION CHANGED - REMOVED FROM LOAD'
				END
				ELSE
				BEGIN
					SELECT @RecordStatus = 'DESTINATION CHANGED'
				END
			END
			--update logic here.
			UPDATE Vehicle
			SET Color = @ExteriorColorCode,
			PickupLocationID = @OriginID,
			DropoffLocationID = @DestinationID,
			CustomerIdentification = @DealerAllocationNumber,
			ChargeRate = @ChargeRate,
			AvailableForPickupDate = @AvailableForPickupDate,
			VehicleStatus = @VehicleStatus,
			DateMadeAvailable = ISNULL(DateMadeAvailable, @DateMadeAvailable) -- want to preserve date if previously populated
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
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
			
			IF @LegStatus = 'Available'
			BEGIN
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
						'IMPORT'	--CreatedBy
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
			--end of latest mods
		END
		ELSE
		BEGIN	
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
					'IMPORT',	--CreatedBy,
					NULL,		--UpdatedDate,
					NULL		--UpdatedBy
				)

				--need to get the orderId key here, to insert into the vehicle record.			
				SELECT @OrderID = @@identity
			END

			--and now do the vehicle
			IF @VehicleYear IS NULL OR DATALENGTH(@VehicleYear)<1
			BEGIN
				SELECT @VehicleYear = ''
			END
			IF @Make IS NULL OR DATALENGTH(@Make)<1
			BEGIN
				SELECT @Make = ''
			END
			IF @Model IS NULL OR DATALENGTH(@Model)<1
			BEGIN
				SELECT @Model = ''
			END
			IF @Bodystyle IS NULL OR DATALENGTH(@Bodystyle)<1
			BEGIN
				SELECT @Bodystyle = ''
			END
			IF @VehicleLength IS NULL OR DATALENGTH(@VehicleLength)<1
			BEGIN
				SELECT @VehicleLength = ''
			END
			IF @VehicleWidth IS NULL OR DATALENGTH(@VehicleWidth)<1
			BEGIN
				SELECT @VehicleWidth = ''
			END
			IF @VehicleHeight IS NULL OR DATALENGTH(@VehicleHeight)<1
			BEGIN
				SELECT @VehicleHeight = ''
			END
			IF @VINDecodedInd IS NULL OR DATALENGTH(@VINDecodedInd)<1
			BEGIN
				SELECT @VINDecodedInd = 0
			END

			/*
			IF @AvailableInd = 1
			BEGIN
				SELECT @AvailableForPickupDate = GetDate()
				SELECT @LegStatus = 'Available'
			END
			ELSE
			BEGIN
			*/
			SELECT @AvailableForPickupDate = NULL
			SELECT @LegStatus = 'Pending'
			--END

			--get the vin, if it exists then just update anything that might have changed.
			SELECT @VINCOUNT = COUNT(*)
			FROM Vehicle
			WHERE (VIN = @VIN
			OR RIGHT(VIN,8) = RIGHT(@VIN,8))
			AND CustomerID IS NULL
			AND (OrderID IS NULL OR OrderID = -1)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END

			IF @VINCOUNT > 0
			BEGIN -- null customerid and ordersid means vehicle was added by phone, so update vehicle and leg
				
				--get the vehicleid
				SELECT @VehicleID = VehicleID
				FROM Vehicle
				WHERE (VIN = @VIN
				OR (DATALENGTH(VIN) = 8 AND RIGHT(VIN,8) = RIGHT(@VIN,8)))
				AND CustomerID IS NULL
				AND (OrderID IS NULL OR OrderID = -1)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error getting vehicle id'
					GOTO Error_Encountered
				END

				--update the vehicle
				UPDATE Vehicle
				SET CustomerID = @CustomerID,
				OrderID = @OrderID,
				VIN = @VIN,			--in case only the vin key was originally entered
				VehicleYear = @VehicleYear,
				Make = @Make,
				Model = @Model,
				Bodystyle = @Bodystyle,
				Color = @ExteriorColorCode,
				PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				VehicleLength = @VehicleLength,
				VehicleWidth = @VehicleWidth,
				VehicleHeight = @VehicleHeight,
				SizeClass = @SizeClass,
				CustomerIdentification = @DealerAllocationNumber,
				ChargeRate = @ChargeRate,
				VINDecodedInd = @VINDecodedInd,
				UpdatedDate = GetDate(),
				UpdatedBy = 'IMPORT'
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END

				--update the leg
				UPDATE Legs
				SET PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				UpdatedDate = GetDate(),
				UpdatedBy = 'IMPORT'
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING LEG RECORD'
					GOTO Error_Encountered
				END
			END
			ELSE
			BEGIN
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
					@CustomerID,		--CustomerID,
					@OrderID,		--OrderID,
					@VehicleYear,		--VehicleYear,
					@Make,			--Make,
					@Model,			--Model,
					@Bodystyle,		--Bodystyle,
					@VIN,			--VIN,
					@ExteriorColorCode,	--Color,
					@VehicleLength,		--VehicleLength
					@VehicleWidth,		--VehicleWidth
					@VehicleHeight,		--VehicleHeight
					@OriginID,		--PickupLocationID,
					@DestinationID,		--DropoffLocationID,
					'Pending',		--VehicleStatus,
					'Pickup Point',		--VehicleLocation,
					@DealerAllocationNumber,	--CustomerIdentification,
					@SizeClass,		--SizeClass,  --decode sizeclass.  might come up with logic for determining the size class.
					NULL,			--BayLocation,
					NULL,			--RailCarNumber,
					0,			--PriorityInd
					NULL,			--HaulType,
					@AvailableForPickupDate,	--AvailableForPickupDate,
					0,			--ShopWorkStartedInd,
					NULL,			--ShopWorkStartedDate,
					0,			--ShopWorkCompleteInd
					NULL,			--ShopWorkCompleteDate
					NULL,			--PaperworkReceivedDate,
					NULL,			--ICLAuditCode,
					@ChargeRate,		--ChargeRate
					0,			--ChargeRateOverrideInd
					0,			--BilledInd
					NULL,			--Datebilled
					@VINDecodedInd,		--VINDecodedInd
					'Active',		--RecordStatus,
					GetDate(),		--CreationDate,
					'IMPORT',		--CreatedBy,
					NULL,			--UpdatedDate,
					NULL,			--UpdatedBy
					0,			--CreditHoldInd
					0,			--PickupNotificationSentInd
					0,			--STIDeliveryNotificationSentInd
					0,			--BillOfLadingSentInd
					0,			--DealerHoldOverrideInd
					0,			--MiscellaneousAdditive
					0,			--FuelSurcharge
					0,			--AccessoriesCompleteInd,
					0,			--PDICompleteInd
					0			--FinalShipawayInspectionDoneInd
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
				Select @PreviousDestination = @DestinationID
	
				--get the Origin.
				Select @PreviousOrigin = @OriginID

				--update the VehiclePool
				IF @LegStatus = 'Available'
				BEGIN
					SELECT @DateAvailable = @AvailableForPickupDate

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
							1,		--PoolSize
							0,		--Reserved
							1,		--Available
							GetDate(),	--CreationDate
							'IMPORT'	--CreatedBy
						)
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Status = 'ERROR CREATING POOL RECORD'
							GOTO Error_Encountered
						END
						SELECT @PoolID = @@Identity
					END
					ELSE
					BEGIN
						SELECT @PoolID = VehiclePoolID
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
				END
				ELSE
				BEGIN
					SELECT @DateAvailable = NULL
					SELECT @PoolID = NULL
				END

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
					@VehicleID,	--VehicleID
					@PoolID,
					@DateAvailable,
					@OriginID,	--PickupLocationID
					@DestinationID,	--DropoffLocationID
					0,		--OutsideCarrierLegInd
					0,		--OutsideCarrierPaymentMethod
					0,		--OutsideCarrierPercentage
					0,		--OutsideCarrierPay
					0,		--OutsideCarrierFuelSurchargePercentage
					0,		--OCFSPEstablishedInd
					1,		--LegNumber
					1,		--FinalLegInd
					@LegStatus,	--LegStatus
					0,		--ShagUnitInd
					GetDate(),	--CreationDate
					'IMPORT',	--CreatedBy
					0		--OutsideCarrierFuelSurchargeType
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR CREATING DEFAULT LEG'
					GOTO Error_Encountered
				END
			END
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
		END

		--update logic here.
		Update_Record_Status:
		UPDATE ImportI73
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE ImportI73ID = @ImportI73ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH ImportI73 into @ImportI73ID, @VIN, @AllocationDealer, @DropShipFlag, @RailVendor, @RailRamp,
 			@PortReleaseDate, @ExteriorColorCode, @USPortofEntry, @DealerAllocationNumber,
			@RouteCode , @Header,
			@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
			@VehicleHeight, @VINDecodedInd

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
		CLOSE ImportI73
		DEALLOCATE ImportI73
		PRINT 'ImportI73 Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ImportI73
		DEALLOCATE ImportI73
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'ImportI73 Error_Encountered =' + STR(@ErrorID)
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
