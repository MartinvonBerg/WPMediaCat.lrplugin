function exportServiceProvider.goToPublishedPhoto( publishSettings, info )
    LrMobdebug.on() 
    local photo = info.photo
    --local wpid = photo:getPropertyForPlugin( _PLUGIN, 'wpid', nil, true)
    local wpid = 0
    --local alt = photo:getFormattedMetadata( 'caption' )
    local alt = ''
    local message = 'Code for this Photo to add to a Wordpress-Blog:'
    local message2 = 'Copy and add to your blog ' .. wpid or 0
    local folder = info.publishedCollectionInfo.name 
    local parents = info.publishedCollectionInfo.parents
    local srcurl = '' -- https://www.mvb1.de/smrtzl/uploads/2020/10/Bike-Hike-Lago-Ischiator-35-scaled.jpg
    -------------- colltest-----------------
    local pubService = info.publishService
    local catalog = LrApplication.activeCatalog()
    local paths = {}
    local npaths = 1
    local sub
    local name = pubService:getName()
    local psid = pubService:getPluginId()
  
    -- Gefundene Pfade in paths zu collectionSets und Collections verarbeiten
    paths = {"Gallerie","Test1","Foto_Albums/Franken-Dennenlohe/","Albums/","Foto_Albums/Bike-Hike-Col-de-Peas/","Neu/",""}
    local str = inspect(paths)
    Log(paths)
    for m=1, #paths-1 do 
      local collections = strsplit(paths[m], '/' )
      local coll = collections[1]
      Log(coll)
      catalog:withWriteAccessDo( 'Create1stLevel', function ()
        local a = 1
        local exist = pubService:createPublishedCollectionSet( coll, nil, true )
        Log( inspect(exist))
      end)
    end
    -------------- colltest-----------------
    --[[
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
    ]]
  end