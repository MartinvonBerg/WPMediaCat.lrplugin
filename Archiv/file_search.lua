require 'lfs'
require 'os'
local os_date

-- code by GianlucaVespignani - 2012-03-04; 2013-01-26
-- Search files in a path, alternative in sub directory
-- @param dir_path string (";" for multiple paths supported)
-- @param filter string - eg.: ".txt" or ".mp3;.wav;.flac"
-- @param s bool - search in subdirectories
-- @param pformat format of data - 'system' for system-dependent number; nil or string with formatting directives
-- @return  files, dirs - files and dir are tables {name, modification, path, size}
function file_search(dir_path, filter, s, pformat)
	-- === Preliminary functions ===
	-- comparison function like the IN() function like SQLlite, item in a array
	-- useful for compair table for escaping already processed item
	-- Gianluca Vespignani 2012-03-03
	local c_in = function(value, tab)
		for k,v in pairs(tab) do
			if v==value then
				return true
			end
		end
		return false
	end

	local string = string	-- http://lua-users.org/wiki/SplitJoin
	function string:split(sep)
		local sep, fields = sep or ":", {}
		local pattern = string.format("([^%s]+)", sep)
		self:gsub(pattern, function(c) fields[#fields+1] = c end)
		return fields
	end

	local ExtensionOfFile = function(filename)
		local rev = string.reverse(filename)
		local len = rev:find("%.")
		local rev_ext = rev:sub(1,len)
		return string.reverse(rev_ext)
	end

	-- === Init ===
	dir_path = dir_path or cwd
	filter = string.lower(filter) or "*"
	local extensions = filter:split(";")
	s = s or false -- as /s : subdirectories

	if pformat == 'system' then	-- if 4th arg is explicity 'system', then return the system-dependent number representing date/time
		os_date = function(os_time)
			return os_date
		end
	else
		-- if 4th arg is nil use default, else it could be a string that respects the Time formatting directives
		pformat = pformat or "%Y/%m/%d" -- eg.: "%Y/%m/%d %H:%M:%S"
		os_date = function(os_time)
			return os.date(pformat, os_time)
		end
	end

	-- == MAIN ==
	local files = {}
	local dirs = {}
	local paths = dir_path:split(";")
	for i,path in ipairs(paths) do
		for f in lfs.dir(path) do
			if f ~= "." and f ~= ".." then
				local attr = lfs.attributes ( path.."/"..f )
				if attr.mode == "file" then
					if filter=="*"
					or c_in( string.lower( ExtensionOfFile(f) ), extensions)
					then
						table.insert(files,{
							name = f,
							modification = os_date(attr.modification) ,
							path = path.."/",
							size = attr.size
						})
					end
				else
					if filter=="*" then			-- if attr.mode == "directory" and file ~= "." and file ~= ".." then end
						table.insert(dirs,{
							name = f ,
							modification = os_date(attr.modification) ,
							path = path.."/",
							size = attr.size
						})
					end
					if s and attr.mode == "directory" then
						local subf={}
						local subd={}
						subf, subd = file_search(path.."/"..f, filter, s, pformat)
						for i,v in ipairs(subf) do
							table.insert(files,{
								name = v.name ,
								modification = v.modification ,
								path = v.path,
								size = v.size
							})
						end
						for i,v in ipairs(subd) do
							table.insert(dirs,{
								name = v.name ,
								modification = v.modification ,
								path = v.path,
								size = v.size
							})
						end
					end
				end
			end
		end
	end
	return files,dirs

	--[=[	ABOUT ATTRIBUTES
> for k,v in pairs(a) do print(k..' \t'..v..'') end
dev     2
change  1175551262	-- date of file Creation
access  1235831652
rdev    2
nlink   1
uid     0
gid     0
ino     0
mode    file
modification    1181692021 -- Date of Last Modification
size    805 in byte
	]=]
end