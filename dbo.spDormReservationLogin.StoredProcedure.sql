USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spDormReservationLogin]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David Maibor
-- Create date: 3/12/18
-- Description:	Check UserCode/Password against Users, UserRole,
--	Code, DormReservations tables

-- Valid login: 
--	UserCode & Pwd in Users table & RecordStatus = 'Active'
--	UserID in UserRole table and has RoleName IN ('Administrator','Driver','Dispatch','Dorm Mgr')
--	Code table shows Role from UserRole table is Active
--	Returns, 'OK' AS result, UserID,RoleName, 'INVALID' if not found
--  Returns ReservationID,DormLocation, DormRoom (if any) for Reservation Day
--	Reservation Day: day before if current time is between 12:00 - 6:00 AM, current day otherwise
--	[XLE'D - Reservation Day: day before if current time is between 12:00 - 7:00 AM, current day otherwise]
--	Decision by Bobby to allow Drivers to reserve/xle up to 2 AM of next day

--	Invalid Login: returns 'INVALID' AS result
--	7/20/18 D.Maibor: add UserCode to @tmp table to return value. 
--	5/8/18 D.Maibor: Per B.Kraez, change day before time to 12:00 - 6:00 AM. 4-5 drivers made mistake of reserving before 7 AM. 
-- =============================================
CREATE PROCEDURE [dbo].[spDormReservationLogin]
	@usercode varchar(20),
	@password varchar(20)
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   DECLARE 
   @reservationdate date = CURRENT_TIMESTAMP,
   @totalrecs int;

   DECLARE @tmp TABLE (
    result varchar (15),
	UserID int,
	UserCode varchar(20),
	RoleName varchar(25),
	DriverID int,
	FirstName varchar(30),
	LastName varchar(30),
	ReservationDate date,
	ReservationID int,
	DormLocation varchar (40),
	DormRoom varchar(40),
	DormRoomID int,
	AlternateEmailAddress varchar(50)
   );

   --If current time is between 12:00:01 - 2 AM, set Reservationdate to day before
   IF CONVERT(time,SYSDATETIME()) BETWEEN '00:00:01' AND '06:00:00'
   SET @reservationdate = DATEADD(DAY,-1,@reservationdate);

   INSERT INTO @tmp
	SELECT 
	null AS result,
	u.UserID,
	u.UserCode,
	ur.RoleName,
	dr.DriverID,
	u.FirstName,
	u.LastName,
	@reservationdate AS ReservationDate,
	res.ReservationID,
	room.DormLocation,
	room.DormRoom,
	res.DormRoomID,
	u.AlternateEmailAddress
	FROM Users u
	INNER JOIN UserRole ur on ur.UserID=u.UserID
	LEFT OUTER JOIN Driver dr on dr.UserID=u.UserID and dr.RecordStatus='Active'
	and dr.OutsideCarrierInd=0
	INNER JOIN Code on Code.CodeType='UserRole'
		AND Code.RecordStatus='Active' 
		AND Code.Code = ur.RoleName
	LEFT OUTER JOIN DormReservations res on res.UserID=u.UserID 
		AND res.ReservationDate=@reservationdate
	LEFT OUTER JOIN DormRooms room on room.DormRoomID=res.DormRoomID
	WHERE u.RecordStatus='Active'
	AND u.UserCode=@usercode
	AND (u.Password=@password OR u.PIN=@password)
	AND ur.RoleName IN ('Administrator','Driver','Dispatch','Dorm Mgr')

	SELECT @totalrecs = COUNT(UserID) FROM @tmp;

	--Create 1 row w/Invalid result if no rows in @tmp
	IF @totalrecs = 0
		INSERT INTO @tmp (result) VALUES ('INVALID');
	ELSE
		UPDATE @tmp SET result='OK';

	-- Use single SELECT statement fo Entity Framework can create a class of columns for the SProc
	SELECT * FROM @tmp;

END



GO
