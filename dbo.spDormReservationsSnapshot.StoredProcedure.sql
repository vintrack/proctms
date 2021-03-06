USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spDormReservationsSnapshot]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		David Maibor
-- Create date: 4/13/18
-- Description:	Return Dorm Room, User name  for the specified Dorm Location, Res. Date for all rooms
-- 4/24/18 D.Maibor: add DAI Guest when room not available
-- 4/20/18 D.Maibor: add trucknumber
-- =============================================
CREATE PROCEDURE [dbo].[spDormReservationsSnapshot]
	@ReservationDate Date,
	@DormLocation varchar(40)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	select 
	rm.DormRoom,
	case
		when rm.AvailableInd=0 then '[DAI Guest]'
		when us.FirstName is null then '[none]'
		else us.FirstName + ' ' + us.LastName 
	end as name,
	case
		when TruckNumber is null then ''
		else '(#' + tr.trucknumber + ')'
	end as trucknumber
	from 
	DormRooms rm 
	left outer join dormreservations res on res.DormRoomID=rm.DormRoomID 
		and res.ReservationDate = @ReservationDate
	left outer join users us on us.userid=res.UserID
	left outer join driver dr on dr.userid=res.userid
	left outer join truck tr on tr.truckid=dr.CurrentTruckID
	where 
	rm.DormLocation=@DormLocation
	order by rm.DormLocation,SortOrder
    
END
GO
