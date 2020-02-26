
local lfs = require("lfs")


-- handle command line args and start premake

_ARGV={...}

_ARGS={}
_OPTIONS={}

os.print=print

for i,v in ipairs(_ARGV) do

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


-- fake command as the dir part is used in later search paths
_PREMAKE_COMMAND	=_BASE_SCRIPT_DIR.."premake"

_SCRIPT=lfs.currentdir() .. "/" .. arg[0]
_SCRIPT_DIR=lfs.currentdir() .. "/" .. string.match(arg[0],"(.*/)")




-- do we need to load script files or have we already done this?
if not _premake_main then
	dofile( _BASE_SCRIPT_DIR .. "src/_premake_main.lua" )
	return _premake_main(_BASE_SCRIPT_DIR.."src")
end
return _premake_main()

