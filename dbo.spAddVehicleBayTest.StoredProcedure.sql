USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddVehicleBayTest]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spAddVehicleBayTest](
		@VIN		varchar(20), 
		@BayLocation	varchar(20), 
		@CreatedBy	varchar(20) 
	)
AS
BEGIN
	/************************************************************************
	*	spAddVehicleBayTest						*
	*									*
	*	Description							*
	*	-----------							*
	*	Adds a new VehicleBayTest record.			 	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/20/2005 JEP    Initial version				*
	*	01/25/2007 CMK    Changed Code to update the bay location in the*
	*                         Dealer Storage table for the specified vin	*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@VehicleID		int,
		@UpdatedDate		datetime,
		@OldBayLocation 	varchar(20),
		@OldVehicleStatus	varchar(20),
		@OldDateRequested	datetime,
		@OldEstimatedPickupDate	datetime,
		@OldRequestPrintedInd	int,
		@OldDealerPrintDate	datetime,
		@OldDealerPrintBy	varchar(20),
		@OldRequestedBy		varchar(20),
		@ReturnCode		int,
		@ReturnMessage		varchar(50),
		@ErrorID		int,
		@Msg			varchar(50),
		@Count			int
	
	BEGIN TRAN
		
	SELECT @Count = 0
	SELECT @ErrorID = 0
	SELECT @VehicleID = 0
	SELECT @UpdatedDate = CURRENT_TIMESTAMP	
		
	IF DATALENGTH(@VIN)<1
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Msg = 'No VIN Number Entered.'
		GOTO Error_Encountered
	END
		
	--get the vehicle id
	SELECT @Count = NULL
	
	SELECT @Count = COUNT(*)
	FROM PortStorageVehicles PSV
	WHERE PSV.VIN LIKE '%'+@VIN+'%'
	AND PSV.DateOut IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the VehicleID'
		GOTO Error_Encountered
	END
		
	IF @Count IS NULL OR @Count = 0
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Msg = 'VIN not found in database'
		GOTO Error_Encountered
	END
	IF @Count > 1
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Msg = 'Multiple matches found for VIN'
		GOTO Error_Encountered
	END
		
	SELECT TOP 1 @VehicleID = PortStorageVehiclesID,
	@OldBayLocation = BayLocation,
	@OldVehicleStatus = VehicleStatus,
	@OldDateRequested = DateRequested,
	@OldEstimatedPickupDate = EstimatedPickupDate,
	@OldRequestPrintedInd = RequestPrintedInd,
	@OldDealerPrintDate = DealerPrintDate,
	@OldDealerPrintBy = DealerPrintBy,
	@OldRequestedBy = RequestedBy
	FROM PortStorageVehicles PSV
	WHERE PSV.VIN LIKE '%'+@VIN+'%'
	AND PSV.DateOut IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the VehicleID'
		GOTO Error_Encountered
	END
	
	IF @OldBayLocation = 'GAT' AND @OldBayLocation <> @BayLocation
	BEGIN
		SELECT @OldVehicleStatus = 'InInventory'
		SELECT @OldDateRequested = NULL
		SELECT @OldEstimatedPickupDate = NULL
		SELECT @OldRequestPrintedInd = 0
		SELECT @OldDealerPrintDate = NULL
		SELECT @OldDealerPrintBy = NULL
		SELECT @OldRequestedBy = NULL
	END
	
	UPDATE PortStorageVehicles
	SET BayLocation = @BayLocation,
	VehicleStatus = @OldVehicleStatus,
	DateRequested = @OldDateRequested,
	EstimatedPickupDate = @OldEstimatedPickupDate,
	RequestPrintedInd = @OldRequestPrintedInd,
	DealerPrintDate = @OldDealerPrintDate,
	DealerPrintBy = @OldDealerPrintBy,
	RequestedBy = @OldRequestedBy,
	UpdatedDate = @UpdatedDate,
	UpdatedBy = @CreatedBy
	WHERE PortStorageVehiclesID = @VehicleID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the Vehicle Record'
		GOTO Error_Encountered
	END
			
		
	Error_Encountered:
	IF @ErrorID <> 0
	BEGIN
		ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Msg
		GOTO Do_Return
	END
	ELSE
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'BayLocation Updated Successfully'
		GOTO Do_Return
	END
	
	Do_Return:
	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM', @VehicleID as 'VehicleID'
	
	RETURN @ReturnCode
END


GO
