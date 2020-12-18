--[[ 
	Global login settings. Updated by the observer set up in startDialog
	Checked by Button 'Test Login'
	by Martin von Berg
]]

local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrColor = import 'LrColor'
local share = LrView.share
require 'Post'
local inspect = require 'inspect' 
----------------------------------------

dialogs = {}

-- Definiert das Feld zu Beginn der Exporteinstellungen aufgerufen mit "Einstellungen bearbeiten ..."
function dialogs.sectionsForTopOfDialog( f, propertyTable )
 --LrMobdebug.on()
	local bind = LrView.bind
	propertyTable.msgBox = 'Not tested yet !'
		
	local result = {
	
		{
			title = "Wordpress Login Details and Settings:", -- Bezeichnung des Abschnitts in den Exporteinstellungen
			
				f:group_box {
					title = "Login Settings",
					EntryBox( f, 'Site URL', 'siteURL'),			-- must start with http:// or https://
					EntryBox( f, 'Login Name', 'loginName'),	
					EntryBox( f, 'Login Password', 'loginPassword'),
					
					f:row {
						fill_horizontal = true,				
						f:push_button {    -- Button mit Callback-Aufruf, der den hash-value zur Authentifizierung prüft
							title = "Test Login",
							action = function( button ) -- test the wp login
								Log( "Pressed Test Login button" )  -- Debugging
								propertyTable.msgBox = ''
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
					title = "Settings for (First)-Sync with Wordpress",
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
							title = "Check for Test-Mode (not used!)",
							value = bind 'DebugMode',
						},
					},

					EntryBox( f, 'Prefix for virtual Copy:', 'preCopy'),					

				},

				f:group_box {
					title = "Select Values-Settings for WP-Metadata",

					f:column {
						--place = 'overlapping',
						--fill_horizontal = 1,
						f:row {
							f:static_text {
								fill_horizontal = 0,
								width_in_chars = 17,
								title = 'WP-alt_text',
							},
							f:static_text {
								fill_horizontal = 0,
								width_in_chars = 17,
								title = 'WP-description',
							},
							f:static_text {
								fill_horizontal = 0,
								width_in_chars = 17,
								title = 'WP-caption',
							},
						},	

						f:row {
							f:simple_list {
								height = 80,
								width = 100,
								allows_multiple_selection = false,
								items = { {title = "Caption", value = 'LRcap'}, {title = "Title", value = 'LRtit'}, },
								value = bind 'WPalt',
							},
								

							f:spacer {
								width = 40
							},

							f:simple_list {
								height = 80,
								width = 100,
								allows_multiple_selection = false,
								items = {{title = "Caption", value = 'LRcap'}, {title = "Title", value = 'LRtit'}, },
								value = bind 'WPdescr',
							},

							f:spacer {
								width = 40
							},	
								
							f:simple_list {
								height = 80,
								width = 100,
								allows_multiple_selection = false,
								items = {{title = "Caption", value = 'LRcap'}, {title = "Title", value = 'LRtit'}, },
								value = bind 'WPcap',
							},	
						},
					},		
				},

		},
	}
	
	return result
end

function updateExportStatus( propertyTable )
	Log('updateExportStatus aufgerufen')
	local message = nil
	local locp = ''

	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)
		
		if propertyTable.doLocalCopy then
			locp = ''
			locp = propertyTable.localPath 
		end

		if propertyTable.WPalt[1] == nil then
			message = 'Selection for Metadata not done!'
		end
	
	until true
	
	if message then
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
	
end

-- wird bei Beginn des Dialogs aufgerufen
-- registriert einen Observer, der bei Änderungen im Feld die genannte Funktion aufruft
function dialogs.startDialog( propertyTable )
	Log('startDialog aufgerufen')
	
	propertyTable:addObserver( 'siteURL', checkURL )

	propertyTable:addObserver( 'doLocalCopy', updateExportStatus )
	propertyTable:addObserver( 'localPath', updateExportStatus )

	propertyTable:addObserver( 'WPalt', updateExportStatus )
	propertyTable:addObserver( 'WPdescr', updateExportStatus )
	propertyTable:addObserver( 'WPcap', updateExportStatus )

	propertyTable:addObserver( 'preCopy', updateExportStatus )

	updateExportStatus( propertyTable )
	
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

-- Hilfsfunktion für den Dialog: Eingabefeld mit einheitlichen Parametern
function EntryBox( f, title, bound)

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