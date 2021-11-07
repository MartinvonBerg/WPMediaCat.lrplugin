--[[ 
	Global login settings. Updated by the observer set up in startDialog
	Checked by Button 'Test Login'
	by Martin von Berg
]]

local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrColor = import 'LrColor'
local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local share = LrView.share
require 'Post'
--local inspect = require 'inspect' 
----------------------------------------

dialogs = {}

-- Definiert das Feld zu Beginn der Exporteinstellungen aufgerufen mit "Einstellungen bearbeiten ..."
function dialogs.sectionsForTopOfDialog( f, propertyTable )
	Log('sectionsForTopOfDialog aufgerufen')
    --LrMobdebug.on()
	local bind = LrView.bind
	propertyTable.msgBox = 'Not tested yet !'
		
	local result = {
	
		{
			title = "WordPress Login Details and Settings:", -- Bezeichnung des Abschnitts in den Exporteinstellungen
			
				f:group_box {
					title = "License and Donation",
					fill_horizontal = 1,
					f:row {
						f:static_text {
							title = 'This Software is Freeware and only for non-commercial use.\nIf you like this Plugin please support me with a Donation. Thank you!.',
							font = '<system/bold>'
						},
						f:push_button {    -- Button mit Callback-Aufruf, der den hash-value zur Authentifizierung prüft
							title = "Donate",
							height_in_lines = 3,
							width_in_chars = 12,
							tooltip = 'Donate Martin a coffee or a beer',
							action = function () -- test the wp login
								LrHttp.openUrlInBrowser( 'https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=CQA6XZ7LUMBJQ' )
							end
						},
						
					},
				},	

				f:group_box {
					title = "Login Settings",
					
					EntryBox( f, 'Site URL', 'siteURL'),			-- must start with http:// or https://
					EntryBox( f, 'Login Name', 'loginName'),	
					EntryBox( f, 'Login Password', 'loginPassword'),
					
					f:row {
									
						f:push_button {    -- Button mit Callback-Aufruf, der den hash-value zur Authentifizierung prüft
							title = "Test Login",
							action = function( button ) -- test the wp login
								Log( "Pressed Test Login button" )  -- Debugging
								propertyTable.msgBox = 'Test started...'
								LrFunctionContext.postAsyncTaskWithContext( "testPost", function( context ) 
									local result = CheckLogin( propertyTable )
									if result then
										-- result in lesbaren String umwandeln und ausgeben
										local str = inspect(result) 
										local length = string.len( str )
										str = string.sub(str,4,length-3)  
										propertyTable.msgBox = "Login Test returned: \n" .. str
										--propertyTable.msgBox = str
										Log( "Login Test returned: ", str )  -- Debugging
									else
										Log( "Post Test failed" )
										propertyTable.msgBox = "Login Test Returned failed. No Result"
									end
								end )			
							end
						},
					},
					f:row {
						f:static_text {
							title = bind( 'msgBox'),
							height_in_lines = 6,
							--text_color = LrColor( 1, 0, 0 ),
							fill_horizontal = 1
						}
					},
				},	

				f:group_box {
					title = "Settings for File Upload",
					fill_horizontal = 1,
					f:row {
		
						f:checkbox {
							title = LOC "$$$/FtpUpload/ExportDialog/doLocalCopy=Convert Files to WEBP",
							value = bind 'dowebp',
						},
		
						f:static_text {
							title = bind( 'webpStatus' ),
							fill_horizontal = 0,
							width_in_chars = 40,
						},
					},
				},

				f:group_box {
					title = "Settings for (First)-Sync with WordPress",
					fill_horizontal = 1,
					f:row {
		
						f:checkbox {
							title = LOC "$$$/FtpUpload/ExportDialog/doLocalCopy=Do local Copy:",
							value = bind 'doLocalCopy',
						},
		
						f:edit_field {
							value = bind 'localPath',
							enabled = bind 'doLocalCopy',
							truncation = 'middle',
							immediate = true,
							fill_horizontal = 1,
						},
					},

					f:column {
						place = 'overlapping',
						fill_horizontal = 1,
						
						f:row {
							f:static_text {
								title = LOC "$$$/FtpUpload/ExportDialog/LocalPath=Local Path:",
								alignment = 'right',
								width = share 'labelWidth',
								visible = bind 'hasNoError',
							},
							
							f:static_text {
								fill_horizontal = 1,
								width_in_chars = 30,
								alignment = 'left',
								title =  bind 'localPath',
								visible = bind 'hasNoError',
							},
		
							f:static_text {
								fill_horizontal = 0,
								width_in_chars = 17,
								title = ' ',
							},
						},
					},

					f:row {
						f:checkbox {
							title = "Only Do Metadata at First-Sync. WP Image Files will not be touched if checked!",
							value = bind 'firstSyncDoMetaOnly',
						},
					},

					f:row {
						f:checkbox {
							title = "First-Sync Metadata handling: CHECKED: LR --> WP || NOT CHECKED: WP --> LR",
							value = bind 'LrMeta_to_WP',
						},
					},

				},

				f:group_box {
					title = "Select Values-Settings for WP-Metadata. WARNING: No consistency check is done!",
					fill_horizontal = 1,
					f:column {
						f:row {
							f:static_text {
								fill_horizontal = 0,
								width_in_chars = 15,
								title = 'WP-alt_text',
							},
							f:static_text {
								fill_horizontal = 0,
								width_in_chars = 15,
								title = 'WP-description',
							},
							f:static_text {
								fill_horizontal = 0,
								width_in_chars = 15,
								title = 'WP-caption',
							},
							f:static_text {
								fill_horizontal = 0,
								width_in_chars = 15,
								title = 'LR-caption',
								text_color = LrColor( 1, 0, 0 ),
							},
						},	

						f:row {
							f:simple_list {
								height = 80,
								width = 100,
								allows_multiple_selection = false,
								items = { {title = "Caption", value = 'LRcap'}, {title = "Title", value = 'LRtit'}, {title = "empty", value = 'empty'}, },
								value = bind 'WPalt',
							},

							f:spacer {
								width = 25
							},

							f:simple_list {
								height = 80,
								width = 100,
								allows_multiple_selection = false,
								items = {{title = "Caption", value = 'LRcap'}, {title = "Title", value = 'LRtit'}, {title = "empty", value = 'empty'}, },
								value = bind 'WPdescr',
							},

							f:spacer {
								width = 25
							},	
								
							f:simple_list {
								height = 80,
								width = 100,
								allows_multiple_selection = false,
								items = {{title = "Caption", value = 'LRcap'}, {title = "Title", value = 'LRtit'}, {title = "empty", value = 'empty'}, },
								value = bind 'WPcap',
							},	

							f:spacer {
								width = 25
							},	
								
							f:simple_list {
								height = 80,
								width = 120,
								allows_multiple_selection = false,
								items = { {title = "WP-alt_text", value = 'WPalt'}, {title = "WP-description", value = 'WPdescr'}, {title = "WP-caption", value = 'WPcap'}, {title = "empty", value = 'empty'}, },
								value = bind 'LRcap',
							}
						},
					},	
					
					f:row {
						f:checkbox {
							title = "Update caption for all Images with LR caption",
							value = bind 'doCaption',
						},
					},

					f:row {
						f:static_text {
							title = "All means: Works for Gutenberg images, galleries and images with text. Their captions will be identical.",
							
						},
					},
				},
		},
	}
	
	--Log('sectionsForTopOfDialog beendet')
	return result
end

function updateExportStatus( propertyTable )
	--Log('updateExportStatus aufgerufen')
	local message = nil
	local msg = inspect(propertyTable.msgBox)
	--Log('Msg: ', msg)

	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)
		if propertyTable.doLocalCopy then
			if propertyTable.localPath == '' then
				message = 'empty path'
			end
			if #propertyTable.localPath > 255 then
				message = 'path too long'
			end
			if WIN_ENV then
				if string.match(propertyTable.localPath ,'[/*?"<>|§$%%~#@€=&\'µ°]') ~= nil then
					message = 'wrong character'
				end
				if string.match(propertyTable.localPath,'[a-zA-Z]:\\.*') == nil then
					message = 'wrong path'
				end
			else
				if string.match(propertyTable.localPath ,'[*?"<>|§$%%~#@€=&\'µ°]') ~= nil then
					message = 'wrong character'
				end
			end	
		end

		if msg ~= nil then
			if string.match(msg,'error') then
				message = 'siteURL failed'
			end
			if string.match(msg,'Not tested') then
				message = 'Test siteURL required!'
			end
		end

	until true
	
	if message then
		--Log(message)
		propertyTable.message = message
		propertyTable.hasError = true
		propertyTable.hasNoError = false
		propertyTable.LR_cantExportBecause = message
	else
		propertyTable.message = nil
		propertyTable.hasError = false
		propertyTable.hasNoError = true
		propertyTable.LR_cantExportBecause = nil
	
	end
	--Log('updateExportStatus beendet')
end

-- wird bei Beginn des Dialogs aufgerufen
-- registriert einen Observer, der bei Änderungen im Feld die genannte Funktion aufruft
function dialogs.startDialog( propertyTable )
	--Log('startDialog aufgerufen')
	
	propertyTable:addObserver( 'siteURL', checkURL )
	
	propertyTable:addObserver( 'dowebp', checkWebpConversion )

	propertyTable:addObserver( 'doLocalCopy', updateExportStatus )
	propertyTable:addObserver( 'localPath', updateExportStatus )

	propertyTable:addObserver( 'WPalt', updateExportStatus )
	propertyTable:addObserver( 'WPdescr', updateExportStatus )
	propertyTable:addObserver( 'WPcap', updateExportStatus )

	propertyTable:addObserver( 'preCopy', updateExportStatus )
	propertyTable:addObserver( 'firstSyncDoMetaOnly', updateExportStatus )
	propertyTable:addObserver( 'LrMeta_to_WP', updateExportStatus )

	propertyTable:addObserver( 'LRcap', updateExportStatus )
	propertyTable:addObserver( 'msgBox', updateExportStatus )

	updateExportStatus( propertyTable )
	--Log('startDialog beendet')
	
end

-- prüft die eingegebene URL im Feld 'Site URL' bei Änderungen im Feld
-- gibt Fehlermeldung aus, wenn kein https verwendet oder http(s) ganz fehlt
function checkURL( propertyTable )
	
	Log( "checkURL: " .. propertyTable.siteURL) -- Debugging

	local str = ""
	if ( string.sub( string.lower( propertyTable.siteURL ), 1, string.len("https"))=="https" == false ) then
		str = str .. "Your WP login details may sent to the server in plain text\nYou should consider using https://\n"
		--LrDialogs.message( str, "", "warning" )
	end	

	if ( string.sub( string.lower( propertyTable.siteURL ), 1, string.len("http"))=="http" == false ) then
		str = str .. "URL should be prefixed with http:// or https://\n"
		--LrDialogs.message( str, "", "warning" )
	end	

	propertyTable.msgBox = str
end

function checkWebpConversion( propertyTable )
	-- body
	Log( "checkWebpConversion: " .. propertyTable.webpStatus) -- Debugging
	
	if propertyTable.dowebp then
		--propertyTable.webpStatus = 'Activated. Tested!'
		local p2 = LrPathUtils.getStandardFilePath( 'documents' )
		
		local filepath = p2 .. DIRSEP .. 'LRTestImagick.txt'
                
		if not LrFileUtils.exists( filepath ) then
			propertyTable.webpStatus = 'ImageMagick not installed. Webp conversion not possible!'
			propertyTable.dowebp = false
		else
			local attr = LrFileUtils.fileAttributes( filepath )
			local size = attr['fileSize']
			Log('Test filesize: ', size)
			if size > 50 then
				propertyTable.webpStatus = 'ImageMagick installed!'
			else
				propertyTable.webpStatus = 'ImageMagick not executable. Webp conversion not possible!'
				propertyTable.dowebp = false
			end
		end
	
	else
		propertyTable.webpStatus = 'WebP De-Activated. Check Installation if you tried to activate.'
	end

	--if MAC_ENV then
	--	propertyTable.webpStatus = 'Not for macOS! Webp conversion not possible!'
	--	propertyTableq.dowebp = false 
	--end
end

-- Hilfsfunktion für den Dialog: Eingabefeld mit einheitlichen Parametern
function EntryBox( f, title, bound)
	--Log('EntryBox aufgerufen')
	local bind = LrView.bind
	local share = LrView.share

	return f:row {
		fill_horizontal = true,
		f:static_text {
			title = title, 
			alignment = 'right',
			width = share 'labelWidth'
		},

		f:edit_field {
			value = bind( bound ), 
			width = 400
		},
	}
	
end