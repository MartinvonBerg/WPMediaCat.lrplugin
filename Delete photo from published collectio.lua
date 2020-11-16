-- Delete photo from published collection, delete in WP-Media-Catalog, delete MetaData in LR Catalog
-- Quelle: https://github.com/willthames/photodeck.lrdevplugin : PhotoDeckPublishServiceProvider.lua (Zeilen 313ff)
-- TODO: vereinfachen!
exportServiceProvider.deletePhotosFromPublishedCollection = function(publishSettings, arrayOfPhotoIds, deletedCallback, localCollectionId)
    Log('publishServiceProvider.deletePhotosFromPublishedCollection')
    LrMobdebug.on() 
    local catalog = LrApplication.activeCatalog()
    local LrPhotosToDelete = {}
    local publishedPhotoById = {}
    local photoIdsToUnpublish = {}
    local photoUnpublish = {}
    local result
    local error_msg = 'nix'
    
    -- this next bit is stupid. Why is there no catalog:getPhotoByRemoteId or similar
    local collection = catalog:getPublishedCollectionByLocalIdentifier(localCollectionId)
    local galleryId = collection:getRemoteId()
    local publishedPhotos = collection:getPublishedPhotos()
    
    for _, pp in pairs(publishedPhotos) do
      publishedPhotoById[pp:getRemoteId()] = pp
    end
  
    for i, photoId in ipairs( arrayOfPhotoIds ) do
      if photoId ~= "" then
        local publishedPhoto = publishedPhotoById[photoId]
        local catphoto = publishedPhoto:getPhoto()
        table.insert(LrPhotosToDelete, catphoto)
        table.insert(photoIdsToUnpublish, photoId)
        photoUnpublish[i] = {}
        photoUnpublish[i][1] = catphoto -- lr cat id
        photoUnpublish[i][2] = photoId  -- remote id
        photoUnpublish[i][3] = true  -- remote id
        photoUnpublish[i][4] = publishedPhoto
      end
    end
    
    --LrFunctionContext.postAsyncTaskWithContext( 'deletePhotos', function( context )
    LrTasks.startAsyncTask(function ()
      LrMobdebug.on()
      local hash = 'Basic ' .. publishSettings.hash
        local httphead = {
        {field='Authorization', value=hash},
      }
      local mypluginID = 'com.adobe.lightroom.export.wp_mediacat2' -- TODO: durch Variable ersetzen
      
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
          end
        end
      
        if (tonumber(wpid) > 0) and (difftime == 0) then
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
          Log('WP-Media deleted: ' ..tostring(wpid) )
        else
          photoUnpublish[i][3] = false
        end
      end
      error_msg = 'fertig'
    end, error_msg )
  
    LrTasks.sleep(2)
    Log('AsyncTask done', error_msg) 
  
    for k=1,#photoUnpublish do
      if photoUnpublish[k][3] then
        deletedCallback( photoUnpublish[k][2] )
      else
        catalog:withWriteAccessDo( 'ResetImage', function () 
          local publishedPhoto = photoUnpublish[k][4]
          publishedPhoto:setEditedFlag(false)
        end )
      end
     end
  
  end