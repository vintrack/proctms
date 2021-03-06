USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spDormLocationInfo]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		David Maibor
-- Create date: 3/22/18
-- Description:	Reservation info for specified dorm, for DormConfirmation program
-- 4/19/18 D.Maibor: add Truck Number
-- =============================================
CREATE PROCEDURE [dbo].[spDormLocationInfo]
	@ReservationDate date,
	@DormLocation varchar(40)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT 
	room.DormRoom,
	CASE
		WHEN ISNULL(room.AvailableInd,0) = 0 THEN 'BLOCKED'
		WHEN ReservationID IS NULL THEN 'AVAILABLE'
		WHEN res.ReservationID IS NOT NULL AND res.ConfirmDate IS NULL THEN 'RESERVED' 
		ELSE 'CONFIRMED'
	END AS Status,
	room.DormRoomID,
	res.ReservationID,
	res.UserID,
	Users.UserCode,
	Users.FirstName + ' ' + Users.LastName AS UserName,
	CASE
		WHEN trk.TruckNumber IS NOT NULL THEN '(Trk# ' + TruckNumber + ')'
		ELSE ''
	END AS TruckNumber
	FROM
	DormRooms room
	LEFT OUTER JOIN DormReservations res on res.DormRoomID=room.DormRoomID
			AND res.ReservationDate=@ReservationDate
	LEFT OUTER JOIN Users on Users.UserID=res.UserID
	LEFT OUTER JOIN Driver dr on dr.UserID=res.UserID
	LEFT OUTER JOIN Truck trk on trk.TruckID = dr.CurrentTruckID
	WHERE room.DormLocation=@DormLocation
	order by room.SortOrder;
END
GO
