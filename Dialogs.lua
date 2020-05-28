
local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrColor = import 'LrColor'
local inspect = require 'inspect'

dialogs = {}

--local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module
--LrMobdebug.start()
 
-- Global login settings. Updated by the observer set up in startDialogs

function dialogs.sectionsForTopOfDialog( f, propertyTable )
  --LrMobdebug.on()
	local bind = LrView.bind
		
	local result = {
	
		{
			title = LOC "$$$/NggPlusPlus/ExportDialog/NggPlusPlus=Wordpress Login Details:",
			
			synopsis = bind { key = 'fullPath', object = propertyTable },
			
				f:group_box {
					title = "Login Settings",
					EntryBox( f, 'Site URL', 'siteURL'),			-- must start http:// or https://
					EntryBox( f, 'Login Name', 'loginName'),	
					EntryBox( f, 'Login Password', 'loginPassword'),
          			EntryBox( f, 'hash-Value (Basic Auth!)', 'hash'),
					f:row {
						fill_horizontal = true,				
						f:push_button {
							title = "Test Login",
							action = function( button ) -- test the wp login
								Log( "Pressed Test Login button" )
								LrFunctionContext.postAsyncTaskWithContext( "testPost", function( context ) 
									local result = CheckLogin( propertyTable )
									if result then
                    					local str = inspect(result)
										Log( "Login Test returned: ", str )
										--propertyTable.msgBox = "Login Test Returned OK"
                    					propertyTable.msgBox = str
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
							text_color = LrColor( 1, 0, 0 ),
							fill_horizontal = 1
						}
					},

				},

		},
	}
	
	return result
end

function dialogs.startDialog( propertyTable )

	propertyTable:addObserver( 'siteURL', checkURL )
	--propertyTable:addObserver( 'loginName', updateLogins )
	-- propertyTable:addObserver( 'loginPassword', updateLogins )
	

end

function checkURL( propertyTable )

	Log( "checkURL: " .. propertyTable.siteURL)

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