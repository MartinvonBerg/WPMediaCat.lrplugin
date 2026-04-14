----- Debug -----------
--local Require = require "Require".path ("../debuggingtoolkit.lrdevplugin").reload ()
--local Debug = require "Debug".init ()
--require "strict.lua"

local LrLogger = import "LrLogger"
local Logger = LrLogger( "WP_MediaCat3" ) 
--JSON=require 'JSON'

--logDebug = true
-- log to logfile in ~/Documents/My Documents. Change this to 'print' to log to console
Logger:enable( "logfile" )

function InitLogger( defaultDebug )
	if logDebug == nil then
		logDebug = defaultDebug or false
	end
end

function Log( ... )
	if logDebug then
		Logger:debug("Log: " .. ArgsToString( {...} ))
	end
end

-- being real cheeky and using JSON to convert text to tables
function ArgsToString( argList )

	local s = ""
	local hasJson = JSON ~= nil and JSON.encode ~= nil
	for i,v in pairs( argList ) do
		if hasJson then
			local ok, encoded = pcall(function() return JSON:encode( v ) end)
			if ok then
				s = s .. " " .. encoded
			else
				s = s .. " " .. tostring(v)
			end
		else
			s = s .. " " .. tostring(v)
		end
    end
    return s

end