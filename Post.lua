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
	Log('Debug: ' .. tostring(logDebug))
	--LrMobdebug.on()
	local ReturnTable = {} 
	--local hash = 'Basic ' .. publishSettings.hash 
	publishSettings.hash = ''
	local uid = publishSettings.loginName
	local pwd = publishSettings.loginPassword
    local hash = 'Basic ' .. encb64(uid .. ':' .. pwd)   
	local httphead = {
      {field='Authorization', value=hash},
      }
  
	local url = publishSettings.siteURL .. "/wp-json/wp/v2/"
	Log('url: ' .. url)  -- Debugging
	Log('hash-value: ' .. hash) -- Debugging

	local result, headers = LrHttp.get( url ) -- GET-Anfrage ohne Auth

	if headers.status == 200 then
		ReturnTable['warning'] = 'REST-API (GET) of site can be reached without PWD! Check OAuth!'
	elseif headers.status == 401 then
       	result = JSON:decode(result)
    	local str = 'GET-Req w/o Auth blocked. Authorization required. ' .. result.message
		ReturnTable['error'] = str
	else
		ReturnTable['error'] = 'Cannot Reach Site. Unknown Error'
		Log('Site not reached: ' .. headers.status)
	end
	
	if headers.status == 200 or headers.status == 401 then
		publishSettings.urlreadable = true

		local result, headers = LrHttp.post( url, '', httphead )
    
		if headers.status == 500 then
			ReturnTable['error'] = 'Login failed! Check Username and Password.'
		elseif headers.status == 404 then
			ReturnTable['success'] = 'Sucess. Login-OK! with hash-Method:    ' .. hash
			publishSettings.hash = encb64(uid .. ':' .. pwd)
			result = JSON:decode(result)  -- Debugging
			Log(result)  -- Debugging
		else
      		ReturnTable['error'] = 'Site reachable, but unknown error.'
    	end
	end
  
  return ReturnTable, nil
 end