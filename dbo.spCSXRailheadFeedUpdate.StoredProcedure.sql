USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spCSXRailheadFeedUpdate]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spCSXRailheadFeedUpdate] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--CSXRailheadFeedImport table variables
	@CSXRailheadFeedImportID	int,
	@ActionCode			varchar(10),
	@Railyard			varchar(6),
	@Railcar			varchar(10),
	@VIN				varchar(17),
	@Dealer				varchar(6),
	@Area1				varchar(6),
	@Area2				varchar(4),
	@BayLocation			varchar(7),
	@Manufacturer			varchar(10),
	@UnloadDate			datetime,
	@UnloadTime			varchar(6),
	@ImportedInd			int,
	@VehicleYear			varchar(6),
	@Make				varchar(50),
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VINDecodedInd			int,
	@NewImportedInd			int,
	@VINCOUNT			int,
	@CustomerID			int,
	@AvailableInd			int,
	@ReleaseCode			varchar(10),
	@VehicleOriginID		int,
	@VehicleDestinationID		int,
	@VehiclePoolID			int,
	@OriginID			int,
	@DestinationID			int,
	@OrderID			int,
	@PoolID				int,
	@VehicleAvailableForPickupDate	datetime,
	@PlantCode			varchar(1),
	@VINBodyType			varchar(1),
	@VehicleType			varchar(1),
	@VINSquish			varchar(10),
	@SizeClass			varchar(1),
	@CustomerCode			varchar(70),
	@TotalOrderUnits		int,
	@TotalOrderChargeRate		int,
	@PreviousOrigin			int,
	@PreviousDestination		int,
	@OrderNumber			int,
	@OrderNumberPlusOne		int,
	@Reserved			int,
	@Available			int,
	@PoolSize			int,
	@RecordStatus			varchar(100),
	@Status				varchar(100),
	@VehicleID			int,
	@Count				int,
	@ReturnCode			int,
	@PoolRecordCount		int,
	@CurrentLegStatus		varchar(20),
	@ChryslerCustomerID		int,
	@SOACustomerID			int,
	@GMCustomerID			int,
	@ReturnMessage			varchar(100),
	@NeedsReviewInd			int,
	@DestinationCode		varchar(20),
	@ChargeRate			decimal(19,2),
	@CreationDate			datetime,
	@VWModelCode			varchar(20)
	
	/************************************************************************
	*	spCSXRailheadFeedUpdate						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the CSXRailheadFeedImport	*
	*	table and updates the existing vehicle records with the Bay	*
	*	Locations and also sets the AvailableForPickupDate in the	*
	*	Vehicle table when appropriate.					*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/19/2004 CMK    Initial version				*
	*									*
	************************************************************************/
	
	
	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @NeedsReviewInd = 0
	
	DECLARE CSXRailheadFeedCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT CSXRailheadFeedImportID, BatchID,
		ActionCode, Railyard, Railcar, VIN,
		Dealer, Area1, Area2, BayLocation,
		Manufacturer, UnloadDate, UnloadTime, ImportedInd,
		VehicleYear, Make, Model, Bodystyle, VehicleLength,
		VehicleWidth, VehicleHeight, VINDecodedInd
		FROM CSXRailheadFeedImport
		WHERE ImportedInd = 0
		AND CreationDate >= DATEADD(day,-15,CURRENT_TIMESTAMP)
		ORDER BY Manufacturer, Railyard, Dealer, VIN

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN CSXRailheadFeedCursor

	SELECT @ChryslerCustomerID = convert(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ChryslerCustomerID'
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR GETTING CHRYSLER CUSTOMERID'
		GOTO Error_Encountered
	END
	
	SELECT @SOACustomerID = convert(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SOACustomerID'
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR GETTING SOA CUSTOMERID'
		GOTO Error_Encountered
	END
	
	SELECT @GMCustomerID = convert(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'GMCustomerID'
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR GETTING GM CUSTOMERID'
		GOTO Error_Encountered
	END
	
	BEGIN TRAN

	FETCH CSXRailheadFeedCursor INTO @CSXRailheadFeedImportID, @BatchID,
		@ActionCode, @Railyard, @Railcar, @VIN,
		@Dealer, @Area1, @Area2, @BayLocation,
		@Manufacturer, @UnloadDate, @UnloadTime, @ImportedInd,
		@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength,
		@VehicleWidth, @VehicleHeight, @VINDecodedInd

	
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @NewImportedInd = 0
		SELECT @RecordStatus = 'Import Pending'
		
		SELECT @CustomerID = NULL
		
		IF @Make = 'Hyundai' AND @Manufacturer = 'Kia'
		BEGIN
			SELECT @Manufacturer = 'Hyundai'
		END
		ELSE IF @Make = 'Kia' AND @Manufacturer = 'Hyundai'
		BEGIN
			SELECT @Manufacturer = 'Kia'
		END
		
		SELECT @CustomerID = CONVERT(int,Value1),
		@AvailableInd = CONVERT(int,Value2)
		FROM Code
		WHERE CodeType = 'CSXRailCustomerCode'
		AND Code = @Manufacturer
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Customer ID From Code Table'
			GOTO Update_Record_Status
		END
		
		IF @CustomerID IS NULL
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Customer ID Not Found In Code Table'
			GOTO Update_Record_Status
		END
		
		--IF WE RUN INTO PROBLEMS WITH MULTIPLE VINS MATCHING
		--WE MAY NEED TO USE THE OWNER VALUE TO DECODE THE CUSTOMERID
			
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle V
		WHERE V.VIN = @VIN
		--AND CustomerID = @CustomerID
		AND V.CustomerID IN (SELECT CONVERT(int,Value1)
			FROM Code
			WHERE CodeType = 'CSXRailCustomerCode')
		AND V.PickupLocationID = (SELECT CONVERT(int,Value1) --03/03/2016 - CMK - added validation for origin
			FROM Code
			WHERE CodeType = 'CSXRailyardCode'
			AND Code = @Railyard)
		--AND VehicleStatus <> 'Delivered'
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @VINCOUNT = 1
		BEGIN
			SELECT TOP 1 @CustomerID = V.CustomerID, @VehicleID = V.VehicleID,
			@CurrentLegStatus = L.LegStatus, @VehicleOriginID = V.PickupLocationID,
			@VehicleDestinationID = V.DropoffLocationID, @ReleaseCode = V.ReleaseCode,
			@CreationDate = V.CreationDate, @VehiclePoolID = L.PoolID,
			@VehicleAvailableForPickupDate = AvailableForPickupDate
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			WHERE V.VIN = @VIN
			--AND V.CustomerID = @CustomerID
			AND V.CustomerID IN (SELECT CONVERT(int,Value1)
				FROM Code
				WHERE CodeType = 'CSXRailCustomerCode')
			AND V.PickupLocationID = (SELECT CONVERT(int,Value1) --03/03/2016 - CMK - added validation for origin
				FROM Code
				WHERE CodeType = 'CSXRailyardCode'
				AND Code = @Railyard)
			--AND V.VehicleStatus <> 'Delivered'
			AND V.VehicleID = L.VehicleID
			AND L.LegNumber = 1
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
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
				SET RailcarNumber = @Railcar,
				BayLocation = @BayLocation,
				UpdatedBy = 'CSX IMPORT',
				UpdatedDate = GetDate(),
				DateMadeAvailable = ISNULL(DateMadeAvailable,CONVERT(varchar(10),@UnloadDate,101)+' '+LEFT(@UnloadTime,2)+':'+SUBSTRING(@UnloadTime,3,2))
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
				SELECT @NeedsReviewInd = 1
				SELECT @NewImportedInd = 1
				SELECT @RecordStatus = 'Open Rail Vehicle Created Record, Bay Updated'
				GOTO Update_Record_Status
			END
			
			IF @Model LIKE 'Corvette%' AND @Dealer = '32449'
			BEGIN
				--TEMP CODE FOR CORVETTES NEEDING INSPECTION BEFORE SHIPPING
				UPDATE Vehicle
				SET RailcarNumber = @Railcar,
				BayLocation = @BayLocation,
				UpdatedBy = 'CSX IMPORT',
				UpdatedDate = GetDate(),
				DateMadeAvailable = ISNULL(DateMadeAvailable,CONVERT(varchar(10),@UnloadDate,101)+' '+LEFT(@UnloadTime,2)+':'+SUBSTRING(@UnloadTime,3,2))
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
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
					'CSX',		--RailCompany,
					@VIN,		--VIN,
					@Railyard,	--OriginCode,
					@Dealer,	--DestinationCode,
					'Open',		--ActionTaken,
					GetDate(),	--CreationDate,
					'CSX IMPORT'	--CreatedBy
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR CREATING LOG RECORD'
					GOTO Error_Encountered
				END
				
				SELECT @NeedsReviewInd = 1
				SELECT @NewImportedInd = 1
				SELECT @RecordStatus = 'Corvette Pending Inspection, Bay Location Updated'
			END
			ELSE IF @Dealer IN ('32177','77834','49308','59964','56278')
			BEGIN
				--TEMP CODE FOR PARKER UNITS NEEDING INSPECTION BEFORE SHIPPING
				UPDATE Vehicle
				SET RailcarNumber = @Railcar,
				BayLocation = @BayLocation,
				UpdatedBy = 'CSX IMPORT',
				UpdatedDate = GetDate(),
				DateMadeAvailable = ISNULL(DateMadeAvailable,CONVERT(varchar(10),@UnloadDate,101)+' '+LEFT(@UnloadTime,2)+':'+SUBSTRING(@UnloadTime,3,2))
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
						'CSX',		--RailCompany,
						@VIN,		--VIN,
						@Railyard,	--OriginCode,
						@Dealer,	--DestinationCode,
						'Open',		--ActionTaken,
						GetDate(),	--CreationDate,
						'CSX IMPORT'	--CreatedBy
					)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR CREATING LOG RECORD'
						GOTO Error_Encountered
					END
				END
				
				SELECT @NeedsReviewInd = 1
				SELECT @NewImportedInd = 1
				SELECT @RecordStatus = 'Parker Unit Pending Inspection, Bay Location Updated'
			END
			
			ELSE IF @Bodystyle LIKE '%Hellcat%'
			BEGIN
				--TEMP CODE FOR HELLCAT UNITS NEEDING INSPECTION BEFORE SHIPPING
				UPDATE Vehicle
				SET RailcarNumber = @Railcar,
				BayLocation = @BayLocation,
				UpdatedBy = 'CSX IMPORT',
				UpdatedDate = GetDate(),
				DateMadeAvailable = ISNULL(DateMadeAvailable,CONVERT(varchar(10),@UnloadDate,101)+' '+LEFT(@UnloadTime,2)+':'+SUBSTRING(@UnloadTime,3,2))
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
						'CSX',		--RailCompany,
						@VIN,		--VIN,
						@Railyard,	--OriginCode,
						@Dealer,	--DestinationCode,
						'Open',		--ActionTaken,
						GetDate(),	--CreationDate,
						'CSX IMPORT'	--CreatedBy
					)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR CREATING LOG RECORD'
						GOTO Error_Encountered
					END
				END
				
				SELECT @NeedsReviewInd = 1
				SELECT @NewImportedInd = 1
				SELECT @RecordStatus = 'Hellcat Unit Pending Inspection, Bay Location Updated'
			END
			
			ELSE IF @CurrentLegStatus = 'OnHold'
			BEGIN
				UPDATE Vehicle
				SET RailcarNumber = @Railcar,
				BayLocation = @BayLocation,
				UpdatedBy = 'CSX IMPORT',
				UpdatedDate = GetDate()
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
				
				SELECT @NewImportedInd = 1
				SELECT @RecordStatus = 'Vehicle On Hold, Bay Location Updated'
			END
			ELSE IF @CurrentLegStatus = 'EnRoute'
			BEGIN
				SELECT @NewImportedInd = 0
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'Vehicle Is En Route'
			END
			ELSE IF @CurrentLegStatus = 'Delivered'
			BEGIN
				SELECT @NewImportedInd = 0
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'Vehicle Is Delivered'
			END
			ELSE IF @CurrentLegStatus <> 'EnRoute' AND @CurrentLegStatus <> 'Delivered'
			BEGIN
				-- if the vehicle is a chrysler check the vehicle table to see if it has a valid shipping status
				IF @CustomerID = @ChryslerCustomerID
				BEGIN
					IF @ReleaseCode IN ('JB','JE','JJ','JS','KZ','SA')
					BEGIN
						SELECT @AvailableInd = 1
					END
					ELSE
					BEGIN
						SELECT @AvailableInd = 0
					END
				END
				
				--update logic here.
				IF @ActionCode = 'UNLOAD'
				BEGIN
					--get the origin id
					SELECT @OriginID = CONVERT(int,Value1)
					FROM Code
					WHERE CodeType = 'CSXRailyardCode'
					AND Code = @Railyard
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
						GOTO Error_Encountered
					END
			
					IF @OriginID IS NULL
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error Getting Origin ID'
						GOTO Update_Record_Status
					END
		
					-- check the origin and destination
					SELECT @DestinationCode = CustomerLocationCode
					FROM Location
					WHERE LocationID = @VehicleDestinationID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
						GOTO Error_Encountered
					END
					
					IF (@OriginID <> @VehicleOriginID) -- OR (@DestinationCode <> @Dealer AND @DestinationCode <> '0'+@Dealer)) AND DATALENGTH(@Dealer) > 0
					BEGIN
						/*
						-- see if we can find the new destination
						SELECT @DestinationID = NULL
								
						SELECT @DestinationID = LocationID
						FROM Location
						WHERE ParentRecordID = @CustomerID
						AND (CustomerLocationCode = @Dealer
						OR CustomerLocationCode = '0'+@Dealer)
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
							GOTO Error_Encountered
						END
									
						IF @DestinationID IS NULL
						BEGIN
							SELECT @RecordStatus = 'Error Getting Destination Location'
							GOTO Update_Record_Status
						END
						*/
						-- if there is an existing pool id, reduce the available count
						IF @AvailableInd = 1 OR @VehiclePoolID IS NOT NULL
						BEGIN
							IF @VehiclePoolID IS NOT NULL
							BEGIN
								UPDATE VehiclePool
								SET PoolSize = PoolSize - 1,
								Available = Available - 1
								WHERE VehiclePoolID = @PoolID
							END
								
							-- get/create the new pool id
							SELECT @Count = COUNT(*)
							FROM VehiclePool
							WHERE OriginID = @OriginID
							AND DestinationID = @VehicleDestinationID 
							AND CustomerID = @CustomerID
							IF @@Error <> 0
							BEGIN
								SELECT @ErrorID = @@ERROR
								SELECT @Status = 'ERROR GETTING POOL COUNT'
								GOTO Error_Encountered
							END
												
							IF @Count > 0
							BEGIN
								--get the pool id
								SELECT TOP 1 @PoolID = VehiclePoolID
								FROM VehiclePool
								WHERE OriginID = @OriginID
								AND DestinationID = @VehicleDestinationID 
								AND CustomerID = @CustomerID
								IF @@Error <> 0
								BEGIN
									SELECT @ErrorID = @@ERROR
									SELECT @Status = 'ERROR GETTING POOL ID'
									GOTO Error_Encountered
								END
													
								--update the pool size and available count
								UPDATE VehiclePool
								SET PoolSize = PoolSize + 1,
								Available = Available + 1,
								UpdatedDate = CURRENT_TIMESTAMP,
								UpdatedBy = 'CSX Import'
								WHERE VehiclePoolID = @PoolID
								IF @@Error <> 0
								BEGIN
									SELECT @ErrorID = @@ERROR
									SELECT @Status = 'ERROR UPDATING POOL RECORD'
									GOTO Error_Encountered
								END
							END
							ELSE
							BEGIN
								--create the pool
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
									@VehicleDestinationID,
									@CustomerID,
									1,
									0,
									1,
									CURRENT_TIMESTAMP,
									'CSX Import'
								)
								IF @@Error <> 0
								BEGIN
									SELECT @ErrorID = @@ERROR
									SELECT @Status = 'ERROR CREATING POOL RECORD'
									GOTO Error_Encountered
								END
											
								SELECT @PoolID = @@IDENTITY
							END
						END
						ELSE
						BEGIN
							SELECT @PoolID = NULL
						END
						-- get the charge rate
						SELECT @ChargeRate = NULL
								
						SELECT @ChargeRate = Rate
						FROM ChargeRate
						WHERE StartLocationID = @OriginID
						AND EndLocationID = @VehicleDestinationID
						AND CustomerID = @CustomerID
						AND RateType = 'Size A Rate'
						AND CASE WHEN @AvailableInd = 1 THEN @UnloadDate ELSE @CreationDate END >= StartDate
						AND CASE WHEN @AvailableInd = 1 THEN @UnloadDate ELSE @CreationDate END < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Status = 'ERROR GETTING CHARGE RATE'
							GOTO Error_Encountered
						END
						
						-- update the vehicle record to make the vehicle available and set the new destination
						UPDATE Vehicle
						SET VehicleStatus = CASE WHEN @AvailableInd = 1 THEN 'Available' ELSE VehicleStatus END,
						PickupLocationID = @OriginID,
						--DropoffLocationID = @DestinationID,
						AvailableForPickupDate = CASE WHEN @AvailableInd = 1 THEN @UnloadDate ELSE NULL END,
						BayLocation = @BayLocation,
						PriorityInd = 0, 
						ChargeRate = @ChargeRate,
						UpdatedBy = 'CSX IMPORT',
						UpdatedDate = CURRENT_TIMESTAMP,
						DateMadeAvailable = CASE WHEN @AvailableInd = 1 THEN ISNULL(DateMadeAvailable,CONVERT(varchar(10),@UnloadDate,101)+' '+LEFT(@UnloadTime,2)+':'+SUBSTRING(@UnloadTime,3,2)) ELSE DateMadeAvailable END
						WHERE VehicleID = @VehicleID
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
							GOTO Error_Encountered
						END
									
						-- update the leg record, set the new pool id, make the leg available and set the new destination
						UPDATE Legs
						SET PoolID = @PoolID,
						PickupLocationID = @OriginID,
						--DropoffLocationID = @DestinationID,
						DateAvailable = CASE WHEN @AvailableInd = 1 THEN @UnloadDate ELSE NULL END,
						LegStatus = CASE WHEN @AvailableInd = 1 THEN 'Available' ELSE LegStatus END,
						UpdatedDate = CURRENT_TIMESTAMP,
						UpdatedBy = 'CSX Import'
						WHERE VehicleID = @VehicleID
						AND LegNumber = 1
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Status = 'ERROR UPDATING LEG RECORD'
							GOTO Error_Encountered
						END
										
						SELECT @NewImportedInd = 1
						/*
						IF @OriginID <> @VehicleOriginID AND @DestinationID <> @VehicleDestinationID
						BEGIN
							SELECT @RecordStatus = 'ORIGIN & DESTINATION UPDATED'
						END
						ELSE 
						*/
						IF @OriginID <> @VehicleOriginID
						BEGIN
							SELECT @RecordStatus = 'ORIGIN UPDATED'
						END
						/*
						ELSE IF @DestinationID <> @VehicleDestinationID
						BEGIN
							SELECT @RecordStatus = 'DESTINATION UPDATED'
						END
						*/
						GOTO Update_Record_Status
					END
					IF @AvailableInd = 1
					BEGIN
						UPDATE Vehicle
						SET RailcarNumber = @Railcar,
						BayLocation = @BayLocation,
						AvailableForPickupDate = @UnloadDate,
						VehicleStatus = CASE WHEN VehicleStatus = 'Pending' THEN 'Available' ELSE VehicleStatus END,
						UpdatedBy = 'CSX IMPORT',
						UpdatedDate = GetDate(),
						DateMadeAvailable = ISNULL(DateMadeAvailable,CONVERT(varchar(10),@UnloadDate,101)+' '+LEFT(@UnloadTime,2)+':'+SUBSTRING(@UnloadTime,3,2))
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
						SET RailcarNumber = @Railcar,
						BayLocation = @BayLocation,
						UpdatedBy = 'CSX IMPORT',
						UpdatedDate = GetDate()
						WHERE VehicleID = @VehicleID
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
							GOTO Error_Encountered
						END
					END
					
					IF @AvailableInd = 1
					BEGIN
						IF @CurrentLegStatus = 'Pending'
						BEGIN
							--update the VehiclePool
							SELECT @PoolRecordCount = 0
						
							SELECT @PoolRecordCount = Count(*)
							FROM VehiclePool
							WHERE CustomerID = @CustomerID
							AND OriginID = @OriginID
							AND DestinationID = @VehicleDestinationID
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
									@VehicleDestinationID,
									@CustomerID,
									1,		--PoolSize
									0,		--Reserved
									1,		--Available
									GetDate(),	--CreationDate
									'CSX IMPORT'	--CreatedBy
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
								AND DestinationID = @VehicleDestinationID
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
						
							--update the first leg
							UPDATE Legs
							SET DateAvailable = @UnloadDate,
							LegStatus = 'Available',
							PoolID = @PoolID,
							UpdatedBy = 'CSX IMPORT',
							UpdatedDate = GetDate()
							WHERE VehicleID = @VehicleID
							AND LegNumber = 1
							IF @@Error <> 0
							BEGIN
								SELECT @ErrorID = @@ERROR
								SELECT @Status = 'ERROR UPDATING LEGS RECORD'
								GOTO Error_Encountered
							END
						END
					END
					SELECT @NewImportedInd = 1
					SELECT @RecordStatus = 'Imported'
					GOTO Update_Record_Status
				END
				ELSE IF @ActionCode = 'MOVE'
				BEGIN
					UPDATE Vehicle
					SET BayLocation = @BayLocation,
					UpdatedBy = 'CSX IMPORT',
					UpdatedDate = GetDate()
					WHERE VehicleID = @VehicleID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
						GOTO Error_Encountered
					END
					
					IF @VehicleAvailableForPickupDate IS NULL
					BEGIN
						SELECT @RecordStatus = 'NOT AVAILABLE - Bay Updated'
						SELECT @NewImportedInd = 1
						SELECT @NeedsReviewInd = 1
					END
					ELSE
					BEGIN
						SELECT @RecordStatus = 'Bay Location Updated'
						SELECT @NewImportedInd = 1
					END
					GOTO Update_Record_Status
				END
				ELSE
				BEGIN
					SELECT @NewImportedInd = 1
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'Invalid Action Code'
					GOTO Update_Record_Status
				END
			END
			ELSE
			BEGIN
				--if the vehicle is already enroute or delivered, just want to make sure that the available date is populated
				UPDATE Vehicle
				SET AvailableForPickupDate = @UnloadDate,
				UpdatedBy = 'CSX IMPORT',
				UpdatedDate = GetDate(),
				DateMadeAvailable = ISNULL(DateMadeAvailable,CONVERT(varchar(10),@UnloadDate,101)+' '+LEFT(@UnloadTime,2)+':'+SUBSTRING(@UnloadTime,3,2))
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
				
				UPDATE Legs
				SET DateAvailable = @UnloadDate,
				UpdatedBy = 'CSX IMPORT',
				UpdatedDate = GetDate()
				WHERE VehicleID = @VehicleID
				AND LegNumber = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING LEGS RECORD'
					GOTO Error_Encountered
				END
				SELECT @RecordStatus = 'Available Date Updated'
				SELECT @NewImportedInd = 1
				GOTO Update_Record_Status
			END
		END
		ELSE IF @VINCOUNT > 1
		BEGIN
			SELECT @NeedsReviewInd = 1
			SELECT @RecordStatus = 'MULTIPLE MATCHES FOUND FOR VIN'
			GOTO Update_Record_Status
		END
		ELSE
		BEGIN

			IF @Manufacturer NOT IN ('CHRYSLER','HONDA','KIA','HYUNDAI','SUBARU','GM', 'FORD')
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'VIN NOT FOUND'
				GOTO Update_Record_Status
			END
			
			SELECT @OriginID = NULL
			SELECT @DestinationID = NULL
		
			--get the Origin.
			SELECT @OriginID = CONVERT(int,Value1)
			FROM Code
			WHERE CodeType = 'CSXRailyardCode'
			AND Code = @Railyard
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
				GOTO Error_Encountered
			END
			IF @OriginID IS NULL
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'Orig Cd '+@Railyard+' Not Found'
				GOTO Update_Record_Status
			END
			
			IF DATALENGTH(@Dealer) > 0
			BEGIN
				IF @CustomerID = @SOACustomerID AND @Dealer = '200011' --want to use the common location
				BEGIN
					SELECT TOP 1 @DestinationID = CONVERT(int,ValueDescription)
					FROM SettingTable
					WHERE ValueKey = 'SOADiversifiedLocationID'
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
						GOTO Error_Encountered
					END
				END
				ELSE
				BEGIN
					--get the destination
					SELECT TOP 1 @DestinationID = LocationID
					FROM Location
					WHERE ParentRecordID = @CustomerID
					AND ParentRecordTable = 'Customer'
					AND CustomerLocationCode = @Dealer
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
							@Dealer,
							0,
							0,
							0,
							0,
							0,
							0,
							'Active',
							GetDate(),
							'CSX IMPORT',
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
			
			IF @Manufacturer = 'CHRYSLER'
			BEGIN
				SELECT @PlantCode = SUBSTRING(@VIN,11,1)
				SELECT @VINSquish = SUBSTRING(@VIN,1,8)+SUBSTRING(@VIN,10,2)
								
				IF @PlantCode IN ('D','H','T','P','M','Z','0','7')
				BEGIN
					IF SUBSTRING(@Model,1,7) IN ('Journey', 'Cheroke', 'Stelvio') OR @VINSquish = '3C4PDDAGET'
					BEGIN
						SELECT @SizeClass = 'B'
					END
					ELSE
					BEGIN
						SELECT @SizeClass = 'A'
					END
				END
				ELSE IF @PlantCode IN ('B','C','R','W','L','6')
				BEGIN
					SELECT @SizeClass = 'B'
				END
				ELSE IF @PlantCode IN ('F','G','J','N','S','E')
					BEGIN
					SELECT @SizeClass = 'C'
				END
				ELSE
				BEGIN
					SELECT @SizeClass = NULL
				END
			END
			ELSE IF @Manufacturer = 'VOLKSWAGEN'
			BEGIN
				-- also update spImportVolkswagenAvailableVehicles, spImportNORADRelease, spImportNSTruckerNotification, spImportI73 and spImportI95 when adding new model codes
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
			ELSE IF @Manufacturer = 'GM'
			BEGIN
				IF LEFT(@VIN,5) IN ('1GB0G','1GB3G','1GB6G','1GBYG','1GB0H','1GB3H','1GB6H','1GBYH','1GD07','1GD37','1GD67','1GDY7','1GD08','1GD38','1GD68','1GDY8')
				BEGIN
					SELECT @SizeClass = 'D'
				END
				ELSE IF LEFT(@VIN,4) IN ('5GAK','3GYF','1GNA','1GNF','2GNA','2GNF','KL77','1GNK','1GKK','2GKA','2GKF','1GYF','1GYK','1GNE')
				BEGIN
					SELECT @SizeClass = 'B'
				END
				ELSE IF LEFT(@VIN,3) IN ('1GY','1GA','1GB','1GC','1GN','1GD','1GJ','1GK','1GT','2GB','2GC','2GT','3GT','3GD','3GC', '3N6')
				BEGIN
					SELECT @SizeClass = 'C'
				END
				ELSE
				BEGIN
					SELECT @SizeClass = 'A'
				END
			END
			ELSE IF @Manufacturer = 'FORD'
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
			ELSE
			BEGIN
				SELECT @SizeClass = 'A'
			END
					
			SELECT @ChargeRate = NULL
			--From these values we can get the financial information.
			SELECT @ChargeRate = Rate
			FROM ChargeRate
			WHERE StartLocationID = @OriginID
			AND EndLocationID = @DestinationID
			AND CustomerID = @CustomerID
			AND RateType = 'Size '+@SizeClass+' Rate'
			AND @UnloadDate >= StartDate
			AND @UnloadDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
			
			--only insert an order record for the ones with different origin and destination values
			IF @OriginID <> ISNULL(@PreviousOrigin,0) OR @DestinationID <> ISNULL(@PreviousDestination,0)
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
					'CSX IMPORT',	--CreatedBy,
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
				ReleaseCode,
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
				@Railcar,			--RailCarNumber,
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
				'CSX IMPORT',			--CreatedBy
				NULL,				--UpdatedDate,
				NULL,				--UpdatedBy
				0,				--CreditHoldInd
				'SA',				--ReleaseCode
				0,				--PickupNotificationSentInd
				0,				--STIDeliveryNotificationSentInd
				0,				--BillOfLadingSentInd
				0,				--DealerHoldOverrideInd
				0,				--MiscellaneousAdditive
				0,				--FuelSurcharge
				0,				--AccessoriesCompleteInd,
				0,				--PDICompleteInd
				0,				--FinalShipawayInspectionDoneInd
				CONVERT(varchar(10),@UnloadDate,101)+' '+LEFT(@UnloadTime,2)+':'+SUBSTRING(@UnloadTime,3,2)	--DateMadeAvailable
						
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
			/* -- 3/29/2012 - CMK - all created units are now pending
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
					'CSX IMPORT'	--CreatedBy
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
				'CSX IMPORT', 	--CreatedBy
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
				'CSX',		--RailCompany,
				@VIN,		--VIN,
				@Railyard,	--OriginCode,
				@Dealer,	--DestinationCode,
				'Open',		--ActionTaken,
				GetDate(),	--CreationDate,
				'CSX IMPORT'	--CreatedBy
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR CREATING LOG RECORD'
				GOTO Error_Encountered
			END
			
			SELECT @RecordStatus = 'VEHICLE CREATED'
			SELECT @NewImportedInd = 1
		END
		--update logic here.
		Update_Record_Status:
		UPDATE CSXRailheadFeedImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @NewImportedind,
		ImportedDate = CASE WHEN @NewImportedInd = 1 THEN GetDate() ELSE NULL END,
		ImportedBy = CASE WHEN @NewImportedInd = 1 THEN @UserCode ELSE NULL END
		WHERE CSXRailheadFeedImportID = @CSXRailheadFeedImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH CSXRailheadFeedCursor INTO @CSXRailheadFeedImportID, @BatchID,
		@ActionCode, @Railyard, @Railcar, @VIN,
		@Dealer, @Area1, @Area2, @BayLocation,
		@Manufacturer, @UnloadDate, @UnloadTime, @ImportedInd,
		@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength,
		@VehicleWidth, @VehicleHeight, @VINDecodedInd

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE CSXRailheadFeedCursor
		DEALLOCATE CSXRailheadFeedCursor
		--PRINT 'ImportRailheadFeed Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE CSXRailheadFeedCursor
		DEALLOCATE CSXRailheadFeedCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		--PRINT 'ImportRailheadFeed Error_Encountered =' + STR(@ErrorID)
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
