--[[----------------------------------------------------------------------------
Info.lua : Dieses Lua-File wird vom Plug-In zuerst aufgerufen
Summary information and definition of script-files for plug-in.

Mind this note in the SDK manual:
You can use the Plug-in Manager to add multiple plug-ins with the same identifier 'LrToolkitIdentifier', 
but only one of them can be enabled at time. If you enable one, any other plug-in that shares the same plug-in ID 
is automatically disabled.
This file 'Info.lua' is just allowed to return the table, nothing more, so 'require' is not possible.
------------------------------------------------------------------------------]]

--ATTENTION: changing the LrToolkitIdentifier will reset all Data for the plugin! All Data will be lost!
-- Private Version: The PiName is NOT correct. But I keep for compatibility reasons.
PiName = 'com.adobe.lightroom.export.wp_mediacat2'
-- A correct name would be: PiName = 'com.mvbplugins.lightroom.export.wp_mediacat2'
TagsetName = 'WordPress-Meta'

return {
	LrSdkVersion = 6.0,
	LrSdkMinimumVersion = 6.0, -- minimum SDK version required by this plug-in
	LrToolkitIdentifier = PiName,
	LrPluginName = LOC "$$$/WP_MediaCat2/PluginName=WP_MediaCat2",
	LrAlsoUseBuiltInTranslations = true, 

	LrInitPlugin = 'PluginInit.lua', 

	LrMetadataProvider  = 'WPMediaCat2Meta.lua', -- Service zur Definition der Metadaten für dieses Plugin-In im angeg. lua-file
	LrMetadataTagsetFactory = 'WpCatTagset.lua',
	
	LrExportServiceProvider = { -- Definition des Export-Service-Proiders von LR für dieses Plugin-In im angeg. lua-file
		title = LOC "$$$/WP_MediaCat2/WP_MediaCat2-title=WP_MediaCat2",
		file = 'Main-Copy1.lua',
	},

	-- this script is executed at shutdown of lightroom: use it correctly otherwise it will hang. See SDK manual
	-- LrShutdownApp = 'shutdown.lua',

	LrLibraryMenuItems = {
		{
		  title = LOC "$$$/WP_MediaCat2/resync=Sync with Meta from WP",
		  file = "ReSyncMetaData.lua",
		  enabledWhen = 'photosSelected',
		},
	  }, 
		
	VERSION = { major=1, minor=4, revision=0, build=1, },
}


	
