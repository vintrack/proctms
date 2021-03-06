USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetFindVehicleDetails]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



/***************************************************
	CREATED	: Jan 19 2012 (Comi)
	UPDATED	: 
	DESC	: Get the Vehicle Details for the Subaru - Find Vehicle screen for the ONLINE mode
****************************************************/
CREATE PROCEDURE [dbo].[spGetFindVehicleDetails]
	@VIN VARCHAR(20)
AS
BEGIN
	
	/* Select the information for the VIN: @VIN */
	SELECT	top 1 isnull(replace(V.FullVIN,',',''),'') AS VIN, 
			isnull(replace(V.BayLocation,',',''),'') AS Location, 
			V.LoadNumber as LoadNumber, 
			isnull(replace(V.ModelDescription,',',''),'') AS Model, 
			isnull(replace(V.ExteriorColor,',',''),'') As Color,
			isnull(replace(V.VehicleStatus,',',''),'') AS VehicleStatus,
			V.DestinationDealerCode as Dealer, 
			V.DateIn as DateIn, 
			V.DriverIn as DriverIn, 
			V.ReleaseDate as ReleaseDate, 
			convert(varchar(16), V.ShopWorkStartedDate, 120) as ThrowIn, 
			convert(varchar(16), V.ShopWorkCompleteDate, 120) as VPCComplete, 
			V.ShipawayLane as SALane, 
			V.DateOut as DateOut, 
			V.DriverOut as DriverOut,
			v.VPCVehicleID,
			isnull(v.SDCVehicleID, 0) as VehicleID
	into #Results
	FROM	VPCVehicle V
	--inner join vehicle veh on v.SDCVehicleID = veh.VehicleID
	WHERE	V.FullVIN = @VIN 
	Order by DateIn desc


	declare @VPCVehicleID int

	select @VPCVehicleID = VPCVehicleID
	from #Results

	select * from #Results
	drop table #Results

	declare @Damages table (InspectionType varchar(255), InspectionDate datetime, DamageCode varchar(4000))

	/* Get all Inspections and DamageCode for the VIN: @VPCVehicleID */
	insert into @Damages
	select c.Value1 as InspectionType, 
		InspectionDate,
		vdd.DamageCode
	from VPCVehicle vpc
	inner join Vehicle v on vpc.SDCVehicleID = v.VehicleID
	left join VehicleInspection vi on v.VehicleID = vi.VehicleID
	inner join Code c on c.CodeType = 'InspectionType' and vi.InspectionType = c.Code 
	left join VehicleDamageDetail vdd on vi.VehicleInspectionID = vdd.VehicleInspectionID
	where  vpc.VPCVehicleid = @VPCVehicleID
	order by c.Value1 asc, vi.InspectionDate asc, vdd.DamageCode asc

	--select * from @Damages

	/* 
		Concatenate the DamageCodes pertaining to the same InspectionType and InspectionDate.
		It is very IMPORTANT that the rows in the @Damages table are ordered by InspectionType and InspectionDate.
	*/
	declare @OldInspectionType varchar(255)
	declare @OldInspectionDate datetime
	declare @JoinedValues varchar (4000)

	set @OldInspectionType = ''
	set @OldInspectionDate = ''
	set @JoinedValues = ''

	update @Damages
	set @JoinedValues = DamageCode = 
		case when InspectionType = @OldInspectionType and InspectionDate = @OldInspectionDate
			then @JoinedValues + '|' + DamageCode 
			else '' + DamageCode 
		end,
		@OldInspectionType = InspectionType,
		@OldInspectionDate = InspectionDate

	--select * from @Damages	

	select InspectionType, max(DamageCode), convert(varchar, InspectionDate, 101) + ' ' + convert(varchar, InspectionDate, 108) as FormatedInspectionDate,
			InspectionDate
	from @Damages
	group by InspectionType, InspectionDate
	order by InspectionDate, InspectionType
	/*  */
END

GO
