USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateAuctionOrderExportData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateAuctionOrderExportData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@LoopCounter			int,
	--AuctionOrdersExport table variables
	@OrderID			varchar(255),
	@OrderDate			varchar(255),
	@AuctionCode			varchar(255),
	@DealerName			varchar(255),
	@DealerNumber			varchar(255),
	@DealerCity			varchar(255),
	@DealerState			varchar(255),
	@DestinationLocation		varchar(255),
	@DestinationCity		varchar(255),
	@DestinationState		varchar(255),
	@DestinationZip			varchar(255),
	@Rate				decimal(19,2),
	@Units				int,
	@DealerContact			varchar(255),
	@Salesperson			varchar(255),
	@Comments			varchar(255),
	@NewDealerFlag			varchar(255),
	@CursorVINKey			varchar(50),
	@VINKey1			varchar(50),
	@VINKey2			varchar(50),
	@VINKey3			varchar(50),
	@VINKey4			varchar(50),
	@VINKey5			varchar(50),
	@VINKey6			varchar(50),
	@VINKey7			varchar(50),
	@VINKey8			varchar(50),
	@VINKey9			varchar(50),
	@VINKey10			varchar(50),
	@VINKey11			varchar(50),
	@VINKey12			varchar(50),
	@VINKey13			varchar(50),
	@VINKey14			varchar(50),
	@VINKey15			varchar(50),
	@VINKey16			varchar(50),
	@VINKey17			varchar(50),
	@VINKey18			varchar(50),
	@VINKey19			varchar(50),
	@VINKey20			varchar(50),
	@VINKey21			varchar(50),
	@VINKey22			varchar(50),
	@VINKey23			varchar(50),
	@VINKey24			varchar(50),
	@VINKey25			varchar(50),
	@VINKey26			varchar(50),
	@VINKey27			varchar(50),
	@VINKey28			varchar(50),
	@CursorModel			varchar(50),
	@Model1				varchar(50),
	@Model2				varchar(50),
	@Model3				varchar(50),
	@Model4				varchar(50),
	@Model5				varchar(50),
	@Model6				varchar(50),
	@Model7				varchar(50),
	@Model8				varchar(50),
	@Model9				varchar(50),
	@Model10			varchar(50),
	@Model11			varchar(50),
	@Model12			varchar(50),
	@Model13			varchar(50),
	@Model14			varchar(50),
	@Model15			varchar(50),
	@Model16			varchar(50),
	@Model17			varchar(50),
	@Model18			varchar(50),
	@Model19			varchar(50),
	@Model20			varchar(50),
	@Model21			varchar(50),
	@Model22			varchar(50),
	@Model23			varchar(50),
	@Model24			varchar(50),
	@Model25			varchar(50),
	@Model26			varchar(50),
	@Model27			varchar(50),
	@Model28			varchar(50),
	@BarCodeAsterix			varchar(50),
	@AuctionCity			varchar(50),
	@ExportBatchID			int,
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(20),
	@CreationDate			datetime,
	--processing variables
	@CursorOrdersID			varchar(255),
	@CursorOrderDate		varchar(255),
	@CursorAuctionCode		varchar(255),
	@CursorDealerName		varchar(255),
	@CursorDealerNumber		varchar(255),
	@CursorDealerCity		varchar(255),
	@CursorDealerState		varchar(255),
	@CursorDestinationLocation	varchar(255),
	@CursorDestinationCity		varchar(255),
	@CursorDestinationState		varchar(255),
	@CursorDestinationZip		varchar(255),
	@CursorRate			decimal(19,2),
	@CursorUnits			int,
	@CursorDealerContact		varchar(255),
	@CursorSalesperson		varchar(255),
	@CursorComments			varchar(255),
	@CursorNewDealerFlag		varchar(255),
	@CursorAuctionCity		varchar(50),
	@Status				varchar(100),
	@LastOrderID			int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateAuctionOrderExportData				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the Auction Order export data for	*
	*	orders that were entered at the auction.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/15/2005 CMK    Initial version				*
	*									*
	************************************************************************/
	
	DECLARE AuctionOrdersCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT O.OrdersID, O.CreationDate, L1.CustomerLocationCode,
		C.CustomerName, C.CustomerCode, L2.City, L2.State,
		L3.LocationName, L3.City, L3.State, L3.Zip,
		ISNULL(CASE WHEN O.CustomerChargeType = 0 OR V.ChargeRateOverrideInd = 1 THEN V.ChargeRate WHEN O.PricingInd = 0 THEN O.PerUnitChargeRate ELSE O.OrderChargeRate/O.Units END,0),
		O.Units,
		L2.PrimaryContactFirstName+' '+L2.PrimaryContactLastName,
		S.SalespersonCode, O.DriverComment,
		CASE WHEN CONVERT(varchar(10),O.CreationDate,101) = CONVERT(varchar(10),C.CreationDate,101) THEN '1' ELSE '0' END,
		RIGHT(V.VIN,8),V.Model, L1.City
		FROM Orders O
		LEFT JOIN Vehicle V ON O.OrdersID = V.OrderID
		LEFT JOIN Customer C ON O.CustomerID = C.CustomerID
		LEFT JOIN Location L1 ON O.PickupLocation = L1.LocationID
		LEFT JOIN Location L2 ON C.MainAddressID = L2.LocationID
		LEFT JOIN Location L3 ON O.DropoffLocation = L3.LocationID
		LEFT JOIN Salesperson S ON O.SalesPersonID = S.SalesPersonID
		WHERE O.OrdersID NOT IN (SELECT AOE.OrderID FROM AuctionOrdersExport AOE)
		AND L1.LocationSubType = 'Auction'
		ORDER BY O.OrdersID, V.VehicleID

	SELECT @ErrorID = 0
	SELECT @LoopCounter = 0
	SELECT @LastOrderID = 0

	OPEN AuctionOrdersCursor

	BEGIN TRAN
	
	--set the default values
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH AuctionOrdersCursor INTO @CursorOrdersID, @CursorOrderDate,@CursorAuctionCode,@CursorDealerName,
		@CursorDealerNumber, @CursorDealerCity, @CursorDealerState, @CursorDestinationLocation,
		@CursorDestinationCity, @CursorDestinationState, @CursorDestinationZip, @CursorRate,
		@CursorUnits, @CursorDealerContact, @CursorSalesperson, @CursorComments, @CursorNewDealerFlag,
		@CursorVINKey, @CursorModel, @CursorAuctionCity
		
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @LastOrderID <> @CursorOrdersID 
		BEGIN
			IF @LastOrderID <> 0
			BEGIN
				INSERT INTO AuctionOrdersExport(
					OrderID,
					OrderDate,
					AuctionCode,
					DealerName,
					DealerNumber,
					DealerCity,
					DealerState,
					DestinationLocation,
					DestinationCity,
					DestinationState,
					DestinationZip,
					Rate,
					Units,
					DealerContact,
					Salesperson,
					Comments,
					NewDealerFlag,
					VINKey1,
					VINKey2,
					VINKey3,
					VINKey4,
					VINKey5,
					VINKey6,
					VINKey7,
					VINKey8,
					VINKey9,
					VINKey10,
					VINKey11,
					VINKey12,
					VINKey13,
					VINKey14,
					VINKey15,
					VINKey16,
					VINKey17,
					VINKey18,
					VINKey19,
					VINKey20,
					VINKey21,
					VINKey22,
					VINKey23,
					VINKey24,
					VINKey25,
					VINKey26,
					VINKey27,
					VINKey28,
					Model1,
					Model2,
					Model3,
					Model4,
					Model5,
					Model6,
					Model7,
					Model8,
					Model9,
					Model10,
					Model11,
					Model12,
					Model13,
					Model14,
					Model15,
					Model16,
					Model17,
					Model18,
					Model19,
					Model20,
					Model21,
					Model22,
					Model23,
					Model24,
					Model25,
					Model26,
					Model27,
					Model28,
					BarCodeAsterix,
					AuctionCity,
					ExportedDate,
					ExportedBy,
					ExportedInd,
					ExportBatchID,
					RecordStatus,
					CreationDate,
					CreatedBy
				)
				VALUES(
					@OrderID,
					@OrderDate,
					@AuctionCode,
					@DealerName,
					@DealerNumber,
					@DealerCity,
					@DealerState,
					@DestinationLocation,
					@DestinationCity,
					@DestinationState,
					@DestinationZip,
					@Rate,
					@Units,
					@DealerContact,
					@Salesperson,
					@Comments,
					@NewDealerFlag,
					@VINKey1,
					@VINKey2,
					@VINKey3,
					@VINKey4,
					@VINKey5,
					@VINKey6,
					@VINKey7,
					@VINKey8,
					@VINKey9,
					@VINKey10,
					@VINKey11,
					@VINKey12,
					@VINKey13,
					@VINKey14,
					@VINKey15,
					@VINKey16,
					@VINKey17,
					@VINKey18,
					@VINKey19,
					@VINKey20,
					@VINKey21,
					@VINKey22,
					@VINKey23,
					@VINKey24,
					@VINKey25,
					@VINKey26,
					@VINKey27,
					@VINKey28,
					@Model1,
					@Model2,
					@Model3,
					@Model4,
					@Model5,
					@Model6,
					@Model7,
					@Model8,
					@Model9,
					@Model10,
					@Model11,
					@Model12,
					@Model13,
					@Model14,
					@Model15,
					@Model16,
					@Model17,
					@Model18,
					@Model19,
					@Model20,
					@Model21,
					@Model22,
					@Model23,
					@Model24,
					@Model25,
					@Model26,
					@Model27,
					@Model28,
					@BarCodeAsterix,
					@AuctionCity,
					@ExportedDate,
					@ExportedBy,
					@ExportedInd,
					@ExportBatchID,
					@RecordStatus,
					@CreationDate,
					@CreatedBy
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error creating SubaruDeliveryExport record'
					GOTO Error_Encountered
				END
			END
			--now that we have inserted the row, clear/reset all of the variables
			SELECT @OrderID = @CursorOrdersID
			SELECT @OrderDate = @CursorOrderDate
			SELECT @AuctionCode = @CursorAuctionCode
			SELECT @DealerName = @CursorDealerName
			SELECT @DealerNumber = @CursorDealerNumber
			SELECT @DealerCity = @CursorDealerCity
			SELECT @DealerState = @CursorDealerState
			SELECT @DestinationLocation = @CursorDestinationLocation
			SELECT @DestinationCity = @CursorDestinationCity
			SELECT @DestinationState = @CursorDestinationState
			SELECT @DestinationZip = @CursorDestinationZip
			SELECT @Rate = @CursorRate
			SELECT @Units = @CursorUnits
			SELECT @DealerContact = @CursorDealerContact
			SELECT @Salesperson = @CursorSalesperson
			SELECT @Comments = @CursorComments
			SELECT @NewDealerFlag = @CursorNewDealerFlag
			SELECT @VINKey1 = @CursorVINKey
			SELECT @VINKey2 = ''
			SELECT @VINKey3 = ''
			SELECT @VINKey4 = ''
			SELECT @VINKey5 = ''
			SELECT @VINKey6 = ''
			SELECT @VINKey7 = ''
			SELECT @VINKey8 = ''
			SELECT @VINKey9 = ''
			SELECT @VINKey10 = ''
			SELECT @VINKey11 = ''
			SELECT @VINKey12 = ''
			SELECT @VINKey13 = ''
			SELECT @VINKey14 = ''
			SELECT @VINKey15 = ''
			SELECT @VINKey16 = ''
			SELECT @VINKey17 = ''
			SELECT @VINKey18 = ''
			SELECT @VINKey19 = ''
			SELECT @VINKey20 = ''
			SELECT @VINKey21 = ''
			SELECT @VINKey22 = ''
			SELECT @VINKey23 = ''
			SELECT @VINKey24 = ''
			SELECT @VINKey25 = ''
			SELECT @VINKey26 = ''
			SELECT @VINKey27 = ''
			SELECT @VINKey28 = ''
			SELECT @Model1 = @CursorModel
			SELECT @Model2 = ''
			SELECT @Model3 = ''
			SELECT @Model4 = ''
			SELECT @Model5 = ''
			SELECT @Model6 = ''
			SELECT @Model7 = ''
			SELECT @Model8 = ''
			SELECT @Model9 = ''
			SELECT @Model10 = ''
			SELECT @Model11 = ''
			SELECT @Model12 = ''
			SELECT @Model13 = ''
			SELECT @Model14 = ''
			SELECT @Model15 = ''
			SELECT @Model16 = ''
			SELECT @Model17 = ''
			SELECT @Model18 = ''
			SELECT @Model19 = ''
			SELECT @Model20 = ''
			SELECT @Model21 = ''
			SELECT @Model22 = ''
			SELECT @Model23 = ''
			SELECT @Model24 = ''
			SELECT @Model25 = ''
			SELECT @Model26 = ''
			SELECT @Model27 = ''
			SELECT @Model28 = ''
			SELECT @BarCodeAsterix = ''
			SELECT @AuctionCity = @CursorAuctionCity
			
			SELECT @LoopCounter = 1
		END
		ELSE
		BEGIN
			SELECT @LoopCounter = @LoopCounter + 1
			IF @LoopCounter = 1
			BEGIN
				SELECT @VINKey1 = @CursorVINKey
				SELECT @Model1 = @CursorModel
			END
			ELSE IF @LoopCounter = 2
			BEGIN
				SELECT @VINKey2 = @CursorVINKey
				SELECT @Model2 = @CursorModel
			END
			ELSE IF @LoopCounter = 3
			BEGIN
				SELECT @VINKey3 = @CursorVINKey
				SELECT @Model3 = @CursorModel
			END
			ELSE IF @LoopCounter = 4
			BEGIN
				SELECT @VINKey4 = @CursorVINKey
				SELECT @Model4 = @CursorModel
			END
			ELSE IF @LoopCounter = 5
			BEGIN
				SELECT @VINKey5 = @CursorVINKey
				SELECT @Model5 = @CursorModel
			END
			ELSE IF @LoopCounter = 6
			BEGIN
				SELECT @VINKey6 = @CursorVINKey
				SELECT @Model6 = @CursorModel
			END
			ELSE IF @LoopCounter = 7
			BEGIN
				SELECT @VINKey7 = @CursorVINKey
				SELECT @Model7 = @CursorModel
			END
			ELSE IF @LoopCounter = 8
			BEGIN
				SELECT @VINKey8 = @CursorVINKey
				SELECT @Model8 = @CursorModel
			END
			ELSE IF @LoopCounter = 9
			BEGIN
				SELECT @VINKey9 = @CursorVINKey
				SELECT @Model9 = @CursorModel
			END
			ELSE IF @LoopCounter = 10
			BEGIN
				SELECT @VINKey10 = @CursorVINKey
				SELECT @Model10 = @CursorModel
			END
			ELSE IF @LoopCounter = 11
			BEGIN
				SELECT @VINKey11 = @CursorVINKey
				SELECT @Model11 = @CursorModel
			END
			ELSE IF @LoopCounter = 12
			BEGIN
				SELECT @VINKey12 = @CursorVINKey
				SELECT @Model12 = @CursorModel
			END
			ELSE IF @LoopCounter = 13
			BEGIN
				SELECT @VINKey13 = @CursorVINKey
				SELECT @Model13 = @CursorModel
			END
			ELSE IF @LoopCounter = 14
			BEGIN
				SELECT @VINKey14 = @CursorVINKey
				SELECT @Model14 = @CursorModel
			END
			ELSE IF @LoopCounter = 15
			BEGIN
				SELECT @VINKey15 = @CursorVINKey
				SELECT @Model15 = @CursorModel
			END
			ELSE IF @LoopCounter = 16
			BEGIN
				SELECT @VINKey16 = @CursorVINKey
				SELECT @Model16 = @CursorModel
			END
			ELSE IF @LoopCounter = 17
			BEGIN
				SELECT @VINKey17 = @CursorVINKey
				SELECT @Model17 = @CursorModel
			END
			ELSE IF @LoopCounter = 18
			BEGIN
				SELECT @VINKey18 = @CursorVINKey
				SELECT @Model18 = @CursorModel
			END
			ELSE IF @LoopCounter = 19
			BEGIN
				SELECT @VINKey19 = @CursorVINKey
				SELECT @Model19 = @CursorModel
			END
			ELSE IF @LoopCounter = 20
			BEGIN
				SELECT @VINKey20 = @CursorVINKey
				SELECT @Model20 = @CursorModel
			END
			ELSE IF @LoopCounter = 21
			BEGIN
				SELECT @VINKey21 = @CursorVINKey
				SELECT @Model21 = @CursorModel
			END
			ELSE IF @LoopCounter = 22
			BEGIN
				SELECT @VINKey22 = @CursorVINKey
				SELECT @Model22 = @CursorModel
			END
			ELSE IF @LoopCounter = 23
			BEGIN
				SELECT @VINKey23 = @CursorVINKey
				SELECT @Model23 = @CursorModel
			END
			ELSE IF @LoopCounter = 24
			BEGIN
				SELECT @VINKey24 = @CursorVINKey
				SELECT @Model24 = @CursorModel
			END
			ELSE IF @LoopCounter = 25
			BEGIN
				SELECT @VINKey25 = @CursorVINKey
				SELECT @Model25 = @CursorModel
			END
			ELSE IF @LoopCounter = 26
			BEGIN
				SELECT @VINKey26 = @CursorVINKey
				SELECT @Model26 = @CursorModel
			END
			ELSE IF @LoopCounter = 27
			BEGIN
				SELECT @VINKey27 = @CursorVINKey
				SELECT @Model27 = @CursorModel
			END
			ELSE IF @LoopCounter = 28
			BEGIN
				SELECT @VINKey28 = @CursorVINKey
				SELECT @Model28 = @CursorModel
			END
			
		END
		
		SELECT @LastOrderID = @CursorOrdersID
		
		FETCH AuctionOrdersCursor INTO @CursorOrdersID, @CursorOrderDate,@CursorAuctionCode,@CursorDealerName,
			@CursorDealerNumber, @CursorDealerCity, @CursorDealerState, @CursorDestinationLocation,
			@CursorDestinationCity, @CursorDestinationState, @CursorDestinationZip, @CursorRate,
			@CursorUnits, @CursorDealerContact, @CursorSalesperson, @CursorComments, @CursorNewDealerFlag,
			@CursorVINKey, @CursorModel, @CursorAuctionCity

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE AuctionOrdersCursor
		DEALLOCATE AuctionOrdersCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE AuctionOrdersCursor
		DEALLOCATE AuctionOrdersCursor
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
