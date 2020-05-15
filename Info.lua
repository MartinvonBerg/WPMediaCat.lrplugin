--[[----------------------------------------------------------------------------

Info.lua
Summary information for plug-in.
------------------------------------------------------------------------------]]

-- plugin naming legacy screw up. identifier stuck as Lr2NggPublisher
-- plugin name, though, is NggPlusPluss
local sPluginName2 = 'NggPlusplus++'		-- can change this
local sPluginName = 'Lr2NggPublisher'		-- cannot change this without unpleasant consequences

return {
	
	LrSdkVersion = 6.0,
	LrSdkMinimumVersion = 6.0, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'com.kim-aldis.NggPlusplus.' .. sPluginName,
	LrPluginName =  sPluginName2 .. "/PluginName=" .. sPluginName2 .. " by Kim Aldis",
	
	LrExportServiceProvider = {
		title = "Ngg++ by Kim Aldis",
		file = 'Main.lua',
	},
}


	
