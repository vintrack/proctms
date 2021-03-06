USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spCalculateAutoportExportPerDiem]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spCalculateAutoportExportPerDiem] (@AutoportExportVehiclesID int, @UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@DateReceived		varchar(10),
	@DateShipped		datetime,
	@CustomerID		int,
	@PerDiem		decimal(19,2),
	@PerDiemGraceDays	int,
	@ProcessingDate		datetime,
	@SizeClass		varchar(1),
	@TotalPerDiem		decimal(19,2),
	@CreationDate		datetime,
	@CreatedBy		varchar(20),
	@Count			int,
	@RecordCount		int,
	@Status			varchar(1000),
	@ReturnCode		int,
	@ReturnMessage		varchar(1000)
	

	/************************************************************************
	*	spCalculateAutoportExportPerDiem				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure creates the AutoportExportPerDiem records for the*
	*	vehicle passed in to the system.				*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/14/2007 CMK    Initial version				*
	*									*
	************************************************************************/
	
	BEGIN TRAN
	
	--see if the vin already exists as an open record.
	SELECT @RecordCount = COUNT(*)
	FROM AutoportExportVehicles
	WHERE AutoportExportVehiclesID = @AutoportExportVehiclesID
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
	@DateReceived = CONVERT(varchar(10),DateReceived,101),
	@DateShipped = CONVERT(varchar(10),DateShipped,101),
	@PerDiemGraceDays = PerDiemGraceDays,
	@SizeClass = SizeClass
	FROM AutoportExportVehicles
	WHERE AutoportExportVehiclesID = @AutoportExportVehiclesID
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
	IF @DateReceived IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'Date Received Missing'
		GOTO Error_Encountered
	END
	IF @DateShipped IS NULL
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Status = 'Date Shipped Missing'
		GOTO Error_Encountered
	END
	IF @DateShipped < @DateReceived
	BEGIN
		SELECT @ErrorID = 100004
		SELECT @Status = 'Date Shipped Before Date Received'
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
	SELECT @ProcessingDate = @DateReceived
	SELECT @Count = 0
	SELECT @TotalPerDiem = 0
	
	WHILE @ProcessingDate <= @DateShipped
	BEGIN
		SELECT @Count = @Count + 1
		
		SELECT @RecordCount = COUNT(*)
		FROM AutoportExportRates
		WHERE @ProcessingDate >= StartDate
		AND @ProcessingDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
		AND CustomerID = @CustomerID
		AND RateType = 'Size '+@SizeClass+' Rate'
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Rate Record Count'
			GOTO Error_Encountered
		END
		--get the per diem rate from the AutoportExportRates table
		SELECT TOP 1 @PerDiem = PerDiem
		FROM AutoportExportRates
		WHERE @ProcessingDate >= StartDate
		AND @ProcessingDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
		AND CustomerID = @CustomerID
		AND RateType = 'Size '+@SizeClass+' Rate'
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
		FROM AutoportExportPerDiem
		WHERE AutoportExportVehiclesID = @AutoportExportVehiclesID
		AND PerDiemDate = @ProcessingDate
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Per Diem Record Count'
			GOTO Error_Encountered
		END
		
		IF @RecordCount = 0
		BEGIN
			--create the AutoportExportPerDiem record
			INSERT INTO AutoportExportPerDiem (
				AutoportExportVehiclesID,
				PerDiemDate,
				PerDiem,
				PerDiemOverrideInd,
				CreationDate,
				CreatedBy
			)
			VALUES (
				@AutoportExportVehiclesID,
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
