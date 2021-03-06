USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spDormReservationAdminDisplay]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		David Maibor
-- Create date: 6/13/18
-- Description:	Retrieve ADMIN Display info for All Occupants
-- =============================================
CREATE PROCEDURE [dbo].[spDormReservationAdminDisplay]
	@startdate datetime,
	@enddate datetime,
	@dormlocation varchar(40)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- Totals 
DECLARE 
@availrooms int,
@color varchar (10),
@currentdate datetime,
@currentdormroomid int,
@currentid int = 1,
@currentlocation varchar(40),
@currentsortorder int,
@guestrooms int,
@maxid int,
@maxsortorder int,
@nextlocation varchar(40),
@resrooms int,
@roominfo varchar(70),
@totalrooms int,
@userid int,
@userinfo varchar(65);

DECLARE @dormrooms TABLE
(DormRoomID int,
DormRoom varchar(40),
DormLocation varchar(40),
AvailableInd int,
SortOrder int);

DECLARE @locations TABLE
(id int identity(1,1),
location varchar(40));

DECLARE @summaryreservations TABLE
(id int identity(1,1),
resdate datetime,
location varchar(40),
resinfo varchar(50),
color varchar(10));

DECLARE @detailreservations TABLE
(
id int identity(1,1),
summaryid int,
sortorder int,
roominfo varchar(70)
);

-- Set up @locations table for outer loop
if (@dormlocation != 'All')
	INSERT INTO @locations (location) values (@dormlocation);
else
	INSERT INTO @locations 
	SELECT Code FROM Code 
	WHERE CodeType='DormLocation' and Value2='1' and RecordStatus='Active'
	ORDER BY Code;

SELECT @maxid = MAX(id) from @locations;
	
-- Loop to process each location
WHILE @currentid <= @maxid
BEGIN
	SELECT @currentlocation = location FROM @locations WHERE id=@currentid;

	-- Get the total rooms & guest rooms for @currentlocation
	SELECT @totalrooms = count(DormRoomID) FROM DormRooms WHERE DormLocation=@currentlocation;
	SELECT @guestrooms = count(DormRoomID) FROM DormRooms WHERE DormLocation=@currentlocation and AvailableInd=0;

	-- Loop to process each day of @startdate/@enddate for current loc
	SET @currentdate = @startdate;
	WHILE @currentdate <= @enddate
	BEGIN
		SELECT @resrooms =
		count(ReservationID)
		FROM DormReservations
		WHERE ReservationDate=@currentdate 
		and DormRoomID in 
		(SELECT DormRoomID FROM DormRooms
		WHERE DormLocation = @currentlocation); 

		Set @availrooms = @totalrooms - @resrooms - @guestrooms;
		IF @availrooms = 0
			SET @color = 'red';
		ELSE
			SET @color = 'blue';

		-- Create rec in @summaryreservations
		INSERT INTO @summaryreservations(resdate,location,resinfo,color)
		VALUES (@currentdate,@currentlocation,@currentlocation + ' (' + CONVERT(varchar(2),@availrooms) + ')',
		@color);

		SET @currentdate = DATEADD(DAY,1,@currentdate);
	END	-- Loop for each day (@currentdate)

	SET @currentid = @currentid + 1;
END	-- Loop for @currentID (Location)

-- Get detailed room list for each res in @summaryreservations
SET @currentid = 1;
SELECT @maxid = MAX(id) from @summaryreservations;
SET @currentlocation = '';

-- Loop to process each rec summaryres
WHILE @currentid <= @maxid
BEGIN
	SELECT @currentdate = resdate FROM @summaryreservations WHERE id=@currentid;
	SELECT @nextlocation = location FROM @summaryreservations WHERE id=@currentid;

	-- Load @dormrooms if @nextlocation <> @currentlocation
	IF @currentlocation <> @nextlocation 
	BEGIN
		SET @currentlocation = @nextlocation;

		DELETE @dormrooms;

		INSERT INTO @dormrooms (DormRoomID,DormRoom,DormLocation,SortOrder,AvailableInd)
		SELECT DormRoomID,DormRoom,DormLocation,SortOrder,AvailableInd
		FROM DormRooms
		WHERE DormLocation = @nextlocation;
	END

	-- Loop to process each room, use SortOrder to cycle through the rooms
	SET @currentsortorder = 1;
	SELECT @maxsortorder = MAX(SortOrder) from @dormrooms;
	
	WHILE @currentsortorder <= @maxsortorder
	BEGIN
		SELECT @currentdormroomid = DormRoomID FROM @dormrooms WHERE SortOrder=@currentsortorder;
		SELECT @roominfo = DormRoom FROM @dormrooms WHERE SortOrder=@currentsortorder;

		-- Set @userinfo as [AVAILABLE]
		SET @userinfo = ' [AVAILABLE]';

		-- Change to [DAI GUEST] if room is unavailable
		IF EXISTS (SELECT DormRoomID FROM @dormrooms WHERE SortOrder=@currentsortorder AND AvailableInd=0)
		SET @userinfo = ' [DAI GUEST]';

		-- Change to User Fname + LName if a res exists
		IF EXISTS (SELECT ReservationID FROM DormReservations 
			WHERE ReservationDate=@currentdate
			AND DormRoomID=@currentdormroomid)
		BEGIN
			SELECT @userid = UserID FROM DormReservations 
			WHERE ReservationDate=@currentdate
			AND DormRoomID=@currentdormroomid;

			SELECT @userinfo = ' [' + SUBSTRING(FirstName,1,1) + '. ' + LastName + ']'
				FROM Users WHERE UserID=@userid;
		END

		SET @roominfo = @roominfo + @userinfo;

		-- Create a rec in @detailreservations for the room
		INSERT INTO @detailreservations (summaryid,sortorder,roominfo)
		VALUES (@currentid,@currentsortorder,@roominfo)

		SET @currentsortorder = @currentsortorder + 1;
	END
	SET @currentid = @currentid + 1;
END

-- Return info from summary & detail tables
select summ.resdate,summ.location,summ.resinfo,summ.color,
det.roominfo,det.sortorder 
from @detailreservations det
inner join @summaryreservations summ on summ.id=det.summaryid
ORDER by resdate,location,sortorder;

END
GO
