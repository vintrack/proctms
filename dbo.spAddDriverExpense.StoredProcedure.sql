USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddDriverExpense]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spAddDriverExpense](
	@DriverID			int,
	@ItemDate			datetime,
	@Type				int,
	@Amount				decimal(19, 2),
	@ItemDescription		varchar(50), 
	@TruckNum			varchar(20), 
	@CreatedBy			varchar(20) 
	)
AS
BEGIN
	/************************************************************************
	*	spAddDriverExpense						*
	*									*
	*	Description							*
	*	-----------							*
	*	Adds a new Expense record.				 	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	09/27/2005 JEP    Initial version				*
	*	12/05/2007 CMK    Added Per Diem Duplicate Check		*
	*	12/08/2015 CMK    Added validation for Mobile App Use		*
	*	01/12/2018 CMK    Added Dorm Per Diem Expense Type and Location *
	*			  Requirement for Sleeper Per Diem		*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	
		@ExpenseID		int,
		@TruckID		int,
		@BackupReceivedInd	int,
		@PaidInd		int,
		@CreationDate		datetime,
		@UpdatedDate		datetime,
		@UpdatedBy		varchar(20),
		@OutsideCarrierInd	int,
		@ReturnCode		int,
		@ReturnMessage		varchar(50),
		@ErrorID		int,
		@Msg			varchar(50),
		@Count			int,
		@SleeperCabInd		int,
		@BackupRequiredInd	int

	SELECT @Count = 0
	SELECT @BackupReceivedInd = 0
	SELECT @ItemDate = CONVERT(varchar(10),@ItemDate,101)
	SET @ExpenseID = 0
	SET @CreationDate = CURRENT_TIMESTAMP
	SET @UpdatedDate = CURRENT_TIMESTAMP
	SET @UpdatedBy = @CreatedBy
	SELECT @SleeperCabInd = 0
	
	BEGIN TRAN
	
	--make sure that it is not an outside carrier trying to enter an expense item
	SELECT TOP 1 @OutsideCarrierInd = OutsideCarrierInd
	FROM Driver
	WHERE DriverID = @DriverID
	IF @@ERROR <> 0
	BEGIN
	SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Getting OutsideCarrierInd'
		GOTO Error_Encountered
	END
		
	IF @OutsideCarrierInd = 1
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Msg = 'Outside Carriers Cannot Enter Expenses'
		GOTO Error_Encountered
	END
	
	--lookup truck ID from truck num
	SET @TruckID = 0
	
	SELECT TOP 1 @TruckID = TruckID
	FROM Truck
	WHERE TruckNumber = @TruckNum
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Getting Truck ID'
		GOTO Error_Encountered
	END
	
	--make sure it is not a future date
	IF @ItemDate >= DATEADD(day,1,CONVERT(varchar(10),CURRENT_TIMESTAMP,101))
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Msg = 'Expenses Cannot Be Future Dated'
		GOTO Error_Encountered
	END
	
	-- make sure it is a valid expense type
	SELECT @Count = COUNT(*)
	FROM Code
	WHERE CodeType = 'DriverExpenseType'
	AND Code = CONVERT(varchar(10),@Type)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Getting Expense Info From Code'
		GOTO Error_Encountered
	END
	
	IF @Count = 0
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Msg = 'Invalid Expense Type'
		GOTO Error_Encountered
	END
	ELSE
	BEGIN
		--if it is a valid expense type get the BackupRequiredInd
		SELECT TOP 1 @BackupRequiredInd = CONVERT(int,Value2)
		FROM Code
		WHERE CodeType = 'DriverExpenseType'
		AND Code = CONVERT(varchar(10),@Type)
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting Backup Required Indicator'
			GOTO Error_Encountered
		END
	END
	
	--getting some bad characters in the description, need to clean
	SELECT @ItemDescription = REPLACE(@ItemDescription,char(9),'')
	SELECT @ItemDescription = REPLACE(@ItemDescription,char(10),'')
	SELECT @ItemDescription = REPLACE(@ItemDescription,char(13),'')
	
	
	--NEED MOPHILLY TO MODIFY WEBSERVICE TO HANDLE -1 PaidInd BEFORE IMPLEMENTING
	
	--IF @BackupRequiredInd = 0
	--BEGIN
	--	SELECT @PaidInd = -1
	--END
	--ELSE
	--BEGIN
		SELECT @PaidInd = 0
	--END
	
	-- error if perdiem already exists for that date
	IF @Type = 0
	BEGIN
		--make sure we only have one per diem for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 0
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100004
			SELECT @Msg = 'Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
		
		--make sure we do not have the combined sleeper/travel per diem for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 10
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100005
			SELECT @Msg = 'Sleeper/Travel Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
	END
	ELSE IF @Type = 1
	BEGIN
		--make sure we only have one sleeper per diem for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 1
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Msg = 'Error Getting Sleeper Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100006
			SELECT @Msg = 'Sleeper Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
		
		--make sure we don't have a hotel expense and a sleeper per diem for the same date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 2
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Msg = 'Error Getting Hotel Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100007
			SELECT @Msg = 'Error, Sleeper Per Diem And Hotel For Same Date'
			GOTO Error_Encountered
		END
		
		--make sure we do not have the combined sleeper/travel per diem for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 10
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100008
			SELECT @Msg = 'Sleeper/Travel Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
		
		--make sure we do not have the dorm per diem for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 12
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100009
			SELECT @Msg = 'Dorm Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
		
		--make sure the truck has a sleeper cab
		SELECT @SleeperCabInd = ISNULL(SleeperCabInd,0)	
		FROM Truck
		WHERE TruckID = @TruckID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Msg = 'Error Getting Sleeper Cab Indicator'
			GOTO Error_Encountered
		END
		IF @SleeperCabInd = 0
		BEGIN
			SELECT @ErrorID = 100010
			SELECT @Msg = 'Invalid Expense Type, Truck Does Not Have Sleeper'
			GOTO Error_Encountered
		END
		
		--drivers are now required to enter the location where they slept
		IF DATALENGTH(ISNULL(@ItemDescription,'')) = 0
		BEGIN
			SELECT @ErrorID = 100011
			SELECT @Msg = 'Enter City And State In The Description Field.'
			GOTO Error_Encountered
		END
	END
	ELSE IF @Type = 2
	BEGIN
		--make sure we only have one hotel expense for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 2
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Msg = 'Error Getting Hotel Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100012
			SELECT @Msg = 'Hotel Expense Already Entered For Date'
			GOTO Error_Encountered
		END
			
		--make sure we don't have a hotel expense and a sleeper per diem for the same date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 1
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Msg = 'Error Getting Sleeper Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100013
			SELECT @Msg = 'Error, Sleeper Per Diem And Hotel For Same Date'
			GOTO Error_Encountered
		END
		
		--make sure we do not have the combined sleeper/travel per diem for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 10
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100014
			SELECT @Msg = 'Sleeper/Travel Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
		
		--make sure we do not have the dorm per diem for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 12
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100015
			SELECT @Msg = 'Dorm Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
		
		--drivers are now required to enter the location where they slept
		IF DATALENGTH(ISNULL(@ItemDescription,'')) = 0
		BEGIN
			SELECT @ErrorID = 100011
			SELECT @Msg = 'Enter City And State In The Description Field.'
			GOTO Error_Encountered
		END
				
		
	END
	ELSE IF @Type = 10
	BEGIN
		--make sure we do not have the combined sleeper/travel per diem for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 10
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100016
			SELECT @Msg = 'Sleeper/Travel Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
		
		--make sure we don't have a per diem for that date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 0
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100017
			SELECT @Msg = 'Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
		
		--make sure we don't already have a sleeper per diem for the same date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 1
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Msg = 'Error Getting Sleeper Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100018
			SELECT @Msg = 'Sleeper Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
		
		--make sure we don't have a hotel expense for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 2
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Msg = 'Error Getting Hotel Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100019
			SELECT @Msg = 'Hotel Expense Already Entered For Date'
			GOTO Error_Encountered
		END
		
		--make sure we do not have the dorm per diem for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 12
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100020
			SELECT @Msg = 'Dorm Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
		
		--make sure the truck has a sleeper cab
		SELECT @SleeperCabInd = ISNULL(SleeperCabInd,0)	
		FROM Truck
		WHERE TruckID = @TruckID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Msg = 'Error Getting Sleeper Cab Indicator'
			GOTO Error_Encountered
		END
		IF @SleeperCabInd = 0
		BEGIN
			SELECT @ErrorID = 100021
			SELECT @Msg = 'Invalid Expense Type, Truck Does Not Have Sleeper'
			GOTO Error_Encountered
		END
		
		--drivers are now required to enter the location where they slept
		IF DATALENGTH(ISNULL(@ItemDescription,'')) = 0
		BEGIN
			SELECT @ErrorID = 100022
			SELECT @Msg = 'Enter City And State In The Description Field.'
			GOTO Error_Encountered
		END
	END
	ELSE IF @Type = 11
	BEGIN
		--make sure we only have mobile app expense for the month
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND DATEPART(month,ItemDate) = DATEPART(month,@ItemDate)
		AND DATEPART(year,ItemDate) = DATEPART(year,@ItemDate)
		AND Type = 11
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Msg = 'Error Getting Hotel Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100023
			SELECT @Msg = 'Mobile App Use Expense Already Entered For Month'
			GOTO Error_Encountered
		END
	END
	ELSE IF @Type = 12
	BEGIN
		--make sure we only have one dorm per diem for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 12
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Msg = 'Error Getting Dorm Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100024
			SELECT @Msg = 'Dorm Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
				
		--make sure we don't already have a sleeper per diem for the same date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 1
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Msg = 'Error Getting Sleeper Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100025
			SELECT @Msg = 'Sleeper Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
		
		--make sure we don't have a hotel expense and a dorm per diem for the same date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 2
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Msg = 'Error Getting Hotel Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100026
			SELECT @Msg = 'Error, Dorm Per Diem And Hotel For Same Date'
			GOTO Error_Encountered
		END
				
		--make sure we do not have the combined sleeper/travel per diem for the date
		SELECT @Count = COUNT(*)
		FROM Expense
		WHERE DriverID = @DriverID
		AND ItemDate = @ItemDate
		AND Type = 10
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting Per Diem Count'
			GOTO Error_Encountered
		END
		IF @Count > 0
		BEGIN
			SELECT @ErrorID = 100027
			SELECT @Msg = 'Sleeper/Travel Per Diem Already Entered For Date'
			GOTO Error_Encountered
		END
				
		--drivers are now required to enter the location where they slept
		IF DATALENGTH(ISNULL(@ItemDescription,'')) = 0
		BEGIN
			SELECT @ErrorID = 100028
			SELECT @Msg = 'Enter Dorm Name In The Description Field.'
			GOTO Error_Encountered
		END
	END

	INSERT INTO Expense( 
			DriverID, 
			ItemDate, 
			Type, 
			Amount, 
			ItemDescription,
			TruckNum,
			TruckID,
			BackupReceivedInd,
			PaidInd,
			CreationDate,
			CreatedBy,
			UpdatedDate,
			UpdatedBy
	)
	VALUES( 
			@DriverID, 
			@ItemDate, 
			@Type, 
			@Amount, 
			@ItemDescription,
			@TruckNum,
			@TruckID,
			@BackupReceivedInd,
			@PaidInd,
			@CreationDate,
			@CreatedBy,
			@UpdatedDate,
			@UpdatedBy
	)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' Inserting Record'
		GOTO Error_Encountered
	END
	
	--get the ExpenseID
	SELECT @ExpenseID = @@Identity
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the VehicleBayTest Record ID'
		GOTO Error_Encountered
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
		SELECT @ReturnMessage = 'Expense Record Created Successfully'
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM', @ExpenseID AS 'ID'

	RETURN @ReturnCode
END



GO
