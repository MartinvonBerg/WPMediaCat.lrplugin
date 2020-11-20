--[[
CheckLogin function Check Login given in PublishSettings
and save to PublishSettings if successful
by Martin von Berg
]]

------------- Debug ----------------------

--local Require = require "Require".path ("../debuggingtoolkit.lrdevplugin").reload ()
--local Debug = require "Debug".init ()
require 'strict.lua'
local inspect = require 'inspect'
local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
LrMobdebug.start()

----------------------------------------

local LrHttp = import( 'LrHttp' )

-- Check Login given in PublishSettings
function CheckLogin( publishSettings ) 

	Log('Debug: ' .. tostring(logDebug))
	LrMobdebug.on()
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
    	local str = 'OK. GET-Req without Auth. blocked. Authorization required. ' -- .. result.message
		ReturnTable['Authentification'] = str
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

		-- Check Install of Plugin for communication via REST-API
		url = publishSettings.siteURL .. "/wp-json/wp/v2/plugins"
		local result, headers = LrHttp.get( url, httphead )
		
		if headers.status == 200 then
			local str = inspect(result) -- JSON-Rückgabe für ein Image in str umwandeln
			local i,j = string.find(result,'wp_wpcat_json_rest') 
			local pluginstatus
			local pluginversion

			if i ~= nil then
				result = JSON:decode(result) 
				for k = 1, #result do
					if result[k]['textdomain'] == "wp_wpcat_json_rest" then
						pluginstatus = result[k]['status']
						pluginversion = result[k]['version']
					end
				end
				if pluginstatus == 'active' then
					ReturnTable['plugin'] = 'OK. Wordpress Plugin installed and active. Version: ' .. tostring(pluginversion)
					publishSettings.wpplugin = true
				else
					ReturnTable['plugin'] = 'OK. Wordpress Plugin installed but not activated! Version: ' .. tostring(pluginversion)
					publishSettings.wpplugin = false
				end
			else
				ReturnTable['plugin'] = 'Plugin not installed. Many functions won\'t work!'
				publishSettings.wpplugin = false
			end
		else
			ReturnTable['plugin'] = 'Unknown Error while searching for Plugin'
			publishSettings.wpplugin = false
		end

	end
  
  return ReturnTable, nil
end