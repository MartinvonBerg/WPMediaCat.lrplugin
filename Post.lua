--[[
CheckLogin function Check Login given in PublishSettings
and save to PublishSettings if successful
by Martin von Berg
]]

------------- Debug ----------------------

--ocal Require = require "Require".path ("../debuggingtoolkit.lrdevplugin").reload ()
--local Debug = require "Debug".init ()
--require 'strict.lua'
local inspect = require 'inspect'
--local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
--LrMobdebug.start()

----------------------------------------

local LrHttp = import( 'LrHttp' )

-- Check Login given in PublishSettings
function CheckLogin( publishSettings ) 
	
	--LrMobdebug.on()
	local ReturnTable = {} 
	local hash = 'Basic ' .. publishSettings.hash 
  --local hash = 'Basic Og=='   -- Debugging
	local httphead = {
      {field='Authorization', value=hash},
      }
  
	local url = publishSettings.siteURL .. "/wp-json/wp/v2/"
	Log(url)  -- Debugging
	Log(hash) -- Debugging
	local result, headers = LrHttp.get( url )

	if headers.status == 200 then
		ReturnTable['warning'] = 'REST-API (GET) of site can be reached without PWD! Check OAuth!'
		publishSettings.urlreadable = true

		local result, headers = LrHttp.post( url, '', httphead )
    
		if headers.status == 500 then
			ReturnTable['error'] = 'Login failed! Check Password / hash-value'
		elseif headers.status == 404 then
			ReturnTable['success'] = 'Sucess. Login-OK!'
			publishSettings.pwdok = 'true'
			result = JSON:decode(result)  -- Debugging
			Log(result)  -- Debugging
		else
      		ReturnTable['error'] = 'Site reachable, but unknown error'
    	end
		return ReturnTable, nil
    
	elseif headers.status == 401 then
       	result = JSON:decode(result)
    	local str = 'REST-API blocked. Authorization required. ' .. result.message
    	ReturnTable['warning'] = str
  	else
    	ReturnTable['error'] = 'Unknown Error'
  	end
  
  return ReturnTable, nil
 end