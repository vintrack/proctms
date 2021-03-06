USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetVehicleByVIN]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






CREATE    PROCEDURE [dbo].[spGetVehicleByVIN]
	@VIN varchar(18)
AS
BEGIN
	/************************************************************************
	*	spGetVehicleByVIN						*
	*									*
	*	Description							*
	*	-----------							*
	*	This returns the first Vehicle that is not delivered find in database *
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/22/2011     Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	declare @VehicleID int

	/*
	Select	Top 1 @VehicleID = VehicleID
	From	Vehicle	
	Where	VehicleStatus <> 'Delivered' And (VIN = @vin or (len(@vin) < 17 and VIN Like '%' + @vin)) 
	order by VehicleID desc
	*/

	Select	Top 1 VehicleID
	From	Vehicle	
	Where	VehicleStatus <> 'Delivered' And (VIN = @vin or (len(@vin) < 17 and VIN Like '%' + @vin)) 
	order by VehicleID desc

	/*
	If we could not find any vehicle with status <> 'Delivered', try to find a vehicle with any status
	*/
/*
	if (@VehicleID is null)
	begin
		Select	Top 1 @VehicleID = VehicleID
		From	Vehicle	
		Where	(VIN = @vin or (len(@vin) < 17 and VIN Like '%' + @vin)) 
		order by VehicleID desc		
	end
*/

/*
	select @VehicleID as VehicleID
*/

	SET nocount off
END





GO
