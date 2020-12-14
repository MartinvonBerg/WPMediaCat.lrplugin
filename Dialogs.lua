--[[ 
	Global login settings. Updated by the observer set up in startDialog
	Checked by Button 'Test Login'
	by Martin von Berg
	TODO: Hash-value gemäß gewähltem Auth-Verfahren (OAuth, OAuth2) aus User-ID und Password berechnen!
]]
----- Debug -----------
--local Require = require "Require".path ("../debuggingtoolkit.lrdevplugin").reload ()
--local Debug = require "Debug".init ()
--require "strict.lua"

local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrColor = import 'LrColor'
local share = LrView.share
require 'Post'

------------- Debug ----------------------

local inspect = require 'inspect' 
local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
LrMobdebug.start()
 ----------------------------------------

dialogs = {}

-- Definiert das Feld zu Beginn der Exporteinstellungen aufgerufen mit "Einstellungen bearbeiten ..."
function dialogs.sectionsForTopOfDialog( f, propertyTable )
 --LrMobdebug.on()
	local bind = LrView.bind
		
	local result = {
	
		{
			title = LOC "$$$/NggPlusPlus/ExportDialog/NggPlusPlus=Wordpress Login Details:", -- Bezeichnung des Abschnitts in den Exporteinstellungen
			
			synopsis = bind { key = 'fullPath', object = propertyTable },
			
				f:group_box {
					title = "Login Settings",
					EntryBox( f, 'Site URL', 'siteURL'),			-- must start with http:// or https://
					EntryBox( f, 'Login Name', 'loginName'),	
					EntryBox( f, 'Login Password', 'loginPassword'),
					-- EntryBox( f, 'hash-Value (Basic Auth!)', 'hash'),
					f:row {
						f:checkbox {
							title = "Check for Test-Mode",
							value = bind 'DebugMode',
						},
					},
					f:row {
						fill_horizontal = true,				
						f:push_button {    -- Button mit Callback-Aufruf, der den hash-value zur Authentifizierung prüft
							title = "Test Login",
							action = function( button ) -- test the wp login
								Log( "Pressed Test Login button" )  -- Debugging
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

		},
	}
	
	return result
end

-- wird bei Beginn des Dialogs aufgerufen
-- registriert einen Observer, der bei Änderungen im Feld die genannte Funktion aufruft
function dialogs.startDialog( propertyTable )
	
	propertyTable:addObserver( 'siteURL', checkURL )
	
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

-- Hilfsfunktion für den ftp-Dialog: Eingabefeld mit einheitlichen Parametern
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