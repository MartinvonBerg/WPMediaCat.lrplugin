--	Main entry point for plugin.
local LrDialogs = import 'LrDialogs'
local LrApplication = import( 'LrApplication' )
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrHttp = import 'LrHttp'
local LrDate = import 'LrDate'
local LrTasks = import 'LrTasks'
local LrProgressScope = import( 'LrProgressScope' )
local LrFunctionContext = import 'LrFunctionContext'
local LrExportSession = import 'LrExportSession'
local LrShell = import 'LrShell'
local LrMD5 = import 'LrMD5'
local LrPhotoInfo = import 'LrPhotoInfo'


local mypluginID = 'com.adobe.lightroom.export.wp_mediacat2' -- TODO: durch variable ersetzen
local catoutdate = 2 -- in days
local HDDwritespeed = 100 -- in MBytes / s
local WPCatColl = 'WPCat'

----- Debug -----------
--logDebug = false
require 'strict'
require 'Logger'
local DebugSync = logDebug
local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
LrMobdebug.start()
local inspect = require 'inspect'
----- Debug -----------

JSON=require 'JSON'
require 'Dialogs'
require 'helpers'
require 'Post'

------------ exportServiceProvider ----------------------------
exportServiceProvider = {}
exportServiceProvider.supportsIncrementalPublish = 'only'
exportServiceProvider.small_icon = "Small-icon.png"
exportServiceProvider.hideSections = { 'exportLocation', 'fileNaming' } -- exportLocation erzeugt den Reiter "Speicherort für Export", evtl. imageSettings ergänzen
exportServiceProvider.allowFileFormats = { 'JPEG' } 								-- TODO: alle Filetypen erlauben. evtl. Plugin von J.Friedl oder Ellis verwenden
exportServiceProvider.allowColorSpaces = { 'sRGB' }
exportServiceProvider.hidePrintResolution = true									-- hide print res controls
exportServiceProvider.canExportVideo = false 										-- video is not supported through this plug-in
exportServiceProvider.supportsCustomSortOrder = true  -- this must be set for ordering
exportServiceProvider.startDialog = dialogs.startDialog							-- see dialogs.lua, integrieren oder umbenennen wie bei ftp-task
exportServiceProvider.sectionsForTopOfDialog = dialogs.sectionsForTopOfDialog -- see dialogs.lua, integrieren oder umbenennen wie bei ftp-task
exportServiceProvider.exportPresetFields = {
	{ key = "siteURL", default = "" },
	{ key = "loginName", default = "" },
	{ key = "loginPassword", default = "" },
	{ key = "hash", default = ""},
	{ key = "DebugMode", default = false}, -- Currently used for Debugging activation
  { key = "urlreadable", default = false},
  { key = "firstsync", default = false},
  { key = "wpplugin", default = false}, -- wird nur bei "Check Login" geprüft. Danach nicht mehr, wenn dann entfernt, dann keine Fehlermeldung
}
exportServiceProvider.titleForGoToPublishedCollection = 'Sync with Wordpress'
exportServiceProvider.titleForGoToPublishedPhoto = 'disable' --or 'Go to Foto in WP Catalog'
exportServiceProvider.disableRenamePublishedCollection = true -- benennt die Sammlung im Dienst um, erzeugt damit einen neuen Ordner
exportServiceProvider.disableRenamePublishedCollectionSet = true -- benennt den ganzen Dienst um
------------ exportServiceProvider ----------------------------

-- publish Photos -- processRenderedPhotos -- hier werden die fotos die in der Sammlung sind verarbeitet. 
function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )
  Log('processRenderedPhotos aufgerufen')
  LrMobdebug.on()

  local exportSession = exportContext.exportSession
  local exportSettings = exportContext.propertyTable
  local catalog = LrApplication.activeCatalog()
	local nPhotos = exportSession:countRenditions()
  local pseudoPublishSettings = exportSettings['< contents >']
  local folder = exportContext.publishedCollectionInfo.name
  local defaultcoll = exportContext.publishedCollectionInfo.isDefaultCollection
  local renderedPhoto = {}
  local progressScope = exportContext:configureProgress {
    title = nPhotos > 1
    and LOC("$$$/PhotoDeck/ProcessRenderedPhotos/Progress=Publishing ^1 photos to PhotoDeck", nPhotos)
    or LOC "$$$/PhotoDeck/ProcessRenderedPhotos/Progress/One=Publishing one photo to PhotoDeck", -- laut LR SDK Handbuch wird dieser Titel bei Publish nicht angezeigt
  }
  
  -- Check Gallery-Name again
  local ok, message = checkfolder( folder )
  if ok == false then
    Log(message)
    LrDialogs.message ('Wrong Collection Name: ' .. folder, 'Reason: ' .. message ..'.\nPlease delete the Collection and create a new one with correct Name containing only a-z, A-Z, 0-9, / - and _ . The Collection must not be named like 2020/11 and must not start or end with slashes.','warning')
    progressScope:done()
    return 
  end

  for i, rendition in exportContext:renditions { stopIfCanceled = true } do
    
    local success, pathOrMessage = rendition:waitForRender()
    local photo = rendition.photo
    local ImageID, wpid, data, result
          
    if success then
      progressScope:setPortionComplete( ( i - 1 ) / nPhotos )
      
      -- Metadaten aus dem LR Katalog auslesen
      wpid = photo:getPropertyForPlugin( mypluginID, 'wpid' ) 
      if wpid == nil or wpid == '' or wpid == 'nil' then wpid = 0 end
      local photoMeta = {
        caption = photo:getFormattedMetadata( 'caption' ),
        title = photo:getFormattedMetadata( 'title' ),
        gallery = photo:getPropertyForPlugin( mypluginID, 'gallery' ),
        keywords = photo:getFormattedMetadata('keywordTagsForExport'), -- return keys as table
        credit = photo:getFormattedMetadata( 'artist' ),
        copyright = photo:getFormattedMetadata( 'copyright' ),
        sortorder = i,
      }
      
     
      if tonumber(wpid) > 0 then -- update image or create virtual copy if existing  
          if progressScope:isCanceled() then progressScope:cancel() end 
          Log('-----------------------------------------------------------')
          Log('WPId :' .. wpid .. ' found in Meta. Now updating')
       
          -- get REST-Meta-Data
          data = GetMedia(pseudoPublishSettings, wpid) 
          data = ExtractDataFromREST(data)

          -- get Filenames and MD5-values
          local filename = photo:getFormattedMetadata( 'fileName' ) -- LrPathUtils.leafname( pathOrMessage ) liefert auch den Dateinamen, hier aber filename für WP-Mediacat
          Log('Updating File: ' .. filename .. ' to WP')
          local renditionFilePath = LrPathUtils.standardizePath( pathOrMessage ) -- Der Anhang -scaled wird von WP automatisch ergänzt
          local dimensions = LrPhotoInfo.fileAttributes( renditionFilePath ) -- table: width, height
          Log('Rendition-Datei: ' .. renditionFilePath)
          local rendFileContent = LrFileUtils.readFile( renditionFilePath )
          local MD5rend = LrMD5.digest( rendFileContent )
          MD5rend = string.upper( MD5rend )
          Log('Folder = Gallery: ' .. folder .. ' : ' .. data.gallery)

          if ((folder == data.gallery) or (folder == WPCatColl and data.gallery == '')) then
                       
            if data.MD5 == MD5rend then
              -- update keywords only (tritt vermutlich nie ein, da bei LR die rendition immer eine andere MD5-Summe hat)
              result = 'none'
              result, data = UpdateKeys( pseudoPublishSettings, photoMeta, wpid )
            else
              -- update photo including keywords
              result = 'none'
              result, data = UpdateMedia( pseudoPublishSettings, filename, renditionFilePath, wpid )
            end
          
            -- Prüfung auf Identität. wenn hier Änderung in der Logik, dann auch in Funktion WritephotoMetaToWp ändern!
            if data['title'] == photoMeta['title'] and  (data['caption'] == photoMeta['title']) then 
              photoMeta['title'] = '' 
            end -- title und caption = title

            if (data['alt'] == photoMeta['caption']) and (data['descr'] == photoMeta['caption'])   then --alt und descr = caption
              photoMeta['caption'] = '' 
            photoMeta['caption'] = '' 
              photoMeta['caption'] = '' 
            end

            if data['gallery'] == photoMeta['gallery'] then photoMeta['gallery'] = '' end
          

            local success = WritephotoMetaToWp( pseudoPublishSettings, tonumber(wpid), photoMeta )
            if success then
              Log('WpId :' .. wpid .. ' REST-Meta was updated')
              ImageID  = 'WPSync' .. tostring(wpid) -- published before?  -- set to wpid
            else
              ImageID = ''
            end
            
            catalog:withWriteAccessDo( 'UpdateDimension', function ()
              photo:setPropertyForPlugin( _PLUGIN,'wpwidth', tostring(dimensions['width']) )
              photo:setPropertyForPlugin( _PLUGIN,'wpheight', tostring(dimensions['height']) )
              photo:setPropertyForPlugin( _PLUGIN,'order', tostring(i) )
            end )

            renderedPhoto[i] = {}
            renderedPhoto[i][1] = photo
            renderedPhoto[i][2] = ImageID -- remoteID
            renderedPhoto[i][3] = exportContext.publishedCollection.localIdentifier
            rendition:recordPublishedPhotoUrl(tostring(exportContext.publishedCollection.localIdentifier))
            
          else
            -- create virtual copy if correct image   
          end

         
          
      else -- add new image to WP Media Catalog
          if progressScope:isCanceled() then progressScope:cancel() end 
          local filename = LrPathUtils.leafName( pathOrMessage ) --liefert auch den Dateinamen, hier aber filename für WP-Mediacat
          Log(i ..' Adding File: ' .. filename .. ' to WP')
          local renditionFilePath = LrPathUtils.standardizePath( pathOrMessage ) -- Der Anhang -scaled wird von WP automatisch ergänzt
          Log('Rendition-Datei: ' .. renditionFilePath)
          local result = 'none'
          result, data = AddNewMedia( pseudoPublishSettings, filename, renditionFilePath, defaultcoll, folder ) -- Einschränkungen siehe dort!
          
          if type(result) == 'number' then
            ImageID  = 'WPSync' .. tostring(result) -- set to wpid --diese Nummer muss eineindeutig sein!
            -- fehlende LR-Metadaten in den WP Katalog schreiben
            WritephotoMetaToWp( pseudoPublishSettings, result, photoMeta )
            -- Custom-Metadaten in WP-Katalog schreiben: Rest-Antwort-Daten in CustomMeta schreiben
            catalog:withWriteAccessDo( 'AddMetaData', function ()
              WriteCustomMetaData( pseudoPublishSettings, photo, data )
            end )

            rendition:recordPublishedPhotoId( ImageID )
            rendition:recordPublishedPhotoUrl(tostring(exportContext.publishedCollection.localIdentifier))
            renderedPhoto[i] = {}
            renderedPhoto[i][1] = photo   -- catalog photo
            renderedPhoto[i][2] = ImageID -- remoteID
            renderedPhoto[i][3] = exportContext.publishedCollection.localIdentifier
            
          else
            LrDialogs.showError( result)
            ImageID = 'nil'
          end

          Log('Upload created new WPId: ' .. ImageID .. ' if empty: not created')
      end
            
    end
    -- delete temp file. There is a cleanup step that happens later, but this will help manage space in the event of a large upload.
		LrFileUtils.delete( pathOrMessage )
    
  end

  progressScope:done()

  -- Set the edited flag as sometimes it es reset by the pscope. Don't know why
  local publishedCollection = LrApplication.activeCatalog():getPublishedCollectionByLocalIdentifier(tonumber(renderedPhoto[1][3])) -- Es wird immer nur aus einer Collection aktualisert
  local publishedPhotos = publishedCollection:getPublishedPhotos()
  local sub = {}
  for m=1, #renderedPhoto do
    sub[m] = renderedPhoto[m][2]
  end
  local arraytostring = inspect(sub)

  for _, pp in pairs(publishedPhotos) do
    local remoteId = pp:getRemoteId()
    local ii,j = string.find(arraytostring, remoteId) -- den vollen Filename suchen

    if ii ~= nil then
      Log('set edit flag: ', remoteId)
      catalog:withWriteAccessDo( 'UpdateEditedFlag', function ()
        pp:setEditedFlag(false)
      end)
    end

  end

end

-- Sync with Wordpress: exportServiceProvider.titleForGoToPublishedCollection = 'Sync with Wordpress'
function exportServiceProvider.goToPublishedCollection( publishSettings, info )
  --LrMobdebug.on()
  Log('goToPublishedCollection aufgerufen (Sync with Wordpress)')
  local collection = info.publishedCollection
  local catalog = LrApplication.activeCatalog()
  local nphotos = collection:getPhotos()
  local firstsync = false
  local result
  local mediatable = {}
  local len = 0
  local perpage -- Anzahl der Media-Einträge per REST-Abfrage
  local getmore = true
  local runs = 0

  local p = string.gsub( _PLUGIN.path,"\\","/")
  local lrcatactive = catalog:getPath()
  lrcatactive = string.gsub( lrcatactive,"\\","/") -- check: zu alt, klein, nicht vorhanden
  local lrcat = p .. "/" .. getfile(lrcatactive)

  -- Prüfe ob der kopierte Katalog vorhanden und aktuell ist
  local catsuccess = LrFileUtils.exists(lrcat)
  if catsuccess == 'file' then -- check: zu alt, klein
    local attrib = LrFileUtils.fileAttributes( lrcat )
    if tonumber(attrib['fileSize']) < 4096 then catsuccess = false end
    local filedate = attrib['fileModificationDate'] -- a number of seconds since midnight UTC on January 1, 2001.
    local currdate = LrDate.currentTime() -- Retrieves the current date and time as a Cocoa date stamp. that is, a number of seconds since midnight UTC on January 1, 2001.
    if math.abs(currdate - filedate) > (catoutdate * 24 * 60 * 60) then 
      catsuccess = false 
      Log('Cat ' .. lrcat .. ' outdated')
    end
  end

  if catsuccess == false or catsuccess == 'directory' then
    local button = LrDialogs.confirm ( "Local Copy of active LR-Catalog not found or outdated",'Press OK to copy ' .. lrcatactive .. ' to ' .. lrcat)
    if button == 'cancel' then
      return
    else
      -- do copy of active catalog
      local waittime = math.floor(LrFileUtils.fileAttributes( lrcatactive )['fileSize'] / (1048576 * HDDwritespeed)) -- Mbyte * HDD - write-speed
      Log('Copy Cat - wait for: ' .. waittime .. ' seconds')
      lrcatactive = string.gsub( lrcatactive,"/","\\") -- Quelle
      lrcat = string.gsub( lrcat,"/","\\")              -- Ziel
      -- LrShell.openPathsViaCommandLine( {goal:string}, cmd:string, source:string)
      local succ = LrShell.openPathsViaCommandLine( {lrcat}, "copy", lrcatactive )
      Log(succ)
      
      local pscope1 = LrProgressScope( {
        title = "Copying LR catalogue. Please Wait!",
      })
      for i=1,waittime do
        pscope1:setPortionComplete(i / waittime)
        LrTasks.sleep(1)
      end
      pscope1:done()
      
      if not succ then
        LrDialogs.message ('Could not copy LR-catalog!','','critical')
        return
      end
    end
  end

  if DebugSync then
    perpage = 20 -- Anzahl der Media-Einträge per REST-Abfrage
  else
    perpage = 100 -- Anzahl der Media-Einträge per REST-Abfrage
  end

  local pscope = LrProgressScope( {
    title = "First Sync WP with LR. Please Wait!",
  })
  
  if #nphotos == 0 then
    firstsync = true -- Zugriff in processRenderedPhotos nur mit exportContext.propertyTable.firstsync
    publishSettings.firstsync = true
    --TODO: exportContext.propertyTable.firstsync = true
  end
  
  -- Alle Fotos mit REST-Api aus dem WP-Media-Catalog auslesen
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
        row = ExtractDataFromREST(result[i])
        local index = runs * perpage + i
        mediatable[index] = row
        i = i+1
      end
      
      if len == perpage then
        getmore = true
        runs = runs +1
        if DebugSync then break end -- nur für Testzwecke: zum vozeitigen Abbruch : Debug
      else
        getmore = false
      end
      
    end
 
  LrDialogs.message ( string.format("Found %d Photos in WordPress-Media-Catalog. Adding to Sync-collection now.", #mediatable),'','info')
  pscope:setPortionComplete(0.2)

  -- Suche die Fotos im LR-Catalog
  local foundph = {}
  local notfound = {}
  local nfound = 1
  local nnotfound = 1
  local searchDesc = {}
  local pscopeadd = (0.65 - 0.2) / #mediatable
  local sqcat1 = p .. "/sqlite3.exe ".. lrcat 
  Log('Use Cat: ' .. sqcat1)

  ----------------------------------------------------------
  -- Suchlauf
  for i=1,#mediatable do
      local filen = mediatable[i].filen
      local success = false
      local lrid
      --if filen:find('Chile09_0322',1,true) then -- _1179 _1259
      --  local b = '3'
      --end
      
      if #filen > 3 then
      -- suche mit Dateiname aus WP -- TODO: Pfad zum echten und aktiven LR-cat verwenden!
        success = LrTasks.execute( sqcat1 .. " \"select id_local from AgLibraryFile where idx_filename is '" .. filen .."'\" > " .. p .. "/test.txt") 
        lrid = LrFileUtils.readFile( p ..'/test.txt' )
        if #lrid > 9 then lrid = string.sub(lrid,1,7) end
        lrid = tonumber(lrid)
      
        if lrid == nil then 
          success = LrTasks.execute( sqcat1 .. " \"select id_local, idx_filename from AgLibraryFile where originalFilename like '" .. filen .."%'\" > " .. p .. "/test.txt") 
          local sqltab = {}
          sqltab = sqlread( p .. "/test.txt", '|')
                    
          if #sqltab == 1 then -- einmal gefunden
            lrid = sqltab[1][1] 
            
          elseif #sqltab > 1 then -- mehrfach gefunden, Auswahl mit Selektor Colorlabel = 'Rot'
            local csel = 0
            local ncol = 0
            
            for m=1,#sqltab do
              local id = tostring(sqltab[m][1] - 1)
              success = LrTasks.execute( sqcat1 .. " \"select colorLabels from Adobe_images where id_local is '" .. id .."'\" > " .. p .. "/collabel.txt")
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
            success = LrTasks.execute( sqcat1 .. " \"select id_local from AgLibraryFile where baseName is '" .. base .."'\" > " .. p .. "/test.txt") 
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
          success = LrTasks.execute( sqcat1 .. " \"select id_local from AgLibraryFile where originalFilename like '" .. filen .."%'\" > " .. p .. "/test.txt") 
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
  
  -- Im Katalog gefundene Fotos zur Collection hinzufügen. Weitere Einschränkung bei mehrfach gefundenden Photos
  addToWPColl(collection, searchDesc, foundph) 
  ------------------------------------------------------------------------

  LrDialogs.message ( string.format("Added %d Photos to WordPress-Media-Catalog.", nfound-1),'','info')
  pscope:setPortionComplete(0.8)
  LrTasks.sleep(nfound*0.2) -- necessary to wait for async process
  
  -- Write extracted Rest-meta-Data to customMetadata in Lightroom Catalog
  catalog:withWriteAccessDo( 'AddMetaData', function () 
    for i=1, nfound-1 do
        if i > #foundph then
          break
        end
        local photos = foundph[i].lrid
                
        for j, photo in ipairs(photos) do
          WriteCustomMetaData( publishSettings, photo, foundph[i])
        end
       
    end 
  end ) -- catalog:withWriteAccessDo
  
  -- Write csv-File with not found Photos
  for i=1,#foundph do
    if foundph[i].lrid[1] == nil then
      table.insert(notfound,foundph[i])
      nnotfound = nnotfound +1
    end
  end
  local p2 = LrPathUtils.getStandardFilePath( 'documents' )
  csvwrite(p2 .. '/notfound.csv',notfound, ';') 
  
  pscope:done()
  LrDialogs.message ( string.format("Added %d Photos to WordPress-Media-Catalog, but %d Photos not found in Catalog! See Log-File", nfound-1, nnotfound-1),'','info')

  -- TODO: Download der nicht gefundenen bilder zum Katalog
  -- TODO: am Ende process rendered photos mit context aufrufen, um die ImageID in der rendition zu setzen.
  -- Verzeichnis im PublishSettingsMenu angeben und Radio-Buttion zur Aktivierung
  -- Wenn Verzeichnis leer und aber aktiviert, dann LrPathUtils.getStandardFilePath( 'pictures' ) verwenden
  -- Metadaten wie auch bei den gefundenen Fotos setzen
  
  end -- if firtsync
end -- function

----------------------------- fertig -----------------------------------------------
-- Delete photo from published collection, delete in WP-Media-Catalog, delete MetaData in LR Catalog
-- Quelle: https://github.com/willthames/photodeck.lrdevplugin : PhotoDeckPublishServiceProvider.lua (Zeilen 313ff)
function exportServiceProvider.deletePhotosFromPublishedCollection (publishSettings, arrayOfPhotoIds, deletedCallback, localCollectionId)
  Log('publishServiceProvider.deletePhotosFromPublishedCollection')
  LrMobdebug.on() 
  local catalog = LrApplication.activeCatalog()
  local publishedPhotoById = {}
  local photoUnpublish = {}
  local result
  local error_msg = 'nix'
  
  -- this next bit is stupid. Why is there no catalog:getPhotoByRemoteId or similar
  local collection = catalog:getPublishedCollectionByLocalIdentifier(localCollectionId)
  --local galleryId = collection:getRemoteId()
  local publishedPhotos = collection:getPublishedPhotos()
  
  for _, pp in pairs(publishedPhotos) do
    publishedPhotoById[pp:getRemoteId()] = pp
  end

  for i, photoId in ipairs( arrayOfPhotoIds ) do
    if photoId ~= "" then
      local publishedPhoto = publishedPhotoById[photoId]
      local catphoto = publishedPhoto:getPhoto()
      photoUnpublish[i] = {}
      photoUnpublish[i][1] = catphoto -- lr cat id
      photoUnpublish[i][2] = photoId  -- remote id
      photoUnpublish[i][3] = publishedPhoto
      photoUnpublish[i][4] = true  -- remote id
    end
  end
  
  LrTasks.startAsyncTask(function ()
    LrMobdebug.on()
    local hash = 'Basic ' .. publishSettings.hash
	  local httphead = {
      {field='Authorization', value=hash},
    }
        
    for i=1, #photoUnpublish do
      local photo = photoUnpublish[i][1]
      local wpid = photo:getPropertyForPlugin( mypluginID, 'wpid' )
      if wpid == nil or wpid =='' then wpid = 0 end
      Log('wpid to delete: ', wpid)
      local success = false

      -- Check timestamps before delete and calculate difference of timestamps
      local difftime = -1
      local wptime = -1
         --- Lightroom Time 
      local lrtime = photo:getRawMetadata( 'dateTimeOriginal' ) --  dateTimeOriginal: (number) The date and time of capture (seconds since midnight GMT January 1, 2001)
      Log('LR dateTimeOriginal: ', lrtime)
      lrtime = LrDate.timeToPosixDate(lrtime)
      Log('LR dateTimeOriginal: ', lrtime)
         --- Wordpress Time        
      if tonumber(wpid) > 0 then     
        local url = publishSettings.siteURL .. "/wp-json/wp/v2/media/" .. tostring(wpid)   
        Log ('Timestamp-URL: ', url)
        local result, headers = LrHttp.get( url, httphead )
        
        if headers.status == 200 then
          result = JSON:decode(result)
          if result['media_details'] ~= nil then
            wptime = tonumber(result["media_details"]["image_meta"]["created_timestamp"])
          end  
          Log('wp created_timestamp: ', wptime)
          difftime = (wptime - lrtime) -- % 3600
          Log('Timediff: ', difftime)
          difftime = difftime % 3600
        elseif headers.status == 404 then
          difftime = 0
        end

      end
    
      --if (tonumber(wpid) > 0) and (difftime == 0) then
        -- geplant war Bilder mit falscher Zeitdifferenz nicht zu löschen
        -- Der Schutz funktioniert: Metadaten werden entfernt und das Foto aus der Collection
        -- Bei erstellten Panos wird aber die Erstellungszeit geändert! Daher: IMMER löschen!
      if (tonumber(wpid) > 0) and (difftime == 0) then 
        success = DeleteMedia(publishSettings, wpid)
      end

      catalog:withWriteAccessDo( 'DeleteMetaData', function ()
          photo:setPropertyForPlugin( _PLUGIN, 'wpid', '' )
          photo:setPropertyForPlugin( _PLUGIN,'upldate', '' )
          photo:setPropertyForPlugin( _PLUGIN,'wpwidth', '')
          photo:setPropertyForPlugin( _PLUGIN,'wpheight', '')
          photo:setPropertyForPlugin( _PLUGIN,'wpimgurl', '')
          photo:setPropertyForPlugin( _PLUGIN,'slug', '' )
          photo:setPropertyForPlugin( _PLUGIN,'post', '')
          photo:setPropertyForPlugin( _PLUGIN,'gallery',  '')
      end )
      Log('WP-Media deleted: ' ..tostring(wpid) )
      
    end
    error_msg = 'fertig'
    
  end, error_msg )

  --LrTasks.sleep( 0.5 * #photoUnpublish)
  --Log('AsyncTask done', error_msg) 

  for k=1,#photoUnpublish do
    if photoUnpublish[k][4] then
      deletedCallback( photoUnpublish[k][2] )
    end
  end

end

-- Diese Funktion wird nach "Veröffentlichen" als erste aufgerufen, Warum und wofür ist unklar
function exportServiceProvider.getCollectionBehaviorInfo( publishSettings )
  --LrMobdebug.on()
  --logDebug = publishSettings.DebugMode
  Log('getCollectionBehaviorInfo call')
  Log('WP-Plugin installed: ', publishSettings.wpplugin)
    	
	return {
		defaultCollectionName = LOC "$$$/Wordpress/DefaultCollectionName/WPCat=WPCat",
		defaultCollectionCanBeDeleted = false,
		canAddCollection = true,
		maxCollectionSetDepth = 0,
	}
	
end

-- Funktion zum Löschen einer ganzen Collection / Folder / Gallerie. Nur für Zusätzliche, nicht der Standard-Folder
-- löscht nur die Fotos im Folder, nicht den Folder im Upload-Verzeichnis
function exportServiceProvider.deletePublishedCollection( publishSettings, info )
  LrMobdebug.on() 
  local catalog = LrApplication.activeCatalog()
  local publishedCollection = info.publishedCollection
  local name = info.name
  local publishedPhotos = publishedCollection:getPublishedPhotos()

  local hash = 'Basic ' .. publishSettings.hash
  local httphead = {
    {field='Authorization', value=hash},
  }

  for _, pp in pairs(publishedPhotos) do
    local remoteId = pp:getRemoteId()
    local wpid = string.match(remoteId, '%d+') -- Rückgabe als string
    local photo = pp:getPhoto()
    
    if wpid == nil or wpid =='' then wpid = 0 end
    Log('wpid to delete: ', wpid)
    
    if (tonumber(wpid) > 0) then 
      DeleteMedia(publishSettings, wpid)
    end

    catalog:withWriteAccessDo( 'DeleteCollection', function ()
        photo:setPropertyForPlugin( _PLUGIN, 'wpid', '' )
        photo:setPropertyForPlugin( _PLUGIN,'upldate', '' )
        photo:setPropertyForPlugin( _PLUGIN,'wpwidth', '')
        photo:setPropertyForPlugin( _PLUGIN,'wpheight', '')
        photo:setPropertyForPlugin( _PLUGIN,'wpimgurl', '')
        photo:setPropertyForPlugin( _PLUGIN,'slug', '' )
        photo:setPropertyForPlugin( _PLUGIN,'post', '')
        photo:setPropertyForPlugin( _PLUGIN,'gallery',  '')
    end )
    Log('WP-Media deleted: ' ..tostring(wpid) )
    
  end
end

-- prüft den gerade erstellten Collection-Name und löscht diesen falls falsch
function exportServiceProvider.endDialogForCollectionSettings( publishSettings, info )
  LrMobdebug.on() 
  local folder = info.name 
  local collection = info.publishedCollection
  local ok = false 
  local message = 'Problem'
  
  ok, message = checkfolder( folder )
  Log(folder)
  Log(ok)
  Log(message)
  
  if ok == false then
    LrDialogs.message ('Wrong Collection Name: ' .. folder, 'Reason: ' .. message ..'.\nPlease delete the Collection and create a new one with correct Name containing only a-z, A-Z, 0-9, / - and _ . The Collection must not be named like 2020/11 and must not start or end with slashes.','warning')
    collection.delete() -- Das ergibt einen Fehler, dann bricht LR ab und die Gallerie wird nicht erstellt
  end

end

function exportServiceProvider.metadataThatTriggersRepublish( publishSettings )
	Log('metadataThatTriggersRepublish aufgerufen')
	return {
    default = true,
    label = false,
		rating = false,
		title = true,
		caption = true,
		keywords = true,
    gps = true,
    gpsAltitude = true,
		dateCreated = false,
		copyright = true,
    customMetadata = true, 
  }

end

function WritephotoMetaToWp( publishSettings, wpid, photoMeta )
	-- Write LR Metadata of photo to WP Mediacat via REST-API
	-- Parameters: wpid: Number evtl. auch String, aber dann zu Number wandelbar
	-- photoMeta: Tabelle mit Metadaten als key-value-pair
	-- publishSettings: Tabelle ähnlich den Lr-Lua-PublishSettings, hier aber kopiert, da Original nicht bereitsteht
	-- LR caption kommt in den alt-tag und in die Beschreibung bzw. description.raw 
	-- alt-tag leerlassen, wenn das Bild als dekoratives Element dient!
  
	-- Example: http-POST: http://127.0.0.1/wordpress/wp-json/wp/v2/media/4224?gallery=paularo&description=cat=paularo
	-- Example: http-POST: http://127.0.0.1/wordpress/wp-json/wp/v2/media/4224?title=MPaul
	-- Example: http-POST: http://127.0.0.1/wordpress/wp-json/wp/v2/media/4474?alt_text=alternate-text
	  
	local success = false
  
	if type(wpid) ~= 'number' or photoMeta == {} or publishSettings == {} or publishSettings['hash'] == '' or publishSettings['siteURL'] == '' then
	  Log('WritephotoMetaToWp failed')
	  return success
	end
  
	local n = 0
	local hash = 'Basic ' .. publishSettings['hash']
	local httphead = {
		{field='Authorization', value=hash},
	}
	local result
	local headers
  
	local function pre(n)
	  -- suffix für url bestimmen je nach anzahl metadaten '?' oder '&'
	  local str = ''
	  if n == 0 then
		str = '?'
	  else
		str = '&'
	  end
	  return str
	end
	
	local char_to_hex = function(c)
	  return string.format("%%%02X", string.byte(c))
	end
	
	local function urlencode(url)
	  if url == nil then
		return
	  end
	  url = url:gsub("\n", "\r\n")
	  url = url:gsub("([^%w ])", char_to_hex)
	  url = url:gsub(" ", "+")
	  return url
	end
  
	local url = publishSettings['siteURL'] .. "/wp-json/wp/v2/media/" .. tostring(wpid)
	
	for k, v in pairs(photoMeta) do
	  if k == 'caption' and v ~= '' and v ~= nil and v ~= 'nil' then -- TODO : bei mehr Metadaten durch case switch ersetzen
		v = urlencode(v) -- der wert muss für dt. Umlaute und leerzeichen encoded werden, aber nur der Wert!
		local str = 'alt_text=' .. v .. '&description=' .. v -- schreibe caption in alt-tag und description, sonst kein Feld in LR vorhanden
		url = url .. pre(n) .. str
		n = n + 1
	  end
	  if k == 'gallery' and v ~= '' and v ~= nil and v ~= 'nil' then
		v = urlencode(v)
		local str = 'gallery=' .. v
		url = url .. pre(n) .. str
		n = n + 1
	  end
	  if k == 'title' and v ~= '' and v ~= nil and v ~= 'nil' then -- TODO : bei mehr Metadaten durch case switch ersetzen
		v = urlencode(v) -- der wert muss für dt. Umlaute und leerzeichen encoded werden, aber nur der Wert!
		local str = 'title=' .. v .. '&caption=' .. v -- schreibe caption in alt-tag und description, sonst kein Feld in LR vorhanden
		url = url .. pre(n) .. str
		n = n + 1
	  end
	end
  
	if n>0 then
	  result, headers = LrHttp.post( url, '', httphead )
	  if headers.status == 200 then
		success = true
		Log('Wrote Meta to Rest: ' .. url)
	  end
	else
	  success = true
	  Log('No Meta to update: ' .. url)
	end
  
	return success
  
end
 
-- REST JSON array with keys
function ExtractDataFromREST( restdata )
	-- aus einer REST-Antwort zu einer Datei die Daten für customMetadata extrahieren
	-- Parameter restdata: JSON-Format der REST-Antwort. liefert array zurück
	local i = 1
	local result = {} 
	result[i] = restdata
	local row = {}
	local lrid, fname, n
  
	local str = inspect(result[i]) -- JSON-Rückgabe für ein Image in str umwandeln
	local ii,j = string.find(str,'original_image') -- den vollen Filename suchen
	if ii ~= nil then
	  fname = result[i].media_details.original_image
	else
	  fname = result[i].media_details.file
	  fname = getfile(fname)
	  fname, n = fname:gsub('-scaled','')
	end
	
	local function findTextinHTML( html )
	  -- find text in HTML-Tag from REST-Api-Data
	  -- Parameter: html : string
	  local w1, w2, text
	  w1, w2 = string.find(html, '<p>.*</p>')
	  if w1 ~=nil and w2 ~= nil then
		text = string.sub(html,w1+3,w2-4)
	  else
		text = ''
	  end
	  return text
	end
  
	local _descr = result[i].description.rendered  
	_descr = findTextinHTML(_descr)
  
	local _caption = result[i].caption.rendered
	_caption = findTextinHTML(_caption)
  
	row = {lrid = {}, id = result[i].id, 
					  upldate = result[i].date, 
					  width = result[i].media_details.width, 
					  height = result[i].media_details.height, 
					  slug = result[i].slug, 
					  post = result[i].post, 
					  gallery = result[i].gallery, 
					  phurl = result[i].source_url, 
					  filen = fname,
					  datemod = result[i].modified, 
					  title = result[i].title.rendered,
					  descr = _descr,  
					  caption = _caption,
					  alt  = result[i].alt_text, 
					  origfile = fname, 
					  MD5 =  result[i].md5_original_file,
		  } 
   
	return row
end
  
-- Write extracted Rest-meta-Data to customMetadata in Lightroom Catalog
function WriteCustomMetaData( publishSettings, photo, restmetadata )
	 -- Achung: muss innerhalb von catalog:withWriteAccessDo('unique-ID', function () ... end) aufgerufen werden
	LrMobdebug.on()
	local i = 1
	local foundph = {}
	foundph[i] =  restmetadata
  
	local date = tostring(foundph[i].upldate)
	date = iso8601ToTime(date)
	local dateday = LrDate.formatShortDate(date)
	local datetime = LrDate.formatMediumTime( date )
	local url = publishSettings['siteURL'] or publishSettings.siteURL
	
	photo:setPropertyForPlugin( _PLUGIN, 'wpid', tostring(foundph[i].id) )
	photo:setPropertyForPlugin( _PLUGIN,'upldate', dateday .. " / " .. datetime)
	photo:setPropertyForPlugin( _PLUGIN,'wpwidth', tostring(foundph[i].width))
	photo:setPropertyForPlugin( _PLUGIN,'wpheight', tostring(foundph[i].height))
	photo:setPropertyForPlugin( _PLUGIN,'slug', tostring(foundph[i].slug))
	photo:setPropertyForPlugin( _PLUGIN,'gallery', tostring(foundph[i].gallery) )
  
	if mytonumber(foundph[i].post) ~= 'nil' then
	  photo:setPropertyForPlugin( _PLUGIN,'post', url .. "/?p=" .. tostring(foundph[i].post)) -- 
	else
	  photo:setPropertyForPlugin( _PLUGIN,'post', '')
	end
  
	--photo:setPropertyForPlugin( _PLUGIN,'wpimgurl', tostring(foundph[i].phurl))
	-- set to: http://127.0.0.1/wordpress/wp-admin/post.php?post=4522&action=edit
	--                https://www.mvb1.de/wp-admin/post.php?post=4884&action=edit
	url = url .. '/wp-admin/post.php?post=' .. tostring(foundph[i].id) .. '&action=edit'
	photo:setPropertyForPlugin( _PLUGIN,'wpimgurl', url )
end
  
  -- Add Media File to WP-Media-Catalog via REST-API
function AddNewMedia( publishSettings, filename, path, defaultcoll, folder ) 
	-- Folgende Annahmen: Nach dem ersten SYNC wird mit WP nicht mehr im Media-Cat gearbeitet. NIE!
	-- Auch mit FTP wird nicht mehr hochgeladen. NIE!
	-- Nur dann, KANN es keine Dateien geben, die zwar im Folder sind aber noch nicht in WP sind oder LR nicht zugeordnet wurden, d.h. WP und LR sind dann immer synchron.
	-- Wenn das geünscht wird, muss im WP-Plugin die Funktion bei der Route 'addtofolder' erweitert werden
	-- Bei GET: Liefert alle WPIDs zu allen Original-Files im Folder. Zusätzlich werden alle Dateien, die nicht in WP sind gelistet als eigener Key in der REST-Antwort
	-- Bei POST mit addtofolder, wird mit dem JPG-Body das WP-Bild mit WPID entweder updated oder ohne WPID die bestehende JPG-Datei überschrieben und dann zu WP ergänzt
	-- In beiden Fällen bei POST wird die WPID als ID zurückgeliefert und der Ablauf in LR-LUA in dieser Funktion kann gleichbleiben! 
	LrMobdebug.on()
	local hash = 'Basic ' .. publishSettings['hash']
	local filen = filename
	local wpid = 0
	local restData = {}
	local url = ''
	local httphead
  
	if publishSettings == {} or publishSettings['hash'] == '' or publishSettings['siteURL'] == '' or filename == '' or path == '' then
	  wpid = 'Internal: Wrong function call of AddNewMedia. Parameter mismatch'
	  return wpid, restData
	end
  
	local imgfile = LrFileUtils.readFile(path) -- Rückgabe als String!
  
	-- Differ between Standard-Collection for the WP-Standard-Cat or another folder in the WP uploads-directory. This is a gallery = collection in LR
	if defaultcoll then  
	  url = publishSettings['siteURL'] .. "/wp-json/wp/v2/media/"
	  httphead = {
		{field='Authorization', value=hash},
		{field='Content-Disposition', value='form-data; filename="' .. filen .. '"'},
		{field='Content-Type', value='image/jpeg'},
	  }
	elseif folder ~= '' then
	  --Header-Wert: Content-Disposition = attachment; filename=example.jpg OHNE Anführungszeichen!
	  url = publishSettings['siteURL'] .. "/wp-json/wpcat/v1/addtofolder/" .. folder
	  httphead = {
		{field='Authorization', value=hash},
		{field='Content-Disposition', value='attachment; filename=' .. filen},
		{field='Content-Type', value='image/jpeg'},
	  }
	else
	  wpid = 'Internal: Wrong function call of AddNewMedia. Parameter mismatch'
	  return wpid, restData
	end
  
	-- Create the image in Wordpress via REST-API according to the above settings
	local result, headers = LrHttp.post( url, imgfile, httphead )
	result = JSON:decode(result)
  
	-- Extract data from the Response to the Create-Request
	  if headers.status == 201 then -- Antwort aus REST bei default-collection mit "/wp-json/wp/v2/media/"
		wpid = tonumber(result['id'])
		restData = ExtractDataFromREST(result)
  
	elseif headers.status == 200 then -- Antwort auf wp-plugin wpcat_json_rest mit "/wp-json/wpcat/v1/addtofolder/"
		wpid = tonumber(result['id'])
		local url = publishSettings['siteURL'] .. "/wp-json/wp/v2/media/" .. tostring(wpid)
		Log("Anfrage des neuen Bildes über Standard-REST: ", url)
		local httphead = {
		  {field='Authorization', value=hash}        
		}
		local result, headers = LrHttp.get( url, httphead )
		result = JSON:decode(result)
		restData = ExtractDataFromREST(result)
  
	else
		wpid = 'Upload: Fault during upload to WP: ' .. filen .. '.\nHeader-Status: ' .. tostring(headers.status) .. '\nMessage: ' .. result['message']
	end
  
	Log('Added Media: ', wpid)
	return wpid, restData
  end
  
-- Update Media File to WP-Media-Catalog via REST-API
function UpdateMedia( publishSettings, filename, path, wpid ) 
	local hash = 'Basic ' .. publishSettings['hash']
	local filen = filename
	local restData = {}
  
	if publishSettings == {} or publishSettings['hash'] == '' or publishSettings['siteURL'] == '' or filename == '' or path == '' then
	  return
	end
  
	local httphead = {
		{field='Authorization', value=hash},
		{field='Content-Disposition', value='form-data; filename=' .. filen },
		{field='Content-Type', value='image/jpeg'},
	}
  
	local imgfile = LrFileUtils.readFile(path) -- Rückgabe als String!
	  
	local url = publishSettings['siteURL'] .. "/wp-json/wpcat/v1/update/" .. tostring(wpid)
	  
	local result, headers = LrHttp.post( url, imgfile, httphead )
  
	if headers.status == 200 then
		result = JSON:decode(result)
		--wpid = tonumber(result['id'])
		--restData = ExtractDataFromREST(result)
	else
		  wpid = 'Fault: ' .. tostring(headers.status .. ' : ' .. filen)
	end
	
	return wpid, result
end
  
-- Get all Media Files / one Medie File from WP-Media-Catalog via REST-API. Provide response as JSON
-- TODO : Authorization-Auswahl im Menu mit Vorauswahl im Dropdown, OAuth2-Plugin mit base64 verwenden, hash nach LR kopieren
function GetMedia( publishSettings, perpage, page ) 
	local result = nil
	if publishSettings == {} or publishSettings == nil then
	  return result
	end
  
	local _hash = publishSettings.hash or publishSettings['hash']
	local _siteURL = publishSettings.siteURL or publishSettings['siteURL'] 
  
	local hash = 'Basic ' .. _hash
	local url = '' 
	  local httphead = {
		{field='Authorization', value=hash},
	  }
	 
	if tonumber(perpage) ~= nil and tonumber(page) ~= nil then
		  url = _siteURL .. "/wp-json/wp/v2/media/?per_page=" .. perpage .. '&page=' .. page
	elseif tonumber(perpage) > 0 and tonumber(page) == nil then
	  url = _siteURL .. "/wp-json/wp/v2/media/" .. perpage
	else  
		  url = _siteURL .. "/wp-json/wp/v2/media/"
	  end
	 
	  local result, headers = LrHttp.get( url, httphead )
  
	  if headers.status == 200 then
		  result = JSON:decode(result)
	 end
	
	return result
  end
  
  -- Delete Media Files from WP-Media-Catalog via REST-API
  function DeleteMedia( publishSettings, wpmediaid ) 
	local result = false
	local idcheck = type(tonumber(wpmediaid))
	if publishSettings == {} or publishSettings.hash == '' or publishSettings.siteURL == '' or idcheck ~= 'number' then
	  return result
	end
  
	local hash = 'Basic ' .. publishSettings.hash
	  local httphead = {
		{field='Authorization', value=hash},
	  }
	local url = ''  
	
	  url = publishSettings.siteURL .. "/wp-json/wp/v2/media/" .. tostring(wpmediaid) .. "?force=1"
	--http://127.0.0.1/wordpress/wp-json/wp/v2/media/3439?force=1
	--http-methode: delete   
	  local result, headers = LrHttp.post( url, '', httphead, 'Delete' )
  
	  if headers.status == 200 then
		result = JSON:decode(result)
		result = result['deleted']
	elseif headers.status == 404 then -- also successful, id is not available
		result = JSON:decode(result)
		result = result['code']
	end
	
	return result
end
  
-- Serch pre-selected Images in LR Database, exclude Copies, marked by "Kopie.."
-- special selection if more then on photo found. Selector: "Rot"
-- This runs as asynchronous Task! Main Task has to wait. No Signalling between Tasks.
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

-- Update image_meta keys of Media File to WP-Media-Catalog via REST-API
--[[
	{
		"image_meta": {
					"credit": "Martin von Berg",
					"caption": "TEst-caption",
					"copyright": "Copyright by Martin von Berg",
					"title": "Auffahrt zum Vallone d`Urtier",
					"keywords": [
						"Aosta",
						"Aostatal",
						"Berge",
						"Bike",
						"Italien",
						"Sommer",
						"Wald",
						"Wiese",
						"forest",
						"italy",
						"lärche",
						"meadow",
						"mountains",
						"summer"
					]
	}
}
]]
function UpdateKeys( publishSettings, photometa, wpid ) 
	local hash = 'Basic ' .. publishSettings['hash']
	local restData = {}
  
	if publishSettings == {} or publishSettings['hash'] == '' or publishSettings['siteURL'] == '' then
	  return
	end
  
	local httphead = {
		{field='Authorization', value=hash},
		{field='Content-Type', value='application/json'},
	}
  
  restData['image_meta'] = photometa
	local image_meta = JSON:encode(photometa)
  
	  
	local url = publishSettings['siteURL'] .. "/wp-json/wpcat/v1/update_meta/" .. tostring(wpid)
	  
	local result, headers = LrHttp.post( url, image_meta, httphead )
  
	if headers.status == 200 then
		result = JSON:decode(result)
		--wpid = tonumber(result['id'])
		--restData = ExtractDataFromREST(result)
	else
		  wpid = 'Fault: ' .. tostring(headers.status .. ' : ' .. filen)
	end
	
	return wpid, result
end

return exportServiceProvider
