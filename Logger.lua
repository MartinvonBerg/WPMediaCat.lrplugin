----- Debug -----------
--local Require = require "Require".path ("../debuggingtoolkit.lrdevplugin").reload ()
--local Debug = require "Debug".init ()
--require "strict.lua"

local LrLogger = import "LrLogger"

local Logger = LrLogger( "WP_MediaCat2" ) 

-- log to logfile in ~/Documents/My Documents. Change this to 'print' to log to console
Logger:enable( "logfile" )

function Log( ... )

	Logger:debug("Log: " .. ArgsToString( {...} ))

end

-- being real cheeky and using JSON to convert text to tables
function ArgsToString( argList )

	local s = ""
	for i,v in pairs( argList ) do
		s = s .. " " .. JSON:encode( v )
    end
    return s

end