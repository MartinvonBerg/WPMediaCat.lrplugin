--[[
	Main entry point for plugin.
]]
local LrDialogs = import( 'LrDialogs' )
local LrApplication = import( 'LrApplication' )
local LrDate = import( 'LrDate' )
local LrLogger = import 'LrLogger'
local inspect = require 'inspect'
local LrErrors = import 'LrErrors'
local LrFtp = import 'LrFtp'
local LrTasks = import 'LrTasks'
local LrBinding = import 'LrBinding'
local LrFunctionContext = import 'LrFunctionContext'
local LrHttp = import( 'LrHttp' )

local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
LrMobdebug.start()

local myLogger = LrLogger( 'NGGlog' )
myLogger:enable( "logfile" )
local function o2L( message )
	myLogger:trace( message )
end

JSON=require 'JSON'
require 'Dialogs'
require 'Post'
require 'Process'
require 'Logger'

local publishServiceProvider = {}

publishServiceProvider.small_icon = "Small-icon.png"

publishServiceProvider.supportsIncrementalPublish = 'only'							-- only publish. No export facility
publishServiceProvider.allowFileFormats = { 'JPEG' } 								-- jpeg only
publishServiceProvider.hidePrintResolution = true									-- hide print res controls
publishServiceProvider.canExportVideo = false 										-- video is not supported through this plug-in
publishServiceProvider.hideSections = { 'exportLocation' }							-- hide export location

publishServiceProvider.processRenderedPhotos = processRenderedPhotos				-- see process.jua

publishServiceProvider.startDialog = dialogs.startDialog							-- see dialogs.lua
publishServiceProvider.sectionsForTopOfDialog = dialogs.sectionsForTopOfDialog

publishServiceProvider.exportPresetFields = {
	{ key = "siteURL", default = "" },
	{ key = "loginName", default = "" },
	{ key = "loginPassword", default = "" },
	{ key = "hash", default = ""},
	{ key = "pwdok", default = "false"},
	{ key = "urlreadable", default = "false"},
}

-- menu titles, Albums, Galleries per NG rather then Collections & Sets
publishServiceProvider.titleForPublishedCollection = "NextGen2 Gallery"
publishServiceProvider.titleForPublishedCollectionSet = "NextGen2 Album"
publishServiceProvider.titleForPublishedSmartCollection = "Smart NextGen2 Album" 
publishServiceProvider.titleForGoToPublishedCollection = 'Sync with Wordpress'

local function GetMedia( publishSettings, perpage, page ) 
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

local function replhyphen(filen)
	filen = filen:reverse()
	local nfound = 0
	local newstring = filen

	for i = 1, filen:len() do
	local letter = filen:sub(i,i ) 
		if (letter == '-')  then
			if (nfound > 0) then
				newstring = newstring:sub(1,i-1) .. '_' .. newstring:sub(i+1,newstring:len())
			end
			nfound = nfound + 1
		end
	end

	filen = newstring:reverse()
	return filen
end

local function add2Cat (collection, file)
  local success = false
  local lrid = {}
    
    --LrTasks.startAsyncTask(function ()
    LrFunctionContext.postAsyncTaskWithContext('add2Cat', function (context)
    
    local catalog = LrApplication.activeCatalog()
    
    lrid = catalog:findPhotos {
      searchDesc = {
        criteria = "filename",
        operation = "==",
        value = file,
      }
    }
    --[[   
    catalog:withWriteAccessDo( 'AddtoWP', function () 
        collection:addPhotos(lrid)
        success = true
      end ) ]]    
    end, lrid)
  
  return lrid 
end

function publishServiceProvider.goToPublishedCollection( publishSettings, info )
  LrMobdebug.on()
  local collection = info.publishedCollection
  local catalog = LrApplication.activeCatalog()
  local nphotos = collection:getPhotos()
  local firstsync = 'false'
  local result
  local mediatable = {}
  local files = {}
  local len = 0
  local perpage = 100
  local getmore = true
  local runs = 0
  
  if nphotos[1] == nil then
    firstsync = 'true' -- TODO: noch als globale Variable definieren
  end
   
  if firstsync and publishSettings.urlreadable then
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
          row = {id = result[i].id, phurl = result[i].source_url, filen = result[i].media_details.sizes.full.file} 
          local index = runs * perpage + i
          files[index] = result[i].media_details.sizes.full.file
        else
          row = {id = result[i].id, phurl = result[i].source_url, filen = ''}
        end
        
        local index = runs * perpage + i
        mediatable[index] = row
        i = i+1
      end
      
      if len == perpage then
        getmore = true
        runs = runs +1
        
      else
        getmore = false
      end
      
    end
	LrDialogs.message ( string.format("Found %d Photos. Adding to collection now.", #mediatable),'','info')
  local foundph = {}
  local notfound = {}
  local nfound = 1
  local nnotfound = 1
  local lrid = {}
    
  for i=1,#mediatable do
      local filen = mediatable[i].filen
      local success = false
      filen = replhyphen(filen)
      --success = add2Cat(collection, filen)
   
                     
      if success then
        foundph[nfound] = mediatable[i]
        nfound = nfound +1
      else
        notfound[nnotfound] = mediatable[i]
        nnotfound = nnotfound +1
      end
  end

  end -- if firtsync
end -- function

-- collection or collection set rename callback
function publishServiceProvider.renamePublishedCollection( publishSettings, info )
  LrMobdebug.on()
	o2L('call renamePublishedCollection')
	local collection = info.publishedCollection
	local newName = info.name
	--local remoteID = collection:getRemoteId()
	local remoteID = 99
	local str = inspect(newName)
  local catalog = LrApplication.activeCatalog()
	o2L(str)
	
	--Debug.pauseIfAsked()
  
  local lrid = catalog:findPhotos {
		searchDesc = {
			criteria = "filename",
			operation = "==",
			value = 'Franken_2019_08-29.jpg' ,
		}
	} 

	--Debug.pauseIfAsked()
	catalog:withWriteAccessDo( 'AddtoWP', function () 
		collection:addPhotos(lrid)
		
		--pubid:setEditedFlag(false)
		--Debug.pauseIfAsked()
	end)
	
	Log( "Rename: " .. collection:getName() .. " to " .. newName  )

	if collection:type() == 'LrPublishedCollectionSet' then
		Log( "Renaming set to: ", newName )
		local result = Post( "album/rename", { aid = remoteID, name = newName }, publishSettings )
		Log( "rename returns", result )
	elseif collection:type() == 'LrPublishedCollection' then
		Log( "Renaming collection 2: ", newName )
		--local result = Post( "gallery/rename", { gid = remoteID, name = newName }, publishSettings )
    local result = 'created!'
		Log( "rename returns", result )
	end
	--Debug.pauseIfAsked()
end

-- reparent collection or collection set callback
function publishServiceProvider.reparentPublishedCollection( publishSettings, info )

	local data = {}

	local collection = info.publishedCollection
	local thisRemoteId = collection:getRemoteId()

	if #info.parents ~= 0 then 
		local newRemoteParentId = info.parents[#info.parents].remoteCollectionId
		local newRemoteParentName = info.parents[#info.parents].name

		data.newparent = newRemoteParentId
		Log( "new parent: ", data.newparent )
	end

	local parent = collection:getParent()
	if parent ~= nil then 		-- not a root collection
		data.parent = parent:getRemoteId()
		Log( "old parent: ",  data.parent )
	end

	if collection:type() == 'LrPublishedCollectionSet' then

		Log( "Reparenting set/album: ", thisRemoteId )
		data.aid = thisRemoteId
		local result = Post( "reparent", data, publishSettings )

	elseif collection:type() == 'LrPublishedCollection' then

		Log( "Reparenting collection/gallery: ", thisRemoteId )
		data.gid = thisRemoteId
		local result = Post( "reparent",  data, publishSettings )

	end
	--Debug.pauseIfAsked()

end

-- image delete callback.
function publishServiceProvider.deletePhotosFromPublishedCollection( publishSettings, arrayOfPhotoIds, deletedCallback )

	for i, photoId in ipairs( arrayOfPhotoIds ) do

		Log( string.format( "Deleting id: %d", photoId ));
		local result = Post( "image/delete",  { pid = photoId }, publishSettings )
		
		-- call the delete callback even if it fails on the Wordpress end
		-- ToDo: Need to fix it so REST doesn't return an error if the delete fails
		--			there's still a potential conflict here if the image is out of
		--			kilter between the server and the local.
		--if result ~= nil then
			deletedCallback( photoId )
		--end

	end
end
-- called when a collection or collection set is deleted
function publishServiceProvider.deletePublishedCollection( publishSettings, info  )

	local collection = info.publishedCollection
	local remoteID = collection:getRemoteId();
	local collectionName = collection:getName()

	-- ToDo: LR quits the op if there's even one failure. Need to delete all we can !! is this fixed??
	if collection:type() == 'LrPublishedCollectionSet' then
		Log( "Deleting set/album: ", remoteID )
		local result = Post( "album/delete", { aid = remoteID, name = collectionName }, publishSettings )
	elseif collection:type() == 'LrPublishedCollection' then
		Log( "Deleting collection/gallery: ", remoteID )
		local result = Post( "gallery/delete", { gid = remoteID, name = collectionName }, publishSettings )
	end

end

-- called when  collection (gallery) is added or renamed.
function publishServiceProvider.updateCollectionSettings( publishSettings, info )
  LrMobdebug.on()
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
function publishServiceProvider.updateCollectionSetSettings( publishSettings, info ) 
	Log( "update Collection Set Settings, creating new album", info.publishedCollection )
LrMobdebug.on()
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

publishServiceProvider.supportsCustomSortOrder = true  -- this must be set for ordering
function publishServiceProvider.imposeSortOrderOnPublishedCollection( publishSettings, info, remoteIdSequence )

	-- ToDo: LR gives an empty id sequence if count of images is 2 or less. Maybe
	-- why 2??
	if #remoteIdSequence == 0 then
		Log( "Sort: zero length id sequence. Nothing to sort")
		return
	end
	local result = Post( "gallery/sort", { sequence = remoteIdSequence }, publishSettings )
end


return publishServiceProvider
