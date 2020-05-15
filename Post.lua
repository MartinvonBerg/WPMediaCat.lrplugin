--[[

post to nggRest.
rest call returns data in result['data'] on success
rest call returns error message in result['error'] on error. Nothing else will be in the return array
rest call may also return  a debugging result['message'] in addtion to data
rest call may also return a warning message in reslut['warning'] in addition to data & message

Post() returns result['data'] if no 'error' field else nil

]]
local Require = require "Require".path ("../debuggingtoolkit.lrdevplugin").reload ()
local Debug = require "Debug".init ()
require 'strict'

local LrHttp = import( 'LrHttp' )
local LrErrors = import( 'LrErrors' )
local LrDialogs = import( 'LrDialogs' )
local inspect = require 'inspect'

local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
LrMobdebug.start()

function Post( endpoint, dataToSend, publishSettings ) 
	--Debug.pauseIfAsked()
	LrMobdebug.on()
	local ReturnTable = {} 
	local head = {
      {field='Authorization', value=publishSettings.hash},
      }
  
	local url = publishSettings.siteURL .. "/wp-json/wp/v2/"
  
	local result, headers = LrHttp.get( url )

	if headers.status == 200 then
		ReturnTable['warning'] = 'REST-API (GET) of site can be reached without PWD! Check OAuth!'
    
		local result, headers = LrHttp.post( url, '', head )
    
		if headers.status == 500 then
			ReturnTable['error'] = 'Login failed! Check Password / hash-value'
		elseif headers.status == 404 then
			ReturnTable['success'] = 'Sucess. Login-OK!'
		else
      ReturnTable['error'] = 'Site reachable, but unknown error'
    end
		--return ReturnTable, nil
    
	elseif headers.status == 401 then
    --ReturnTable['warning'] = 'REST-API blocked. Authorization required'
    result = JSON:decode(result)
    local str = 'REST-API blocked. Authorization required. ' .. result.message
    ReturnTable['warning'] = str
  else
    ReturnTable['error'] = 'Unknown Error'
  end
  
  return ReturnTable, nil
  
	--[[		
	-- returns result as JSON
	local result, headers = LrHttp.post( url, '', head )
 
	-- Connection fail.
	-- This happens very occasionally when uploading, particularly with large numbers of large images. 
	--			No idea why. Ignore it for now & let the user re-upload. Maybe the server just doesn't
	--			like too many concurrent connections?
	--			Or might be an incorrect URL
	if headers.status == nil then
		PostError( "Could not connect to " .. publishSettings.siteURL .. " ?", endpoint, headers )
		return nil
	end
	--Log( string.format( "Status Code: %s %s", tostring( headers.status ), tostring( headers.statusDesc ) ) )

	-- status = 200 with nil in the statusDesc means success
	if headers.status ~= 200 then
		PostError( "Unknown status returned", endpoint, headers )
		return nil
	end

	-- Result from post() is sometimes nil. 
	if result == nil then
		PostError( "Post returned nil, somthing went wrong", endpoint, headers )
		return nil
	end
	-- ToDo: trap errors in decode more betterer.
	ReturnTable = JSON:decode( result )

	if ReturnTable == nil then
		PostError( "JSON decode returned nil. Something has gone wrong", endpoint, headers )
		return nil
	end

	-- warning message but continue
	if ReturnTable['warning'] ~= nil then 
		LrDialogs.message( "Warning from nggRest:" .. ReturnTable['warning'] )
	end
	-- data exists, return result as table
	if ReturnTable ~= nil then
		return ReturnTable, nil
	end
	
	-- Fatal error. dialog, error, die
	if ReturnTable['error'] ~= nil then
		PostError( "Fatal Error from nggRest. message returned is: " .. ReturnTable['error'], endpoint, headers )
		return nil
	end

	-- something odd came back.
	PostError("Invalid return from nggRest. Return value = " .. ReturnTable, endpoint, headers );
	return nil
    ]]
end

function PostError ( str, endpoint, headers )

	LrDialogs.showError ( string.format( "Error from Post( %s ): %s :\nStatus msg = %s\nStatus code = %s", endpoint, str, tostring( headers.statusDesc ), tostring( headers.status ) ) )

end