
-- we really need LFS
lfs=require("lfs")


premake=premake or {}

	
_PREMAKE_COPYRIGHT	="Copyright (C) 2002-2015 Jason Perkins and the Premake Project"
_PREMAKE_VERSION	="4.0.0-lua"
_PREMAKE_URL		="https://github.com/premake/premake-4.x"
_OS					="other"

-- jit knows the OS, but it might need tweaking to fit what names premake uses
if jit then
	_OS=string.lower(jit.os)
end

_USER_HOME_DIR		=os.getenv("HOME")
_WORKING_DIR		=lfs.currentdir()



_ARGV=arg

_ARGS={}
_OPTIONS={}

os.print=print

for i,v in ipairs(_ARGV) do
print(v)
	if (v:sub(1,1)=="/") or (v:sub(1,2)=="--") then -- args

		local o=v

		if     o:sub(1,1)=="/"  then o=o:sub(2)
		elseif o:sub(1,2)=="--" then o=o:sub(3)
		end
		
		s=""
		
		local e=o:find("=")
		if e then
			s=o:sub(e+1)
			o=o:sub(1,e-1)
		end

		print(o,s)

		_OPTIONS[o]=s
		
	else

		if not _ACTION then
			_ACTION=v
		else
			_ARGS[#_ARGS+1]=v
		end

	end
end


--hack, probably linux only for now to get started
if arg[0]:sub(1,1) == "/" then -- absolute path
	_BASE_SCRIPT_DIR=string.match(arg[0],"(.*/)") .. "/../../"
else
	_BASE_SCRIPT_DIR=lfs.currentdir() .. "/" .. string.match(arg[0],"(.*/)") .. "/../../"
end
_BASE_SCRIPT_DIR=string.gsub(_BASE_SCRIPT_DIR,"//","/")


--print(_BASE_SCRIPT_DIR)



dofile( _BASE_SCRIPT_DIR .. "src/host/criteria.lua" )
dofile( _BASE_SCRIPT_DIR .. "src/host/debug.lua" )
dofile( _BASE_SCRIPT_DIR .. "src/host/path.lua" )
dofile( _BASE_SCRIPT_DIR .. "src/host/os.lua" )
dofile( _BASE_SCRIPT_DIR .. "src/host/string.lua" )
dofile( _BASE_SCRIPT_DIR .. "src/host/buffered.lua" )
dofile( _BASE_SCRIPT_DIR .. "src/host/http.lua" )
dofile( _BASE_SCRIPT_DIR .. "src/host/zip.lua" )



-- fake command as the dir part is used in later search paths
_PREMAKE_COMMAND	=_BASE_SCRIPT_DIR.."premake"

_SCRIPT=lfs.currentdir() .. "/" .. arg[0]
_SCRIPT_DIR=lfs.currentdir() .. "/" .. string.match(arg[0],"(.*/)")



--[=[


do
	local scripts_path
	for i,v in ipairs(_ARGV) do
		if "/scripts=" ==v:sub(1,9)  then scripts_path=v:sub(10) end
		if "--scripts="==v:sub(1,10) then scripts_path=v:sub(11) end
	end
	if scripts_path then print("scripts_path =",scripts_path) end

	local env_path=os.getenv("PREMAKE_PATH");

	local aa={}
	table.insert(aa,".")
	if scripts_path then table.insert(aa,scripts_path) end
	if env_path then table.insert(aa,env_path) end
	table.insert(aa,_USER_HOME_DIR.."/.premake")
	if _OS=="osx" then
		table.insert(aa,_USER_HOME_DIR.."/Library/Application Support/Premake")
	end
	table.insert(aa,"/usr/local/share/premake;/usr/share/premake")

	table.insert(aa,_BASE_SCRIPT_DIR.."src")
	table.insert(aa,_BASE_SCRIPT_DIR.."src/host")
	
	premake.path=table.concat(aa,";")
	if _OS~="windows" then
		premake.path=premake.path:gsub(":",";") -- cleanup any : seperators
	end

end

--[[ test the above vars
for n,v in pairs(_G) do
	if type(n)=="string" then
		if string.sub(n,1,1)=="_" then
			print(n,tostring(v))
		end
	end
end
for n,v in pairs(premake) do
	if type(n)=="string" then
		print("premake."..n,tostring(v))
	end
end
]]



local _dofile=dofile
dofile=function(n)

	local p=os.locate(n) or n

--print("DOFILE",n,p,lfs.currentdir())

	local pd,pf=path._splitpath(p)
	
	local OLD_SCRIPT=_SCRIPT
	local OLD_SCRIPT_DIR=_SCRIPT_DIR

	 _SCRIPT=p
	 _SCRIPT_DIR=pd
	 
	 local old_cd=lfs.currentdir()
	 lfs.chdir(_SCRIPT_DIR)
--	 print("CD1",_SCRIPT_DIR,pf)

	local a,b=_dofile(p)
	
	 lfs.chdir(old_cd)
--	 print("OD",old_cd)
	_SCRIPT=OLD_SCRIPT
	_SCRIPT_DIR=OLD_SCRIPT_DIR
	
	return a,b
end

local _loadfile=loadfile
loadfile=function(n)

	local p=path.getabsolute(n)
--print("LOADFILE",n,p)
	local pd,pf=path._splitpath(p)
	
	local OLD_SCRIPT=_SCRIPT
	local OLD_SCRIPT_DIR=_SCRIPT_DIR

	 _SCRIPT=p
	 _SCRIPT_DIR=pd
	 
	 local old_cd=lfs.currentdir()
	 lfs.chdir(_SCRIPT_DIR)
--	 print("CD2",_SCRIPT_DIR,pf)

	local a,b=_loadfile(n)

-- reseting the dir will break the next include so leave it hanging
-- problem is the loadfile chunk is not run until later

--	 lfs.chdir(old_cd)
--	 print("OD",old_cd)
--	_SCRIPT=OLD_SCRIPT
--	_SCRIPT_DIR=OLD_SCRIPT_DIR

	return a,b
end

]=]

dofile( _BASE_SCRIPT_DIR .. "src/_premake_main.lua" )
_premake_main(_BASE_SCRIPT_DIR.."src")
