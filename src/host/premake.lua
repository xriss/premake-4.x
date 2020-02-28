
-- we really need LFS
lfs=require("lfs_any")


premake=premake or {}

	
_PREMAKE_COPYRIGHT	="Copyright (C) 2002-2015 Jason Perkins and the Premake Project"
_PREMAKE_VERSION	="4.0.0-puremake"
_PREMAKE_URL		="https://github.com/xriss/puremake"
_OS					="other"

-- jit knows the OS, but it might need tweaking to fit what names premake uses
if jit then
	_OS=string.lower(jit.os)
end

_USER_HOME_DIR		=os.getenv("HOME")
_WORKING_DIR		=lfs.currentdir()


