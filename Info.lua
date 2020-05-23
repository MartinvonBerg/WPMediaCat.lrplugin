--[[----------------------------------------------------------------------------

Info.lua
Summary information for plug-in.
------------------------------------------------------------------------------]]

return {
	
	LrSdkVersion = 6.0,
	LrSdkMinimumVersion = 6.0, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'com.adobe.lightroom.export.wp_mediacat2',
	LrPluginName = LOC "$$$/Wordpress/PluginName=WP_MediaCat2",
	
	LrExportServiceProvider = {
		title = LOC "$$$/Wordpress/Wordpress-title=WP_MediaCat2",
		file = 'Main.lua',
	},
	LrMetadataProvider  = 'WPMediaCat2Meta.lua',
	
	VERSION = { major=2, minor=0, revision=0, build=1, },
}


	
