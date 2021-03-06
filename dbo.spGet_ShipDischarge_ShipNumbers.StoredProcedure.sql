USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGet_ShipDischarge_ShipNumbers]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




CREATE procedure [dbo].[spGet_ShipDischarge_ShipNumbers]
as
begin
	/************************************************************************
	*	spGet_ShipDischarge_ShipNumbers						*
	*														*
	*	Description											*
	*	-----------											*
	*	This returns the list of Ship Numbers				*
	*	for the DAI YMS handheld application				*
	*	(for the Ship Discharge screen). 					*
	*														*
	*	Change History										*
	*	--------------										*
	*	Date       Init's Description						*
	*	---------- ------ ----------------------------------------	*
	*	10/05/2012    CristiP    Initial version (based on Colin's script)*
	*									*
	************************************************************************/

	SELECT DISTINCT ShipNumber
	FROM VPCVehicle
	WHERE DateIn IS NULL
	AND ShipNumber IS NOT NULL
	ORDER BY ShipNumber DESC
end



GO
