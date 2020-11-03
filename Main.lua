--	Main entry point for plugin.
----- Debug -----------
--local Require = require "Require".path ("../debuggingtoolkit.lrdevplugin").reload ()
--local Debug = require "Debug".init ()
--require "strict.lua"

local LrDialogs = import 'LrDialogs'
local LrApplication = import( 'LrApplication' )
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrView = import 'LrView'
local LrHttp = import 'LrHttp'
local LrLogger = import 'LrLogger'
local LrDate = import 'LrDate'
local LrTasks = import 'LrTasks'
local LrProgressScope = import( 'LrProgressScope' )
local LrFunctionContext = import 'LrFunctionContext'
local LrExportSession = import 'LrExportSession'
--local LrErrors = import 'LrErrors'
--local LrFtp = import 'LrFtp'
--local LrXml = import 'LrXml'
--local bind = LrView.bind
--local share = LrView.share

JSON=require 'JSON'
require 'Dialogs'
--require 'Process'
require 'helpers'
require 'Logger'

----- Debug -----------
--local Require = require "Require".path ("../debuggingtoolkit.lrdevplugin").reload ()
--local Debug = require "Debug".init ()
require "strict"
--require "strict.lua"
local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
LrMobdebug.start()
local inspect = require 'inspect'
local myLogger = LrLogger( 'WPSynclog' )
myLogger:enable( "logfile" )
local function o2L( message )
	myLogger:trace( message )
end
----- Debug -----------

------------ exportServiceProvider ----------------------------
exportServiceProvider = {}
exportServiceProvider.supportsIncrementalPublish = 'only'
exportServiceProvider.small_icon = "Small-icon.png"
exportServiceProvider.hideSections = { 'exportLocation', 'exportVideo' } -- exportLocation erzeugt den Reiter "Speicherort für Export"
exportServiceProvider.allowFileFormats = { 'JPEG' } 								-- TODO: alle Filetypen erlauben. evtl. Plugin von J.Friedl oder Ellis verwenden
exportServiceProvider.allowColorSpaces = { 'sRGB' }
exportServiceProvider.hidePrintResolution = true									-- hide print res controls
exportServiceProvider.canExportVideo = false 										-- video is not supported through this plug-in
exportServiceProvider.supportsCustomSortOrder = true  -- this must be set for ordering
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
exportServiceProvider.disableRenamePublishedCollection = false -- benennt die Sammlung im Dienst um, erzeugt damit einen neuen Ordner
exportServiceProvider.disableRenamePublishedCollectionSet = true -- benennt den ganzen Dienst um
------------ exportServiceProvider ----------------------------

function exportServiceProvider.metadataThatTriggersRepublish( publishSettings )
	Log('metadataThatTriggersRepublish aufgerufen')
	return {
    -- TODO: Nach dem Neustart sind alle Bilder in republish
    --['com.adobe.lightroom.export.wp_mediacat2.*'] = true, -- TODO: Änderung führt nicht zum Republish in der Sammlung!
    default = false,
		title = true,
		caption = true,
		keywords = true,
		gps = true,
		--dateCreated = false,
		copyright = true,
		--label = false,
		--rating = false, 
	  --customMetadata = true, -- TODO: Änderung führt nicht zum Republish in der Sammlung!
  }

end

-- publish Photos -- processRenderedPhotos -- hier werden die fotos die in der Sammlung sind verarbeitet. Bug : rendition is empty
-- aber nPhotos is korrekt
function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )
  Log('processRenderedPhotos aufgerufen')
  --Debug.pauseIfAsked()
  LrMobdebug.on()

  --local LrExportSession = import 'LrExportSession' 
	local exportSession = exportContext.exportSession
  local exportSettings = exportContext.propertyTable
  local catalog = LrApplication.activeCatalog()
	local nPhotos = exportSession:countRenditions()
  local mypluginID = 'com.adobe.lightroom.export.wp_mediacat2' -- TODO: durch variable ersetzen
  local pseudoPublishSettings = exportSettings['< contents >']
  
   local progressScope = exportContext:configureProgress {
    title = nPhotos > 1
    and LOC("$$$/PhotoDeck/ProcessRenderedPhotos/Progress=Publishing ^1 photos to PhotoDeck", nPhotos)
    or LOC "$$$/PhotoDeck/ProcessRenderedPhotos/Progress/One=Publishing one photo to PhotoDeck",
  }

  for i, rendition in exportContext:renditions { stopIfCanceled = true } do
    
    local success, pathOrMessage = rendition:waitForRender()
    local photo = rendition.photo
    local ImageID
    local wpid
    local data
    
    if success then
      progressScope:setPortionComplete( ( i - 1 ) / nPhotos )
      
      wpid = photo:getPropertyForPlugin( mypluginID, 'wpid' ) 
      if wpid == nil or wpid == '' then wpid = 0 end
      
      local photoMeta = {
        caption = photo:getFormattedMetadata('caption'),
        title = photo:getFormattedMetadata( 'title' ),
        gallery = photo:getPropertyForPlugin( mypluginID, 'gallery' ),
      }
     
      if tonumber(wpid) > 0 then -- replace image or change state to published after first sync 
          -- TODO: stimmt nur für first sync! replace image oder update geht nicht!
          Log(wpid .. ' found. Now updating')
          -- Abfrage: replace nur Metadaten oder das komplette Bild?
          -- nur Änderung von Titel, Bildunterschrift, und Gallery, wenn's mal geht über REST in description, caption, alt_text, title
          -- alle anderen Daten, Bild, GPS : Bild komplett ersetzen, dafür ist eine WP-Funktion erforderlich!
          -- Wie zwischen den beiden Fällen unterscheiden?
          
          data = GetMedia(pseudoPublishSettings, wpid) 
          data = ExtractDataFromREST(data)

          -- Prüfung auf Identität, wenn hier Änderung, dann auch in WritephotoMetaToWp
          if data['title'] == photoMeta['title'] and  (data['caption'] == photoMeta['title']) then photoMeta['title'] = '' end -- title und caption = title
          if (data['alt'] == photoMeta['caption']) and (data['descr'] == photoMeta['caption'])   then --alt und descr = caption
            photoMeta['caption'] = '' 
          end
          if data['gallery'] == photoMeta['gallery'] then photoMeta['gallery'] = '' end
         
          local success = WritephotoMetaToWp( pseudoPublishSettings, tonumber(wpid), photoMeta )
          if success then
            Log(wpid .. ' found. Was updated')
            ImageID  = 'WPSync' .. tostring(wpid) -- published before?  -- set to wpid
          else
            ImageID = ''
          end
      
      else -- add new image to WP Media Catalog
          local filename = photo:getFormattedMetadata( 'fileName' ) -- LrPathUtils.leafname( pathOrMessage ) liefert auch den Dateinamen, hier aber filename für WP-Mediacat
          Log('Datei: ' .. filename)
          local renditionFilePath = LrPathUtils.standardizePath( pathOrMessage ) -- Der Anhang -scaled wird von WP automatisch ergänzt
          Log('Rendition-Datei: ' .. renditionFilePath)
          local result = 'none'
          result, data = AddNewMedia( pseudoPublishSettings, filename, renditionFilePath )
          
          if type(result) == 'number' then
            ImageID  = 'WPSync' .. tostring(result) -- set to wpid --diese Nummer muss eineindeutig sein!
            -- fehlende LR-Metadaten in den WP Katalog schreiben
            
            WritephotoMetaToWp( pseudoPublishSettings, result, photoMeta )
            -- Custom-Metadaten in WP-Katalog schreiben: Rest-Antwort-Daten in CustomMeta schreiben
            catalog:withWriteAccessDo( 'AddMetaData', function ()
              WriteCustomMetaData( photo, data )
            end )

          else
            ImageID = ''
          end

          Log('Upload: ' .. result)
      end
      rendition:recordPublishedPhotoId( ImageID )
    end
    -- delete temp file. There is a cleanup step that happens later, but this will help manage space in the event of a large upload.
		LrFileUtils.delete( pathOrMessage )
    
  end

  progressScope:done()

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
      -- TODO: do nothing until field is available via REST-API
      --local gallery = photo:getPropertyForPlugin( mypluginID, 'gallery' ) -- TODO: Dieser Wert ist in Rest noch nicht verfügbar
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

function ExtractDataFromREST( restdata )
  -- aus einer REST-Antwort zu einer Datei die Daten für customMetadata extrahieren
  -- Parameter restdata: JSON-Format der REST-Antwort
  local i = 1
  local result = {} 
  result[i] = restdata
  local row = {}
  local keyfound = false
  local lrid
  local w1, w2

  local str = inspect(result[i]) -- JSON-Rückgabe für ein Image in str umwandeln
  local ii,j = string.find(str,'full') -- den vollen Filename suchen
  if ii ~= nil then
    keyfound = true  -- Der filename ist in der Rest-Antwort enthalten
  end
  
  local _descr = result[i].description.rendered  
  w1, w2 = string.find(_descr, '<p>.*</p>')
  if w1 ~=nil and w2 ~= nil then
    _descr = string.sub(_descr,w1+3,w2-4)
    w1 = nil
    w2 = nil
  else
    _descr = ''
  end

  local _caption = result[i].caption.rendered
  w1, w2 = string.find(_caption, '<p>.*</p>')
  if w1 ~=nil and w2 ~= nil then
    _caption = string.sub(_caption,w1+3,w2-4)
    w1 = nil
    w2 = nil
  else
    _caption = ''
  end

  if keyfound then
    row = {lrid = {}, id = result[i].id, 
                      upldate = result[i].date, 
                      width = result[i].media_details.width, 
                      height = result[i].media_details.height, 
                      slug = result[i].slug, 
                      post = result[i].post, 
                      gallery = result[i].gallery, 
                      phurl = result[i].source_url, 
                      filen = result[i].media_details.sizes.full.file,
                      datemod = result[i].modified, 
                      title = result[i].title.rendered,
                      descr = _descr,  
                      caption = _caption,
                      alt  = result[i].alt_text, 
                      origfile = result[i].media_details.original_image,  -- Fehler, wenn nicht vorhanden?
          } 
  else
    local fname = result[i].media_details.file
    fname = getfile(fname)
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
                      origfile = result[i].media_details.original_image, -- Fehler, wenn nicht vorhanden?
                    } 
  end

  return row
end

function WriteCustomMetaData( photo, restmetadata )
  -- Write extracted Rest-meta-Data to customMetadata in Lightroom Catalog
  -- Achung: muss innerhalb von catalog:withWriteAccessDo('unique-ID', function () ... end) aufgerufen werden
  local i = 1
  local foundph = {}
  foundph[i] =  restmetadata

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

-- Add Media File to WP-Media-Catalog via REST-API
function AddNewMedia( publishSettings, filename, path ) 
  local hash = 'Basic ' .. publishSettings['hash']
  local filen = filename
  local wpid = 0
  local restData = {}

  if publishSettings == {} or publishSettings['hash'] == '' or publishSettings['siteURL'] == '' or filename == '' or path == '' then
    return
  end

	local httphead = {
      {field='Authorization', value=hash},
      {field='Content-Disposition', value='form-data; filename="' .. filen .. '"'},
      {field='Content-Type', value='image/jpeg'},
    }

  local imgfile = LrFileUtils.readFile(path) -- Rückgabe als String!
    
  local url = publishSettings['siteURL'] .. "/wp-json/wp/v2/media/"
    
	local result, headers = LrHttp.post( url, imgfile, httphead )

	if headers.status == 201 then
      result = JSON:decode(result)
      wpid = tonumber(result['id'])
      restData = ExtractDataFromREST(result)
  else
    	wpid = 'Fault: ' .. tostring(headers.status .. ' : ' .. filen)
  end
  
  return wpid, restData
end

-- Get all Media Files from WP-Media-Catalog via REST-API
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
   
  if tonumber(perpage) ~=nil and tonumber(page) ~=nil then
		url = _siteURL .. "/wp-json/wp/v2/media/?per_page=" .. perpage .. '&page=' .. page
  elseif tonumber(perpage) > 0 and tonumber(page) ==nil then
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

-- Sync with Wordpress: exportServiceProvider.titleForGoToPublishedCollection = 'Sync with Wordpress'
function exportServiceProvider.goToPublishedCollection( publishSettings, info )
  --LrMobdebug.on()
  o2L('goToPublishedCollection aufgerufen')
  local collection = info.publishedCollection
  local catalog = LrApplication.activeCatalog()
  local nphotos = collection:getPhotos()
  local firstsync = false
  local result
  local mediatable = {}
  local len = 0
  local perpage = 10
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
        local str = inspect(result[i]) -- JSON-Rückgabe für ein Image in str imwandeln
        local ii,j = string.find(str,'full') -- den vollen Filename suchen
        if ii ~= nil then
          keyfound = true  -- Der filename ist im Rest enthalten
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
        break -- nur für Testzwecke: zum vozeitigen Abbruch : Debug
      else
        getmore = false
      end
      
    end
 
   LrDialogs.message ( string.format("Found %d Photos in WordPress-Media-Catalog. Adding to collection now.", #mediatable),'','info')
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
  
  LrDialogs.message ( string.format("Added %d Photos to WordPress-Media-Catalog.", nfound-1),'','info')
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
  -- TODO: am Ende process rendered photos mit contect aufrufen, um die ImageID in der rendition zu setzen.
  -- Verzeichnis im PublishSettingsMenu angeben und Radio-Buttion zur Aktivierung
  -- Wenn Verzeichnis leer und aber aktiviert, dann LrPathUtils.getStandardFilePath( 'pictures' ) verwenden
  -- Metadaten wie auch bei den gefundenen Fotos setzen
  
  end -- if firtsync
end -- function

-- image delete callback: Die callback Funktion selbst fehlt, ebenso POST
-- Geht nicht : gibt eine Fehlermeldung, die nicht zum Absturz führt
--[[function exportServiceProvider.deletePhotosFromPublishedCollection( publishSettings, arrayOfPhotoIds )
function exportServiceProvider.deletePhotosFromPublishedCollection( publishSettings, arrayOfPhotoIds, deletedCallback )
-- REST-API mit Auth und Force zum Löschen
-- Foto aus der Sammlung entfernen
-- Metdaten aus dem Foto löschen
  o2L('deletePhotosFromPublishedCollection call')
  --LrMobdebug.on()
  LrTasks.startAsyncTask(function ()
    LrMobdebug.on() 
    --local collection = info.publishedCollection     
    local catalog = LrApplication.activeCatalog()
    --local nphotos = collection:getPhotos()
    --local myPluginID = 'com.adobe.lightroom.export.wp_mediacat2'
    
    for i, photoId in ipairs( arrayOfPhotoIds ) do
      local photo = catalog:findPhotos {
         searchDesc = {
           criteria = "all",
           operation = "==",
           value = photoId,
          }      
     }
      local aperture = '999'
      if ((photo ~=nil) and (#photo > 0)) then
        aperture = photo:getFormattedMetadata( 'aperture' )
      end
      Log('Blende: ' .. aperture)
    end
    
  end )
      
  for i, photoId in ipairs( arrayOfPhotoIds ) do

    --Log( string.format( "Deleting id: %d", photoId ));
    Log( "Deleting id: %d" .. photoId );
    -- local result = Post( "image/delete",  { pid = photoId }, publishSettings )
    --local ImageID = photoId:getPropertyForPlugin( _PLUGIN, 'wpid' )
    --local aperture = photoId:getFormattedMetadata( 'aperture' )
    --local aperture = '99'      
    --Log('Blende: ' .. aperture)
    -- call the delete callback even if it fails on the Wordpress end
    -- ToDo: Need to fix it so REST doesn't return an error if the delete fails
    --			there's still a potential conflict here if the image is out of kilter between the server and the local.	
    --if result ~= nil then
    deletedCallback( photoId ) -- Diese Callback-Funktion ist noch nicht definiert
    --end

  end
end
]]

-- Delete photo from published collection, delete in WP-Media-Catalog, delete MetaData in LR Catalog
-- Quelle: https://github.com/willthames/photodeck.lrdevplugin : PhotoDeckPublishServiceProvider.lua (Zeilen 313ff)
exportServiceProvider.deletePhotosFromPublishedCollection = function(publishSettings, arrayOfPhotoIds, deletedCallback, localCollectionId)
  o2L('publishServiceProvider.deletePhotosFromPublishedCollection')
  --LrMobdebug.on() 
  local catalog = LrApplication.activeCatalog()
  local collection = catalog:getPublishedCollectionByLocalIdentifier(localCollectionId)
  local galleryId = collection:getRemoteId()
  local photoIdsToDelete = {}
  local photoIdsToUnpublish = {}
  local LrPhotosToDelete = {}
  local result
  local error_msg
  -- this next bit is stupid. Why is there no catalog:getPhotoByRemoteId or similar
  local publishedPhotos = collection:getPublishedPhotos()
  local publishedPhotoById = {}

  for _, pp in pairs(publishedPhotos) do
    publishedPhotoById[pp:getRemoteId()] = pp
  end
  for i, photoId in ipairs( arrayOfPhotoIds ) do
    error_msg = nil
    if photoId ~= "" then
      local publishedPhoto = publishedPhotoById[photoId]
      local catphoto = publishedPhoto:getPhoto()
      table.insert(LrPhotosToDelete, catphoto)
      local collCount = 0
      for _, c in pairs(publishedPhoto:getPhoto():getContainedPublishedCollections()) do
        if c:getRemoteId() ~= galleryId then
          collCount = collCount + 1
        end
      end

      if collCount == 0 then
        -- delete photo if this is the only collection it's in
        table.insert(photoIdsToDelete, photoId)
      else
        -- otherwise unpublish from the passed in collection
        table.insert(photoIdsToUnpublish, photoId)
      end
    end
  end
  
  LrTasks.startAsyncTask(function ()
   
    local mypluginID = 'com.adobe.lightroom.export.wp_mediacat2' -- TODO: durch Variable ersetzen

    for i, photo in ipairs( LrPhotosToDelete ) do
      --local aperture = '999'
      --local photo2 = LrPhotosToDelete[i]
      --local photo3 = photo:getPhoto()
      --aperture = photo:getFormattedMetadata( 'aperture' )
      local wpid = photo:getPropertyForPlugin( mypluginID, 'wpid' )
      if wpid == nil then wpid = 0 end
      local success = false
      
      if tonumber(wpid) > 0 then
        success = DeleteMedia(publishSettings, wpid)
      end

      if success then
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
        Log('WP-Media deleted: ' ..tostring(wpid).. '  ' .. tostring(success))
      end
    end
  end )

  -- Unpublish
  local photoIdsToUnpublishCount = #photoIdsToUnpublish
  if photoIdsToUnpublishCount == 1 then
    -- Only one photo needs to be unpublished. Use non batched API endpoint.
    local photoId = photoIdsToUnpublish[1]
    --result, error_msg = PhotoDeckAPI.unpublishPhoto(photoId, galleryId)

    if error_msg then
      LrErrors.throwUserError(LOC("$$$/PhotoDeck/DeletePhotos/ErrorUnpublishingPhoto=Error unpublishing photo: ^1", error_msg))
    else
      deletedCallback(photoId)
    end
  elseif photoIdsToUnpublishCount > 0 then
    -- More than one photo needs to be unpublished. Use batched API endpoint.
    --result, error_msg = PhotoDeckAPI.unpublishPhotos(photoIdsToUnpublish, galleryId)

    if error_msg then
      LrErrors.throwUserError(LOC("$$$/PhotoDeck/DeletePhotos/ErrorUnpublishingPhotos=Error unpublishing photos: ^1", error_msg))
    else
      for _, photoId in ipairs(photoIdsToUnpublish) do
        deletedCallback(photoId)
      end
    end
  end

  -- Delete
  local photoIdsToDeleteCount = #photoIdsToDelete
  if photoIdsToDeleteCount == 1 then
    -- Only one photo needs to be deleted. Use non batched API endpoint.
    local photoId = photoIdsToDelete[1]
    --result, error_msg = PhotoDeckAPI.deletePhoto(photoId)

    if error_msg then
      LrErrors.throwUserError(LOC("$$$/PhotoDeck/DeletePhotos/ErrorDeletingPhoto=Error deleting photo: ^1", error_msg))
    else
      deletedCallback(photoId)
    end
  elseif photoIdsToDeleteCount > 0 then
    -- More than one photo needs to be deleted. Use batched API endpoint.
    --result, error_msg = PhotoDeckAPI.deletePhotos(photoIdsToDelete)

    if error_msg then
      LrErrors.throwUserError(LOC("$$$/PhotoDeck/DeletePhotos/ErrorDeletingPhotos=Error deleting photos: ^1", error_msg))
    else
      for _, photoId in ipairs(photoIdsToDelete) do
        deletedCallback(photoId)
      end
    end
  end
end

--called when  collection (gallery) is added or renamed.
--[[ hier gibt es wahrsch. keine Funktion
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
]]

-- called when a publish collection set (album) is added or changed. (renamed)
--[[ hier gibt es wahrsch. keine Funktion
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
]]

-- sort order als Variable im PHP in WP einstellen:
--[[hier gibt es also wahrsch. keine Funktion)
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
]]

--(optional) This plug-in defined callback function is called when the user chooses the "Go to Published Photo" context-menu item.
-- direkten Login in die Medien-Bibliothek öffnen
function exportServiceProvider.goToPublishedPhoto( publishSettings, info )
  o2L('goToPublishedPhoto call')
end

-- Diese Funktion wird nach "Veröffentlichen" als erste aufgerufen, Warum und wofür ist unklar
function exportServiceProvider.getCollectionBehaviorInfo( publishSettings )
  o2L('getCollectionBehaviorInfo call')
  --outputToLog('getCollectionBehaviorInfo aufgerufen')
	
	return {
		defaultCollectionName = LOC "$$$/Wordpress/DefaultCollectionName/WPCat=WPCat",
		defaultCollectionCanBeDeleted = true,
		canAddCollection = true,
		maxCollectionSetDepth = 0,
	}
	
end

return exportServiceProvider
