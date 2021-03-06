USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportCustomers]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportCustomers]
AS
BEGIN
	set nocount on
	DECLARE	--imptDealers Table Variables
	@imptDealersID			int,
	@name				varchar(255),
	@attn				varchar(255),
	@addr1				varchar(255),
	@addr2				varchar(255),
	@city				varchar(255),
	@state				varchar(255),
	@zip				varchar(255),
	@abbrev				varchar(255),
	@dlrno				varchar(255),
	@phone				varchar(255),
	@fax				varchar(255),
	@notes				varchar(255),
	@salesman			varchar(255),
	--Customer Table Variables
	@CustomerID			int,
	@CustomerCode			varchar(20),
	@CustomerName			varchar(50),
	@DBAName			varchar(50),
	@ShortName			varchar(50),
	@MainAddressID			int,
	@BillingAddressID		int,
	@CustomerType			varchar(20),
	@CustomerSubType		varchar(20),
	@InternalComment		varchar(1000),
	@DriverComment			varchar(1000),
	@CollectionsIssueInd		int,
	@ApplyFuelSurchargeInd		int,
	@FuelSurchargePercent		decimal(19,2),
	@DefaultBillingMethod		varchar(20),
	@DoNotPrintInvoiceInd		int,
	@DoNotExportInvoiceInfoInd	int,
	@RecordStatus			varchar(15),
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	@UpdatedDate			datetime,
	@UpdatedBy			varchar(20),
	--@imptDealersID			int,
	--Location Table Variables
	@LocationID			int,
	@ParentRecordID			int,
	@ParentRecordTable		varchar(20),
	@LocationType			varchar(20),
	@LocationSubType		varchar(20),
	@LocationName			varchar(100),
	@CustomerLocationCode		varchar(50),
	@AddressLine1			varchar(50),
	@AddressLine2			varchar(50),
	--@City				varchar(30),
	--@State				varchar(2),
	--@Zip				varchar(14),
	@Country			varchar(30),
	@MainPhone			varchar(20),
	@FaxNumber			varchar(20),
	@PrimaryContactFirstName	varchar(30),
	@PrimaryContactLastName		varchar(30),
	@PrimaryContactPhone		varchar(20),
	@PrimaryContactEmail		varchar(255),
	@AlternateContactFirstName	varchar(30),
	@AlternateContactLastName	varchar(30),
	@AlternateContactPhone		varchar(20),
	@AlternateContactEmail		varchar(255),
	@OtherPhone1Description		varchar(50),
	@OtherPhone1			varchar(20),
	@OtherPhone2Description		varchar(50),
	@OtherPhone2			varchar(20),
	@AuctionPayOverrideInd		int,
	@AuctionPayRate			decimal(19, 2),
	@FlatDeliveryPayInd		int,
	@FlatDeliveryPayRate		decimal(19, 2),
	@LocationNotes			varchar(1000),
	@DriverDirections		varchar(1000),
	--@RecordStatus			varchar(15),
	--@CreationDate			datetime,
	--@CreatedBy			varchar(20),
	--@UpdatedDate			datetime,
	--@UpdatedBy			varchar (20)
	--Processing Variables
	@msg				varchar(100),
	@ErrorID			int,
	@RowCount			int,
	@CustomerCount			int,
	@loopcounter			int,
	@Status				varchar(50),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)

	/************************************************************************
	*	spImportCustomers						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the imptDealers table and 	*
	*	creates/updates the Customer records.				*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	02/28/2005 CMK    Initial version				*
	*									*
	************************************************************************/
		
	
	/* Declare the main processing cursor */
	DECLARE imptDealersProcessingCursor INSENSITIVE CURSOR
		FOR
		SELECT imptDealersID, name, attn,
		addr1, addr2, city, state, zip,
		abbrev, dlrno, phone, fax,
		notes, salesman
	FROM imptDealers
	--WHERE patindex('%DO%NOT%USE%',name) < 1
	WHERE DATALENGTH(dlrno)>0
	ORDER BY name


	SELECT @loopcounter = 0
	OPEN imptDealersProcessingCursor
	
	BEGIN TRAN
	
	SELECT @RowCount = @@cursor_rows
	SELECT @msg =  'Dealer Records to Process: ' + CONVERT(varchar(10),@RowCount)
	print @msg
	
	
	FETCH imptDealersProcessingCursor into @imptDealersID,
		@name, @attn, @addr1, @addr2, @city, @state, @zip,
		@abbrev, @dlrno, @phone, @fax, @notes, @salesman
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @ErrorID = 0
		SELECT @loopcounter = @loopcounter + 1
		SELECT @msg = 'Iteration: ' + CONVERT(varchar(10),@loopcounter) + ' Customer Number: ' + isnull(@dlrno,'')
		print @msg
		
		--Set the default values
		SELECT @CustomerType = 'Dealer'
		SELECT @RecordStatus = 'Active'
		SELECT @CreationDate = Current_Timestamp
		SELECT @CreatedBy = 'DlrImport'
		SELECT @CollectionsIssueInd = 0
		SELECT @ApplyFuelSurchargeInd = 0
		SELECT @FuelSurchargePercent = 0
		SELECT @DefaultBillingMethod = 'Bill To Customer'
		SELECT @DoNotPrintInvoiceInd = 0
		SELECT @DoNotExportInvoiceInfoInd = 0
		SELECT @CustomerCode = @dlrno
		SELECT @CustomerName = @name
		SELECT @ShortName = @abbrev
		SELECT @InternalComment = @notes
		
		IF @CustomerName = 'Beacon Al''s' AND @CustomerCode = '91399'
		BEGIN
			GOTO End_Of_Loop
		END
		
		IF @CustomerName LIKE 'Adesa -%'
			OR @CustomerName LIKE 'Adesa Auction%'
			OR @CustomerName LIKE 'Adesa Auto Auction%'
			OR @CustomerName LIKE 'Manheim Auto Auction%'
		BEGIN
			SELECT @CustomerType = 'Auction'
		END
		ELSE IF @CustomerName LIKE 'General Motors%'
			OR @CustomerName LIKE 'Kia Motors%'
			OR @CustomerName LIKE 'Mazda Motors%'
			OR @CustomerName LIKE 'Mercedes Benz U. S. A.%'
			OR @CustomerName LIKE 'Mercedes-Benz Of North%'
			OR @CustomerName LIKE 'Mitsubishi Motor Sales%'
			OR @CustomerName LIKE 'Nissan Motor Corp%'
			OR @CustomerName LIKE 'Nissan North America%'
			OR @CustomerName LIKE 'Saab Cars USA%'
			OR @CustomerName LIKE 'Subaru Dist%'
			OR @CustomerName LIKE 'Subaru Of America%'
			OR @CustomerName LIKE 'Volkwagen Of America%'
			OR @CustomerName LIKE 'Volvo Cars%'
		BEGIN
			SELECT @CustomerType = 'OEM'
		END
		ELSE IF @CustomerName LIKE 'Adventure Rentals%'
			OR @CustomerName LIKE 'Alamo%'
			OR @CustomerName LIKE 'Avis%'
			OR @CustomerName LIKE 'Budget%'
			OR @CustomerName LIKE 'Capital Auto Rental%'
			OR @CustomerName LIKE 'Dollar%'
			OR @CustomerName LIKE 'Enterprise%'
			OR @CustomerName LIKE 'Hertz%'
		BEGIN
			SELECT @CustomerType = 'Rental Co'
		END
		ELSE IF @CustomerName LIKE 'A. J. Auto Trans%'
			OR @CustomerName LIKE 'A1 Auto Trans%'
			OR @CustomerName LIKE 'Accurate Auto Carriers%'
			OR @CustomerName LIKE 'ACH Auto Car Hauling%'
			OR @CustomerName LIKE 'Action Auto%'
			OR @CustomerName LIKE 'A & D Auto Transport%'
			OR @CustomerName LIKE 'Adesa Auto Transport%'
			OR @CustomerName LIKE 'All Points Van%'
			OR @CustomerName LIKE 'All State Auto%'
			OR @CustomerName LIKE 'D & D Auto Transport%'
			OR @CustomerName LIKE 'D & W Auto%'
			OR @CustomerName LIKE 'M & M Transport%'
			OR @CustomerName LIKE 'M & M Trucking%'
			OR @CustomerName LIKE 'Payson%'
		BEGIN
			SELECT @CustomerType = 'Trucking Co'
		END
		
		
		--See if the customer already exists
		SELECT @CustomerCount = 0
		SELECT @CustomerCount = COUNT(*)
		FROM Customer
		WHERE CustomerCode = @CustomerCode
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error getting customer count'
			GOTO Error_Encountered
		END
		IF @CustomerCount > 1
		BEGIN
			SELECT @ErrorID = 100000
			SELECT @Status = 'Multiple Matches on Customer Code'
			GOTO Error_Encountered
		END
		
		IF @CustomerCount = 0 AND patindex('%DO%NOT%USE%',@CustomerName) < 1
		BEGIN
			--Insert into the Customer table
			INSERT INTO Customer (
				CustomerCode,
				CustomerName,
				ShortName,
				CustomerType,
				InternalComment,
				CollectionsIssueInd,
				ApplyFuelSurchargeInd,
				FuelSurchargePercent,
				DefaultBillingMethod,
				DoNotPrintInvoiceInd,
				DoNotExportInvoiceInfoInd,
				RecordStatus,
				CreationDate,
				CreatedBy
			)
			VALUES(
				LTRIM(RTRIM(@CustomerCode)),
				LTRIM(RTRIM(@CustomerName)),
				LTRIM(RTRIM(@ShortName)),
				LTRIM(RTRIM(@CustomerType)),
				LTRIM(RTRIM(@InternalComment)),
				@CollectionsIssueInd,
				@ApplyFuelSurchargeInd,
				@FuelSurchargePercent,
				@DefaultBillingMethod,
				@DoNotPrintInvoiceInd,
				@DoNotExportInvoiceInfoInd,
				LTRIM(RTRIM(@RecordStatus)),
				@CreationDate,
				LTRIM(RTRIM(@CreatedBy))
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @Status = 'Error creating customer record'
				GOTO Error_Encountered
			END
			ELSE
			BEGIN
				SELECT @CustomerID = @@Identity
			END
			
			--Now Create the Billing Address
					
			--Set the defaults
			SELECT @ParentRecordTable = 'Customer'
			SELECT @LocationType = 'BillingAddress'
			SELECT @Country = 'U.S.A.'
			SELECT @AuctionPayOverrideInd = 0
			SELECT @AuctionPayRate = 0
			SELECT @FlatDeliveryPayInd = 0
			SELECT @FlatDeliveryPayRate = 0
			SELECT @RecordStatus = 'Active'
			SELECT @CreationDate = Current_Timestamp
			SELECT @CreatedBy = 'DlrImport'
					
			--Bring in the values from the import table
			SELECT @ParentRecordID = @CustomerID
			SELECT @LocationName = @CustomerName
			SELECT @AddressLine1 = @addr1
			SELECT @AddressLine2 = @addr2
			SELECT @City = @City
			SELECT @State = @State
			SELECT @Zip = @Zip
			SELECT @MainPhone = REPLACE(REPLACE(REPLACE(REPLACE(@phone,'(',''),')',''),'-',''),' ','')
			SELECT @FaxNumber = REPLACE(REPLACE(REPLACE(REPLACE(@fax,'(',''),')',''),'-',''),' ','')
			SELECT @LocationNotes = isnull(@attn,'')+' -- '+ isnull(@notes,'')
						
			--Insert into the Location table
			INSERT INTO Location (
				ParentRecordID,
				ParentRecordTable,
				LocationType,
				LocationName,
				AddressLine1,
				AddressLine2,
				City,
				State,
				Zip,
				Country,
				MainPhone,
				FaxNumber,
				AuctionPayOverrideInd,
				AuctionPayRate,
				FlatDeliveryPayInd,
				FlatDeliveryPayRate,
				MileagePayBoostOverrideInd,
				MileagePayBoost,
				LocationNotes,
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
				@ParentRecordID,
				LTRIM(RTRIM(@ParentRecordTable)),
				LTRIM(RTRIM(@LocationType)),
				LTRIM(RTRIM(@LocationName)),
				LTRIM(RTRIM(@AddressLine1)),
				LTRIM(RTRIM(@AddressLine2)),
				LTRIM(RTRIM(@City)),
				LTRIM(RTRIM(@State)),
				LTRIM(RTRIM(@Zip)),
				LTRIM(RTRIM(@Country)),
				LTRIM(RTRIM(@MainPhone)),
				LTRIM(RTRIM(@FaxNumber)),
				@AuctionPayOverrideInd,
				@AuctionPayRate,
				@FlatDeliveryPayInd,
				@FlatDeliveryPayRate,
				0,
				0,
				LTRIM(RTRIM(@LocationNotes)),
				LTRIM(RTRIM(@RecordStatus)),
				@CreationDate,
				LTRIM(RTRIM(@CreatedBy)),
				0,
				0,
				0,
				0,
				0,
				'A',				--ShortHaulPaySchedule,
				0,				--NYBridgeAdditiveEligibleInd
				0,				--HotDealerInd
				0,				--DisableLoadBuildingInd
				0				--LocationHasInspectorsInd
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @Status = 'Error creating location record'
				GOTO Error_Encountered
			END
			ELSE
			BEGIN
				SELECT @LocationID = @@Identity
			END
			
			-- Update the customer record with the billing address id
			UPDATE Customer
			Set BillingAddressID = @LocationID,
			MainAddressID = @LocationID
			WHERE CustomerID = @CustomerID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @Status = 'Error updating customer record with address id'
				GOTO Error_Encountered
			END
			
		END
		ELSE
		BEGIN
			--Update the Customer
			SELECT @CustomerID = CustomerID, @BillingAddressID = BillingAddressID, @MainAddressID = MainAddressID
			FROM Customer
			WHERE CustomerCode = @CustomerCode
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @Status = 'Error getting the customer information'
				GOTO Error_Encountered
			END
			
			IF patindex('%DO%NOT%USE%',@CustomerName) >= 1
			BEGIN
				--Deactivate the customer
				UPDATE Customer
				SET CustomerName = @CustomerName,
				RecordStatus = 'Inactive',
				UpdatedDate = @CreationDate,
				UpdatedBy = @CreatedBy
				WHERE CustomerID = @CustomerID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@Error
					SELECT @Status = 'Error updating the customer record'
					GOTO Error_Encountered
				END
			END
			ELSE
			BEGIN
				UPDATE Customer
				SET CustomerName = @CustomerName,
				ShortName = @ShortName,
				CustomerType = @CustomerType,
				InternalComment = @InternalComment,
				UpdatedDate = @CreationDate,
				UpdatedBy = @CreatedBy
				WHERE CustomerID = @CustomerID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@Error
					SELECT @Status = 'Error updating the customer record'
					GOTO Error_Encountered
				END
			
				--Update the Billing and StreetAddresses
				UPDATE Location
				SET LocationName = LTRIM(RTRIM(@CustomerName)),
				AddressLine1 = LTRIM(RTRIM(@addr1)),
				AddressLine2 = LTRIM(RTRIM(@addr2)),
				City = LTRIM(RTRIM(@City)),
				State = LTRIM(RTRIM(@State)),
				Zip = LTRIM(RTRIM(@Zip)),
				MainPhone = REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@phone)),'(',''),')',''),'-',''),' ',''),
				FaxNumber = REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@fax)),'(',''),')',''),'-',''),' ',''),
				LocationNotes = LTRIM(RTRIM(isnull(@attn,'')+' -- '+ isnull(@notes,'')))
				WHERE LocationID IN (@MainAddressID, @BillingAddressID)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@Error
					SELECT @Status = 'Error updating the address records'
					GOTO Error_Encountered
				END
			END
		END
		
		
		End_Of_Loop:
		IF @ErrorID = 0
		BEGIN
			SELECT @msg = 'Conversion For Customer Number '+isnull(@dlrno,'')+' was SUCCESSFUL'
		END
		ELSE
		BEGIN
			SELECT @msg='ERROR Number '+CONVERT(varchar(10),@ErrorID)+ ' Encountered Processing Customer Number '+isnull(@dlrno,'')
		END
		--print @msg
		FETCH imptDealersProcessingCursor into @imptDealersID,
			@name, @attn, @addr1, @addr2, @city, @state, @zip,
			@abbrev, @dlrno, @phone, @fax, @notes, @salesman
	END

	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE imptDealersProcessingCursor
		DEALLOCATE imptDealersProcessingCursor
		PRINT 'I08Update Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE imptDealersProcessingCursor
		DEALLOCATE imptDealersProcessingCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'I08Update Error_Encountered =' + STR(@ErrorID)
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
