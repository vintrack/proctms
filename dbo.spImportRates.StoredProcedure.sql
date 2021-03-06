USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportRates]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportRates]
AS
BEGIN
	DECLARE	--ImportLocation Table Variables
	@ImportRateID				int,
	@ParentRecordID				varchar(255),
	@FromLocationID				varchar(255),
	@FromCustomerLocationCode		varchar(255),
	@ToLocationID				varchar(255),
	@ToCustomerLocationCode			varchar(255),
	@Rate					varchar(255),
	@RateClass				varchar(255),
	@EffectiveDate				datetime,
	@EndDate				datetime,
	@Status					varchar(100),
	@MiscellaneousAdditive			decimal(19,2),
	@DriverPayBasisPercent			decimal(19,2),
	@CurrencyCountryCode			varchar(20),
	@Tolls					decimal(19,2),
	@Ferry					decimal(19,2),
	--ChargeRate Table Variables
	@ChargeRateID				int,
	@CustomerID				int,
	@StartLocationID			int,
	@EndLocationID				int,
	@RateType				varchar(20),
	@FixedRate				decimal(19,2),
	@VariableRate				decimal(19,2),
	@Mileage				decimal(19,2),
	@ChargeRate				decimal(19,2),
	@RateOverrideInd			decimal(19,2),
	@DriverPayBasisPercentOverrideInd	int,
	@RecordStatus				varchar(15),
	@CreationDate				datetime,
	@CreatedBy				varchar(20),
	@UpdatedDate				datetime,
	@UpdatedBy				varchar(20),
	@StartDate				datetime,
	--Processing Variables
	@AddEditInd				int,		-- 1= add location, 0 = edit location
	@ICLCustomerCode			varchar(20),
	@ErrorID				int,
	@ReturnCode				int,
	@ReturnMessage				varchar(100),
	@ExceptionEncounteredInd		int,
	@RowCount				int,
	@loopcounter				int

	/************************************************************************
	*	spImportRates							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ImportLocations table 	*
	*	and creates/updates the Location records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	04/01/2005 CMK    Initial version				*
	*									*
	************************************************************************/
	
	set nocount on
	/* Declare the main processing cursor */
	DECLARE ImportRatesCursor INSENSITIVE CURSOR
		FOR
		SELECT ImportRateID, ParentRecordID, FromLocationID, FromCustomerLocationCode,
		ToLocationID, ToCustomerLocationCode, Rate, RateClass, EffectiveDate, EndDate, Mileage,
		ISNULL(MiscellaneousAdditive,0), ISNULL(DriverPayBasisPercent,0), CurrencyCountryCode, ISNULL(Tolls,0), ISNULL(Ferry,0)
		FROM ImportRate
	ORDER BY ParentRecordID, FromLocationID, ToLocationID, ISNULL(EffectiveDate,CURRENT_TIMESTAMP)


	SELECT @loopcounter = 0
	OPEN ImportRatesCursor
	
	BEGIN TRAN
	
	SELECT @RowCount = @@cursor_rows
	SELECT @ExceptionEncounteredInd = 0
	
	
	FETCH ImportRatesCursor INTO @ImportRateID, @ParentRecordID, @FromLocationID, @FromCustomerLocationCode,
		@ToLocationID, @ToCustomerLocationCode, @Rate, @RateClass, @EffectiveDate, @EndDate, @Mileage,
		@MiscellaneousAdditive, @DriverPayBasisPercent, @CurrencyCountryCode, @Tolls, @Ferry
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--Reset the Processing Variables
		SELECT @ErrorID = 0
		SELECT @AddEditInd = 1
		
		
		--set the rate type
		IF @RateClass = 'A'
		BEGIN
			SELECT @RateType = 'Size A Rate'
		END
		ELSE IF @RateClass = 'B'
		BEGIN
			SELECT @RateType = 'Size B Rate'
		END
		ELSE IF @RateClass = 'C'
		BEGIN
			SELECT @RateType = 'Size C Rate'
		END
		ELSE IF @RateClass = 'D'
		BEGIN
			SELECT @RateType = 'Size D Rate'
		END
		ELSE IF @RateClass = 'E'
		BEGIN
			SELECT @RateType = 'Size E Rate'
		END
		ELSE IF @RateClass = 'Size A Rate'
		BEGIN
			SELECT @RateType = 'Size A Rate'
		END
		ELSE IF @RateClass = 'Size B Rate'
		BEGIN
			SELECT @RateType = 'Size B Rate'
		END
		ELSE IF @RateClass = 'Size C Rate'
		BEGIN
			SELECT @RateType = 'Size C Rate'
		END
		ELSE IF @RateClass = 'Size D Rate'
		BEGIN
			SELECT @RateType = 'Size D Rate'
		END
		ELSE IF @RateClass = 'Size E Rate'
		BEGIN
			SELECT @RateType = 'Size E Rate'
		END
		ELSE
		BEGIN
			SELECT @ErrorID = 100009
			GOTO End_Of_Loop
		END
		--Validate the customerID
		IF @ParentRecordID IS NULL OR @ParentRecordID = ''
		BEGIN
			SELECT @ErrorID = 100000
			GOTO End_Of_Loop
		END
		
		SELECT @RowCount = Count(*)
		FROM Customer
		WHERE CustomerID = @ParentRecordID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			GOTO Error_Encountered
		END
		ELSE IF @RowCount = 0
		BEGIN
			SELECT @ErrorID = 100001
			GOTO End_Of_Loop
		END
				
		--validate the origin location
		IF ISNULL(@FromLocationID,0) > 0
		BEGIN
			--validate that the location id belongs to the customer
			SELECT @RowCount = COUNT(*)
			FROM Location
			WHERE LocationID = @FromLocationID
			AND ((ParentRecordTable = 'Customer'
			AND ParentRecordID = @ParentrecordID)
			OR ParentRecordTable = 'Common')
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				GOTO Error_Encountered
			END
			ELSE IF @RowCount = 0
			BEGIN
				SELECT @ErrorID = 100002
				GOTO End_Of_Loop
			END
			
		END
		ELSE IF DATALENGTH(@FromCustomerLocationCode) > 0
		BEGIN
			--validate that the location id belongs to the customer or is a common location
			SELECT @RowCount = COUNT(*)
			FROM Location
			WHERE CustomerLocationCode = @FromCustomerLocationCode
			AND ((ParentRecordTable = 'Customer'
			AND ParentRecordID = @ParentrecordID)
			OR ParentRecordTable = 'Common')
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				GOTO Error_Encountered
			END
			ELSE IF @RowCount = 0
			BEGIN
				--try to decode the customer to see if this is a subaru, nissan, icl or mercedes location
				
				--see if it is soa
				IF (SELECT Count(*)
				FROM SettingTable
				WHERE ValueKey = 'SOACustomerID'
				AND ValueDescription = CONVERT(varchar(20),@ParentRecordID))=1
				BEGIN
					--do the SOA decode
					SELECT @RowCount = Count(*)
					FROM Code
					WHERE CodeType = 'SOALocationCode'
					AND Code = @FromCustomerLocationCode
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@Error
						GOTO Error_Encountered
					END
									
					IF @RowCount = 1
					BEGIN
						SELECT @FromLocationID = CONVERT(int,Value1)
						FROM Code
						WHERE CodeType = 'SOALocationCode'
						AND Code = @FromCustomerLocationCode
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@Error
							GOTO Error_Encountered
						END
					END
					ELSE
					BEGIN
						SELECT @ErrorID = 100002
						GOTO End_Of_Loop
					END
				END
				ELSE IF (SELECT Count(*)
				FROM SettingTable
				WHERE ValueKey = 'SDCCustomerID'
				AND ValueDescription = CONVERT(varchar(20),@ParentRecordID))=1
				BEGIN
					--do the SOA decode
					SELECT @RowCount = Count(*)
					FROM Code
					WHERE CodeType = 'SDCLocationCode'
					AND Code = @FromCustomerLocationCode
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@Error
						GOTO Error_Encountered
					END
											
					IF @RowCount = 1
					BEGIN
						SELECT @FromLocationID = CONVERT(int,Value1)
						FROM Code
						WHERE CodeType = 'SDCLocationCode'
						AND Code = @FromCustomerLocationCode
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@Error
							GOTO Error_Encountered
						END
					END
					ELSE
					BEGIN
						SELECT @ErrorID = 100002
						GOTO End_Of_Loop
					END
				END
				ELSE IF (SELECT Count(*)
				FROM SettingTable
				WHERE ValueKey = 'NissanCustomerID'
				AND ValueDescription = CONVERT(varchar(20),@ParentRecordID))=1
				BEGIN
					--do the Nissan decode
					SELECT @RowCount = Count(*)
					FROM Code
					WHERE CodeType = 'NissanRailheadCode'
					AND Code = @FromCustomerLocationCode
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@Error
						GOTO Error_Encountered
					END
					
					IF @RowCount = 1
					BEGIN
						SELECT @FromLocationID = CONVERT(int,Value1)
						FROM Code
						WHERE CodeType = 'NissanRailheadCode'
						AND Code = @FromCustomerLocationCode
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@Error
							GOTO Error_Encountered
						END
					END
					ELSE
					BEGIN
						SELECT @ErrorID = 100002
						GOTO End_Of_Loop
					END
				END
				ELSE IF (SELECT Count(*)
				FROM SettingTable
				WHERE ValueKey = 'MercedesCustomerID'
				AND ValueDescription = CONVERT(varchar(20),@ParentRecordID))=1
				BEGIN
					--do the Mercedes decode
					SELECT @RowCount = Count(*)
					FROM Code
					WHERE CodeType = 'MercedesLocationCode'
					AND Code = @FromCustomerLocationCode
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@Error
						GOTO Error_Encountered
					END
								
					IF @RowCount = 1
					BEGIN
						SELECT @FromLocationID = CONVERT(int,Value1)
						FROM Code
						WHERE CodeType = 'MercedesLocationCode'
						AND Code = @FromCustomerLocationCode
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@Error
							GOTO Error_Encountered
						END
					END
					ELSE
					BEGIN
						SELECT @ErrorID = 100002
						GOTO End_Of_Loop
					END
				END
				ELSE IF (SELECT Count(*)
				FROM Code
				WHERE CodeType = 'ICLCustomerCode'
				AND Value1 = CONVERT(varchar(20),@ParentRecordID))=1
				BEGIN
					--do the ICL decode
					SELECT @ICLCustomerCode = Code
					FROM Code
					WHERE CodeType = 'ICLCustomerCode'
					AND Value1 = CONVERT(varchar(20),@ParentRecordID)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@Error
						GOTO Error_Encountered
					END
					
					SELECT @RowCount = Count(*)
					FROM Code
					WHERE CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
					AND Code = @FromCustomerLocationCode
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@Error
						GOTO Error_Encountered
					END
									
					IF @RowCount = 1
					BEGIN
						SELECT @FromLocationID = CONVERT(int,Value1)
						FROM Code
						WHERE CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
						AND Code = @FromCustomerLocationCode
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@Error
							GOTO Error_Encountered
						END
					END
					ELSE
					BEGIN
						SELECT @ErrorID = 100002
						GOTO End_Of_Loop
					END
				END
				ELSE
				BEGIN
					SELECT @ErrorID = 100002
					GOTO End_Of_Loop
				END
			END
			ELSE IF @RowCount = 1
			BEGIN
				--get the location id
				SELECT @FromLocationID = LocationID
				FROM Location
				WHERE CustomerLocationCode = @FromCustomerLocationCode
				AND ((ParentRecordTable = 'Customer'
				AND ParentRecordID = @ParentrecordID)
				OR ParentRecordTable = 'Common')
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@Error
					GOTO Error_Encountered
				END
			END
			ELSE
			BEGIN
				SELECT @ErrorID = 100003
				GOTO End_Of_Loop
			END
		END
		ELSE
		BEGIN
			SELECT @ErrorID = 100004
			GOTO End_Of_Loop
		END
		
		--validate the destination
		IF ISNULL(@ToLocationID,0) > 0
		BEGIN
			--validate that the location id belongs to the customer
			SELECT @RowCount = COUNT(*)
			FROM Location
			WHERE LocationID = @ToLocationID
			AND ((ParentRecordTable = 'Customer'
			AND ParentRecordID = @ParentrecordID)
			OR ParentRecordTable = 'Common')
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				GOTO Error_Encountered
			END
			ELSE IF @RowCount = 0
			BEGIN
				SELECT @ErrorID = 100005
				GOTO End_Of_Loop
			END
			
		END
		ELSE IF DATALENGTH(@ToCustomerLocationCode) > 0
		BEGIN
			--validate that the location id belongs to the customer or is a common location
			SELECT @RowCount = COUNT(*)
			FROM Location
			WHERE CustomerLocationCode = @ToCustomerLocationCode
			AND ((ParentRecordTable = 'Customer'
			AND ParentRecordID = @ParentrecordID)
			OR ParentRecordTable = 'Common')
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				GOTO Error_Encountered
			END
			ELSE IF @RowCount = 0
			BEGIN
				--try to decode to see if this is a subaru, nissan, icl or mercedes location
				--see if it is soa
				IF (SELECT Count(*)
				FROM SettingTable
				WHERE ValueKey = 'SOACustomerID'
				AND ValueDescription = CONVERT(varchar(20),@ParentRecordID))=1
				BEGIN
					--do the SOA decode
					SELECT @RowCount = Count(*)
					FROM Code
					WHERE CodeType = 'SOALocationCode'
					AND Code = @ToCustomerLocationCode
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@Error
						GOTO Error_Encountered
					END
									
					IF @RowCount = 1
					BEGIN
						SELECT @ToLocationID = CONVERT(int,Value1)
						FROM Code
						WHERE CodeType = 'SOALocationCode'
						AND Code = @ToCustomerLocationCode
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@Error
							GOTO Error_Encountered
						END
					END
					ELSE
					BEGIN
						SELECT @ErrorID = 100005
						GOTO End_Of_Loop
					END
				END
				ELSE IF (SELECT Count(*)
				FROM SettingTable
				WHERE ValueKey = 'SDCCustomerID'
				AND ValueDescription = CONVERT(varchar(20),@ParentRecordID))=1
				BEGIN
					--do the SOA decode
					SELECT @RowCount = Count(*)
					FROM Code
					WHERE CodeType = 'SDCLocationCode'
					AND Code = @ToCustomerLocationCode
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@Error
						GOTO Error_Encountered
					END
											
					IF @RowCount = 1
					BEGIN
						SELECT @ToLocationID = CONVERT(int,Value1)
						FROM Code
						WHERE CodeType = 'SDCLocationCode'
						AND Code = @ToCustomerLocationCode
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@Error
							GOTO Error_Encountered
						END
					END
					ELSE
					BEGIN
						SELECT @ErrorID = 100005
						GOTO End_Of_Loop
					END
				END
				ELSE IF (SELECT Count(*)
				FROM SettingTable
				WHERE ValueKey = 'NissanCustomerID'
				AND ValueDescription = CONVERT(varchar(20),@ParentRecordID))=1
				BEGIN
					--do the Nissan decode
					SELECT @RowCount = Count(*)
					FROM Code
					WHERE CodeType = 'NissanRailheadCode'
					AND Code = @ToCustomerLocationCode
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@Error
						GOTO Error_Encountered
					END
					
					IF @RowCount = 1
					BEGIN
						SELECT @ToLocationID = CONVERT(int,Value1)
						FROM Code
						WHERE CodeType = 'NissanRailheadCode'
						AND Code = @ToCustomerLocationCode
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@Error
							GOTO Error_Encountered
						END
					END
					ELSE
					BEGIN
						SELECT @ErrorID = 100005
						GOTO End_Of_Loop
					END
				END
				ELSE IF (SELECT Count(*)
				FROM SettingTable
				WHERE ValueKey = 'MercedesCustomerID'
				AND ValueDescription = CONVERT(varchar(20),@ParentRecordID))=1
				BEGIN
					--do the Mercedes decode
					SELECT @RowCount = Count(*)
					FROM Code
					WHERE CodeType = 'MercedesLocationCode'
					AND Code = @ToCustomerLocationCode
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@Error
						GOTO Error_Encountered
					END
								
					IF @RowCount = 1
					BEGIN
						SELECT @ToLocationID = CONVERT(int,Value1)
						FROM Code
						WHERE CodeType = 'MercedesLocationCode'
						AND Code = @ToCustomerLocationCode
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@Error
							GOTO Error_Encountered
						END
					END
					ELSE
					BEGIN
						SELECT @ErrorID = 100005
						GOTO End_Of_Loop
					END
				END
				ELSE IF (SELECT Count(*)
				FROM Code
				WHERE CodeType = 'ICLCustomerCode'
				AND Value1 = CONVERT(varchar(20),@ParentRecordID))=1
				BEGIN
					--do the ICL decode
					SELECT @ICLCustomerCode = Code
					FROM Code
					WHERE CodeType = 'ICLCustomerCode'
					AND Value1 = CONVERT(varchar(20),@ParentRecordID)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@Error
						GOTO Error_Encountered
					END
					
					SELECT @RowCount = Count(*)
					FROM Code
					WHERE CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
					AND Code = @ToCustomerLocationCode
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@Error
						GOTO Error_Encountered
					END
									
					IF @RowCount = 1
					BEGIN
						SELECT @ToLocationID = CONVERT(int,Value1)
						FROM Code
						WHERE CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
						AND Code = @ToCustomerLocationCode
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@Error
							GOTO Error_Encountered
						END
					END
					ELSE
					BEGIN
						SELECT @ErrorID = 100005
						GOTO End_Of_Loop
					END
				END
				ELSE
				BEGIN
					SELECT @ErrorID = 100005
					GOTO End_Of_Loop
				END
			END
			ELSE IF @RowCount = 1
			BEGIN
				--get the location id
				SELECT @ToLocationID = LocationID
				FROM Location
				WHERE CustomerLocationCode = @ToCustomerLocationCode
				AND ((ParentRecordTable = 'Customer'
				AND ParentRecordID = @ParentrecordID)
				OR ParentRecordTable = 'Common')
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@Error
					GOTO Error_Encountered
				END
			END
			ELSE
			BEGIN
				SELECT @ErrorID = 100006
				GOTO End_Of_Loop
			END
		END
		ELSE
		BEGIN
			SELECT @ErrorID = 100007
			GOTO End_Of_Loop
		END
		
		IF @EffectiveDate IS NULL
		BEGIN
			SELECT @EffectiveDate = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
		END
		
		--validate the date range
		SELECT @RowCount = COUNT(*)
		FROM ChargeRate
		WHERE CustomerID = @ParentRecordID
		AND StartLocationID = @FromLocationID
		AND EndLocationID = @ToLocationID
		AND RateType = @RateType
		AND EndDate > DATEADD(day,-1,@EffectiveDate)
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Rate Count'
			GOTO Error_Encountered
		END
		IF @RowCount > 0
		BEGIN
			SELECT @ErrorID = 100010
			GOTO End_Of_Loop
		END
		
		--see if we have a rate already
		SELECT @RowCount = COUNT(*)
		FROM ChargeRate
		WHERE CustomerID = @ParentRecordID
		AND RateType = @RateType
		AND StartLocationID = @FromLocationID
		AND EndLocationID = @ToLocationID
		AND EndDate IS NULL
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			GOTO Error_Encountered
		END
		IF @RowCount > 0
		BEGIN
			--add the end date to the old rate
			UPDATE ChargeRate
			SET UpdatedDate = GetDate(),
			UpdatedBy = 'Rate Import',
			EndDate = DATEADD(day,-1,@EffectiveDate)
			WHERE CustomerID = @ParentRecordID
			AND RateType = @RateType
			AND StartLocationID = @FromLocationID
			AND EndLocationID = @ToLocationID
			AND EndDate IS NULL
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				GOTO End_Of_Loop
			END
		END
		
		--Create the Rate
		--Set the defaults
		SELECT @ChargeRate = CONVERT(decimal(19,2),@Rate)
		SELECT @FixedRate = @ChargeRate
		SELECT @VariableRate = 0
		SELECT @RateOverrideInd = 0
		IF @DriverPayBasisPercent > 0
		BEGIN
			SELECT @DriverPayBasisPercentOverrideInd = 1
		END
		ELSE
		BEGIN
			SELECT @DriverPayBasisPercentOverrideInd = 0
		END
		SELECT @RecordStatus = 'Active'
		SELECT @CreationDate = Current_Timestamp
		SELECT @CreatedBy = 'Rate Import'
					
		--Insert into the Location table
		INSERT INTO ChargeRate (
			CustomerID,
			StartLocationID,
			EndLocationID,
			RateType,
			FixedRate,
			VariableRate,
			Mileage,
			Rate,
			RateOverrideInd,
			RecordStatus,
			CreationDate,
			CreatedBy,
			StartDate,
			EndDate,
			MiscellaneousAdditive,
			DealerReimbursement,
			DriverPayBasisPercent,
			DriverPayBasisPercentOverrideInd,
			CurrencyCountryCode,
			Tolls,
			Ferry
		)
		VALUES(
			@ParentRecordID,
			@FromLocationID,
			@ToLocationID,
			@RateType,
			@FixedRate,
			@VariableRate,
			@Mileage,
			@ChargeRate,
			@RateOverrideInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy,
			@EffectiveDate,
			@EndDate,
			@MiscellaneousAdditive,
			0,	--DealerReimbursement
			@DriverPayBasisPercent,
			@DriverPayBasisPercentOverrideInd,
			@CurrencyCountryCode,
			@Tolls,
			@Ferry
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			GOTO End_Of_Loop
		END
		ELSE
		BEGIN
			SELECT @ChargeRateID = @@Identity
		END
		SELECT @Status = 'Rate Created'
		
		End_Of_Loop:
		IF @ErrorID = 100000
		BEGIN
			SELECT @Status = 'Need Parent Record ID'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100001
		BEGIN
			SELECT @Status = 'Customer Not Found'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100002
		BEGIN
			SELECT @Status = 'Unable To Find From Location ID'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100003
		BEGIN
			SELECT @Status = 'Multiple Matches On From Location ID'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100004
		BEGIN
			SELECT @Status = 'From Location ID/Code Not In Import File'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100005
		BEGIN
			SELECT @Status = 'Unable To Find End Location ID'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100006
		BEGIN
			SELECT @Status = 'Multiple Matches On End Location ID'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100007
		BEGIN
			SELECT @Status = 'To Location ID/Code Not In Import File'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100008
		BEGIN
			SELECT @Status = 'Multiple Rate Matches Found'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100009
		BEGIN
			SELECT @Status = 'Invalid Rate Class'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100010
		BEGIN
			SELECT @Status = 'Effective Date Overlaps Other Closed Rates'
			SELECT @ExceptionEncounteredInd = 1
		END			
		--update the import record
		UPDATE ImportRate
		SET Status = @Status
		WHERE ImportRateID = @ImportRateID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			GOTO Error_Encountered
		END
		
		FETCH ImportRatesCursor INTO @ImportRateID, @ParentRecordID, @FromLocationID, @FromCustomerLocationCode,
		@ToLocationID, @ToCustomerLocationCode, @Rate, @RateClass, @EffectiveDate, @EndDate, @Mileage,
		@MiscellaneousAdditive, @DriverPayBasisPercent, @CurrencyCountryCode, @Tolls, @Ferry
	END
	SELECT @ErrorID = 0 --if we got to this point this should be fine
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportRatesCursor
		DEALLOCATE ImportRatesCursor
		SELECT @ReturnCode = 0
		IF @ExceptionEncounteredInd = 0
		BEGIN
			SELECT @ReturnMessage = 'Processing Completed Successfully'
		END
		ELSE
		BEGIN
			SELECT @ReturnMessage = 'Processing Completed Successfully, but with exceptions'
		END
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ImportRatesCursor
		DEALLOCATE ImportRatesCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
	END
	
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	
	RETURN
END
GO
