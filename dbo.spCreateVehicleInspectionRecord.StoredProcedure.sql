USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spCreateVehicleInspectionRecord]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spCreateVehicleInspectionRecord](
	@VehicleID		int,
	@InspectionType		int,
	@InspectionDate		datetime,
	@InspectedBy		varchar(20),	-- Can be either user name or application name
	@AttendedInd		int,		-- 0 = No, 1 = Yes
	@SubjectToInspectionInd	int,
	@CleanVehicleInd	int,
	@Notes			varchar(1000),
	@deliveryInitials	varchar(5) = '',
	@LegsID			int = 0
	)
AS
BEGIN
	/************************************************************************
	*	spCreateVehicleInspectionRecord					*
	*									*
	*	Description							*
	*	-----------							*
	*	Creates the parent record for vehicle inspection damage codes. 	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/04/2005 CMK    Initial version				*
	*	06/25/2007 JEP    added delivery initials			*
	*	05/14/2012 CMK    Added STI Email Code				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@VehicleInspectionID	int,
		@DamageCodeCount	int,
		@CustomerID		int,
		@LoadNumber		varchar(20),
		@DropoffLocationID	int,
		@VIN			varchar(17),
		@VehicleYear		varchar(6),
		@Make			varchar(50),
		@Model			varchar(50),
		@DropoffDate		datetime,
		@CreationDate		datetime,
		@CreatedBy		varchar(20),
		@UpdatedDate		datetime,
		@UpdatedBy		varchar(20),
		@ReturnCode		int,
		@ReturnMessage		varchar(50),
		@ReturnVehicleInspID	int,
		@ErrorID		int,
		@Msg			varchar(50)

	SELECT @ErrorID = 0
			
	BEGIN TRAN
	
	SELECT @DamageCodeCount = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @InspectedBy
	
	IF @InspectionType IN (2, 3, 6) AND @LegsID = 0
	BEGIN
		SELECT @LegsID = LegsID
		FROM Legs
		WHERE VehicleID = @VehicleID
		AND (CASE WHEN @InspectionType = 2 THEN 1 ELSE 0 END = LegNumber
		OR CASE WHEN @InspectionType IN (3, 6) THEN 1 ELSE 0 END = FinalLegInd)
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting LegsID'
			GOTO Error_Encountered
		END
	END
	
	INSERT INTO VehicleInspection(
		VehicleID,
		InspectionType,
		InspectionDate,
		InspectedBy,
		DamageCodeCount,
		AttendedInd,
		SubjectToInspectionInd,
		CleanVehicleInd,
		Notes,
		CreationDate,
		CreatedBy,
		UpdatedDate,
		UpdatedBy,
		DeliveryInitials,
 		LegsID  /*  Added legs value */
	)
	VALUES(
		@VehicleID,
		@InspectionType,
		@InspectionDate,
		@InspectedBy,
		@DamageCodeCount,
		@AttendedInd,
		@SubjectToInspectionInd,
		@CleanVehicleInd,
		@Notes,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy,
		@deliveryInitials,
		@LegsID  /*  Added legs value */
	)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating Vehicle Inspection Record'
		GOTO Error_Encountered
	END
	
	SELECT @VehicleInspectionID = @@IDENTITY
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the identity value'
		GOTO Error_Encountered
	END
	
	--if this is an sti delivery, insert into the STIDeliverEmail table
	IF @SubjectToInspectionInd = 1
	BEGIN
		SELECT @CustomerID = V.CustomerID,
		@LoadNumber = L2.LoadNumber,
		@DropoffLocationID = V.DropoffLocationID,
		@VIN = V.VIN,
		@VehicleYear = V.VehicleYear,
		@Make = V.Make,
		@Model = V.Model,
		@DropoffDate = L.DropoffDate
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.FinalLegInd = 1
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		WHERE V.VehicleID = @VehicleID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting STI Delivery Email details'
			GOTO Error_Encountered
		END
		INSERT INTO STIDeliveryEmail(
			CustomerID,
			VehicleID,
			LoadNumber,
			DropoffLocationID,
			VIN,
			VehicleYear,
			Make,
			Model,
			DropoffDate,
			EmailSentInd,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@CustomerID,
			@VehicleID,
			@LoadNumber,
			@DropoffLocationID,
			ISNULL(@VIN,''),
			ISNULL(@VehicleYear,''),
			ISNULL(@Make,''),
			ISNULL(@Model,''),
			@DropoffDate,
			0,		--EmailSentInd,
			@CreationDate,
			@CreatedBy
		)
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating STI Delivery Email record'
			GOTO Error_Encountered
		END
	END
 	Error_Encountered:
	IF @ErrorID <> 0
	BEGIN
		ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Msg
		SELECT @ReturnVehicleInspID = 0
		
	END
	ELSE
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Inspection Record Created Successfully'
		SELECT @ReturnVehicleInspID = @VehicleInspectionID
		
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM', @ReturnVehicleInspID  AS 'RVI'

	RETURN @ReturnCode
END

GO
