--[[
CheckLogin function Check Login given in PublishSettings
and save to PublishSettings if successful
by Martin von Berg
]]

------------- Debug ----------------------
--[[
local Require = require "Require".path ("../debuggingtoolkit.lrdevplugin").reload ()
local Debug = require "Debug".init ()
require 'strict'
local inspect = require 'inspect'
local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
LrMobdebug.start()
]]
----------------------------------------

local LrHttp = import( 'LrHttp' )

-- Check Login given in PublishSettings
function CheckLogin( publishSettings ) 
	
	--LrMobdebug.on()
	local ReturnTable = {} 
	local hash = 'Basic ' .. publishSettings.hash 
	local httphead = {
      {field='Authorization', value=hash},
      }
  
	local url = publishSettings.siteURL .. "/wp-json/wp/v2/"
  
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