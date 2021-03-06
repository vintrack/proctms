USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateSDCDateInPickupDeliveryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[spGenerateSDCDateInPickupDeliveryData]
AS
BEGIN
	set nocount on

	DECLARE
	@BatchID		int,
	@VehicleID		int,
	@VIN			varchar(17),
	@VINKey			varchar(8),
	@RecordType		varchar(20),
	@StatusDate		datetime,
	@DriverID		int,
	@TruckID		int,
	@DriverNumber		varchar(10),
	@DriverName		varchar(60),
	@TruckNumber		varchar(10),
	@DamageCode1		varchar(5),
	@DamageCode2		varchar(5),
	@DamageCode3		varchar(5),
	@DamageCode4		varchar(5),
	@DamageCode5		varchar(5),
	@DamageCode6		varchar(5),
	@DamageCode7		varchar(5),
	@DamageCode8		varchar(5),
	@DamageCode9		varchar(5),
	@DamageCode10		varchar(5),
	@MasterFrom		varchar(10),
	@MasterLoads		varchar(10),
	@ControlNumber		varchar(20),
	@OriginZip		varchar(14),
	@OriginState		varchar(2),
	@OriginCity		varchar(30),
	@ExportedInd		int,
	@ExportedDate		datetime,
	@ExportedBy		varchar(20),
	@CreationDate		datetime,
	@CreatedBy		varchar(20),
	@DeliveryBayLocation	varchar(20),
	--processing variables
	@CustomerID		int,
	@ErrorID		int,
	@loopcounter		int,
	@LocationSubType	varchar(20),
	@Status			varchar(100),
	@ReturnCode		int,
	@ReturnMessage		varchar(100)	

	/************************************************************************
	*	spGenerateSDCDateInPickupDeliveryData				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the SDC Date In, Pickup and Delivery	*
	*	data that is used for updating FoxPro and also for the return	*
	*	files for SDC.							*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/24/2005 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextDIPUDEBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'BatchID Not Found'
		GOTO Error_Encountered2
	END

	--get the SOA Customer ID
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SOACustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SOA CustomerID'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'SOA CustomerID Not Found'
		GOTO Error_Encountered2
	END
	
	--cursor for the SOA delivery (Date In) records
	DECLARE DIPUDECursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, D.DriverID, T.TruckID, V.VIN, RIGHT(V.VIN,8),
		L.DropoffDate,
		CASE WHEN L2.OutsideCarrierLoadInd = 1 THEN D2.DriverNumber ELSE D.DriverNumber END,
		CASE WHEN L2.OutsideCarrierLoadInd = 1 THEN OC.CarrierName ELSE SUBSTRING(U.FirstName,1,1)+' '+U.LastName END,
		ISNULL(T.TruckNumber,'001'), VDD1.DamageCode, VDD2.DamageCode, VDD3.DamageCode, VDD4.DamageCode,
		VDD5.DamageCode, VDD6.DamageCode, VDD7.DamageCode, VDD8.DamageCode, VDD9.DamageCode,
		VDD10.DamageCode, 'EBR', R.DriverRunNumber, RIGHT(L2.LoadNumber,5),
		L3.Zip, L3.State, L3.City, L.DeliveryBayLocation
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.DropoffLocationID = V.DropoffLocationID
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Run R ON L2.RunID = R.RunID
		LEFT JOIN Driver D ON R.DriverID = D.DriverID
		LEFT JOIN Users U ON D.UserID = U.UserID
		LEFT JOIN OutsideCarrier OC ON L2.OutsideCarrierID = OC.OutsideCarrierID
		LEFT JOIN Driver D2 ON OC.OutsideCarrierID = D2.OutsideCarrierID 
		LEFT JOIN Truck T ON R.TruckID = T.TruckID
		LEFT JOIN RunStops RS ON R.RunID = RS.RunID
		AND RS.StopType = 'StartEmptyPoint'
		LEFT JOIN Location L3 ON RS.LocationID = L3.LocationID
		LEFT JOIN VehicleInspection VI ON L.VehicleID = VI.VehicleID
		AND VI.VehicleInspectionID = (SELECT TOP 1 VI2.VehicleInspectionID FROM VehicleInspection VI2 WHERE VI2.InspectionType = 3 AND VI2.VehicleID = V.VehicleID)
		LEFT JOIN VehicleDamageDetail VDD1 ON VI.VehicleInspectionID = VDD1.VehicleInspectionID
		AND VDD1.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
			FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID)
		LEFT JOIN VehicleDamageDetail VDD2 ON VI.VehicleInspectionID = VDD2.VehicleInspectionID
		AND VDD2.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
			FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
			AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID)
		LEFT JOIN VehicleDamageDetail VDD3 ON VI.VehicleInspectionID = VDD3.VehicleInspectionID
		AND VDD3.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
			FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
			AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID)
		LEFT JOIN VehicleDamageDetail VDD4 ON VI.VehicleInspectionID = VDD4.VehicleInspectionID
		AND VDD4.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
			FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
			AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID)
		LEFT JOIN VehicleDamageDetail VDD5 ON VI.VehicleInspectionID = VDD5.VehicleInspectionID
		AND VDD5.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
			FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
			AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID)
		LEFT JOIN VehicleDamageDetail VDD6 ON VI.VehicleInspectionID = VDD6.VehicleInspectionID
		AND VDD6.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
			FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
			AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID)
		LEFT JOIN VehicleDamageDetail VDD7 ON VI.VehicleInspectionID = VDD7.VehicleInspectionID
		AND VDD7.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
			FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
			AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD6.VehicleDamageDetailID)
		LEFT JOIN VehicleDamageDetail VDD8 ON VI.VehicleInspectionID = VDD8.VehicleInspectionID
		AND VDD8.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
			FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
			AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD6.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD7.VehicleDamageDetailID)
		LEFT JOIN VehicleDamageDetail VDD9 ON VI.VehicleInspectionID = VDD9.VehicleInspectionID
		AND VDD9.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
			FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
			AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD6.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD7.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD8.VehicleDamageDetailID)
		LEFT JOIN VehicleDamageDetail VDD10 ON VI.VehicleInspectionID = VDD10.VehicleInspectionID
		AND VDD10.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
			FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
			AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD6.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD7.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD8.VehicleDamageDetailID
			AND VDDa.VehicleDamageDetailID <> VDD9.VehicleDamageDetailID)
		WHERE (V.CustomerID = @CustomerID
		OR (V.CustomerID = 5709 AND V.DropoffLocationID = 11776)	--03/14/08 to get units coming from NEAT terminal
		OR (V.CustomerID = 5447 AND V.DropoffLocationID = 11776))	--03/14/08 to get SOA Manual units
		AND L.DropoffDate >= '01/01/2008'				--03/14/08 older units do not need reporting
		--AND V.VehicleStatus IN ('EnRoute','Delivered')
		AND V.VehicleStatus = 'Delivered'
		AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportDateInPickupDelivery WHERE RecordType = 'DI')
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN DIPUDECursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextDIPUDEBatchID'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting BatchID'
			GOTO Error_Encountered
	END

	--set the default values
	SELECT @ExportedInd = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = 'SQLServer'
	SELECT @RecordType = 'DI'
	
	FETCH DIPUDECursor INTO @VehicleID, @DriverID, @TruckID, @VIN, @VINKey,
		@StatusDate, @DriverNumber, @DriverName, @TruckNumber, @DamageCode1,
		@DamageCode2, @DamageCode3, @DamageCode4, @DamageCode5, @DamageCode6,
		@DamageCode7, @DamageCode8, @DamageCode9, @DamageCode10, @MasterFrom,
		@MasterLoads, @ControlNumber, @OriginZip, @OriginState, @OriginCity, @DeliveryBayLocation
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO ExportDateInPickupDelivery(
			BatchID,
			VehicleID,
			VIN,
			VINKey,
			RecordType,
			StatusDate,
			DriverID,
			TruckID,
			DriverNumber,
			DriverName,
			TruckNumber,
			DamageCode1,
			DamageCode2,
			DamageCode3,
			DamageCode4,
			DamageCode5,
			DamageCode6,
			DamageCode7,
			DamageCode8,
			DamageCode9,
			DamageCode10,
			MasterFrom,
			MasterLoads,
			ControlNumber,
			OriginZip,
			OriginState,
			OriginCity,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			CreationDate,
			CreatedBy,
			DeliveryBayLocation
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@VIN,
			@VINKey,
			@RecordType,
			@StatusDate,
			@DriverID,
			@TruckID,
			@DriverNumber,
			@DriverName,
			@TruckNumber,
			@DamageCode1,
			@DamageCode2,
			@DamageCode3,
			@DamageCode4,
			@DamageCode5,
			@DamageCode6,
			@DamageCode7,
			@DamageCode8,
			@DamageCode9,
			@DamageCode10,
			@MasterFrom,
			@MasterLoads,
			@ControlNumber,
			@OriginZip,
			@OriginState,
			@OriginCity,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
			@CreationDate,
			@CreatedBy,
			@DeliveryBayLocation
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating Date In record'
			GOTO Error_Encountered
		END
			
		FETCH DIPUDECursor INTO @VehicleID, @DriverID, @TruckID, @VIN, @VINKey,
			@StatusDate, @DriverNumber, @DriverName, @TruckNumber, @DamageCode1,
			@DamageCode2, @DamageCode3, @DamageCode4, @DamageCode5, @DamageCode6,
			@DamageCode7, @DamageCode8, @DamageCode9, @DamageCode10, @MasterFrom,
			@MasterLoads, @ControlNumber, @OriginZip, @OriginState, @OriginCity, @DeliveryBayLocation

	END --end of loop
	
	CLOSE DIPUDECursor
	DEALLOCATE DIPUDECursor
		
	--get the SDC Customer ID
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SDCCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SDC CustomerID'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'SDC CustomerID Not Found'
		GOTO Error_Encountered2
	END
	
	--cursor for the SDC Pickup records
	DECLARE DIPUDECursor CURSOR
		LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT V.VehicleID, D.DriverID, T.TruckID, V.VIN, RIGHT(V.VIN,8),
			L.PickupDate,
			CASE WHEN L2.OutsideCarrierLoadInd = 1 THEN D2.DriverNumber ELSE D.DriverNumber END,
			CASE WHEN L2.OutsideCarrierLoadInd = 1 THEN OC.CarrierName ELSE SUBSTRING(U.FirstName,1,1)+' '+U.LastName END,
			T.TruckNumber, VDD1.DamageCode, VDD2.DamageCode, VDD3.DamageCode, VDD4.DamageCode,
			VDD5.DamageCode, VDD6.DamageCode, VDD7.DamageCode, VDD8.DamageCode, VDD9.DamageCode,
			VDD10.DamageCode, 'DIV', R.DriverRunNumber, RIGHT(L2.LoadNumber,5),
			L3.Zip, L3.State, L3.City
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.PickupLocationID = V.PickupLocationID
			LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
			LEFT JOIN Run R ON L2.RunID = R.RunID
			LEFT JOIN Driver D ON R.DriverID = D.DriverID
			LEFT JOIN Users U ON D.UserID = U.UserID
			LEFT JOIN OutsideCarrier OC ON L2.OutsideCarrierID = OC.OutsideCarrierID
			LEFT JOIN Driver D2 ON OC.OutsideCarrierID = D2.OutsideCarrierID 
			LEFT JOIN Truck T ON R.TruckID = T.TruckID
			LEFT JOIN RunStops RS ON R.RunID = RS.RunID
			AND RS.StopType = 'StartEmptyPoint'
			LEFT JOIN Location L3 ON RS.LocationID = L3.LocationID
			LEFT JOIN VehicleInspection VI ON L.VehicleID = VI.VehicleID
			AND VI.VehicleInspectionID = (SELECT TOP 1 VI2.VehicleInspectionID FROM VehicleInspection VI2 WHERE VI2.InspectionType = 2 AND VI2.VehicleID = V.VehicleID)
			LEFT JOIN VehicleDamageDetail VDD1 ON VI.VehicleInspectionID = VDD1.VehicleInspectionID
			AND VDD1.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID)
			LEFT JOIN VehicleDamageDetail VDD2 ON VI.VehicleInspectionID = VDD2.VehicleInspectionID
			AND VDD2.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD3 ON VI.VehicleInspectionID = VDD3.VehicleInspectionID
			AND VDD3.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD4 ON VI.VehicleInspectionID = VDD4.VehicleInspectionID
			AND VDD4.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD5 ON VI.VehicleInspectionID = VDD5.VehicleInspectionID
			AND VDD5.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD6 ON VI.VehicleInspectionID = VDD6.VehicleInspectionID
			AND VDD6.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD7 ON VI.VehicleInspectionID = VDD7.VehicleInspectionID
			AND VDD7.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD6.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD8 ON VI.VehicleInspectionID = VDD8.VehicleInspectionID
			AND VDD8.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD6.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD7.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD9 ON VI.VehicleInspectionID = VDD9.VehicleInspectionID
			AND VDD9.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD6.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD7.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD8.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD10 ON VI.VehicleInspectionID = VDD10.VehicleInspectionID
			AND VDD10.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD6.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD7.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD8.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD9.VehicleDamageDetailID)
			WHERE V.CustomerID = @CustomerID
			AND V.VehicleStatus IN ('EnRoute','Delivered')
			AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportDateInPickupDelivery WHERE RecordType = 'PU')
			ORDER BY V.VehicleID

	OPEN DIPUDECursor
	
	--set the default values
	SELECT @ExportedInd = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = 'SQLServer'
	SELECT @RecordType = 'PU'
	
	FETCH DIPUDECursor INTO @VehicleID, @DriverID, @TruckID, @VIN, @VINKey,
		@StatusDate, @DriverNumber, @DriverName, @TruckNumber, @DamageCode1,
		@DamageCode2, @DamageCode3, @DamageCode4, @DamageCode5, @DamageCode6,
		@DamageCode7, @DamageCode8, @DamageCode9, @DamageCode10, @MasterFrom,
		@MasterLoads, @ControlNumber, @OriginZip, @OriginState, @OriginCity
	
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO ExportDateInPickupDelivery(
			BatchID,
			VehicleID,
			VIN,
			VINKey,
			RecordType,
			StatusDate,
			DriverID,
			TruckID,
			DriverNumber,
			DriverName,
			TruckNumber,
			DamageCode1,
			DamageCode2,
			DamageCode3,
			DamageCode4,
			DamageCode5,
			DamageCode6,
			DamageCode7,
			DamageCode8,
			DamageCode9,
			DamageCode10,
			MasterFrom,
			MasterLoads,
			ControlNumber,
			OriginZip,
			OriginState,
			OriginCity,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@VIN,
			@VINKey,
			@RecordType,
			@StatusDate,
			@DriverID,
			@TruckID,
			@DriverNumber,
			@DriverName,
			@TruckNumber,
			@DamageCode1,
			@DamageCode2,
			@DamageCode3,
			@DamageCode4,
			@DamageCode5,
			@DamageCode6,
			@DamageCode7,
			@DamageCode8,
			@DamageCode9,
			@DamageCode10,
			@MasterFrom,
			@MasterLoads,
			@ControlNumber,
			@OriginZip,
			@OriginState,
			@OriginCity,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating Pickup record'
			GOTO Error_Encountered
		END
			
		FETCH DIPUDECursor INTO @VehicleID, @DriverID, @TruckID, @VIN, @VINKey,
		@StatusDate, @DriverNumber, @DriverName, @TruckNumber, @DamageCode1,
		@DamageCode2, @DamageCode3, @DamageCode4, @DamageCode5, @DamageCode6,
		@DamageCode7, @DamageCode8, @DamageCode9, @DamageCode10, @MasterFrom,
		@MasterLoads, @ControlNumber, @OriginZip, @OriginState, @OriginCity

	END --end of loop


	CLOSE DIPUDECursor
	DEALLOCATE DIPUDECursor
		
	--cursor for the SDC Delivery records
	DECLARE DIPUDECursor CURSOR
		LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT V.VehicleID, D.DriverID, T.TruckID, V.VIN, RIGHT(V.VIN,8),
			L.DropoffDate,
			CASE WHEN L2.OutsideCarrierLoadInd = 1 THEN D2.DriverNumber ELSE D.DriverNumber END,
			CASE WHEN L2.OutsideCarrierLoadInd = 1 THEN OC.CarrierName ELSE SUBSTRING(U.FirstName,1,1)+' '+U.LastName END,
			T.TruckNumber, VDD1.DamageCode, VDD2.DamageCode, VDD3.DamageCode, VDD4.DamageCode,
			VDD5.DamageCode, VDD6.DamageCode, VDD7.DamageCode, VDD8.DamageCode, VDD9.DamageCode,
			VDD10.DamageCode, 'DIV', R.DriverRunNumber, RIGHT(L2.LoadNumber,5),
			L3.Zip, L3.State, L3.City
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.DropoffLocationID = V.DropoffLocationID
			LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
			LEFT JOIN Run R ON L2.RunID = R.RunID
			LEFT JOIN Driver D ON R.DriverID = D.DriverID
			LEFT JOIN Users U ON D.UserID = U.UserID
			LEFT JOIN OutsideCarrier OC ON L2.OutsideCarrierID = OC.OutsideCarrierID
			LEFT JOIN Driver D2 ON OC.OutsideCarrierID = D2.OutsideCarrierID 
			LEFT JOIN Truck T ON R.TruckID = T.TruckID
			LEFT JOIN RunStops RS ON R.RunID = RS.RunID
			AND RS.StopType = 'StartEmptyPoint'
			LEFT JOIN Location L3 ON RS.LocationID = L3.LocationID
			LEFT JOIN VehicleInspection VI ON L.VehicleID = VI.VehicleID
			AND VI.VehicleInspectionID = (SELECT TOP 1 VI2.VehicleInspectionID FROM VehicleInspection VI2 WHERE VI2.InspectionType = 3 AND VI2.VehicleID = V.VehicleID)
			LEFT JOIN VehicleDamageDetail VDD1 ON VI.VehicleInspectionID = VDD1.VehicleInspectionID
			AND VDD1.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID)
			LEFT JOIN VehicleDamageDetail VDD2 ON VI.VehicleInspectionID = VDD2.VehicleInspectionID
			AND VDD2.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD3 ON VI.VehicleInspectionID = VDD3.VehicleInspectionID
			AND VDD3.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD4 ON VI.VehicleInspectionID = VDD4.VehicleInspectionID
			AND VDD4.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD5 ON VI.VehicleInspectionID = VDD5.VehicleInspectionID
			AND VDD5.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD6 ON VI.VehicleInspectionID = VDD6.VehicleInspectionID
			AND VDD6.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD7 ON VI.VehicleInspectionID = VDD7.VehicleInspectionID
			AND VDD7.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD6.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD8 ON VI.VehicleInspectionID = VDD8.VehicleInspectionID
			AND VDD8.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD6.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD7.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD9 ON VI.VehicleInspectionID = VDD9.VehicleInspectionID
			AND VDD9.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD6.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD7.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD8.VehicleDamageDetailID)
			LEFT JOIN VehicleDamageDetail VDD10 ON VI.VehicleInspectionID = VDD10.VehicleInspectionID
			AND VDD10.VehicleDamageDetailID = (SELECT TOP 1 VDDa.VehicleDamageDetailID
				FROM VehicleDamageDetail VDDa WHERE VDDa.VehicleInspectionID  = VI.VehicleInspectionID
				AND VDDa.VehicleDamageDetailID <> VDD1.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD2.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD3.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD4.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD5.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD6.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD7.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD8.VehicleDamageDetailID
				AND VDDa.VehicleDamageDetailID <> VDD9.VehicleDamageDetailID)
			WHERE V.CustomerID = @CustomerID
			AND L.LegStatus = 'Delivered'
			AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportDateInPickupDelivery WHERE RecordType = 'DE')
			ORDER BY V.VehicleID

	OPEN DIPUDECursor
	
	--set the default values
	SELECT @ExportedInd = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = 'SQLServer'
	SELECT @RecordType = 'DE'
	
	FETCH DIPUDECursor INTO @VehicleID, @DriverID, @TruckID, @VIN, @VINKey,
		@StatusDate, @DriverNumber, @DriverName, @TruckNumber, @DamageCode1,
		@DamageCode2, @DamageCode3, @DamageCode4, @DamageCode5, @DamageCode6,
		@DamageCode7, @DamageCode8, @DamageCode9, @DamageCode10, @MasterFrom,
		@MasterLoads, @ControlNumber, @OriginZip, @OriginState, @OriginCity
		
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO ExportDateInPickupDelivery(
			BatchID,
			VehicleID,
			VIN,
			VINKey,
			RecordType,
			StatusDate,
			DriverID,
			TruckID,
			DriverNumber,
			DriverName,
			TruckNumber,
			DamageCode1,
			DamageCode2,
			DamageCode3,
			DamageCode4,
			DamageCode5,
			DamageCode6,
			DamageCode7,
			DamageCode8,
			DamageCode9,
			DamageCode10,
			MasterFrom,
			MasterLoads,
			ControlNumber,
			OriginZip,
			OriginState,
			OriginCity,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@VIN,
			@VINKey,
			@RecordType,
			@StatusDate,
			@DriverID,
			@TruckID,
			@DriverNumber,
			@DriverName,
			@TruckNumber,
			@DamageCode1,
			@DamageCode2,
			@DamageCode3,
			@DamageCode4,
			@DamageCode5,
			@DamageCode6,
			@DamageCode7,
			@DamageCode8,
			@DamageCode9,
			@DamageCode10,
			@MasterFrom,
			@MasterLoads,
			@ControlNumber,
			@OriginZip,
			@OriginState,
			@OriginCity,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating Pickup record'
			GOTO Error_Encountered
		END
			
		FETCH DIPUDECursor INTO @VehicleID, @DriverID, @TruckID, @VIN, @VINKey,
			@StatusDate, @DriverNumber, @DriverName, @TruckNumber, @DamageCode1,
			@DamageCode2, @DamageCode3, @DamageCode4, @DamageCode5, @DamageCode6,
			@DamageCode7, @DamageCode8, @DamageCode9, @DamageCode10, @MasterFrom,
			@MasterLoads, @ControlNumber, @OriginZip, @OriginState, @OriginCity

	END --end of loop


	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE DIPUDECursor
		DEALLOCATE DIPUDECursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE DIPUDECursor
		DEALLOCATE DIPUDECursor
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
