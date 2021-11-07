-- Skript for Re-Syncing Metadata from WordPress
-- Write the data to title and caption. Use the selection for the capttion
-- to decide which data from WordPress is used: Description, Caption or alt_text.
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrProgressScope = import( 'LrProgressScope' )
require('PluginGlobals')


--local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
--LrMobdebug.start()

 
LrTasks.startAsyncTask(function ()
    --LrMobdebug.on()

    local pscope = LrProgressScope( {
      title = LOC "$$$/WP_MediaCat2/resyncPscope=Synching MetaData (WP->LR). Please Wait!",
    })
    
    local catalog = LrApplication.activeCatalog()
    
    -- Get the current active publishService that is triggering the action on complicated way.
    -- This did NOT work: publishServices = catalog:getPublishServices( pluginname or _PLUGIN ).
    local publishServices = catalog:getPublishServices()
    for _, pubservice in pairs( publishServices ) do
      local name = pubservice:getPluginId()
      if name == PiName then
        publishSettings = pubservice:getPublishSettings()
      end
    end

    -- Check WP-Metadata that shall be used for the LR caption
    local LRcap = publishSettings['LRcap'][1]
    
    -- Get the selected photos
    local photos = catalog:getTargetPhotos() -- array of LrPhoto not LrPublishedPhoto!
    
    for _, photo in pairs(photos) do
        --name = photo:getFormattedMetadata("fileName")
        wpid = photo:getPropertyForPlugin( _PLUGIN, 'wpid' )
        -- Get MetaData with REST-API
        data = GetMedia(publishSettings, wpid)  -- data = nil if wpid invalid or = 0
        data = ExtractDataFromREST(data)              -- data = {} if data-in = nil. Used: filen, gallery, MD5
        -- Write MetaData to photo according to selection
        if LRcap == 'WPdescr' then
          capvalue = data['descr']
        elseif LRcap == 'WPcap' then
          capvalue = data['caption']
        elseif LRcap == 'WPalt' then
          capvalue = data['alt']
        else
          capvalue = ''
        end
        
        catalog:withWriteAccessDo( 'Sync MetaData with WP', function ()
          photo:setRawMetadata( 'title', data['title'] )
          photo:setRawMetadata( 'caption',capvalue ) 
        end )  
    end

    --local timetable = {
    --  timeout = 0.1,
   -- }
    
    -- second loop to set the edited flag
    -- loop through all selected photos. Whe don't know the published photo yet.
    for _, photo in pairs(photos) do

        local allcoll = photo:getContainedPublishedCollections()

        -- loop through all published Collections that contain this photo
        for _, coll in pairs(allcoll) do
          local pubservice = coll:getService()
          local name = pubservice:getPluginId()

          -- if the published collection is in our current published service we found the right collection
          -- this works only because it is allowed to add one catalog-photo once! Special for this Plugin.
          if name == PiName then
            local collWithPhoto = coll
            local pubPhotos = collWithPhoto:getPublishedPhotos()

            -- now loop through all published photos that are contained in the collection
            for _, pubPhoto in pairs(pubPhotos) do
              local catPhoto = pubPhoto:getPhoto()

              -- finally we found the published photo that we recently updated it matches to the selected photo. 
              if catPhoto == photo then

                -- do update the edited flag only if it is set to true, means edited
                LrTasks.sleep(0.2)
                local editFlag = pubPhoto:getEditedFlag()

                if editFlag then
                  local remoteId = pubPhoto:getRemoteId()
                  Log('set edit flag after Sync: ', remoteId)

                  catalog:withWriteAccessDo( 'Set Edit Flag after Sync', function ()
                    pubPhoto:setEditedFlag(false) -- dies muss am publishedphoto gesetzt werden, nicht am LrPhoto!
                  end )

                  --LrDialogs.message( 'Flag set for ' .. remoteId)
                end 
              end
            end
          end
        end
    end

    -- prepare message as protocol
    --local msg = string.format( LOC "$$$/WP_MediaCat2/resyncMsg=Sync Protocol" .. "%q", filename)
    --LrDialogs.message( LOC "$$$/WP_MediaCat2/resyncHeader=Sync Metadata Result", msg)
    pscope:done()
end )