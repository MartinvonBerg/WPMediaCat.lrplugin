-- helpers.lua

local LrDate = import( 'LrDate' )
local LrTasks = import( 'LrTasks' )
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'


------------ helper functions for LR to WP Plugin --------------------------------------------

--- Returns the baseFilename, and Extension as 2 values
--- @param strFilename string with filename and extension, e.g. 'myphoto.jpg'
--- @return string baseFilename, string extension
function SplitFilename(strFilename)
    if strFilename ~= nil then
        return string.match(strFilename, "(.-)%.(%a+)")
    else
        return '',''
    end
end

---------------------- local shorted if expressions ----------------------------------------------------------
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

--- iso8601ToTime(dateTimeISO8601) : returns Cocoa timestamp as used all through out Lr
---@param dateTimeISO8601 string
---@return unknown
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

--- write csv-file data to path with given seperator sep
---@param path string
---@param data table of tables, e.g. {{field1=value1, field2=value2}, {field1=value3, field2=value4}}
---@param sep string
function csvwrite(path, data, sep)
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

--- get filename of Path (the value after the last '/')
---@param path string 
---@param sep string|nil optional seperator, default is '/'
---@return string
function getfile(path, sep)
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

--- get the mime_type of a file
--- assuming only jpg or png files used for export and the real mime-type and file-extension match
---  @param file string : the complete path or filename with extension
---  @return string mime-type string of the file 'mime/jpeg' or 'mime/png'
function getMime(file)
    local mime = 'image/jpeg'
    local base = getfile(file)
    local _, ext = SplitFilename(base)
    ext = string.lower( ext )

    if ext == 'png' then
        mime = 'image/png'
    elseif ext == 'webp'  then
        mime = 'image/webp'
    end

    return mime
end

--- split string by given seperator
--- @param inString string to split
--- @param sSeparator string separator, default is ','
--- @param nMax nil|number maximum number of splits, default is nil (no limit)
--- @param bRegexp nil|boolean whether sSeparator is a regular expression, default is false (plain)
--- @return table array of split values
function strsplit(inString, sSeparator, nMax, bRegexp)
	
    if inString == nil or inString == 'nil' then
        return {}
    end

    sSeparator = sSeparator or ','

    if nMax and nMax < 1 then
        nMax = nil
    end

    local aRecord = {}

    if inString:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1

        local nField, nStart = 1, 1
        local nFirst,nLast = inString:find(sSeparator, nStart, bPlain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = inString:sub(nStart, nFirst-1)
            nField = nField+1
            nStart = nLast+1
            nFirst,nLast = inString:find(sSeparator, nStart, bPlain)
            nMax = nMax-1
        end
        aRecord[nField] = inString:sub(nStart)
    end

    return aRecord
end

--- encode data to base64 string
--- @source https://stackoverflow.com/questions/34618946/lua-base64-encode
--- @param data string to encode
--- @return string base64 encoded string
function encb64(data)
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
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

--- decode base64 string
--- @param data string to decode
--- @return string decoded string
function decb64(data)
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
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

--- convert value to number if it is a number, otherwise return 'nil' as string
--- @param value any value to convert to number
--- @return number|string|nil
function mytonumber( value )
    if type(value) == 'number' then
        return tonumber( value )
    else
        return 'nil'
    end
end

--- check wether new Collection name is OK and fullfills the requirements (naming conventions)
--- Do not allow WP standard folder names, no leading or trailing slashes, only a-zA-Z0-9-_/
--- is called in in main.lua after the user has entered a name for the new collection, before creating the collection
--- @param proposedName string name of the new collection to check
--- @return boolean, string|nil returns true if name is ok, otherwise false and error message
function checkfolder( proposedName )
    -- WP-StandardFolder nicht erlauben 
    -- WP erlaubt das: [a-zA-Z0-9\\/\\-_]*
    local first = string.sub(proposedName,1,1)
    local last = string.sub(proposedName, #proposedName, #proposedName)
    local wpcatsub = string.match(proposedName, '%d%d%d%d/%d%d')
    if wpcatsub ~= nil then
        proposedName = string.gsub(proposedName,wpcatsub,'')
    end

    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_/'
    
    local count = 0
    for i=1, #proposedName do
        local letter = string.sub(proposedName,i,i)
        local k,l = string.find(b,letter)
        if k == l and mytonumber(k) ~= 'nil' then 
            count = count + 1 
        end
    end

    if count ~= #proposedName then
        return false, 'Dont use other characters than a-z, A-Z, 0-9, / - _'
    elseif first == '/' or first == '\\' or last == '/' or last == '\\'  then
      return false, 'No limiting slashes allowed'
    elseif proposedName == '' or wpcatsub ~=nil then
      return false, 'Dont use WP Standard-Folder-Name'
    else 
      return true
    end
  
  end

--- array ist einfache Tabelle als liste mit Stringwerten, wie von strsplit gelifert
--- Annahme, dass der Wert nur einmal vorhanden ist
---@param array table simple Table as List of String values as returned by strsplit
---@param key string value to find in array
---@param depth string|integer optional depth to search in array, default is '' (search whole array), if 1 is given, only search for first value in array
---@return integer index of key in array, or 0 if not found
function findValueInArray (array, key, depth)
    local result = 0
    
    if depth == '' or depth == nil then
        for i=1, #array do
            if array[i] == key then
                result = i
                break
            end
        end
    end

    if depth ==1 then
        for i=1, #array do
            if array[i] == key then
                result = i
                break
            end
        end
    end

    return result
end

---set suffix for url depending on number of metadata
---@param n number
---@return string '?' oder '&'
function pre(n)
    
    local str = ''
    if n == 0 then
        str = '?'
    else
        str = '&'
    end
    return str
end

--- url encode bzw. sanitize für korrekten code im http-request
--- @param url string to encode
--- @return nil|string url encoded string
function urlencode(url)
    
    local char_to_hex = function(c)
        return string.format("%%%02X", string.byte(c))
    end

    if url == nil then
        return
    end

    url = url:gsub("\n", "\r\n")
    url = url:gsub("([^%w ])", char_to_hex)
    url = url:gsub(" ", "+")

    return url

end

---check whether key is defined in table
---@param table table
---@param key string
---@return boolean
function tableHasKey(table,key)
    return table[key] ~= nil
end

---round up number to integer
---@param value number
---@return integer
function round(value)
    if value % 1 < 0.5 then
        return math.floor(value)
    else
        return math.floor(value) + 1
    end
end

---add quotes for WINDOWS or POSIX around a file or path.
---@globals WIN_ENV boolean provided by LR SDK.
---@param s string
---@return string
function quote(s)
    if WIN_ENV then
        return quote_win(s)
    else
        return quote_posix(s)
    end
end

---add quotes for WINDOWS around a file or path.
---@param s string
---@return string
function quote_win(s)
    local result = '"'
    local backslashes = 0

    for i = 1, #s do
        local c = s:sub(i,i)

        if c == '\\' then
            backslashes = backslashes + 1
        elseif c == '"' then
            result = result .. string.rep('\\', backslashes * 2 + 1) .. '"'
            backslashes = 0
        else
            result = result .. string.rep('\\', backslashes) .. c
            backslashes = 0
        end
    end

    -- trailing backslashes vor dem schließenden Quote
    result = result .. string.rep('\\', backslashes * 2)

    result = result .. '"'
    return result
end

---add quotes for POSIX around a file or path.
---@param s string
---@return string
function quote_posix(s)
    return "'" .. string.gsub(s, "'", "'\\''") .. "'"
end

---get the path of an executable by calling 'where' on Windows or 'command -v' on POSIX systems, and return nil if not found.
---@param executable string
---@return nil|string
function getExecutablePath(executable)
    if executable == nil or executable == '' then
        return nil
    end

    local p2 = LrPathUtils.getStandardFilePath( 'documents' ) 
    local tmpfile = p2 .. DIRSEP .. 'exe_check.txt'

    local cmd = WIN_ENV and 'where "' .. executable .. '" > "' .. tmpfile .. '" 2>&1' or 'command -v "' .. executable .. '" > "' .. tmpfile .. '" 2>&1'
    local status = LrTasks.execute(cmd)
    local firstLine = nil

    if status == 0 then
        local contents = LrFileUtils.readFile(tmpfile)
        if contents and contents ~= '' then
            firstLine = string.match(contents, '^%s*([^\r\n]+)')
        end
    end

    if tmpfile and tmpfile ~= '' then
        LrFileUtils.delete( tmpfile )
    end

    if firstLine == nil or firstLine == '' then
        return nil
    end

    if WIN_ENV and string.find(firstLine, 'Could not find files', 1, true) then
        return nil
    end

    return firstLine
end

---execute a OS CLI command and return the exit code and the output as string.
---@param cmd string
---@return number, string
function execWithOutput(cmd)

    -- eindeutige Temp-Datei
    local tmpFile = LrPathUtils.child(
        LrPathUtils.getStandardFilePath('temp'),
        'lr_cmd_output_.txt'
    )

    -- stdout + stderr umleiten
    local fullCmd = cmd .. ' > "' .. tmpFile .. '" 2>&1'

    Log('CMD: ' .. fullCmd)

    -- ausführen
    local result = LrTasks.execute(fullCmd)
    Log('Exit-Code: ' .. tostring(result))

    -- Datei lesen (SDK-konform)
    local content = ''
    if LrFileUtils.exists(tmpFile) then
        content = LrFileUtils.readFile(tmpFile) or ''
    end

    Log('CMD-OUTPUT: ' .. content)

    -- optional: aufräumen
    LrFileUtils.delete(tmpFile)

    return result, content
end

---create a string with the current WordPress Upload Folder for Media like "2026/04"
---@return string
function getWPStandardMediaFolder()
    local now = LrDate.currentTime()
    local dateTable = LrDate.timeToUserFormat(now, "%Y/%m")
    return dateTable
end
