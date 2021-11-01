--[[----------------------------------------------------------------------------
Info.lua : Dieses Lua-File wird vom Plug-In zuerst aufgerufen
Summary information and definition of script-files for plug-in.
------------------------------------------------------------------------------]]

return {
	
	LrSdkVersion = 6.0,
	LrSdkMinimumVersion = 6.0, -- minimum SDK version required by this plug-in
	--changing the LrToolkitIdentifier will reset all Data for the plugin! All Data will be lost!
	LrToolkitIdentifier = 'com.mvbplugins.lightroom.export.wp_mediacat2',
	LrPluginName = LOC "$$$/WP_MediaCat2/PluginName=WP_MediaCat2",
	LrAlsoUseBuiltInTranslations = true, --

	LrInitPlugin = 'PluginInit.lua', --

	LrMetadataProvider  = 'WPMediaCat2Meta.lua', -- Service zur Definition der Metadaten für dieses Plugin-In im angeg. lua-file
	
	LrExportServiceProvider = { -- Definition des Export-Service-Proiders von LR für dieses Plugin-In im angeg. lua-file
		title = LOC "$$$/WP_MediaCat2/WP_MediaCat2-title=WP_MediaCat2",
		file = 'Main-Copy1.lua',
	},

	-- this script is executed at shutdown of lightroom: use it correctly otherwise it will hang. See SDK manual
	-- LrShutdownApp = 'shutdown.lua',
		
	VERSION = { major=1, minor=4, revision=0, build=1, },
}


	
