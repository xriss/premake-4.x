
local lfs = require("lfs_any")

-- bundle all the lua files

_ARGV={...}

--hack, probably linux only for now to get started
if arg[0]:sub(1,1) == "/" then -- absolute path
	_BASE_SCRIPT_DIR=string.match(arg[0],"(.*/)") .. "/../../"
else
	_BASE_SCRIPT_DIR=lfs.currentdir() .. "/" .. string.match(arg[0],"(.*/)") .. "/../../"
end
_BASE_SCRIPT_DIR=string.gsub(_BASE_SCRIPT_DIR,"//","/")


local fo=io.open( _BASE_SCRIPT_DIR .. "/puremake.lua" ,"wb")
fo:write("#!/usr/bin/env luajit\n\n")
fo:write("--[[\n\n")

local fp=assert(io.open(_BASE_SCRIPT_DIR .. "LICENSE.txt","rb"))
local d=fp:read("*all")
fp:close()
fo:write(d)

fo:write("\n\n")

local fp=assert(io.open(_BASE_SCRIPT_DIR .. "README.md","rb"))
local d=fp:read("*all")
fp:close()
fo:write(d)

fo:write("\n]]\n\n")

local preload_module=function(p,name)

	local fp=assert(io.open(p,"rb"))
	local data=fp:read("*all")
	fp:close()

	fo:write([[
package.preload["]]..name..[["] = function ()
]]..data..[[
end
]])

end



local findfiles
findfiles=function(base,dir)
	local path=base..( dir=="" and "" or ("/"..dir) )
	for filename in lfs.dir(path) do
		if filename~="." and filename~=".." then
			local file=path.."/"..filename
			if lfs.attributes(file,"mode") == "file" then

				local name=( dir=="" and "" or (dir.."/") )..filename
				name=name:gsub("%.lua$","")
				name=name:gsub("/",".")

				print("MODULE",name)
				preload_module(file,name)

			elseif lfs.attributes(file,"mode")== "directory" then
--				print("found dir, "..file," containing:")
				findfiles(base,( dir=="" and "" or (dir.."/") )..filename)
			end
		end
	end
end
findfiles(_BASE_SCRIPT_DIR.."lua","")



local amalgamate=function(p)

	local fp=assert(io.open(_BASE_SCRIPT_DIR .. p,"rb"))
	local d=fp:read("*all")
	fp:close()

	fo:write("-- AMALGAMATE FILE HEAD : "..p.."\n")
	fo:write(d)
	fo:write("-- AMALGAMATE FILE TAIL : "..p.."\n")

end


local scripts  = dofile(_BASE_SCRIPT_DIR .. "src/_manifest.lua")

for _,v in ipairs(scripts) do
	amalgamate("/src/"..v)
end

amalgamate("/src/_premake_main.lua")
amalgamate("/src/host/main.lua")


fo:close()
