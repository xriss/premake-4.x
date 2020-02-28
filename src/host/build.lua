
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

fo:write("\n]]\n\n")

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
