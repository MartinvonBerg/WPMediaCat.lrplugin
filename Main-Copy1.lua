--	Main entry point for plugin.
-- TODO: Translation of all strings
local LrDialogs = import 'LrDialogs'
local LrApplication = import( 'LrApplication' )
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrHttp = import 'LrHttp'
local LrDate = import 'LrDate'
local LrTasks = import 'LrTasks'
local LrProgressScope = import( 'LrProgressScope' )
local LrFunctionContext = import 'LrFunctionContext'
local LrPhotoInfo = import 'LrPhotoInfo'

---- Get sytem and Lightroom version information
--if WIN_ENV then
--  os = 'WIN'
--else
--  os = 'macOS'
--end
local version = LrApplication.versionTable()
local LRVmajor = version['major']
local LRVminor = version['minor']
local LRVrevis = version['revision']

----- Debug -----------
--logDebug = false
--require 'strict'
--require 'Logger'
--local DebugSync = false
--local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
--LrMobdebug.start()
--local inspect = require 'inspect'
----- Debug ------------
--LrMobdebug.on()

-- load and define external ressources
--JSON=require 'JSON'
require 'Dialogs'
require 'helpers'
require 'functions-Copy1'

local mypluginID = PiName 
local WPCatColl = 'WPCat'

------------ exportServiceProvider ----------------------------
exportServiceProvider = {}
exportServiceProvider.supportsIncrementalPublish = 'only'
exportServiceProvider.small_icon = "Small-icon.png"
exportServiceProvider.hideSections = { 'exportLocation', 'fileNaming' } -- exportLocation erzeugt den Reiter "Speicherort für Export", evtl. imageSettings ergänzen
exportServiceProvider.allowFileFormats = { 'JPEG' } 								
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
  { key = "wpplugin", default = false}, -- wird nur bei "Check Login" geprüft. Danach nicht mehr, wenn dann entfernt, dann keine Fehlermeldung
  { key = 'doLocalCopy', default = false},
  { key = 'localPath', default = 'D:\\WPcat'},
  { key = 'WPalt', default = {'LRcap'}},
  { key = 'LRcap', default = {'WPalt'}},
  { key = 'WPdescr', default = {'LRcap'}},
  { key = 'WPcap', default = {'LRtit'}},
  { key = 'preCopy', default = 'Copy-'},
  { key = 'firstSyncDoMetaOnly', default = true},
  { key = 'LrMeta_to_WP', default = false},
  { key = 'dowebp', default = false},
  { key = 'doCaption', default = false},
  { key = 'webpStatus', default = 'not tested yet'},
}
exportServiceProvider.titleForGoToPublishedCollection = LOC "$$$/WP_MediaCat2/only=Only" .. WPCatColl .. ' : ' .. LOC "$$$/WP_MediaCat2/FirstSync=First-Sync with WordPress"
exportServiceProvider.titleForGoToPublishedPhoto = LOC "$$$/WP_MediaCat2/CopyToClip=Copy Wordpress-Code to Clip" --or 'Go to Foto in WP Catalog'
exportServiceProvider.disableRenamePublishedCollection = true -- benennt die Sammlung im Dienst um, erzeugt damit einen neuen Ordner
exportServiceProvider.disableRenamePublishedCollectionSet = true -- benennt den ganzen Dienst um
------------ exportServiceProvider ----------------------------

-- this function is only called AFTER publishing AND if custum sort order is selected AND if supportsCustomSortOrder = true
-- So, after the custum sorting at least one photo has to be re-published to have this sort order written to WP.
-- wird auch nach dem Löschen aufgerufen!
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

   if not success and wpid ~= nil then
    LrDialogs.message('Could not write custom Sort-Order to Wordpress for ID: ' .. inspect(wpid) ,'','info')
   end

end

-- publish Photos -- processRenderedPhotos -- main functon for updating and uploading photos to WP  
function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )
  Log('processRenderedPhotos aufgerufen')
  --LrMobdebug.on()

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
  local dowebp = exportSettings.dowebp -- Achtung: Das wird mehrfach gesetzt

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

  -- Check Metadata match
  local LRcap = pseudoPublishSettings['LRcap'][1]
  local WPalt = pseudoPublishSettings['WPalt'][1]
	local WPdescr = pseudoPublishSettings['WPdescr'][1]
  local WPcap = pseudoPublishSettings['WPcap'][1]
  --[[
  local metaMatch = false
  -- TODO: Decide to provide a setting for 'strict metadata handling'. If so, this outcommented part has to run in strict mode.
  if ((LRcap == 'WPalt') and (WPalt == 'LRcap')) or ((LRcap == 'WPdescr') and (WPdescr == 'LRcap')) or ((LRcap == 'WPcap') and (WPcap == 'LRcap')) then 
    metaMatch = true
  else
    Log('MetaData mismatch')
    metaMatch = false
    LrDialogs.message ('Warning','Mismatch of MetaData Assignment! Check Export Settings! Upload is canceled!')
    progressScope:done()
    return 
  end 
  ]]

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
      }
      -- get the meta data for webp images 
      local WebpPhotoMeta = getWebpMetaData ( photo )
         

      -- get REST-Meta-Data
      data = GetMedia(pseudoPublishSettings, wpid)  -- data = nil if wpid invalid or = 0
      data = ExtractDataFromREST(data)              -- data = {} if data-in = nil. Used: filen, gallery, MD5
      
      -- get Filenames, dimensions and size
      local filename = LrPathUtils.leafName( pathOrMessage ) -- LrPathUtils.leafname( pathOrMessage ) liefert auch den Dateinamen, hier aber filename für WP-Mediacat
      local renditionFilePath = LrPathUtils.standardizePath( pathOrMessage ) -- Der Anhang -scaled wird von WP automatisch ergänzt
      local dimensions = LrPhotoInfo.fileAttributes( renditionFilePath ) -- table: width, height
      local rendFileSize = mytonumber(LrFileUtils.fileAttributes( renditionFilePath )['fileSize'])
      --local pathToOriginal = photo:getRawMetadata('path')

      -- check if photo is valid, with filename and copyname and regex for '_' and '-'
      local validPhoto = false
      local lrcopyname = photo:getFormattedMetadata( 'copyName' )

      local base4search = nil
      local result1 = nil
      local result2 = nil

      if data.filen ~= nil then
        local wpBaseFileName, ext = SplitFilename( data.filen ) -- wpfilename : data.filen
        base4search = '^' .. string.gsub( wpBaseFileName, "[-_]","[-_]") -- base : wordpress
      end

      -- Feature SafeMode: Es wird eine neue WPID erstellt, wenn filename und base4search NICHT übereinstimmen.
      -- Oder: Nur wenn die beiden übereinstimmen wird das Bild mit der bereits vergegbenen WPID aktualisiert.
      -- Die Umbennennung von Bildern NACH der Veröffentlichung ist damit nicht möglich.

      -- Feature OverWriteMode: Dateien können mit derselben WPID umbenannt werden. Es wird keine neuen WPID vergeben.
      -- Realisiert mit result2 = 'overwrite'

      if lrcopyname ~= nil and base4search ~= nil then
        result1 = string.match(lrcopyname, base4search) -- lrcopyname kann auch leer sein, d.h.nil. Das ist meistens der Fall --> result1 = nil
      end

      if base4search ~= nil then
        result2 = string.match(filename, base4search)
        -- OverWriteMode. TODO: Decide whether to provide a setting for that.
        -- SafeMode: Uncomment this line.
        result2 = 'overwrite' -- will force validPhoto to true
      end 

      if result1 ~= nil or result2 ~= nil then
        validPhoto = true -- Foto mit diesem Dateinamen existiert unter dieser wpid. Vergleichsergebnis wird gleich zugewiesen
      end    
      
      -- check the manually created NEW virtual copy, reset Custom-metadata and set CopyName if ok
      -- filenames are OK but foldernames and gallery-names do not match
      local isVirtCopy = photo:getRawMetadata('isVirtualCopy') -- bool
      local pubColl = photo:getContainedPublishedCollections()
               
      if validPhoto and isVirtCopy and #pubColl == 1 and rendition.publishedPhotoId == nil and result1 == nil then -- recordPublishedPhotoId( ImageID ) ist hier auch noch leer
        wpid = 0
        photoMeta['gallery'] = ''
        ResetCustomMeta( photo )
        --local name = 'Copy of ' .. filename
        local lrcopyname = photo:getFormattedMetadata( 'copyName' )
        lrcopyname = string.gsub( lrcopyname, ' ', '-')
        local name = lrcopyname .. '-' .. filename
        catalog:withWriteAccessDo( 'SetCopyName', function ()
          photo:setRawMetadata( 'copyName', name )
        end)
        filename = name -- Namen der virt. Kopie verwenden!
      end
      
      
      -- Reset Metadata if the photo is not valid, meaning the filenames do not match --> Force generation of new photo in WP-media-cat. Never overwrite
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

          local firstSync = rendition.publishedPhotoId == nil --boolean
          local firstSyncDoMetaOnly = pseudoPublishSettings['firstSyncDoMetaOnly'] -- false: image-files in WP will be updated at firstSync
          local LrMeta_to_WP = pseudoPublishSettings['LrMeta_to_WP'] -- true: LR --> WP || false WP --> LR for Metadata only at firstSync
          
          -- bei firstsync Daten in LR mit WP-Daten überschreiben und WP nicht verändern!
          if not firstSync then

            if mytonumber(data.MD5.size) == rendFileSize then 
              -- update keywords only if filesizes are identical
              Log('    Files identical')
              result = 'none'
              result, data = UpdateKeys( pseudoPublishSettings, photoMeta, wpid )
            else
              -- update photo including keywords. This is always the case for webp-images
              result = 'none'
              result, data = UpdateMedia( pseudoPublishSettings, filename, renditionFilePath, wpid )
              
              if dowebp then
                UpdateKeys( pseudoPublishSettings, WebpPhotoMeta, wpid )
              end
              
              -- write WP-dimensions of image to Custom-Metadata. 
              catalog:withWriteAccessDo( 'UpdateDimension', function ()
                photo:setPropertyForPlugin( _PLUGIN,'wpwidth', tostring(dimensions['width']) )
                photo:setPropertyForPlugin( _PLUGIN,'wpheight', tostring(dimensions['height']) )
              end )
            end
                 
            -- Prüfung auf Identität. wenn hier Änderung in der Logik, dann auch in Funktion WritephotoMetaToWp ändern!
            -- wenn gleich, dann leeren String setzen --> Es wird dann nichts geändert: geht nich mehr bei variabler zuweisung, zu viele Abhängigkeiten
            --if data['title'] == photoMeta['title'] then photoMeta['title'] = '' end 

            --if (data['alt'] == photoMeta['caption']) and (data['descr'] == photoMeta['caption'])   then --alt und descr = caption
            --  photoMeta['caption'] = '' 
            --end
            if data['gallery'] == photoMeta['gallery'] then photoMeta['gallery'] = '' end
          
            local success = WritephotoMetaToWp( pseudoPublishSettings, tonumber(wpid), photoMeta )
            if success then
              Log('WpId :' .. wpid .. ' REST-Meta was updated')
              ImageID  = 'WPSync' .. tostring(wpid) -- published before?  -- set to wpid
            else
              ImageID = '' -- photo wird als unpublished gesetzt
            end
          --------------- firstSync ----------------------------------  
          elseif firstSync then

            if firstSyncDoMetaOnly then 
              -- It is intentional that nothing happens here. Just here to avoid confusion why the if-then-else is not complete.
            else
              -- update photo including keywords
              result = 'none'
              result, data = UpdateMedia( pseudoPublishSettings, filename, renditionFilePath, wpid )
              -- write WP-dimensions of image to Custom-Metadata. 
              catalog:withWriteAccessDo( 'UpdateDimension', function ()
                photo:setPropertyForPlugin( _PLUGIN,'wpwidth', tostring(dimensions['width']) )
                photo:setPropertyForPlugin( _PLUGIN,'wpheight', tostring(dimensions['height']) )
              end )
            end

            -- MetaData is always synchronized independet of firstSyncDoMetaOnly
            if LrMeta_to_WP then
              -- Meta: LR --> WP at firstSync 
              WritephotoMetaToWp( pseudoPublishSettings, wpid, photoMeta )
              result, data = UpdateKeys( pseudoPublishSettings, photoMeta, wpid )
            else 
              -- Meta: WP --> LR  : WP-data is in variable 'data'.
              -- Only done for titel and caption. Nothing more.
              -- Mind this could be quite anoying if WP data is empty! If so, all titles and captions will be deleted in LR. So, to use with care!
              -- TODO: Decide whether to handle keywords also. 
              -- Check propertyTable selection for LRcap 
              local value = photo:getFormattedMetadata( 'caption' ) --fallback if the following does not provide a value
              if LRcap == 'WPalt'  then 
                value = data.alt
              elseif LRcap == 'WPdescr' then
                value = data.descr
              elseif LRcap == 'WPcap' then
                value = data.caption
              end

              -- sanitize the values ot have empty fields if WP values are empty and not 'nil'
              if value == nil or value == 'nil' then value = '' end
              if data.title == nil or data.title == 'nil' then data.title = '' end

              catalog:withWriteAccessDo( 'SetLRMetaData', function ()
                photo:setRawMetadata( 'title', data.title )
                photo:setRawMetadata( 'caption', value ) 
              end )

            end
            ImageID  = 'WPSync' .. tostring(wpid) 
          end
          
          renderedPhoto[i] = {}
          renderedPhoto[i][1] = photo
          renderedPhoto[i][2] = ImageID -- remoteID
          renderedPhoto[i][3] = exportContext.publishedCollection.localIdentifier
          rendition:recordPublishedPhotoId( ImageID )  
          rendition:recordPublishedPhotoUrl(tostring(exportContext.publishedCollection.localIdentifier))
              
      elseif tonumber(wpid) == 0 then -- add new image to WP Media Catalog
          if progressScope:isCanceled() then progressScope:cancel() end 
          Log('Photo ' .. i ..': Adding File: ' .. filename .. ' to WP')
          Log('Rendition-Datei: ' .. renditionFilePath)
          Log('Folder: ' .. folder)
          Log('Collec: ' .. tostring(defaultcoll) )
          
          local result = 'none'
          result, data = AddNewMedia( pseudoPublishSettings, filename, renditionFilePath, defaultcoll, folder ) -- Einschränkungen siehe dort!
          
          if type(result) == 'number' then
            ImageID  = 'WPSync' .. tostring(result) -- set to wpid --diese Nummer muss eineindeutig sein!
            -- fehlende LR-Metadaten in den WP Katalog schreiben
            WritephotoMetaToWp( pseudoPublishSettings, result, photoMeta )
            -- mit UpdateKeys die Metadaten für webp-Bilder ergänzen
            if dowebp then
               UpdateKeys( pseudoPublishSettings, WebpPhotoMeta, result )
            end
            -- Custom-Metadaten in WP-Katalog schreiben: Rest-Antwort-Daten in CustomMeta schreiben
            catalog:withWriteAccessDo( 'AddMetaData', function ()
              WriteCustomMetaData( pseudoPublishSettings, photo, data )
              --photo:setPropertyForPlugin( _PLUGIN,'order', tostring(i) )
            end )

            renderedPhoto[i] = {}
            renderedPhoto[i][1] = photo   -- catalog photo
            renderedPhoto[i][2] = ImageID -- remoteID
            renderedPhoto[i][3] = exportContext.publishedCollection.localIdentifier
            rendition:recordPublishedPhotoId( ImageID )
            rendition:recordPublishedPhotoUrl(tostring(exportContext.publishedCollection.localIdentifier))
            
          else
            LrDialogs.showError( result)
            ImageID = 'nil'
          end

          Log('Upload created new WPId: ' .. ImageID .. ' if empty: not created')
      --elseif validPhoto and ((folder ~= data.gallery) or (folder == WPCatColl and data.gallery ~= '')) then
      else
          -- do nothing skip
          countnotuploaded = countnotuploaded + 1
          notuploaded[countnotuploaded] = filename
      end
            
    end
    -- delete temp file. There is a cleanup step that happens later, but this will help manage space in the event of a large upload.
		LrFileUtils.delete( pathOrMessage )
    
  end -- for rendition

  if #notuploaded > 0 then
    LrDialogs.message('Could not upload images!', 'Some images were already uploaded to other collections. \nProposal: Remove from this collection or create a virtual Copy.', 'warning')
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

  if LRVmajor > 5 then
    for _, pp in pairs(publishedPhotos) do -- pp ist vom type LrPublishedPhoto. Hier kann also RemoteId und url gesetzt werden
      local remoteId = pp:getRemoteId()
      local ii,j = string.find(arraytostring, remoteId) -- den vollen Filename suchen
      local url = pseudoPublishSettings['siteURL']

      if ii ~= nil then
        local editFlag = pp:getEditedFlag()
        if editFlag then  
          Log('set edit flag: ', remoteId)
          local wpid = string.gsub( tostring(remoteId), 'WPSync', '')
          url = url .. '/wp-admin/post.php?post=' .. wpid .. '&action=edit'
          
          catalog:withWriteAccessDo( 'UpdateEditedFlag', function ()
            -- TODO: new 11 / 2021. The RemoteID was not set before. Does this work? Why did it work before with getRemoteId?
            -- Comment out or delete if other functions using the RemoteID do not work anymore.
            pp:setRemoteId( wpid ) 
            pp:setRemoteUrl( url)
            pp:setEditedFlag(false)
          end)
        end

      end
    end
  end
  ------------------------ End set edited flag

  progressScope:done()
end

-- called if somebody wants to move a published collection. This is not allowed. Delete first, create new collection and publish this one.
function exportServiceProvider.reparentPublishedCollection( publishSettings, info )
  Log('reparentPublishedCollection aufgerufen')
  error( '\nWarning: Function to move Collections not provided.\nPlugin works correctly. Don\'t worry.\nHowto:\n -Create New Collection and move photos manually. \n -Delete the collection you wanted to move and then publish the new collection' )
end

-- Sync with Wordpress: exportServiceProvider.titleForGoToPublishedCollection = 'Sync with Wordpress'
function exportServiceProvider.goToPublishedCollection( publishSettings, info )
  --LrMobdebug.on()
  Log('goToPublishedCollection aufgerufen (Sync with Wordpress)')
  local collection = info.publishedCollection
  local pubService = info.publishService
  local defaultcoll = info.publishedCollectionInfo.isDefaultCollection
  local catalog = LrApplication.activeCatalog()
  local nphotos = collection:getPhotos() -- array of LrPhoto
  local firstsync = false
  local result
  local mediatable = {}
  local len = 0
  local perpage -- Anzahl der Media-Einträge per REST-Abfrage
  local getmore = true
  local runs = 0

  -- Suchlauf bei Debug verkürzen
  if DebugSync then
    perpage = 30 -- Anzahl der Media-Einträge per REST-Abfrage
  else
    perpage = 100 -- Anzahl der Media-Einträge per REST-Abfrage
  end

  local pscope = LrProgressScope( {
    title = "First Sync WP with LR. Please Wait!",
  })
  
  if #nphotos == 0 then
    firstsync = true -- Zugriff in processRenderedPhotos nur mit exportContext.propertyTable.firstsync
  end
  
  -- Nur bei Firstsync also wenn die Collection leer ist und wenn es die Haupt-Collection ist.
  if (firstsync == true and publishSettings.urlreadable == true and defaultcoll) then
    Log('Start First Sync')
    pscope:setPortionComplete(0.05)

    -- Alle Fotos mit REST-Api aus dem WP-Media-Catalog auslesen  
    while getmore == true
    do
      Log('Start While')
      LrFunctionContext.callWithContext( "GetMedia", function( context )    
         result = GetMedia(publishSettings, perpage, runs+1)
      end,
      result)
      len = #result
      Log('Fetched ' .. len .. ' Photos')
          
      local i = 1
      while result[i] ~= nil
      do
        local row = {}
        row = ExtractDataFromREST(result[i])
        local index = runs * perpage + i
        mediatable[index] = row
        if row == {} then
          local str = inspect(result)
          Log('Z429: ' .. str)
        end
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
    
    Log('End While')
    --LrDialogs.message ( string.format("Found %d Photos in WordPress-Media-Catalog. Adding to Sync-collection now.", #mediatable),'','info')
    pscope:setPortionComplete(0.15)

    -- Suche die Fotos im lokalen LR-Catalog (Eigentlich eine Vorsuche zur Bestimmung der Suchmethode)
    local foundph = {}
    local notfound = {}
    local nfound = 1
    local nnotfound = 1
    local searchDesc = {}
    local paths = {}
    local npaths = 1
    local sub
    local Level1 = {}
    local pscopeadd = (0.2 - 0.15) / #mediatable
    local newfilepath

    ----------------------------------------------------------
    -- Suchlauf für alle Dateien : Pfade bestimmen
    for i=1,#mediatable do
        local filen = mediatable[i].filen
        local success = false
        local lrid
        local searchdesriptor = ''

        if filen == nil or filen == 'nil' then 
          local str = inspect(mediatable[i])
          Log('Filename nicht definiert. Nr : ' .. i .. str)
          break
        end
        
        if pscope:isCanceled() then pscope:cancel() end 

        -- Pfade für Collection und CollectionSet bestimmen
        local path = mediatable[i].phurl
        local pathlist = {}

        if path == nil or path == 'nil' then 
          local str = inspect (mediatable[i])
          Log(str) 
        else
          pathlist = strsplit(path, '/' )
        end 

        local uploadindex = findValueInArray (pathlist, 'uploads')
        sub =''
        for c=uploadindex+1, #pathlist-1 do -- hier wird immer nur ein pfad durchsucht
          sub = sub .. pathlist[c] .. '/'
        end
        -- Pfad nur ergänzen wenn nicht schon vorhanden und kein WP-Standard-Pfad
        if findValueInArray(paths, sub) == 0 then
          local wpcatsub = string.match(sub, '%d%d%d%d/%d%d')
          if wpcatsub == nil then
            paths[npaths] = sub
            npaths = npaths +1
          end
        end

        mediatable[i]['path'] = sub
        -----------------------------------------
        if pscope:isCanceled() then pscope:cancel() end
        pscope:setPortionComplete(0.15 + i * pscopeadd)

    end

    -- Gefundene Pfade in paths zu collectionSets und Collections verarbeiten
    local str = inspect(paths)
    Log(paths)
    for m=1, #paths do -- Achtung evtl -1
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
          end )
          -- set this to parent -- Fehl Suche in vorhandenen, ob die Coll bereits vorhanden ist
          collparent = result
        elseif level == ncollections then
          catalog:withWriteAccessDo( 'Create1stLevel', function ()
            result = pubService:createPublishedCollection( coll, collparent, true)
          end )
          
        end
      end

      Level1[m] = result -- enthält alle Collections in der Reihenfolge wie Pfade in paths
    end

    if pscope:isCanceled() then pscope:cancel() end
    pscope:setPortionComplete(0.2)

    
    -- Im Katalog gefundene Fotos zur Collection hinzufügen. Weitere Einschränkung bei mehrfach gefundenden Photos
    addToWPColl(collection, searchDesc, mediatable, Level1, paths) 
    ------------------------------------------------------------------------

    local pscopeadd = (0.6 - 0.2) / (#mediatable +1)
    for wait=1, #mediatable do
      LrTasks.sleep(0.3) -- necessary to wait for async process pscope 0,4
      pscope:setPortionComplete(0.2 + wait * pscopeadd)
    end
    --LrDialogs.message ( string.format("Added %d Photos to WordPress-Media-Catalog.", nfound-1),'','info')
    pscope:setPortionComplete(0.6)
    if pscope:isCanceled() then pscope:cancel() end

    -- nicht gefundene Photos herunterladen und zum Katalog eränzen
    local copyfile = publishSettings.doLocalCopy
    local copypath = publishSettings.localPath

    if copyfile then
      -- prüfen, ob der pfad existiert
      -- create download-directory 
      local _exists = LrFileUtils.exists( copypath )
      if not _exists then
        LrFileUtils.createDirectory( copypath )
      end
      Log('Start download of unknown Photos.')

      -- fotos herunterladen
      for nn=1,#mediatable do
        local photos = mediatable[nn].lrid
        
        -- Mind: Do NOT allow webp images because LR still can't handle this natively. So skip webp images.
        -- This is problematic if the image is only available in webp. Thus it will not added to LR.
        -- Could be solved by 'back-conversion' to jpg but sounds quite exhaustive.
        if (mediatable[nn].mime == 'image/jpeg' or mediatable[nn].mime == 'image/png') and #photos == 0 then
        --if mediatable[nn].mime == 'image/jpeg' and #photos == 0 then
          if WIN_ENV then
            newfilepath = copypath .. '\\' .. mediatable[nn].filen
          else
            -- Backslash unwandeln
            local macname = string.gsub(mediatable[nn].filen, '\\', '/')
            newfilepath = copypath .. '/' .. macname
            Log('Macname: ', newfilepath)
          end

          -- nur speichern, wenn datei nicht existiert
          if not LrFileUtils.exists( newfilepath ) then
            local newlrphoto = nil
            local downLoadUrl = mediatable[nn].origurl

            -- check if shortened url are used in WordPress and add the site url if so
            local url = publishSettings['siteURL'] 
            local result = string.match( downLoadUrl, url )
            if result == nil then
              downLoadUrl = url .. downLoadUrl
            end
            Log('ADD-2-CAT: ' .. downLoadUrl .. ' -> ' .. newfilepath)
            
            --- AsyncTask zum herunterladen
            LrTasks.startAsyncTask(function ()
              local httphead = {
                {field='Content-Type', value=mediatable[nn].mime}, --- noch für png und gif erweitern
                {field='Application', value='application/octet-stream'},
                }
              local newfilecontent, headers =LrHttp.get( downLoadUrl )
              local file = assert(io.open(newfilepath, "wb"))
              if newfilecontent ~= nil then
                file:write(newfilecontent)
              end
              file:close()
            end )
          
            -- Sleep --
            LrTasks.sleep(2)
            if not LrFileUtils.exists( newfilepath ) then
              LrTasks.sleep(10)
            end
          
            -- bild erfolgreich heruntergeladen
            if LrFileUtils.exists( newfilepath ) == 'file' then
              catalog:withWriteAccessDo( 'AddNewPhoto', function ()
                newlrphoto = catalog:addPhoto( newfilepath )
              end )
              
              -- lrphoto and foundph anhängen. lrid = lrphoto setzen
              mediatable[nn].lrid = {newlrphoto}
            end
            
          end -- if not exists
          
        end -- if mime-type 
      end -- for
    end -- copyfile 
            
    -- Write extracted Rest-meta-Data to customMetadata in Lightroom Catalog
    local pscopeadd = (0.95 - 0.7) / (#mediatable +1)
    catalog:withWriteAccessDo( 'AddMetaData', function () 
      for i=1, #mediatable do
          local photos = mediatable[i].lrid

          if #photos > 0 then
            -- Collection bestimmen
            local new_collection
            local path = mediatable[i]['path']
            local index = 0
                
            index = findValueInArray(paths, path)

            if index > 0 then
              new_collection = Level1[index]
            else
              new_collection = collection
            end

            new_collection:addPhotos(photos) -- richtige collection bestimmen
                            
            for j, photo in ipairs(photos) do
              WriteCustomMetaData( publishSettings, photo, mediatable[i]) 
            end
          end
          pscope:setPortionComplete(0.7 + i * pscopeadd)
      end 
    end ) -- catalog:withWriteAccessDo
    
    pscope:setPortionComplete(0.95)

    -- Write csv-File with not found Photos
    if not copyfile then
      for i=1,#mediatable do
        local photos = mediatable[i].lrid
        if #photos == 0 then
          table.insert(notfound,mediatable[i])
          nnotfound = nnotfound +1
        end
      end
      local p2 = LrPathUtils.getStandardFilePath( 'documents' )
      csvwrite(p2 .. '/notfound.csv',notfound, ';') 
    end

    pscope:done()
    --LrDialogs.message ( string.format("Added %d Photos to WordPress-Media-Catalog, but %d Photos not found in Catalog! See Log-File", nfound-1, nnotfound-1),'','info')
  
  end -- if firtsync

  pscope:done()
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

  --local os = LrSystemInfo.osVersion()
  --local ii,j = string.find(os,'indows') -- den vollen Filename suchen
  --if ii ~= nil then
  --  os = 'WIN'
  -- end
  
  -- Create nested folder name from parents of collection sets
  for i=#parents,1,-1 do
    local par = parents[i].name
    folder = par .. '/' .. folder
  end

  local wpgall = '[gpxview imgpath="' .. folder .. '" gpxfile=".." alttext="Bildergalerie mit Karte, GPX-Track und Höhenprofil "]'
  local wpimage ='<!-- wp:image {"align":"center","id":'.. wpid .. ',"sizeSlug":"full","linkDestination":"none"} --> <div class="wp-block-image"><figure class="aligncenter size-full"><img src="'.. srcurl ..'" alt="'.. alt ..'" class="wp-image-'.. wpid ..'"/><figcaption>' .. alt .. '</figcaption></figure></div><!-- /wp:image -->'
  local wp = wpgall .. '    ' .. wpimage
  local copyCmd = "echo '".. wp .."' | pbcopy" -- MAC

  if WIN_ENV then
         copyCmd = 'Echo '.. '"'.. wp.. '"' .. ' | clip'
  end

  LrTasks.execute(copyCmd)
  LrDialogs.message(message2, wp, 'info')
  
end

-- Delete photo from published collection, delete in WP-Media-Catalog, delete MetaData in LR Catalog
-- Quelle: https://github.com/willthames/photodeck.lrdevplugin : PhotoDeckPublishServiceProvider.lua (Zeilen 313ff)
function exportServiceProvider.deletePhotosFromPublishedCollection (publishSettings, arrayOfPhotoIds, deletedCallback, localCollectionId)
  Log('publishServiceProvider.deletePhotosFromPublishedCollection')
  --LrMobdebug.on() 
  local catalog = LrApplication.activeCatalog()
  local publishedPhotoById = {}
  local photoUnpublish = {}
  local result
  local error_msg = 'nix'
  
  -- this next bit is stupid. Why is there no catalog:getPhotoByRemoteId or similar
  -- is necessary to get the LRphoto object and not the publishedPhoto object.
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
    --LrMobdebug.on()
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
      --[[
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
      ]]
      --if (tonumber(wpid) > 0) and (difftime == 0) then
        -- geplant war Bilder mit falscher Zeitdifferenz nicht zu löschen
        -- Der Schutz funktioniert: Metadaten werden entfernt und das Foto aus der Collection
        -- Bei erstellten Panos wird aber die Erstellungszeit geändert! Daher: IMMER löschen!
      if (tonumber(wpid) > 0) then 
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

-- Diese Funktion wird nach Programmstart und "Veröffentlichen" als erste aufgerufen, Warum und wofür ist unklar
function exportServiceProvider.getCollectionBehaviorInfo( publishSettings )
  --LrMobdebug.on()
  --logDebug = publishSettings.DebugMode
  Log('getCollectionBehaviorInfo call')
  Log('WP-Plugin installed: ', publishSettings.wpplugin)
  Log('WPalt : ' .. inspect(publishSettings.WPalt[1]) .. '  WPdescr = ' .. inspect(publishSettings.WPdescr[1]) .. '  WPcap = ' .. inspect(publishSettings.WPcap[1]) )
  Log('LRcap : ' .. inspect(publishSettings.LRcap[1]))
  Log('firstSyncDoMetaOnly : ' .. inspect(publishSettings.firstSyncDoMetaOnly))
  Log('LrMeta_to_WP : ' .. inspect(publishSettings.LrMeta_to_WP))
  Log('OS: ' .. os .. ' LR-Version: ' .. LRVmajor .. '.' .. LRVminor .. '.' .. LRVrevis .. '.' )

  -- check availability of ImageMagick on start-up 
  -- delete-file First
  --[[
  local p2 = LrPathUtils.getStandardFilePath( 'documents' )
  local filepath = p2 .. '\\LRTestImagick.txt'
  if LrFileUtils.exists( filepath ) then
    LrFileUtils.delete( filepath )
  end
  
  LrTasks.startAsyncTask( function(  )
    local p2 = LrPathUtils.getStandardFilePath( 'documents' )
    
    -- do test for Imagemagick  
    local cmd = 'magick -version > "' .. p2 .. '\\LRTestImagick.txt"' 
    
    Log ('image ', cmd)
    LrTasks.execute( cmd ) 
  end 
  )
  ]]

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
  --LrMobdebug.on() 
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
  --LrMobdebug.on() 
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
  --LrMobdebug.on() 
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
