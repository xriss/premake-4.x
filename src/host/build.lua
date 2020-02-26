
-- bundle all the lua files

_ARGV={...}

--hack, probably linux only for now to get started
if arg[0]:sub(1,1) == "/" then -- absolute path
	_BASE_SCRIPT_DIR=string.match(arg[0],"(.*/)") .. "/../../"
else
	_BASE_SCRIPT_DIR=lfs.currentdir() .. "/" .. string.match(arg[0],"(.*/)") .. "/../../"
end
_BASE_SCRIPT_DIR=string.gsub(_BASE_SCRIPT_DIR,"//","/")


print(_BASE_SCRIPT_DIR)

