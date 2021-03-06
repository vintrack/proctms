USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetStorageNotification]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO








/***************************************************
	CREATED	: May 14 2013 (Atti)
	UPDATED	: 
	DESC	: Get the List for Storage Notification
****************************************************/
CREATE   PROCEDURE [dbo].[spGetStorageNotification]
AS
BEGIN
	create table #StorageNotification([PortStorageVehiclesID] int not null, [VIN] varchar(17) null, [BayLocation] varchar(20) null, 
		[Make] varchar(50) null, [Model] varchar(50) null, [Color] varchar(20) null, [DealerName] varchar(50) null, 
		[Release] datetime null, [DateIn] datetime null, [DateOut] datetime null, [EstimatedPickupDate] datetime null, 
		[DealerPrintDate] datetime null, [DealerPrintBy] varchar(50), [RequestPrintedInd] int null, 
		[RequestPrintedBatchId] int null, [DateRequestPrinted] datetime null
	)

	/*get the full list*/
	insert into #StorageNotification
	SELECT psv.[PortStorageVehiclesID], psv.[VIN], psv.[BayLocation], 
		psv.[Make], psv.[Model], psv.[Color], 
	
		CASE WHEN DATALENGTH(C.ShortName) > 0 
		THEN isnull(C.ShortName, '')
		ELSE isnull(C.CustomerName, '') END as DealerName,
	
		psv.[DateRequested] as Release,
		psv.[DateIn], psv.[DateOut],  psv.[EstimatedPickupDate],
		psv.DealerPrintDate, psv.DealerPrintBy, psv.RequestPrintedInd, psv.RequestPrintedBatchId, psv.DateRequestPrinted
	FROM [dbo].[PortStorageVehicles] psv
	left outer join [dbo].[Customer] c on c.[CustomerID] = psv.[CustomerID]
	where 
	psv.VehicleStatus = 'Requested'
	and psv.RecordStatus = 'Active'
	and psv.RequestPrintedInd = 0
	and (psv.LastPhysicalDate < psv.DateRequested or psv.LastPhysicalDate is NULL)
	order by psv.DateRequested asc

	/*create a copy of the list*/
	select *
	into #StorageNotificationFullList
	from #StorageNotification


	/*remove what was already sent last time*/	
	delete sn from #StorageNotification sn
	inner join [DataForStorageNotification] dsn on dsn.[PortStorageVehiclesID] = sn.[PortStorageVehiclesID]
	
	/*truncate the [DataForStorageNotification] table and add the latest full list*/
	truncate table [DataForStorageNotification]

	insert into [DataForStorageNotification] (PortStorageVehiclesID)
	select distinct [PortStorageVehiclesID] from #StorageNotificationFullList

	select * from #StorageNotification

	drop table #StorageNotification
	drop table #StorageNotificationFullList
END
GO
