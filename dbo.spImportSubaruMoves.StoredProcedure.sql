USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportSubaruMoves]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportSubaruMoves] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@loopcounter		int,
	@ImportSubaruMovesID	int,
	@VINNumber		varchar(17),
	@MDLCDE			varchar(5),
	@MODELDESCR		varchar(20),
	@TRNS			varchar(4),
	@BDYTYP			varchar(20),
	@ExteriorColorCode	varchar(3),
	@EXTCLR			varchar(30),
	@ORGDLR			varchar(6),
	@SP			varchar(1),
	@ENGINENUMBER		varchar(6),
	@FCTYACC		varchar(4),
	@SHPNUM			varchar(3),
	@CASENUM		varchar(4),
	@LOADNUMBER		varchar(7),
	@HR			varchar(1),
	@PRODDATE		varchar(6),
	@BlankColumn		varchar(4),
	@FNLDLR			varchar(6),
	@DC			varchar(1),
	@ST			varchar(1),
	@RELEASDATE		datetime,
	@AC			varchar(1),
	@ML			varchar(1),
	@PRIREQ			varchar(6),
	@RELSCODE		varchar(4),
	@DAYSIN			varchar(4),
	@INColumn		varchar(1),
	@ImportedInd		int,
	@DaysInInt		int,
	@VINCOUNT		int,
	@DestinationID		int,
	@OriginID		int,
	@ChargeRate		decimal(19,2),
	@CustomerID		int,
	@OrderID		int,
	@CustomerCode		varchar(70),
	@PreviousOrigin		int,
	@PreviousDestination	int,
	@OrderNumber		int,
	@RecordStatus		varchar(100),
	@Status			varchar(100),
	@OrderNumberPlusOne	int,
	@VehicleID		int,
	@VehicleDestinationID	int,
	@VehiclePoolID		int,
	@VehicleLoadID		int,
	@ReturnCode		int,
	@ReturnMessage		varchar(100),
	@PoolRecordCount	int,
	@PoolID			int,
	@TotalOrderUnits	int,
	@TotalOrderChargeRate	decimal(19,2),
	@LegsCount		int,
	@DecodedColor		varchar(20),
	@VehicleYear		varchar(6), 
	@Make			varchar(50), 
	@Model			varchar(50),
	@Bodystyle		varchar(50),
	@VehicleLength		varchar(10),
	@VehicleWidth		varchar(10),
	@VehicleHeight		varchar(10),
	@VINDecodedInd		int,
	@ImportedDate		datetime,
	@ImportedBy		varchar(20),
	@StorageDealerInd	int,
	@StorageLoadID		int,
	@UnitsPutInStorageCount	int,
	@LoadNumCounter		int,
	@LegID			int,
	@Result			int,
	@DATSLoadNumber		varchar(10),
	@CreationDate		datetime,
	@VehicleOriginID	int
			
	
	/************************************************************************
	*	spImportSubaruMoves						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ImportSubaruMoves table 	*
	*	and creates the new orders and vehicle records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/01/2004 CMK    Initial version				*
	*	11/10/2004 CMK    Moved ShagUnitInd from Vehicle to Leg		*
	*	08/23/2005 CMK    Added Color Decode				*
	*	09/08/2005 CMK    Added Code for vehicles that already exist	*
	*	12/02/2005 CMK    Changed VIN found code to update status and 	*
	*	                  not update any vehicle, leg or pool records	*
	*	05/17/2006 CMK    Added code for SDC Dealer Storage loads	*
	*									*
	************************************************************************/
	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @UnitsPutInStorageCount = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP

	--get the customer id from the setting table
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SDCCustomerID'
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

	DECLARE SubaruMoves CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT ImportSubaruMovesID, VINNumber, MDLCDE, MODELDESCR, TRNS,
		BDYTYP, ExteriorColorCode, EXTCLR, ORGDLR, SP, ENGINENUMBER, FCTYACC, SHPNUM,
		CASENUM, LOADNUMBER, HR, PRODDATE, BlankColumn, FNLDLR, DC, ST,
		RELEASDATE, AC, ML, PRIREQ, RELSCODE, CASE WHEN DAYSIN = '****' THEN '0' ELSE DAYSIN END, INColumn, ImportedInd,
		VehicleYear, Make, Model, Bodystyle, VehicleLength, VehicleWidth,
		VehicleHeight, VINDecodedInd
		FROM ImportSubaruMoves
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY FNLDLR, ImportSubaruMovesID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN SubaruMoves

	BEGIN TRAN

	FETCH SubaruMoves INTO @ImportSubaruMovesID, @VINNumber, @MDLCDE, @MODELDESCR, @TRNS,
		@BDYTYP, @ExteriorColorCode, @EXTCLR, @ORGDLR, @SP, @ENGINENUMBER, @FCTYACC, @SHPNUM,
		@CASENUM, @LOADNUMBER, @HR, @PRODDATE, @BlankColumn, @FNLDLR, @DC, @ST,
		@RELEASDATE, @AC, @ML, @PRIREQ, @RELSCODE, @DAYSIN, @INColumn, @ImportedInd,
		@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
		@VehicleHeight, @VINDecodedInd

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @DaysInInt = ISNULL(CONVERT(int,@DAYSIN),0)
		SELECT @StorageDealerInd = 0
		SELECT @StorageLoadID = NULL
		SELECT @DestinationID = NULL
		--get the destination.
		SELECT @DestinationID = L.LocationID,
		@StorageDealerInd = CASE WHEN S.LocationID IS NOT NULL THEN 1 ELSE 0 END
		FROM Location L
		LEFT JOIN SDCStorageDealers S ON L.LocationID = S.LocationID
		WHERE ParentRecordID = @CustomerID
		AND ParentRecordTable = 'Customer'
		AND CustomerLocationCode = @FNLDLR
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
				@FNLDLR,
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
		SELECT @OriginID = NULL
		SELECT @OriginID = CONVERT(int,Value1)
		FROM Code
		WHERE CodeType = 'SDCLocationCode'
		AND Code = 'DAI' --ALL SDC LOADS ORIGINATE FROM CHARLESTOWN
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
			GOTO Error_Encountered
		END
/* CURRENTLY ALL SDC LOADS ORIGINATE FROM CHARLESTOWN
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
				@OriginLocation,
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
			SELECT @OriginID = @@Identity
		END
*/
		SELECT @ChargeRate = NULL
		--From these values we can get the financial information.
		--Need to add logic to check size class. not in this particular file.
		SELECT @ChargeRate = Rate
		FROM ChargeRate
		WHERE StartLocationID = @OriginID
		AND EndLocationID = @DestinationID
		AND CustomerID = @CustomerID
		AND RateType = 'Size A Rate' -- for now
		AND @CreationDate >= StartDate
		AND @CreationDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
		
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VINNumber
		AND CustomerID = @CustomerID
		AND OrderID IS NOT NULL
		AND VehicleStatus <> 'Delivered'
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
			@VehicleDestinationID = V.DropoffLocationID
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			WHERE V.VIN = @VINNumber
			AND V.CustomerID = @CustomerID
			AND V.OrderID IS NOT NULL
			AND VehicleStatus <> 'Delivered'
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
				GOTO Error_Encountered
			END
			
			-- check the origin/destination
			IF @OriginID <> @VehicleOriginID
			BEGIN
				SELECT @RecordStatus = 'ORIGIN MISMATCH'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Import_Record
			END
			ELSE IF @DestinationID <> @VehicleDestinationID
			BEGIN
				SELECT @RecordStatus = 'DESTINATION MISMATCH'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Import_Record
			END
			ELSE
			BEGIN
				SELECT @RecordStatus = 'VIN ALREADY EXISTS'
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
			END
			
			--update logic here.
			UPDATE Vehicle
			SET Color = @EXTCLR,
			ChargeRate = @ChargeRate,
			VehicleStatus = CASE WHEN VehicleStatus = 'Pending' THEN 'Available' ELSE VehicleStatus END,
			AvailableForPickupDate = CASE WHEN VehicleStatus = 'Pending' THEN @RELEASDATE ELSE AvailableForPickupDate END,
			IntoInventoryDate = DATEADD(day,-@DaysInInt,@RELEASDATE),
			PriorityInd = CASE WHEN @PRIREQ = 1 THEN 1 ELSE 0 END,
			UpdatedDate = CURRENT_TIMESTAMP,
			UpdatedBy = 'Rel Impt',
			DateMadeAvailable = ISNULL(DateMadeAvailable,CURRENT_TIMESTAMP)
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
			END

			UPDATE Legs
			SET LegStatus = CASE WHEN LegStatus = 'Pending' THEN 'Available' ELSE LegStatus END,
			DateAvailable = CASE WHEN LegStatus = 'Pending' THEN @RELEASDATE ELSE DateAvailable END,
			UpdatedDate = CURRENT_TIMESTAMP,
			UpdatedBy = 'Rel Impt'
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
			END

			--update the VPCVehicle Table
			UPDATE VPCVehicle
			SET DestinationDealerCode = @FNLDLR,
			--LoadID = CASE WHEN @StorageLoadID IS NOT NULL THEN @StorageLoadID ELSE 0 END,
			--LoadNumber = CASE WHEN @StorageLoadID IS NOT NULL THEN 'D'+REPLICATE('0',6-DATALENGTH(@FNLDLR))+@FNLDLR ELSE NULL END,
			ReleaseDate = @RELEASDATE,
			VehicleStatus = CASE WHEN VehicleStatus IN ('Pending','InInventory') THEN 'Released' ELSE VehicleStatus END,
			PriorityInd = CASE WHEN @PRIREQ = 1 THEN 1 ELSE 0 END,
			UpdatedDate = CURRENT_TIMESTAMP,
			UpdatedBy = 'Rel Impt'
			WHERE SDCVehicleID = @VehicleID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating VPC Vehicle'
				GOTO Error_Encountered
			END
			/*
			--get the vehicle id
			SELECT @VehicleID = V.VehicleID,
			@VehicleDestinationID = V.DropoffLocationID,
			@VehicleLoadID = L.LoadID,
			@VehiclePoolID = L.PoolID
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.LegNumber = 1
			WHERE V.VIN = @VINNumber
			AND V.CustomerID = @CustomerID
			AND V.VehicleStatus <> 'Delivered'
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vehicle id'
				GOTO Error_Encountered
			END

			--update logic here.
			UPDATE Vehicle
			SET Color = @EXTCLR,
			PickupLocationID = @OriginID,
			DropoffLocationID = @DestinationID,
			ChargeRate = @ChargeRate,
			VehicleStatus = 'Available',
			AvailableForPickupDate = ISNULL(AvailableForPickupDate,@RELEASDATE),
			IntoInventoryDate = DATEADD(day,-@DaysInInt,@RELEASDATE)
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
			END

			IF @VehicleLoadID IS NULL
			BEGIN
				--update the VehiclePool
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
						'RELEASE IMPORT'	--CreatedBy
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
						
					IF ISNULL(@VehiclePoolID,0) <> @PoolID
					BEGIN
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
				IF @VehiclePoolID IS NOT NULL AND @PoolID <> @VehiclePoolID
				BEGIN
					--decrease the old pool
					UPDATE VehiclePool
					SET PoolSize = PoolSize - 1,
					Available = Available - 1
					WHERE VehiclePoolID = @VehiclePoolID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING OLD POOL RECORD'
						GOTO Error_Encountered
					END
				END
			END
			ELSE
			BEGIN
				SELECT @PoolID = NULL
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

			IF @LegsCount > 0
			BEGIN
				IF @VehicleLoadID IS NULL
				BEGIN
					--have legs, so update them
					UPDATE Legs
					SET PickupLocationID = @OriginID,
					DateAvailable = ISNULL(DateAvailable,@RELEASDATE),
					LegStatus = 'Available',
					PoolID = @PoolID
					WHERE VehicleID = @VehicleID
					AND LegNumber = 1
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error updating starting leg'
						GOTO Error_Encountered
					END
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
				
				IF @LegsCount > 1
				BEGIN
					UPDATE Legs
					SET LegStatus = 'Pending Prev. Leg'
					WHERE VehicleID = @VehicleID
					AND LegNumber > 1
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error updating ending leg'
						GOTO Error_Encountered
					END
				END
			END
			ELSE
			BEGIN
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
					ShagUnitind,
					CreationDate,
					CreatedBy,
					OutsideCarrierFuelSurchargeType
				)
				VALUES(
					@VehicleID,
					@PoolID,
					@RELEASDATE,
					@OriginID,
					@DestinationID,
					0, 		--OutsideCarrierLegInd
					0, 		--OutsideCarrierPaymentMethod
					0, 		--OutsideCarrierPercentage
					0, 		--OutsideCarrierPay
					0, 		--OutsideCarrierFuelSurchargePercentage
					0, 		--OCFSPEstablishedInd
					1, 		--LegNumber
					1, 		--FinalLegInd
					'Available',
					0,		--ShagUnitInd
					GetDate(), 	--CreationDate
					'IMPORT', 	--CreatedBy
					0		--OutsideCarrierFuelSurchargeType
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR CREATING DEFAULT LEG'
					GOTO Error_Encountered
				END
			END
			*/
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
			
			--try to decode the color
			SET @DecodedColor = NULL
			
			SELECT @DecodedColor = CodeDescription
			FROM Code
			WHERE CodeType = 'SubaruColorCode'
			AND Code = @EXTCLR
			
			IF @DecodedColor IS NULL OR DATALENGTH(@DecodedColor)<1
			BEGIN
				SELECT @DecodedColor = @EXTCLR
			END
			IF @VehicleYear IS NULL OR DATALENGTH(@VehicleYear)<1
			BEGIN
				SELECT @VehicleYear = ''
			END
			IF @Make IS NULL OR DATALENGTH(@Make)<1
			BEGIN
				SELECT @Make = 'Subaru'
			END
			IF @Model IS NULL OR DATALENGTH(@Model)<1
			BEGIN
				SELECT @Model = @MODELDESCR
			END
			IF @Bodystyle IS NULL OR DATALENGTH(@Bodystyle)<1
			BEGIN
				SELECT @Bodystyle = @BDYTYP
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
			
			--get the vin, if it exists then just update anything that might have changed.
			SELECT @VINCOUNT = COUNT(*)
			FROM Vehicle
			WHERE VIN = @VINNumber
			AND CustomerID = @CustomerID
			AND OrderID IS NULL
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END

			IF @VINCOUNT > 0
			BEGIN -- customerid and null ordersid means vehicle was added by foxpro, so update vehicle and leg
				
				--get the vehicleid
				SELECT @VehicleID = VehicleID
				FROM Vehicle
				WHERE VIN = @VINNumber
				AND CustomerID = @CustomerID
				AND OrderID IS NULL
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error getting vehicle id'
					GOTO Error_Encountered
				END

				--update the vehicle
				UPDATE Vehicle
				SET OrderID = @OrderID,
				VehicleYear = @VehicleYear,
				Make = @Make,
				Model = @Model,
				Bodystyle = @Bodystyle,
				Color = @DecodedColor,
				VehicleLength = @VehicleLength,
				VehicleWidth = @VehicleWidth,
				VehicleHeight = @VehicleHeight,
				PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				VehicleStatus = 'Available',
				VehicleLocation = 'Pickup Point',
				CustomerIdentification = @CASENUM,
				SizeClass = 'A',
				RailCarNumber = '',
				PriorityInd = CASE WHEN @PRIREQ = 1 THEN 1 ELSE 0 END,
				AvailableForPickupDate = @RELEASDATE,
				IntoInventoryDate = DATEADD(day,-@DaysInInt,@RELEASDATE),
				ChargeRate = @ChargeRate,
				ChargeRateOverrideInd = 0,
				BilledInd = 0,
				VINDecodedInd = @VINDecodedInd,
				UpdatedDate = GetDate(),
				UpdatedBy = 'IMPORT',
				DateMadeAvailable = ISNULL(DateMadeAvailable,CURRENT_TIMESTAMP)
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
					IntoInventoryDate,
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
					DateMadeAvailable
				)
				VALUES(
					@CustomerID,				--CustomerID,
					@OrderID,				--OrderID,
					@VehicleYear,				--VehicleYear,	--YEAR MAKE MODEL INFO WILL BE REPLACED WITH CALL TO POLK DATA
					@Make,					--Make,
					@Model,					--Model,
					@Bodystyle,				--Bodystyle,
					@VINNumber,				--VIN,
					@DecodedColor,				--Color,
					@VehicleLength,				--VehicleLength,
					@VehicleWidth,				--VehicleWidth,
					@VehicleHeight,				--VehicleHeight,
					@OriginID,				--PickupLocationID,
					@DestinationID,				--DropoffLocationID,
					'Available',				--VehicleStatus,
					'Pickup Point',				--VehicleLocation,
					@CASENUM,				--CustomerIdentification,
					'A',					--SizeClass,
					NULL,					--BayLocation,
					'',					--RailCarNumber,
					CASE WHEN @PRIREQ = 1 THEN 1 ELSE 0 END,	--PriorityInd
					NULL,					--HaulType,
					@RELEASDATE,				--AvailableForPickupDate,
					0,					--ShopWorkStartedInd,
					NULL,					--ShopWorkStartedDate,
					0,					--ShopWorkCompleteInd,
					NULL,					--ShopWorkCompleteDate,
					NULL,					--PaperworkReceivedDate,
					NULL,					--ICLAuditCode,
					DATEADD(day,-@DaysInInt,@RELEASDATE),	--IntoInventoryDate
					@ChargeRate,
					0,					--ChargeRateOverrideInd
					0,					--BilledInd,
					NULL,					--BilledDate,
					@VINDecodedInd,				--VINDecodedInd,
					'Active',				--RecordStatus,
					GetDate(),				--CreationDate
					'IMPORT',				--CreatedBy
					NULL,					--UpdatedDate,
					NULL,					--UpdatedBy
					0,					--CreditHoldInd
					0,					--PickupNotificationSentInd
					0,					--STIDeliveryNotificationSentInd
					0,					--BillOfLadingSentInd
					0,					--DealerHoldOverrideInd
					0,					--MiscellaneousAdditive
					0,					--FuelSurcharge
					0,					--AccessoriesCompleteInd,
					0,					--PDICompleteInd
					0,					--FinalShipawayInspectionDoneInd
					CURRENT_TIMESTAMP			--DateMadeAvailable
				)
			
				IF @@Error <> 0
					BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR CREATING VEHICLE RECORD'
					GOTO Error_Encountered
				END

				SELECT @VehicleID = @@Identity
			END
			
			SELECT @TotalOrderUnits = @TotalOrderUnits + 1
			SELECT @TotalOrderChargeRate = @TotalOrderChargeRate + @ChargeRate

			--need to save off the previous destination and orign.
			--get the destination.
			Select @PreviousDestination = @DestinationID

			--get the Origin.
			Select @PreviousOrigin = @OriginID

			--update the VehiclePool
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
					'RAIL IMPORT'	--CreatedBy
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
			
			IF @VINCOUNT > 0
			BEGIN
				--update the leg record
				UPDATE Legs
				SET PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				PoolID = @PoolID,
				DateAvailable = @RELEASDATE,
				LegStatus = 'Available',
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
					@RELEASDATE,
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
					'Available',	--LegStatus
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
			
			--if this is a storage dealer add the vehicle to the storage load
			IF @StorageDealerInd = 1 AND @PRIREQ <> 1
			BEGIN
				--see if the storage load already exists
				SELECT @StorageLoadID = LoadsID
				FROM Loads
				WHERE CustomerLoadNumber = 'D'+REPLICATE('0',6-DATALENGTH(@FNLDLR))+@FNLDLR
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING STORAGE LOAD NUMBER'
					GOTO Error_Encountered
				END
				print 'storageloadid = '+convert(varchar(10),@StorageLoadID)
				IF @StorageLoadID IS NULL
				BEGIN
					print 'creating storage load'
					-- the storage load id is null, so create the storage load
					--get the loadnumber
					SELECT @LoadNumCounter = ValueDescription
					FROM SettingTable
					WHERE ValueKey = 'NextLoadNumber'
					IF @@ERROR <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the NextLoadNumber'
						GOTO Error_Encountered
					END
	
					--update the nextloadnumber
					UPDATE SettingTable
					SET ValueDescription = @LoadNumCounter + 1
					WHERE ValueKey = 'NextLoadNumber'
					IF @@ERROR <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the NextLoadNumber'
						GOTO Error_Encountered
					END
	
					-- format load counter like: 'YYMMXXXXX'  (june 2005, 1st load num: '05060001')
					set @DATSLoadNumber = left(convert(varchar(6),getdate(),12),4) + right(replicate('0',4) + convert(varchar(4),@LoadNumCounter), 4)
					print 'about to insert storage load'
					INSERT INTO Loads(
						LoadNumber,
						CustomerLoadNumber,
						LoadSize, 
						NumberLoaded, 
						NumberDelivered,
						OutsideCarrierLoadInd, 
						OutsideCarrierID, 
						ScheduledPickupDate, 
						LoadStatus, 
						CreationDate, 
						CreatedBy,
						HotLoadInd
					)
					VALUES(
						@DATSLoadNumber, 
						'D'+REPLICATE('0',6-DATALENGTH(@FNLDLR))+@FNLDLR,
						0, 		-- loadsize 
						0, 		-- NumberLoaded,int
						0, 		-- NumberDelivered
						0, 		-- OutsideCarrierLoadInd,int
						null, 		-- OutsideCarrierID,int
						null, 		-- ScheduledPickupDate,datetime
						'Unassigned', 	-- LoadStatus,varchar(20)
						getdate(), 	-- CreationDate,datetime
						'IMPORT', 	-- CreatedBy
						0		-- HotLoadInd
					)
					IF @@ERROR <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered inserting the load record'
						GOTO Error_Encountered
					END
						
					--get the loadid
					SELECT @StorageLoadID = @@Identity
					IF @@ERROR <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the New Load ID'
						GOTO Error_Encountered
					END
					print 'storageloadid = '+convert(varchar(10),@StorageLoadID)
				END
				
				--get the leg id
				SELECT TOP 1 @LegID = LegsID
				FROM Legs
				WHERE VehicleID = @VehicleID
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting Leg ID'
					GOTO Error_Encountered
				END
				print 'legid = '+convert(varchar(10),@LegID)
				--add the vehicle to the load
				EXEC @Result = spAddVehicleToLoad @LegID, @StorageLoadID,NULL,NULL,NULL,'IMPORT',1
				IF @Result <> 0
				BEGIN
					print 'add vehicle to load failed'
					SELECT @ErrorID = @Result
					SELECT @Status = 'Error Number '+CONVERT(varchar(10),@Result)+' encountered adding vehicle to storage load'
				END
				SELECT @UnitsPutInStorageCount = @UnitsPutInStorageCount + 1
				print '@units put in storage count = '+convert(varchar(10),@UnitsPutInStorageCount)
			END
			
			--update the VPCVehicle Table
			UPDATE VPCVehicle
			SET DestinationDealerCode = @FNLDLR,
			--LoadID = CASE WHEN @StorageLoadID IS NOT NULL THEN @StorageLoadID ELSE 0 END,
			LoadNumber = CASE WHEN @StorageLoadID IS NOT NULL THEN 'D'+REPLICATE('0',6-DATALENGTH(@FNLDLR))+@FNLDLR ELSE NULL END,
			ReleaseDate = @RELEASDATE,
			VehicleStatus = CASE WHEN VehicleStatus IN ('Pending','InInventory') THEN 'Released' ELSE VehicleStatus END,
			PriorityInd = CASE WHEN @PRIREQ = 1 THEN 1 ELSE 0 END,
			UpdatedDate = CURRENT_TIMESTAMP,
			UpdatedBy = 'Rel Impt'
			WHERE SDCVehicleID = @VehicleID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating VPC Vehicle'
				GOTO Error_Encountered
			END
			
			print 'about to set record status'
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
		END
		print 'at update import record'
		--update logic here.
		Update_Import_Record:
		UPDATE ImportSubaruMoves
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE ImportSubaruMovesID = @ImportSubaruMovesID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END
		
		

		FETCH SubaruMoves INTO @ImportSubaruMovesID, @VINNumber, @MDLCDE, @MODELDESCR, @TRNS,
		@BDYTYP, @ExteriorColorCode, @EXTCLR, @ORGDLR, @SP, @ENGINENUMBER, @FCTYACC, @SHPNUM,
		@CASENUM, @LOADNUMBER, @HR, @PRODDATE, @BlankColumn, @FNLDLR, @DC, @ST,
		@RELEASDATE, @AC, @ML, @PRIREQ, @RELSCODE, @DAYSIN, @INColumn, @ImportedInd,
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
		CLOSE SubaruMoves
		DEALLOCATE SubaruMoves
		PRINT 'ImportSubaruMoves Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE SubaruMoves
		DEALLOCATE SubaruMoves
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'ImportSubaruMoves Error_Encountered =' + STR(@ErrorID)
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @UnitsPutInStorageCount StorageCount
	
	RETURN
END
GO
