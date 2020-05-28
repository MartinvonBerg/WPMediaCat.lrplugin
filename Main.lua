----- Debug -------------
--local Require = require "Require".path ("../debuggingtoolkit.lrdevplugin").reload ()
--local Debug = require "Debug".init ()
--require "strict"
--require "strict.lua"
----- Debug ------------

--	Main entry point for plugin.

local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrView = import 'LrView'
local LrHttp = import 'LrHttp'
local LrLogger = import 'LrLogger'
--local LrXml = import 'LrXml'
local LrDate = import 'LrDate'
--local LrErrors = import 'LrErrors'
--local LrFtp = import 'LrFtp'
local LrTasks = import 'LrTasks'
local bind = LrView.bind
local share = LrView.share

JSON=require 'JSON'
require 'Dialogs'
require 'Post'
--require 'Process'
require("helpers")

local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
LrMobdebug.start()
local myLogger = LrLogger( 'WPSynclog' )
myLogger:enable( "logfile" )
local function o2L( message )
	myLogger:trace( message )
end

------------ exportServiceProvider ----------------------------
exportServiceProvider = {}
exportServiceProvider.small_icon = "Small-icon.png"
exportServiceProvider.supportsIncrementalPublish = 'only'							-- only publish. No export facility
exportServiceProvider.allowFileFormats = { 'JPEG' } 								-- TODO: alle Filetypen erlauben. evtl. Plugin von J.Friedl oder Ellis verwenden
exportServiceProvider.hidePrintResolution = true									-- hide print res controls
exportServiceProvider.canExportVideo = false 										-- video is not supported through this plug-in
exportServiceProvider.hideSections = { 'exportLocation', 'exportVideo' }							-- hide export location
--exportServiceProvider.processRenderedPhotos = processRenderedPhotos				-- TODO: see process.lua, integrieren oder umbenennen wie bei ftp-task
exportServiceProvider.startDialog = dialogs.startDialog							-- see dialogs.lua, integrieren oder umbenennen wie bei ftp-task
exportServiceProvider.sectionsForTopOfDialog = dialogs.sectionsForTopOfDialog -- see dialogs.lua, integrieren oder umbenennen wie bei ftp-task
exportServiceProvider.exportPresetFields = {
	{ key = "siteURL", default = "" },
	{ key = "loginName", default = "" },
	{ key = "loginPassword", default = "" },
	{ key = "hash", default = ""},
	{ key = "pwdok", default = "false"},
  { key = "urlreadable", default = false},
  { key = "firstsync", default = false},
}
exportServiceProvider.titleForGoToPublishedCollection = 'Sync with Wordpress'
exportServiceProvider.titleForGoToPublishedPhoto = 'Go to Foto in WP Catalog'
exportServiceProvider.supportsCustomSortOrder = true  -- this must be set for ordering

-- Get all Media Files from WP-Media-Catalog via REST-API
-- TODO : Authorization-Auswahl im Menu mit Vorauswahl im Dropdown, OAuth2-Plugin mit base64 verwenden, hash nach LR kopieren
function GetMedia( publishSettings, perpage, page ) 
	local hash = 'Basic ' .. publishSettings.hash
	local httphead = {
      {field='Authorization', value=hash},
    }
	local url = ''  
	if perpage ~=nil then
		url = publishSettings.siteURL .. "/wp-json/wp/v2/media/?per_page=" .. perpage .. '&page=' .. page
	else
		url = publishSettings.siteURL .. "/wp-json/wp/v2/media/"
	end
   
	local result, headers = LrHttp.get( url, httphead )

	if headers.status == 200 then
    	result = JSON:decode(result)
  	else
    	result = nil
  	end
  
  return result
 end

-- Serch pre-selected Images in LR Database, exclude Copies, marked by "Kopie.."
-- special selection if more then on photo found. Selector: "Rot"
-- This runs as asynchronous Task! Main Task has to wait. No Signalling between Takks.
-- add found photos to WP-LR-Sync-Collection
function addToWPColl (collection, search, photos)
  
  LrTasks.startAsyncTask(function ()
    --LrMobdebug.on()
    local catalog = LrApplication.activeCatalog()
    local len = #search
    local selphoto
        
    for i=1,len do
      local lrid = catalog:findPhotos {
        searchDesc = {search[i],
         { criteria = "copyname", -- selektiert die Kopien aus
           operation = "noneOf",
           value = "Kopie", -- TODO: International? oder im PublishSettingsMenu einstellen?
         }, 
        combine = "intersect"} -- UND-Verknüpfung der Kriterien
      }
    
      --------- Auswahl bei mehr als einem gefundenen Foto
      if lrid[2] ~= nil then
        local label = {} 
        local sel = 0
        local nred = 0
        local csel = 0
        local ncol = 0
        local coll = {}
        local pubcoll = {}
        
        for k, ph in ipairs(lrid) do
          label[k] = ph:getFormattedMetadata('label')
          if label[k] == "Rot" then -- TDODO als Variable setzen, für andere Selektoren
            sel = k
            nred = nred +1
          end
          coll[k] = ph:getContainedCollections()
          pubcoll[k] = ph:getContainedPublishedCollections()
          if ((coll[k] ~= nil) or (pubcoll[k] ~= nil)) then
            csel = k
            ncol = ncol +1
          end
          
        end
        
        if nred == 1 then
          selphoto = {lrid[sel]}
          lrid = selphoto
        elseif ncol == 1 then
          selphoto = {lrid[csel]}
          lrid = selphoto
        end
        
      end
      
      photos[i].lrid = lrid -- Speichern der gefundenen Fotos in der Tabelle

      catalog:withWriteAccessDo( 'AddtoWP', function () 
		    collection:addPhotos(lrid)
		  end ) 
    end
  end )
  
end

function exportServiceProvider.goToPublishedCollection( publishSettings, info )
  --LrMobdebug.on()
  o2L('goToPublishedCollection aufgerufen')
  local collection = info.publishedCollection
  local catalog = LrApplication.activeCatalog()
  local nphotos = collection:getPhotos()
  local firstsync = 'false'
  local result
  local mediatable = {}
  local len = 0
  local perpage = 100
  local getmore = true
  local runs = 0
  local plugpath = _PLUGIN.path

  local pscope = LrProgressScope( {
    title = "First Sync WP with LR. Please Wait!",
  })
  
  if #nphotos == 0 then
    firstsync = true 
    publishSettings.firstsync = true
  end
   
  if (firstsync == true and publishSettings.urlreadable == true) then
    while getmore == true
    do
      LrFunctionContext.callWithContext( "GetMedia", function( context )    
         result = GetMedia(publishSettings, perpage, runs+1)
      end,
      result)
      len = #result
          
      local i = 1
      while result[i] ~= nil
      do
        local row = {}
        local keyfound = false
        local str = inspect(result[i])
        local ii,j = string.find(str,'full')
        if ii ~= nil then
          keyfound = true  
		end
		
        if keyfound then
          row = {lrid = {}, id = result[i].id, upldate = result[i].date, width = result[i].media_details.width, height = result[i].media_details.height, slug = result[i].slug, post = result[i].post, gallery = result[i].gallery, phurl = result[i].source_url, filen = result[i].media_details.sizes.full.file} 
        else
          local fname = result[i].media_details.file
          fname = getfile(fname)
          row = {lrid = {}, id = result[i].id, upldate = result[i].date, width = result[i].media_details.width, height = result[i].media_details.height, slug = result[i].slug, post = result[i].post, gallery = result[i].gallery, phurl = result[i].source_url, filen = fname} 
		    end
        
        local index = runs * perpage + i
        mediatable[index] = row
        i = i+1
      end
      
      if len == perpage then
        getmore = true
        runs = runs +1
        --break -- nur für Testzwecke: zum vozeitigen Abbruch : Debug
      else
        getmore = false
      end
      
    end
 
   --LrDialogs.message ( string.format("Found %d Photos in WordPress-Media-Catalog. Adding to collection now.", #mediatable),'','info')
   pscope:setPortionComplete(0.2)

  local foundph = {}
  local notfound = {}
  local nfound = 1
  local nnotfound = 1
  local searchDesc = {}
  local p = string.gsub( plugpath,"\\","/")
  local pscopeadd = (0.65 - 0.2) / #mediatable

  for i=1,#mediatable do
      local filen = mediatable[i].filen
      local success = false
      local lrid
      if filen:find('Chile09_0322',1,true) then -- _1179 _1259
        local b = '3'
      end
      
      if #filen > 3 then
      -- suche mit Dateiname aus WP -- TODO: Pfad zum echten und aktiven LR-cat verwenden!
        success = LrTasks.execute( p .. "/sqlite3.exe ".. p .. "/Lightroom-2.lrcat \"select id_local from AgLibraryFile where idx_filename is '" .. filen .."'\" > " .. p .. "/test.txt") 
        lrid = LrFileUtils.readFile( p ..'/test.txt' )
        if #lrid > 9 then lrid = string.sub(lrid,1,7) end
        lrid = tonumber(lrid)
      
        if lrid == nil then 
          success = LrTasks.execute( p.. "/sqlite3.exe ".. p .. "/Lightroom-2.lrcat \"select id_local, idx_filename from AgLibraryFile where originalFilename like '" .. filen .."%'\" > " .. p .. "/test.txt") 
          local sqltab = {}
          sqltab = sqlread( p .. "/test.txt", '|')
                    
          if #sqltab == 1 then -- einmal gefunden
            lrid = sqltab[1][1] 
            
          elseif #sqltab > 1 then -- mehrfach gefunden, Auswahl mit Selektor Colorlabel = 'Rot'
            local csel = 0
            local ncol = 0
            
            for m=1,#sqltab do
              local id = tostring(sqltab[m][1] - 1)
              success = LrTasks.execute( p.. "/sqlite3.exe ".. p .. "/Lightroom-2.lrcat \"select colorLabels from Adobe_images where id_local is '" .. id .."'\" > " .. p .. "/collabel.txt")
              local label = LrFileUtils.readFile( p ..'/collabel.txt' )
              --Wenn CololLabel == 'Rot' dann filen = idx_filename
              if label:find('Rot',1,true) then -- TODO: Rot als Eingabe-Feld
                csel = m
                ncol = ncol +1
              end
            end -- for
            
            if ncol == 1 then
              lrid = sqltab[csel][1]
              filen = sqltab[csel][2]
            end
          end
        end -- end if lrid
        
        if lrid == nil then
          local base, ext = SplitFilename(filen)
          if base ~= nil then
            success = LrTasks.execute( p.. "/sqlite3.exe ".. p .. "/Lightroom-2.lrcat \"select id_local from AgLibraryFile where baseName is '" .. base .."'\" > " .. p .. "/test.txt") 
            lrid = LrFileUtils.readFile( p ..'/test.txt' )
            if #lrid > 9 then lrid = string.sub(lrid,1,7) end
            lrid = tonumber(lrid)
            if lrid ~= nil then
              filen = base
            end
          end
        end
      
        if lrid == nil then
          filen = replhyphen(filen)
          success = LrTasks.execute( p.. "/sqlite3.exe ".. p .. "/Lightroom-2.lrcat \"select id_local from AgLibraryFile where originalFilename like '" .. filen .."%'\" > " .. p .. "/test.txt") 
          lrid = LrFileUtils.readFile( p ..'/test.txt' )
          if #lrid > 9 then lrid = string.sub(lrid,1,7) end
          lrid = tonumber(lrid)
        end
      --- ende dersuche
      else
        lrid = nil
      end
    
      if lrid ~=nil then
        foundph[nfound] = mediatable[i] 
        searchDesc[nfound] = { criteria = "filename", operation = "==", value = filen, }
        nfound = nfound +1
      else
        notfound[nnotfound] = mediatable[i]
        nnotfound = nnotfound +1
      end
      pscope:setPortionComplete(0.2 + i * pscopeadd)
  end
  pscope:setPortionComplete(0.65)
  
  addToWPColl(collection, searchDesc, foundph) 
  
  --LrDialogs.message ( string.format("Added %d Photos to WordPress-Media-Catalog.", nfound-1),'','info')
  pscope:setPortionComplete(0.8)
  LrTasks.sleep(nfound*0.2) -- necessary to wait for async process
  
  catalog:withWriteAccessDo( 'AddMetaData', function () 
    for i=1, nfound-1 do
        if i > #foundph then
          break
        end
        local photos = foundph[i].lrid
                
        for j, photo in ipairs(photos) do
          local date = tostring(foundph[i].upldate)
          date = iso8601ToTime(date)
          local dateday = LrDate.formatShortDate(date)
          local datetime = LrDate.formatMediumTime( date )

          photo:setPropertyForPlugin( _PLUGIN, 'wpid', tostring(foundph[i].id) )
          photo:setPropertyForPlugin( _PLUGIN,'upldate', dateday .. " / " .. datetime)
          photo:setPropertyForPlugin( _PLUGIN,'wpwidth', tostring(foundph[i].width))
          photo:setPropertyForPlugin( _PLUGIN,'wpheight', tostring(foundph[i].height))
          photo:setPropertyForPlugin( _PLUGIN,'wpimgurl', tostring(foundph[i].phurl))
          photo:setPropertyForPlugin( _PLUGIN,'slug', tostring(foundph[i].slug))
          photo:setPropertyForPlugin( _PLUGIN,'post', tostring(foundph[i].post))
          photo:setPropertyForPlugin( _PLUGIN,'gallery', tostring(foundph[i].gallery) )
        end
       
    end 
  end ) -- catalog:withWriteAccessDo
  
  for i=1,#foundph do
    if foundph[i].lrid[1] == nil then
      table.insert(notfound,foundph[i])
      nnotfound = nnotfound +1
    end
  end
  local p2 = LrPathUtils.getStandardFilePath( 'documents' )
  csvwrite(p2 .. '/notfound.csv',notfound) 
  
  pscope:done()
  LrDialogs.message ( string.format("Added %d Photos to WordPress-Media-Catalog, but %d Photos not found in Catalog! See Log-File", nfound-1, nnotfound-1),'','info')

  -- TODO: Download der nicht gefundenen bilder zum Katalog
  -- Verzeichnis im PublishSettingsMenu angeben und Radio-Buttion zur Aktivierung
  -- Wenn Verzeichnis leer und aber aktiviert, dann LrPathUtils.getStandardFilePath( 'pictures' ) verwenden
  -- Metadaten wie auch bei den gefundenen Fotos setzen
  
  end -- if firtsync
end -- function
--[[
-- image delete callback.
function exportServiceProvider.deletePhotosFromPublishedCollection( publishSettings, arrayOfPhotoIds, deletedCallback )
-- REST-API mit Auth und Force zum Löschen
-- Foto aus der Sammlung entfernen
-- Metdaten aus dem Foto löschen
  o2l('deletePhotosFromPublishedCollection call')
	for i, photoId in ipairs( arrayOfPhotoIds ) do

		Log( string.format( "Deleting id: %d", photoId ));
		--local result = Post( "image/delete",  { pid = photoId }, publishSettings )
		
		-- call the delete callback even if it fails on the Wordpress end
		-- ToDo: Need to fix it so REST doesn't return an error if the delete fails
		--			there's still a potential conflict here if the image is out of
		--			kilter between the server and the local.
		--if result ~= nil then
			--deletedCallback( photoId )
		--end

	end
end

 called when  collection (gallery) is added or renamed.
-- hier gibt es wahrsch. keine Funktion
function exportServiceProvider.updateCollectionSettings( publishSettings, info )
  --LrMobdebug.on()
  o2L('updateCollectionSetSettings call')
  Log( "update Collection Set Settings, creating new album", info.publishedCollection )
	local data = {}		-- the data table we'll be sending to WP

	local collection = info.publishedCollection
	local remoteID = collection:getRemoteId()	-- null if not yet published

	data.name = collection:getName()

	-- parenting
	-- WP needs to add the new album to the parent's list of children.
	local parentSet = collection:getParent()
	if parentSet then
		data.parent = parentSet:getRemoteId()
	end
	--Debug.pauseIfAsked()

	if remoteID == nil then	-- remote gallery doesn't exist yet, create new one

		Log( "Creating new gallery", data.name )

		local result = Post( "gallery/create", data, publishSettings )

		if result ~= nil then
			local gid = result.gid
			local  catalog = LrApplication.activeCatalog()
			catalog:withWriteAccessDo( "setGID", function( context )
				collection:setRemoteId( gid ) -- set remote gallery id
				Log( "Set remote album id: ", gid )
				end )
		end
	else
		Log( "Remote Gallery Exists already. Doing nothing")
	end

end

-- called when a publish collection set (album) is added or changed. (renamed)
-- hier gibt es wahrsch. keine Funktion
function exportServiceProvider.updateCollectionSetSettings( publishSettings, info ) 
	Log( "update Collection Set Settings, creating new album", info.publishedCollection )
--LrMobdebug.on()
	--LrTasks.startAsyncTask( function()

		local data = {}		-- the data table we'll be sending to WP

		local collection = info.publishedCollection
		local remoteID = collection:getRemoteId()	-- null if not yet published
		data.name = collection:getName()

		-- parenting
		-- WP needs to add the new album to the parent's list of children.
		local parentSet = collection:getParent()
		if parentSet then
			data.parent = parentSet:getRemoteId()
		end
		--Debug.pauseIfAsked()
		if remoteID == nil then	-- remote album doesn't exist yet, create new one
		
			local result = Post( "album/create", data, publishSettings )
	
			if result ~= nil then

				local aid = result.aid
				-- set the remote id for this collection set
				local  catalog = LrApplication.activeCatalog()
				catalog:withWriteAccessDo( "setAID", function( context )
					collection:setRemoteId( aid ) -- set remote gallery id
					Log( "Set remote album id: ", aid )
					end )
			end

		else	-- gallery has been changed in some other way. Rename, possibly?
			--LrDialogs.showBezel( "Remote Album Exists", 3 )
			Log( "Remote Album Exists already. Doing nothing")
		end
	
	--end) -- lrTasks
end 

-- sort order als Variable im PHP in WP einstellen:
-- hier gibt es also wahrsch. keine Funktion)
function exportServiceProvider.imposeSortOrderOnPublishedCollection( publishSettings, info, remoteIdSequence )
  o2L('imposeSortOrderOnPublishedCollection call')
	-- ToDo: LR gives an empty id sequence if count of images is 2 or less. Maybe
	-- why 2??
	if #remoteIdSequence == 0 then
		Log( "Sort: zero length id sequence. Nothing to sort")
		return
	end
	--local result = Post( "gallery/sort", { sequence = remoteIdSequence }, publishSettings )
end


-- direkten Login in die Medien-Bibliothek öffnen
function exportServiceProvider.goToPublishedPhoto( publishSettings, info )
  o2L('goToPublishedPhoto call')
--(optional) This plug-in defined callback function is called when the user chooses the "Go to Published Photo" context-menu item.
end
]]
-- publish Photos -- processRenderedPhotos
function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )
  o2L('processRenderedPhotos aufgerufen')
  
  --Debug.pauseIfAsked()
  LrMobdebug.on()
  --local LrExportSession = import 'LrExportSession' 
	local exportSession = exportContext.exportSession
  local exportSettings = exportContext.propertyTable
	local nPhotos = exportSession:countRenditions()
  local exportParams = exportSettings
	local publishedCollectionInfo = exportContext.publishedCollectionInfo
  local rend = exportContext.renditions
  local uploadedPhotoIds = {}
  --Debug.pauseIfAsked()
  --[[
  for i, rendition in exportContext:renditions { stopIfCanceled = true } do

		local photo = rendition.photo

		if not rendition.wasSkipped then

			local success, pathOrMessage = rendition:waitForRender()
      if success then
        local ImageID = 0-- published before? 
        if ImageID then -- replace image
						
        else -- new image
						ImageID  = 111 -- set to wpid
        end
        rendition:recordPublishedPhotoId( ImageID )
      end
      
    end
  end
  ]]
end

function exportServiceProvider.getCollectionBehaviorInfo( publishSettings )
  o2L('getCollectionBehaviorInfo call')
  -- Diese Funktion wird nach "Veröffentlichen" als erste aufgerufen
	--outputToLog('getCollectionBehaviorInfo aufgerufen')
	
	return {
		defaultCollectionName = LOC "$$$/Wordpress/DefaultCollectionName/WPCat=WPCat",
		defaultCollectionCanBeDeleted = false,
		canAddCollection = true,
		maxCollectionSetDepth = 0,
	}
	
end

function exportServiceProvider.metadataThatTriggersRepublish( publishSettings )
	--outputToLog('metadataThatTriggersRepublish aufgerufen')
	return {

		default = true,
		title = true,
		caption = true,
		keywords = true,
		gps = true,
		dateCreated = false,
		copyright = true,
		headline = true,
		instructions = true,
		label = true,
		provider = true,
		rating = false,
		source = true,
		imagedate = true,
	}

end

return exportServiceProvider
