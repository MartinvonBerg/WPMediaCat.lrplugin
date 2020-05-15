--[[
	Main publish loop
]]
local LrDate = import 'LrDate'
local LrPathUtils = import 'LrPathUtils'
local LrPhotoInfo = import 'LrPhotoInfo'
local LrFileUtils = import 'LrFileUtils'
local LrDialogs = import 'LrDialogs'
local LrStringUtils = import 'LrStringUtils'
local LrErrors = import 'LrErrors'
local LrTasks = import 'LrTasks'


function processRenderedPhotos( functionContext, exportContext )

	local exportSession = exportContext.exportSession
	local nPhotos = exportSession:countRenditions()

	local progressScope = exportContext:configureProgress {
		title = nPhotos > 1
			and LOC( "$$$/pnPublish/Publish/Progress=Publishing ^1 photos to NextGen", nPhotos )
			or LOC "$$$/pnPublish/Progress/One=Publishing one photo to NextGen",
	}

	Log( '%%%%%%%%%%%%%%%%%%%% start export %%%%%%%%%%%%%%%%%%%%%%%%' )
	Log( "% Publishing " .. nPhotos .. " image(s) to NextGen       %" )
	Log( '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%' )

	local Collectioninfo = exportContext.publishedCollectionInfo
	local CollectionName = Collectioninfo.name

	local GalleryID = exportContext.publishedCollectionInfo.remoteId
	if not GalleryID then  -- Gallery never got created in publishServiceProvider.updateCollectionSettings() something badly wrong
		LrErrors.throwUserError( "processRenderedPhotos(): Gallery " .. CollectionName .. " Doesn't exist on the server") 
	end

	local totalSecs = LrDate.currentTime()

	local nTasksRunning = 0	-- keep tracks on how many upload tasks are running
	local MaxTasks = 8		-- maximum number of upload tasks
	Log( string.format( "Max Upload Tasks %d", MaxTasks ))

	-- clear the log server log file so it doesn't get to huge. 
	local res = Post( "log/delete", { n=1 }, exportContext.propertyTable )

	for i, rendition in exportContext:renditions { stopIfCanceled = true } do

		local secs = LrDate.currentTime()
		
		progressScope:setPortionComplete( ( i - 1 ) / nPhotos )
		progressScope:setCaption( i .. " Of " .. nPhotos .. " Uploaded" )
		if progressScope:isCanceled() then break end

		local photo = rendition.photo

		if not rendition.wasSkipped then

			local success, pathOrMessage = rendition:waitForRender()
			
			progressScope:setPortionComplete( ( i - 0.5 ) / nPhotos )
			progressScope:setCaption( i .. " Of " .. nPhotos .. " Uploaded" )

			if progressScope:isCanceled() then break end

			if success then

				local fileName = LrPathUtils.leafName( pathOrMessage )
				local fileSize = LrFileUtils.fileAttributes( pathOrMessage ).fileSize
				
				local inf = LrPhotoInfo.fileAttributes( pathOrMessage )

				local ImageID = rendition.publishedPhotoId

				if ImageID then
					Log( string.format( "Image to be RePublished: %s. %d of %d (id=%d)", fileName, i, nPhotos, ImageID ) )
				else
					Log( string.format( "New Image to be Published: %s. %d of %d", fileName, i, nPhotos ) )
				end

				-- throttle the number of running upload tasks
				while nTasksRunning >= MaxTasks do LrTasks.sleep (1) end

				-- to base64
				local file = assert(io.open(pathOrMessage, "rb"))
				local binData = file:read("*all")
				file:close()
				local base64Data = LrStringUtils.encodeBase64(binData)

				-- background the upload. Faster.
				LrTasks.startAsyncTask( function() 

					local uploadSecs = LrDate.currentTime()
					local thisTask = nTasksRunning
					nTasksRunning = nTasksRunning + 1
	
					if ImageID then -- replace image
						local result = Post( "image/upload", { id = ImageID, gid = GalleryID, name = fileName, imagedata = base64Data, count = i }, exportContext.propertyTable )
						if result == nil then -- something went wrong.
							nTasksRunning = nTasksRunning - 1
							return
						end
					else -- new image
						local result = Post( "image/upload", {gid = GalleryID, name = fileName, imagedata = base64Data, count = i }, exportContext.propertyTable )
						if result == nil then  -- something went wrong
							nTasksRunning = nTasksRunning - 1
							return
						end
						ImageID  = result.id
					end
					rendition:recordPublishedPhotoId( ImageID )
					Log( string.format( "Upload task %d of %d finishing for Image %d (id=%d). Upload time: %d seconds", thisTask, nTasksRunning, i, ImageID, LrDate.currentTime() - uploadSecs ) )

					nTasksRunning = nTasksRunning - 1
				end)

			end -- success

		end -- not rendition.wasSkipped

	end  -- for i in renditions

	-- wait for all the upload tasks to complete
	while ( nTasksRunning > 0) do
		Log( string.format( "Waiting for %d upload tasks to complete", nTasksRunning ) )
		LrTasks.sleep( 1 )
	end

	totalSecs = LrDate.currentTime() - totalSecs

	LrDialogs.showBezel( string.format( "Publish done: %d images in %d seconds. Average: %f", nPhotos, totalSecs, totalSecs/nPhotos ), 3 ) 
	Log( '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%' )
	Log( string.format( "%% Publish done: %d images in %d seconds. Average: %f", nPhotos, totalSecs, totalSecs/nPhotos ) ) 
	Log( '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%' )
end