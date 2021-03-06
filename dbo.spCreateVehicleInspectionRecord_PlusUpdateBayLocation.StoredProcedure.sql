USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spCreateVehicleInspectionRecord_PlusUpdateBayLocation]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE  PROCEDURE [dbo].[spCreateVehicleInspectionRecord_PlusUpdateBayLocation](
	@VehicleID		int,
	@InspectionType		int,
	@InspectionDate		datetime,
	@InspectedBy		varchar(20),	-- Can be either user name or application name
	@AttendedInd		int,		-- 0 = No, 1 = Yes
	@SubjectToInspectionInd	int,
	@CleanVehicleInd	int,
	@Notes			varchar(1000),
	@deliveryInitials	varchar(5) = '',
	@BayLocation		varchar(20)
	)
AS
BEGIN
	DECLARE	@ReturnCode		int,
		@ReturnMessage		varchar(50),
		@ReturnVehicleInspID	int

	create table #tmp (ReturnCode int, ReturnMessage varchar(50), ReturnVehicleInspID int)

	insert into #tmp
	exec spCreateVehicleInspectionRecord 
		@VehicleID,
		@InspectionType,
		@InspectionDate,
		@InspectedBy,
		@AttendedInd,
		@SubjectToInspectionInd,
		@CleanVehicleInd,
		@Notes,
		@deliveryInitials


	if (ltrim(@BayLocation) <> '')
	begin
		-- update the BayLocation
		UPDATE Vehicle
		SET BayLocation = @BayLocation
		WHERE VehicleID = @VehicleID
	end
	-------------------------------

	SELECT ReturnCode AS 'RC', ReturnMessage AS 'RM', ReturnVehicleInspID  AS 'RVI'
	FROM #tmp

	select top 1 @ReturnCode = ReturnCode from #tmp

	drop table #tmp

	RETURN @ReturnCode
END




GO
