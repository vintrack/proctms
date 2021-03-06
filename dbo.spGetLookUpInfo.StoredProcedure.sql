USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetLookUpInfo]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






CREATE     procedure [dbo].[spGetLookUpInfo]
@Code as varchar (50)
as
begin
	/************************************************************************
	*	spGetLookUpInfo						*
	*									*
	*	Description							*
	*	-----------							*
	*	This returns LookUp Information for the DAI YMS handheld 	*
	*	application. 							*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/29/2011        Initial version				*
	*									*
	************************************************************************/	

	set nocount on	

	if (@Code = 'DamageAreaCode')
	begin
		Select replace(isnull(Code, ''), ',', ';') + ',' + 
			replace(isnull(CodeDescription, ''), ',', ';') + ',' + 
			replace(isnull(Value1, ''), ',', ';') as CSVValues
			/* , Code, CodeDescription, Value1 */
		from Code 
		where CodeType ='DamageAreaCode' and RecordStatus ='Active'
		order by SortOrder asc
	end
	else
	if (@Code = 'DamageTypeCode')
	begin
		Select replace(isnull(Code, ''), ',', ';') + ',' + 
			replace(isnull(CodeDescription, ''), ',', ';') + ',' + 
			replace(isnull(Value1, ''), ',', ';') as CSVValues
			/* , Code, CodeDescription, Value1 */
		from Code
		where CodeType ='DamageTypeCode' and RecordStatus ='Active'
		order by SortOrder asc
	end
	else
	if (@Code = 'DamageSeverityCode')
	begin
		Select replace(isnull(Code, ''), ',', ';') + ',' + 
			replace(isnull(CodeDescription, ''), ',', ';') + ',' + 
			replace(isnull(Value1, ''), ',', ';') as CSVValues
			/* , Code, CodeDescription, Value1 */
		from Code
		where CodeType ='DamageSeverityCode' and RecordStatus ='Active'
		order by SortOrder asc
	end
	else
	if (@Code = 'Inspect')
	begin
		SELECT replace(isnull(U.UserCode, ''), ',', ';') + ',' +
			replace(isnull(U.PortPassIDNumber, ''), ',', ';') + ',' +
			replace(isnull(U.FirstName, ''), ',', ';') + ' ' + replace(isnull(U.LastName, ''), ',', ';') as CSVValues
			/*,U.UserCode, U.PortPassIDNumber, U.FirstName+' '+U.LastName */
		FROM Users U
		WHERE U.RecordStatus = 'Active'
		AND U.UserID IN (SELECT UR.UserID FROM UserRole UR WHERE UR.RoleName = 'YardOperations')
		ORDER BY U.PortPassIDNumber
	end
	else
	if (@Code = 'ExportASN')
	begin
		/* 
		   This look-up file needs a header line as File Identifier
		   The IsData field was added to be able to keep the header line on the top
		*/
		SELECT convert(varchar, getdate(), 113) as CSVValues, '' as VIN, 0 as IsData

		UNION

		SELECT replace(C.HandheldScannerCustomerCode, ',', ';') + ',' +
			replace(AEV.VIN, ',', ';') + ',' +  
			replace(AEV.DestinationName, ',', ';') as CSVValues, AEV.VIN as VIN, 1 as IsData
		FROM AutoportExportVehicles AEV
		LEFT JOIN Customer C ON AEV.CustomerID = C.CustomerID
		WHERE AEV.VehicleStatus = 'Pending' and isnull(AEV.VIN, '') <> ''

		ORDER BY IsData, VIN 
	end
	else
	if (@Code = 'ExportCustomer')
	begin		
		SELECT replace(C.HandheldScannerCustomerCode, ',', ';') + ',' + 
			CASE WHEN DATALENGTH(C.ShortName) > 0 
				THEN replace(C.ShortName, ',', ';') 
				ELSE replace(C.CustomerName, ',', ';') 
			END as CSVValues
		FROM Customer C
		WHERE C.RecordStatus = 'Active'
		AND C.AutoportExportCustomerInd = 1
		ORDER BY C.HandheldScannerCustomerCode
	end
	else
	if (@Code = 'ExportPort')
	begin	
		SELECT replace(C.Value2, ',', ';') + ',' + replace(C.Code, ',', ';') as CSVValues
		FROM Code C
		WHERE C.CodeType = 'ExportDischargePort'
		AND C.RecordStatus = 'Active'
		AND C.Code <> ''
		ORDER BY C.SortOrder, C.Value2
	end
	else
	if (@Code = 'ColorCode')
	begin
		SELECT replace(Code, ',', ';') + ',' + replace(CodeDescription, ',', ';') as CSVValues
		FROM Code
		WHERE  CodeType = 'Color'
		AND RecordStatus = 'Active'
		ORDER BY SortOrder, Code
	end
	else
	if (@Code = 'ExportSizeClass')
	begin
		SELECT	replace(Code, ',', ';') + ',' + replace(CodeDescription, ',', ';') as CSVValues
		FROM	Code C
		WHERE	C.CodeType = 'SizeClass'
				AND C.CodeDescription <> 'N/A'
				AND C.RecordStatus = 'Active'
		ORDER	BY SortOrder, Code
	end
	else
	if (@Code = 'StorageReceiptDealer')
	begin		
		SELECT replace(C.CustomerCode, ',', ';') + ',' +
			CASE WHEN DATALENGTH(C.ShortName) > 0 
				THEN isnull(replace(C.ShortName, ',', ';'), '') 
				ELSE isnull(replace(C.CustomerName, ',', ';'), '') 
			END as CSVValues
		FROM Customer C
		WHERE C.RecordStatus = 'Active'
		AND C.PortStorageCustomerInd = 1
		ORDER BY CASE WHEN DATALENGTH(C.ShortName) > 0 
					THEN isnull(replace(C.ShortName, ',', ';'), '') 
					ELSE isnull(replace(C.CustomerName, ',', ';'), '') 
				 END
	end
	else
	if (@Code = 'StorageNotification')
	begin
		select convert(varchar(20), getdate(), 112) + '_' + convert(varchar(20), getdate(), 114) as HeaderLine
		
		SELECT convert(varchar, psv.[PortStorageVehiclesID]) + ',' + 
			convert(varchar, psv.[VIN]) + ',' + 

			replace(replace(isnull(psv.[BayLocation], ''), '#', '#0'), ',', '#1') + ',' +
			replace(replace(isnull(psv.[Make], ''), '#', '#0'), ',', '#1') + ',' +
			replace(replace(isnull(psv.[Model], ''), '#', '#0'), ',', '#1') + ',' +
			replace(replace(isnull(psv.[Color], ''), '#', '#0'), ',', '#1') + ',' +
		
			CASE WHEN DATALENGTH(C.ShortName) > 0 
			THEN replace(replace(isnull(C.ShortName, ''), '#', '#0'), ',', '#1')
			ELSE replace(replace(isnull(C.CustomerName, ''), '#', '#0'), ',', '#1') END + ',' +
		
			isnull(convert(varchar, psv.DateRequested, 101) + ' ' + convert(varchar, psv.DateRequested, 108), '') + ',' +
			isnull(convert(varchar, psv.DateIn, 101) + ' ' + convert(varchar, psv.DateIn, 108), '') + ',' +
			isnull(convert(varchar, psv.DateOut, 101) + ' ' + convert(varchar, psv.DateOut, 108), '') + ',' +
			isnull(convert(varchar, psv.EstimatedPickupDate, 101) + ' ' + convert(varchar, psv.EstimatedPickupDate, 108), '')
		FROM [PortStorageVehicles] psv
		left outer join [Customer] c on c.[CustomerID] = psv.[CustomerID]
		where psv.VehicleStatus = 'Requested'
		and psv.RecordStatus = 'Active'
		and 
		(	
			psv.RequestPrintedInd = 0

			or

			(psv.LastPhysicalDate < psv.DateRequested or psv.LastPhysicalDate is NULL)
		)
		order by psv.DateRequested asc
	end
	else
	begin
		raiserror (N'The value of the @Code parameter should be one of these {''DamageAreaCode'', ''DamageTypeCode'', ''DamageSeverityCode'', ''Inspect'',
			''ExportASN'', ''ExportCustomer'', ''ExportPort'', ''ColorCode'', ''ExportSizeClass'', ''StorageReceiptDealer'', ''StorageNotification''}', 16, 1)
	end

	set nocount off
end

GO
