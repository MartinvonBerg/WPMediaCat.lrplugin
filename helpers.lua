----- Debug -----------
--local Require = require "Require".path ("../debuggingtoolkit.lrdevplugin").reload ()
--local Debug = require "Debug".init ()
--require "strict.lua"

local LrDate = import( 'LrDate' )

------------ helper functions --------------------------------------------
function SplitFilename(strFilename)
	-- Returns the baseFilename, and Extension as 2 values
	return string.match(strFilename, "(.-)%.(%a+)")
end

function replhyphen(filen)
	-- replhyphen '-' with underscore '_' in string
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

---------------------- shorted if expressions ----------------------------------------------------------
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

function csvwrite(path, data, sep)
	-- write csv-file data to path with given seperator sep
	  sep = sep or ';'
	  local file = assert(io.open(path, "w"))
	  for i=1,#data do
		  local j = 1
		  for key,coll in pairs(data[i]) do
			  if j>1 then file:write(sep) end
			  if type(coll) == 'table' then
				coll = tostring(coll[1])
			  end
			  file:write(coll)
			  j = j +1
		  end
		  file:write('\n')
	  end
	  file:close()
  end

function getfile(path, sep)
	-- get filename of Path (the value after the last '/')
	local n
	path, n = path:gsub('\\','/')
	sep = sep or '/'
	path = path:reverse()
	local index = 0

	for i = 1, path:len() do
	local letter = path:sub(i,i ) 
		if (letter == sep) then
			--print (index)
			index = i
			--print (index)
			break
		end
	end
	path = path:sub(1,index-1)
	path = path:reverse()
	--outputToLog(path)
	return path
end

function strsplit(string, sSeparator, nMax, bRegexp)
	-- split string by given seperator
    if sSeparator == '' then
        sSeparator = ','
    end

    if nMax and nMax < 1 then
        nMax = nil
    end

    local aRecord = {}

    if string:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1

        local nField, nStart = 1, 1
        local nFirst,nLast = string:find(sSeparator, nStart, bPlain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = string:sub(nStart, nFirst-1)
            nField = nField+1
            nStart = nLast+1
            nFirst,nLast = string:find(sSeparator, nStart, bPlain)
            nMax = nMax-1
        end
        aRecord[nField] = string:sub(nStart)
    end

    return aRecord
end

---------------------------------------------------------------------
function sqlread(path, sep, tonum, null)
	-- read sqlite3.exe result to table, result stored in *.txt, seperated by '|'
    tonum = tonum or true
    sep = sep or ','
    null = null or ''
    local csvFile = {}
    local fields = {}
    local file = assert(io.open(path, "r"))
    for line in file:lines() do
        fields = strsplit(line, sep)
        if tonum then -- convert numeric fields to numbers
            for i=1,#fields do
                local field = fields[i]
                if field == '' then
                    field = null
                end
                fields[i] = tonumber(field) or field
            end
        end
        table.insert(csvFile, fields)
    end
    file:close()
    return csvFile
end

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
-- source: https://stackoverflow.com/questions/34618946/lua-base64-encode
-- encoding
function encb64(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
function decb64(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
    end))
end