-- special helper functions for the LR-SDK-API
---
local LrApplication = import( 'LrApplication' )
local LrFileUtils = import 'LrFileUtils'
local LrHttp = import 'LrHttp'
local LrDate = import 'LrDate'
local LrTasks = import 'LrTasks'


----- Debug -----------
--logDebug = false
require 'strict'
require 'Logger'
local DebugSync = logDebug
local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
LrMobdebug.start()
local inspect = require 'inspect'
----- Debug -----------

---------------------------------------------------------

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
	LrMobdebug.on()  
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

    if k == 'sortorder' and v ~= '' and v ~= nil and v ~= 'nil' then -- hier wird nur eine Nummer als integer übergeben
      v = urlencode( tostring(v))
      local str = 'gallery_sort=' .. v
      url = url .. pre(n) .. str
      n = n + 1
    end
    
	end
  
	if n>0 then
	  result, headers = LrHttp.post( url, '', httphead )
    
    if headers.status == 200 then -- der POST-Request wird in diesem Fall immer mit status = 200 beantwortet
      success = true
      Log('Wrote Meta to Rest: ' .. url)
    else
      success = false
      Log('Could not write Meta to Rest: ' .. url)
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
  
	if restdata == nil or restdata == '' or restdata == 'nil' or restdata == {} or result[i].media_type == 'file' or result[i].mime_type == "image/x-icon"  then -- mime_type = \"image/x-icon\"
		return row
	end
  
	local str = inspect(result[i]) -- JSON-Rückgabe für ein Image in str umwandeln
	local ii,j = string.find(str,'original_image') -- den vollen Filename suchen
	if ii ~= nil then
	  fname = result[i].media_details.original_image
	else
	  fname = result[i].media_details.file
	  if fname == nil or fname == 'nil' then Log(str) 
	  else
	  fname = getfile(fname)
	  fname, n = fname:gsub('-scaled','')
	  end
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
  
  row = { lrid = {}, 
          id = result[i].id, 
          upldate = result[i].date, 
          width = result[i].media_details.width, 
          height = result[i].media_details.height, 
          slug = result[i].slug, 
          post = result[i].post, 
          gallery = result[i].gallery, 
          phurl = result[i].source_url, 
          filen = fname,
		  datemod = result[i].modified, 
		  datecreated = result[i].media_details.image_meta.created_timestamp,
          title = result[i].title.rendered,
          descr = _descr,  
          caption = _caption,
          alt  = result[i].alt_text, 
          origfile = fname, 
          MD5 =  result[i].md5_original_file, -- table contains MD5 und filesize of fname on server
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
-- param: page : wenn nicht angegeben, dann muss perpage eine wpid sein!
-- param: fields : definiert die abzurufenden Felder mit ..../media/<wpid>?_fields=id,gallery,filen,MD5
function GetMedia( publishSettings, perpage, page ) 
  LrMobdebug.on()
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
		  Log(url)
	elseif tonumber(perpage) > 0 and tonumber(page) == nil then
    	url = _siteURL .. "/wp-json/wp/v2/media/" .. perpage
  	elseif tonumber(perpage) == 0 then
    	return
	else  
		url = _siteURL .. "/wp-json/wp/v2/media/"
	end
	 
	local result, headers = LrHttp.get( url, httphead )
  
	if headers.status == 200 then
      result = JSON:decode(result)
  else 
    result = nil
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
function addToWPColl (collection, search, photos, all_collections, all_paths)
	
	LrTasks.startAsyncTask(function ()
		LrMobdebug.on()
		local str =inspect(all_paths)
		Log('Paths in addToWPColl: ', str)
		local catalog = LrApplication.activeCatalog()
		local selphoto
			
		for i=1, #search do

			local searchDesc = {}

			if search[i]['criteria'] == 'copyname' then
				searchDesc = { 
					{ criteria = search[i]['criteria'], operation = search[i]['operation'], value = search[i]['value'], } ,
					combine = "intersect",
				} 
			else
				searchDesc = { 
					{ criteria = search[i]['criteria'], operation = search[i]['operation'], value = search[i]['value'], } ,
					{ criteria = "copyname", -- selektiert die Kopien aus
						operation = "noneOf",
						value = "Kopie", -- TODO: International? oder im PublishSettingsMenu einstellen?
					}, 
				combine = "intersect"} -- UND-Verknüpfung der Kriterien
			end

			local str = inspect(searchDesc)
			Log(str)

			local lrid = catalog:findPhotos {
				searchDesc 
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

			-- Collection bestimmen
			local new_collection
			local path = search[i]['path']
			local index = 0
					
			index = findValueInArray(all_paths, path)
			if index > 0 then
				new_collection = all_collections[index]
			else
				new_collection = collection
			end

			--local name = new_collection:getCollectionInfoSummary()['name']
			--Log(path .. '=' .. name)

			local wptimestamp = photos[i].datecreated
			local lrtime = lrid[1]:getRawMetadata( 'dateTimeOriginal' ) --  dateTimeOriginal: (number) The date and time of capture (seconds since midnight GMT January 1, 2001)
			lrtime = mytonumber(lrtime)
			if lrtime == 'nil' then lrtime = 0 end
			local diff = lrtime - wptimestamp
			Log(photos[i].filen  .. ' WPtime: ' .. wptimestamp .. ' LRtime: ' .. lrtime .. ' Diff: ' .. diff .. ' len: ' .. #lrid )	
			
			catalog:withWriteAccessDo( 'AddtoWP', function () 
					new_collection:addPhotos(lrid)
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

-- Reset the Custom Meta-Date of this plugin 
function ResetCustomMeta (photo)
  local catalog = LrApplication.activeCatalog()
  catalog:withWriteAccessDo( 'DeleteCollection', function ()
    photo:setPropertyForPlugin( _PLUGIN, 'wpid', '' )
    photo:setPropertyForPlugin( _PLUGIN,'upldate', '' )
    photo:setPropertyForPlugin( _PLUGIN,'wpwidth', '')
    photo:setPropertyForPlugin( _PLUGIN,'wpheight', '')
    photo:setPropertyForPlugin( _PLUGIN,'wpimgurl', '')
    photo:setPropertyForPlugin( _PLUGIN,'slug', '' )
    photo:setPropertyForPlugin( _PLUGIN,'post', '')
    photo:setPropertyForPlugin( _PLUGIN,'gallery',  '')
    --photo:setPropertyForPlugin( _PLUGIN,'order', '' )
  end )
end