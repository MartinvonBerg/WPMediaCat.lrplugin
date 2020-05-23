local LrDate = import( 'LrDate' )
------------ helper functions --------------------------------------------
function SplitFilename(strFilename)
	-- Returns the baseFilename, and Extension as 2 values
	return string.match(strFilename, "(.-)%.(%a+)")
end

function replhyphen(filen)
	filen = filen:reverse()
	local nfound = 0
	local newstring = filen

	for i = 1, filen:len() do
	local letter = filen:sub(i,i ) 
		if (letter == '-')  then
			if (nfound > 0) then
				newstring = newstring:sub(1,i-1) .. '_' .. newstring:sub(i+1,newstring:len())
			end
			nfound = nfound + 1
		end
	end

	filen = newstring:reverse()
	return filen
end

---------------------- iso8601ToTime(timeISO8601) ----------------------------------------------------------
function ifnil(str, subst)
	return ((str == nil) and subst) or str
end 

function iif(condition, thenExpr, elseExpr)
	if condition then
		return thenExpr
	else
		return elseExpr
	end
end 

-- iso8601ToTime(dateTimeISO8601) : returns Cocoa timestamp as used all through out Lr  
function iso8601ToTime(dateTimeISO8601)
	-- ISO8601: YYYY-MM-DD{THH:mm:{ss{Zssss}}
	-- date is mandatory, time as whole, seconds and timezone may or may not be present, e.g.:
        --	srcDateTimeISO8601 = '2016-07-06T17:16:15Z-3600'
        --	srcDateTimeISO8601 = '2016-07-06T17:16:15Z'
        --	srcDateTimeISO8601 = '2016-07-06T17:16:15'
        --	srcDateTimeISO8601 = '2016-07-06T17:16'
        --	srcDateTimeISO8601 = '2016-07-06'

	local year, month, day, hour, minute, second, tzone = string.match(dateTimeISO8601, '(%d%d%d%d)%-(%d%d)%-(%d%d)T*(%d*):*(%d*):*(%d*)Z*([%-%+]*%d*)')
	return LrDate.timeFromComponents(tonumber(ifnil(year, "2001")), tonumber(ifnil(month,"1")), tonumber(ifnil(day, "1")), 
									 tonumber(ifnil(hour, "0")), tonumber(ifnil(minute, "0")), tonumber(ifnil(second, "0")),
									 iif(ifnil(tzone, '') == '', "local", tzone))
end