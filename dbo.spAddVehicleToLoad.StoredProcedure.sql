USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddVehicleToLoad]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE  PROCEDURE [dbo].[spAddVehicleToLoad](
	@LegsID			int,
	@LoadID			int,
	@DriverID		int,		-- pass null if not reserving
	@ReserveInd		int,		-- if passed in it will reserve the vehicle for the driver as well
	@Date			datetime,
	@User			varchar(20),	-- Can be either user name or application name
	@pReturnCode		int = 0 OUTPUT	-- 0 = return result set, otherwise don't
	)
AS
BEGIN
	/************************************************************************
	*	spAddVehicleToLoad						*
	*									*
	*	Description							*
	*	-----------							*
	*	Adds a vehicle to a load and updates all related information.	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/17/2005 CMK    Initial version				*
	*	08/02/2005 CMK    Added adjustments to # Loaded & Delivered	*
	*	09/09/2005 CMK    Added Code for SDC Yard Moves			*
	*	04/18/2018 CMK    Added code for adding SDC Dealer Storage units*
	*			  to the PortStorageVehicles table		*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@OriginID			int,
		@DestinationID			int,
		@LegPoolID			int,
		@LegLoadID			int,
		@LegStatus			varchar(20),
		@VehiclePoolID			int,
		@PoolSize			int,
		@Reserved			int,
		@Available			int,
		@CreationDate			datetime,
		@CreatedBy			varchar(20),
		@UpdatedDate			datetime,
		@UpdatedBy			varchar(20),
		@DriverOut			varchar(100),
		@ReturnCode			int,
		@ReturnMessage			varchar(100),
		@ErrorID			int,
		@Msg				varchar(100),
		@LoadSize			int,
		@NumberLoaded			int,
		@NumberDelivered		int,
		@LoadLane			varchar(20),
		@SDCCustomerID			int,
		@ShopWorkCompleteInd		int,
		@SDCYardMovesID			int,
		@BayLocation			varchar(20),
		@FromLoadNumber			varchar(20),
		@FromBayLocation		varchar(20),
		@ToLoadNumber			varchar(20),
		@ToBayLocation			varchar(20),
		@CustomerLoadNumber		varchar(20),
		@OldCustomerLoadNumber		varchar(20),
		@LoadSizeAdjustment		int,
		@Count				int,
		@VehicleReservationID		int,
		@ReservationCount		int,
		@ReservationSize		int,
		@CustomerID			int,
		@VehicleID			int,
		@VehicleStatus			varchar(20),
		@FinalLegInd			int,
		@RunID				int,
		@PickupDate			datetime,
		@DeliveryDate			datetime,
		@DateOut			datetime,
		@VehicleLocation		varchar(20),
		@SDCDAILocationID		int,
		@VIN				varchar(17),
		@ComingFromSDCBayOrLoadLaneInd	int,
		@LoadNumber			varchar(20),
		@DestinationDealerCode		varchar(20),
		@PortStorageCustomerID		int,
		@VehicleYear			varchar(6),
		@Make				varchar(50),
		@Model				varchar(50),
		@Bodystyle			varchar(50),
		@Color				varchar(20),
		@VehicleLength			varchar(10),
		@VehicleWidth			varchar(10),
		@VehicleHeight			varchar(10),
		@DateAvailable			datetime,
		@VINDecodedInd			int,
		@VINCount			int

	/* CUSTOM ERRORS
	100000 Vehicle Reserved By Another Load
	100001 Vehicle Already Belongs To This Load
	100010 LegsID OR LoadsID is missing
	100011 Vehicle Is On Hold
	*/
	SELECT @Count = 0
	SELECT @ErrorID = 1
	SELECT @LoadSizeAdjustment = 0
	SELECT @UpdatedDate = CURRENT_TIMESTAMP
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @ComingFromSDCBayOrLoadLaneInd = 0
		
	BEGIN TRAN
	
	--print 'beginning tran'
	IF @LegsID IS NULL OR @LoadID IS NULL
	BEGIN
		SELECT @ErrorID = 100010
		SELECT @Msg = 'LegsID OR LoadsID is missing.'
		GOTO Error_Encountered
	END
	--print 'getting leg status'
	--get the load status
	SELECT @LegStatus = CASE WHEN LoadStatus IN ('Scheduled & Assigned','Assigned','Scheduled','EnRoute','Delivered')
	THEN LoadStatus ELSE 'In Load' END, @RunID = RunID, @PickupDate = ActualPickupDate, @DeliveryDate = ActualDeliveryDate,
	@LoadLane = ISNULL(LoadLane,''), @CustomerLoadNumber = CustomerLoadNumber,
	@LoadNumber = CASE WHEN DATALENGTH(CustomerLoadNumber) > 0 THEN CustomerLoadNumber ELSE LoadNumber END
	FROM Loads
	WHERE LoadsID = @LoadID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Load Status'
		GOTO Error_Encountered
	END
	--print 'leg status = '+@LegStatus
	--print 'getting the leg info'
	--get the leg information
	SELECT @OriginID = L.PickupLocationID,
	@DestinationID = L.DropoffLocationID,
	@LegLoadID = ISNULL(L.LoadID,0),
	@LegPoolID = ISNULL(L.PoolID,0),
	@CustomerID = V.CustomerID,
	@VehicleID = V.VehicleID,
	@FinalLegInd = L.FinalLegInd,
	@BayLocation = V.BayLocation,
	@ShopWorkCompleteInd = V.ShopWorkCompleteInd,
	@OldCustomerLoadNumber = ISNULL(L2.CustomerLoadNumber,''),
	@VIN = V.VIN,
	@VehicleStatus = V.VehicleStatus,
	@DriverOut = CASE WHEN L2.OutsideCarrierLoadInd = 0 THEN U.FirstName+' '+U.LastName ELSE OC.CarrierName END,
	@DestinationDealerCode = L3.CustomerLocationCode,
	@VehicleYear = V.VehicleYear,
	@Make = V.Make,
	@Model = V.Model,
	@Bodystyle = V.Bodystyle,
	@Color = V.Color,
	@VehicleLength = V.VehicleLength,
	@VehicleWidth = V.VehicleWidth,
	@VehicleHeight = V.VehicleHeight,
	@DateAvailable = V.AvailableForPickupDate,
	@VINDecodedInd = V.VINDecodedInd
	FROM Legs L
	LEFT JOIN Vehicle V ON L.VehicleID = V.VehicleID
	LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
	LEFT JOIN Driver D ON L2.DriverID = D.DriverID
	LEFT JOIN Users U ON D.UserID = U.UserID
	LEFT JOIN OutsideCarrier OC ON L.OutsideCarrierID = OC.OutsideCarrierID
	LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
	WHERE L.LegsID = @LegsID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Leg Information'
		GOTO Error_Encountered
	END
	--print 'originid = '+convert(varchar(10),@OriginID)
	--print 'DestinationID = '+convert(varchar(10),@DestinationID)
	--print 'LegLoadID = '+convert(varchar(10),@LegLoadID)
	--print 'LegPoolID = '+convert(varchar(10),@LegPoolID)
	--print 'CustomerID = '+convert(varchar(10),@CustomerID)
	
	IF @VehicleStatus = 'OnHold'
	BEGIN
		SELECT @ErrorID = 100011
		SELECT @Msg = 'VEHICLE IS ON HOLD.'
		GOTO Error_Encountered
	END
	IF @LegLoadID = @LoadID
	BEGIN
		--print 'legloadid = loadid'
		SELECT @ErrorID = 0 -- 100001
		SELECT @Msg = 'Vehicle Already Belongs To This Load.'
		GOTO Error_Encountered
	END
	IF @LegPoolID > 0
	BEGIN
		--print 'poolid > 0'
		--get any reservation information
		SELECT @ReservationCount = Count(*)
		FROM VehicleReservations
		WHERE LoadsID = @LoadID
		AND PoolID = @LegPoolID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Reservation Count'
			GOTO Error_Encountered
		END
		
		IF @ReservationCount > 0
		BEGIN
			SELECT @VehicleReservationID = VehicleReservationsID, @ReservationSize = Units
			FROM VehicleReservations
			WHERE LoadsID = @LoadID
			AND PoolID = @LegPoolID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Reservation Size'
				GOTO Error_Encountered
			END
		END
		
		-- get the pool information
		SELECT @VehiclePoolID = VehiclePoolID,
		@PoolSize = PoolSize,
		@Reserved = Reserved,
		@Available = Available
		FROM VehiclePool
		WHERE OriginID = @OriginID
		AND DestinationID = @DestinationID
		AND CustomerID = @CustomerID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Pool ID'
			GOTO Error_Encountered
		END
	
		IF @ReservationSize > 0
		BEGIN
			--vehicle probably reserved for load, but not reserved by driver at terminal
			IF @ReservationSize = 1
			BEGIN
				DELETE VehicleReservations
				WHERE VehicleReservationsID = @VehicleReservationID
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered deleting Vehicle Reservation'
					GOTO Error_Encountered
				END
			END
			ELSE IF @ReservationSize > 1
			BEGIN
				UPDATE VehicleReservations
				SET Units = Units - 1
				WHERE VehicleReservationsID = @VehicleReservationID
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating Vehicle Reservation'
					GOTO Error_Encountered
				END
			END
			SELECT @Reserved = @Reserved - 1
			SELECT @PoolSize = @PoolSize - 1
			SELECT @LoadSizeAdjustment = 0	
		END
		ELSE
		BEGIN
			IF @Available > 0
			BEGIN
				SELECT @PoolSize = @PoolSize - 1
				SELECT @Available = @Available - 1
			END
			ELSE IF @Reserved > 0
			BEGIN
				SELECT @ErrorID = 100000
				SELECT @Msg = 'The selected vehicle is likely reserved for another load.'
				GOTO Error_Encountered
			END
			SELECT @LoadSizeAdjustment = 1
		END
		
		UPDATE VehiclePool
		SET PoolSize = @PoolSize,
		Available = @Available,
		Reserved = @Reserved
		WHERE VehiclePoolID = @VehiclePoolID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the Vehicle Pool (2)'
			GOTO Error_Encountered
		END
	END
	ELSE IF @LegLoadID > 0
	BEGIN
		--print 'loadid > 0'
		--if the vehicle is coming from another load, reduce the load size
		UPDATE Loads
		SET LoadSize = LoadSize - 1
		WHERE LoadsID = @LegLoadID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the Old Load Record'
			GOTO Error_Encountered
		END
		
		SELECT @LoadSizeAdjustment = 1
	END
	
	IF @LegStatus = 'EnRoute' OR @LegStatus = 'Delivered'
	BEGIN
		--print 'about to update vehicle'
		IF @LegStatus = 'Delivered' AND @FinalLegInd = 1
		BEGIN
			SELECT @VehicleStatus = 'Delivered'
			SELECT @VehicleLocation = 'Delivery Point'
		END
		ELSE IF @LegStatus = 'Delivered' AND @FinalLegInd = 0
		BEGIN
			SELECT @VehicleStatus = 'EnRoute'
			SELECT @VehicleLocation = 'Intermediate Point'
		END
		ELSE
		BEGIN
			SELECT @VehicleStatus = 'EnRoute'
			SELECT @VehicleLocation = 'On Truck'
		END
		--update the vehicle
		UPDATE Vehicle
		SET VehicleStatus = @VehicleStatus,
		VehicleLocation = @VehicleLocation,
		UpdatedDate = @UpdatedDate,
		UpdatedBy = @User
		WHERE VehicleID = @VehicleID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the Vehicle Record'
			GOTO Error_Encountered
		END
	END
	
	--print 'about to update leg'
	--update the leg
	UPDATE Legs
	SET LoadID = @LoadID,
	PoolID = NULL,
	RunID = @RunID,
	LegStatus = @LegStatus,
	PickupDate = @PickupDate,
	DropoffDate = @DeliveryDate,
	ReservedByDriverInd = @ReserveInd,
	ReservedByDriverID = @DriverID,
	UpdatedDate = @UpdatedDate,
	UpdatedBy = @User
	WHERE LegsID = @LegsID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the Leg Record'
		GOTO Error_Encountered
	END
	
	--get the new load size
	SELECT @LoadSize = COUNT(*)
	FROM Legs
	WHERE LoadID = @LoadID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' getting new Load Size'
		GOTO Error_Encountered
	END
	
	--get the new number loaded
	SELECT @NumberLoaded = COUNT(*)
	FROM Legs
	WHERE LoadID = @LoadID
	AND LegStatus IN ('EnRoute', 'Complete', 'Delivered')
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' getting new Number Loaded'
		GOTO Error_Encountered
	END
	
	--get the new number delivered
	SELECT @NumberDelivered = COUNT(*)
	FROM Legs
	WHERE LoadID = @LoadID
	AND LegStatus IN ('Complete','Delivered')
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' getting new Number Delivered'
		GOTO Error_Encountered
	END
	
	--change the load size
	UPDATE Loads
	SET LoadSize = @LoadSize, --LoadSize+@LoadSizeAdjustment,
	NumberLoaded = @NumberLoaded, --CASE WHEN @LegStatus = 'EnRoute' THEN NumberLoaded + 1 WHEN @LegStatus = 'Delivered' THEN NumberLoaded + 1 ELSE NumberLoaded END,
	NumberDelivered = @NumberDelivered, --CASE WHEN @LegStatus = 'Delivered' THEN NumberDelivered + 1 ELSE NumberDelivered END,
	UpdatedDate = @UpdatedDate,
	UpdatedBy = @User
	WHERE LoadsID = @LoadID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the Load Record'
		GOTO Error_Encountered
	END

	--see if this is an sdc vehicle and if so write/update an sdc yard moves record
	SELECT @SDCCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SDCCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting SDC Customer ID'
		GOTO Error_Encountered
	END
	--print 'about to hit sdc code'
	IF @CustomerID = @SDCCustomerID
	BEGIN
		--print 'in sdc code'
		IF DATALENGTH(@CustomerLoadNumber) > 0 --any sdc load without an sdc load number is likely part of a new release
		BEGIN
			--print 'have customer load number'
			--this is an sdc vehicle so we have to create/update a yard moves exit
		
			--get the sdc dai locationid
			SELECT @SDCDAILocationID = CONVERT(int,ValueDescription)
			FROM SettingTable
			WHERE ValueKey = 'SDCDiversifiedLocationID'
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the SDC Customer ID'
				GOTO Error_Encountered
			END
			--print 'about to get sdc yard moves id'
			--see if there is already an sdc yard moves record
			SELECT @SDCYardMovesID = NULL
		
			SELECT @SDCYardMovesID = SDCYardMovesID
			FROM SDCYardMoves
			WHERE VehicleID = @VehicleID
			--AND MovePrintedInd = 0
			AND MoveCompletedInd = 0
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting SDCYardMovesID'
				GOTO Error_Encountered
			END
			--print 'sdc yard moves id = '+convert(varchar(10),isnull(@Sdcyardmovesid,''))
			
			SELECT @ToLoadNumber = @CustomerLoadNumber
			--print 'to load number = '+@toloadnumber
			IF @ShopWorkCompleteInd = 1
			BEGIN
				--print 'shop work completeind = 1'
				IF DATALENGTH(@LoadLane)>0
				BEGIN
					--print 'have load lane'
					SELECT @ToBayLocation = @LoadLane
				END
				ELSE
				BEGIN
					--print 'no load lane'
					SELECT @ToBayLocation = @BayLocation
				END
			END
			ELSE
			BEGIN
				--print 'shop work complete = 0'
				SELECT @ToBayLocation = @BayLocation
			END
			--print 'to bay location = '+@ToBayLocation
			--update the vehicle with its bay location
			UPDATE Vehicle
			SET --BayLocation = @ToBayLocation,
			FinalShipawayInspectionDoneInd = 0,
			FinalShipawayInspectionDate = NULL,
			FinalShipawayInspectionDoneBy = NULL,
			UpdatedDate = @UpdatedDate,
			UpdatedBy = @UpdatedBy
			WHERE VehicleID = @VehicleID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating vehicle bay location'
				GOTO Error_Encountered
			END
			
			--print 'about to do bay check'
			IF ISNULL(@BayLocation,'') <> ISNULL(@ToBayLocation,'')
			BEGIN
				--print 'in bay check'
				--see if the vehicle is coming from a bay and if so release the bay
				SELECT @Count = NULL
				
				SELECT @Count = COUNT(*)
				FROM SDCBayLocations
				WHERE BayNumber = @BayLocation
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting bay count record'
					GOTO Error_Encountered
				END
				--print 'bay count = '+convert(varchar(10),@Count)
				IF @Count > 0
				BEGIN
					--print 'updating bay'
					UPDATE SDCBayLocations
					SET AvailableInd = 1
					WHERE BayNumber = @BayLocation
					IF @@ERROR <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating SDCBayLocations record'
						GOTO Error_Encountered
					END
					
					SELECT @ComingFromSDCBayOrLoadLaneInd = 1
				END
				--print 'about to do load lane check'
				--see if the vehicle is coming from a load lane and if the load lane is empty release it
				SELECT @Count = NULL
									
				SELECT @BayLocation = CASE WHEN CHARINDEX(' ',@BayLocation) > 0 THEN LEFT(@BayLocation,CHARINDEX(' ',@BayLocation)-1) ELSE @BayLocation END
		
				SELECT @Count = COUNT(*)
				FROM SDCLoadLanes
				WHERE LaneNumber = @BayLocation
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting lane count record'
					GOTO Error_Encountered
				END
				--print 'load lane count = '+convert(varchar(10),@Count)						
				IF @Count > 0 -- we have a load lane so check to see if we can make it available
				BEGIN
					--print 'doing load lane occupancy check'
					SELECT @Count = NULL
							
					SELECT @Count = COUNT(*)
					FROM Vehicle V
					LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
					WHERE L.PickupLocationID = @SDCDAILocationID
					AND V.CustomerID = @SDCCustomerID
					AND L.LegStatus NOT IN ('EnRoute', 'Delivered')
					AND LEFT(V.BayLocation,DATALENGTH(@BayLocation)) = @BayLocation
					AND V.VehicleID <> @VehicleID
					IF @@ERROR <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating load lane count'
						GOTO Error_Encountered
					END
						
					IF @Count = 0
					BEGIN
						UPDATE SDCLoadLanes
						SET AvailableInd = 1
						WHERE LaneNumber = @BayLocation
						IF @@ERROR <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating SDCLoadLanes record'
							GOTO Error_Encountered
						END
					END
					
					SELECT @ComingFromSDCBayOrLoadLaneInd = 1
				END
			END
			--print 'ComingFromSDCBayOrLoadLaneInd = '+convert(varchar(10),@ComingFromSDCBayOrLoadLaneInd)
			--IF @ComingFromSDCBayOrLoadLaneInd = 1
			--BEGIN
				--print 'about to write/update sdc yard moves record'
				IF @SDCYardMovesID IS NULL
				BEGIN
					--print 'in the sdc yard moves insert'
					SELECT @FromLoadNumber = @OldCustomerLoadNumber
					SELECT @FromBayLocation = @BayLocation
					
					IF @FromLoadNumber <> @ToLoadNumber OR @FromBayLocation <> @ToBayLocation
					BEGIN
						--inserting a new sdc yard moves record
						INSERT INTO SDCYardMoves(
							VehicleID,
							FromLoadNumber,
							FromBayLocation,
							ToLoadNumber,
							ToBayLocation,
							MovePrintedInd,
							CreationDate,
							CreatedBy,
							MoveCompletedInd
						)
						VALUES(
							@VehicleID,
							@FromLoadNumber,
							@FromBayLocation,
							@ToLoadNumber,
							@ToBayLocation,
							0,		--MovePrintedInd,
							@CreationDate,
							'AddVehToLd',
							0		--MoveCompletedInd
						)
						IF @@ERROR <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating SDCYardMoves record'
							GOTO Error_Encountered
						END
					END
				END
				ELSE
				BEGIN
					IF @OldCustomerLoadNumber <> @ToLoadNumber OR @BayLocation <> @ToBayLocation
					BEGIN
						SELECT @FromBayLocation = @BayLocation
						--print 'in the sdc yard moves update'
						--updating the existing yard moves record
						UPDATE SDCYardMoves
						SET ToLoadNumber = @ToLoadNumber,
						ToBayLocation = @ToBayLocation,
						UpdatedDate = @UpdatedDate,
						UpdatedBy = 'AddVehToLd'
						WHERE SDCYardMovesID = @SDCYardMovesID
						IF @@ERROR <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating SDCYardMoves record'
							GOTO Error_Encountered
						END
					END
					ELSE
					BEGIN
						UPDATE SDCYardMoves
						SET MoveCompletedInd = 1
						WHERE SDCYardMovesID = @SDCYardMovesID
						IF @@ERROR <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating SDCYardMoves record'
							GOTO Error_Encountered
						END
					END
				END
			--END
			
			UPDATE VPCVehicle
			SET LoadNumber = @ToLoadNumber,
			FinalShipawayInspectionDoneInd = 0,
			FinalShipawayInspectionDate = NULL,
			FinalShipawayInspectionDoneBy = NULL
			WHERE SDCVehicleID = @VehicleID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating VPCVehicle record'
				GOTO Error_Encountered
			END
			
			IF @LegStatus = 'EnRoute' OR @LegStatus = 'Delivered'
			BEGIN
				SELECT @DateOut = @PickupDate
				
				--update the vpc vehicle record
				UPDATE VPCVehicle
				SET DateOut = @DateOut,
				DriverOut = @DriverOut,
				VehicleStatus = 'Shipped',
				UpdatedDate = @DateOut,
				UpdatedBy = @User
				WHERE SDCVehicleID = @VehicleID
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating VPCVehicle record'
					GOTO Error_Encountered
				END
			END
			
			--if this is a dealer storage load, then add the vehicle to the PortStorageVehiclesTable
			IF @LoadNumber LIKE 'D%' --Dealer Storage Loads are the only ones that start with 'D'
			BEGIN
				--04/17/2018 - CMK - now also need to put the units into the PortStorageVehicles table
				SELECT @PortStorageCustomerID = NULL
							
				SELECT @PortStorageCustomerID = CustomerID
				FROM Customer
				WHERE VendorNumber = @DestinationDealerCode
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting Port Storage CustomerID'
					GOTO Error_Encountered
				END
				IF @PortStorageCustomerID IS NULL
				BEGIN
					SELECT @ErrorID = 100012
					SELECT @Msg = 'DEALER '+@DestinationDealerCode+' NOT CONFIGURED FOR STORAGE! PLEASE CORRECT AND RETRY.'
					GOTO Error_Encountered
				END
							
				SELECT @VINCOUNT = COUNT(*)
				FROM PortStorageVehicles
				WHERE DateOut IS NULL
				AND VIN = @VIN
				AND SDCVehicleID = @VehicleID
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting PortStorageVehicle count'
					GOTO Error_Encountered
				END
							
				IF @VINCOUNT = 0
				BEGIN
					--add the vehicle to the PortStorageVehicles table
					INSERT INTO PortStorageVehicles(
						CustomerID,
						VehicleYear,
						Make,
						Model,
						Bodystyle,
						VIN,
						Color,
						VehicleLength,
						VehicleWidth,
						VehicleHeight,
						VehicleStatus,
						CustomerIdentification,
						SizeClass,
						BayLocation,
						EntryRate,
						EntryRateOverrideInd,
						PerDiemGraceDays,
						PerDiemGraceDaysOverrideInd,
						TotalCharge,
						DateIn,
						BilledInd,
						VINDecodedInd,
						RecordStatus,
						CreationDate,
						CreatedBy,
						CreditHoldInd,
						RequestPrintedInd,
						LastPhysicalDate,
						SDCVehicleID
					)
					VALUES(
						@PortStorageCustomerID,
						@VehicleYear,
						@Make,
						@Model,
						@Bodystyle,
						@VIN,
						@Color,		--Color,
						@VehicleLength,
						@VehicleWidth,
						@VehicleHeight,
						'InInventory',				--VehicleStatus,
						'',					--CustomerIdentification,
						'A',					--SizeClass,
						@BayLocation,
						0,					--EntryRate,
						0,					--EntryRateOverrideInd,
						0,					--PerDiemGraceDays,
						0,					--PerDiemGraceDaysOverrideInd,
						0,					--TotalCharge,
						CONVERT(date,CURRENT_TIMESTAMP),	--DateIn,
						0,					--BilledInd,
						@VINDecodedInd,
						'Active',				--RecordStatus,
						@CreationDate,
						@User,					--CreatedBy
						0,					--CreditHoldInd
						0,					--RequestPrintedInd
						@CreationDate,				--LastPhysicalDate
						@VehicleID				--SDCVehicleID
					)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Msg = 'ERROR CREATING STORAGE VEHICLE RECORD'
						GOTO Error_Encountered
					END
				END
			END
		END
	END
	
	--Add the ActionHistory record
	INSERT INTO ActionHistory (
		RecordID,
		RecordTableName,
		ActionType,
		Comments,
		CreationDate,
		CreatedBy
	)
	VALUES(
		@VehicleID,
		'Vehicle',
		'Vehicle Added To Load',
		'VIN '+@VIN+' Added To Load '+@LoadNumber,
		@CreationDate,
		@User
	)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered adding Action History record'
		GOTO Error_Encountered
	END
	
	--got through without any errors, so make sure the error id is zero
	SELECT @ErrorID = 0
	--print 'error encountered = 0'
	
	Error_Encountered:
	IF @ErrorID <> 0
	BEGIN
		--print 'about to do a rollback'
		ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Msg
	END
	ELSE
	BEGIN
		--print 'about to do a commit'
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Vehicle Processed Successfully'
	END

	IF @pReturnCode = 0
	BEGIN
		SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM'
	END
	
	SET @pReturnCode = @ReturnCode

	RETURN @ReturnCode
END

GO
