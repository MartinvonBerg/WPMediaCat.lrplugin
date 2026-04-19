-- special helper functions for the LR-SDK-API
---
local LrApplication = import( 'LrApplication' )
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrHttp = import 'LrHttp'
local LrDate = import 'LrDate'
local LrTasks = import 'LrTasks'
local LrPhotoInfo = import 'LrPhotoInfo'
JSON=require 'JSON'
require 'helpers'

----- Debug -----------
--logDebug = false
--require 'strict'
require 'Logger'
--DebugSync = false
inspect = require 'inspect'
----- Debug ------------

---------------------------------------------------------
-- Write LR Metadata of photo to WP Mediacat via REST-API
function WritephotoMetaToWp( publishSettings, wpid, photoMeta )
	-- Parameters: wpid: Number evtl. auch String, aber dann zu Number wandelbar
	-- photoMeta: Tabelle mit Metadaten als key-value-pair
	-- publishSettings: Tabelle ähnlich den Lr-Lua-PublishSettings, hier aber kopiert, da Original nicht bereitsteht
	-- LR caption kommt in den alt-tag und in die Beschreibung bzw. description.raw 
	-- SEO: alt-tag leerlassen, wenn das Bild als dekoratives Element dient!
  
	-- Example: http-POST: http://127.0.0.1/wordpress/wp-json/wp/v2/media/4224?gallery=paularo&description=cat=paularo
	-- Example: http-POST: http://127.0.0.1/wordpress/wp-json/wp/v2/media/4224?title=MPaul
	-- Example: http-POST: http://127.0.0.1/wordpress/wp-json/wp/v2/media/4474?alt_text=alternate-text
	--LrMobdebug.on()  
	local success = false
	local docaption = publishSettings['doCaption']
	local restData = {}

	if type(wpid) ~= 'string' then
		wpid =  tostring(wpid)
	end
  
	if photoMeta == {} or publishSettings == {} or publishSettings['hash'] == '' or publishSettings['siteURL'] == '' then
	  local phMeta = inspect( photoMeta)
	  local id = inspect(wpid)	
	  Log('WritephotoMetaToWp failed for ' .. id .. ' with type ' .. type(wpid) )
	  Log('Meta was: ', phMeta)
	  Log('hash ', publishSettings['hash'])
	  Log('siteURL ', publishSettings['siteURL'])
	  return success
	end

	-- check reachability of WP-site and Plugin
	local result = CheckLogin( publishSettings )
	if tableHasKey( result, 'error' ) then
		Log('WritephotoMetaToWp: ', result['error'])
		wpid = result['error']
		return wpid, restData
	end
	if not publishSettings.wpplugin then
		Log('WritephotoMetaToWp: WP-Plugin not available')
		wpid = 'WP-Plugin not available'
		return wpid, restData
	end
	
	local n = 0
	local hash = 'Basic ' .. publishSettings['hash']
	local httphead = {
		{field='Authorization', value=hash},
	}
	local result
	local headers
    
	local url = publishSettings['siteURL'] .. "/wp-json/wp/v2/media/" .. wpid
	local WPalt = publishSettings['WPalt'][1]
	local WPdescr = publishSettings['WPdescr'][1]
	local WPcap = publishSettings['WPcap'][1]

	
	for k, v in pairs(photoMeta) do
		
	  -- LR Caption (caption) to write into WordPress REST-Fields	
	  if k == 'caption' and v ~= '' and v ~= nil and v ~= 'nil' then 
		v = urlencode(v) -- der wert muss für dt. Umlaute und leerzeichen encoded werden, aber nur der Wert!

		-- select which WP REST-Field will be filled with caption 
		if WPalt == 'LRcap' then
			local str = 'alt_text=' .. v
			url = url .. pre(n) .. str
			n = n + 1
		end

		if WPdescr == 'LRcap' then
			local str = 'description=' .. v
			url = url .. pre(n) .. str
			n = n + 1
		end

		if WPcap == 'LRcap' then
			local str = 'caption=' .. v
			url = url .. pre(n) .. str
			n = n + 1
			
			if docaption then
				url = url .. "&docaption=true"
			end
		end

	  end
	  
	  -- LR Title to write into WordPress REST-Fields
	  if k == 'title' and v ~= '' and v ~= nil and v ~= 'nil' then 
		v = urlencode(v) -- der wert muss für dt. Umlaute und leerzeichen encoded werden, aber nur der Wert!

		local str = 'title=' .. v -- der Titel wird immer fix in den Titel geschrieben
		url = url .. pre(n) .. str
		n = n + 1

		-- select which WP REST-Field will be filled with title
		if WPalt == 'LRtit' then
			local str = 'alt_text=' .. v
			url = url .. pre(n) .. str
			n = n + 1
		end

		if WPdescr == 'LRtit' then
			local str = 'description=' .. v
			url = url .. pre(n) .. str
			n = n + 1
		end

		if WPcap == 'LRtit' then
			local str = 'caption=' .. v
			url = url .. pre(n) .. str
			n = n + 1

			if docaption then
				url = url .. "&docaption=true"
			end
		end		

      end
	  ---------------------------------
	  
	  if k == 'gallery' and v ~= '' and v ~= nil and v ~= 'nil' then
		v = urlencode(v)
		local str = 'gallery=' .. v
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
  
	if restdata == nil 
		or restdata == '' 
		or restdata == 'nil' 
		or restdata == {} 
		or result[i].media_details == nil
		or result[i].media_type == 'file' 
		or result[i].mime_type == "image/x-icon"  
	then -- mime_type = \"image/x-icon\"
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
		  origurl = result[i].guid.rendered,
		  MD5 =  result[i].md5_original_file, -- table contains MD5 und filesize of fname on server
		  mime = result[i].mime_type,
		  } 
   
	return row
end
  
-- Write extracted Rest-meta-Data to customMetadata in Lightroom Catalog
function WriteCustomMetaData( publishSettings, photo, restmetadata )
	 -- Achung: muss innerhalb von catalog:withWriteAccessDo('unique-ID', function () ... end) aufgerufen werden
	
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
--LrMobdebug.on()
	-- Folgende Annahmen: Nach dem ersten SYNC wird mit WP nicht mehr im Media-Cat gearbeitet. NIE!
	-- Auch mit FTP wird nicht mehr hochgeladen. NIE!
	-- Nur dann, KANN es keine Dateien geben, die zwar im Folder sind aber noch nicht in WP sind oder LR nicht zugeordnet wurden, d.h. WP und LR sind dann immer synchron.
	-- Wenn das geünscht wird, muss im WP-Plugin die Funktion bei der Route 'addtofolder' erweitert werden
	-- Bei GET: Liefert alle WPIDs zu allen Original-Files im Folder. Zusätzlich werden alle Dateien, die nicht in WP sind gelistet als eigener Key in der REST-Antwort
	-- Bei POST mit addtofolder, wird mit dem JPG-Body das WP-Bild mit WPID entweder updated oder ohne WPID die bestehende JPG-Datei überschrieben und dann zu WP ergänzt
	-- In beiden Fällen bei POST wird die WPID als ID zurückgeliefert und der Ablauf in LR-LUA in dieser Funktion kann gleichbleiben! 
	Log('AddNewMedia called')
	local hash = 'Basic ' .. publishSettings['hash']
	local filen = filename
	local wpid = 0
	local restData = {}
	local url = ''
	local httphead
	local mime = 'image/jpeg'
	local doConversion = publishSettings['doConversion']
	local conversionQuality = publishSettings['conversionQuality']
	local fileFormat = publishSettings['fileFormat']
	local reduceMetaData = publishSettings['reduceMetaData']
	local generateSubsizes = publishSettings['generateSubsizes']
	local convertStatus = publishSettings['webpStatus']
	local convertLib = 'none'
	local exiftoolPath = getExecutablePath('exiftool')
	local exiftoolCmd = exiftoolPath and quote(exiftoolPath) or nil
  
	-- check parameters
	if publishSettings == {} or publishSettings['hash'] == '' or publishSettings['siteURL'] == '' or filename == '' or path == '' then
	  wpid = 'Internal: Wrong function call of AddNewMedia. Parameter mismatch'
	  Log('Added Media 1: ', wpid)
	  Log('path: ', path, 'filename: ', filename, 'hash: ', publishSettings['hash'], 'siteURL: ', publishSettings['siteURL'], 'hash: ',hash)
	  return wpid, restData
	end
	
	-- check reachability of WP-site and Plugin
	local result = CheckLogin( publishSettings )
	if tableHasKey( result, 'error' ) then
		Log('AddNewMedia: ', result['error'])
		wpid = result['error']
		return wpid, restData
	end
	if not publishSettings.wpplugin then
		Log('AddNewMedia: WP-Plugin not available')
		wpid = 'WP-Plugin not available'
		return wpid, restData
	end

	-- check the image conversion library and prepare the conversion command accordingly. 
	-- the convertStatus is either 'libvips is installed! ...' or 'ImageMagick is installed! ...' or 'No library for conversion found ...'
	-- The convertLib shall be set to either 'libvips' or 'magick' or 'none' accordingly. 
	if doConversion then
		Log('webPStatus: ', convertStatus)
		convertLib = getConversionLibraryFromStatus( convertStatus )
		Log('convertLib: ', convertLib)
	end

	-- get the dimensions of the original image
	local dimensions = LrPhotoInfo.fileAttributes( path )
	local w = dimensions.width
	local h = dimensions.height
	Log('WP-Dimensions: ', w, h)

	-- reduce Metadata
	if reduceMetaData then
		local cmd2 = ''
		if exiftoolCmd then
			cmd2 = "exiftool -P -adobe:all= -photoshop:all= -thumbnailimage= -software= -serialnumber=0 -lensserialnumber=0 -xmp:all= -tagsFromFile " .. quote(path) .. " -XMP-iptcCore:all -XMP-dc:all -XMP-xmpRights:all " .. quote(path)
			execWithOutput( cmd2 )

			cmd2 = "exiftool -SensitivityType= -RecommendedExposureIndex= -MeteringMode= -LightSource= -Flash= -SubSecTimeOriginal= -SubSecTimeDigitized= -SensingMethod= -FileSource= -SceneType= -CFAPattern= -ExposureMode= -WhiteBalance= -SceneCaptureType= -GainControl= -Contrast= -Saturation= -Sharpness= -SubjectDistanceRange= " .. quote(path)
			execWithOutput( cmd2 )
		else
			Log('exiftool not found in PATH')
			wpid = 'Internal: exiftool not found in PATH. Required for Metadata reduction.'
			return wpid, restData
		end
	end
	
	-- create the new file if webp or avif if set
	if doConversion and fileFormat == 'WEBP' and convertLib ~= 'none' then
		mime = 'image/webp'
		local cmd = ''
		local cmd2 = ''
		local newfile = string.gsub( path, '%.jpg$', '.webp')
		-- convert jpg file to webp with imagick. Must be installed

		if convertLib == 'magick' then
			cmd = "magick " .. quote(path) .. " -quality " .. conversionQuality .. " -define webp:auto-filter=true " .. quote(newfile)
		else
			cmd = "vips copy " .. quote(path) .. " " .. quote(newfile .. "[Q=" .. conversionQuality .. ",smart_subsample=true,effort=4]")
			cmd2 = "exiftool -overwrite_original -all= -TagsFromFile " .. quote(path) .. " -EXIF:all -XMP:all -ICC_PROFILE:all " .. quote(newfile)
		end

		execWithOutput( cmd ) 
		if cmd2 ~= ''  then
			execWithOutput( cmd2 )
		end
		Log('Webp-Path: ', newfile)
		filen = string.gsub(filen, '%.jpg$', '.webp')
		Log('Webp-file:', filen)
		LrTasks.sleep(0.1)
		path = newfile

	elseif doConversion and fileFormat == 'AVIF' and convertLib ~= 'none' then
		mime = 'image/avif'
		local cmd = ''
		local newfile = string.gsub( path, '%.jpg$', '.avif')
		-- convert jpg file to avif with imagick. Must be installed
		
		if convertLib == 'magick' then
			cmd = "magick " .. quote(path) .. " -quality " .. conversionQuality .. " " .. quote(newfile)
		else
			cmd = "vips copy " .. quote(path) .. " " .. quote(newfile .. "[Q=" .. conversionQuality .. ",effort=4]")
			cmd2 = "exiftool -overwrite_original -all= -TagsFromFile " .. quote(path) .. " -EXIF:all -XMP:all  -ICC_PROFILE:all " .. quote(newfile)
		end

		execWithOutput( cmd )
		if cmd2 ~= ''  then
			execWithOutput( cmd2 )
		end
		Log('Avif-Path: ', newfile)
		filen = string.gsub( filen, '%.jpg$', '.avif' )
		Log('Avif-file:', filen)
		LrTasks.sleep(0.1)
		path = newfile

	end

	-- generate and upload sub-sizes if set. For all file types
	if generateSubsizes and not defaultcoll then
		-- generate the filenames
		sizes = getImageSubsizes(publishSettings, hash)
		Log('WP-Subsizes: ', sizes)

		files = generateFileNames(w,h, filen,sizes)
		Log('WP-Files: ', files)
		
		-- generate the sub-sizes in a loop and upload them to wordpress
		for key,_ in pairs(sizes) do
			local newfilen = sizes[key].file
			local baseName = newfilen:match("^(.*)%.")
			local newpath = string.gsub(path, "([^\\]+)%.([^%.]+)$", baseName .. ".%2")
			Log('newpath: ', newpath)

			-- resize the image
			resizeImage(path, newpath, sizes[key].width, sizes[key].height, sizes[key].crop, conversionQuality, mime, convertLib)

			-- upload the image CASE 1: new file, subsize, special folder
			uploadMedia(newpath,           -- path to the file
						newfilen,          -- filename
						publishSettings,   -- table with settings including siteURL
						hash,              -- authorization hash
						mime,              -- mime type of the file
						defaultcoll,       -- boolean for default collection
						folder,            -- folder path or empty string
						'filetofolder',     -- route
						0                 -- The WP ID of the media 
				)
		end
	end

	-- upload the image CASE 2: new image to wordpress, original, WPCat and CASE 3: new image to wordpress, original, special folder
	local result, headers = uploadMedia(path, filen, publishSettings, hash, mime, defaultcoll, folder, 'addtofolder', 0)
	
	-- Extract data from the Response to the Create-Request
	if headers.status == 201 and wpid ~= nil then -- Antwort aus REST bei default-collection mit "/wp-json/wp/v2/media/"
		result = JSON:decode(result)
		wpid = tonumber(result['id'])
		restData = ExtractDataFromREST(result)
  
	elseif headers.status == 200 and wpid ~= nil then -- Antwort auf wp-plugin wpcat_json_rest mit "/wp-json/extmedialib/v1/addtofolder/"
		result = JSON:decode(result)
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
		wpid = 'Upload: Fault during upload to WP: ' .. filen .. '.\nHeader-Status: ' .. tostring(headers.status) .. '\nMessage: ' .. inspect(result)
	end

	Log('AddNewMedia url: ' .. url .. ' filen ' .. filen)
	Log('http: ' .. inspect(headers.status) .. ' ID ' .. inspect(wpid))
	Log('result: ' .. inspect(result))
	Log('Added Media 3: ', inspect(wpid) )

	return wpid, restData
end
  
-- Update Media File to WP-Media-Catalog via REST-API
function UpdateMedia( publishSettings, filename, path, defaultcoll, folder, wpid ) 
	local hash = 'Basic ' .. publishSettings['hash']
	local filen = filename
	local restData = {}
	local mime = 'image/jpeg'
	local doConversion = publishSettings['doConversion']
	local conversionQuality = publishSettings['conversionQuality']
	local fileFormat = publishSettings['fileFormat']
	local reduceMetaData = publishSettings['reduceMetaData']
	local generateSubsizes = publishSettings['generateSubsizes']
	local convertStatus = publishSettings['webpStatus']
	local convertLib = 'none'
	local exiftoolPath = getExecutablePath('exiftool')
	local exiftoolCmd = exiftoolPath and quote(exiftoolPath) or nil
	
	-- check parameters
	if publishSettings == {} or publishSettings['hash'] == '' or publishSettings['siteURL'] == '' or filename == '' or path == '' then
		wpid = 'Internal: Wrong function call of AddNewMedia. Parameter mismatch'
		Log('Update Media 1: ', wpid)
		return wpid, restData
	end
	
	-- check reachability of WP-site and Plugin
	local result = CheckLogin( publishSettings )
	if tableHasKey( result, 'error' ) then
		Log('UpdateMedia: ', result['error'])
		wpid = result['error']
		return wpid, restData
	end
	if not publishSettings.wpplugin then
		Log('UpdateMedia: WP-Plugin not available')
		wpid = 'WP-Plugin not available'
		return wpid, restData
	end

	-- check the image conversion library and prepare the conversion command accordingly. 
	if doConversion then
		Log('webPStatus: ', convertStatus)
		convertLib = getConversionLibraryFromStatus( convertStatus )
		Log('convertLib: ', convertLib)
	end

	-- get the dimensions of the original image
	local dimensions = LrPhotoInfo.fileAttributes( path )
	local w = dimensions.width
	local h = dimensions.height
	Log('WP-Dimensions: ', w, h)
	
	-- reduce Metadata
	if reduceMetaData then
		local cmd2 = ''
		if exiftoolCmd then
			cmd2 = "exiftool -P -adobe:all= -photoshop:all= -thumbnailimage= -software= -serialnumber=0 -lensserialnumber=0 -xmp:all= -tagsFromFile " .. quote(path) .. " -XMP-iptcCore:all -XMP-dc:all -XMP-xmpRights:all " .. quote(path)
			execWithOutput( cmd2 )

			cmd2 = "exiftool -SensitivityType= -RecommendedExposureIndex= -MeteringMode= -LightSource= -Flash= -SubSecTimeOriginal= -SubSecTimeDigitized= -SensingMethod= -FileSource= -SceneType= -CFAPattern= -ExposureMode= -WhiteBalance= -SceneCaptureType= -GainControl= -Contrast= -Saturation= -Sharpness= -SubjectDistanceRange= " .. quote(path)
			execWithOutput( cmd2 )
		else
			Log('exiftool not found in PATH')
			wpid = 'Internal: exiftool not found in PATH. Required for Metadata reduction.'
			return wpid, restData
		end
	end

		-- create the new file if webp or avif if set
	if doConversion and fileFormat == 'WEBP' and convertLib ~= 'none' then
		mime = 'image/webp'
		local cmd = ''
		local cmd2 = ''
		local newfile = string.gsub( path, '%.jpg$', '.webp')
		-- convert jpg file to webp with imagick. Must be installed

		if convertLib == 'magick' then
			cmd = "magick " .. quote(path) .. " -quality " .. conversionQuality .. " -define webp:auto-filter=true " .. quote(newfile)
		else
			cmd = "vips copy " .. quote(path) .. " " .. quote(newfile .. "[Q=" .. conversionQuality .. ",smart_subsample=true,effort=4]")
			cmd2 = "exiftool -overwrite_original -all= -TagsFromFile " .. quote(path) .. " -EXIF:all -XMP:all -ICC_PROFILE:all " .. quote(newfile)
		end

		execWithOutput( cmd ) 
		if cmd2 ~= ''  then
			execWithOutput( cmd2 )
		end
		Log('Webp-Path: ', newfile)
		filen = string.gsub(filen, '%.jpg$', '.webp')
		Log('Webp-file:', filen)
		LrTasks.sleep(0.1)
		path = newfile

	elseif doConversion and fileFormat == 'AVIF' and convertLib ~= 'none' then
		mime = 'image/avif'
		local cmd = ''
		local newfile = string.gsub( path, '%.jpg$', '.avif')
		-- convert jpg file to avif with imagick. Must be installed
		
		if convertLib == 'magick' then
			cmd = "magick " .. quote(path) .. " -quality " .. conversionQuality .. " " .. quote(newfile)
		else
			cmd = "vips copy " .. quote(path) .. " " .. quote(newfile .. "[Q=" .. conversionQuality .. ",effort=4]")
			cmd2 = "exiftool -overwrite_original -all= -TagsFromFile " .. quote(path) .. " -EXIF:all -XMP:all  -ICC_PROFILE:all " .. quote(newfile)
		end

		execWithOutput( cmd )
		if cmd2 ~= ''  then
			execWithOutput( cmd2 )
		end
		Log('Avif-Path: ', newfile)
		filen = string.gsub( filen, '%.jpg$', '.avif' )
		Log('Avif-file:', filen)
		LrTasks.sleep(0.1)
		path = newfile

	end

	-- generate and upload sub-sizes if set. For all file types
	if generateSubsizes and not defaultcoll then
		-- generate the filenames
		sizes = getImageSubsizes(publishSettings, hash)
		Log('WP-Subsizes: ', sizes)

		files = generateFileNames(w,h, filen,sizes)
		Log('WP-Files: ', files)
		
		-- generate the sub-sizes in a loop and upload them to wordpress
		for key,_ in pairs(sizes) do
			local newfilen = sizes[key].file
			local baseName = newfilen:match("^(.*)%.")
			local newpath = string.gsub(path, "([^\\]+)%.([^%.]+)$", baseName .. ".%2")
			Log('newpath: ', newpath)

			-- resize the image
			resizeImage(path, newpath, sizes[key].width, sizes[key].height, sizes[key].crop, conversionQuality, mime, convertLib)

			-- upload the image CASE 4: update file, subsize, special folder
			uploadMedia(newpath,           -- path to the file in local file system
						newfilen,          -- filename
						publishSettings,   -- table with settings including siteURL
						hash,              -- authorization hash
						mime,              -- mime type of the file
						defaultcoll,       -- boolean for default collection
						folder,            -- folder path or empty string
						'updatefile',      -- route
						wpid                  -- The WP ID of the file to update
				)
		end
	end
	
	-- upload the updated and unscaled image which was generated by Lightroom
	-- CASE 5: update image in WordPress, original, special folder and WPCat
	local result, headers = uploadMedia(path, filen, publishSettings, hash, mime, defaultcoll, folder, 'updatemedia', wpid)

	if headers.status == 200 then
		result = JSON:decode(result)
	else
		wpid = 'Update Media Fault: ' .. tostring((headers.status or 'nil') .. ' : ' .. filen)
	end
	
	return wpid, result
end
  
-- Get all Media Files / one Medie File from WP-Media-Catalog via REST-API. Provide response as JSON
-- param: page : wenn nicht angegeben, dann muss perpage eine wpid sein!
-- TODO use parameter _fields with request : ..../media/<wpid>?_fields=id,gallery,filen,MD5 to shorten the transferred data.
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
	
	-- check reachability of WP-site and Plugin
	local result = CheckLogin( publishSettings )
	if tableHasKey( result, 'error' ) then
		Log('DeleteMedia: ', result['error'])
		wpid = result['error']
		return wpid, {}
	end
	if not publishSettings.wpplugin then
		Log('DeleteMedia: WP-Plugin not available')
		wpid = 'WP-Plugin not available'
		return wpid, {}
	end
	
	local hash = 'Basic ' .. publishSettings.hash
	  local httphead = {
		{field='Authorization', value=hash},
	  }
	local url = ''  
	
	url = publishSettings.siteURL .. "/wp-json/wp/v2/media/" .. tostring(wpmediaid) .. "?force=1"
	--http://127.0.0.1/wordpress/wp-json/wp/v2/media/3439?force=1
	--http-method: delete   
	local result, headers = LrHttp.post( url, '', httphead, 'DELETE' )
  
	if headers.status == 200 then
		result = JSON:decode(result)
		result = result['deleted']
	elseif headers.status == 404 then -- also successful, ID is not available
		result = JSON:decode(result)
		result = result['code']
		Log('Delete Code 404: ' .. tostring(wpmediaid) .. '. HTTP-Status: ' .. tostring(headers.status) .. ' Message: ' .. inspect(result))
	else 
		Log('Could not delete Media ID ' .. tostring(url) .. ' / HTTP-Status: ' .. tostring(headers.status) .. ' Message: ' .. inspect(result))
	end
	
	return result
end
  
-- Serch pre-selected Images in LR Database, exclude Copies, marked by "Kopie.."
-- special selection if more then on photo found. Selector: "Rot"
-- This runs as asynchronous Task! Main Task has to wait. No Signalling between Tasks.
-- add found photos to WP-LR-Sync-Collection
function addToWPColl (collection, search, photos, all_collections, all_paths)
	
	LrTasks.startAsyncTask(function ()
		--LrMobdebug.on()
		local str =inspect(all_paths)
		Log('Paths in addToWPColl: ', str)
		local catalog = LrApplication.activeCatalog()
		local selphoto
		local specialsearch = true
		local lrid = {}
			
		for i=1, #photos do

			local filen = photos[i].filen
			local base = ''
			local ext = ''
			photos[i].lrid = {}

			if filen == nil or filen == 'nil' then 
				local str = inspect(photos[i])
				Log('Filename nicht definiert. Nr : ' .. i .. str)
			else
				base, ext = SplitFilename(filen)
			end

			if ext == 'gif' or ext == 'GIF' or ext == '' or filen == nil or filen == 'nil' then
					-- do nothing : skip	
			else 
				---- M I : search virt. Copy --------------------------
				lrid = catalog:findPhotos {
					searchDesc = {
						{
							criteria = "copyname",
							operation = "any",
							value = base,
							value2 = "",
						},
						{
							criteria = "filename",
							operation = "noneOf",
							value = base,
							value2 = "",
						},
						combine = "intersect",
					},
				}

				---- M II : search basename with wildcard --------------------------
				if #lrid == 0 then
					base = string.gsub( base,"[-_]"," ") -- in LR funktioniert die Suche aber nur mit einem Leerzeichen
					--base = string.gsub( base,"_"," ")

					lrid = catalog:findPhotos {
						searchDesc = {
							{
								criteria = "filename",
								operation = "all",
								value = base,
							},
							{
								criteria = "copyname",
								operation = "noneOf",
								value = base,
							},
							combine = "intersect",
						},
					}

					if #lrid > 1 then
						local newlrid = {}

						for k, photo in ipairs(lrid) do
							local lrfilename = photo:getFormattedMetadata( 'fileName' )
							local base4search = '^' .. string.gsub( base," ","[-_]") .. '%.'
							local result = string.match(lrfilename, base4search)
							if result ~= nil then
								Log('  ' .. inspect(lrfilename) .. '  ' .. inspect(base4search) ..'  ' .. inspect(result))
								--table.insert(newlrid, photo)
								newlrid[ #newlrid +1 ] = photo
							end
						end

						lrid = newlrid

					end

				end

				--------- Auswahl bei mehr als einem gefundenen Foto
				if lrid[2] ~= nil and specialsearch then
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
				
				if #lrid > 0 then
					photos[i].lrid = lrid -- Speichern der gefundenen Fotos in der Tabelle
				end
				----------------------------
				
				-- Collection bestimmen
				local new_collection
				local path = photos[i]['path']
				local index = 0
						
				index = findValueInArray(all_paths, path)
				if index > 0 then
					new_collection = all_collections[index]
				else
					new_collection = collection
				end

				local name = new_collection:getCollectionInfoSummary()['name']
				--Log(path .. '=' .. name)
				Log(photos[i].filen .. '; --> ; ' .. base .. '; N lrid = ;' .. #lrid .. '; Coll ; '.. name)	

				--[[
				if #lrid > 0 then
					catalog:withWriteAccessDo( 'AddtoWP', function () 
							new_collection:addPhotos(lrid)
					end ) 
				end
				]]
			end

		end -- end for photos
		
	end )

end

-- Update image_meta keys of Media File to WP-Media-Catalog via REST-API
-- @param wpid number or integer the Wordpress id as integer
function UpdateKeys( publishSettings, photometa, wpid ) 
	local hash = 'Basic ' .. publishSettings['hash']
	  
	if publishSettings == {} or publishSettings['hash'] == '' or publishSettings['siteURL'] == '' then
	  return
	end
	
	-- check reachability of WP-site and Plugin
	local result = CheckLogin( publishSettings )
	if tableHasKey( result, 'error' ) then
		Log('UpdateKeys: ', result['error'])
		wpid = result['error']
		return wpid, {}
	end
	if not publishSettings.wpplugin then
		Log('UpdateKeys: WP-Plugin not available')
		wpid = 'WP-Plugin not available'
		return wpid, {}
	end
	
	local httphead = {
		{field='Authorization', value=hash},
		{field='Content-Type', value='application/json'},
	}
  
  	-- restData['image_meta'] = photometa
	local image_meta = JSON:encode(photometa)
	Log('WPid: ', wpid)
	local url = publishSettings['siteURL'] .. "/wp-json/extmedialib/v1/update_meta/" .. tostring(wpid)
	Log('Url for image_meta: ', url)
	Log('meta as json:', inspect(image_meta) )
	  
	local result, headers = LrHttp.post( url, image_meta, httphead )
	Log('UpdateKeys http-status: ', headers.status)
	if headers.status == 200 then
		result = JSON:decode(result)
		--wpid = tonumber(result['id'])
		--restData = ExtractDataFromREST(result)
	else
		  wpid = 'Update Key Fault: ' .. tostring(headers.status)
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

-- get Metadata from photo and return as json table
function getWebpMetaData ( photo )

	local aspect = photo:getRawMetadata( 'aspectRatio' )
	local orientation = 0

	if aspect > 1.0 then
		orientation = 1
	else
		orientation = 0
	end

	local time = photo:getRawMetadata( 'dateTimeOriginal' )
	if time == nil or time == '' or time == 'nil' then 
		time = ''
	else
		time = tostring( 978307200 + time )
	end

	local WebpPhotoMeta = { 
		image_meta = {
			aperture          = tostring( photo:getRawMetadata( 'aperture' ) ),
			credit            = photo:getFormattedMetadata( 'artist' ),
			camera            = photo:getFormattedMetadata( 'cameraModel' ),
			caption           = photo:getFormattedMetadata( 'caption' ),
			created_timestamp = time,
			copyright         = photo:getFormattedMetadata( 'copyright' ),
			focal_length      = tostring( photo:getRawMetadata( 'focalLength35mm' ) ),
			iso               = tostring( photo:getRawMetadata( 'isoSpeedRating' ) ),
			shutter_speed     = string.sub( tostring( photo:getRawMetadata( 'shutterSpeed' ) ), 1, 10),
			title             = photo:getFormattedMetadata( 'title' ),
			orientation       = tostring( orientation ),
			keywords          = strsplit( photo:getFormattedMetadata('keywordTagsForExport'), ', ' ) -- return keys as table
		}
	}
	
	return WebpPhotoMeta
end

-- Functions for local generation of image subsizes
function getImageSubsizes(publishSettings, hash)
	local url = publishSettings['siteURL'] .. "/wp-json/extmedialib/v1/imagesubsizes"
	local httphead = {
			{field='Authorization', value=hash},
		}
    -- Make the HTTP GET request to the WordPress REST API
	local result, headers = LrHttp.get( url, httphead )
    
    -- Parse the JSON response
    local response = JSON:decode(result)
    
    -- Initialize array to store the sizes
    local sizesArray = {}
    
    -- Check if we have a valid response with sizes
    if response and response.sizes then
        -- Convert the sizes object to an array format
        for name, details in pairs(response.sizes) do
            table.insert(sizesArray, {
                name = name,
                width = details.width,
                height = details.height,
                crop = details.crop
            })
        end
    end
    
    -- Return the array of sizes
    return sizesArray
end

function generateFileNames(origWidth, origHeight, fileName, dimensions)
    local origAspect = origWidth / origHeight

    local baseName = fileName:match("^(.*)%.")
    local extension = fileName:match("%.([^%.]+)$")

    local new = {}

    for k, dim in pairs(dimensions) do

        local crop = dim.crop
        local newWidth = dim.width or 0
        local newHeight = dim.height or 0

        -- Normalize 9999 → 0
        if newWidth >= 9999 then newWidth = 0 end
        if newHeight >= 9999 then newHeight = 0 end

        local finalW, finalH

        if crop and newWidth > 0 and newHeight > 0 then
            -- exakt wie PHP
            finalW = newWidth
            finalH = newHeight

        else
            if newWidth > 0 and newHeight > 0 then
                -- beide gesetzt → proportional einpassen
                local targetAspect = newWidth / newHeight

                if targetAspect > origAspect then
                    -- begrenzt durch Höhe
                    finalH = newHeight
                    finalW = round(newHeight * origAspect)
                else
                    -- begrenzt durch Breite
                    finalW = newWidth
                    finalH = round(newWidth / origAspect)
                end

            elseif newWidth > 0 then
                -- nur Breite vorgegeben
                finalW = newWidth
                finalH = round(newWidth / origAspect)

            elseif newHeight > 0 then
                -- nur Höhe vorgegeben
                finalH = newHeight
                finalW = round(newHeight * origAspect)

            else
                -- nichts gesetzt → Original
                finalW = origWidth
                finalH = origHeight
            end
        end

        local suffix = tostring(finalW) .. "x" .. tostring(finalH)

        dim.file = baseName .. "-" .. suffix .. "." .. extension
        dim.width = finalW
        dim.height = finalH

        new[k] = dim
    end

    return new
end

-- Function to resize an image. Returns nothing
function resizeImage(path, newpath, width, height, crop, quality, mime, convertLib)
	local cmd = ''
	local resize = ''
	local widthNum = tonumber(width) or 0
	local heightNum = tonumber(height) or 0
	local widthStr = tostring(widthNum)
	local heightStr = tostring(heightNum)
	local settings2 = ''
	local minquality = 30
	local newquality = 0
	local area = widthNum * heightNum
	newquality = math.min(quality, math.max(minquality, math.floor(quality * (area / 4369920))));

	-- check if the input file exists
	if not LrFileUtils.exists(path) then
		Log('Resize: Input file does not exist: ', path)
		return
	end

	if convertLib == 'magick' then
		-- general settings for all image types
		local settings1 = ' -filter Triangle -define filter:support=2.0 -colorspace sRGB -dither None -interlace none -unsharp 0.25x0.25+8+0.065 -depth 8'
		if mime == 'image/avif' then
			-- settings for AVIF
			settings2 = ' -define heic:speed=5 -define heic:compression-effort=5 -define heic:threads=3 -define avif:effort=5 -define avif:threads=3'
		elseif mime == 'image/webp' then
			-- settings for WEBP
			settings2 = ' -define webp:method=6 -define webp:low-memory=false'
		elseif mime == 'image/jpeg' then
			-- settings for JPEG
			settings2 = ' -define jpeg:fancy-upsampling=off -define jpeg:sampling-factor=4:2:0'	
		else
			Log('Unsupported MIME type for magick: ', mime)
		end
		settings1 = settings1 .. settings2

		if crop then
			resize=widthStr .. 'x' .. heightStr ..'!'
		else
			resize=widthStr
		end

		if WIN_ENV then
			cmd = "magick \"" .. path .. "\" -quality " .. newquality .. settings1 .. " -resize " .. resize .. " \"" .. newpath .. "\"" 
		else
			cmd = "magick " .. path .. "\" -quality " .. newquality .. settings1 .. " -resize " .. resize .. " " .. newpath
		end

		execWithOutput(cmd)

	elseif convertLib == 'libvips' then
		local outTarget = ""
		local delCMD = WIN_ENV and "cmd /C del /Q " or "rm "
		local p2 = LrPathUtils.getStandardFilePath( 'temp' ) .. DIRSEP
		local tmp1 = p2 .."tmp_vips_1.v"
		local tmp2 = p2 .."tmp_vips_2.v"
		local tmp3 = p2 .."tmp_vips_3.v"
		local cmd1, cmd2, cmd3, cmd4, cmd5 = '', '', '', '', ''

		if mime == 'image/webp' then
			outTarget = newpath .. "[Q=" .. newquality .. ",effort=6,smart_subsample=true]"
		elseif mime == 'image/avif' then
			outTarget = newpath .. "[Q=" .. newquality .. ",effort=5]"
		elseif mime == 'image/jpeg' then
			outTarget = newpath .. "[Q=" .. newquality .. ",interlace=true]"
		else
			Log('Unsupported MIME type for libvips: ', mime)
		end

		if crop then
			cmd1 = "vips thumbnail " .. quote(path) .. " " .. quote(tmp1) .. " " .. widthStr .. " --height " .. heightStr .. " --crop attention" -- or " --crop center
		else
			cmd1 = "vips thumbnail " .. quote(path) .. " " .. quote(tmp1) .. " " .. widthStr
		end
		
		cmd2 = "vips sharpen " .. quote(tmp1) .. " " .. quote(tmp2) .. " --sigma=0.3 --x1=2 --y2=10 --y3=20 --m1=0 --m2=3"
		cmd3 = "vips copy " .. quote(tmp2) .. " " .. quote(outTarget)
		cmd4 = "exiftool -overwrite_original -all= -TagsFromFile " .. quote(path) .. " -EXIF:all -XMP:all -ICC_PROFILE:all " .. quote(newpath)
		cmd5 = delCMD .. " " .. quote(tmp1) .. " " .. quote(tmp2)
		
		execWithOutput(cmd1)
		execWithOutput(cmd2)
		execWithOutput(cmd3)
		execWithOutput(cmd4)
		execWithOutput(cmd5)
		
	else
		Log('No valid conversion library available for resizing. Please check the settings and the conversion status. Resize skipped.')
		return
	end
	
	return
end

function uploadMedia(newpath, newfilen, publishSettings, hash, mime, defaultcoll, folder, route, wpid)
	
	Log ('uploadMedia: ', newpath, newfilen, hash, mime, defaultcoll, folder, route)
	-- check the parameters for nil or empty
	if route == '' or route == nil or newfilen == nil or publishSettings == nil or hash == nil or mime == nil or folder == nil or defaultcoll == nil or newfilen == '' or publishSettings == '' or hash == '' or mime == '' or folder == '' or defaultcoll == ''  then
		return false, {}
	end

	local generateSubsizes = publishSettings['generateSubsizes']

	-- Check if the file exists
    if LrFileUtils.exists(newpath) then
        Log('Subsize-File exists: ', newpath)
        
        local url, httphead
		local headervalue = ''

        -- Differ between Standard-Collection for the WP-Standard-Cat or another folder in the WP uploads-directory. This is a gallery = collection in LR
        
		-- CASE 2: new image to wordpress, original, WPCat
		if defaultcoll and route == 'addtofolder' then
            url = publishSettings['siteURL'] .. "/wp-json/wp/v2/media/" -- uses the WP build in functionality to upload images via REST-API
			headervalue = 'form-data'
		
		-- CASE 3: new image to wordpress, original, special folder
		elseif route == 'addtofolder' then
            url = publishSettings['siteURL'] .. "/wp-json/extmedialib/v1/".. route .."/" .. folder -- uses the function of the REST-API-Plugin
			headervalue = 'attachment'

		-- CASE 1: new file, subsize, special folder (defaultcoll unused, not working in WP)
        elseif route == 'filetofolder' then
			-- if defaultcoll then folder = getWPStandardMediaFolder() end -- this should be used if the subsizes are uploaded to the WP-Standard-Cat before uploading the image
            url = publishSettings['siteURL'] .. "/wp-json/extmedialib/v1/".. route .."/" .. folder -- uses the function of the REST-API-Plugin
			headervalue = 'attachment'
		
		-- CASE 5: update image in WordPress, original, special folder and WPCat
		elseif route == 'updatemedia' and wpid ~= nil then
			-- upload the updated and unscaled image which was generated by Lightroom -- uses the function of the REST-API-Plugin
			-- changemime is added always, just in case. It does not disturb if not required.
			local subsizesuploaded = ''
			if generateSubsizes then
				subsizesuploaded = '&subsizesuploaded=true' -- we assume here that all subsizes were uploaded successfully
			end
			url = publishSettings['siteURL'] .. "/wp-json/extmedialib/v1/update/" .. tostring(wpid) .. "?changemime=true" .. subsizesuploaded
			headervalue = 'form-data'
		
		-- CASE 4: update file, subsize, special folder
		elseif route == 'updatefile' then
			--if defaultcoll then folder = getWPStandardMediaFolder() end -- this should be used if the subsizes are uploaded to the WP-Standard-Cat before updating the image
            url = publishSettings['siteURL'] .. "/wp-json/extmedialib/v1/filetofolder/" .. folder .. "?overwrite"
			headervalue = 'attachment'

        else
            local wpid = 'Internal: Wrong function call of AddNewMedia. Parameter mismatch'
            Log('Upload Media: ', wpid)
            return false, {}
        end
        
		httphead = {
			{field='Authorization', value=hash},
			{field='Content-Disposition', value= headervalue .. '; filename=' .. newfilen},
			{field='Content-Type', value=mime}
		}

        local imgfile = LrFileUtils.readFile(newpath)
        local result, headers = LrHttp.post(url, imgfile, httphead)
		Log('Upload-Result: ', headers.status, ' : ', url)
		Log('Upload-Result: ', inspect(result))
        return result, headers
    else
        Log('Subsize-File does not exist: ', newpath)
        return false, {}
    end
end

-- Parse conversion status text and return conversion library key.
-- Returns: 'libvips', 'magick', or 'none'.
function getConversionLibraryFromStatus(convertStatus)
	if type(convertStatus) ~= 'string' or convertStatus == '' then
		return 'none'
	end

	local status = string.lower(convertStatus)
	local hasInstalled = string.find(status, 'installed', 1, true) ~= nil

	if hasInstalled and string.find(status, 'libvips', 1, true) ~= nil then
		return 'libvips'
	end

	if hasInstalled and string.find(status, 'imagemagick', 1, true) ~= nil then
		return 'magick'
	end

	return 'none'
end