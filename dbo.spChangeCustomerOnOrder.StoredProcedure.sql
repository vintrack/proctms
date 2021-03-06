USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spChangeCustomerOnOrder]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spChangeCustomerOnOrder] (
	@OrderID 		int,
	@NewCustomerID		int,
	@NewPickupLocationID	int,
	@NewDropoffLocationID	int,
	@UserCode 		varchar(20)
	)
AS
BEGIN
	set nocount on

	DECLARE
	@OriginalCustomerID		int,
	@OriginalPickupLocationID	int,
	@OriginalDropoffLocationID	int,
	@OriginalPoolID			int,
	@NewPoolID			int,
	@VehicleID			int,
	@LegsID				int,
	@VehicleStatus			varchar(20),
	@LegStatus			varchar(20),
	@LegNumber			int,
	@FinalLegInd			int,
	@LoadID				int,
	@RunID				int,
	@RunStatus			varchar(20),
	@PayrollID			int,
	@DriverName			varchar(60),
	@DriversToRefresh		varchar(500),
	@RunsToRepair			varchar(200),
	@PayrollRecordsToRepair		varchar(200),
	@DateAvailable			datetime,
	@PoolRecordCount		int,
	@UpdatedDate			datetime,
	@ErrorID			int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@Status				varchar(100),
	@loopcounter			int
	
	
	/************************************************************************
	*	spChangeCustomerOnOrder						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure changes the CustomerID, PickupLocationID and 	*
	*	DropoffLocationID and associated tables for the supplied order.	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/29/2006 CMK    Initial version				*
	*									*
	************************************************************************/
	
	BEGIN TRAN
	
	SELECT @RunsToRepair = ''
	SELECT @PayrollRecordsToRepair = ''
	SELECT @DriversToRefresh = ''
	SELECT @ErrorID = 0
	
	--get the current order values
	SELECT @OriginalCustomerID = CustomerID, @OriginalPickupLocationID = PickupLocation,
	@OriginalDropoffLocationID = DropoffLocation
	FROM Orders
	WHERE OrdersID = @OrderID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR GETTING ORDER VALUES'
		GOTO Error_Encountered2
	END
	
	--update the order records
	UPDATE Orders
	SET CustomerID = @NewCustomerID,
	PickupLocation = @NewPickupLocationID,
	DropoffLocation = @NewDropoffLocationID,
	UpdatedDate = @UpdatedDate,
	UpdatedBy = @UserCode
	WHERE OrdersID = @OrderID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR UPDATING ORDER RECORD'
		GOTO Error_Encountered2
	END
	
	--update the vehicle, legs, loads, run and runstops records	
	DECLARE VehicleList CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L.LegsID, V.VehicleStatus, L.LegStatus, L.LegNumber,
		L.FinalLegInd, L.PickupLocationID, L.DropoffLocationID,
		L.LoadID, L.RunID, L.PoolID, V.AvailableForPickupDate
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		WHERE V.OrderID = @OrderID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN VehicleList
	
	FETCH VehicleList INTO @VehicleID, @LegsID, @VehicleStatus, @LegStatus, @LegNumber,
		@FinalLegInd, @OriginalPickupLocationID, @OriginalDropoffLocationID, @LoadID,
		@RunID, @OriginalPoolID, @DateAvailable
		
	WHILE @@FETCH_STATUS = 0
	BEGIN

		--update the vehicle record
		UPDATE Vehicle
		SET CustomerID = @NewCustomerID,
		PickupLocationID = @NewPickupLocationID,
		DropoffLocationID = @NewDropoffLocationID,
		UpdatedDate = @UpdatedDate,
		UpdatedBy = @UserCode
		WHERE VehicleID = @VehicleID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
			GOTO Error_Encountered
		END
		
		--if there is an old pool, reduce it by 1
		IF @OriginalPoolID IS NOT NULL
		BEGIN
			UPDATE VehiclePool
			SET PoolSize = PoolSize - 1,
			Available = Available - 1,
			UpdatedDate = @UpdatedDate,
			UpdatedBy = @UserCode
			WHERE VehiclePoolID = @OriginalPoolID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING OLD POOL'
				GOTO Error_Encountered
			END
		
		END
		
		--if the vehicle is not pending, and is not in a load, get the new pool
		IF @DateAvailable IS NOT NULL AND @LoadID IS NULL
		BEGIN
			--update the VehiclePool
			SELECT @PoolRecordCount = 0
									
			SELECT @PoolRecordCount = Count(*)
			FROM VehiclePool
			WHERE CustomerID = @NewCustomerID
			AND OriginID = @NewPickupLocationID
			AND DestinationID = @NewDropoffLocationID
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
					@NewPickupLocationID,
					@NewDropoffLocationID,
					@NewCustomerID,
					1,		--PoolSize
					0,		--Reserved
					1,		--Available
					@UpdatedDate,	--CreationDate
					@UserCode	--CreatedBy
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR CREATING POOL RECORD'
					GOTO Error_Encountered
				END
				SELECT @NewPoolID = @@Identity
			END
			ELSE
			BEGIN
				SELECT @NewPoolID = VehiclePoolID
				FROM VehiclePool
				WHERE CustomerID = @NewCustomerID
				AND OriginID = @NewPickupLocationID
				AND DestinationID = @NewDropoffLocationID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING POOL ID'
					GOTO Error_Encountered
				END
								
				UPDATE VehiclePool
				SET PoolSize = PoolSize + 1,
				Available = Available + 1,
				UpdatedDate = @UpdatedDate,
				UpdatedBy = @UserCode
				WHERE VehiclePoolID = @NewPoolID
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
			SELECT @NewPoolID = NULL
		END
		
		--update the leg record
		IF @LegNumber = 1 AND @FinalLegInd = 1
		BEGIN
			UPDATE Legs
			SET PickupLocationID = @NewPickupLocationID,
			DropoffLocationID = @NewDropoffLocationID,
			PoolID = @NewPoolID,
			UpdatedDate = @UpdatedDate,
			UpdatedBy = @UserCode
			WHERE LegsID = @LegsID
		END
		ELSE
		BEGIN
			SELECT @ErrorID = 100001
			SELECT @Status = 'ONE OF THE VEHICLES HAS A SPLIT, PLEASE UPDATE MANUALLY'
			GOTO Error_Encountered
		END
		
		FETCH VehicleList INTO @VehicleID, @LegsID, @VehicleStatus, @LegStatus, @LegNumber,
			@FinalLegInd, @OriginalPickupLocationID, @OriginalDropoffLocationID, @LoadID,
			@RunID, @OriginalPoolID, @DateAvailable

	END --end of loop
	
	--get a list of the runs and payroll ids
	
	CLOSE VehicleList
	DEALLOCATE VehicleList
		
	DECLARE VehicleList CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT DISTINCT R.RunID, P.PayrollID,
		CASE WHEN U.UserID IS NOT NULL THEN U.FirstName+' '+U.LastName ELSE '' END,
		R.RunStatus
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		LEFT JOIN Run R ON L.RunID = R.RunID
		LEFT JOIN Payroll P ON R.RunID = P.RunID
		LEFT JOIN Driver D ON R.DriverID = D.DriverID
		LEFT JOIN Users U ON D.UserID = U.UserID
		WHERE V.OrderID = @OrderID
		AND L.RunID IS NOT NULL

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN VehicleList
	
	FETCH VehicleList INTO @RunID, @PayrollID, @DriverName, @RunStatus
		
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @PayrollID IS NOT NULL AND @PayrollID <> 0
		BEGIN
			--if the run is in payroll, add it to the in payroll list
			IF DATALENGTH(@PayrollRecordsToRepair) > 0
			BEGIN
				SELECT @PayrollRecordsToRepair = @PayrollRecordsToRepair+', '+CONVERT(varchar(10),@PayrollID)
			END
			ELSE
			BEGIN
				SELECT @PayrollRecordsToRepair = CONVERT(varchar(10),@PayrollID)
			END
	
		END
		ELSE IF @DriverName IS NOT NULL AND @RunStatus = 'Open'
		BEGIN
			--if there is a driver, add it to the driver list
			IF DATALENGTH(@DriversToRefresh) > 0
			BEGIN
				SELECT @DriversToRefresh = @DriversToRefresh+', '+@DriverName
			END
			ELSE
			BEGIN
				SELECT @DriversToRefresh = @DriverName
			END
		END
		ELSE
		BEGIN
			--if there is a run record, add it to the in run list
						SELECT @RunsToRepair = ''
			IF DATALENGTH(@RunsToRepair) > 0
			BEGIN
				SELECT @RunsToRepair = @RunsToRepair+', '+CONVERT(varchar(10),@RunID)
			END
			ELSE
			BEGIN
				SELECT @RunsToRepair = CONVERT(varchar(10),@RunID)
			END
						
		END
		
		FETCH VehicleList INTO @RunID, @PayrollID, @DriverName, @RunStatus
		
	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE VehicleList
		DEALLOCATE VehicleList
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully.'
		IF DATALENGTH(@RunsToRepair) > 0
		BEGIN
			SELECT @ReturnMessage = @ReturnMessage+' The following runs need to be looked at: '+@RunsToRepair
		END
		IF DATALENGTH(@DriversToRefresh) > 0
		BEGIN
			SELECT @ReturnMessage = @ReturnMessage+' The following drivers need to refresh their phones: '+@DriversToRefresh
		END
		IF DATALENGTH(@PayrollRecordsToRepair) > 0
		BEGIN
			SELECT @ReturnMessage = @ReturnMessage+' The following payroll records need to be looked at: '+@PayrollRecordsToRepair
		END
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE VehicleList
		DEALLOCATE VehicleList
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END
	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'BadExit'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END
	
	Do_Return:
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	
	RETURN
END
GO
