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
local LrSelection = import 'LrSelection'
local LrSystemInfo = import 'LrSystemInfo'


local mypluginID = 'com.adobe.lightroom.export.wp_mediacat2' -- TODO: durch variable ersetzen
local catoutdate = 2 -- max. allowd age of lrcat-copy in days
local HDDwritespeed = 100 -- in MBytes / s
local WPCatColl = 'WPCat'

----- Debug -----------
--logDebug = false
require 'strict'
require 'Logger'
local DebugSync = false
local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
LrMobdebug.start()
local inspect = require 'inspect'
----- Debug -----------

JSON=require 'JSON'
require 'Dialogs'
require 'helpers'
require 'functions'

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
exportServiceProvider.titleForGoToPublishedPhoto = 'Copy Wordpress-Code to Clip' --or 'Go to Foto in WP Catalog'
exportServiceProvider.disableRenamePublishedCollection = true -- benennt die Sammlung im Dienst um, erzeugt damit einen neuen Ordner
exportServiceProvider.disableRenamePublishedCollectionSet = true -- benennt den ganzen Dienst um
------------ exportServiceProvider ----------------------------

-- this function is only called AFTER publishing AND if custum sort order is selected AND if supportsCustomSortOrder = true
-- So, after the custum sorting at least one photo has to be re-published to have this sort order written to WP.
function exportServiceProvider.imposeSortOrderOnPublishedCollection( publishSettings, info, remoteIdSequence )
   Log('impose Sort aufgerufen')
   local str = inspect(remoteIdSequence)
   Log('Sequence: ', str)
   local success = false 
   local wpid
   local photoMeta = {}

   for i=1, #remoteIdSequence do -- i = Sort order
    wpid = tonumber(string.match( remoteIdSequence[i] , '%d+')) -- wpid als string
    Log('ID: ', wpid)
    photoMeta = {
      sortorder = i,
    }
    success = WritephotoMetaToWp( publishSettings, wpid, photoMeta )
   end

   if not success then
    LrDialogs.message('Could not write custom Sort-Order to Wordpress for ID: ' .. wpid ,'','info')
   end

end

-- publish Photos -- processRenderedPhotos -- main functon for updating and uploading photos to WP  
function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )
  Log('processRenderedPhotos aufgerufen')
  LrMobdebug.on()

  local exportSession = exportContext.exportSession
  local exportSettings = exportContext.propertyTable
  local catalog = LrApplication.activeCatalog()
	local nPhotos = exportSession:countRenditions()
  local pseudoPublishSettings = exportSettings['< contents >']
  local folder = exportContext.publishedCollectionInfo.name
  local parents = exportContext.publishedCollectionInfo.parents
  local defaultcoll = exportContext.publishedCollectionInfo.isDefaultCollection
  local renderedPhoto = {}
  local notuploaded = {}
  local countnotuploaded = 0

  local progressScope = exportContext:configureProgress {
    title = nPhotos > 1
    and LOC("$$$/PhotoDeck/ProcessRenderedPhotos/Progress=Publishing ^1 photos to PhotoDeck", nPhotos)
    or LOC "$$$/PhotoDeck/ProcessRenderedPhotos/Progress/One=Publishing one photo to PhotoDeck", -- laut LR SDK Handbuch wird dieser Titel bei Publish nicht angezeigt
  }
  
  -- Create nested foldername from parents of collection sets
  for i=#parents,1,-1 do
    local par = parents[i].name
    folder = par .. '/' .. folder
  end
  
  -- Check Gallery-Name again, skip render if wrong name (do not remove! This is necessary)
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
        --sortorder = i,
      }

      -- get REST-Meta-Data
      data = GetMedia(pseudoPublishSettings, wpid)  -- data = nil if wpid invalid or = 0
      data = ExtractDataFromREST(data)              -- data = {} if data-in = nil. Used: filen, gallery, MD5
      
      -- get Filenames, dimensions and size
      local filename = LrPathUtils.leafName( pathOrMessage ) -- LrPathUtils.leafname( pathOrMessage ) liefert auch den Dateinamen, hier aber filename für WP-Mediacat
      local renditionFilePath = LrPathUtils.standardizePath( pathOrMessage ) -- Der Anhang -scaled wird von WP automatisch ergänzt
      local dimensions = LrPhotoInfo.fileAttributes( renditionFilePath ) -- table: width, height
      local rendFileSize = mytonumber(LrFileUtils.fileAttributes( renditionFilePath )['fileSize'])
      local validPhoto = data.filen == filename
      
      
      -- check the manually created virtual copy and reset metadata if ok
      if validPhoto and ((folder ~= data.gallery) or (folder == WPCatColl and data.gallery ~= '')) then
        local isVirtCopy = photo:getRawMetadata('isVirtualCopy') -- bool
        local pubColl = photo:getContainedPublishedCollections()
       
        if isVirtCopy and #pubColl == 1 then
          wpid = 0
          photoMeta['gallery'] = ''
          ResetCustomMeta( photo )
          local name = 'Copy of ' .. filename
          catalog:withWriteAccessDo( 'SetCopyName', function ()
            photo:setRawMetadata( 'copyName', name )
          end)
        end
      
      end
      
      -- Feset Metadata if the photo is not valid, meaning the filenames does not match
      if not validPhoto then
        wpid = 0
        photoMeta['gallery'] = ''
        ResetCustomMeta( photo )
      end
      
      -- update photo (wpid > 0) or upload new photo (wpid == 0) or skip and count number for the final message
      if tonumber(wpid) > 0 and validPhoto and ((folder == data.gallery) or (folder == WPCatColl and data.gallery == '')) then -- update image or create virtual copy if existing  
          if progressScope:isCanceled() then progressScope:cancel() end 
          Log('-----------------------------------------------------------')
          Log('WPId :' .. wpid .. ' found in Meta. Now updating')
          Log('Updating File: ' .. filename .. ' to WP')
          Log('Rendition-Datei: ' .. renditionFilePath)
          Log('Folder = Gallery: ' .. folder .. ' : ' .. data.gallery)
          Log('Size: ' .. data.MD5.size .. ' : ' .. rendFileSize)
                  
          if mytonumber(data.MD5.size) == rendFileSize then
            -- update keywords only (tritt vermutlich nie ein, da bei LR die rendition immer eine andere MD5-Summe hat)
            Log('    Files identical')
            result = 'none'
            result, data = UpdateKeys( pseudoPublishSettings, photoMeta, wpid )
          else
            -- update photo including keywords
            result = 'none'
            result, data = UpdateMedia( pseudoPublishSettings, filename, renditionFilePath, wpid )
          end
        
          -- Prüfung auf Identität. wenn hier Änderung in der Logik, dann auch in Funktion WritephotoMetaToWp ändern!
          if data['title'] == photoMeta['title'] and (data['caption'] == photoMeta['title']) then -- title und caption = title
            photoMeta['title'] = '' 
          end 

          if (data['alt'] == photoMeta['caption']) and (data['descr'] == photoMeta['caption'])   then --alt und descr = caption
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
            --photo:setPropertyForPlugin( _PLUGIN,'order', tostring(i) )
          end )

          renderedPhoto[i] = {}
          renderedPhoto[i][1] = photo
          renderedPhoto[i][2] = ImageID -- remoteID
          renderedPhoto[i][3] = exportContext.publishedCollection.localIdentifier
          rendition:recordPublishedPhotoId( ImageID )
          rendition:recordPublishedPhotoUrl(tostring(exportContext.publishedCollection.localIdentifier))
              
      elseif tonumber(wpid) == 0 then -- add new image to WP Media Catalog
          if progressScope:isCanceled() then progressScope:cancel() end 
          Log(i ..' Adding File: ' .. filename .. ' to WP')
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
              --photo:setPropertyForPlugin( _PLUGIN,'order', tostring(i) )
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
      elseif validPhoto and ((folder ~= data.gallery) or (folder == WPCatColl and data.gallery ~= '')) then
          -- do nothing skip
          countnotuploaded = countnotuploaded + 1
          notuploaded[countnotuploaded] = filename
      end
            
    end
    -- delete temp file. There is a cleanup step that happens later, but this will help manage space in the event of a large upload.
		LrFileUtils.delete( pathOrMessage )
    
  end -- for rendition

  progressScope:done()
  if #notuploaded > 0 then
    LrDialogs.message('Could not upload images!', 'Some images were already uploaded to other collections. \nProposal: Remove from this collection.', 'warning')
  end

  -- Set the edited flag as sometimes it is reset by the pscope afterwards. Don't know why this happens
  local publishedPhotos = {}
  if #renderedPhoto > 0 then
    local publishedCollection = LrApplication.activeCatalog():getPublishedCollectionByLocalIdentifier(tonumber(renderedPhoto[1][3])) -- Es wird immer nur aus einer Collection aktualisert
    publishedPhotos = publishedCollection:getPublishedPhotos()
  end

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
  ------------------------ End set edited flag

end

-- called if somebody wants to move a published collection. This is not allowed. Delete first, create new collection and publish this one.
function exportServiceProvider.reparentPublishedCollection( publishSettings, info )
  Log('reparentPublishedCollection aufgerufen')
  error( '\nWarning: Function to move Collections not provided.\nPlugin works correctly. Don\'t worry.\nHowto:\n -Create New Collection and move photos manually. \n -Delete the collection you wanted to move then publish the new collection' )
end

-- Sync with Wordpress: exportServiceProvider.titleForGoToPublishedCollection = 'Sync with Wordpress'
function exportServiceProvider.goToPublishedCollection( publishSettings, info )
  LrMobdebug.on()
  Log('goToPublishedCollection aufgerufen (Sync with Wordpress)')
  local collection = info.publishedCollection
  local pubService = info.publishService
  local catalog = LrApplication.activeCatalog()
  local nphotos = collection:getPhotos() -- array of LrPhoto
  local firstsync = false
  local result
  local mediatable = {}
  local len = 0
  local perpage -- Anzahl der Media-Einträge per REST-Abfrage
  local getmore = true
  local runs = 0

  -- Pfad für die Kopie von lrcat definieren
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

  -- wenn nicht, dann Katalog kopieren
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
    perpage = 50 -- Anzahl der Media-Einträge per REST-Abfrage
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
  local paths = {}
  local npaths = 1
  local sub
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
      if pscope:isCanceled() then pscope:cancel() end 

      -- Collection und CollectionSet bestimmen
      local path = mediatable[i].phurl
      local pathlist = strsplit(path, '/' )
      local uploadindex = findValueInArray (pathlist, 'uploads')
      sub =''
      for c=uploadindex+1, #pathlist-1 do -- hier wird immer nur ein pfad durchsucht
        sub = sub .. pathlist[c] .. '/'
      end
      
      if #filen > 3 then
      -- suche mit Dateiname aus WP 
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
      lrid = nil -- debug
      if lrid ~=nil then
        foundph[nfound] = mediatable[i] 
        searchDesc[nfound] = { criteria = "filename", operation = "==", value = filen, }
        nfound = nfound +1
      else
        notfound[nnotfound] = mediatable[i]
        nnotfound = nnotfound +1
      end
      if pscope:isCanceled() then pscope:cancel() end
      pscope:setPortionComplete(0.2 + i * pscopeadd)

      if findValueInArray(paths, sub) == 0 then
        local wpcatsub = string.match(sub, '%d%d%d%d/%d%d')
        if wpcatsub == nil then
          paths[npaths] = sub
          npaths = npaths +1
        end
      end
  end

  -- Gefundene Pfade in paths zu collectionSets und Collections verarbeiten
  local str = inspect(paths)
  Log(paths)
  for m=1, #paths-1 do 
    local collections = strsplit(paths[m], '/' )
    local coll = collections[1]
    Log(coll)
    catalog:withWriteAccessDo( 'CreateFirstLevel', function ()
      local a = 1
      local exist = pubService:createPublishedCollectionSet( coll, nil, true )
      Log( inspect(exist))
    end)
  end

  if pscope:isCanceled() then pscope:cancel() end
  pscope:setPortionComplete(0.65)
  
  -- Im Katalog gefundene Fotos zur Collection hinzufügen. Weitere Einschränkung bei mehrfach gefundenden Photos
  addToWPColl(collection, searchDesc, foundph) 
  ------------------------------------------------------------------------

  LrDialogs.message ( string.format("Added %d Photos to WordPress-Media-Catalog.", nfound-1),'','info')
  pscope:setPortionComplete(0.8)
  if pscope:isCanceled() then pscope:cancel() end
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

-- function called if Right-Click on photo and titleForGoToPublishedPhoto = 'Copy Wordpress-Code to Clip' is selected
-- creates code for WP and copies it to the clipboard. It is not possible to copy the code out of the message window!
function exportServiceProvider.goToPublishedPhoto( publishSettings, info )
  local photo = info.photo -- Type LrPhoto
  local wpid = photo:getPropertyForPlugin( mypluginID, 'wpid' )
  local alt = photo:getFormattedMetadata( 'caption' )
  local message = 'Code for this Photo to add to a Wordpress-Blog:'
  local message2 = 'Copy and add to your blog ' .. wpid
  local folder = info.publishedCollectionInfo.name 
  local parents = info.publishedCollectionInfo.parents
  local srcurl = '' -- https://www.mvb1.de/smrtzl/uploads/2020/10/Bike-Hike-Lago-Ischiator-35-scaled.jpg

  -- get REST-Meta-Data
  local data = GetMedia(publishSettings, wpid)  -- data = nil if wpid invalid or = 0
  data = ExtractDataFromREST(data)              -- data = {} if data-in = nil
  srcurl = data.phurl

  local os = LrSystemInfo.osVersion()
  local ii,j = string.find(os,'indows') -- den vollen Filename suchen
  if ii ~= nil then
    os = 'WIN'
  end
  
  -- Create nested folder name from parents of collection sets
  for i=#parents,1,-1 do
    local par = parents[i].name
    folder = par .. '/' .. folder
  end

  local wpgall = '[gpxview imgpath="' .. folder .. '" gpxfile=".." alttext="Bildergalerie mit Karte, GPX-Track und Höhenprofil "]'
  local wpimage ='<!-- wp:image {"align":"center","id":'.. wpid .. ',"sizeSlug":"full","linkDestination":"none"} --> <div class="wp-block-image"><figure class="aligncenter size-full"><img src="'.. srcurl ..'" alt="'.. alt ..'" class="wp-image-'.. wpid ..'"/><figcaption>' .. alt .. '</figcaption></figure></div><!-- /wp:image -->'
  local wp = wpgall .. '    ' .. wpimage
  local copyCmd = "echo '".. wp .."' | pbcopy" -- MAC

  if os == "WIN" then
         copyCmd = 'Echo '.. '"'.. wp.. '"' .. ' | clip'
  end

  LrTasks.execute(copyCmd)
  --LrDialogs.message(message2, wp, 'info')

  -------------- colltest-----------------
  local pubService = info.publishService
  local catalog = LrApplication.activeCatalog()
  local paths = {}
  local npaths = 1
  local sub
  local name = pubService:getName()
  Log(name)
  local psid = pubService:getPluginId()
  Log(psid)
  local Level1 = {}

  -- Gefundene Pfade in paths zu collectionSets und Collections verarbeiten
  paths = {"Gallerie/Sync1/","Gallerie/Sync2/","Test1/","Test2/a1/", "Test2/a2/", "Foto_Albums/Franken-Dennenlohe/","Albums/","Foto_Albums/Bike-Hike-Col-de-Peas/","Neu/",""}
  local str = inspect(paths)
  Log(paths)
  for m=1, #paths-1 do 
    local collections = strsplit(paths[m], '/' )
    local ncollections = #collections-1
    -- first Level
    --local level = 1
    local collparent = nil
    Level1[m] = {}
    local result

    for level=1, ncollections do
      local coll = collections[level]
      Log(coll)
     
      if level < ncollections then
        catalog:withWriteAccessDo( 'Create1stLevel', function ()
          result = pubService:createPublishedCollectionSet( coll, collparent, true) -- Ergebnis kann nicht übergeben werden, führt zu Fehler!
        end)
        -- set this to parent -- Fehl Suche in vorhandenen, ob die Coll bereits vorhanden ist
        collparent = result
      elseif level == ncollections then
        catalog:withWriteAccessDo( 'Create1stLevel', function ()
          result = pubService:createPublishedCollection( coll, collparent, true)
        end)
        
      end
    end

    Level1[m] = result
  end

  --[[
  Log('Adding to Collections')
  for m=1, #Level1 do
    local photos = {}
    photos[1] = photo
    local coll = Level1[m]
    Log(coll.type())
    catalog:withWriteAccessDo( 'AddOnePhoto', function ()
      Log('writeAccess')
      coll.addPhotos( photo )
    end)
    
  end  
  ]]
  
end

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
  -- is necessary to get the LRphoto object and not the publishedphoot
  local collection = catalog:getPublishedCollectionByLocalIdentifier(localCollectionId)
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

      ResetCustomMeta (photo)
      Log('WP-Media deleted: ' ..tostring(wpid) )
      
    end
    error_msg = 'fertig'
    
  end, error_msg )

  --LrTasks.sleep( 0.5 * #photoUnpublish)
  --Log('AsyncTask done', error_msg) 

  -- Remove the RemoteID
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
		maxCollectionSetDepth = 4,
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
    
    ResetCustomMeta (photo)
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

-- prüft den gerade erstellten Collection-Set-Name und löscht diesen falls falsch
-- funktioniert nur für den CollectionSet Name nicht für die ganze Hierarchie, daher muss in process rendered Photo nochmals geprüft werden
function exportServiceProvider.endDialogForCollectionSetSettings( publishSettings, info )
  LrMobdebug.on() 
  local folder = info.name 
  local collection = info.publishedCollectionSet
  local ok = false 
  local message = 'Problem'
  
  ok, message = checkfolder( folder )
  Log(folder)
  Log(ok)
  Log(message)
  
  if ok == false then
    LrDialogs.message ('Wrong Collection-Set Name: ' .. folder, 'Reason: ' .. message ..'.\nPlease delete the Collection-Set and create a new one with correct Name containing only a-z, A-Z, 0-9, / - and _ . The Collection Set must not be named like 2020/11 and must not start or end with slashes.','warning')
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

return exportServiceProvider

----------------------------- Ende Funktionen für PublishService -----------------------------------------------
