--[[----------------------------------------------------------------------------

Info.lua : Dieses Lua-File wird vom Plug-In zuerst aufgerufen
Summary information for plug-in.
Plugin abgeleitet aus NGGPlus zur Synchronisierung des WP Medienkatalogs mit Lightroom via REST-API
Status: Auslesen des Medienkatalogs via REST-API und finden der Files in der LR sqlite3-Datenbank funktioniert
25.05.2020: Problem: beim ersten veröffentlichen ist die Rendition leer, die Anzahl der Renditions jedoch richtig. Ursache unklar
------------------------------------------------------------------------------]]

return {
	
	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 3.0, -- minimum SDK version required by this plug-in
	LrToolkitIdentifier = 'com.adobe.lightroom.export.wp_mediacat2',
	LrPluginName = LOC "$$$/WP_MediaCat2/PluginName=WP_MediaCat2",
	
	LrExportServiceProvider = { -- Definition des Export-Service-Proiders von LR für dieses Plugin-In im angeg. lua-file
		title = LOC "$$$/WP_MediaCat2/WP_MediaCat2-title=WP_MediaCat2",
		file = 'Main.lua',
	},
	LrMetadataProvider  = 'WPMediaCat2Meta.lua', -- Service zur Definition der Metadaten für dieses Plugin-In im angeg. lua-file
	
	VERSION = { major=1, minor=4, revision=0, build=1, },
}


	
