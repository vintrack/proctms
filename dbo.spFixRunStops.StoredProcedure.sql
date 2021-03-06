USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spFixRunStops]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spFixRunStops](
	@RunID			int,
	@who            varchar(20) = '',
	@debug			int = 0
	)
AS
BEGIN
	/************************************************************************
	*	spFixRunStops - as of 10/14/2005
	*	
	*	Description
	*	-----------
	*	summarize child legs to runstops, correct existing runstops as necessary
	*	
	*	Change History
	*	--------------
	*	Date       Init's Description
	*	10/12/2005 JEP    Initial version
	*	10/13/2005 JEP    added better output messages
	*	10/14/2005 JEP    if @who param not passed, use driver usercode (join run > driver > user)
	*	                  removed final 3 optional params from spUpdateRunStop call
	*	                  @NullPickupDate and NullDropoffDate now use zeros for time value (was 23:59.59.999)
	*	11/04/2005 JEP    added Error_Encountered2 and Error_Encountered3 to close cursors
	*	
	************************************************************************/	

	SET nocount on

	DECLARE @LegSummary TABLE
		  (runid  	    int,
		   stopNum      int,
		   locID  	    int,
		   stopDate     datetime,
		   numOrig      int,
		   numDest      int,
		   numLoaded    int,
		   numUnloaded  int,
		   stopType     varchar(20)
		   )
	DECLARE
		--run record fields
		@DriverID            int,
		@UserCode            varchar(20),
		@RunStartDate        datetime,
		@StartedEmptyFromID  int,
		@StartedLoadedFromID int,
		@UnitsOnTruck        int,
		@MaxUnitsOnTruck     int,
		@TotalStops          int,
		@SEFRunStopsID  	 int, -- started empty from record RunStopsID
		--leg summary fields
		@lsStopNum      int,
		@lsLocID  	    int,
		@lsStopDate     datetime,
		@lsSortDate     datetime,
		@lsNumLoaded    int,
		@lsNumUnloaded  int,
		@lsNumOrig      int,
		@lsNumDest      int,
		@lsStopType     varchar(20),
		@lsSefInd       int,
		-- runstop fields
		@RunStopsID  	int,
		@RunStopNumber  int,
		@rsLocID  	    int,
		@rsStopDate     datetime,
		@rsNumLoaded    int,
		@rsNumUnloaded  int,
		@rsStopType     varchar(20),
		@rsSefInd       int,
		@NumReloads     int,
		--process vars
		@NullPickupDate datetime,
		@NullDropoffDate datetime,
		@FirstStopDate datetime,
		@LastStopNum		int,
		@NewLocID		int,
		@NumOnTruck     int,
		@MaxOnTruck     int,
		@RSFixCount     int,
		@RSUpdateCount  int,
		@RSInsertCount  int,
		@RSDeleteCount  int,
		@RSNotDeletedCount  int,
		@RunUpdateNeeded   int,
		@UpdateNeeded   int,
		@InsertNeeded   int,
		@DeleteNeeded   int,
		@FixNeeded      int,
		@RSUpdateString varchar(5000),
		--standard vars
		@ReturnCode		int,
		@ReturnMessage	varchar(50),
		@ErrorID		int,
		@Msg			varchar(50),
		@Count			int

	SET @NullPickupDate = '2048-12-31 00:00:00.000'
	SET @NullDropoffDate = '2049-12-31 00:00:00.000'
	SET @FirstStopDate = @NullPickupDate
	SET @NumOnTruck = 0
	SET @MaxOnTruck = 0
	SET @LastStopNum = 1
	
	SET @RunUpdateNeeded = 0
	SET @RSFixCount = 0
	SET @RSUpdateCount = 0
	SET @RSInsertCount = 0
	SET @RSDeleteCount = 0
	SET @RSNotDeletedCount = 0
	
	SET @Count = 0
	SET @ErrorID = 0
	SET @ReturnMessage = '(RunID=' + convert(varchar,@RunID) + ') '
	
	BEGIN TRAN
	
	-- get the run record, error if not found
	SELECT @Count = count(*)
	FROM Run
	WHERE RunID = @RunID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Run Record'
		GOTO Error_Encountered
	END
	IF @Count = 0
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Msg = 'Error: Run Record Not Found'
		GOTO Error_Encountered
	END
	IF @Count > 1
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Msg = 'Error: Multiple Run Records Found'
		GOTO Error_Encountered
	END
	
	SELECT 
		@DriverID = r.DriverID,
		@UserCode = u.UserCode,
		@RunStartDate = r.RunStartDate,
		@StartedEmptyFromID = r.StartedEmptyFromID,
		@StartedLoadedFromID = r.StartedLoadedFromID,
		@UnitsOnTruck = r.UnitsOnTruck,
		@MaxUnitsOnTruck = r.MaxUnitsOnTruck,
		@TotalStops = r.TotalStops
	FROM Run  r join driver d on d.driverid=r.driverid join users u on u.userid = d.userid
	WHERE RunID = @RunID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Run Record Details'
		GOTO Error_Encountered
	END
	
	IF ((@who = '') or (@who is null))
		set @who = @UserCode
	
	-- summarize legs to runstops
	DECLARE LegSummaryCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT 
			locID,
			min(evtDate) stopDate, -- min(sortDate) sortDate,
			sum(orig) numOrig, 
			sum(dest) numDest, 
			sum(loaded) numLoaded, 
			sum(unloaded) numUnloaded, 
			stopType = (case
				when sum(orig)>0 and sum(dest)>0 then 'Pickup & Dropoff'
				when sum(orig)>0 and sum(dest)=0 then 'Pickup'
				when sum(orig)=0 and sum(dest)>0 then 'Dropoff'
				else 'StartEmptyPoint' end)
		FROM (
			select PickupLocationID as locID, 1 as orig, 0 as dest, 
				loaded=(case when pickupdate is null then 0 else 1 end), 0 as unloaded, 
				isnull(PickupDate,@NullPickupDate) as evtDate
			  from Legs
			  where runID = @runID
			UNION ALL
			select DropoffLocationID as locID, 0 as orig, 1 as dest, 
				0 as loaded, unloaded=(case when DropoffDate is null then 0 else 1 end), 
				isnull(DropoffDate,@NullDropoffDate) as evtDate
			  from Legs
			  where runID = @runID
		) as detail
		GROUP BY detail.locID
		ORDER BY min(evtDate), sum(orig) desc, sum(dest) desc
	OPEN LegSummaryCursor
	FETCH LegSummaryCursor INTO @lsLocID, @lsStopDate, @lsNumOrig, @lsNumDest, @lsNumLoaded, @lsNumUnloaded, @lsStopType -- @lsSortDate, 
	
	WHILE @@FETCH_STATUS = 0
	BEGIN -- add results to @LegSummary table with stop number set to row number...
		set @LastStopNum = @LastStopNum + 1
		
		SET @NumOnTruck = @NumOnTruck + @lsNumLoaded - @lsNumUnloaded
		
		if (@NumOnTruck > @MaxOnTruck)
			SET @MaxOnTruck = @NumOnTruck
		
		if (@lsStopDate < @FirstStopDate)
			SET @FirstStopDate = @lsStopDate
		
		if @lsStopDate = @NullPickupDate
			set @lsStopDate = null
		if @lsStopDate = @NullDropoffDate
			set @lsStopDate = null
		
		insert into @LegSummary values(@RunID, @LastStopNum, @lsLocID, @lsStopDate, @lsNumOrig, @lsNumDest, @lsNumLoaded, @lsNumUnloaded, @lsStopType)
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered inserting @LegSummary Record'
			GOTO Error_Encountered2
		END
		
		FETCH LegSummaryCursor INTO @lsLocID, @lsStopDate, @lsNumOrig, @lsNumDest, @lsNumLoaded, @lsNumUnloaded, @lsStopType -- @lsSortDate, 
	END
	
	-- compare Run details to calculated values: 
	set @RSUpdateString = 'RunID ' + convert(varchar,@RunID)
	
	if ( (@RunStartDate <> @FirstStopDate)
		or (@TotalStops <> @LastStopNum)
		or (@UnitsOnTruck <> @NumOnTruck)
		or (@MaxUnitsOnTruck <> @MaxOnTruck) )
	begin -- update run record
		SET @RunUpdateNeeded = 1
		set @RSUpdateString = @RSUpdateString + ' updated'
		if @debug = 0
		begin
			UPDATE Run
			SET RunStartDate = @FirstStopDate,
				TotalStops = @LastStopNum,
				UnitsOnTruck = @NumOnTruck,
				MaxUnitsOnTruck = @MaxOnTruck,
				UpdatedDate = CURRENT_TIMESTAMP,
				UpdatedBy = @who
			WHERE RunID = @RunID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the Run Record'
				GOTO Error_Encountered2
			END
		end
	end

	if @debug = 1
	begin
		set @RSUpdateString = @RSUpdateString + 
			': NumStops: ' + convert(varchar,@LastStopNum) + 
			'; NumOnTruck=' + convert(varchar,@NumOnTruck) + 
			'; MaxOnTruck=' + convert(varchar,@MaxOnTruck)
		print @RSUpdateString
	end
	
	insert into @LegSummary values(@RunID, 1, @StartedEmptyFromID, @FirstStopDate, 0, 0, 0, 0, 'StartEmptyPoint')
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered setting up the StartEmptyPoint @LegSummary Record'
		GOTO Error_Encountered2
	END
		
	
	-- now join LegSummary to Runstops by common locationID
	DECLARE RunStopsCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT 
			R.driverid, 
			stopLocations.locID, --locID, either from leg summary or from runstop record, or both
			--leg summary fields
			isnull(LS.stopNum,0), 
			isnull(LS.locID,0), 
			LS.stopDate, 
			isnull(LS.numLoaded,0), 
			isnull(LS.numUnloaded,0),
			isnull(LS.stopType,''),
			lsSefInd = (Case when (LS.stopType = 'StartEmptyPoint') and (LS.stopNum = 1) then 1 else 0 end),
			--existing runstop record fields
			isnull(RS.RunStopsID,0),
			isnull(RS.RunStopNumber,0),
			isnull(RS.LocationID,0),
			RS.StopDate,
			isnull(RS.UnitsLoaded,0),
			isnull(RS.UnitsUnloaded,0),
			isnull(RS.StopType,''),
			rsSefInd = (Case when (RS.StopType = 'StartEmptyPoint') and (RS.RunStopNumber = 1) then 1 else 0 end),
			isnull(RS.NumberOfReloads,0) 
		FROM Run R
		JOIN (select runID, locID, sefInd from (
					select runID, locID, sefInd = (Case when (stopType='StartEmptyPoint') and (stopNum=1) then 1 else 0 end)
					from @LegSummary --where runID = @runID
					UNION ALL
					select runID, LocationID as locID, sefInd = (Case when (StopType='StartEmptyPoint') and (RunStopNumber=1) then 1 else 0 end)
					from RunStops 
					where runID = @runID --and not ((StopType = 'StartEmptyPoint') and (RunStopNumber = 1))
				) temp group by runid, locID, sefInd
			) stopLocations on stopLocations.runID = r.runID
		LEFT JOIN RunStops RS ON RS.runID = R.runID and RS.LocationID = stopLocations.locID 
			and stopLocations.sefInd = (Case when (RS.StopType = 'StartEmptyPoint') and (RS.RunStopNumber = 1) then 1 else 0 end)
		LEFT JOIN @LegSummary LS ON LS.locID = stopLocations.locID -- LS.runID = R.runID and 
			and stopLocations.sefInd = (Case when (LS.stopType = 'StartEmptyPoint') and (LS.stopNum = 1) then 1 else 0 end)
		WHERE R.RunID = @RunID
		ORDER BY isnull(LS.stopNum,0), stopLocations.locID

	SET @Count = 0
	OPEN RunStopsCursor
	FETCH RunStopsCursor INTO @DriverID, @NewLocID,
		@lsStopNum, @lsLocID, @lsStopDate, @lsNumLoaded, @lsNumUnloaded, @lsStopType, @lsSefInd, 
		@RunStopsID, @RunStopNumber, @rsLocID, @rsStopDate, @rsNumLoaded, @rsNumUnloaded, @rsStopType, @rsSefInd, @NumReloads
	
	WHILE @@FETCH_STATUS = 0
	BEGIN -- add results to @LegSummary table with stop number set to row number...
		SET @Count = @Count + 1
		set @RSUpdateString = convert(varchar,@Count) + ': locID=' + convert(varchar,@NewLocID)
		--initialize loop vars
		SET @UpdateNeeded = 0
		SET @InsertNeeded = 0
		SET @DeleteNeeded = 0
		SET @FixNeeded = 0
		
		if (@RunStopsID = 0) and (@lsStopNum > 0) -- need to add runstop record
		  begin
			set @InsertNeeded = 1
			set @RSUpdateString = @RSUpdateString + 
				'; lsStopNum=' + convert(varchar,@lsStopNum) + 
				'; lsNumLoaded=' + convert(varchar,@lsNumLoaded) + 
				'; lsNumUnloaded=' + convert(varchar,@lsNumUnloaded) + 
				'; lsStopType=' + @lsStopType + 
				'; lsStopDate=' + convert(varchar,@lsStopDate,100)
		  end
		else if (@RunStopsID > 0) -- we have an existing runstop record
		  begin
			set @RSUpdateString = @RSUpdateString + '; RunStopsID=' + convert(varchar,@RunStopsID)
			if @lsStopNum = 0 -- we need to delete runstop record (as long as no reloads)
			  begin
			  	if @NumReloads = 0 -- we need to delete runstop record
			  	  begin
					set @DeleteNeeded = 1
					set @RSUpdateString = @RSUpdateString + '; DeleteNeeded=' + convert(varchar,@DeleteNeeded)
			  	  end
			  	else -- no more runstop, but number of reloads !!!
			  	  begin
					set @RSNotDeletedCount = @RSNotDeletedCount + 1
					set @RSUpdateString = @RSUpdateString + '; NOT DELETED: NumReloads=' + convert(varchar,@NumReloads)
			  	  end
			  end
			else -- existing record, not deleting, check other values....
			  begin
				if (@lsStopNum <> @RunStopNumber) -- stop num changed
				  begin
					set @UpdateNeeded = 1
					set @RSUpdateString = @RSUpdateString + 
						'; lsStopNum=' + convert(varchar,@lsStopNum) + 
						'; RunStopNumber=' + convert(varchar,@RunStopNumber) --'; lsLocID=' + convert(varchar,@lsLocID) + 
				  end
				if (@lsNumLoaded <> @rsNumLoaded) 
				  begin
					set @UpdateNeeded = 1
					set @RSUpdateString = @RSUpdateString + 
						'; lsNumLoaded=' + convert(varchar,@lsNumLoaded) + 
						'; rsNumLoaded=' + convert(varchar,@rsNumLoaded)
				  end
				if (@lsNumUnloaded <> @rsNumUnloaded) 
				  begin
					set @UpdateNeeded = 1
					set @RSUpdateString = @RSUpdateString + 
						'; lsNumUnloaded=' + convert(varchar,@lsNumUnloaded) + 
						'; rsNumUnloaded=' + convert(varchar,@rsNumUnloaded)
				  end
				if (@lsStopType <> @rsStopType) 
				  begin
					set @UpdateNeeded = 1
					set @RSUpdateString = @RSUpdateString + 
						'; lsStopType=' + @lsStopType + 
						'; rsStopType=' + @rsStopType
				  end
				if (@lsStopDate <> @rsStopDate) 
				  begin
					set @UpdateNeeded = 1
					set @RSUpdateString = @RSUpdateString + 
						'; lsStopDate=' + convert(varchar,@lsStopDate,100) + 
						'; rsStopDate=' + convert(varchar,@rsStopDate,100)
				  end
			  end
		  end
		
		if (@InsertNeeded + @DeleteNeeded + @UpdateNeeded) > 0
		  begin
			set @FixNeeded = 1
			set @RSFixCount = @RSFixCount + 1
		  end
		else
			set @RSUpdateString = @RSUpdateString + ' No Fix Needed.'
		
		if @InsertNeeded = 1
			set @RSInsertCount = @RSInsertCount + 1
		else if @DeleteNeeded = 1
			set @RSDeleteCount = @RSDeleteCount + 1
		else if @UpdateNeeded = 1
			set @RSUpdateCount = @RSUpdateCount + 1
			
		if @debug = 1
			print @RSUpdateString
		
		if (@debug = 0) and (@FixNeeded = 1)
		  begin
			exec spUpdateRunStop 
				@DriverID, -- DriverID-int, 
				@RunID, -- RunID-int, 
				@NewLocID, -- LocationID-int, 
				@lsStopType, -- StopType-varchar-20,
				@lsNumLoaded, -- NumberLoaded-int, 
				@lsNumUnloaded, -- NumberUnloaded-int, 
				@NumReloads, -- NumberOfReloads-int, 
				@lsStopDate, -- StopDate-datetime,
				@lsStopNum, -- RunStopNumber-int, 
				@who, -- WhoCreated-varchar-20, 
				@RunStopsID, -- RunStopsID-int=0, 
				@DeleteNeeded -- , -- DeleteNeeded-int=0,
				--@NumOnTruck, -- UnitsOnTruck-int, 
				--@MaxOnTruck, -- MaxUnitsOnTruck-int, 
				--@LastStopNum -- TotalStops-int
		  end
		
		FETCH RunStopsCursor INTO @DriverID, @NewLocID ,
			@lsStopNum, @lsLocID, @lsStopDate, @lsNumLoaded, @lsNumUnloaded, @lsStopType, @lsSefInd, 
			@RunStopsID, @RunStopNumber, @rsLocID, @rsStopDate, @rsNumLoaded, @rsNumUnloaded, @rsStopType, @rsSefInd, @NumReloads
	END

	Error_Encountered3:
	CLOSE RunStopsCursor
	DEALLOCATE RunStopsCursor

	Error_Encountered2:
	CLOSE LegSummaryCursor
	DEALLOCATE LegSummaryCursor

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		SET @ReturnCode = 0
		SET @ReturnMessage =  @ReturnMessage + ' finished successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		SET @ReturnCode = @ErrorID
		SET @ReturnMessage =  @ReturnMessage + ' Error: ' + @Msg
		GOTO Do_Return
	END

	Do_Return:
	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM', @RunID as 'RunID', @RunUpdateNeeded as 'RunUpdtInd', @RSFixCount as 'FixCnt', @RSUpdateCount as 'UpdateCnt', @RSInsertCount as 'InsertCnt', @RSDeleteCount as 'DeleteCnt', @RSNotDeletedCount as 'NotDeletedCnt'

	RETURN @ReturnCode
END

GO
