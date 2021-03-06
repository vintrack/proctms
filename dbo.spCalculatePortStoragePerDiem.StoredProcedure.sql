USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spCalculatePortStoragePerDiem]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spCalculatePortStoragePerDiem] (@PortStorageVehiclesID int, @UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@DateIn			varchar(10),
	@DateOut		datetime,
	@CustomerID		int,
	@PerDiem		decimal(19,2),
	@PerDiemGraceDays	int,
	@ProcessingDate		datetime,
	@TotalPerDiem		decimal(19,2),
	@CreationDate		datetime,
	@CreatedBy		varchar(20),
	@Count			int,
	@RecordCount		int,
	@Status			varchar(1000),
	@ReturnCode		int,
	@ReturnMessage		varchar(1000)
	

	/************************************************************************
	*	spCalculatePortStoragePerDiem					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure creates the PortStoragePerDiem records for the	*
	*	vehicle passed in to the system.				*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	11/15/2006 CMK    Initial version				*
	*									*
	************************************************************************/
	
	BEGIN TRAN
	
	--see if the vin already exists as an open record.
	SELECT @RecordCount = COUNT(*)
	FROM PortStorageVehicles
	WHERE PortStorageVehiclesID = @PortStorageVehiclesID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error getting vin count'
		GOTO Error_Encountered
	END
	
	IF @RecordCount = 0
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Status = 'VIN Not Found'
		GOTO Error_Encountered
	END
	
	SELECT @CustomerID = CustomerID,
	@DateIn = CONVERT(varchar(10),DateIn,101),
	@DateOut = CONVERT(varchar(10),DateOut,101),
	@PerDiemGraceDays = PerDiemGraceDays
	FROM PortStorageVehicles
	WHERE PortStorageVehiclesID = @PortStorageVehiclesID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error getting vehicle details'
		GOTO Error_Encountered
	END
	
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Customer ID Missing'
		GOTO Error_Encountered
	END
	IF @DateIn IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'Date In Missing'
		GOTO Error_Encountered
	END
	IF @DateOut IS NULL
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Status = 'Date Out Missing'
		GOTO Error_Encountered
	END
	IF @DateOut < @DateIn
	BEGIN
		SELECT @ErrorID = 100004
		SELECT @Status = 'Date Out Before Date In'
		GOTO Error_Encountered
	END
	
	IF @PerDiemGraceDays IS NULL
	BEGIN
		SELECT @ErrorID = 100005
		SELECT @Status = 'Per Diem Grace Days Missing'
		GOTO Error_Encountered
	END
	
	SELECT @ErrorID = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @UserCode
	SELECT @ProcessingDate = @DateIn
	SELECT @Count = 0
	SELECT @TotalPerDiem = 0
	
	WHILE @ProcessingDate <= @DateOut
	BEGIN
		SELECT @Count = @Count + 1
		
		SELECT @RecordCount = COUNT(*)
		FROM PortStorageRates
		WHERE @ProcessingDate >= StartDate
		AND @ProcessingDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
		AND CustomerID = @CustomerID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Rate Record Count'
			GOTO Error_Encountered
		END
		--get the per diem rate from the PortStorageRates table
		SELECT TOP 1 @PerDiem = PerDiem
		FROM PortStorageRates
		WHERE @ProcessingDate >= StartDate
		AND @ProcessingDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
		AND CustomerID = @CustomerID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Per Diem'
			GOTO Error_Encountered
		END
		IF @PerDiem IS NULL
		BEGIN
			SELECT @ErrorID = 100006
			SELECT @Status = 'Per Diem Rate Missing'
			GOTO Error_Encountered
		END
		
		IF @Count <= @PerDiemGraceDays
		BEGIN
			SELECT @PerDiem = 0
		END
		
		--see if a per diem rate record exists for this date
		SELECT @RecordCount = COUNT(*)
		FROM PortStoragePerDiem
		WHERE PortStorageVehiclesID = @PortStorageVehiclesID
		AND PerDiemDate = @ProcessingDate
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Per Diem Record Count'
			GOTO Error_Encountered
		END
		
		IF @RecordCount = 0
		BEGIN
			--create the PortStoragePerDiem record
			INSERT INTO PortStoragePerDiem (
				PortStorageVehiclesID,
				PerDiemDate,
				PerDiem,
				PerDiemOverrideInd,
				CreationDate,
				CreatedBy
			)
			VALUES (
				@PortStorageVehiclesID,
				@ProcessingDate,
				@PerDiem,
				0,		--PerDiemOverrideInd
				@CreationDate,
				@CreatedBy
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Inserting Per Diem Record'
				GOTO Error_Encountered
			END
		END
		
		End_Of_Loop:
		SELECT @TotalPerDiem = @TotalPerDiem + @PerDiem
		SELECT @ProcessingDate = DATEADD(day,1,@ProcessingDate)
	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		IF @ErrorID IN (100000,100001,100002,100003,100004,100005)
		BEGIN
			COMMIT TRAN
		END
		ELSE
		BEGIN
			ROLLBACK TRAN
		END	
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Do_Return:
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @TotalPerDiem AS TotalPerDiem

	RETURN
END
GO
