-- Skript for Re-Syncing Metadata from WordPress
-- Write the data to title and caption. Use the selection for the capttion
-- to decide which data from WordPress is used: Description, Caption or alt_text.
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
require('PluginGlobals')


local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
LrMobdebug.start()

 
LrTasks.startAsyncTask(function ()
    LrMobdebug.on()
    
    local catalog = LrApplication.activeCatalog()
    
    -- Warum muss das so kompliziert sein? der direkte aufruf funktioniert nicht.
    -- get the current active publishService that is triggering the action
    -- This did NOT work: publishServices = catalog:getPublishServices( pluginname or _PLUGIN )
    local publishServices = catalog:getPublishServices( )
    for _, pubservice in pairs( publishServices ) do
      local psID = pubservice.localIdentifier
      local name = pubservice:getPluginId()
      if name == PiName then
        publishSettings = pubservice:getPublishSettings()
      end
    end

    -- Check Metadata match
    local LRcap = publishSettings['LRcap'][1]
    
    local photos = catalog:getTargetPhotos() -- array of LrPhoto
    local filename = ''

    for _, pp in pairs(photos) do
        name = pp:getFormattedMetadata("fileName")
        wpid = pp:getPropertyForPlugin( _PLUGIN, 'wpid' )
        -- Get MetaData with REST-API
        data = GetMedia(publishSettings, wpid)  -- data = nil if wpid invalid or = 0
        data = ExtractDataFromREST(data)              -- data = {} if data-in = nil. Used: filen, gallery, MD5
        -- Write MetaData to photo according to selection
        --data['title'], abhängig von LRCap : data['caption'], data['alt'], data['descr']
        catalog:withWriteAccessDo( 'SyncLRMetaData', function ()
          pp:setRawMetadata( 'title', data['title'] )
          pp:setRawMetadata( 'caption', data['caption'] ) 
          --pp:setEditedFlag(false) -- dies muss am publishedphoto gesetzt werden, nicht am LrPhoto!
        end )
        
        filename = filename .. ' / wpid: ' .. wpid .. ' : ' .. name .. ' : ' .. data['title']
    end

    -- prepare message as protocol
    local msg = string.format( LOC "$$$/WP_MediaCat2/resyncMsg=Sync Protocol" .. "%q", filename)
    LrDialogs.message( LOC "$$$/WP_MediaCat2/resyncHeader=Sync Metadata Result", msg)
end )