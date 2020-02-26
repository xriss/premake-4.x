#!/usr/bin/env luajit

-- AMALGAMATE FILE HEAD : /src/host/string.lua

string=string or {}


string.startswith=function(a,b)

--	os.print("FUNCTION","string."..debug.getinfo(1).name,a,b,b==a:sub(1,#b))
	
	if a and b then
		return b==a:sub(1,#b)
	end
	
end

string.endswith=function(a,b)

--	os.print("FUNCTION","string."..debug.getinfo(1).name,a,b,b==a:sub(-#b))

	if a and b then
		return b==a:sub(-#b)
	end
end
-- AMALGAMATE FILE TAIL : /src/host/string.lua
-- AMALGAMATE FILE HEAD : /src/host/path.lua
--
-- (C) 2020 Kriss@XIXs.com and released under the MIT license,
-- see http://opensource.org/licenses/MIT for full license text.
--
local coroutine,package,string,table,math,io,os,debug,assert,dofile,error,_G,getfenv,getmetatable,ipairs,Gload,loadfile,loadstring,next,pairs,pcall,print,rawequal,rawget,rawset,select,setfenv,setmetatable,tonumber,tostring,type,unpack,_VERSION,xpcall,module,require=coroutine,package,string,table,math,io,os,debug,assert,dofile,error,_G,getfenv,getmetatable,ipairs,load,loadfile,loadstring,next,pairs,pcall,print,rawequal,rawget,rawset,select,setfenv,setmetatable,tonumber,tostring,type,unpack,_VERSION,xpcall,module,require

--[[#lua.wetgenes.path

Manage file paths under linux or windows, so we need to deal with \ or 
/ and know the root difference between / and C:\

	local wpath=require("wetgenes.path")

]]
local M={}
local wpath=M

-- a soft require of lfs so lfs can be nil
local lfs=select(2,pcall( function() return require("lfs") end ))


--[[#lua.wetgenes.path.setup

setup for windows or linux style paths, to force one or the other use

	wpath.setup("win")
	wpath.setup("nix")

We automatically call this at startup and make a best guess, you can 
revert to this best guess with

	wpath.setup()

This is a global setting, so be careful with changes. Mostly its 
probably best to stick with the best guess unless we are mistakenly 
guessing windows.

]]
wpath.setup=function(flavour)

-- try and guess if we are dealing with linux or windows style paths
	if not flavour then
		if package.config:sub(1,1) ==  "/" then -- paths begin with /
			flavour="nix"
		else
			flavour="win"
		end
	end

	if flavour == "win" then
	
		wpath.root="C:\\"
		wpath.separator="\\"
		wpath.delimiter=":"
		wpath.winhax=true

	elseif flavour == "nix" then

		wpath.root="/"
		wpath.separator="/"
		wpath.delimiter=";"
		wpath.winhax=false
	
	end


end
wpath.setup()
wpath.winhax=true -- always need winhax



--[[#lua.wetgenes.path.split

split a path into numbered components

]]
wpath.split=function(p)
	local ps={}
	local fi=1
	while true do
		local fa,fb=string.find(p,wpath.winhax and "[\\/]" or "[/]",fi)
		if fa then
			local s=string.sub(p,fi,fa-1)
			if s~="" or ps[#ps]~="" then -- ignore multiple separators
				ps[#ps+1]=s
			end
			fi=fb+1
		else
			break
		end
	end
	ps[#ps+1]=string.sub(p,fi)

	return ps
end

--[[#lua.wetgenes.path.join

join a split path, tables are auto expanded

]]
wpath.join=function(...)
	local ps={}
	for i,v in ipairs({...}) do
		local t=type(v)
		if t=="table" then
			for j,s in ipairs(v) do
				if type(s)=="string" then
					ps[#ps+1]=s
				end
			end
		else
			if type(v)=="string" then
				ps[#ps+1]=v
			end
		end
	end
	return table.concat(ps,wpath.separator)
end

--[[#lua.wetgenes.path.parse

split a path into named parts like so

	-------------------------------------
	|               path                |
	-------------------------------------
	|           dir        |    file    |
	|----------------------|------------|
	| root |    folder     | name  ext  |
	|----------------------|------------|
	|  /   |  home/user/   | file  .txt |
	-------------------------------------
	
this can be reversed with simple joins and checks for nil

	dir = (root or "")..(folder or "")
	file = (name or "")..(ext or "")
	path = (dir or "")..(file or "")
	
if root is set then it implies an absolute path and will be something 
like C:\ under windows.

]]
wpath.parse=function(p)
	local ps=wpath.split(p)
	local r={}

	if ps[1] then
		if ps[1]=="" and ps[2] then -- unix root
			r.root=wpath.separator
			table.remove(ps,1)
		elseif #(ps[1])==2 and string.sub(ps[1],2,2)==":" and wpath.winhax then -- windows root
			r.root=ps[1]..wpath.separator
			table.remove(ps,1)
		end
	end

	if ps[1] then
		r.file=ps[#ps]
		table.remove(ps,#ps)

		local da,db=string.find(r.file, ".[^.]*$")
		if da and da>1 then -- ignore if at the start of name
			r.name=string.sub(r.file,1,da-1)
			r.ext=string.sub(r.file,da,db)
		else
			r.name=r.file
		end

	end

	if ps[1] then
		if ps[#ps] ~= "" then
			ps[#ps+1]="" -- force a trailing /
		end
		r.folder=table.concat(ps,wpath.separator)
	end

	if r.root then -- root is part of dir
		r.dir=r.root..(r.folder or "")
	else
		r.dir=r.folder -- may be nil
	end
	
	r.path = (r.dir or "")..(r.file or "")

	return r
end

--[[#lua.wetgenes.path.normalize

remove ".." and "." components from the path string

]]
wpath.normalize=function(p)
	local pp=wpath.parse(p) -- we need to know if path contains a root
	local ps=wpath.split(p)
	
	local idx=2

	while idx <= #ps-1 do
		if ps[idx]=="" then -- remove double //
			table.remove(ps,idx)
		else -- just advance
			idx=idx+1
		end
	end
			
	idx=1
	while idx <= #ps do
		if ps[idx]=="." then -- just remove this one, no need to advance
			table.remove(ps,idx)
		elseif ps[idx]==".." then -- remove this and the previous one if we can
			if idx>( ( pp.root or p:sub(1,1)=="$" ) and 2 or 1) then -- can we remove previous part
				idx=idx-1
				table.remove(ps,idx)
				table.remove(ps,idx)
			else -- we can not remove so must ignore
--				table.remove(ps,idx)
				idx=idx+1
			end
		else -- just advance
			idx=idx+1
		end
	end

--print("N",p,wpath.join(ps))

	return wpath.join(ps)
end

--[[#lua.wetgenes.path.currentdir

Get the current working directory, this requires lfs and if lfs is not 
available then it will return wpath.root this path will have a trailing 
separator so can be joined directly to a filename.

	wpath.currentdir().."filename.ext"

]]
wpath.currentdir=function()

	local d
	if lfs then d=lfs.currentdir() end
	
	if d then -- make sure we end in a separator
		local ds=wpath.split(d)
		if ds[#ds] ~= "" then
			ds[#ds+1]="" -- force a trailing /
		end
		return wpath.join(ds)
	end

	return wpath.root -- default root
end


--[[#lua.wetgenes.path.resolve

Join all path segments and resolve them to absolute using wpath.join 
and wpath.normalize with a prepended wpath.currentdir as necessary.

]]
wpath.resolve=function(...)

	local p=wpath.join(...)

	if wpath.parse(p).root or p:sub(1,1)=="$" then -- already absolute
		return wpath.normalize(p) -- just normalize
	end
	
	return wpath.normalize( wpath.currentdir()..p ) -- prepend currentdir
end


--[[#lua.wetgenes.path.relative

Build a relative path from point a to point b this will probably be a 
bunch of ../../../ followed by some of the ending of the second 
argument.

]]
wpath.relative=function(pa,pb)

	local a=wpath.split(wpath.resolve(pa))
	local b=wpath.split(wpath.resolve(pb))
	
	if a[#a] == "" then -- remove trailing slash
		table.remove(a,#a)
	end

	local r={}
	local match=#a+1 -- if the test below falls through then the match is all of a
	for i=1,#a do
		if a[i] ~= b[i] then -- start of difference
			match=i
			break
		end
	end
	
	if match==1 or ( match==2 and a[1]=="" )  then -- no match
		return pb -- just return full path
	end

	for i=match,#a do r[#r+1]=".." end -- step back
	if #r==0 then r[#r+1]="." end -- start at current
	for i=match,#b do r[#r+1]=b[i] end -- step forward

	return wpath.join(r)
end

--[[#lua.wetgenes.path.parent

Resolve input and go up a single directory level, ideally you should 
pass in a directory, IE a string that ends in / or \ and we will return 
the parent of this directory.

If called repeatedly, then eventually we will return wpath.root

]]
wpath.parent=function(...)
	return wpath.resolve(...,"..","")
end




path=path or {}


path.getrelative=function(a,b)

	local r=wpath.relative(a,b)

--print("R",a,b,r)
	
	if r:sub(1,2)=="./" then r=r:sub(3) end
	if r:sub(-1)=="/" then r=r:sub(1,-2) end

	return r
end

path.getabsolute=function(p)

	local r=wpath.resolve(p)
	
	if r:sub(1,2)=="./" then r=r:sub(3) end
	if r:sub(-1)=="/" then r=r:sub(1,-2) end

	return r
end

path.normalize=function(p)

	local r=wpath.normalize(p)
	
	if r:sub(1,2)=="./" then r=r:sub(3) end
	if r:sub(-1)=="/" then r=r:sub(1,-2) end

	return r
end

path.translate=function(a,b)

	if type(a)=="table" then
		local t={}
		for i,v in ipairs(a) do
			t[i]=path.translate(v,b)
		end
		return t
	end
	
	b=b or "\\"
	local r=a
	
--	os.print("FUNCTION","path."..debug.getinfo(1).name,a,b)

	if b=="\\" then r=a:gsub("/" ,"\\") end
	if b=="/"  then r=a:gsub("\\","/")  end
	

	return r
	
end


-- return pathdir,pathfile
path._splitpath=function(p)

	local r=wpath.parse(p)
	
	return r.dir or "" , r.file or ""

end

path.join=function(...)

	local aa={...}
	
	if aa[1]==nil or aa[1]=="" then aa[1]="." end

	local n=""
	for i,v in ipairs(aa) do
		if path.isabsolute(v) then
			n=v
		else
			if n~="" then n=n.."/" end
			n=n..v
		end
	end
	
	n=path.normalize(n)
--	os.print("FUNCTION","path."..debug.getinfo(1).name,n)
	
	return n
end



path.isabsolute=function(a)

	local c1=a:sub(1,1)
	local c2=a:sub(2,2)
	
	local r= ( c1=="/" or c1=="\\" or c1=="$" or (c1=="\"" and c2=="$") or (c2==":") )

--	os.print("FUNCTION","path."..debug.getinfo(1).name,a,r)
	
	return r
	
end

path.wildcards=function(s)

-- escape
	local r=s

	r=r:gsub("([%+%.%-%^%$%(%)%%])",function(a) return "%"..a end)
	r=r:gsub("(%*+)",function(a) if a=="**" then return "[^/]*" end return ".*" end)

--	os.print("FUNCTION","path."..debug.getinfo(1).name,s,r)
	
	return s
	
end
-- AMALGAMATE FILE TAIL : /src/host/path.lua
-- AMALGAMATE FILE HEAD : /src/host/os.lua

os=os or {}

os.mkdir=function(s)
	return lfs.mkdir(s)
end

os.chdir=function(s)
--os.print("CD",s)
	return lfs.chdir(s)
end

os.isdir=function(s)
	local a=lfs.attributes(s)
	if a and a.mode=="directory" then return true end
	return false
end

os.pathsearch=function(name,...)
	local aa={...}
	for i=1,#aa do
		local p=aa[i]
		if p then
			local mode=nil
			
			if p:find(";") then
				mode=";"
			elseif p:find(":") then
				if p:find(":") == "2" then -- bad windows
					mode=nil
				else
					mode=":"
				end
			end
			
			local ps={}
			if mode then
				local fi=1
				while true do
					local fa,fb=string.find(p,mode,fi)
					if fa then
						local s=string.sub(p,fi,fa-1)
						ps[#ps+1]=s
						fi=fb+1
					else
						break
					end
				end
				ps[#ps+1]=string.sub(p,fi)
			else
				ps[#ps+1]=p
			end

			for _,n in ipairs(ps) do
				local t=n.."/"..name
				if os.isfile(t) then return n end
			end
		end
	end

-- os.print("FUNCTION","os."..debug.getinfo(1).name)

end

--[[

os.chmod=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
os.copyfile=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
os._is64bit=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
os.isdir=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end

os.getversion=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end

os.islink=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end


os.mkdir=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
os.realpath=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
os.rmdir=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
os.stat=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
os.writefile_ifnotequal=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end

]]

os.matchstart=function(p)
	local it={}
	
	it.p=p
	it.pd,it.pf=path._splitpath(p)
	
	if it.pd=="" then it.pd="." end

	pcall( function() it.dir_func,it.dir_data=lfs.dir(it.pd) end )
--ass
-- very very simple glob hack, any other special character will messup

	it.pf=it.pf:gsub("%.","%.")
	it.pf=it.pf:gsub("%*",".*")
	it.pf=it.pf:gsub("%?",".")

--	os.print("FUNCTION","os."..debug.getinfo(1).name,p,it.pd,it.pf)
		
	return it
end
os.matchdone=function()end

os.matchnext=function(it)
--	os.print("FUNCTION","os."..debug.getinfo(1).name,it)
	
	if not it.dir_func then return nil end -- no dir
	
	while true do
		it.filename=it.dir_func(it.dir_data)


		if not it.filename then return nil end -- end

		if it.filename~="." and it.filename~=".." then 
			if it.filename:match(it.pf) then
--				os.print(it.filename)
				return true
			end -- a match
		end
	end
	
end

os.matchname=function(it)

--	os.print("FUNCTION","os."..debug.getinfo(1).name,it.pd..it.filename)
	
	return it.filename	

end



os.matchisfile=function(it)

--	os.print("FUNCTION","os."..debug.getinfo(1).name,it.pd..it.filename,os.isfile( os.matchname(it)))
	
	return os.isfile( path.join( it.pd , it.filename) )

end

os.uuid=function()

	local r=string.format("%04X%04X-%04X-%04X-%04X-%04X%04X%04X",
		math.random(0,0xffff),math.random(0,0xffff),
		math.random(0,0xffff),math.random(0,0xffff),math.random(0,0xffff),
		math.random(0,0xffff),math.random(0,0xffff),math.random(0,0xffff))
		
--	os.print("FUNCTION","os."..debug.getinfo(1).name,r)

	return r
end



os.getcwd=function()

--	os.print("FUNCTION","os."..debug.getinfo(1).name)
	
	return lfs.currentdir()
	
end

os.isfile=function(a)

	local r=lfs.attributes(a,'mode')=="file"

--	os.print("FUNCTION","os."..debug.getinfo(1).name,a,r)
	
	return r
end


os.locate=function(...)

	for _,a in ipairs{...} do
		if lfs.attributes(a,'mode')=="file" then return path.getabsolute(a) end
		local r
		local paths=path._split(premake.path,";")
		for i,p in ipairs(paths) do
			local t=path.getabsolute(p.."/"..a)
			if lfs.attributes(t,'mode')=="file" then r=t break end
		end
		if r then return r end
	end
--	os.print("FUNCTION","os."..debug.getinfo(1).name,a,r)

	return nil
end


	
	

-- AMALGAMATE FILE TAIL : /src/host/os.lua
-- AMALGAMATE FILE HEAD : /src/host/premake.lua

-- we really need LFS
lfs=require("lfs")


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


-- AMALGAMATE FILE TAIL : /src/host/premake.lua
-- AMALGAMATE FILE HEAD : /src/base/os.lua
--
-- os.lua
-- Additions to the OS namespace.
-- Copyright (c) 2002-2011 Jason Perkins and the Premake project
--


--
-- Same as os.execute(), but accepts string formatting arguments.
--

	function os.executef(cmd, ...)
		cmd = string.format(cmd,...)
		return os.execute(cmd)
	end


--
-- Scan the well-known system locations for a particular library.
--

	local function parse_ld_so_conf(conf_file)
		-- Linux ldconfig file parser to find system library locations
		local first, last
		local dirs = { }
		local file = io.open(conf_file)
		-- Handle missing ld.so.conf (BSDs) gracefully
		if file == nil then
			return dirs
		end
		for line in io.lines(conf_file) do
			-- ignore comments
			first = line:find("#", 1, true)
			if first ~= nil then
				line = line:sub(1, first - 1)
			end

			if line ~= "" then
				-- check for include files
				first, last = line:find("include%s+")
				if first ~= nil then
					-- found include glob
					local include_glob = line:sub(last + 1)
					local includes = os.matchfiles(include_glob)
					for _, v in ipairs(includes) do
						dirs = table.join(dirs, parse_ld_so_conf(v))
					end
				else
					-- found an actual ld path entry
					table.insert(dirs, line)
				end
			end
		end
		return dirs
	end

	function os.findlib(libname)
		local path, formats

		-- assemble a search path, depending on the platform
		if os.is("windows") then
			formats = { "%s.dll", "%s" }
			path = os.getenv("PATH")
		elseif os.is("haiku") then
			formats = { "lib%s.so", "%s.so" }
			path = os.getenv("LIBRARY_PATH")
		else
			if os.is("macosx") then
				formats = { "lib%s.dylib", "%s.dylib" }
				path = os.getenv("DYLD_LIBRARY_PATH")
			else
				formats = { "lib%s.so", "%s.so" }
				path = os.getenv("LD_LIBRARY_PATH") or ""

				for _, v in ipairs(parse_ld_so_conf("/etc/ld.so.conf")) do
					path = path .. ":" .. v
				end
			end

			table.insert(formats, "%s")
			path = path or ""
			if os.is64bit() then
				path = path .. ":/lib64:/usr/lib64/:usr/local/lib64"
			end
			path = path .. ":/lib:/usr/lib:/usr/local/lib"
		end

		for _, fmt in ipairs(formats) do
			local name = string.format(fmt, libname)
			local result = os.pathsearch(name, path)
			if result then return result end
		end
	end



--
-- Retrieve the current operating system ID string.
--

	function os.get()
		return _OPTIONS.os or _OS
	end



--
-- Check the current operating system; may be set with the /os command line flag.
--

	function os.is(id)
		return (os.get():lower() == id:lower())
	end



--
-- Determine if the current system is running a 64-bit architecture
--

	local _64BitHostTypes = {
		"x86_64",
		"ia64",
		"amd64",
		"ppc64",
		"powerpc64",
		"sparc64"
	}

	function os.is64bit()
		-- Call the native code implementation. If this returns true then
		-- we're 64-bit, otherwise do more checking locally
--		if (os._is64bit()) then
--			return true
--		end

		-- Identify the system
		local arch
		if _OS == "windows" then
			arch = os.getenv("PROCESSOR_ARCHITECTURE")
		elseif _OS == "macosx" then
			arch = os.outputof("echo $HOSTTYPE")
		else
			arch = os.outputof("uname -m")
		end

		-- Check our known 64-bit identifiers
		arch = arch:lower()
		for _, hosttype in ipairs(_64BitHostTypes) do
			if arch:find(hosttype) then
				return true
			end
		end
		return false
	end



--
-- The os.matchdirs() and os.matchfiles() functions
--

	local function domatch(result, mask, wantfiles)
		-- need to remove extraneous path info from the mask to ensure a match
		-- against the paths returned by the OS. Haven't come up with a good
		-- way to do it yet, so will handle cases as they come up
		if mask:startswith("./") then
			mask = mask:sub(3)
		end

		-- strip off any leading directory information to find out
		-- where the search should take place
		local basedir = mask
		local starpos = mask:find("%*")
		if starpos then
			basedir = basedir:sub(1, starpos - 1)
		end
		basedir = path.getdirectory(basedir)

		-- recurse into subdirectories?
		local recurse = mask:find("**", nil, true)

		-- convert mask to a Lua pattern
		mask = path.wildcards(mask)

		local function matchwalker(basedir)
			local wildcard = path.join(basedir, "*")
			-- retrieve files from OS and test against mask
			local m = os.matchstart(wildcard)
			while (os.matchnext(m)) do
				local isfile = os.matchisfile(m)
				if ((wantfiles and isfile) or (not wantfiles and not isfile)) then
					local basename = os.matchname(m)
					local fullname = path.join(basedir, basename)
					if basename ~= ".." and fullname:match(mask) == fullname then
						table.insert(result, fullname)
					end
				end
			end
			os.matchdone(m)

			-- check subdirectories
			if recurse then
				m = os.matchstart(wildcard)
				while (os.matchnext(m)) do
					if not os.matchisfile(m) then
						local dirname = os.matchname(m)
						if (not dirname:startswith(".")) then
							matchwalker(path.join(basedir, dirname))
						end
					end
				end
				os.matchdone(m)
			end
		end

		matchwalker(basedir)
	end

	function os.matchdirs(...)
		local result = { }
		for _, mask in ipairs({...}) do
			domatch(result, mask, false)
		end
		return result
	end

	function os.matchfiles(...)
		local result = { }
		for _, mask in ipairs({...}) do
			domatch(result, mask, true)
		end
		return result
	end



--
-- An overload of the os.mkdir() function, which will create any missing
-- subdirectories along the path.
--

	local builtin_mkdir = os.mkdir
	function os.mkdir(p)
		local dir = iif(p:startswith("/"), "/", "")
		for part in p:gmatch("[^/]+") do
			dir = dir .. part

			if (part ~= "" and not path.isabsolute(part) and not os.isdir(dir)) then
				local ok, err = builtin_mkdir(dir)
				if (not ok) then
					return nil, err
				end
			end

			dir = dir .. "/"
		end

		return true
	end


--
-- Run a shell command and return the output.
--

	function os.outputof(cmd)
		local pipe = io.popen(cmd)
		local result = pipe:read('*a')
		pipe:close()
		return result
	end


--
-- Remove a directory, along with any contained files or subdirectories.
--

	local builtin_rmdir = os.rmdir
	function os.rmdir(p)
		-- recursively remove subdirectories
		local dirs = os.matchdirs(p .. "/*")
		for _, dname in ipairs(dirs) do
			os.rmdir(dname)
		end

		-- remove any files
		local files = os.matchfiles(p .. "/*")
		for _, fname in ipairs(files) do
			os.remove(fname)
		end

		-- remove this directory
		builtin_rmdir(p)
	end

-- AMALGAMATE FILE TAIL : /src/base/os.lua
-- AMALGAMATE FILE HEAD : /src/base/path.lua
--
-- path.lua
-- Path manipulation functions.
-- Copyright (c) 2002-2010 Jason Perkins and the Premake project
--


--
-- Retrieve the filename portion of a path, without any extension.
--

	function path.getbasename(p)
		local name = path.getname(p)
		local i = name:findlast(".", true)
		if (i) then
			return name:sub(1, i - 1)
		else
			return name
		end
	end


--
-- Retrieve the directory portion of a path, or an empty string if
-- the path does not include a directory.
--

	function path.getdirectory(p)
		local i = p:findlast("/", true)
		if (i) then
			if i > 1 then i = i - 1 end
			return p:sub(1, i)
		else
			return "."
		end
	end


--
-- Retrieve the drive letter, if a Windows path.
--

	function path.getdrive(p)
		local ch1 = p:sub(1,1)
		local ch2 = p:sub(2,2)
		if ch2 == ":" then
			return ch1
		end
	end



--
-- Retrieve the file extension.
--

	function path.getextension(p)
		local i = p:findlast(".", true)
		if (i) then
			return p:sub(i)
		else
			return ""
		end
	end



--
-- Retrieve the filename portion of a path.
--

	function path.getname(p)
		local i = p:findlast("[/\\]")
		if (i) then
			return p:sub(i + 1)
		else
			return p
		end
	end


--
-- Returns true if the filename represents a C/C++ source code file. This check
-- is used to prevent passing non-code files to the compiler in makefiles. It is
-- not foolproof, but it has held up well. I'm open to better suggestions.
--

	function path.iscfile(fname)
		local extensions = { ".c", ".s", ".m" }
		local ext = path.getextension(fname):lower()
		return table.contains(extensions, ext)
	end

	function path.iscppfile(fname)
		local extensions = { ".cc", ".cpp", ".cxx", ".c", ".s", ".m", ".mm" }
		local ext = path.getextension(fname):lower()
		return table.contains(extensions, ext)
	end

	function path.iscppheader(fname)
		local extensions = { ".h", ".hh", ".hpp", ".hxx" }
		local ext = path.getextension(fname):lower()
		return table.contains(extensions, ext)
	end



--
-- Returns true if the filename represents a Windows resource file. This check
-- is used to prevent passing non-resources to the compiler in makefiles.
--

	function path.isresourcefile(fname)
		local extensions = { ".rc" }
		local ext = path.getextension(fname):lower()
		return table.contains(extensions, ext)
	end



--
-- Takes a path which is relative to one location and makes it relative
-- to another location instead.
--

	function path.rebase(p, oldbase, newbase)
		p = path.getabsolute(path.join(oldbase, p))
		p = path.getrelative(newbase, p)
		return p
	end


--
-- Convert the separators in a path from one form to another. If `sep`
-- is nil, then a platform-specific separator is used.
--

	local builtin_translate = path.translate

	function path.translate(p, sep)
		if not sep then
			if os.is("windows") then
				sep = "\\"
			else
				sep = "/"
			end
		end
		return builtin_translate(p, sep)
	end


--
-- Converts from a simple wildcard syntax, where * is "match any"
-- and ** is "match recursive", to the corresponding Lua pattern.
--
-- @param pattern
--    The wildcard pattern to convert.
-- @returns
--    The corresponding Lua pattern.
--

	function path.wildcards(pattern)
		-- Escape characters that have special meanings in Lua patterns
		pattern = pattern:gsub("([%+%.%-%^%$%(%)%%])", "%%%1")

		-- Replace wildcard patterns with special placeholders so I don't
		-- have competing star replacements to worry about
		pattern = pattern:gsub("%*%*", "\001")
		pattern = pattern:gsub("%*", "\002")

		-- Replace the placeholders with their Lua patterns
		pattern = pattern:gsub("\001", ".*")
		pattern = pattern:gsub("\002", "[^/]*")

		return pattern
	end
-- AMALGAMATE FILE TAIL : /src/base/path.lua
-- AMALGAMATE FILE HEAD : /src/base/string.lua
--
-- string.lua
-- Additions to Lua's built-in string functions.
-- Copyright (c) 2002-2008 Jason Perkins and the Premake project
--


--
-- Returns an array of strings, each of which is a substring of s
-- formed by splitting on boundaries formed by `pattern`.
-- 

	function string.explode(s, pattern, plain)
		if (pattern == '') then return false end
		local pos = 0
		local arr = { }
		for st,sp in function() return s:find(pattern, pos, plain) end do
			table.insert(arr, s:sub(pos, st-1))
			pos = sp + 1
		end
		table.insert(arr, s:sub(pos))
		return arr
	end
	


--
-- Find the last instance of a pattern in a string.
--

	function string.findlast(s, pattern, plain)
		local curr = 0
		repeat
			local next = s:find(pattern, curr + 1, plain)
			if (next) then curr = next end
		until (not next)
		if (curr > 0) then
			return curr
		end	
	end



--
-- Returns true if `haystack` starts with the sequence `needle`.
--

	function string.startswith(haystack, needle)
		return (haystack:find(needle, 1, true) == 1)
	end
-- AMALGAMATE FILE TAIL : /src/base/string.lua
-- AMALGAMATE FILE HEAD : /src/base/table.lua
--
-- table.lua
-- Additions to Lua's built-in table functions.
-- Copyright (c) 2002-2008 Jason Perkins and the Premake project
--
	

--
-- Returns true if the table contains the specified value.
--

	function table.contains(t, value)
		for _,v in pairs(t) do
			if (v == value) then
				return true
			end
		end
		return false
	end
	
		
--
-- Enumerates an array of objects and returns a new table containing
-- only the value of one particular field.
--

	function table.extract(arr, fname)
		local result = { }
		for _,v in ipairs(arr) do
			table.insert(result, v[fname])
		end
		return result
	end
	
	

--
-- Flattens a hierarchy of tables into a single array containing all
-- of the values.
--

	function table.flatten(arr)
		local result = { }
		
		local function flatten(arr)
			for _, v in ipairs(arr) do
				if type(v) == "table" then
					flatten(v)
				else
					table.insert(result, v)
				end
			end
		end
		
		flatten(arr)
		return result
	end


--
-- Merges an array of items into a string.
--

	function table.implode(arr, before, after, between)
		local result = ""
		for _,v in ipairs(arr) do
			if (result ~= "" and between) then
				result = result .. between
			end
			result = result .. before .. v .. after
		end
		return result
	end


--
-- Inserts a value of array of values into a table. If the value is
-- itself a table, its contents are enumerated and added instead. So 
-- these inputs give these outputs:
--
--   "x" -> { "x" }
--   { "x", "y" } -> { "x", "y" }
--   { "x", { "y" }} -> { "x", "y" }
--

	function table.insertflat(tbl, values)
		if type(values) == "table" then
			for _, value in ipairs(values) do
				table.insertflat(tbl, value)
			end
		else
			table.insert(tbl, values)
		end
	end


--
-- Returns true if the table is empty, and contains no indexed or keyed values.
--

	function table.isempty(t)
		return next(t) == nil
	end


--
-- Adds the values from one array to the end of another and
-- returns the result.
--

	function table.join(...)
		local result = { }
		for _,t in ipairs({...}) do
			if type(t) == "table" then
				for _,v in ipairs(t) do
					table.insert(result, v)
				end
			else
				table.insert(result, t)
			end
		end
		return result
	end


--
-- Return a list of all keys used in a table.
--

	function table.keys(tbl)
		local keys = {}
		for k, _ in pairs(tbl) do
			table.insert(keys, k)
		end
		return keys
	end


--
-- Adds the key-value associations from one table into another
-- and returns the resulting merged table.
--

	function table.merge(...)
		local result = { }
		for _,t in ipairs({arg}) do
			if type(t) == "table" then
				for k,v in pairs(t) do
					result[k] = v
				end
			else
				error("invalid value")
			end
		end
		return result
	end
	


--
-- Translates the values contained in array, using the specified
-- translation table, and returns the results in a new array.
--

	function table.translate(arr, translation)
		local result = { }
		for _, value in ipairs(arr) do
			local tvalue
			if type(translation) == "function" then
				tvalue = translation(value)
			else
				tvalue = translation[value]
			end
			if (tvalue) then
				table.insert(result, tvalue)
			end
		end
		return result
	end
	
		
-- AMALGAMATE FILE TAIL : /src/base/table.lua
-- AMALGAMATE FILE HEAD : /src/base/io.lua
--
-- io.lua
-- Additions to the I/O namespace.
-- Copyright (c) 2008-2009 Jason Perkins and the Premake project
--


--
-- Prepare to capture the output from all subsequent calls to io.printf(), 
-- used for automated testing of the generators.
--

	function io.capture()
		io.captured = ''
	end
	
	
	
--
-- Returns the captured text and stops capturing.
--

	function io.endcapture()
		local captured = io.captured
		io.captured = nil
		return captured
	end
	
	
--
-- Open an overload of the io.open() function, which will create any missing
-- subdirectories in the filename if "mode" is set to writeable.
--

	local builtin_open = io.open
	function io.open(fname, mode)
		if (mode) then
			if (mode:find("w")) then
				local dir = path.getdirectory(fname)
				ok, err = os.mkdir(dir)
				if (not ok) then
					error(err, 0)
				end
			end
		end
		return builtin_open(fname, mode)
	end



-- 
-- A shortcut for printing formatted output to an output stream.
--

	function io.printf(msg, ...)
		if not io.eol then
			io.eol = "\n"
		end

		if not io.indent then
			io.indent = "\t"
		end

		if type(msg) == "number" then
			s = string.rep(io.indent, msg) .. string.format(...)
		else
			s = string.format(msg,...)
		end
		
		if io.captured then
			io.captured = io.captured .. s .. io.eol
		else
			io.write(s)
			io.write(io.eol)
		end
	end


--
-- Because I use io.printf() so often in the generators, create a terse shortcut
-- for it. This saves me typing, and also reduces the size of the executable.
--

	_p = io.printf
-- AMALGAMATE FILE TAIL : /src/base/io.lua
-- AMALGAMATE FILE HEAD : /src/base/globals.lua
--
-- globals.lua
-- Global tables and variables, replacements and extensions to Lua's global functions.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--
	
	
-- A top-level namespace for support functions

	premake = { }
	

-- The list of supported platforms; also update list in cmdline.lua

	premake.platforms = 
	{
		Native = 
		{ 
			cfgsuffix       = "",
		},
		x32 = 
		{ 
			cfgsuffix       = "32",
		},
		x64 = 
		{ 
			cfgsuffix       = "64",
		},
		Universal = 
		{ 
			cfgsuffix       = "univ",
		},
		Universal32 = 
		{ 
			cfgsuffix       = "univ32",
		},
		Universal64 = 
		{ 
			cfgsuffix       = "univ64",
		},
		PS3 = 
		{ 
			cfgsuffix       = "ps3",
			iscrosscompiler = true,
			nosharedlibs    = true,
			namestyle       = "PS3",
		},
		WiiDev =
		{
			cfgsuffix       = "wii",
			iscrosscompiler = true,
			namestyle       = "PS3",
		},
		Xbox360 = 
		{ 
			cfgsuffix       = "xbox360",
			iscrosscompiler = true,
			namestyle       = "windows",
		},
	}


--
-- A replacement for Lua's built-in dofile() function, this one sets the
-- current working directory to the script's location, enabling script-relative
-- referencing of other files and resources.
--

	local builtin_dofile = dofile
	function dofile(fname)
		-- remember the current working directory and file; I'll restore it shortly
		local oldcwd = os.getcwd()
		local oldfile = _SCRIPT

		-- if the file doesn't exist, check the search path
		if (not os.isfile(fname)) then
			local path = os.pathsearch(fname, _OPTIONS["scripts"], os.getenv("PREMAKE_PATH"))
			if (path) then
				fname = path.."/"..fname
			end
		end

		-- use the absolute path to the script file, to avoid any file name
		-- ambiguity if an error should arise
		_SCRIPT = path.getabsolute(fname)
		
		-- switch the working directory to the new script location
		local newcwd = path.getdirectory(_SCRIPT)
		os.chdir(newcwd)
		
		-- run the chunk. How can I catch variable return values?
		local a, b, c, d, e, f = builtin_dofile(_SCRIPT)
		
		-- restore the previous working directory when done
		_SCRIPT = oldfile
		os.chdir(oldcwd)
		return a, b, c, d, e, f
	end



--
-- "Immediate If" - returns one of the two values depending on the value of expr.
--

	function iif(expr, trueval, falseval)
		if (expr) then
			return trueval
		else
			return falseval
		end
	end
	
	
	
--
-- A shortcut for including another "premake4.lua" file, often used for projects.
--

	function include(fname)
		return dofile(fname .. "/premake4.lua")
	end



--
-- A shortcut for printing formatted output.
--

	function printf(msg, ...)
		print(string.format(msg,...))
	end

	
		
--
-- An extension to type() to identify project object types by reading the
-- "__type" field from the metatable.
--

	local builtin_type = type	
	function type(t)
		local mt = getmetatable(t)
		if (mt) then
			if (mt.__type) then
				return mt.__type
			end
		end
		return builtin_type(t)
	end
	
-- AMALGAMATE FILE TAIL : /src/base/globals.lua
-- AMALGAMATE FILE HEAD : /src/base/action.lua
--
-- action.lua
-- Work with the list of registered actions.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--

	premake.action = { }


--
-- The list of registered actions.
--

	premake.action.list = { }
	

--
-- Register a new action.
--
-- @param a
--    The new action object.
-- 

	function premake.action.add(a)
		-- validate the action object, at least a little bit
		local missing
		for _, field in ipairs({"description", "trigger"}) do
			if (not a[field]) then
				missing = field
			end
		end
		
		if (missing) then
			error("action needs a " .. missing, 3)
		end

		-- add it to the master list
		premake.action.list[a.trigger] = a		
	end


--
-- Trigger an action.
--
-- @param name
--    The name of the action to be triggered.
-- @returns
--    None.
--

	function premake.action.call(name)
		local a = premake.action.list[name]
		for sln in premake.solution.each() do
			if a.onsolution then
				a.onsolution(sln)
			end
			for prj in premake.solution.eachproject(sln) do
				if a.onproject then
					a.onproject(prj)
				end
			end
		end
		
		if a.execute then
			a.execute()
		end
	end


--
-- Retrieve the current action, as determined by _ACTION.
--
-- @return
--    The current action, or nil if _ACTION is nil or does not match any action.
--

	function premake.action.current()
		return premake.action.get(_ACTION)
	end
	
	
--
-- Retrieve an action by name.
--
-- @param name
--    The name of the action to retrieve.
-- @returns
--    The requested action, or nil if the action does not exist.
--

	function premake.action.get(name)
		return premake.action.list[name]
	end


--
-- Iterator for the list of actions.
--

	function premake.action.each()
		-- sort the list by trigger
		local keys = { }
		for _, action in pairs(premake.action.list) do
			table.insert(keys, action.trigger)
		end
		table.sort(keys)
		
		local i = 0
		return function()
			i = i + 1
			return premake.action.list[keys[i]]
		end
	end


--
-- Activates a particular action.
--
-- @param name
--    The name of the action to activate.
--

	function premake.action.set(name)
		_ACTION = name
		-- Some actions imply a particular operating system
		local action = premake.action.get(name)
		if action then
			_OS = action.os or _OS
		end
	end


--
-- Determines if an action supports a particular language or target type.
--
-- @param action
--    The action to test.
-- @param feature
--    The feature to check, either a programming language or a target type.
-- @returns
--    True if the feature is supported, false otherwise.
--

	function premake.action.supports(action, feature)
		if not action then
			return false
		end
		if action.valid_languages then
			if table.contains(action.valid_languages, feature) then
				return true
			end
		end
		if action.valid_kinds then
			if table.contains(action.valid_kinds, feature) then
				return true
			end
		end
		return false
	end
-- AMALGAMATE FILE TAIL : /src/base/action.lua
-- AMALGAMATE FILE HEAD : /src/base/option.lua
--
-- option.lua
-- Work with the list of registered options.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--

	premake.option = { }


--
-- The list of registered options.
--

	premake.option.list = { }


--
-- Register a new option.
--
-- @param opt
--    The new option object.
--

	function premake.option.add(opt)
		-- some sanity checking
		local missing
		for _, field in ipairs({ "description", "trigger" }) do
			if (not opt[field]) then
				missing = field
			end
		end

		if (missing) then
			error("option needs a " .. missing, 3)
		end

		-- add it to the master list
		premake.option.list[opt.trigger] = opt
	end


--
-- Retrieve an option by name.
--
-- @param name
--    The name of the option to retrieve.
-- @returns
--    The requested option, or nil if the option does not exist.
--

	function premake.option.get(name)
		return premake.option.list[name]
	end


--
-- Iterator for the list of options.
--

	function premake.option.each()
		-- sort the list by trigger
		local keys = { }
		for _, option in pairs(premake.option.list) do
			table.insert(keys, option.trigger)
		end
		table.sort(keys)

		local i = 0
		return function()
			i = i + 1
			return premake.option.list[keys[i]]
		end
	end


--
-- Validate a list of user supplied key/value pairs against the list of registered options.
--
-- @param values
--    The list of user supplied key/value pairs.
-- @returns
---   True if the list of pairs are valid, false and an error message otherwise.
--

	function premake.option.validate(values)
		for key, value in pairs(values) do
			-- does this option exist
			local opt = premake.option.get(key)
			if (not opt) then
				return false, "invalid option '" .. key .. "'"
			end

			-- does it need a value?
			if (opt.value and value == "") then
				return false, "no value specified for option '" .. key .. "'"
			end

			-- is the value allowed?
			if opt.allowed then
				local found = false
				for _, match in ipairs(opt.allowed) do
					if match[1] == value then
						found = true
						break
					end
				end
				if not found then
					return false, string.format("invalid value '%s' for option '%s'", value, key)
				end
			end
		end
		return true
	end
-- AMALGAMATE FILE TAIL : /src/base/option.lua
-- AMALGAMATE FILE HEAD : /src/base/tree.lua
--
-- tree.lua
-- Functions for working with the source code tree.
-- Copyright (c) 2009 Jason Perkins and the Premake project
--

	premake.tree = { }
	local tree = premake.tree


--
-- Create a new tree.
--
-- @param n
--    The name of the tree, applied to the root node (optional).
--

	function premake.tree.new(n)
		local t = {
			name = n,
			children = { }
		}
		return t
	end


--
-- Add a new node to the tree, or returns the current node if it already exists.
--
-- @param tr
--    The tree to contain the new node.
-- @param p
--    The path of the new node.
-- @param onaddfunc
--     A function to call when a new node is added to the tree. Receives the
--     new node as an argument.
-- @returns
--    The new tree node.
--

	function premake.tree.add(tr, p, onaddfunc)
		-- Special case "." refers to the current node
		if p == "." then
			return tr
		end
		
		-- Look for the immediate parent for this new node, creating it if necessary.
		-- Recurses to create as much of the tree as necessary.
		local parentnode = tree.add(tr, path.getdirectory(p), onaddfunc)

		-- Another special case, ".." refers to the parent node and doesn't create anything
		local childname = path.getname(p)
		if childname == ".." then
			return parentnode
		end
		
		-- Create the child if necessary. If two children with the same name appear
		-- at the same level, make sure they have the same path to prevent conflicts
		-- i.e. ../Common and ../../Common can both appear at the top of the tree
		-- yet they have different paths (Bug #3016050)
		local childnode = parentnode.children[childname]
		if not childnode or childnode.path ~= p then
			childnode = tree.insert(parentnode, tree.new(childname))
			childnode.path = p
			if onaddfunc then
				onaddfunc(childnode)
			end
		end
		
		return childnode
	end


--
-- Insert one tree into another.
--
-- @param parent
--    The parent tree, to contain the child.
-- @param child
--    The child tree, to be inserted.
--

	function premake.tree.insert(parent, child)
		table.insert(parent.children, child)
		if child.name then
			parent.children[child.name] = child
		end
		child.parent = parent
		return child
	end


--
-- Gets the node's relative path from it's parent. If the parent does not have
-- a path set (it is the root or other container node) returns the full node path.
--
-- @param node
--    The node to query.
--

	function premake.tree.getlocalpath(node)
		if node.parent.path then
			return node.name
		elseif node.cfg then
			return node.cfg.name
		else
			return node.path
		end
	end


--
-- Remove a node from a tree.
--
-- @param node
--    The node to remove.
--

	function premake.tree.remove(node)
		local children = node.parent.children
		for i = 1, #children do
			if children[i] == node then
				table.remove(children, i)
			end
		end
		node.children = {}
	end


--
-- Sort the nodes of a tree in-place.
--
-- @param tr
--    The tree to sort.
--

	function premake.tree.sort(tr)
		tree.traverse(tr, {
			onnode = function(node)
				table.sort(node.children, function(a,b)
					return a.name < b.name
				end)
			end
		}, true)
	end


--
-- Traverse a tree.
--
-- @param t
--    The tree to traverse.
-- @param fn
--    A collection of callback functions, which may contain any or all of the
--    following entries. Entries are called in this order.
--
--    onnode         - called on each node encountered
--    onbranchenter  - called on branches, before processing children
--    onbranch       - called only on branch nodes
--    onleaf         - called only on leaf nodes
--    onbranchexit   - called on branches, after processing children
--
--    Callbacks receive two arguments: the node being processed, and the
--    current traversal depth.
--
-- @param includeroot
--    True to include the root node in the traversal, otherwise it will be skipped.
-- @param initialdepth
--    An optional starting value for the traversal depth; defaults to zero.
--

	function premake.tree.traverse(t, fn, includeroot, initialdepth)

		-- forward declare my handlers, which call each other
		local donode, dochildren

		-- process an individual node
		donode = function(node, fn, depth)
			if node.isremoved then 
				return 
			end

			if fn.onnode then 
				fn.onnode(node, depth) 
			end
			
			if #node.children > 0 then
				if fn.onbranchenter then
					fn.onbranchenter(node, depth)
				end
				if fn.onbranch then 
					fn.onbranch(node, depth) 
				end
				dochildren(node, fn, depth + 1)
				if fn.onbranchexit then
					fn.onbranchexit(node, depth)
				end
			else
				if fn.onleaf then 
					fn.onleaf(node, depth) 
				end
			end
		end
		
		-- this goofy iterator allows nodes to be removed during the traversal
		dochildren = function(parent, fn, depth)
			local i = 1
			while i <= #parent.children do
				local node = parent.children[i]
				donode(node, fn, depth)
				if node == parent.children[i] then
					i = i + 1
				end
			end
		end
		
		-- set a default initial traversal depth, if one wasn't set
		if not initialdepth then
			initialdepth = 0
		end

		if includeroot then
			donode(t, fn, initialdepth)
		else
			dochildren(t, fn, initialdepth)
		end
	end
-- AMALGAMATE FILE TAIL : /src/base/tree.lua
-- AMALGAMATE FILE HEAD : /src/base/solution.lua
--
-- solution.lua
-- Work with the list of solutions loaded from the script.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--

	premake.solution = { }


-- The list of defined solutions (which contain projects, etc.)

	premake.solution.list = { }


--
-- Create a new solution and add it to the session.
--
-- @param name
--    The new solution's name.
--

	function premake.solution.new(name)
		local sln = { }

		-- add to master list keyed by both name and index
		table.insert(premake.solution.list, sln)
		premake.solution.list[name] = sln
			
		-- attach a type descriptor
		setmetatable(sln, { __type="solution" })

		sln.name           = name
		sln.basedir        = os.getcwd()			
		sln.projects       = { }
		sln.blocks         = { }
		sln.configurations = { }
		return sln
	end


--
-- Iterate over the collection of solutions in a session.
--
-- @returns
--    An iterator function.
--

	function premake.solution.each()
		local i = 0
		return function ()
			i = i + 1
			if i <= #premake.solution.list then
				return premake.solution.list[i]
			end
		end
	end


--
-- Iterate over the projects of a solution.
--
-- @param sln
--    The solution.
-- @returns
--    An iterator function.
--

	function premake.solution.eachproject(sln)
		local i = 0
		return function ()
			i = i + 1
			if (i <= #sln.projects) then
				return premake.solution.getproject(sln, i)
			end
		end
	end


--
-- Retrieve a solution by name or index.
--
-- @param key
--    The solution key, either a string name or integer index.
-- @returns
--    The solution with the provided key.
--

	function premake.solution.get(key)
		return premake.solution.list[key]
	end


--
-- Retrieve the project at a particular index.
--
-- @param sln
--    The solution.
-- @param idx
--    An index into the array of projects.
-- @returns
--    The project at the given index.
--

	function premake.solution.getproject(sln, idx)
		-- retrieve the root configuration of the project, with all of
		-- the global (not configuration specific) settings collapsed
		local prj = sln.projects[idx]
		local cfg = premake.getconfig(prj)
		
		-- root configuration doesn't have a name; use the project's
		cfg.name = prj.name
		return cfg
	end
-- AMALGAMATE FILE TAIL : /src/base/solution.lua
-- AMALGAMATE FILE HEAD : /src/base/project.lua
--
-- project.lua
-- Functions for working with the project data.
-- Copyright (c) 2002 Jason Perkins and the Premake project
--

	premake.project = { }


--
-- Create a tree from a project's list of files, representing the filesystem hierarchy.
--
-- @param prj
--    The project containing the files to map.
-- @returns
--    A new tree object containing a corresponding filesystem hierarchy. The root node
--    contains a reference back to the original project: prj = tr.project.
--

	function premake.project.buildsourcetree(prj)
		local tr = premake.tree.new(prj.name)
		tr.project = prj

		local isvpath

		local function onadd(node)
			node.isvpath = isvpath
		end

		for fcfg in premake.project.eachfile(prj) do
			isvpath = (fcfg.name ~= fcfg.vpath)
			local node = premake.tree.add(tr, fcfg.vpath, onadd)
			node.cfg = fcfg
		end

		premake.tree.sort(tr)
		return tr
	end


--
-- Returns an iterator for a set of build configuration settings. If a platform is
-- specified, settings specific to that platform and build configuration pair are
-- returned.
--

	function premake.eachconfig(prj, platform)
		-- I probably have the project root config, rather than the actual project
		if prj.project then prj = prj.project end

		local cfgs = prj.solution.configurations
		local i = 0

		return function ()
			i = i + 1
			if i <= #cfgs then
				return premake.getconfig(prj, cfgs[i], platform)
			end
		end
	end



--
-- Iterator for a project's files; returns a file configuration object.
--

	function premake.project.eachfile(prj)
		-- project root config contains the file config list
		if not prj.project then prj = premake.getconfig(prj) end
		local i = 0
		local t = prj.files
		return function ()
			i = i + 1
			if (i <= #t) then
				local fcfg = prj.__fileconfigs[t[i]]
				fcfg.vpath = premake.project.getvpath(prj, fcfg.name)
				return fcfg
			end
		end
	end



--
-- Apply XML escaping to a value.
--

	function premake.esc(value)
		if (type(value) == "table") then
			local result = { }
			for _,v in ipairs(value) do
				table.insert(result, premake.esc(v))
			end
			return result
		else
			value = value:gsub('&',  "&amp;")
			value = value:gsub('"',  "&quot;")
			value = value:gsub("'",  "&apos;")
			value = value:gsub('<',  "&lt;")
			value = value:gsub('>',  "&gt;")
			value = value:gsub('\r', "&#x0D;")
			value = value:gsub('\n', "&#x0A;")
			return value
		end
	end



--
-- Given a map of supported platform identifiers, filters the solution's list
-- of platforms to match. A map takes the form of a table like:
--
--  { x32 = "Win32", x64 = "x64" }
--
-- Only platforms that are listed in both the solution and the map will be
-- included in the results. An optional default platform may also be specified;
-- if the result set would otherwise be empty this platform will be used.
--

	function premake.filterplatforms(sln, map, default)
		local result = { }
		local keys = { }
		if sln.platforms then
			for _, p in ipairs(sln.platforms) do
				if map[p] and not table.contains(keys, map[p]) then
					table.insert(result, p)
					table.insert(keys, map[p])
				end
			end
		end

		if #result == 0 and default then
			table.insert(result, default)
		end

		return result
	end



--
-- Locate a project by name; case insensitive.
--

	function premake.findproject(name)
		for sln in premake.solution.each() do
			for prj in premake.solution.eachproject(sln) do
				if (prj.name == name) then
					return  prj
				end
			end
		end
	end



--
-- Locate a file in a project with a given extension; used to locate "special"
-- items such as Windows .def files.
--

	function premake.findfile(prj, extension)
		for _, fname in ipairs(prj.files) do
			if fname:endswith(extension) then return fname end
		end
	end



--
-- Retrieve a configuration for a given project/configuration pairing.
-- @param prj
--   The project to query.
-- @param cfgname
--   The target build configuration; only settings applicable to this configuration
--   will be returned. May be nil to retrieve project-wide settings.
-- @param pltname
--   The target platform; only settings applicable to this platform will be returned.
--   May be nil to retrieve platform-independent settings.
-- @returns
--   A configuration object containing all the settings for the given platform/build
--   configuration pair.
--

	function premake.getconfig(prj, cfgname, pltname)
		-- might have the root configuration, rather than the actual project
		prj = prj.project or prj

		-- if platform is not included in the solution, use general settings instead
		if pltname == "Native" or not table.contains(prj.solution.platforms or {}, pltname) then
			pltname = nil
		end

		local key = (cfgname or "")
		if pltname then key = key .. pltname end
		return prj.__configs[key]
	end



--
-- Build a name from a build configuration/platform pair. The short name
-- is good for makefiles or anywhere a user will have to type it in. The
-- long name is more readable.
--

	function premake.getconfigname(cfgname, platform, useshortname)
		if cfgname then
			local name = cfgname
			if platform and platform ~= "Native" then
				if useshortname then
					name = name .. premake.platforms[platform].cfgsuffix
				else
					name = name .. "|" .. platform
				end
			end
			return iif(useshortname, name:lower(), name)
		end
	end



--
-- Returns a list of sibling projects on which the specified project depends.
-- This is used to list dependencies within a solution or workspace. Must
-- consider all configurations because Visual Studio does not support per-config
-- project dependencies.
--
-- @param prj
--    The project to query.
-- @returns
--    A list of dependent projects, as an array of objects.
--

	function premake.getdependencies(prj)
		-- make sure I've got the project and not root config
		prj = prj.project or prj

		local results = { }
		for _, cfg in pairs(prj.__configs) do
			for _, link in ipairs(cfg.links) do
				local dep = premake.findproject(link)
				if dep and not table.contains(results, dep) then
					table.insert(results, dep)
				end
			end
		end

		return results
	end



--
-- Uses a pattern to format the basename of a file (i.e. without path).
--
-- @param prjname
--    A project name (string) to use.
-- @param pattern
--    A naming pattern. The sequence "%%" will be replaced by the
--    project name.
-- @returns
--    A filename (basename only) matching the specified pattern, without
--    path components.
--

	function premake.project.getbasename(prjname, pattern)
		return pattern:gsub("%%%%", prjname)
	end



--
-- Uses information from a project (or solution) to format a filename.
--
-- @param prj
--    A project or solution object with the file naming information.
-- @param pattern
--    A naming pattern. The sequence "%%" will be replaced by the
--    project name.
-- @returns
--    A filename matching the specified pattern, with a relative path
--    from the current directory to the project location.
--

	function premake.project.getfilename(prj, pattern)
		local fname = premake.project.getbasename(prj.name, pattern)
		fname = path.join(prj.location, fname)
		return path.getrelative(os.getcwd(), fname)
	end



--
-- Returns a list of link targets. Kind may be one of:
--   siblings     - linkable sibling projects
--   system       - system (non-sibling) libraries
--   dependencies - all sibling dependencies, including non-linkable
--   all          - return everything
--
-- Part may be one of:
--   name      - the decorated library name with no directory
--   basename  - the undecorated library name
--   directory - just the directory, no name
--   fullpath  - full path with decorated name
--   object    - return the project object of the dependency
--

 	function premake.getlinks(cfg, kind, part)
		-- if I'm building a list of link directories, include libdirs
		local result = iif (part == "directory" and kind == "all", cfg.libdirs, {})

		-- am I getting links for a configuration or a project?
		local cfgname = iif(cfg.name == cfg.project.name, "", cfg.name)

		-- how should files be named?
		local pathstyle = premake.getpathstyle(cfg)
		local namestyle = premake.getnamestyle(cfg)

		local function canlink(source, target)
			if (target.kind ~= "SharedLib" and target.kind ~= "StaticLib") then
				return false
			end
			if premake.iscppproject(source) then
				return premake.iscppproject(target)
			elseif premake.isdotnetproject(source) then
				return premake.isdotnetproject(target)
			end
		end

		for _, link in ipairs(cfg.links) do
			local item

			-- is this a sibling project?
			local prj = premake.findproject(link)
			if prj and kind ~= "system" then

				local prjcfg = premake.getconfig(prj, cfgname, cfg.platform)
				if kind == "dependencies" or canlink(cfg, prjcfg) then
					if (part == "directory") then
						item = path.rebase(prjcfg.linktarget.directory, prjcfg.location, cfg.location)
					elseif (part == "basename") then
						item = prjcfg.linktarget.basename
					elseif (part == "fullpath") then
						item = path.rebase(prjcfg.linktarget.fullpath, prjcfg.location, cfg.location)
					elseif (part == "object") then
						item = prjcfg
					end
				end

			elseif not prj and (kind == "system" or kind == "all") then

				if (part == "directory") then
					item = path.getdirectory(link)
				elseif (part == "fullpath") then
					item = link
					if namestyle == "windows" then
						if premake.iscppproject(cfg) then
							item = item .. ".lib"
						elseif premake.isdotnetproject(cfg) then
							item = item .. ".dll"
						end
					end
				elseif part == "name" then
					item = path.getname(link)
				elseif part == "basename" then
					item = path.getbasename(link)
				else
					item = link
				end

				if item:find("/", nil, true) then
					item = path.getrelative(cfg.project.location, item)
				end

			end

			if item then
				if pathstyle == "windows" and part ~= "object" then
					item = path.translate(item, "\\")
				end
				if not table.contains(result, item) then
					table.insert(result, item)
				end
			end
		end

		return result
	end



--
-- Gets the name style for a configuration, indicating what kind of prefix,
-- extensions, etc. should be used in target file names.
--
-- @param cfg
--    The configuration to check.
-- @returns
--    The target naming style, one of "windows", "posix", or "PS3".
--

	function premake.getnamestyle(cfg)
		return premake.platforms[cfg.platform].namestyle or premake.gettool(cfg).namestyle or "posix"
	end



--
-- Gets the path style for a configuration, indicating what kind of path separator
-- should be used in target file names.
--
-- @param cfg
--    The configuration to check.
-- @returns
--    The target path style, one of "windows" or "posix".
--

	function premake.getpathstyle(cfg)
		if premake.action.current().os == "windows" then
			return "windows"
		else
			return "posix"
		end
	end


--
-- Assembles a target for a particular tool/system/configuration.
--
-- @param cfg
--    The configuration to be targeted.
-- @param direction
--    One of 'build' for the build target, or 'link' for the linking target.
-- @param pathstyle
--    The path format, one of "windows" or "posix". This comes from the current
--    action: Visual Studio uses "windows", GMake uses "posix", etc.
-- @param namestyle
--    The file naming style, one of "windows" or "posix". This comes from the
--    current tool: GCC uses "posix", MSC uses "windows", etc.
-- @param system
--    The target operating system, which can modify the naming style. For example,
--    shared libraries on Mac OS X use a ".dylib" extension.
-- @returns
--    An object with these fields:
--      basename   - the target with no directory or file extension
--      name       - the target name and extension, with no directory
--      directory  - relative path to the target, with no file name
--      prefix     - the file name prefix
--      suffix     - the file name suffix
--      fullpath   - directory, name, and extension
--      bundlepath - the relative path and file name of the bundle
--

	function premake.gettarget(cfg, direction, pathstyle, namestyle, system)
		if system == "bsd" or system == "solaris" then
			system = "linux"
		end

		-- Fix things up based on the current system
		local kind = cfg.kind
		if premake.iscppproject(cfg) then
			-- On Windows, shared libraries link against a static import library
			if (namestyle == "windows" or system == "windows")
				and kind == "SharedLib" and direction == "link"
				and not cfg.flags.NoImportLib
			then
				kind = "StaticLib"
			end

			-- Posix name conventions only apply to static libs on windows (by user request)
			if namestyle == "posix" and system == "windows" and kind ~= "StaticLib" then
				namestyle = "windows"
			end
		end

		-- Initialize the target components
		local field   = "build"
		if direction == "link" and cfg.kind == "SharedLib" then
			field = "implib"
		end

		local name    = cfg[field.."name"] or cfg.targetname or cfg.project.name
		local dir     = cfg[field.."dir"] or cfg.targetdir or path.getrelative(cfg.location, cfg.basedir)
		local prefix  = ""
		local suffix  = ""
		local ext     = ""
		local bundlepath, bundlename

		if namestyle == "windows" then
			if kind == "ConsoleApp" or kind == "WindowedApp" then
				ext = ".exe"
			elseif kind == "SharedLib" then
				ext = ".dll"
			elseif kind == "StaticLib" then
				ext = ".lib"
			end
		elseif namestyle == "posix" then
			if kind == "WindowedApp" and system == "macosx" then
				bundlename = name .. ".app"
				bundlepath = path.join(dir, bundlename)
				dir = path.join(bundlepath, "Contents/MacOS")
			elseif kind == "SharedLib" then
				prefix = "lib"
				ext = iif(system == "macosx", ".dylib", ".so")
			elseif kind == "StaticLib" then
				prefix = "lib"
				ext = ".a"
			end
		elseif namestyle == "PS3" then
			if kind == "ConsoleApp" or kind == "WindowedApp" then
				ext = ".elf"
			elseif kind == "StaticLib" then
				prefix = "lib"
				ext = ".a"
			end
		end

		prefix = cfg[field.."prefix"] or cfg.targetprefix or prefix
		suffix = cfg[field.."suffix"] or cfg.targetsuffix or suffix
		ext    = cfg[field.."extension"] or cfg.targetextension or ext

		-- build the results object
		local result = { }
		result.basename   = name .. suffix
		result.name       = prefix .. name .. suffix .. ext
		result.directory  = dir
		result.prefix     = prefix
		result.suffix     = suffix
		result.fullpath   = path.join(result.directory, result.name)
		result.bundlepath = bundlepath or result.fullpath

		if pathstyle == "windows" then
			result.directory = path.translate(result.directory, "\\")
			result.fullpath  = path.translate(result.fullpath,  "\\")
		end

		return result
	end


--
-- Return the appropriate tool interface, based on the target language and
-- any relevant command-line options.
--

	function premake.gettool(cfg)
		if premake.iscppproject(cfg) then
			if _OPTIONS.cc then
				return premake[_OPTIONS.cc]
			end
			local action = premake.action.current()
			if action.valid_tools then
				return premake[action.valid_tools.cc[1]]
			end
			return premake.gcc
		else
			return premake.dotnet
		end
	end



--
-- Given a source file path, return a corresponding virtual path based on
-- the vpath entries in the project. If no matching vpath entry is found,
-- the original path is returned.
--

	function premake.project.getvpath(prj, abspath)
		-- If there is no match, the result is the original filename
		local vpath = abspath

		-- The file's name must be maintained in the resulting path; use these
		-- to make sure I don't cut off too much

		local fname = path.getname(abspath)
		local max = abspath:len() - fname:len()

		-- Look for matching patterns
		for replacement, patterns in pairs(prj.vpaths or {}) do
			for _, pattern in ipairs(patterns) do
				local i = abspath:find(path.wildcards(pattern))
				if i == 1 then

					-- Trim out the part of the name that matched the pattern; what's
					-- left is the part that gets appended to the replacement to make
					-- the virtual path. So a pattern like "src/**.h" matching the
					-- file src/include/hello.h, I want to trim out the src/ part,
					-- leaving include/hello.h.

					-- Find out where the wildcard appears in the match. If there is
					-- no wildcard, the match includes the entire pattern

					i = pattern:find("*", 1, true) or (pattern:len() + 1)

					-- Trim, taking care to keep the actual file name intact.

					local leaf
					if i < max then
						leaf = abspath:sub(i)
					else
						leaf = fname
					end

					if leaf:startswith("/") then
						leaf = leaf:sub(2)
					end

					-- check for (and remove) stars in the replacement pattern.
					-- If there are none, then trim all path info from the leaf
					-- and use just the filename in the replacement (stars should
					-- really only appear at the end; I'm cheating here)

					local stem = ""
					if replacement:len() > 0 then
						stem, stars = replacement:gsub("%*", "")
						if stars == 0 then
							leaf = path.getname(leaf)
						end
					else
						leaf = path.getname(leaf)
					end

					vpath = path.join(stem, leaf)

				end
			end
		end

		-- remove any dot ("./", "../") patterns from the start of the path
		local changed
		repeat
			changed = true
			if vpath:startswith("./") then
				vpath = vpath:sub(3)
			elseif vpath:startswith("../") then
				vpath = vpath:sub(4)
			else
				changed = false
			end
		until not changed

		return vpath
	end


--
-- Returns true if the solution contains at least one C/C++ project.
--

	function premake.hascppproject(sln)
		for prj in premake.solution.eachproject(sln) do
			if premake.iscppproject(prj) then
				return true
			end
		end
	end



--
-- Returns true if the solution contains at least one .NET project.
--

	function premake.hasdotnetproject(sln)
		for prj in premake.solution.eachproject(sln) do
			if premake.isdotnetproject(prj) then
				return true
			end
		end
	end



--
-- Returns true if the project use the C language.
--

	function premake.project.iscproject(prj)
		return prj.language == "C"
	end


--
-- Returns true if the project uses a C/C++ language.
--

	function premake.iscppproject(prj)
		return (prj.language == "C" or prj.language == "C++")
	end



--
-- Returns true if the project uses a .NET language.
--

	function premake.isdotnetproject(prj)
		return (prj.language == "C#")
	end
-- AMALGAMATE FILE TAIL : /src/base/project.lua
-- AMALGAMATE FILE HEAD : /src/base/config.lua
--
-- configs.lua
--
-- Functions for working with configuration objects (which can include
-- projects and solutions).
--
-- Copyright (c) 2008-2011 Jason Perkins and the Premake project
--

	premake.config = { }
	local config = premake.config


-- 
-- Determine if a configuration represents a "debug" or "release" build.
-- This controls the runtime library selected for Visual Studio builds
-- (and might also be useful elsewhere).
--

	function premake.config.isdebugbuild(cfg)
		-- If any of the optimize flags are set, it's a release a build
		if cfg.flags.Optimize or cfg.flags.OptimizeSize or cfg.flags.OptimizeSpeed then
			return false
		end
		-- If symbols are not defined, it's a release build
		if not cfg.flags.Symbols then
			return false
		end
		return true
	end


--
-- Determines if this configuration can be linked incrementally.
-- 
	
	function premake.config.isincrementallink(cfg)
		if cfg.kind == "StaticLib" 
				or config.isoptimizedbuild(cfg.flags)
				or cfg.flags.NoIncrementalLink then
			return false
		end
		return true
	end


--
-- Determine if this configuration uses one of the optimize flags. 
-- Optimized builds get different treatment, such as full linking 
-- instead of incremental.
--
	
	function premake.config.isoptimizedbuild(flags)
		return flags.Optimize or flags.OptimizeSize or flags.OptimizeSpeed
	end

-- AMALGAMATE FILE TAIL : /src/base/config.lua
-- AMALGAMATE FILE HEAD : /src/base/bake.lua
--
-- base/bake.lua
--
-- Takes all the configuration information provided by the project scripts
-- and stored in the solution->project->block hierarchy and flattens it all 
-- down into one object per configuration. These objects are cached with the 
-- project, and can be retrieved by calling the getconfig() or eachconfig().
--
-- Copyright (c) 2008-2011 Jason Perkins and the Premake project
--

	premake.bake = { }
	local bake = premake.bake


-- do not copy these fields into the configurations

	local nocopy = 
	{
		blocks    = true,
		keywords  = true,
		projects  = true,
		__configs = true,
	}

-- do not cascade these fields from projects to configurations

	local nocascade = 
	{
		makesettings = true,
	}
		
-- leave these paths as absolute, rather than converting to project relative

	local keeprelative =
	{
		basedir  = true,
		location = true,
	}



--
-- Returns a list of all of the active terms from the current environment.
-- See the docs for configuration() for more information about the terms.
--

	function premake.getactiveterms()
		local terms = { _action = _ACTION:lower(), os = os.get() }
		
		-- add option keys or values
		for key, value in pairs(_OPTIONS) do
			if value ~= "" then
				table.insert(terms, value:lower())
			else
				table.insert(terms, key:lower())
			end
		end
		
		return terms
	end
	
	
--
-- Test a single configuration block keyword against a list of terms.
-- The terms are a mix of key/value pairs. The keyword is tested against
-- the values; on a match, the corresponding key is returned. This 
-- enables testing for required values in iskeywordsmatch(), below.
--

	function premake.iskeywordmatch(keyword, terms)
		-- is it negated?
		if keyword:startswith("not ") then
			return not premake.iskeywordmatch(keyword:sub(5), terms)
		end
		
		for _, pattern in ipairs(keyword:explode(" or ")) do
			for termkey, term in pairs(terms) do
				if term:match(pattern) == term then
					return termkey
				end
			end
		end
	end
	
	
		
--
-- Checks a set of configuration block keywords against a list of terms.
-- The required flag is used by the file configurations: only blocks
-- with a term that explictly matches the filename get applied; more
-- general blocks are skipped over (since they were already applied at
-- the config level).
--

	function premake.iskeywordsmatch(keywords, terms)
		local hasrequired = false
		for _, keyword in ipairs(keywords) do
			local matched = premake.iskeywordmatch(keyword, terms)
			if not matched then
				return false
			end
			if matched == "required" then
				hasrequired = true
			end
		end
		
		if terms.required and not hasrequired then
			return false
		else
			return true
		end
	end


--
-- Converts path fields from absolute to location-relative paths.
--
-- @param location
--    The base location, paths will be relative to this directory.
-- @param obj
--    The object containing the fields to be adjusted.
--

	local function adjustpaths(location, obj)
		function adjustpathlist(list)
			for i, p in ipairs(list) do
				list[i] = path.getrelative(location, p) 
			end
		end
		
		for name, value in pairs(obj) do
			local field = premake.fields[name]
			if field and value and not keeprelative[name] then
				if field.kind == "path" then
					obj[name] = path.getrelative(location, value) 
				elseif field.kind == "dirlist" or field.kind == "filelist" then
					adjustpathlist(value)
				elseif field.kind == "keypath" then
					for k,v in pairs(value) do
						adjustpathlist(v)
					end
				end
			end
		end
	end
	
	

--
-- Merge all of the fields from one object into another. String values are overwritten,
-- while list values are merged. Fields listed in premake.nocopy are skipped.
--
-- @param dest
--    The destination object, to contain the merged settings.
-- @param src
--    The source object, containing the settings to added to the destination.
--

	local function mergefield(kind, dest, src)
		local tbl = dest or { }
		if kind == "keyvalue" or kind == "keypath" then
			for key, value in pairs(src) do
				tbl[key] = mergefield("list", tbl[key], value)
			end
		else
			for _, item in ipairs(src) do
				if not tbl[item] then
					table.insert(tbl, item)
					tbl[item] = item
				end
			end
		end
		return tbl
	end
	
	local function mergeobject(dest, src)
		-- if there's nothing to add, quick out
		if not src then 
			return 
		end
		
		for fieldname, value in pairs(src) do
			if not nocopy[fieldname] then
				-- fields that are included in the API are merged...
				local field = premake.fields[fieldname]
				if field then
					if type(value) == "table" then
						dest[fieldname] = mergefield(field.kind, dest[fieldname], value)
					else
						dest[fieldname] = value
					end
				
				-- ...everything else is just copied as-is
				else
					dest[fieldname] = value
				end
			end
		end
	end
	
	

--
-- Merges the settings from a solution's or project's list of configuration blocks,
-- for all blocks that match the provided set of environment terms.
--
-- @param dest
--    The destination object, to contain the merged settings.
-- @param obj
--    The solution or project object being collapsed.
-- @param basis
--    "Root" level settings, from the solution, which act as a starting point for
--    all of the collapsed settings built during this call.
-- @param terms
--    A list of keywords to filter the configuration blocks; only those that
--    match will be included in the destination.
-- @param cfgname
--    The name of the configuration being collapsed. May be nil.
-- @param pltname
--    The name of the platform being collapsed. May be nil.
--

	local function merge(dest, obj, basis, terms, cfgname, pltname)
		-- the configuration key is the merged configuration and platform names
		local key = cfgname or ""
		pltname = pltname or "Native"
		if pltname ~= "Native" then
			key = key .. pltname
		end
		
		-- add the configuration and platform to the block filter terms
		terms.config = (cfgname or ""):lower()
		terms.platform = pltname:lower()
		
		-- build the configuration base by merging the solution and project level settings
		local cfg = {}
		mergeobject(cfg, basis[key])
		adjustpaths(obj.location, cfg)
		mergeobject(cfg, obj)
		
		-- add `kind` to the filter terms
		if (cfg.kind) then 
			terms['kind']=cfg.kind:lower()
		end
		
		-- now add in any blocks that match the filter terms
		for _, blk in ipairs(obj.blocks) do
			if (premake.iskeywordsmatch(blk.keywords, terms))then
				mergeobject(cfg, blk)
				if (cfg.kind and not cfg.terms.kind) then 
					cfg.terms['kind'] = cfg.kind:lower()
					terms['kind'] = cfg.kind:lower()
				end
			end
		end
		
		-- package it all up and add it to the result set
		cfg.name      = cfgname
		cfg.platform  = pltname
		for k,v in pairs(terms) do
			cfg.terms[k] =v
		end
		dest[key] = cfg
	end
	
	
		
--
-- Collapse a solution or project object down to a canonical set of configuration settings,
-- keyed by configuration block/platform pairs, and taking into account the current
-- environment settings.
--
-- @param obj
--    The solution or project to be collapsed.
-- @param basis
--    "Root" level settings, from the solution, which act as a starting point for
--    all of the collapsed settings built during this call.
-- @returns
--    The collapsed list of settings, keyed by configuration block/platform pair.
--

	local function collapse(obj, basis)
		local result = {}
		basis = basis or {}
		
		-- find the solution, which contains the configuration and platform lists
		local sln = obj.solution or obj

		-- build a set of configuration filter terms; only those configuration blocks 
		-- with a matching set of keywords will be included in the merged results
		local terms = premake.getactiveterms()

		-- build a project-level configuration. 
		merge(result, obj, basis, terms)--this adjusts terms

		-- now build configurations for each build config/platform pair
		for _, cfgname in ipairs(sln.configurations) do
			local terms_local = {}
			for k,v in pairs(terms)do terms_local[k]=v end
			merge(result, obj, basis, terms_local, cfgname, "Native")--terms cam also be adjusted here
			for _, pltname in ipairs(sln.platforms or {}) do
				if pltname ~= "Native" then
					merge(result, obj, basis,terms_local, cfgname, pltname)--terms also here
				end
			end
		end
		
		return result
	end



--
-- Computes a unique objects directory for every configuration, using the
-- following choices:
--   [1] -> the objects directory as set in the project of config
--   [2] -> [1] + the platform name
--   [3] -> [2] + the configuration name
--   [4] -> [3] + the project name
--

	local function builduniquedirs()
		local num_variations = 4
		
		-- Start by listing out each possible object directory for each configuration.
		-- Keep a count of how many times each path gets used across the session.
		local cfg_dirs = {}
		local hit_counts = {}
		
		for sln in premake.solution.each() do
			for _, prj in ipairs(sln.projects) do
				for _, cfg in pairs(prj.__configs) do

					local dirs = { }
					dirs[1] = path.getabsolute(path.join(cfg.location, cfg.objdir or cfg.project.objdir or "obj"))
					dirs[2] = path.join(dirs[1], iif(cfg.platform == "Native", "", cfg.platform))
					dirs[3] = path.join(dirs[2], cfg.name)
					dirs[4] = path.join(dirs[3], cfg.project.name)
					cfg_dirs[cfg] = dirs
					
					-- configurations other than the root should bias toward a more
					-- description path, including the platform or config name
					local start = iif(cfg.name, 2, 1)
					for v = start, num_variations do
						local d = dirs[v]
						hit_counts[d] = (hit_counts[d] or 0) + 1
					end

				end
			end
		end
		
		-- Now assign an object directory to each configuration, skipping those
		-- that are in use somewhere else in the session
		for sln in premake.solution.each() do
			for _, prj in ipairs(sln.projects) do
				for _, cfg in pairs(prj.__configs) do

					local dir
					local start = iif(cfg.name, 2, 1)
					for v = start, num_variations do
						dir = cfg_dirs[cfg][v]
						if hit_counts[dir] == 1 then break end
					end
					cfg.objectsdir = path.getrelative(cfg.location, dir)
				end
			end
		end		
		
	end
	


--
-- Pre-computes the build and link targets for a configuration.
--

	local function buildtargets()
		for sln in premake.solution.each() do
			for _, prj in ipairs(sln.projects) do
				for _, cfg in pairs(prj.__configs) do
					-- determine which conventions the target should follow for this config
					local pathstyle = premake.getpathstyle(cfg)
					local namestyle = premake.getnamestyle(cfg)

					-- build the targets
					cfg.buildtarget = premake.gettarget(cfg, "build", pathstyle, namestyle, cfg.system)
					cfg.linktarget  = premake.gettarget(cfg, "link",  pathstyle, namestyle, cfg.system)
					if pathstyle == "windows" then
						cfg.objectsdir = path.translate(cfg.objectsdir, "\\")
					end

				end
			end
		end		
	end
		
  	local function getCfgKind(cfg)
  		if(cfg.kind) then
  			return cfg.kind;
  		end
  		
  		if(cfg.project.__configs[""] and cfg.project.__configs[""].kind) then
  			return cfg.project.__configs[""].kind;
  		end
  		
  		return nil
  	end
  
  	local function getprojrec(dstArray, foundList, cfg, cfgname, searchField, bLinkage)
  		if(not cfg) then return end
  		
  		local foundUsePrjs = {};
  		for _, useName in ipairs(cfg[searchField]) do
  			local testName = useName:lower();
  			if((not foundList[testName])) then
  				local theProj = nil;
  				local theUseProj = nil;
  				for _, prj in ipairs(cfg.project.solution.projects) do
  					if (prj.name:lower() == testName) then
  						if(prj.usage) then
  							theUseProj = prj;
  						else
  							theProj = prj;
  						end
  					end
  				end
  
  				--Must connect to a usage project.
  				if(theUseProj) then
  					foundList[testName] = true;
  					local prjEntry = {
  						name = testName,
  						proj = theProj,
  						usageProj = theUseProj,
  						bLinkageOnly = bLinkage,
  					};
  					dstArray[testName] = prjEntry;
  					table.insert(foundUsePrjs, theUseProj);
  				end
  			end
  		end
  		
  		for _, usePrj in ipairs(foundUsePrjs) do
  			--Links can only recurse through static libraries.
  			if((searchField ~= "links") or
  				(getCfgKind(usePrj.__configs[cfgname]) == "StaticLib")) then
  				getprojrec(dstArray, foundList, usePrj.__configs[cfgname],
  					cfgname, searchField, bLinkage);
  			end
  		end
  	end
  
  --
  -- This function will recursively get all projects that the given configuration has in its "uses"
  -- field. The return values are a list of tables. Each table in that list contains the following:
  --		name = The lowercase name of the project.
  --		proj = The project. Can be nil if it is usage-only.
  --		usageProj = The usage project. Can't be nil, as using a project that has no
  -- 			usage project is not put into the list.
  --		bLinkageOnly = If this is true, then only the linkage information should be copied.
  -- The recursion will only look at the "uses" field on *usage* projects.
  -- This function will also add projects to the list that are mentioned in the "links"
  -- field of usage projects. These will only copy linker information, but they will recurse.
  -- through other "links" fields.
  --
  	local function getprojectsconnections(cfg, cfgname)
  		local dstArray = {};
  		local foundList = {};
  		foundList[cfg.project.name:lower()] = true;
  
  		--First, follow the uses recursively.
  		getprojrec(dstArray, foundList, cfg, cfgname, "uses", false);
  		
  		--Next, go through all of the usage projects and recursively get their links.
  		--But only if they're not already there. Get the links as linkage-only.
  		local linkArray = {};
  		for prjName, prjEntry in pairs(dstArray) do
  			getprojrec(linkArray, foundList, prjEntry.usageProj.__configs[cfgname], cfgname, 
  				"links", true);
  		end
  		
  		--Copy from linkArray into dstArray.
  		for prjName, prjEntry in pairs(linkArray) do
  			dstArray[prjName] = prjEntry;
  		end
  		
  		return dstArray;
  	end
  	
  	
  	local function isnameofproj(cfg, strName)
  		local sln = cfg.project.solution;
  		local strTest = strName:lower();
  		for prjIx, prj in ipairs(sln.projects) do
  			if (prj.name:lower() == strTest) then
  				return true;
  			end
  		end
  		
  		return false;
  	end
	
	
  --
  -- Copies the field from dstCfg to srcCfg.
  --
  	local function copydependentfield(srcCfg, dstCfg, strSrcField)
  		local srcField = premake.fields[strSrcField];
  		local strDstField = strSrcField;
  		
  		if type(srcCfg[strSrcField]) == "table" then
  			--handle paths.
  			if (srcField.kind == "dirlist" or srcField.kind == "filelist") and
  				(not keeprelative[strSrcField]) then
  				for i,p in ipairs(srcCfg[strSrcField]) do
  					table.insert(dstCfg[strDstField],
  						path.rebase(p, srcCfg.project.location, dstCfg.project.location))
  				end
  			else
  				if(strSrcField == "links") then
  					for i,p in ipairs(srcCfg[strSrcField]) do
  						if(not isnameofproj(dstCfg, p)) then
  							table.insert(dstCfg[strDstField], p)
  						else
  							printf("Failed to copy '%s' from proj '%s'.",
  								p, srcCfg.project.name);
  						end
  					end
  				else
  					for i,p in ipairs(srcCfg[strSrcField]) do
  						table.insert(dstCfg[strDstField], p)
  					end
  				end
  			end
  		else
  			if(srcField.kind == "path" and (not keeprelative[strSrcField])) then
  				dstCfg[strDstField] = path.rebase(srcCfg[strSrcField],
  					prj.location, dstCfg.project.location);
  			else
  				dstCfg[strDstField] = srcCfg[strSrcField];
  			end
  		end
  	end
  	
	
  --
  -- This function will take the list of project entries and apply their usage project data
  -- to the given configuration. It will copy compiling information for the projects that are
  -- not listed as linkage-only. It will copy the linking information for projects only if
  -- the source project is not a static library. It won't copy linking information
  -- if the project is in this solution; instead it will add that project to the configuration's
  -- links field, expecting that Premake will handle the rest.
  --	
  	local function copyusagedata(cfg, cfgname, linkToProjs)
  		local myPrj = cfg.project;
  		local bIsStaticLib = (getCfgKind(cfg) == "StaticLib");
  		
  		for prjName, prjEntry in pairs(linkToProjs) do
  			local srcPrj = prjEntry.usageProj;
  			local srcCfg = srcPrj.__configs[cfgname];
  
  			for name, field in pairs(premake.fields) do
  				if(srcCfg[name]) then
  					if(field.usagecopy) then
  						if(not prjEntry.bLinkageOnly) then
  							copydependentfield(srcCfg, cfg, name)
  						end
  					elseif(field.linkagecopy) then
  						--Copy the linkage data if we're building a non-static thing
  						--and this is a pure usage project. If it's not pure-usage, then
  						--we will simply put the project's name in the links field later.
  						if((not bIsStaticLib) and (not prjEntry.proj)) then
  							copydependentfield(srcCfg, cfg, name)
  						end
  					end
  				end
  			end
  
  			if((not bIsStaticLib) and prjEntry.proj) then
  				table.insert(cfg.links, prjEntry.proj.name);
  			end
  		end
  	end


--
-- Main function, controls the process of flattening the configurations.
--
		
	function premake.bake.buildconfigs()
	
		-- convert project path fields to be relative to project location
		for sln in premake.solution.each() do
			for _, prj in ipairs(sln.projects) do
				prj.location = prj.location or sln.location or prj.basedir
				adjustpaths(prj.location, prj)
				for _, blk in ipairs(prj.blocks) do
					adjustpaths(prj.location, blk)
				end
			end
			sln.location = sln.location or sln.basedir
		end
		
		-- collapse configuration blocks, so that there is only one block per build
		-- configuration/platform pair, filtered to the current operating environment		
		for sln in premake.solution.each() do
			local basis = collapse(sln)
			for _, prj in ipairs(sln.projects) do
				prj.__configs = collapse(prj, basis)
				for _, cfg in pairs(prj.__configs) do
					bake.postprocess(prj, cfg)
				end
			end
		end	
		
		-- This loop finds the projects that a configuration is connected to
		-- via its "uses" field. It will then copy any usage project information from that
		-- usage project to the configuration in question.
		for sln in premake.solution.each() do
			for prjIx, prj in ipairs(sln.projects) do
				if(not prj.usage) then
					for cfgname, cfg in pairs(prj.__configs) do
						local usesPrjs = getprojectsconnections(cfg, cfgname);
						copyusagedata(cfg, cfgname, usesPrjs)
					end
				end
			end
		end		

		-- Remove all usage projects.
		for sln in premake.solution.each() do
			local removeList = {};
			for index, prj in ipairs(sln.projects) do
				if(prj.usage) then
					table.insert(removeList, 1, index); --Add in reverse order.
				end
			end
			
			for _, index in ipairs(removeList) do
				table.remove(sln.projects, index);
			end
		end
		
		-- assign unique object directories to each configuration
		builduniquedirs()
		
		-- walk it again and build the targets and unique directories
		buildtargets(cfg)

	end
	

--
-- Post-process a project configuration, applying path fix-ups and other adjustments
-- to the "raw" setting data pulled from the project script.
--
-- @param prj
--    The project object which contains the configuration.
-- @param cfg
--    The configuration object to be fixed up.
--

	function premake.bake.postprocess(prj, cfg)
		cfg.project   = prj
		cfg.shortname = premake.getconfigname(cfg.name, cfg.platform, true)
		cfg.longname  = premake.getconfigname(cfg.name, cfg.platform)
		
		-- set the project location, if not already set
		cfg.location = cfg.location or cfg.basedir
		
		-- figure out the target system
		local platform = premake.platforms[cfg.platform]
		if platform.iscrosscompiler then
			cfg.system = cfg.platform
		else
			cfg.system = os.get()
		end
		
		-- adjust the kind as required by the target system
		if cfg.kind == "SharedLib" and platform.nosharedlibs then
			cfg.kind = "StaticLib"
		end
		
		-- remove excluded files from the file list
		local files = { }
		for _, fname in ipairs(cfg.files) do
			local excluded = false
			for _, exclude in ipairs(cfg.excludes) do
				excluded = (fname == exclude)
				if (excluded) then break end
			end
						
			if (not excluded) then
				table.insert(files, fname)
			end
		end
		cfg.files = files

		-- fixup the data		
		for name, field in pairs(premake.fields) do
			-- re-key flag fields for faster lookups
			if field.isflags then
				local values = cfg[name]
				for _, flag in ipairs(values) do values[flag] = true end
			end
		end

		-- build configuration objects for all files
		-- TODO: can I build this as a tree instead, and avoid the extra
		-- step of building it later?
		cfg.__fileconfigs = { }
		for _, fname in ipairs(cfg.files) do
			cfg.terms.required = fname:lower()
			local fcfg = {}
			for _, blk in ipairs(cfg.project.blocks) do
				if (premake.iskeywordsmatch(blk.keywords, cfg.terms)) then
					mergeobject(fcfg, blk)
				end
			end

			-- add indexed by name and integer
			-- TODO: when everything is converted to trees I won't need
			-- to index by name any longer
			fcfg.name = fname
			cfg.__fileconfigs[fname] = fcfg
			table.insert(cfg.__fileconfigs, fcfg)
		end
	end
-- AMALGAMATE FILE TAIL : /src/base/bake.lua
-- AMALGAMATE FILE HEAD : /src/base/api.lua
--
-- api.lua
-- Implementation of the solution, project, and configuration APIs.
-- Copyright (c) 2002-2011 Jason Perkins and the Premake project
--


--
-- Here I define all of the getter/setter functions as metadata. The actual
-- functions are built programmatically below.
--

	premake.fields =
	{
		basedir =
		{
			kind  = "path",
			scope = "container",
		},

		buildaction =
		{
			kind  = "string",
			scope = "config",
			allowed = {
				"Compile",
				"Copy",
				"Embed",
				"None"
			}
		},

		buildoptions =
		{
			kind  = "list",
			scope = "config",
		},

		configurations =
		{
			kind  = "list",
			scope = "solution",
		},

		debugargs =
		{
			kind = "list",
			scope = "config",
		},

		debugdir =
		{
			kind = "path",
			scope = "config",
		},

		debugenvs  =
		{
			kind = "list",
			scope = "config",
		},

		defines =
		{
			kind  = "list",
			scope = "config",
		},

		deploymentoptions =
		{
			kind  = "list",
			scope = "config",
			usagecopy = true,
		},

		excludes =
		{
			kind  = "filelist",
			scope = "config",
		},

		files =
		{
			kind  = "filelist",
			scope = "config",
		},

		flags =
		{
			kind  = "list",
			scope = "config",
			isflags = true,
			usagecopy = true,
			allowed = function(value)

				local allowed_flags = {
					ATL = 1,
					DebugEnvsDontMerge = 1,
					DebugEnvsInherit = 1,
					EnableSSE = 1,
					EnableSSE2 = 1,
					ExtraWarnings = 1,
					FatalWarnings = 1,
					FloatFast = 1,
					FloatStrict = 1,
					Managed = 1,
					MFC = 1,
					NativeWChar = 1,
					No64BitChecks = 1,
					NoEditAndContinue = 1,
					NoExceptions = 1,
					NoFramePointer = 1,
					NoImportLib = 1,
					NoIncrementalLink = 1,
					NoManifest = 1,
					NoMinimalRebuild = 1,
					NoNativeWChar = 1,
					NoPCH = 1,
					NoRTTI = 1,
					Optimize = 1,
					OptimizeSize = 1,
					OptimizeSpeed = 1,
					SEH = 1,
					StaticATL = 1,
					StaticRuntime = 1,
					Symbols = 1,
					Unicode = 1,
					Unsafe = 1,
					WinMain = 1
				}

				local englishToAmericanSpelling =
				{
					optimise = 'optimize',
					optimisesize = 'optimizesize',
					optimisespeed = 'optimizespeed',
				}

				local lowervalue = value:lower()
				lowervalue = englishToAmericanSpelling[lowervalue] or lowervalue
				for v, _ in pairs(allowed_flags) do
					if v:lower() == lowervalue then
						return v
					end
				end
				return nil, "invalid flag"
			end,
		},

		framework =
		{
			kind = "string",
			scope = "container",
			allowed = {
				"1.0",
				"1.1",
				"2.0",
				"3.0",
				"3.5",
				"4.0",
				"4.5",
			}
		},

		imagepath =
		{
			kind = "path",
			scope = "config",
		},

		imageoptions =
		{
			kind  = "list",
			scope = "config",
		},

		implibdir =
		{
			kind  = "path",
			scope = "config",
		},

		implibextension =
		{
			kind  = "string",
			scope = "config",
		},

		implibname =
		{
			kind  = "string",
			scope = "config",
		},

		implibprefix =
		{
			kind  = "string",
			scope = "config",
		},

		implibsuffix =
		{
			kind  = "string",
			scope = "config",
		},

		includedirs =
		{
			kind  = "dirlist",
			scope = "config",
			usagecopy = true,
		},

		kind =
		{
			kind  = "string",
			scope = "config",
			allowed = {
				"ConsoleApp",
				"WindowedApp",
				"StaticLib",
				"SharedLib"
			}
		},

		language =
		{
			kind  = "string",
			scope = "container",
			allowed = {
				"C",
				"C++",
				"C#"
			}
		},

		libdirs =
		{
			kind  = "dirlist",
			scope = "config",
			linkagecopy = true,
		},

		frameworkdirs =
		{
			kind = "dirlist",
			scope = "config",
		},

		linkoptions =
		{
			kind  = "list",
			scope = "config",
		},

		links =
		{
			kind  = "list",
			scope = "config",
			allowed = function(value)
				-- if library name contains a '/' then treat it as a path to a local file
				if value:find('/', nil, true) then
					value = path.getabsolute(value)
				end
				return value
			end,
			linkagecopy = true,
		},

		location =
		{
			kind  = "path",
			scope = "container",
		},

		makesettings =
		{
			kind = "list",
			scope = "config",
		},

		objdir =
		{
			kind  = "path",
			scope = "config",
		},

		pchheader =
		{
			kind  = "string",
			scope = "config",
		},

		pchsource =
		{
			kind  = "path",
			scope = "config",
		},

		platforms =
		{
			kind  = "list",
			scope = "solution",
			allowed = table.keys(premake.platforms),
		},

		postbuildcommands =
		{
			kind  = "list",
			scope = "config",
		},

		prebuildcommands =
		{
			kind  = "list",
			scope = "config",
		},

		prelinkcommands =
		{
			kind  = "list",
			scope = "config",
		},

		resdefines =
		{
			kind  = "list",
			scope = "config",
		},

		resincludedirs =
		{
			kind  = "dirlist",
			scope = "config",
		},

		resoptions =
		{
			kind  = "list",
			scope = "config",
		},

		targetdir =
		{
			kind  = "path",
			scope = "config",
		},

		targetextension =
		{
			kind  = "string",
			scope = "config",
		},

		targetname =
		{
			kind  = "string",
			scope = "config",
		},

		targetprefix =
		{
			kind  = "string",
			scope = "config",
		},

		targetsuffix =
		{
			kind  = "string",
			scope = "config",
		},

		trimpaths =
		{
			kind = "dirlist",
			scope = "config",
		},

		uuid =
		{
			kind  = "string",
			scope = "container",
			allowed = function(value)
				local ok = true
				if (#value ~= 36) then ok = false end
				for i=1,36 do
					local ch = value:sub(i,i)
					if (not ch:find("[ABCDEFabcdef0123456789-]")) then ok = false end
				end
				if (value:sub(9,9) ~= "-")   then ok = false end
				if (value:sub(14,14) ~= "-") then ok = false end
				if (value:sub(19,19) ~= "-") then ok = false end
				if (value:sub(24,24) ~= "-") then ok = false end
				if (not ok) then
					return nil, "invalid UUID"
				end
				return value:upper()
			end
		},

		uses =
		{
			kind  = "list",
			scope = "config",
		},

		vpaths =
		{
			kind = "keypath",
			scope = "container",
		},

	}


--
-- End of metadata
--



--
-- Check to see if a value exists in a list of values, using a
-- case-insensitive match. If the value does exist, the canonical
-- version contained in the list is returned, so future tests can
-- use case-sensitive comparisions.
--

	function premake.checkvalue(value, allowed)
		if (allowed) then
			if (type(allowed) == "function") then
				return allowed(value)
			else
				for _,v in ipairs(allowed) do
					if (value:lower() == v:lower()) then
						return v
					end
				end
				return nil, "invalid value '" .. value .. "'"
			end
		else
			return value
		end
	end



--
-- Retrieve the current object of a particular type from the session. The
-- type may be "solution", "container" (the last activated solution or
-- project), or "config" (the last activated configuration). Returns the
-- requested container, or nil and an error message.
--

	function premake.getobject(t)
		local container

		if (t == "container" or t == "solution") then
			container = premake.CurrentContainer
		else
			container = premake.CurrentConfiguration
		end

		if t == "solution" then
			if type(container) == "project" then
				container = container.solution
			end
			if type(container) ~= "solution" then
				container = nil
			end
		end

		local msg
		if (not container) then
			if (t == "container") then
				msg = "no active solution or project"
			elseif (t == "solution") then
				msg = "no active solution"
			else
				msg = "no active solution, project, or configuration"
			end
		end

		return container, msg
	end



--
-- Adds values to an array field of a solution/project/configuration. `ctype`
-- specifies the container type (see premake.getobject) for the field.
--

	function premake.setarray(ctype, fieldname, value, allowed)
		local container, err = premake.getobject(ctype)
		if (not container) then
			error(err, 4)
		end

		if (not container[fieldname]) then
			container[fieldname] = { }
		end

		local function doinsert(value, depth)
			if (type(value) == "table") then
				for _,v in ipairs(value) do
					doinsert(v, depth + 1)
				end
			else
				value, err = premake.checkvalue(value, allowed)
				if (not value) then
					error(err, depth)
				end
				table.insert(container[fieldname], value)
			end
		end

		if (value) then
			doinsert(value, 5)
		end

		return container[fieldname]
	end



--
-- Adds values to an array-of-directories field of a solution/project/configuration.
-- `ctype` specifies the container type (see premake.getobject) for the field. All
-- values are converted to absolute paths before being stored.
--

	local function domatchedarray(ctype, fieldname, value, matchfunc)
		local result = { }

		function makeabsolute(value, depth)
			if (type(value) == "table") then
				for _, item in ipairs(value) do
					makeabsolute(item, depth + 1)
				end
			elseif type(value) == "string" then
				if value:find("*") then
					makeabsolute(matchfunc(value), depth + 1)
				else
					table.insert(result, path.getabsolute(value))
				end
			else
				error("Invalid value in list: expected string, got " .. type(value), depth)
			end
		end

		makeabsolute(value, 3)
		return premake.setarray(ctype, fieldname, result)
	end

	function premake.setdirarray(ctype, fieldname, value)
		return domatchedarray(ctype, fieldname, value, os.matchdirs)
	end

	function premake.setfilearray(ctype, fieldname, value)
		return domatchedarray(ctype, fieldname, value, os.matchfiles)
	end


--
-- Adds values to a key-value field of a solution/project/configuration. `ctype`
-- specifies the container type (see premake.getobject) for the field.
--

	function premake.setkeyvalue(ctype, fieldname, values)
		local container, err = premake.getobject(ctype)
		if not container then
			error(err, 4)
		end

		if not container[fieldname] then
			container[fieldname] = {}
		end

		if type(values) ~= "table" then
			error("invalid value; table expected", 4)
		end

		local field = container[fieldname]

		for key,value in pairs(values) do
			if not field[key] then
				field[key] = {}
			end
			table.insertflat(field[key], value)
		end

		return field
	end


--
-- Set a new value for a string field of a solution/project/configuration. `ctype`
-- specifies the container type (see premake.getobject) for the field.
--

	function premake.setstring(ctype, fieldname, value, allowed)
		-- find the container for this value
		local container, err = premake.getobject(ctype)
		if (not container) then
			error(err, 4)
		end

		-- if a value was provided, set it
		if (value) then
			value, err = premake.checkvalue(value, allowed)
			if (not value) then
				error(err, 4)
			end

			container[fieldname] = value
		end

		return container[fieldname]
	end



--
-- The getter/setter implemention.
--

	local function accessor(name, value)
		local kind    = premake.fields[name].kind
		local scope   = premake.fields[name].scope
		local allowed = premake.fields[name].allowed

		if (kind == "string" or kind == "path") and value then
			if type(value) ~= "string" then
				error("string value expected", 3)
			end
		end

		if kind == "string" then
			return premake.setstring(scope, name, value, allowed)
		elseif kind == "path" then
			if value then value = path.getabsolute(value) end
			return premake.setstring(scope, name, value)
		elseif kind == "list" then
			return premake.setarray(scope, name, value, allowed)
		elseif kind == "dirlist" then
			return premake.setdirarray(scope, name, value)
		elseif kind == "filelist" then
			return premake.setfilearray(scope, name, value)
		elseif kind == "keyvalue" or kind == "keypath" then
			return premake.setkeyvalue(scope, name, value)
		end
	end



--
-- Build all of the getter/setter functions from the metadata above.
--

	for name,_ in pairs(premake.fields) do
		_G[name] = function(value)
			return accessor(name, value)
		end
	end



--
-- Project object constructors.
--

	function configuration(terms)
		if not terms then
			return premake.CurrentConfiguration
		end

		local container, err = premake.getobject("container")
		if (not container) then
			error(err, 2)
		end

		local cfg = { }
		cfg.terms = table.flatten({terms})

		table.insert(container.blocks, cfg)
		premake.CurrentConfiguration = cfg

		-- create a keyword list using just the indexed keyword items. This is a little
		-- confusing: "terms" are what the user specifies in the script, "keywords" are
		-- the Lua patterns that result. I'll refactor to better names.
		cfg.keywords = { }
		for _, word in ipairs(cfg.terms) do
			table.insert(cfg.keywords, path.wildcards(word):lower())
		end

		-- initialize list-type fields to empty tables
		for name, field in pairs(premake.fields) do
			if (field.kind ~= "string" and field.kind ~= "path") then
				cfg[name] = { }
			end
		end

		return cfg
	end

	local function createproject(name, sln, isUsage)
		local prj = {}

		-- attach a type
		setmetatable(prj, {
			__type = "project",
		})

		-- add to master list keyed by both name and index
		table.insert(sln.projects, prj)
		if(isUsage) then
			--If we're creating a new usage project, and there's already a project
			--with our name, then set us as the usage project for that project.
			--Otherwise, set us as the project in that slot.
			if(sln.projects[name]) then
				sln.projects[name].usageProj = prj;
			else
				sln.projects[name] = prj
			end
		else
			--If we're creating a regular project, and there's already a project
			--with our name, then it must be a usage project. Set it as our usage project
			--and set us as the project in that slot.
			if(sln.projects[name]) then
				prj.usageProj = sln.projects[name];
			end

			sln.projects[name] = prj
		end

		prj.solution       = sln
		prj.name           = name
		prj.basedir        = os.getcwd()
		prj.uuid           = os.uuid()
		prj.blocks         = { }
		prj.usage		   = isUsage;

		return prj;
	end

	function usage(name)
		if (not name) then
			--Only return usage projects.
			if(type(premake.CurrentContainer) ~= "project") then return nil end
			if(not premake.CurrentContainer.usage) then return nil end
			return premake.CurrentContainer
		end

		-- identify the parent solution
		local sln
		if (type(premake.CurrentContainer) == "project") then
			sln = premake.CurrentContainer.solution
		else
			sln = premake.CurrentContainer
		end
		if (type(sln) ~= "solution") then
			error("no active solution", 2)
		end

  		-- if this is a new project, or the project in that slot doesn't have a usage, create it
  		if((not sln.projects[name]) or
  			((not sln.projects[name].usage) and (not sln.projects[name].usageProj))) then
  			premake.CurrentContainer = createproject(name, sln, true)
  		else
  			premake.CurrentContainer = iff(sln.projects[name].usage,
  				sln.projects[name], sln.projects[name].usageProj)
  		end

  		-- add an empty, global configuration to the project
  		configuration { }

  		return premake.CurrentContainer
  	end

  	function project(name)
  		if (not name) then
  			--Only return non-usage projects
  			if(type(premake.CurrentContainer) ~= "project") then return nil end
  			if(premake.CurrentContainer.usage) then return nil end
  			return premake.CurrentContainer
		end

  		-- identify the parent solution
  		local sln
  		if (type(premake.CurrentContainer) == "project") then
  			sln = premake.CurrentContainer.solution
  		else
  			sln = premake.CurrentContainer
  		end
  		if (type(sln) ~= "solution") then
  			error("no active solution", 2)
  		end

  		-- if this is a new project, or the old project is a usage project, create it
  		if((not sln.projects[name]) or sln.projects[name].usage) then
  			premake.CurrentContainer = createproject(name, sln)
  		else
  			premake.CurrentContainer = sln.projects[name];
  		end

		-- add an empty, global configuration to the project
		configuration { }

		return premake.CurrentContainer
	end


	function solution(name)
		if not name then
			if type(premake.CurrentContainer) == "project" then
				return premake.CurrentContainer.solution
			else
				return premake.CurrentContainer
			end
		end

		premake.CurrentContainer = premake.solution.get(name)
		if (not premake.CurrentContainer) then
			premake.CurrentContainer = premake.solution.new(name)
		end

		-- add an empty, global configuration
		configuration { }

		return premake.CurrentContainer
	end


--
-- Define a new action.
--
-- @param a
--    The new action object.
--

	function newaction(a)
		premake.action.add(a)
	end


--
-- Define a new option.
--
-- @param opt
--    The new option object.
--

	function newoption(opt)
		premake.option.add(opt)
	end
-- AMALGAMATE FILE TAIL : /src/base/api.lua
-- AMALGAMATE FILE HEAD : /src/base/cmdline.lua
--
-- cmdline.lua
-- Functions to define and handle command line actions and options.
-- Copyright (c) 2002-2011 Jason Perkins and the Premake project
--


--
-- Built-in command line options
--

	newoption 
	{
		trigger     = "cc",
		value       = "VALUE",
		description = "Choose a C/C++ compiler set",
		allowed = {
			{ "gcc", "GNU GCC (gcc/g++)" },
			{ "ow",  "OpenWatcom"        },
		}
	}

	newoption
	{
		trigger     = "dotnet",
		value       = "VALUE",
		description = "Choose a .NET compiler set",
		allowed = {
			{ "msnet",   "Microsoft .NET (csc)" },
			{ "mono",    "Novell Mono (mcs)"    },
			{ "pnet",    "Portable.NET (cscc)"  },
		}
	}

	newoption
	{
		trigger     = "file",
		value       = "FILE",
		description = "Read FILE as a Premake script; default is 'premake4.lua'"
	}
	
	newoption
	{
		trigger     = "help",
		description = "Display this information"
	}
		
	newoption
	{
		trigger     = "os",
		value       = "VALUE",
		description = "Generate files for a different operating system",
		allowed = {
			{ "bsd",      "OpenBSD, NetBSD, or FreeBSD" },
			{ "haiku",    "Haiku" },
			{ "linux",    "Linux" },
			{ "macosx",   "Apple Mac OS X" },
			{ "solaris",  "Solaris" },
			{ "windows",  "Microsoft Windows" },
		}
	}

	newoption
	{
		trigger     = "platform",
		value       = "VALUE",
		description = "Add target architecture (if supported by action)",
		allowed = {
			{ "x32",         "32-bit" },
			{ "x64",         "64-bit" },
			{ "universal",   "Mac OS X Universal, 32- and 64-bit" },
			{ "universal32", "Mac OS X Universal, 32-bit only" },
			{ "universal64", "Mac OS X Universal, 64-bit only" },
			{ "ps3",         "Playstation 3 (experimental)" },
			{ "xbox360",     "Xbox 360 (experimental)" },
		}
	}
	
	newoption
	{
		trigger     = "scripts",
		value       = "path",
		description = "Search for additional scripts on the given path"
	}
	
	newoption
	{
		trigger     = "version",
		description = "Display version information"
	}
	-- AMALGAMATE FILE TAIL : /src/base/cmdline.lua
-- AMALGAMATE FILE HEAD : /src/tools/dotnet.lua
--
-- dotnet.lua
-- Interface for the C# compilers, all of which are flag compatible.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--
	
	premake.dotnet = { }
	premake.dotnet.namestyle = "windows"
	

--
-- Translation of Premake flags into CSC flags
--

	local flags =
	{
		FatalWarning   = "/warnaserror",
		Optimize       = "/optimize",
		OptimizeSize   = "/optimize",
		OptimizeSpeed  = "/optimize",
		Symbols        = "/debug",
		Unsafe         = "/unsafe"
	}


--
-- Return the default build action for a given file, based on the file extension.
--

	function premake.dotnet.getbuildaction(fcfg)
		local ext = path.getextension(fcfg.name):lower()
		if fcfg.buildaction == "Compile" or ext == ".cs" then
			return "Compile"
		elseif fcfg.buildaction == "Embed" or ext == ".resx" then
			return "EmbeddedResource"
		elseif fcfg.buildaction == "Copy" or ext == ".asax" or ext == ".aspx" then
			return "Content"
		elseif fcfg.buildaction == "Page" or ext == ".xaml" then
			if ( path.getname( fcfg.name ) == "App.xaml" ) then
				return "ApplicationDefinition"
			else
				return "Page"
			end
		else
			return "None"
		end
	end
	
	
	
--
-- Returns the compiler filename (they all use the same arguments)
--

	function premake.dotnet.getcompilervar(cfg)
		if (_OPTIONS.dotnet == "msnet") then
			return "csc"
		elseif (_OPTIONS.dotnet == "mono") then
			if (cfg.framework <= "1.1") then
				return "mcs"
			elseif (cfg.framework >= "4.0") then
				return "dmcs"
			else 
				return "gmcs"
			end
		else
			return "cscc"
		end
	end



--
-- Returns a list of compiler flags, based on the supplied configuration.
--

	function premake.dotnet.getflags(cfg)
		local result = table.translate(cfg.flags, flags)
		return result		
	end



--
-- Translates the Premake kind into the CSC kind string.
--

	function premake.dotnet.getkind(cfg)
		if (cfg.kind == "ConsoleApp") then
			return "Exe"
		elseif (cfg.kind == "WindowedApp") then
			return "WinExe"
		elseif (cfg.kind == "SharedLib") then
			return "Library"
		end
	end-- AMALGAMATE FILE TAIL : /src/tools/dotnet.lua
-- AMALGAMATE FILE HEAD : /src/tools/gcc.lua
--
-- gcc.lua
-- Provides GCC-specific configuration strings.
-- Copyright (c) 2002-2011 Jason Perkins and the Premake project
--


	premake.gcc = { }


--
-- Set default tools
--

	premake.gcc.cc     = "gcc"
	premake.gcc.cxx    = "g++"
	premake.gcc.ar     = "ar"


--
-- Translation of Premake flags into GCC flags
--

	local cflags =
	{
		EnableSSE      = "-msse",
		EnableSSE2     = "-msse2",
		ExtraWarnings  = "-Wall -Wextra",
		FatalWarnings  = "-Werror",
		FloatFast      = "-ffast-math",
		FloatStrict    = "-ffloat-store",
		NoFramePointer = "-fomit-frame-pointer",
		Optimize       = "-O2",
		OptimizeSize   = "-Os",
		OptimizeSpeed  = "-O3",
		Symbols        = "-g",
	}

	local cxxflags =
	{
		NoExceptions   = "-fno-exceptions",
		NoRTTI         = "-fno-rtti",
	}


--
-- Map platforms to flags
--

	premake.gcc.platforms =
	{
		Native = {
			cppflags = "-MMD",
		},
		x32 = {
			cppflags = "-MMD",
			flags    = "-m32",
			ldflags  = "-L/usr/lib32",
		},
		x64 = {
			cppflags = "-MMD",
			flags    = "-m64",
			ldflags  = "-L/usr/lib64",
		},
		Universal = {
			cppflags = "",
			flags    = "-arch i386 -arch x86_64 -arch ppc -arch ppc64",
		},
		Universal32 = {
			cppflags = "",
			flags    = "-arch i386 -arch ppc",
		},
		Universal64 = {
			cppflags = "",
			flags    = "-arch x86_64 -arch ppc64",
		},
		PS3 = {
			cc         = "ppu-lv2-g++",
			cxx        = "ppu-lv2-g++",
			ar         = "ppu-lv2-ar",
			cppflags   = "-MMD",
		},
		WiiDev = {
			cppflags    = "-MMD -MP -I$(LIBOGC_INC) $(MACHDEP)",
			ldflags		= "-L$(LIBOGC_LIB) $(MACHDEP)",
			cfgsettings = [[
  ifeq ($(strip $(DEVKITPPC)),)
    $(error "DEVKITPPC environment variable is not set")'
  endif
  include $(DEVKITPPC)/wii_rules']],
		},
	}

	local platforms = premake.gcc.platforms


--
-- Returns a list of compiler flags, based on the supplied configuration.
--

	function premake.gcc.getcppflags(cfg)
		local flags = { }
		table.insert(flags, platforms[cfg.platform].cppflags)

		-- We want the -MP flag for dependency generation (creates phony rules
		-- for headers, prevents make errors if file is later deleted), but
		-- Haiku doesn't support it (yet)
		if flags[1]:startswith("-MMD") and cfg.system ~= "haiku" then
			table.insert(flags, "-MP")
		end

		return flags
	end


	function premake.gcc.getcflags(cfg)
		local result = table.translate(cfg.flags, cflags)
		table.insert(result, platforms[cfg.platform].flags)
		if cfg.system ~= "windows" and cfg.kind == "SharedLib" then
			table.insert(result, "-fPIC")
		end
		return result
	end


	function premake.gcc.getcxxflags(cfg)
		local result = table.translate(cfg.flags, cxxflags)
		return result
	end


--
-- Returns a list of linker flags, based on the supplied configuration.
--

	function premake.gcc.getldflags(cfg)
		local result = { }

		-- OS X has a bug, see http://lists.apple.com/archives/Darwin-dev/2006/Sep/msg00084.html
		if not cfg.flags.Symbols then
			if cfg.system == "macosx" then
				table.insert(result, "-Wl,-x")
			else
				table.insert(result, "-s")
			end
		end

		if cfg.kind == "SharedLib" then
			if cfg.system == "macosx" then
				table.insert(result, "-dynamiclib")
			else
				table.insert(result, "-shared")
			end

			if cfg.system == "windows" and not cfg.flags.NoImportLib then
				table.insert(result, '-Wl,--out-implib="' .. cfg.linktarget.fullpath .. '"')
			end
		end

		if cfg.kind == "WindowedApp" and cfg.system == "windows" then
			table.insert(result, "-mwindows")
		end

		local platform = platforms[cfg.platform]
		table.insert(result, platform.flags)
		table.insert(result, platform.ldflags)

		return result
	end


--
-- Return a list of library search paths. Technically part of LDFLAGS but need to
-- be separated because of the way Visual Studio calls GCC for the PS3. See bug
-- #1729227 for background on why library paths must be split.
--

	function premake.gcc.getlibdirflags(cfg)
		local result = { }
		for _, value in ipairs(premake.getlinks(cfg, "all", "directory")) do
			table.insert(result, '-L' .. _MAKE.esc(value))
		end
		return result
	end



--
-- This is poorly named: returns a list of linker flags for external 
-- (i.e. system, or non-sibling) libraries. See bug #1729227 for 
-- background on why the path must be split.
--

	function premake.gcc.getlinkflags(cfg)
		local result = {}
		for _, value in ipairs(premake.getlinks(cfg, "system", "name")) do
			if path.getextension(value) == ".framework" then
				table.insert(result, '-framework ' .. _MAKE.esc(path.getbasename(value)))
			else
				table.insert(result, '-l' .. _MAKE.esc(value))
			end
		end
		return result
	end



--
-- Decorate defines for the GCC command line.
--

	function premake.gcc.getdefines(defines)
		local result = { }
		for _,def in ipairs(defines) do
			table.insert(result, '-D' .. def)
		end
		return result
	end



--
-- Decorate include file search paths for the GCC command line.
--

	function premake.gcc.getincludedirs(includedirs)
		local result = { }
		for _,dir in ipairs(includedirs) do
			table.insert(result, "-I" .. _MAKE.esc(dir))
		end
		return result
	end


--
-- Return platform specific project and configuration level
-- makesettings blocks.
--

	function premake.gcc.getcfgsettings(cfg)
		return platforms[cfg.platform].cfgsettings
	end
-- AMALGAMATE FILE TAIL : /src/tools/gcc.lua
-- AMALGAMATE FILE HEAD : /src/tools/msc.lua
--
-- msc.lua
-- Interface for the MS C/C++ compiler.
-- Copyright (c) 2009 Jason Perkins and the Premake project
--

	
	premake.msc = { }
	premake.msc.namestyle = "windows"
-- AMALGAMATE FILE TAIL : /src/tools/msc.lua
-- AMALGAMATE FILE HEAD : /src/tools/ow.lua
--
-- ow.lua
-- Provides Open Watcom-specific configuration strings.
-- Copyright (c) 2008 Jason Perkins and the Premake project
--

	premake.ow = { }
	premake.ow.namestyle = "windows"
	
	
--
-- Set default tools
--

	premake.ow.cc     = "WCL386"
	premake.ow.cxx    = "WCL386"
	premake.ow.ar     = "ar"
	
	
--
-- Translation of Premake flags into OpenWatcom flags
--

	local cflags =
	{
		ExtraWarnings  = "-wx",
		FatalWarning   = "-we",
		FloatFast      = "-omn",
		FloatStrict    = "-op",
		Optimize       = "-ox",
		OptimizeSize   = "-os",
		OptimizeSpeed  = "-ot",
		Symbols        = "-d2",
	}

	local cxxflags =
	{
		NoExceptions   = "-xd",
		NoRTTI         = "-xr",
	}
	


--
-- No specific platform support yet
--

	premake.ow.platforms = 
	{
		Native = { 
			flags = "" 
		},
	}


	
--
-- Returns a list of compiler flags, based on the supplied configuration.
--

	function premake.ow.getcppflags(cfg)
		return {}
	end

	function premake.ow.getcflags(cfg)
		local result = table.translate(cfg.flags, cflags)		
		if (cfg.flags.Symbols) then
			table.insert(result, "-hw")   -- Watcom debug format for Watcom debugger
		end
		return result		
	end
	
	function premake.ow.getcxxflags(cfg)
		local result = table.translate(cfg.flags, cxxflags)
		return result
	end
	


--
-- Returns a list of linker flags, based on the supplied configuration.
--

	function premake.ow.getldflags(cfg)
		local result = { }
		
		if (cfg.flags.Symbols) then
			table.insert(result, "op symf")
		end
				
		return result
	end
		
	
--
-- Returns a list of linker flags for library search directories and 
-- library names.
--

	function premake.ow.getlinkflags(cfg)
		local result = { }
		return result
	end
	
	

--
-- Decorate defines for the command line.
--

	function premake.ow.getdefines(defines)
		local result = { }
		for _,def in ipairs(defines) do
			table.insert(result, '-D' .. def)
		end
		return result
	end


	
--
-- Decorate include file search paths for the command line.
--

	function premake.ow.getincludedirs(includedirs)
		local result = { }
		for _,dir in ipairs(includedirs) do
			table.insert(result, '-I "' .. dir .. '"')
		end
		return result
	end

-- AMALGAMATE FILE TAIL : /src/tools/ow.lua
-- AMALGAMATE FILE HEAD : /src/tools/snc.lua
--
-- snc.lua
-- Provides Sony SNC-specific configuration strings.
-- Copyright (c) 2010 Jason Perkins and the Premake project
--

	
	premake.snc = { }
	

-- TODO: Will cfg.system == "windows" ever be true for SNC? If
-- not, remove the conditional blocks that use this test.

--
-- Set default tools
--

	premake.snc.cc     = "snc"
	premake.snc.cxx    = "g++"
	premake.snc.ar     = "ar"
	
	
--
-- Translation of Premake flags into SNC flags
--

	local cflags =
	{
		ExtraWarnings  = "-Xdiag=2",
		FatalWarnings  = "-Xquit=2",
	}

	local cxxflags =
	{
		NoExceptions   = "", -- No exceptions is the default in the SNC compiler.
		NoRTTI         = "-Xc-=rtti",
	}
	
	
--
-- Map platforms to flags
--

	premake.snc.platforms = 
	{
		PS3 = {
			cc         = "ppu-lv2-g++",
			cxx        = "ppu-lv2-g++",
			ar         = "ppu-lv2-ar",
			cppflags   = "-MMD -MP",
		}
	}

	local platforms = premake.snc.platforms
	

--
-- Returns a list of compiler flags, based on the supplied configuration.
--

	function premake.snc.getcppflags(cfg)
		local result = { }
		table.insert(result, platforms[cfg.platform].cppflags)
		return result
	end

	function premake.snc.getcflags(cfg)
		local result = table.translate(cfg.flags, cflags)
		table.insert(result, platforms[cfg.platform].flags)
		if cfg.kind == "SharedLib" then
			table.insert(result, "-fPIC")
		end
		
		return result		
	end
	
	function premake.snc.getcxxflags(cfg)
		local result = table.translate(cfg.flags, cxxflags)
		return result
	end
	


--
-- Returns a list of linker flags, based on the supplied configuration.
--

	function premake.snc.getldflags(cfg)
		local result = { }
		
		if not cfg.flags.Symbols then
			table.insert(result, "-s")
		end
	
		if cfg.kind == "SharedLib" then
			table.insert(result, "-shared")				
			if not cfg.flags.NoImportLib then
				table.insert(result, '-Wl,--out-implib="' .. cfg.linktarget.fullpath .. '"')
			end
		end
		
		local platform = platforms[cfg.platform]
		table.insert(result, platform.flags)
		table.insert(result, platform.ldflags)
		
		return result
	end
		

--
-- Return a list of library search paths. Technically part of LDFLAGS but need to
-- be separated because of the way Visual Studio calls SNC for the PS3. See bug 
-- #1729227 for background on why library paths must be split.
--

	function premake.snc.getlibdirflags(cfg)
		local result = { }
		for _, value in ipairs(premake.getlinks(cfg, "all", "directory")) do
			table.insert(result, '-L' .. _MAKE.esc(value))
		end
		return result
	end
	


	--
	-- This is poorly named: returns a list of linker flags for external 
	-- (i.e. system, or non-sibling) libraries. See bug #1729227 for 
	-- background on why the path must be split.
	--

	function premake.snc.getlinkflags(cfg)
		local result = {}
		for _, value in ipairs(premake.getlinks(cfg, "system", "name")) do
			table.insert(result, '-l' .. _MAKE.esc(value))
		end
		return result
	end
	
	

--
-- Decorate defines for the SNC command line.
--

	function premake.snc.getdefines(defines)
		local result = { }
		for _,def in ipairs(defines) do
			table.insert(result, '-D' .. def)
		end
		return result
	end


	
--
-- Decorate include file search paths for the SNC command line.
--

	function premake.snc.getincludedirs(includedirs)
		local result = { }
		for _,dir in ipairs(includedirs) do
			table.insert(result, "-I" .. _MAKE.esc(dir))
		end
		return result
	end
-- AMALGAMATE FILE TAIL : /src/tools/snc.lua
-- AMALGAMATE FILE HEAD : /src/base/validate.lua
--
-- validate.lua
-- Tests to validate the run-time environment before starting the action.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--


--
-- Performs a sanity check of all of the solutions and projects 
-- in the session to be sure they meet some minimum requirements.
--

	function premake.checkprojects()
		local action = premake.action.current()
		
		for sln in premake.solution.each() do
		
			-- every solution must have at least one project
			if (#sln.projects == 0) then
				return nil, "solution '" .. sln.name .. "' needs at least one project"
			end
			
			-- every solution must provide a list of configurations
			if (#sln.configurations == 0) then
				return nil, "solution '" .. sln.name .. "' needs configurations"
			end
			
			for prj in premake.solution.eachproject(sln) do

				-- every project must have a language
				if (not prj.language) then
					return nil, "project '" ..prj.name .. "' needs a language"
				end
				
				-- and the action must support it
				if (action.valid_languages) then
					if (not table.contains(action.valid_languages, prj.language)) then
						return nil, "the " .. action.shortname .. " action does not support " .. prj.language .. " projects"
					end
				end

				for cfg in premake.eachconfig(prj) do								
					
					-- every config must have a kind
					if (not cfg.kind) then
						return nil, "project '" ..prj.name .. "' needs a kind in configuration '" .. cfg.name .. "'"
					end
				
					-- and the action must support it
					if (action.valid_kinds) then
						if (not table.contains(action.valid_kinds, cfg.kind)) then
							return nil, "the " .. action.shortname .. " action does not support " .. cfg.kind .. " projects"
						end
					end
					
				end
				
				-- some actions have custom validation logic
				if action.oncheckproject then
					action.oncheckproject(prj)
				end
				
			end
		end		
		return true
	end


--
-- Check the specified tools (/cc, /dotnet, etc.) against the current action
-- to make sure they are compatible and supported.
--

	function premake.checktools()
		local action = premake.action.current()
		if (not action.valid_tools) then 
			return true 
		end
		
		for tool, values in pairs(action.valid_tools) do
			if (_OPTIONS[tool]) then
				if (not table.contains(values, _OPTIONS[tool])) then
					return nil, "the " .. action.shortname .. " action does not support /" .. tool .. "=" .. _OPTIONS[tool] .. " (yet)"
				end
			else
				_OPTIONS[tool] = values[1]
			end
		end
		
		return true
	end
-- AMALGAMATE FILE TAIL : /src/base/validate.lua
-- AMALGAMATE FILE HEAD : /src/base/help.lua
--
-- help.lua
-- User help, displayed on /help option.
-- Copyright (c) 2002-2008 Jason Perkins and the Premake project
--


	function premake.showhelp()
	
		-- display the basic usage
		printf("Premake %s, a build script generator", _PREMAKE_VERSION)
		printf(_PREMAKE_COPYRIGHT)
		printf("%s %s", _VERSION, _COPYRIGHT)
		printf("")
		printf("Usage: puremake [options] action [arguments]")
		printf("")

		
		-- display all options
		printf("OPTIONS")
		printf("")
		for option in premake.option.each() do
			local trigger = option.trigger
			local description = option.description
			if (option.value) then trigger = trigger .. "=" .. option.value end
			if (option.allowed) then description = description .. "; one of:" end
			
			printf(" --%-15s %s", trigger, description) 
			if (option.allowed) then
				for _, value in ipairs(option.allowed) do
					printf("     %-14s %s", value[1], value[2])
				end
			end
			printf("")
		end

		-- display all actions
		printf("ACTIONS")
		printf("")
		for action in premake.action.each() do
			printf(" %-17s %s", action.trigger, action.description)
		end
		printf("")


		-- see more
		printf("For additional information, see http://industriousone.com/premake")
		
	end


-- AMALGAMATE FILE TAIL : /src/base/help.lua
-- AMALGAMATE FILE HEAD : /src/base/premake.lua
--
-- premake.lua
-- High-level processing functions.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--


--
-- Open a file for output, and call a function to actually do the writing.
-- Used by the actions to generate solution and project files.
--
-- @param obj
--    A solution or project object; will be based to the callback function.
-- @param filename
--    The output filename; see the docs for premake.project.getfilename()
--    for the expected format.
-- @param callback
--    The function responsible for writing the file, should take a solution
--    or project as a parameters.
--

	function premake.generate(obj, filename, callback)
		filename = premake.project.getfilename(obj, filename)
		printf("Generating %s...", filename)

		local f, err = io.open(filename, "wb")
		if (not f) then
			error(err, 0)
		end

		io.output(f)
		callback(obj)
		f:close()
	end
-- AMALGAMATE FILE TAIL : /src/base/premake.lua
-- AMALGAMATE FILE HEAD : /src/actions/codeblocks/_codeblocks.lua
--
-- _codeblocks.lua
-- Define the Code::Blocks action(s).
-- Copyright (c) 2002-2011 Jason Perkins and the Premake project
--

	premake.codeblocks = { }

	newaction {
		trigger         = "codeblocks",
		shortname       = "Code::Blocks",
		description     = "Generate Code::Blocks project files",
		
		valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib" },
		
		valid_languages = { "C", "C++" },
		
		valid_tools     = {
			cc   = { "gcc", "ow" },
		},
		
		onsolution = function(sln)
			premake.generate(sln, "%%.workspace", premake.codeblocks.workspace)
		end,
		
		onproject = function(prj)
			premake.generate(prj, "%%.cbp", premake.codeblocks.cbp)
		end,
		
		oncleansolution = function(sln)
			premake.clean.file(sln, "%%.workspace")
		end,
		
		oncleanproject = function(prj)
			premake.clean.file(prj, "%%.cbp")
			premake.clean.file(prj, "%%.depend")
			premake.clean.file(prj, "%%.layout")
		end
	}
-- AMALGAMATE FILE TAIL : /src/actions/codeblocks/_codeblocks.lua
-- AMALGAMATE FILE HEAD : /src/actions/codeblocks/codeblocks_workspace.lua
--
-- codeblocks_workspace.lua
-- Generate a Code::Blocks workspace.
-- Copyright (c) 2009 Jason Perkins and the Premake project
--

	function premake.codeblocks.workspace(sln)
		_p('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>')
		_p('<CodeBlocks_workspace_file>')
		_p(1,'<Workspace title="%s">', sln.name)
		
		for prj in premake.solution.eachproject(sln) do
			local fname = path.join(path.getrelative(sln.location, prj.location), prj.name)
			local active = iif(prj.project == sln.projects[1], ' active="1"', '')
			
			_p(2,'<Project filename="%s.cbp"%s>', fname, active)
			for _,dep in ipairs(premake.getdependencies(prj)) do
				_p(3,'<Depends filename="%s.cbp" />', path.join(path.getrelative(sln.location, dep.location), dep.name))
			end
		
			_p(2,'</Project>')
		end
		
		_p(1,'</Workspace>')
		_p('</CodeBlocks_workspace_file>')
	end

-- AMALGAMATE FILE TAIL : /src/actions/codeblocks/codeblocks_workspace.lua
-- AMALGAMATE FILE HEAD : /src/actions/codeblocks/codeblocks_cbp.lua
--
-- codeblocks_cbp.lua
-- Generate a Code::Blocks C/C++ project.
-- Copyright (c) 2009, 2011 Jason Perkins and the Premake project
--

	local codeblocks = premake.codeblocks


--
-- Write out a list of the source code files in the project.
--

	function codeblocks.files(prj)
		local pchheader
		if (prj.pchheader) then
			pchheader = path.getrelative(prj.location, prj.pchheader)
		end
		
		for fcfg in premake.project.eachfile(prj) do
			_p(2,'<Unit filename="%s">', premake.esc(fcfg.name))
			if fcfg.name ~= fcfg.vpath then
				_p(3,'<Option virtualFolder="%s" />', path.getdirectory(fcfg.vpath))
			end
			if path.isresourcefile(fcfg.name) then
				_p(3,'<Option compilerVar="WINDRES" />')
			elseif path.iscfile(fcfg.name) and prj.language == "C++" then
				_p(3,'<Option compilerVar="CC" />')
			end
			if not prj.flags.NoPCH and fcfg.name == pchheader then
				_p(3,'<Option compilerVar="%s" />', iif(prj.language == "C", "CC", "CPP"))
				_p(3,'<Option compile="1" />')
				_p(3,'<Option weight="0" />')
				_p(3,'<Add option="-x c++-header" />')
			end
			_p(2,'</Unit>')
		end
	end

	function premake.codeblocks.debugenvs(cfg)
		--Assumption: if gcc is being used then so is gdb although this section will be ignored by
		--other debuggers. If using gcc and not gdb it will silently not pass the
		--environment arguments to the debugger
		if premake.gettool(cfg) == premake.gcc then
			_p(3,'<debugger>')
				_p(4,'<remote_debugging target="%s">', premake.esc(cfg.longname))
					local args = ''
					local sz = #cfg.debugenvs
					for idx, v in ipairs(cfg.debugenvs) do
						args = args .. 'set env ' .. v 
						if sz ~= idx then args = args .. '&#x0A;' end
					end
					_p(5,'<options additional_cmds_before="%s" />',args)
				_p(4,'</remote_debugging>')
			_p(3,'</debugger>')
		else
			 error('Sorry at this moment there is no support for debug environment variables with this debugger and codeblocks')
		end
	end
	
--
-- The main function: write out the project file.
--
	
	function premake.codeblocks.cbp(prj)
		-- alias the C/C++ compiler interface
		local cc = premake.gettool(prj)
		
		_p('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>')
		_p('<CodeBlocks_project_file>')
		_p(1,'<FileVersion major="1" minor="6" />')
		
		-- write project block header
		_p(1,'<Project>')
		_p(2,'<Option title="%s" />', premake.esc(prj.name))
		_p(2,'<Option pch_mode="2" />')
		_p(2,'<Option compiler="%s" />', _OPTIONS.cc)

		-- build a list of supported target platforms; I don't support cross-compiling yet
		local platforms = premake.filterplatforms(prj.solution, cc.platforms, "Native")
		for i = #platforms, 1, -1 do
			if premake.platforms[platforms[i]].iscrosscompiler then
				table.remove(platforms, i)
			end
		end 
		
		-- write configuration blocks
		_p(2,'<Build>')
		for _, platform in ipairs(platforms) do		
			for cfg in premake.eachconfig(prj, platform) do
				_p(3,'<Target title="%s">', premake.esc(cfg.longname))
				
				_p(4,'<Option output="%s" prefix_auto="0" extension_auto="0" />', premake.esc(cfg.buildtarget.fullpath))
				
				if cfg.debugdir then
					_p(4,'<Option working_dir="%s" />', premake.esc(cfg.debugdir))
				end
				
				_p(4,'<Option object_output="%s" />', premake.esc(cfg.objectsdir))

				-- identify the type of binary
				local types = { WindowedApp = 0, ConsoleApp = 1, StaticLib = 2, SharedLib = 3 }
				_p(4,'<Option type="%d" />', types[cfg.kind])

				_p(4,'<Option compiler="%s" />', _OPTIONS.cc)
				
				if (cfg.kind == "SharedLib") then
					_p(4,'<Option createDefFile="0" />')
					_p(4,'<Option createStaticLib="%s" />', iif(cfg.flags.NoImportLib, 0, 1))
				end

				-- begin compiler block --
				_p(4,'<Compiler>')
				for _,flag in ipairs(table.join(cc.getcflags(cfg), cc.getcxxflags(cfg), cc.getdefines(cfg.defines), cfg.buildoptions)) do
					_p(5,'<Add option="%s" />', premake.esc(flag))
				end
				if not cfg.flags.NoPCH and cfg.pchheader then
					_p(5,'<Add option="-Winvalid-pch" />')
					_p(5,'<Add option="-include &quot;%s&quot;" />', premake.esc(cfg.pchheader))
				end
				for _,v in ipairs(cfg.includedirs) do
					_p(5,'<Add directory="%s" />', premake.esc(v))
				end
				_p(4,'</Compiler>')
				-- end compiler block --
				
				-- begin linker block --
				_p(4,'<Linker>')
				for _,flag in ipairs(table.join(cc.getldflags(cfg), cfg.linkoptions)) do
					_p(5,'<Add option="%s" />', premake.esc(flag))
				end
				for _,v in ipairs(premake.getlinks(cfg, "all", "directory")) do
					_p(5,'<Add directory="%s" />', premake.esc(v))
				end
				for _,v in ipairs(premake.getlinks(cfg, "all", "basename")) do
					_p(5,'<Add library="%s" />', premake.esc(v))
				end
				_p(4,'</Linker>')
				-- end linker block --
				
				-- begin resource compiler block --
				if premake.findfile(cfg, ".rc") then
					_p(4,'<ResourceCompiler>')
					for _,v in ipairs(cfg.includedirs) do
						_p(5,'<Add directory="%s" />', premake.esc(v))
					end
					for _,v in ipairs(cfg.resincludedirs) do
						_p(5,'<Add directory="%s" />', premake.esc(v))
					end
					_p(4,'</ResourceCompiler>')
				end
				-- end resource compiler block --
				
				-- begin build steps --
				if #cfg.prebuildcommands > 0 or #cfg.postbuildcommands > 0 then
					_p(4,'<ExtraCommands>')
					for _,v in ipairs(cfg.prebuildcommands) do
						_p(5,'<Add before="%s" />', premake.esc(v))
					end
					for _,v in ipairs(cfg.postbuildcommands) do
						_p(5,'<Add after="%s" />', premake.esc(v))
					end

					_p(4,'</ExtraCommands>')
				end
				-- end build steps --
				
				_p(3,'</Target>')
			end
		end
		_p(2,'</Build>')
		
		codeblocks.files(prj)
		
		_p(2,'<Extensions>')
        for _, platform in ipairs(platforms) do
			for cfg in premake.eachconfig(prj, platform) do
				if cfg.debugenvs and #cfg.debugenvs > 0 then
					premake.codeblocks.debugenvs(cfg)
				end
			end
		end
		_p(2,'</Extensions>')

		_p(1,'</Project>')
		_p('</CodeBlocks_project_file>')
		_p('')
		
	end
-- AMALGAMATE FILE TAIL : /src/actions/codeblocks/codeblocks_cbp.lua
-- AMALGAMATE FILE HEAD : /src/actions/codelite/_codelite.lua
--
-- _codelite.lua
-- Define the CodeLite action(s).
-- Copyright (c) 2008-2009 Jason Perkins and the Premake project
--

	premake.codelite = { }

	newaction {
		trigger         = "codelite",
		shortname       = "CodeLite",
		description     = "Generate CodeLite project files",
	
		valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib" },
		
		valid_languages = { "C", "C++" },
		
		valid_tools     = {
			cc   = { "gcc" },
		},
		
		onsolution = function(sln)
			premake.generate(sln, "%%.workspace", premake.codelite.workspace)
		end,
		
		onproject = function(prj)
			premake.generate(prj, "%%.project", premake.codelite.project)
		end,
		
		oncleansolution = function(sln)
			premake.clean.file(sln, "%%.workspace")
			premake.clean.file(sln, "%%_wsp.mk")
			premake.clean.file(sln, "%%.tags")
		end,
		
		oncleanproject = function(prj)
			premake.clean.file(prj, "%%.project")
			premake.clean.file(prj, "%%.mk")
			premake.clean.file(prj, "%%.list")
			premake.clean.file(prj, "%%.out")
		end
	}
-- AMALGAMATE FILE TAIL : /src/actions/codelite/_codelite.lua
-- AMALGAMATE FILE HEAD : /src/actions/codelite/codelite_workspace.lua
--
-- codelite_workspace.lua
-- Generate a CodeLite workspace file.
-- Copyright (c) 2009, 2011 Jason Perkins and the Premake project
--

	function premake.codelite.workspace(sln)
		_p('<?xml version="1.0" encoding="utf-8"?>')
		_p('<CodeLite_Workspace Name="%s" Database="./%s.tags">', premake.esc(sln.name), premake.esc(sln.name))
		
		for i,prj in ipairs(sln.projects) do
			local name = premake.esc(prj.name)
			local fname = path.join(path.getrelative(sln.location, prj.location), prj.name)
			local active = iif(i==1, "Yes", "No")
			_p('  <Project Name="%s" Path="%s.project" Active="%s" />', name, fname, active)
		end
		
		-- build a list of supported target platforms; I don't support cross-compiling yet
		local platforms = premake.filterplatforms(sln, premake[_OPTIONS.cc].platforms, "Native")
		for i = #platforms, 1, -1 do
			if premake.platforms[platforms[i]].iscrosscompiler then
				table.remove(platforms, i)
			end
		end 

		_p('  <BuildMatrix>')
		for _, platform in ipairs(platforms) do
			for _, cfgname in ipairs(sln.configurations) do
				local name = premake.getconfigname(cfgname, platform):gsub("|","_")
				_p('    <WorkspaceConfiguration Name="%s" Selected="yes">', name)
				for _,prj in ipairs(sln.projects) do
					_p('      <Project Name="%s" ConfigName="%s"/>', prj.name, name)
				end
				_p('    </WorkspaceConfiguration>')
			end
		end
		_p('  </BuildMatrix>')
		_p('</CodeLite_Workspace>')
	end

-- AMALGAMATE FILE TAIL : /src/actions/codelite/codelite_workspace.lua
-- AMALGAMATE FILE HEAD : /src/actions/codelite/codelite_project.lua
--
-- codelite_project.lua
-- Generate a CodeLite C/C++ project file.
-- Copyright (c) 2009, 2011 Jason Perkins and the Premake project
--

	local codelite = premake.codelite
	local tree = premake.tree


--
-- Write out a list of the source code files in the project.
--

	function codelite.files(prj)
		local tr = premake.project.buildsourcetree(prj)
		tree.traverse(tr, {
			
			-- folders are handled at the internal nodes
			onbranchenter = function(node, depth)
				_p(depth, '<VirtualDirectory Name="%s">', node.name)
			end,

			onbranchexit = function(node, depth)
				_p(depth, '</VirtualDirectory>')
			end,

			-- source files are handled at the leaves
			onleaf = function(node, depth)
				_p(depth, '<File Name="%s"/>', node.cfg.name)
			end,
			
		}, true, 1)
	end
	

--
-- The main function: write out the project file.
--

	function premake.codelite.project(prj)
		io.indent = "  "
		
		_p('<?xml version="1.0" encoding="utf-8"?>')
		_p('<CodeLite_Project Name="%s">', premake.esc(prj.name))

		-- Write out the list of source code files in the project
		codelite.files(prj)

		local types = { 
			ConsoleApp  = "Executable", 
			WindowedApp = "Executable", 
			StaticLib   = "Static Library",
			SharedLib   = "Dynamic Library",
		}
		_p('  <Settings Type="%s">', types[prj.kind])
		
		-- build a list of supported target platforms; I don't support cross-compiling yet
		local platforms = premake.filterplatforms(prj.solution, premake[_OPTIONS.cc].platforms, "Native")
		for i = #platforms, 1, -1 do
			if premake.platforms[platforms[i]].iscrosscompiler then
				table.remove(platforms, i)
			end
		end 

		for _, platform in ipairs(platforms) do
			for cfg in premake.eachconfig(prj, platform) do
				local name = premake.esc(cfg.longname):gsub("|","_")
				local compiler = iif(cfg.language == "C", "gcc", "g++")
				_p('    <Configuration Name="%s" CompilerType="gnu %s" DebuggerType="GNU gdb debugger" Type="%s">', name, compiler, types[cfg.kind])
			
				local fname  = premake.esc(cfg.buildtarget.fullpath)
				local objdir = premake.esc(cfg.objectsdir)
				local runcmd = cfg.buildtarget.name
				local rundir = cfg.debugdir or cfg.buildtarget.directory
				local runargs = table.concat(cfg.debugargs, " ")
				local pause  = iif(cfg.kind == "WindowedApp", "no", "yes")
				_p('      <General OutputFile="%s" IntermediateDirectory="%s" Command="./%s" CommandArguments="%s" WorkingDirectory="%s" PauseExecWhenProcTerminates="%s"/>', fname, objdir, runcmd, runargs, rundir, pause)
				
				-- begin compiler block --
				local flags = premake.esc(table.join(premake.gcc.getcflags(cfg), premake.gcc.getcxxflags(cfg), cfg.buildoptions))
				_p('      <Compiler Required="yes" Options="%s">', table.concat(flags, ";"))
				for _,v in ipairs(cfg.includedirs) do
					_p('        <IncludePath Value="%s"/>', premake.esc(v))
				end
				for _,v in ipairs(cfg.defines) do
					_p('        <Preprocessor Value="%s"/>', premake.esc(v))
				end
				_p('      </Compiler>')
				-- end compiler block --
				
				-- begin linker block --
				flags = premake.esc(table.join(premake.gcc.getldflags(cfg), cfg.linkoptions))
				_p('      <Linker Required="yes" Options="%s">', table.concat(flags, ";"))
				for _,v in ipairs(premake.getlinks(cfg, "all", "directory")) do
					_p('        <LibraryPath Value="%s" />', premake.esc(v))
				end
				for _,v in ipairs(premake.getlinks(cfg, "siblings", "basename")) do
					_p('        <Library Value="%s" />', premake.esc(v))
				end
				for _,v in ipairs(premake.getlinks(cfg, "system", "name")) do
					_p('        <Library Value="%s" />', premake.esc(v))
				end		
				_p('      </Linker>')
				-- end linker block --
				
				-- begin resource compiler block --
				if premake.findfile(cfg, ".rc") then
					local defines = table.implode(table.join(cfg.defines, cfg.resdefines), "-D", ";", "")
					local options = table.concat(cfg.resoptions, ";")
					_p('      <ResourceCompiler Required="yes" Options="%s%s">', defines, options)
					for _,v in ipairs(table.join(cfg.includedirs, cfg.resincludedirs)) do
						_p('        <IncludePath Value="%s"/>', premake.esc(v))
					end
					_p('      </ResourceCompiler>')
				else
					_p('      <ResourceCompiler Required="no" Options=""/>')
				end
				-- end resource compiler block --
				
				-- begin build steps --
				if #cfg.prebuildcommands > 0 then
					_p('      <PreBuild>')
					for _,v in ipairs(cfg.prebuildcommands) do
						_p('        <Command Enabled="yes">%s</Command>', premake.esc(v))
					end
					_p('      </PreBuild>')
				end
				if #cfg.postbuildcommands > 0 then
					_p('      <PostBuild>')
					for _,v in ipairs(cfg.postbuildcommands) do
						_p('        <Command Enabled="yes">%s</Command>', premake.esc(v))
					end
					_p('      </PostBuild>')
				end
				-- end build steps --
				
				_p('      <CustomBuild Enabled="no">')
				_p('        <CleanCommand></CleanCommand>')
				_p('        <BuildCommand></BuildCommand>')
				_p('        <SingleFileCommand></SingleFileCommand>')
				_p('        <MakefileGenerationCommand></MakefileGenerationCommand>')
				_p('        <ThirdPartyToolName>None</ThirdPartyToolName>')
				_p('        <WorkingDirectory></WorkingDirectory>')
				_p('      </CustomBuild>')
				_p('      <AdditionalRules>')
				_p('        <CustomPostBuild></CustomPostBuild>')
				_p('        <CustomPreBuild></CustomPreBuild>')
				_p('      </AdditionalRules>')
				_p('    </Configuration>')
			end
		end
		_p('  </Settings>')

		for _, platform in ipairs(platforms) do
			for cfg in premake.eachconfig(prj, platform) do
				_p('  <Dependencies name="%s">', cfg.longname:gsub("|","_"))
				for _,dep in ipairs(premake.getdependencies(prj)) do
					_p('    <Project Name="%s"/>', dep.name)
				end
				_p('  </Dependencies>')
			end
		end
		
		_p('</CodeLite_Project>')
	end
-- AMALGAMATE FILE TAIL : /src/actions/codelite/codelite_project.lua
-- AMALGAMATE FILE HEAD : /src/actions/make/_make.lua
--
-- _make.lua
-- Define the makefile action(s).
-- Copyright (c) 2002-2011 Jason Perkins and the Premake project
--

	_MAKE = { }
	premake.make = { }
	local make = premake.make

--
-- Escape a string so it can be written to a makefile.
--

	function _MAKE.esc(value)
		local result
		if (type(value) == "table") then
			result = { }
			for _,v in ipairs(value) do
				table.insert(result, _MAKE.esc(v))
			end
			return result
		else
			-- handle simple replacements
			result = value:gsub("\\", "\\\\")
			result = result:gsub(" ", "\\ ")
			result = result:gsub("%(", "\\%(")
			result = result:gsub("%)", "\\%)")

			-- leave $(...) shell replacement sequences alone
			result = result:gsub("$\\%((.-)\\%)", "$%(%1%)")
			return result
		end
	end



--
-- Rules for file ops based on the shell type. Can't use defines and $@ because
-- it screws up the escaping of spaces and parethesis (anyone know a solution?)
--

	function premake.make_copyrule(source, target)
		_p('%s: %s', target, source)
		_p('\t@echo Copying $(notdir %s)', target)
		_p('ifeq (posix,$(SHELLTYPE))')
		_p('\t$(SILENT) cp -fR %s %s', source, target)
		_p('else')
		_p('\t$(SILENT) copy /Y $(subst /,\\\\,%s) $(subst /,\\\\,%s)', source, target)
		_p('endif')
	end

	function premake.make_mkdirrule(var)
		_p('\t@echo Creating %s', var)
		_p('ifeq (posix,$(SHELLTYPE))')
		_p('\t$(SILENT) mkdir -p %s', var)
		_p('else')
		_p('\t$(SILENT) mkdir $(subst /,\\\\,%s)', var)
		_p('endif')
		_p('')
	end


--
-- Format a list of values to be safely written as part of a variable assignment.
--

	function make.list(value)
		if #value > 0 then
			return " " .. table.concat(value, " ")
		else
			return ""
		end
	end


--
-- Get the makefile file name for a solution or a project. If this object is the
-- only one writing to a location then I can use "Makefile". If more than one object
-- writes to the same location I use name + ".make" to keep it unique.
--

	function _MAKE.getmakefilename(this, searchprjs)
		-- how many projects/solutions use this location?
		local count = 0
		for sln in premake.solution.each() do
			if (sln.location == this.location) then count = count + 1 end
			if (searchprjs) then
				for _,prj in ipairs(sln.projects) do
					if (prj.location == this.location) then count = count + 1 end
				end
			end
		end

		if (count == 1) then
			return "Makefile"
		else
			return this.name .. ".make"
		end
	end


--
-- Returns a list of object names, properly escaped to be included in the makefile.
--

	function _MAKE.getnames(tbl)
		local result = table.extract(tbl, "name")
		for k,v in pairs(result) do
			result[k] = _MAKE.esc(v)
		end
		return result
	end



--
-- Write out the raw settings blocks.
--

	function make.settings(cfg, cc)
		if #cfg.makesettings > 0 then
			for _, value in ipairs(cfg.makesettings) do
				_p(value)
			end
		end

		local toolsettings = cc.platforms[cfg.platform].cfgsettings
		if toolsettings then
			_p(toolsettings)
		end
	end


--
-- Register the "gmake" action
--

	newaction {
		trigger         = "gmake",
		shortname       = "GNU Make",
		description     = "Generate GNU makefiles for POSIX, MinGW, and Cygwin",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib" },

		valid_languages = { "C", "C++", "C#" },

		valid_tools     = {
			cc     = { "gcc" },
			dotnet = { "mono", "msnet", "pnet" },
		},

		onsolution = function(sln)
			premake.generate(sln, _MAKE.getmakefilename(sln, false), premake.make_solution)
		end,

		onproject = function(prj)
			local makefile = _MAKE.getmakefilename(prj, true)
			if premake.isdotnetproject(prj) then
				premake.generate(prj, makefile, premake.make_csharp)
			else
				premake.generate(prj, makefile, premake.make_cpp)
			end
		end,

		oncleansolution = function(sln)
			premake.clean.file(sln, _MAKE.getmakefilename(sln, false))
		end,

		oncleanproject = function(prj)
			premake.clean.file(prj, _MAKE.getmakefilename(prj, true))
		end
	}
-- AMALGAMATE FILE TAIL : /src/actions/make/_make.lua
-- AMALGAMATE FILE HEAD : /src/actions/make/make_solution.lua
--
-- make_solution.lua
-- Generate a solution-level makefile.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--

	function premake.make_solution(sln)
		-- create a shortcut to the compiler interface
		local cc = premake[_OPTIONS.cc]

		-- build a list of supported target platforms that also includes a generic build
		local platforms = premake.filterplatforms(sln, cc.platforms, "Native")

		-- write a header showing the build options
		_p('# %s solution makefile autogenerated by Premake', premake.action.current().shortname)
		_p('# Type "make help" for usage help')
		_p('')
		
		-- set a default configuration
		_p('ifndef config')
		_p('  config=%s', _MAKE.esc(premake.getconfigname(sln.configurations[1], platforms[1], true)))
		_p('endif')
		_p('export config')
		_p('')

		-- list the projects included in the solution
		_p('PROJECTS := %s', table.concat(_MAKE.esc(table.extract(sln.projects, "name")), " "))
		_p('')
		_p('.PHONY: all clean help $(PROJECTS)')
		_p('')
		_p('all: $(PROJECTS)')
		_p('')

		-- write the project build rules
		for _, prj in ipairs(sln.projects) do
			_p('%s: %s', _MAKE.esc(prj.name), table.concat(_MAKE.esc(table.extract(premake.getdependencies(prj), "name")), " "))
			_p('\t@echo "==== Building %s ($(config)) ===="', prj.name)
			_p('\t@${MAKE} --no-print-directory -C %s -f %s', _MAKE.esc(path.getrelative(sln.location, prj.location)), _MAKE.esc(_MAKE.getmakefilename(prj, true)))
			_p('')
		end

		-- clean rules
		_p('clean:')
		for _ ,prj in ipairs(sln.projects) do
			_p('\t@${MAKE} --no-print-directory -C %s -f %s clean', _MAKE.esc(path.getrelative(sln.location, prj.location)), _MAKE.esc(_MAKE.getmakefilename(prj, true)))
		end
		_p('')
		
		-- help rule
		_p('help:')
		_p(1,'@echo "Usage: make [config=name] [target]"')
		_p(1,'@echo ""')
		_p(1,'@echo "CONFIGURATIONS:"')

		local cfgpairs = { }
		for _, platform in ipairs(platforms) do
			for _, cfgname in ipairs(sln.configurations) do
				_p(1,'@echo "   %s"', premake.getconfigname(cfgname, platform, true))
			end
		end

		_p(1,'@echo ""')
		_p(1,'@echo "TARGETS:"')
		_p(1,'@echo "   all (default)"')
		_p(1,'@echo "   clean"')

		for _, prj in ipairs(sln.projects) do
			_p(1,'@echo "   %s"', prj.name)
		end

		_p(1,'@echo ""')
		_p(1,'@echo "For more information, see http://industriousone.com/premake/quick-start"')
		
	end
-- AMALGAMATE FILE TAIL : /src/actions/make/make_solution.lua
-- AMALGAMATE FILE HEAD : /src/actions/make/make_cpp.lua
--
-- make_cpp.lua
-- Generate a C/C++ project makefile.
-- Copyright (c) 2002-2013 Jason Perkins and the Premake project
--

	premake.make.cpp = { }
	local cpp = premake.make.cpp
	local make = premake.make


	function premake.make_cpp(prj)
		-- create a shortcut to the compiler interface
		local cc = premake.gettool(prj)

		-- build a list of supported target platforms that also includes a generic build
		local platforms = premake.filterplatforms(prj.solution, cc.platforms, "Native")

		premake.gmake_cpp_header(prj, cc, platforms)

		for _, platform in ipairs(platforms) do
			for cfg in premake.eachconfig(prj, platform) do
				premake.gmake_cpp_config(cfg, cc)
			end
		end

		-- list intermediate files
		_p('OBJECTS := \\')
		for _, file in ipairs(prj.files) do
			if path.iscppfile(file) then
				_p('\t$(OBJDIR)/%s.o \\', _MAKE.esc(path.getbasename(file)))
			end
		end
		_p('')

		_p('RESOURCES := \\')
		for _, file in ipairs(prj.files) do
			if path.isresourcefile(file) then
				_p('\t$(OBJDIR)/%s.res \\', _MAKE.esc(path.getbasename(file)))
			end
		end
		_p('')

		-- identify the shell type
		_p('SHELLTYPE := msdos')
		_p('ifeq (,$(ComSpec)$(COMSPEC))')
		_p('  SHELLTYPE := posix')
		_p('endif')
		_p('ifeq (/bin,$(findstring /bin,$(SHELL)))')
		_p('  SHELLTYPE := posix')
		_p('endif')
		_p('')

		-- main build rule(s)
		_p('.PHONY: clean prebuild prelink')
		_p('')

		if os.is("MacOSX") and prj.kind == "WindowedApp" then
			_p('all: $(TARGETDIR) $(OBJDIR) prebuild prelink $(TARGET) $(dir $(TARGETDIR))PkgInfo $(dir $(TARGETDIR))Info.plist')
		else
			_p('all: $(TARGETDIR) $(OBJDIR) prebuild prelink $(TARGET)')
		end
		_p('\t@:')
		_p('')

		-- target build rule
		_p('$(TARGET): $(GCH) $(OBJECTS) $(LDDEPS) $(RESOURCES)')
		_p('\t@echo Linking %s', prj.name)
		_p('\t$(SILENT) $(LINKCMD)')
		_p('\t$(POSTBUILDCMDS)')
		_p('')

		-- Create destination directories. Can't use $@ for this because it loses the
		-- escaping, causing issues with spaces and parenthesis
		_p('$(TARGETDIR):')
		premake.make_mkdirrule("$(TARGETDIR)")

		_p('$(OBJDIR):')
		premake.make_mkdirrule("$(OBJDIR)")

		-- Mac OS X specific targets
		if os.is("MacOSX") and prj.kind == "WindowedApp" then
			_p('$(dir $(TARGETDIR))PkgInfo:')
			_p('$(dir $(TARGETDIR))Info.plist:')
			_p('')
		end

		-- clean target
		_p('clean:')
		_p('\t@echo Cleaning %s', prj.name)
		_p('ifeq (posix,$(SHELLTYPE))')
		_p('\t$(SILENT) rm -f  $(TARGET)')
		_p('\t$(SILENT) rm -rf $(OBJDIR)')
		_p('else')
		_p('\t$(SILENT) if exist $(subst /,\\\\,$(TARGET)) del $(subst /,\\\\,$(TARGET))')
		_p('\t$(SILENT) if exist $(subst /,\\\\,$(OBJDIR)) rmdir /s /q $(subst /,\\\\,$(OBJDIR))')
		_p('endif')
		_p('')

		-- custom build step targets
		_p('prebuild:')
		_p('\t$(PREBUILDCMDS)')
		_p('')

		_p('prelink:')
		_p('\t$(PRELINKCMDS)')
		_p('')

		-- precompiler header rule
		cpp.pchrules(prj)

		-- per-file build rules
		cpp.fileRules(prj)

		-- include the dependencies, built by GCC (with the -MMD flag)
		_p('-include $(OBJECTS:%%.o=%%.d)')
		_p('ifneq (,$(PCH))')
			_p('  -include $(OBJDIR)/$(notdir $(PCH)).d')
		_p('endif')
	end



--
-- Write the makefile header
--

	function premake.gmake_cpp_header(prj, cc, platforms)
		_p('# %s project makefile autogenerated by Premake', premake.action.current().shortname)

		-- set up the environment
		_p('ifndef config')
		_p('  config=%s', _MAKE.esc(premake.getconfigname(prj.solution.configurations[1], platforms[1], true)))
		_p('endif')
		_p('')

		_p('ifndef verbose')
		_p('  SILENT = @')
		_p('endif')
		_p('')

		_p('CC = %s', cc.cc)
		_p('CXX = %s', cc.cxx)
		_p('AR = %s', cc.ar)
		_p('')

		_p('ifndef RESCOMP')
		_p('  ifdef WINDRES')
		_p('    RESCOMP = $(WINDRES)')
		_p('  else')
		_p('    RESCOMP = windres')
		_p('  endif')
		_p('endif')
		_p('')
	end

--
-- Write a block of configuration settings.
--

	function premake.gmake_cpp_config(cfg, cc)

		_p('ifeq ($(config),%s)', _MAKE.esc(cfg.shortname))

		-- if this platform requires a special compiler or linker, list it here
		cpp.platformtools(cfg, cc)

		_p('  OBJDIR     = %s', _MAKE.esc(cfg.objectsdir))
		_p('  TARGETDIR  = %s', _MAKE.esc(cfg.buildtarget.directory))
		_p('  TARGET     = $(TARGETDIR)/%s', _MAKE.esc(cfg.buildtarget.name))
		_p('  DEFINES   +=%s', make.list(cc.getdefines(cfg.defines)))
		_p('  INCLUDES  +=%s', make.list(cc.getincludedirs(cfg.includedirs)))

		-- set up precompiled headers
		cpp.pchconfig(cfg)

		-- CPPFLAGS, CFLAGS, CXXFLAGS, and RESFLAGS
		cpp.flags(cfg, cc)

		-- write out libraries, linker flags, and the link command
		cpp.linker(cfg, cc)

		_p('  define PREBUILDCMDS')
		if #cfg.prebuildcommands > 0 then
			_p('\t@echo Running pre-build commands')
			_p('\t%s', table.implode(cfg.prebuildcommands, "", "", "\n\t"))
		end
		_p('  endef')

		_p('  define PRELINKCMDS')
		if #cfg.prelinkcommands > 0 then
			_p('\t@echo Running pre-link commands')
			_p('\t%s', table.implode(cfg.prelinkcommands, "", "", "\n\t"))
		end
		_p('  endef')

		_p('  define POSTBUILDCMDS')
		if #cfg.postbuildcommands > 0 then
			_p('\t@echo Running post-build commands')
			_p('\t%s', table.implode(cfg.postbuildcommands, "", "", "\n\t"))
		end
		_p('  endef')

		-- write out config-level makesettings blocks
		make.settings(cfg, cc)

		_p('endif')
		_p('')
	end


--
-- Platform support
--

	function cpp.platformtools(cfg, cc)
		local platform = cc.platforms[cfg.platform]
		if platform.cc then
			_p('  CC         = %s', platform.cc)
		end
		if platform.cxx then
			_p('  CXX        = %s', platform.cxx)
		end
		if platform.ar then
			_p('  AR         = %s', platform.ar)
		end
	end


--
-- Configurations
--

	function cpp.flags(cfg, cc)

		if cfg.pchheader and not cfg.flags.NoPCH then
			_p('  FORCE_INCLUDE += -include $(OBJDIR)/$(notdir $(PCH))')
		end

		_p('  ALL_CPPFLAGS  += $(CPPFLAGS) %s $(DEFINES) $(INCLUDES)', table.concat(cc.getcppflags(cfg), " "))

		_p('  ALL_CFLAGS    += $(CFLAGS) $(ALL_CPPFLAGS)%s', make.list(table.join(cc.getcflags(cfg), cfg.buildoptions)))
		_p('  ALL_CXXFLAGS  += $(CXXFLAGS) $(ALL_CFLAGS)%s', make.list(cc.getcxxflags(cfg)))

		_p('  ALL_RESFLAGS  += $(RESFLAGS) $(DEFINES) $(INCLUDES)%s',
		        make.list(table.join(cc.getdefines(cfg.resdefines),
		                                cc.getincludedirs(cfg.resincludedirs), cfg.resoptions)))
	end


--
-- Linker settings, including the libraries to link, the linker flags,
-- and the linker command.
--

	function cpp.linker(cfg, cc)
		-- Patch #3401184 changed the order
		_p('  ALL_LDFLAGS   += $(LDFLAGS)%s', make.list(table.join(cc.getlibdirflags(cfg), cc.getldflags(cfg), cfg.linkoptions)))

		_p('  LDDEPS    +=%s', make.list(_MAKE.esc(premake.getlinks(cfg, "siblings", "fullpath"))))
		_p('  LIBS      += $(LDDEPS)%s', make.list(cc.getlinkflags(cfg)))

		if cfg.kind == "StaticLib" then
			if cfg.platform:startswith("Universal") then
				_p('  LINKCMD    = libtool -o $(TARGET) $(OBJECTS)')
			else
				_p('  LINKCMD    = $(AR) -rcs $(TARGET) $(OBJECTS)')
			end
		else

			-- this was $(TARGET) $(LDFLAGS) $(OBJECTS)
			--   but had trouble linking to certain static libs; $(OBJECTS) moved up
			-- $(LDFLAGS) moved to end (http://sourceforge.net/p/premake/patches/107/)
			-- $(LIBS) moved to end (http://sourceforge.net/p/premake/bugs/279/)

			local tool = iif(cfg.language == "C", "CC", "CXX")
			_p('  LINKCMD    = $(%s) -o $(TARGET) $(OBJECTS) $(RESOURCES) $(ALL_LDFLAGS) $(LIBS)', tool)

		end
	end


--
-- Precompiled header support
--

	function cpp.pchconfig(cfg)

		-- If there is no header, or if PCH has been disabled, I can early out

		if not cfg.pchheader or cfg.flags.NoPCH then
			return
		end

		-- Visual Studio requires the PCH header to be specified in the same way
		-- it appears in the #include statements used in the source code; the PCH
		-- source actual handles the compilation of the header. GCC compiles the
		-- header file directly, and needs the file's actual file system path in
		-- order to locate it.

		-- To maximize the compatibility between the two approaches, see if I can
		-- locate the specified PCH header on one of the include file search paths
		-- and, if so, adjust the path automatically so the user doesn't have
		-- add a conditional configuration to the project script.

		local pch = cfg.pchheader
		for _, incdir in ipairs(cfg.includedirs) do

			-- convert this back to an absolute path for os.isfile()
			local abspath = path.getabsolute(path.join(cfg.project.location, incdir))

			local testname = path.join(abspath, pch)
			if os.isfile(testname) then
				pch = path.getrelative(cfg.location, testname)
				break
			end
		end

		_p('  PCH        = %s', _MAKE.esc(pch))
		_p('  GCH        = $(OBJDIR)/$(notdir $(PCH)).gch')

	end


	function cpp.pchrules(prj)
		_p('ifneq (,$(PCH))')
		_p('.NOTPARALLEL: $(GCH) $(PCH)')
		_p('$(GCH): $(PCH)')
		_p('\t@echo $(notdir $<)')

		local cmd = iif(prj.language == "C", "$(CC) -x c-header $(ALL_CFLAGS)", "$(CXX) -x c++-header $(ALL_CXXFLAGS)")
		_p('\t$(SILENT) %s -MMD -MP $(DEFINES) $(INCLUDES) -o "$@" -MF "$(@:%%.gch=%%.d)" -c "$<"', cmd)

		_p('endif')
		_p('')
	end


--
-- Build command for a single file.
--

	function cpp.fileRules(prj)
		for _, file in ipairs(prj.files or {}) do
			if path.iscppfile(file) then
				_p('$(OBJDIR)/%s.o: %s', _MAKE.esc(path.getbasename(file)), _MAKE.esc(file))
				_p('\t@echo $(notdir $<)')
				cpp.buildcommand(path.iscfile(file), "o")
				_p('')
			elseif (path.getextension(file) == ".rc") then
				_p('$(OBJDIR)/%s.res: %s', _MAKE.esc(path.getbasename(file)), _MAKE.esc(file))
				_p('\t@echo $(notdir $<)')
				_p('\t$(SILENT) $(RESCOMP) $< -O coff -o "$@" $(ALL_RESFLAGS)')
				_p('')
			end
		end
	end

	function cpp.buildcommand(iscfile, objext)
		local flags = iif(iscfile, '$(CC) $(ALL_CFLAGS)', '$(CXX) $(ALL_CXXFLAGS)')
		_p('\t$(SILENT) %s $(FORCE_INCLUDE) -o "$@" -MF "$(@:%%.%s=%%.d)" -c "$<"', flags, objext)
	end
-- AMALGAMATE FILE TAIL : /src/actions/make/make_cpp.lua
-- AMALGAMATE FILE HEAD : /src/actions/make/make_csharp.lua
--
-- make_csharp.lua
-- Generate a C# project makefile.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--

--
-- Given a .resx resource file, builds the path to corresponding .resource
-- file, matching the behavior and naming of Visual Studio.
--
		
	local function getresourcefilename(cfg, fname)
		if path.getextension(fname) == ".resx" then
		    local name = cfg.buildtarget.basename .. "."
		    local dir = path.getdirectory(fname)
		    if dir ~= "." then 
				name = name .. path.translate(dir, ".") .. "."
			end
			return "$(OBJDIR)/" .. _MAKE.esc(name .. path.getbasename(fname)) .. ".resources"
		else
			return fname
		end
	end



--
-- Main function
--
	
	function premake.make_csharp(prj)
		local csc = premake.dotnet

		-- Do some processing up front: build a list of configuration-dependent libraries.
		-- Libraries that are built to a location other than $(TARGETDIR) will need to
		-- be copied so they can be found at runtime.
		local cfglibs = { }
		local cfgpairs = { }
		local anycfg
		for cfg in premake.eachconfig(prj) do
			anycfg = cfg
			cfglibs[cfg] = premake.getlinks(cfg, "siblings", "fullpath")
			cfgpairs[cfg] = { }
			for _, fname in ipairs(cfglibs[cfg]) do
				if path.getdirectory(fname) ~= cfg.buildtarget.directory then
					cfgpairs[cfg]["$(TARGETDIR)/" .. _MAKE.esc(path.getname(fname))] = _MAKE.esc(fname)
				end
			end
		end
		
		-- sort the files into categories, based on their build action
		local sources = {}
		local embedded = { }
		local copypairs = { }
		
		for fcfg in premake.project.eachfile(prj) do
			local action = csc.getbuildaction(fcfg)
			if action == "Compile" then
				table.insert(sources, fcfg.name)
			elseif action == "EmbeddedResource" then
				table.insert(embedded, fcfg.name)
			elseif action == "Content" then
				copypairs["$(TARGETDIR)/" .. _MAKE.esc(path.getname(fcfg.name))] = _MAKE.esc(fcfg.name)
			elseif path.getname(fcfg.name):lower() == "app.config" then
				copypairs["$(TARGET).config"] = _MAKE.esc(fcfg.name)
			end
		end

		-- Any assemblies that are on the library search paths should be copied
		-- to $(TARGETDIR) so they can be found at runtime
		local paths = table.translate(prj.libdirs, function(v) return path.join(prj.basedir, v) end)
		paths = table.join({prj.basedir}, paths)
		for _, libname in ipairs(premake.getlinks(prj, "system", "fullpath")) do
			local libdir = os.pathsearch(libname..".dll", unpack(paths))
			if (libdir) then
				local target = "$(TARGETDIR)/" .. _MAKE.esc(path.getname(libname))
				local source = path.getrelative(prj.basedir, path.join(libdir, libname))..".dll"
				copypairs[target] = _MAKE.esc(source)
			end
		end
		
		-- end of preprocessing --


		-- set up the environment
		_p('# %s project makefile autogenerated by Premake', premake.action.current().shortname)
		_p('')
		
		_p('ifndef config')
		_p('  config=%s', _MAKE.esc(prj.configurations[1]:lower()))
		_p('endif')
		_p('')
		
		_p('ifndef verbose')
		_p('  SILENT = @')
		_p('endif')
		_p('')
		
		_p('ifndef CSC')
		_p('  CSC=%s', csc.getcompilervar(prj))
		_p('endif')
		_p('')
		
		_p('ifndef RESGEN')
		_p('  RESGEN=resgen')
		_p('endif')
		_p('')

		-- Platforms aren't support for .NET projects, but I need the ability to match
		-- the buildcfg:platform identifiers with a block of settings. So enumerate the
		-- pairs the same way I do for C/C++ projects, but always use the generic settings
		local platforms = premake.filterplatforms(prj.solution, premake[_OPTIONS.cc].platforms)
		table.insert(platforms, 1, "")

		-- write the configuration blocks
		for cfg in premake.eachconfig(prj) do
			premake.gmake_cs_config(cfg, csc, cfglibs)
		end

		-- set project level values
		_p('# To maintain compatibility with VS.NET, these values must be set at the project level')
		_p('TARGET     := $(TARGETDIR)/%s', _MAKE.esc(prj.buildtarget.name))
		_p('FLAGS      += /t:%s %s', csc.getkind(prj):lower(), table.implode(_MAKE.esc(prj.libdirs), "/lib:", "", " "))
		_p('REFERENCES += %s', table.implode(_MAKE.esc(premake.getlinks(prj, "system", "basename")), "/r:", ".dll", " "))
		_p('')
		
		-- list source files
		_p('SOURCES := \\')
		for _, fname in ipairs(sources) do
			_p('\t%s \\', _MAKE.esc(path.translate(fname)))
		end
		_p('')
		
		_p('EMBEDFILES := \\')
		for _, fname in ipairs(embedded) do
			_p('\t%s \\', getresourcefilename(prj, fname))
		end
		_p('')

		_p('COPYFILES += \\')
		for target, source in pairs(cfgpairs[anycfg]) do
			_p('\t%s \\', target)
		end
		for target, source in pairs(copypairs) do
			_p('\t%s \\', target)
		end
		_p('')

		-- identify the shell type
		_p('SHELLTYPE := msdos')
		_p('ifeq (,$(ComSpec)$(COMSPEC))')
		_p('  SHELLTYPE := posix')
		_p('endif')
		_p('ifeq (/bin,$(findstring /bin,$(SHELL)))')
		_p('  SHELLTYPE := posix')
		_p('endif')
		_p('')

		-- main build rule(s)
		_p('.PHONY: clean prebuild prelink')
		_p('')
		
		_p('all: $(TARGETDIR) $(OBJDIR) prebuild $(EMBEDFILES) $(COPYFILES) prelink $(TARGET)')
		_p('')
		
		_p('$(TARGET): $(SOURCES) $(EMBEDFILES) $(DEPENDS)')
		_p('\t$(SILENT) $(CSC) /nologo /out:$@ $(FLAGS) $(REFERENCES) $(SOURCES) $(patsubst %%,/resource:%%,$(EMBEDFILES))')
		_p('\t$(POSTBUILDCMDS)')
		_p('')

		-- Create destination directories. Can't use $@ for this because it loses the
		-- escaping, causing issues with spaces and parenthesis
		_p('$(TARGETDIR):')
		premake.make_mkdirrule("$(TARGETDIR)")
		
		_p('$(OBJDIR):')
		premake.make_mkdirrule("$(OBJDIR)")

		-- clean target
		_p('clean:')
		_p('\t@echo Cleaning %s', prj.name)
		_p('ifeq (posix,$(SHELLTYPE))')
		_p('\t$(SILENT) rm -f $(TARGETDIR)/%s.* $(COPYFILES)', prj.buildtarget.basename)
		_p('\t$(SILENT) rm -rf $(OBJDIR)')
		_p('else')
		_p('\t$(SILENT) if exist $(subst /,\\\\,$(TARGETDIR)/%s.*) del $(subst /,\\\\,$(TARGETDIR)/%s.*)', prj.buildtarget.basename, prj.buildtarget.basename)
		for target, source in pairs(cfgpairs[anycfg]) do
			_p('\t$(SILENT) if exist $(subst /,\\\\,%s) del $(subst /,\\\\,%s)', target, target)
		end
		for target, source in pairs(copypairs) do
			_p('\t$(SILENT) if exist $(subst /,\\\\,%s) del $(subst /,\\\\,%s)', target, target)
		end
		_p('\t$(SILENT) if exist $(subst /,\\\\,$(OBJDIR)) rmdir /s /q $(subst /,\\\\,$(OBJDIR))')
		_p('endif')
		_p('')

		-- custom build step targets
		_p('prebuild:')
		_p('\t$(PREBUILDCMDS)')
		_p('')
		
		_p('prelink:')
		_p('\t$(PRELINKCMDS)')
		_p('')

		-- per-file rules
		_p('# Per-configuration copied file rules')
		for cfg in premake.eachconfig(prj) do
			_p('ifneq (,$(findstring %s,$(config)))', _MAKE.esc(cfg.name:lower()))
			for target, source in pairs(cfgpairs[cfg]) do
				premake.make_copyrule(source, target)
			end
			_p('endif')
			_p('')
		end
		
		_p('# Copied file rules')
		for target, source in pairs(copypairs) do
			premake.make_copyrule(source, target)
		end

		_p('# Embedded file rules')
		for _, fname in ipairs(embedded) do 
			if path.getextension(fname) == ".resx" then
				_p('%s: %s', getresourcefilename(prj, fname), _MAKE.esc(fname))
				_p('\t$(SILENT) $(RESGEN) $^ $@')
			end
			_p('')
		end
		
	end


--
-- Write a block of configuration settings.
--

	function premake.gmake_cs_config(cfg, csc, cfglibs)
			
		_p('ifneq (,$(findstring %s,$(config)))', _MAKE.esc(cfg.name:lower()))
		_p('  TARGETDIR  := %s', _MAKE.esc(cfg.buildtarget.directory))
		_p('  OBJDIR     := %s', _MAKE.esc(cfg.objectsdir))
		_p('  DEPENDS    := %s', table.concat(_MAKE.esc(premake.getlinks(cfg, "dependencies", "fullpath")), " "))
		_p('  REFERENCES := %s', table.implode(_MAKE.esc(cfglibs[cfg]), "/r:", "", " "))
		_p('  FLAGS      += %s %s', table.implode(cfg.defines, "/d:", "", " "), table.concat(table.join(csc.getflags(cfg), cfg.buildoptions), " "))
		
		_p('  define PREBUILDCMDS')
		if #cfg.prebuildcommands > 0 then
			_p('\t@echo Running pre-build commands')
			_p('\t%s', table.implode(cfg.prebuildcommands, "", "", "\n\t"))
		end
		_p('  endef')
		
		_p('  define PRELINKCMDS')
		if #cfg.prelinkcommands > 0 then
			_p('\t@echo Running pre-link commands')
			_p('\t%s', table.implode(cfg.prelinkcommands, "", "", "\n\t"))
		end
		_p('  endef')
		
		_p('  define POSTBUILDCMDS')
		if #cfg.postbuildcommands > 0 then
			_p('\t@echo Running post-build commands')
			_p('\t%s', table.implode(cfg.postbuildcommands, "", "", "\n\t"))
		end
		_p('  endef')
		
		_p('endif')
		_p('')

	end
-- AMALGAMATE FILE TAIL : /src/actions/make/make_csharp.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/_vstudio.lua
--
-- _vstudio.lua
-- Define the Visual Studio 200x actions.
-- Copyright (c) 2008-2011 Jason Perkins and the Premake project
--

	premake.vstudio = { }
	local vstudio = premake.vstudio


--
-- Map Premake platform identifiers to the Visual Studio versions. Adds the Visual
-- Studio specific "any" and "mixed" to make solution generation easier.
--

	vstudio.platforms = {
		any     = "Any CPU",
		mixed   = "Mixed Platforms",
		Native  = "Win32",
		x86     = "x86",
		x32     = "Win32",
		x64     = "x64",
		PS3     = "PS3",
		Xbox360 = "Xbox 360",
	}



--
-- Returns the architecture identifier for a project.
-- Used by the solutions.
--

	function vstudio.arch(prj)
		if (prj.language == "C#") then
			if (_ACTION < "vs2005") then
				return ".NET"
			else
				return "Any CPU"
			end
		else
			return "Win32"
		end
	end



--
-- Process the solution's list of configurations and platforms, creates a list
-- of build configuration/platform pairs in a Visual Studio compatible format.
--

	function vstudio.buildconfigs(sln)
		local cfgs = { }

		local platforms = premake.filterplatforms(sln, vstudio.platforms, "Native")

		-- Figure out what's in this solution
		local hascpp    = premake.hascppproject(sln)
		local hasdotnet = premake.hasdotnetproject(sln)

		-- "Mixed Platform" solutions are generally those containing both
		-- C/C++ and .NET projects. Starting in VS2010, all .NET solutions
		-- also contain the Mixed Platform option.
		if hasdotnet and (_ACTION > "vs2008" or hascpp) then
			table.insert(platforms, 1, "mixed")
		end

		-- "Any CPU" is added to solutions with .NET projects. Starting in
		-- VS2010, only pure .NET solutions get this option.
		if hasdotnet and (_ACTION < "vs2010" or not hascpp) then
			table.insert(platforms, 1, "any")
		end

		-- In Visual Studio 2010, pure .NET solutions replace the Win32 platform
		-- with x86. In mixed mode solution, x86 is used in addition to Win32.
		if _ACTION > "vs2008" then
			local platforms2010 = { }
			for _, platform in ipairs(platforms) do
				if vstudio.platforms[platform] == "Win32" then
					if hascpp then
						table.insert(platforms2010, platform)
					end
					if hasdotnet then
						table.insert(platforms2010, "x86")
					end
				else
					table.insert(platforms2010, platform)
				end
			end
			platforms = platforms2010
		end


		for _, buildcfg in ipairs(sln.configurations) do
			for _, platform in ipairs(platforms) do
				local entry = { }
				entry.src_buildcfg = buildcfg
				entry.src_platform = platform

				-- PS3 is funky and needs special handling; it's more of a build
				-- configuration than a platform from Visual Studio's point of view.
				-- This has been fixed in VS2010 as it now truly supports 3rd party
				-- platforms, so only do this fixup when not in VS2010
				if platform ~= "PS3" or _ACTION > "vs2008" then
					entry.buildcfg = buildcfg
					entry.platform = vstudio.platforms[platform]
				else
					entry.buildcfg = platform .. " " .. buildcfg
					entry.platform = "Win32"
				end

				-- create a name the way VS likes it
				entry.name = entry.buildcfg .. "|" .. entry.platform

				-- flag the "fake" platforms added for .NET
				entry.isreal = (platform ~= "any" and platform ~= "mixed")

				table.insert(cfgs, entry)
			end
		end

		return cfgs
	end



--
-- Clean Visual Studio files
--

	function vstudio.cleansolution(sln)
		premake.clean.file(sln, "%%.sln")
		premake.clean.file(sln, "%%.suo")
		premake.clean.file(sln, "%%.ncb")
		-- MonoDevelop files
		premake.clean.file(sln, "%%.userprefs")
		premake.clean.file(sln, "%%.usertasks")
	end

	function vstudio.cleanproject(prj)
		local fname = premake.project.getfilename(prj, "%%")

		os.remove(fname .. ".vcproj")
		os.remove(fname .. ".vcproj.user")

		os.remove(fname .. ".vcxproj")
		os.remove(fname .. ".vcxproj.user")
		os.remove(fname .. ".vcxproj.filters")

		os.remove(fname .. ".csproj")
		os.remove(fname .. ".csproj.user")

		os.remove(fname .. ".pidb")
		os.remove(fname .. ".sdf")
	end

	function vstudio.cleantarget(name)
		os.remove(name .. ".pdb")
		os.remove(name .. ".idb")
		os.remove(name .. ".ilk")
		os.remove(name .. ".vshost.exe")
		os.remove(name .. ".exe.manifest")
	end



--
-- Assemble the project file name.
--

	function vstudio.projectfile(prj)
		local pattern
		if prj.language == "C#" then
			pattern = "%%.csproj"
		else
			pattern = iif(_ACTION > "vs2008", "%%.vcxproj", "%%.vcproj")
		end

		local fname = premake.project.getbasename(prj.name, pattern)
		fname = path.join(prj.location, fname)
		return fname
	end


--
-- Returns the Visual Studio tool ID for a given project type.
--

	function vstudio.tool(prj)
		if (prj.language == "C#") then
			return "FAE04EC0-301F-11D3-BF4B-00C04F79EFBC"
		else
			return "8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942"
		end
	end


--
-- Register Visual Studio 2002
--

	newaction {
		trigger         = "vs2002",
		shortname       = "Visual Studio 2002",
		description     = "Generate Microsoft Visual Studio 2002 project files",
		os              = "windows",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib" },

		valid_languages = { "C", "C++", "C#" },

		valid_tools     = {
			cc     = { "msc"   },
			dotnet = { "msnet" },
		},

		onsolution = function(sln)
			premake.generate(sln, "%%.sln", vstudio.sln2002.generate)
		end,

		onproject = function(prj)
			if premake.isdotnetproject(prj) then
				premake.generate(prj, "%%.csproj", vstudio.cs2002.generate)
				premake.generate(prj, "%%.csproj.user", vstudio.cs2002.generate_user)
			else
				premake.generate(prj, "%%.vcproj", vstudio.vc200x.generate)
				premake.generate(prj, "%%.vcproj.user", vstudio.vc200x.generate_user)
			end
		end,

		oncleansolution = premake.vstudio.cleansolution,
		oncleanproject  = premake.vstudio.cleanproject,
		oncleantarget   = premake.vstudio.cleantarget,

		vstudio = {}
	}


--
-- Register Visual Studio 2003
--

	newaction {
		trigger         = "vs2003",
		shortname       = "Visual Studio 2003",
		description     = "Generate Microsoft Visual Studio 2003 project files",
		os              = "windows",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib" },

		valid_languages = { "C", "C++", "C#" },

		valid_tools     = {
			cc     = { "msc"   },
			dotnet = { "msnet" },
		},

		onsolution = function(sln)
			premake.generate(sln, "%%.sln", vstudio.sln2003.generate)
		end,

		onproject = function(prj)
			if premake.isdotnetproject(prj) then
				premake.generate(prj, "%%.csproj", vstudio.cs2002.generate)
				premake.generate(prj, "%%.csproj.user", vstudio.cs2002.generate_user)
			else
				premake.generate(prj, "%%.vcproj", vstudio.vc200x.generate)
				premake.generate(prj, "%%.vcproj.user", vstudio.vc200x.generate_user)
			end
		end,

		oncleansolution = premake.vstudio.cleansolution,
		oncleanproject  = premake.vstudio.cleanproject,
		oncleantarget   = premake.vstudio.cleantarget,

		vstudio = {}
	}


--
-- Register Visual Studio 2005
--

	newaction {
		trigger         = "vs2005",
		shortname       = "Visual Studio 2005",
		description     = "Generate Microsoft Visual Studio 2005 project files",
		os              = "windows",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib" },

		valid_languages = { "C", "C++", "C#" },

		valid_tools     = {
			cc     = { "msc"   },
			dotnet = { "msnet" },
		},

		onsolution = function(sln)
			premake.generate(sln, "%%.sln", vstudio.sln2005.generate)
		end,

		onproject = function(prj)
			if premake.isdotnetproject(prj) then
				premake.generate(prj, "%%.csproj", vstudio.cs2005.generate)
				premake.generate(prj, "%%.csproj.user", vstudio.cs2005.generate_user)
			else
				premake.generate(prj, "%%.vcproj", vstudio.vc200x.generate)
				premake.generate(prj, "%%.vcproj.user", vstudio.vc200x.generate_user)
			end
		end,

		oncleansolution = vstudio.cleansolution,
		oncleanproject  = vstudio.cleanproject,
		oncleantarget   = vstudio.cleantarget,

		vstudio = {
			productVersion  = "8.0.50727",
			solutionVersion = "9",
		}
	}

--
-- Register Visual Studio 2008
--

	newaction {
		trigger         = "vs2008",
		shortname       = "Visual Studio 2008",
		description     = "Generate Microsoft Visual Studio 2008 project files",
		os              = "windows",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib" },

		valid_languages = { "C", "C++", "C#" },

		valid_tools     = {
			cc     = { "msc"   },
			dotnet = { "msnet" },
		},

		onsolution = function(sln)
			premake.generate(sln, "%%.sln", vstudio.sln2005.generate)
		end,

		onproject = function(prj)
			if premake.isdotnetproject(prj) then
				premake.generate(prj, "%%.csproj", vstudio.cs2005.generate)
				premake.generate(prj, "%%.csproj.user", vstudio.cs2005.generate_user)
			else
				premake.generate(prj, "%%.vcproj", vstudio.vc200x.generate)
				premake.generate(prj, "%%.vcproj.user", vstudio.vc200x.generate_user)
			end
		end,

		oncleansolution = vstudio.cleansolution,
		oncleanproject  = vstudio.cleanproject,
		oncleantarget   = vstudio.cleantarget,

		vstudio = {
			productVersion  = "9.0.21022",
			solutionVersion = "10",
			toolsVersion    = "3.5",
		}
	}


--
-- Register Visual Studio 2010
--

	newaction
	{
		trigger         = "vs2010",
		shortname       = "Visual Studio 2010",
		description     = "Generate Microsoft Visual Studio 2010 project files",
		os              = "windows",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib" },

		valid_languages = { "C", "C++", "C#"},

		valid_tools     = {
			cc     = { "msc"   },
			dotnet = { "msnet" },
		},

		onsolution = function(sln)
			premake.generate(sln, "%%.sln", vstudio.sln2005.generate)
		end,

		onproject = function(prj)
			if premake.isdotnetproject(prj) then
				premake.generate(prj, "%%.csproj", vstudio.cs2005.generate)
				premake.generate(prj, "%%.csproj.user", vstudio.cs2005.generate_user)
			else
			premake.generate(prj, "%%.vcxproj", premake.vs2010_vcxproj)
			premake.generate(prj, "%%.vcxproj.user", premake.vs2010_vcxproj_user)
			premake.generate(prj, "%%.vcxproj.filters", vstudio.vc2010.generate_filters)
			end
		end,

		oncleansolution = premake.vstudio.cleansolution,
		oncleanproject  = premake.vstudio.cleanproject,
		oncleantarget   = premake.vstudio.cleantarget,

		vstudio = {
			productVersion  = "8.0.30703",
			solutionVersion = "11",
			targetFramework = "4.0",
			toolsVersion    = "4.0",
		}
	}
-- AMALGAMATE FILE TAIL : /src/actions/vstudio/_vstudio.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs2002_solution.lua
--
-- vs2002_solution.lua
-- Generate a Visual Studio 2002 solution.
-- Copyright (c) 2009-2011 Jason Perkins and the Premake project
--

	premake.vstudio.sln2002 = { }
	local vstudio = premake.vstudio
	local sln2002 = premake.vstudio.sln2002

	function sln2002.generate(sln)
		io.indent = nil -- back to default
		io.eol = '\r\n'

		-- Precompute Visual Studio configurations
		sln.vstudio_configs = premake.vstudio.buildconfigs(sln)

		_p('Microsoft Visual Studio Solution File, Format Version 7.00')
		
		-- Write out the list of project entries
		for prj in premake.solution.eachproject(sln) do
			local projpath = path.translate(path.getrelative(sln.location, vstudio.projectfile(prj)))
			_p('Project("{%s}") = "%s", "%s", "{%s}"', vstudio.tool(prj), prj.name, projpath, prj.uuid)
			_p('EndProject')
		end

		_p('Global')
		_p(1,'GlobalSection(SolutionConfiguration) = preSolution')
		for i, cfgname in ipairs(sln.configurations) do
			_p(2,'ConfigName.%d = %s', i - 1, cfgname)
		end
		_p(1,'EndGlobalSection')

		_p(1,'GlobalSection(ProjectDependencies) = postSolution')
		_p(1,'EndGlobalSection')
		
		_p(1,'GlobalSection(ProjectConfiguration) = postSolution')
		for prj in premake.solution.eachproject(sln) do
			for _, cfgname in ipairs(sln.configurations) do
				_p(2,'{%s}.%s.ActiveCfg = %s|%s', prj.uuid, cfgname, cfgname, vstudio.arch(prj))
				_p(2,'{%s}.%s.Build.0 = %s|%s', prj.uuid, cfgname, cfgname, vstudio.arch(prj))
			end
		end
		_p(1,'EndGlobalSection')
		_p(1,'GlobalSection(ExtensibilityGlobals) = postSolution')
		_p(1,'EndGlobalSection')
		_p(1,'GlobalSection(ExtensibilityAddIns) = postSolution')
		_p(1,'EndGlobalSection')
		
		_p('EndGlobal')
	end
	
-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs2002_solution.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs2002_csproj.lua
--
-- vs2002_csproj.lua
-- Generate a Visual Studio 2002/2003 C# project.
-- Copyright (c) 2009-2011 Jason Perkins and the Premake project
--

	premake.vstudio.cs2002 = { }
	local vstudio = premake.vstudio
	local cs2002 = premake.vstudio.cs2002

	
--
-- Figure out what elements a particular file need in its item block,
-- based on its build action and any related files in the project.
-- 

	local function getelements(prj, action, fname)
	
		if action == "Compile" and fname:endswith(".cs") then
			return "SubTypeCode"
		end

		if action == "EmbeddedResource" and fname:endswith(".resx") then
			-- is there a matching *.cs file?
			local basename = fname:sub(1, -6)
			local testname = path.getname(basename .. ".cs")
			if premake.findfile(prj, testname) then
				return "Dependency", testname
			end
		end
		
		return "None"
	end


--
-- Write out the <Files> element.
--

	function cs2002.Files(prj)
		local tr = premake.project.buildsourcetree(prj)
		premake.tree.traverse(tr, {
			onleaf = function(node)
				local action = premake.dotnet.getbuildaction(node.cfg)
				local fname  = path.translate(premake.esc(node.cfg.name), "\\")
				local elements, dependency = getelements(prj, action, node.path)

				_p(4,'<File')
				_p(5,'RelPath = "%s"', fname)
				_p(5,'BuildAction = "%s"', action)
				if dependency then
					_p(5,'DependentUpon = "%s"', premake.esc(path.translate(dependency, "\\")))
				end
				if elements == "SubTypeCode" then
					_p(5,'SubType = "Code"')
				end
				_p(4,'/>')
			end
		}, false)
	end


--
-- The main function: write the project file.
--

	function cs2002.generate(prj)
		io.eol = "\r\n"
		_p('<VisualStudioProject>')

		_p(1,'<CSHARP')
		_p(2,'ProjectType = "Local"')
		_p(2,'ProductVersion = "%s"', iif(_ACTION == "vs2002", "7.0.9254", "7.10.3077"))
		_p(2,'SchemaVersion = "%s"', iif(_ACTION == "vs2002", "1.0", "2.0"))
		_p(2,'ProjectGuid = "{%s}"', prj.uuid)
		_p(1,'>')

		_p(2,'<Build>')
		
		-- Write out project-wide settings
		_p(3,'<Settings')
		_p(4,'ApplicationIcon = ""')
		_p(4,'AssemblyKeyContainerName = ""')
		_p(4,'AssemblyName = "%s"', prj.buildtarget.basename)
		_p(4,'AssemblyOriginatorKeyFile = ""')
		_p(4,'DefaultClientScript = "JScript"')
		_p(4,'DefaultHTMLPageLayout = "Grid"')
		_p(4,'DefaultTargetSchema = "IE50"')
		_p(4,'DelaySign = "false"')
		if _ACTION == "vs2002" then
			_p(4,'NoStandardLibraries = "false"')
		end
		_p(4,'OutputType = "%s"', premake.dotnet.getkind(prj))
		if _ACTION == "vs2003" then
			_p(4,'PreBuildEvent = ""')
			_p(4,'PostBuildEvent = ""')
		end
		_p(4,'RootNamespace = "%s"', prj.buildtarget.basename)
		if _ACTION == "vs2003" then
			_p(4,'RunPostBuildEvent = "OnBuildSuccess"')
		end
		_p(4,'StartupObject = ""')
		_p(3,'>')

		-- Write out configuration blocks		
		for cfg in premake.eachconfig(prj) do
			_p(4,'<Config')
			_p(5,'Name = "%s"', premake.esc(cfg.name))
			_p(5,'AllowUnsafeBlocks = "%s"', iif(cfg.flags.Unsafe, "true", "false"))
			_p(5,'BaseAddress = "285212672"')
			_p(5,'CheckForOverflowUnderflow = "false"')
			_p(5,'ConfigurationOverrideFile = ""')
			_p(5,'DefineConstants = "%s"', premake.esc(table.concat(cfg.defines, ";")))
			_p(5,'DocumentationFile = ""')
			_p(5,'DebugSymbols = "%s"', iif(cfg.flags.Symbols, "true", "false"))
			_p(5,'FileAlignment = "4096"')
			_p(5,'IncrementalBuild = "false"')
			if _ACTION == "vs2003" then
				_p(5,'NoStdLib = "false"')
				_p(5,'NoWarn = ""')
			end
			_p(5,'Optimize = "%s"', iif(cfg.flags.Optimize or cfg.flags.OptimizeSize or cfg.flags.OptimizeSpeed, "true", "false"))
			_p(5,'OutputPath = "%s"', premake.esc(cfg.buildtarget.directory))
			_p(5,'RegisterForComInterop = "false"')
			_p(5,'RemoveIntegerChecks = "false"')
			_p(5,'TreatWarningsAsErrors = "%s"', iif(cfg.flags.FatalWarnings, "true", "false"))
			_p(5,'WarningLevel = "4"')
			_p(4,'/>')
		end
		_p(3,'</Settings>')

		-- List assembly references
		_p(3,'<References>')
		for _, ref in ipairs(premake.getlinks(prj, "siblings", "object")) do
			_p(4,'<Reference')
			_p(5,'Name = "%s"', ref.buildtarget.basename)
			_p(5,'Project = "{%s}"', ref.uuid)
			_p(5,'Package = "{%s}"', vstudio.tool(ref))
			_p(4,'/>')
		end
		for _, linkname in ipairs(premake.getlinks(prj, "system", "fullpath")) do
			_p(4,'<Reference')
			_p(5,'Name = "%s"', path.getbasename(linkname))
			_p(5,'AssemblyName = "%s"', path.getname(linkname))
			if path.getdirectory(linkname) ~= "." then
				_p(5,'HintPath = "%s"', path.translate(linkname, "\\"))
			end
			_p(4,'/>')
		end
		_p(3,'</References>')
		
		_p(2,'</Build>')

		-- List source files
		_p(2,'<Files>')
		_p(3,'<Include>')
		cs2002.Files(prj)
		_p(3,'</Include>')
		_p(2,'</Files>')
		
		_p(1,'</CSHARP>')
		_p('</VisualStudioProject>')

	end
-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs2002_csproj.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs2002_csproj_user.lua
--
-- vs2002_csproj_user.lua
-- Generate a Visual Studio 2002/2003 C# .user file.
-- Copyright (c) 2009 Jason Perkins and the Premake project
--

	local cs2002 = premake.vstudio.cs2002

	function cs2002.generate_user(prj)
		io.eol = "\r\n"

		_p('<VisualStudioProject>')
		_p(1,'<CSHARP>')
		_p(2,'<Build>')
		
		-- Visual Studio wants absolute paths
		local refpaths = table.translate(prj.libdirs, function(v) return path.getabsolute(prj.location .. "/" .. v) end)
		_p(3,'<Settings ReferencePath = "%s">', path.translate(table.concat(refpaths, ";"), "\\"))
		
		for cfg in premake.eachconfig(prj) do
			_p(4,'<Config')
			_p(5,'Name = "%s"', premake.esc(cfg.name))
			_p(5,'EnableASPDebugging = "false"')
			_p(5,'EnableASPXDebugging = "false"')
			_p(5,'EnableUnmanagedDebugging = "false"')
			_p(5,'EnableSQLServerDebugging = "false"')
			_p(5,'RemoteDebugEnabled = "false"')
			_p(5,'RemoteDebugMachine = ""')
			_p(5,'StartAction = "Project"')
			_p(5,'StartArguments = ""')
			_p(5,'StartPage = ""')
			_p(5,'StartProgram = ""')
			_p(5,'StartURL = ""')
			_p(5,'StartWorkingDirectory = ""')
			_p(5,'StartWithIE = "false"')
			_p(4,'/>')
		end
		
		_p(3,'</Settings>')
		_p(2,'</Build>')
		_p(2,'<OtherProjectSettings')
		_p(3,'CopyProjectDestinationFolder = ""')
		_p(3,'CopyProjectUncPath = ""')
		_p(3,'CopyProjectOption = "0"')
		_p(3,'ProjectView = "ProjectFiles"')
		_p(3,'ProjectTrust = "0"')
		_p(2,'/>')
		
		_p(1,'</CSHARP>')
		_p('</VisualStudioProject>')
		
	end
-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs2002_csproj_user.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs200x_vcproj.lua
--
-- vs200x_vcproj.lua
-- Generate a Visual Studio 2002-2008 C/C++ project.
-- Copyright (c) 2009-2013 Jason Perkins and the Premake project
--


--
-- Set up a namespace for this file
--

	premake.vstudio.vc200x = { }
	local vc200x = premake.vstudio.vc200x
	local tree = premake.tree


--
-- Return the version-specific text for a boolean value.
--

	local function bool(value)
		if (_ACTION < "vs2005") then
			return iif(value, "TRUE", "FALSE")
		else
			return iif(value, "true", "false")
		end
	end


--
-- Return the optimization code.
--

	function vc200x.optimization(cfg)
		local result = 0
		for _, value in ipairs(cfg.flags) do
			if (value == "Optimize") then
				result = 3
			elseif (value == "OptimizeSize") then
				result = 1
			elseif (value == "OptimizeSpeed") then
				result = 2
			end
		end
		return result
	end



--
-- Write the project file header
--

	function vc200x.header(element)
		io.eol = "\r\n"
		_p('<?xml version="1.0" encoding="Windows-1252"?>')
		_p('<%s', element)
		_p(1,'ProjectType="Visual C++"')

		if _ACTION == "vs2002" then
			_p(1,'Version="7.00"')
		elseif _ACTION == "vs2003" then
			_p(1,'Version="7.10"')
		elseif _ACTION == "vs2005" then
			_p(1,'Version="8.00"')
		elseif _ACTION == "vs2008" then
			_p(1,'Version="9.00"')
		end
	end


--
-- Write out the <Configuration> element.
--

	function vc200x.Configuration(name, cfg)
		_p(2,'<Configuration')
		_p(3,'Name="%s"', premake.esc(name))
		_p(3,'OutputDirectory="%s"', premake.esc(cfg.buildtarget.directory))
		_p(3,'IntermediateDirectory="%s"', premake.esc(cfg.objectsdir))

		local cfgtype
		if (cfg.kind == "SharedLib") then
			cfgtype = 2
		elseif (cfg.kind == "StaticLib") then
			cfgtype = 4
		else
			cfgtype = 1
		end
		_p(3,'ConfigurationType="%s"', cfgtype)

		if (cfg.flags.MFC) then
			_p(3, 'UseOfMFC="%d"', iif(cfg.flags.StaticRuntime, 1, 2))
		end				  
		if (cfg.flags.ATL or cfg.flags.StaticATL) then
			_p(3, 'UseOfATL="%d"', iif(cfg.flags.StaticATL, 1, 2))
		end
		_p(3,'CharacterSet="%s"', iif(cfg.flags.Unicode, 1, 2))
		if cfg.flags.Managed then
			_p(3,'ManagedExtensions="1"')
		end
		_p(3,'>')
	end
	

--
-- Write out the <Files> element.
--

	function vc200x.Files(prj)
		local tr = premake.project.buildsourcetree(prj)
		
		tree.traverse(tr, {
			-- folders are handled at the internal nodes
			onbranchenter = function(node, depth)
				_p(depth, '<Filter')
				_p(depth, '\tName="%s"', node.name)
				_p(depth, '\tFilter=""')
				_p(depth, '\t>')
			end,

			onbranchexit = function(node, depth)
				_p(depth, '</Filter>')
			end,

			-- source files are handled at the leaves
			onleaf = function(node, depth)
				local fname = node.cfg.name
				
				_p(depth, '<File')
				_p(depth, '\tRelativePath="%s"', path.translate(fname, "\\"))
				_p(depth, '\t>')
				depth = depth + 1

				-- handle file configuration stuff. This needs to be cleaned up and simplified.
				-- configurations are cached, so this isn't as bad as it looks
				for _, cfginfo in ipairs(prj.solution.vstudio_configs) do
					if cfginfo.isreal then
						local cfg = premake.getconfig(prj, cfginfo.src_buildcfg, cfginfo.src_platform)
						
						local usePCH = (not prj.flags.NoPCH and prj.pchsource == node.cfg.name)
						local isSourceCode = path.iscppfile(fname)
						local needsCompileAs = (path.iscfile(fname) ~= premake.project.iscproject(prj))
						
						if usePCH or (isSourceCode and needsCompileAs) then
							_p(depth, '<FileConfiguration')
							_p(depth, '\tName="%s"', cfginfo.name)
							_p(depth, '\t>')
							_p(depth, '\t<Tool')
							_p(depth, '\t\tName="%s"', iif(cfg.system == "Xbox360", 
							                                 "VCCLX360CompilerTool", 
							                                 "VCCLCompilerTool"))
							if needsCompileAs then
								_p(depth, '\t\tCompileAs="%s"', iif(path.iscfile(fname), 1, 2))
							end
							
							if usePCH then
								if cfg.system == "PS3" then
									local options = table.join(premake.snc.getcflags(cfg), 
									                           premake.snc.getcxxflags(cfg), 
									                           cfg.buildoptions)
									options = table.concat(options, " ");
									options = options .. ' --create_pch="$(IntDir)/$(TargetName).pch"'			                    
									_p(depth, '\t\tAdditionalOptions="%s"', premake.esc(options))
								else
									_p(depth, '\t\tUsePrecompiledHeader="1"')
								end
							end

							_p(depth, '\t/>')
							_p(depth, '</FileConfiguration>')
						end

					end
				end

				depth = depth - 1
				_p(depth, '</File>')
			end,
		}, false, 2)

	end

	
--
-- Write out the <Platforms> element; ensures that each target platform
-- is listed only once. Skips over .NET's pseudo-platforms (like "Any CPU").
--

	function vc200x.Platforms(prj)
		local used = { }
		_p(1,'<Platforms>')
		for _, cfg in ipairs(prj.solution.vstudio_configs) do
			if cfg.isreal and not table.contains(used, cfg.platform) then
				table.insert(used, cfg.platform)
				_p(2,'<Platform')
				_p(3,'Name="%s"', cfg.platform)
				_p(2,'/>')
			end
		end
		_p(1,'</Platforms>')
	end


--
-- Return the debugging symbols level for a configuration.
--

	function vc200x.Symbols(cfg)
		if (not cfg.flags.Symbols) then
			return 0
		else
			-- Edit-and-continue does't work for some configurations
			if cfg.flags.NoEditAndContinue or 
			   vc200x.optimization(cfg) ~= 0 or 
			   cfg.flags.Managed or 
			   cfg.platform == "x64" then
				return 3
			else
				return 4
			end
		end
	end


--
-- Compiler block for Windows and XBox360 platforms.
--

	function vc200x.VCCLCompilerTool(cfg)
		_p(3,'<Tool')
		_p(4,'Name="%s"', iif(cfg.platform ~= "Xbox360", "VCCLCompilerTool", "VCCLX360CompilerTool"))
		
		if #cfg.buildoptions > 0 then
			_p(4,'AdditionalOptions="%s"', table.concat(premake.esc(cfg.buildoptions), " "))
		end
		
		_p(4,'Optimization="%s"', vc200x.optimization(cfg))
		
		if cfg.flags.NoFramePointer then
			_p(4,'OmitFramePointers="%s"', bool(true))
		end
		
		if #cfg.includedirs > 0 then
			_p(4,'AdditionalIncludeDirectories="%s"', premake.esc(path.translate(table.concat(cfg.includedirs, ";"), '\\')))
		end
		
		if #cfg.defines > 0 then
			_p(4,'PreprocessorDefinitions="%s"', premake.esc(table.concat(cfg.defines, ";")))
		end
		
		if premake.config.isdebugbuild(cfg) and not cfg.flags.NoMinimalRebuild and not cfg.flags.Managed then
			_p(4,'MinimalRebuild="%s"', bool(true))
		end
		
		if cfg.flags.NoExceptions then
			_p(4,'ExceptionHandling="%s"', iif(_ACTION < "vs2005", "FALSE", 0))
		elseif cfg.flags.SEH and _ACTION > "vs2003" then
			_p(4,'ExceptionHandling="2"')
		end
		
		if vc200x.optimization(cfg) == 0 and not cfg.flags.Managed then
			_p(4,'BasicRuntimeChecks="3"')
		end
		if vc200x.optimization(cfg) ~= 0 then
			_p(4,'StringPooling="%s"', bool(true))
		end
		
		local runtime
		if premake.config.isdebugbuild(cfg) then
			runtime = iif(cfg.flags.StaticRuntime, 1, 3)
		else
			runtime = iif(cfg.flags.StaticRuntime, 0, 2)
		end
		_p(4,'RuntimeLibrary="%s"', runtime)

		_p(4,'EnableFunctionLevelLinking="%s"', bool(true))

		if _ACTION > "vs2003" and cfg.platform ~= "Xbox360" and cfg.platform ~= "x64" then
			if cfg.flags.EnableSSE then
				_p(4,'EnableEnhancedInstructionSet="1"')
			elseif cfg.flags.EnableSSE2 then
				_p(4,'EnableEnhancedInstructionSet="2"')
			end
		end
	
		if _ACTION < "vs2005" then
			if cfg.flags.FloatFast then
				_p(4,'ImproveFloatingPointConsistency="%s"', bool(false))
			elseif cfg.flags.FloatStrict then
				_p(4,'ImproveFloatingPointConsistency="%s"', bool(true))
			end
		else
			if cfg.flags.FloatFast then
				_p(4,'FloatingPointModel="2"')
			elseif cfg.flags.FloatStrict then
				_p(4,'FloatingPointModel="1"')
			end
		end
		
		if _ACTION < "vs2005" and not cfg.flags.NoRTTI then
			_p(4,'RuntimeTypeInfo="%s"', bool(true))
		elseif _ACTION > "vs2003" and cfg.flags.NoRTTI and not cfg.flags.Managed then
			_p(4,'RuntimeTypeInfo="%s"', bool(false))
		end
		
		if cfg.flags.NativeWChar then
			_p(4,'TreatWChar_tAsBuiltInType="%s"', bool(true))
		elseif cfg.flags.NoNativeWChar then
			_p(4,'TreatWChar_tAsBuiltInType="%s"', bool(false))
		end
		
		if not cfg.flags.NoPCH and cfg.pchheader then
			_p(4,'UsePrecompiledHeader="%s"', iif(_ACTION < "vs2005", 3, 2))
			_p(4,'PrecompiledHeaderThrough="%s"', cfg.pchheader)
		else
			_p(4,'UsePrecompiledHeader="%s"', iif(_ACTION > "vs2003" or cfg.flags.NoPCH, 0, 2))
		end
		
		_p(4,'WarningLevel="%s"', iif(cfg.flags.ExtraWarnings, 4, 3))
		
		if cfg.flags.FatalWarnings then
			_p(4,'WarnAsError="%s"', bool(true))
		end
		
		if _ACTION < "vs2008" and not cfg.flags.Managed then
			_p(4,'Detect64BitPortabilityProblems="%s"', bool(not cfg.flags.No64BitChecks))
		end
		
		_p(4,'ProgramDataBaseFileName="$(OutDir)\\%s.pdb"', path.getbasename(cfg.buildtarget.name))
		_p(4,'DebugInformationFormat="%s"', vc200x.Symbols(cfg))
		if cfg.language == "C" then
			_p(4, 'CompileAs="1"')
		end
		_p(3,'/>')
	end
	
	

--
-- Linker block for Windows and Xbox 360 platforms.
--

	function vc200x.VCLinkerTool(cfg)
		_p(3,'<Tool')
		if cfg.kind ~= "StaticLib" then
			_p(4,'Name="%s"', iif(cfg.platform ~= "Xbox360", "VCLinkerTool", "VCX360LinkerTool"))
			
			if cfg.flags.NoImportLib then
				_p(4,'IgnoreImportLibrary="%s"', bool(true))
			end
			
			if #cfg.linkoptions > 0 then
				_p(4,'AdditionalOptions="%s"', table.concat(premake.esc(cfg.linkoptions), " "))
			end
			
			if #cfg.links > 0 then
				_p(4,'AdditionalDependencies="%s"', table.concat(premake.getlinks(cfg, "all", "fullpath"), " "))
			end
			
			_p(4,'OutputFile="$(OutDir)\\%s"', cfg.buildtarget.name)

			_p(4,'LinkIncremental="%s"', 
				iif(premake.config.isincrementallink(cfg) , 2, 1))
			
			_p(4,'AdditionalLibraryDirectories="%s"', table.concat(premake.esc(path.translate(cfg.libdirs, '\\')) , ";"))
			
			local deffile = premake.findfile(cfg, ".def")
			if deffile then
				_p(4,'ModuleDefinitionFile="%s"', deffile)
			end
			
			if cfg.flags.NoManifest then
				_p(4,'GenerateManifest="%s"', bool(false))
			end
			
			_p(4,'GenerateDebugInformation="%s"', bool(vc200x.Symbols(cfg) ~= 0))
			
			if vc200x.Symbols(cfg) ~= 0 then
				_p(4,'ProgramDataBaseFileName="$(OutDir)\\%s.pdb"', path.getbasename(cfg.buildtarget.name))
			end
			
			_p(4,'SubSystem="%s"', iif(cfg.kind == "ConsoleApp", 1, 2))
			
			if vc200x.optimization(cfg) ~= 0 then
				_p(4,'OptimizeReferences="2"')
				_p(4,'EnableCOMDATFolding="2"')
			end
			
			if (cfg.kind == "ConsoleApp" or cfg.kind == "WindowedApp") and not cfg.flags.WinMain then
				_p(4,'EntryPointSymbol="mainCRTStartup"')
			end
			
			if cfg.kind == "SharedLib" then
				local implibname = cfg.linktarget.fullpath
				_p(4,'ImportLibrary="%s"', iif(cfg.flags.NoImportLib, cfg.objectsdir .. "\\" .. path.getname(implibname), implibname))
			end
			
			_p(4,'TargetMachine="%d"', iif(cfg.platform == "x64", 17, 1))
		
		else
			_p(4,'Name="VCLibrarianTool"')
		
			if #cfg.links > 0 then
				_p(4,'AdditionalDependencies="%s"', table.concat(premake.getlinks(cfg, "all", "fullpath"), " "))
			end
		
			_p(4,'OutputFile="$(OutDir)\\%s"', cfg.buildtarget.name)

			if #cfg.libdirs > 0 then
				_p(4,'AdditionalLibraryDirectories="%s"', premake.esc(path.translate(table.concat(cfg.libdirs , ";"))))
			end

			local addlOptions = {}
			if cfg.platform == "x32" then
				table.insert(addlOptions, "/MACHINE:X86")
			elseif cfg.platform == "x64" then
				table.insert(addlOptions, "/MACHINE:X64")
			end
			addlOptions = table.join(addlOptions, cfg.linkoptions)
			if #addlOptions > 0 then
				_p(4,'AdditionalOptions="%s"', table.concat(premake.esc(addlOptions), " "))
			end
		end
		
		_p(3,'/>')
	end
	
	
--
-- Compiler and linker blocks for the PS3 platform, which uses Sony's SNC.
--

	function vc200x.VCCLCompilerTool_PS3(cfg)
		_p(3,'<Tool')
		_p(4,'Name="VCCLCompilerTool"')

		local buildoptions = table.join(premake.snc.getcflags(cfg), premake.snc.getcxxflags(cfg), cfg.buildoptions)
		if not cfg.flags.NoPCH and cfg.pchheader then
			_p(4,'UsePrecompiledHeader="%s"', iif(_ACTION < "vs2005", 3, 2))
			_p(4,'PrecompiledHeaderThrough="%s"', path.getname(cfg.pchheader))
			table.insert(buildoptions, '--use_pch="$(IntDir)/$(TargetName).pch"')
		else
			_p(4,'UsePrecompiledHeader="%s"', iif(_ACTION > "vs2003" or cfg.flags.NoPCH, 0, 2))
		end
		_p(4,'AdditionalOptions="%s"', premake.esc(table.concat(buildoptions, " ")))

		if #cfg.includedirs > 0 then
			_p(4,'AdditionalIncludeDirectories="%s"', premake.esc(path.translate(table.concat(cfg.includedirs, ";"), '\\')))
		end

		if #cfg.defines > 0 then
			_p(4,'PreprocessorDefinitions="%s"', table.concat(premake.esc(cfg.defines), ";"))
		end

		_p(4,'ProgramDataBaseFileName="$(OutDir)\\%s.pdb"', path.getbasename(cfg.buildtarget.name))
		_p(4,'DebugInformationFormat="0"')
		_p(4,'CompileAs="0"')
		_p(3,'/>')
	end


	function vc200x.VCLinkerTool_PS3(cfg)
		_p(3,'<Tool')
		if cfg.kind ~= "StaticLib" then
			_p(4,'Name="VCLinkerTool"')
			
			local buildoptions = table.join(premake.snc.getldflags(cfg), cfg.linkoptions)
			if #buildoptions > 0 then
				_p(4,'AdditionalOptions="%s"', premake.esc(table.concat(buildoptions, " ")))
			end
			
			if #cfg.links > 0 then
				_p(4,'AdditionalDependencies="%s"', table.concat(premake.getlinks(cfg, "all", "fullpath"), " "))
			end
			
			_p(4,'OutputFile="$(OutDir)\\%s"', cfg.buildtarget.name)
			_p(4,'LinkIncremental="0"')
			_p(4,'AdditionalLibraryDirectories="%s"', table.concat(premake.esc(path.translate(cfg.libdirs, '\\')) , ";"))
			_p(4,'GenerateManifest="%s"', bool(false))
			_p(4,'ProgramDatabaseFile=""')
			_p(4,'RandomizedBaseAddress="1"')
			_p(4,'DataExecutionPrevention="0"')			
		else
			_p(4,'Name="VCLibrarianTool"')

			local buildoptions = table.join(premake.snc.getldflags(cfg), cfg.linkoptions)
			if #buildoptions > 0 then
				_p(4,'AdditionalOptions="%s"', premake.esc(table.concat(buildoptions, " ")))
			end
		
			if #cfg.links > 0 then
				_p(4,'AdditionalDependencies="%s"', table.concat(premake.getlinks(cfg, "all", "fullpath"), " "))
			end
		
			_p(4,'OutputFile="$(OutDir)\\%s"', cfg.buildtarget.name)

			if #cfg.libdirs > 0 then
				_p(4,'AdditionalLibraryDirectories="%s"', premake.esc(path.translate(table.concat(cfg.libdirs , ";"))))
			end
		end
		
		_p(3,'/>')
	end
	


--
-- Resource compiler block.
--

	function vc200x.VCResourceCompilerTool(cfg)
		_p(3,'<Tool')
		_p(4,'Name="VCResourceCompilerTool"')

		if #cfg.resoptions > 0 then
			_p(4,'AdditionalOptions="%s"', table.concat(premake.esc(cfg.resoptions), " "))
		end

		if #cfg.defines > 0 or #cfg.resdefines > 0 then
			_p(4,'PreprocessorDefinitions="%s"', table.concat(premake.esc(table.join(cfg.defines, cfg.resdefines)), ";"))
		end

		if #cfg.includedirs > 0 or #cfg.resincludedirs > 0 then
			local dirs = table.join(cfg.includedirs, cfg.resincludedirs)
			_p(4,'AdditionalIncludeDirectories="%s"', premake.esc(path.translate(table.concat(dirs, ";"), '\\')))
		end

		_p(3,'/>')
	end
	
	

--
-- Manifest block.
--

	function vc200x.VCManifestTool(cfg)
		-- locate all manifest files
		local manifests = { }
		for _, fname in ipairs(cfg.files) do
			if path.getextension(fname) == ".manifest" then
				table.insert(manifests, fname)
			end
		end
		
		_p(3,'<Tool')
		_p(4,'Name="VCManifestTool"')
		if #manifests > 0 then
			_p(4,'AdditionalManifestFiles="%s"', premake.esc(table.concat(manifests, ";")))
		end
		_p(3,'/>')
	end



--
-- VCMIDLTool block
--

	function vc200x.VCMIDLTool(cfg)
		_p(3,'<Tool')
		_p(4,'Name="VCMIDLTool"')
		if cfg.platform == "x64" then
			_p(4,'TargetEnvironment="3"')
		end
		_p(3,'/>')
	end

	

--
-- Write out a custom build steps block.
--

	function vc200x.buildstepsblock(name, steps)
		_p(3,'<Tool')
		_p(4,'Name="%s"', name)
		if #steps > 0 then
			_p(4,'CommandLine="%s"', premake.esc(table.implode(steps, "", "", "\r\n")))
		end
		_p(3,'/>')
	end



--
-- Map project tool blocks to handler functions. Unmapped blocks will output
-- an empty <Tool> element.
--

	vc200x.toolmap = 
	{
		VCCLCompilerTool       = vc200x.VCCLCompilerTool,
		VCCLCompilerTool_PS3   = vc200x.VCCLCompilerTool_PS3,
		VCLinkerTool           = vc200x.VCLinkerTool,
		VCLinkerTool_PS3       = vc200x.VCLinkerTool_PS3,
		VCManifestTool         = vc200x.VCManifestTool,
		VCMIDLTool             = vc200x.VCMIDLTool,
		VCResourceCompilerTool = vc200x.VCResourceCompilerTool,
		VCPreBuildEventTool    = function(cfg) vc200x.buildstepsblock("VCPreBuildEventTool", cfg.prebuildcommands) end,
		VCPreLinkEventTool     = function(cfg) vc200x.buildstepsblock("VCPreLinkEventTool", cfg.prelinkcommands) end,
		VCPostBuildEventTool   = function(cfg) vc200x.buildstepsblock("VCPostBuildEventTool", cfg.postbuildcommands) end,
	}


--
-- Return a list of sections for a particular Visual Studio version and target platform.
--

	local function getsections(version, platform)
		if version == "vs2002" then
			return {
				"VCCLCompilerTool",
				"VCCustomBuildTool",
				"VCLinkerTool",
				"VCMIDLTool",
				"VCPostBuildEventTool",
				"VCPreBuildEventTool",
				"VCPreLinkEventTool",
				"VCResourceCompilerTool",
				"VCWebServiceProxyGeneratorTool",
				"VCWebDeploymentTool"
			}
		end
		if version == "vs2003" then
			return {
				"VCCLCompilerTool",
				"VCCustomBuildTool",
				"VCLinkerTool",
				"VCMIDLTool",
				"VCPostBuildEventTool",
				"VCPreBuildEventTool",
				"VCPreLinkEventTool",
				"VCResourceCompilerTool",
				"VCWebServiceProxyGeneratorTool",
				"VCXMLDataGeneratorTool",
				"VCWebDeploymentTool",
				"VCManagedWrapperGeneratorTool",
				"VCAuxiliaryManagedWrapperGeneratorTool"
			}
		end
		if platform == "Xbox360" then
			return {
				"VCPreBuildEventTool",
				"VCCustomBuildTool",
				"VCXMLDataGeneratorTool",
				"VCWebServiceProxyGeneratorTool",
				"VCMIDLTool",
				"VCCLCompilerTool",
				"VCManagedResourceCompilerTool",
				"VCResourceCompilerTool",
				"VCPreLinkEventTool",
				"VCLinkerTool",
				"VCALinkTool",
				"VCX360ImageTool",
				"VCBscMakeTool",
				"VCX360DeploymentTool",
				"VCPostBuildEventTool",
				"DebuggerTool",
			}
		end
		if platform == "PS3" then
			return {
				"VCPreBuildEventTool",
				"VCCustomBuildTool",
				"VCXMLDataGeneratorTool",
				"VCWebServiceProxyGeneratorTool",
				"VCMIDLTool",
				"VCCLCompilerTool_PS3",
				"VCManagedResourceCompilerTool",
				"VCResourceCompilerTool",
				"VCPreLinkEventTool",
				"VCLinkerTool_PS3",
				"VCALinkTool",
				"VCManifestTool",
				"VCXDCMakeTool",
				"VCBscMakeTool",
				"VCFxCopTool",
				"VCAppVerifierTool",
				"VCWebDeploymentTool",
				"VCPostBuildEventTool"
			}	
		else
			return {	
				"VCPreBuildEventTool",
				"VCCustomBuildTool",
				"VCXMLDataGeneratorTool",
				"VCWebServiceProxyGeneratorTool",
				"VCMIDLTool",
				"VCCLCompilerTool",
				"VCManagedResourceCompilerTool",
				"VCResourceCompilerTool",
				"VCPreLinkEventTool",
				"VCLinkerTool",
				"VCALinkTool",
				"VCManifestTool",
				"VCXDCMakeTool",
				"VCBscMakeTool",
				"VCFxCopTool",
				"VCAppVerifierTool",
				"VCWebDeploymentTool",
				"VCPostBuildEventTool"
			}	
		end
	end



--
-- The main function: write the project file.
--

	function vc200x.generate(prj)
		vc200x.header('VisualStudioProject')
		
		_p(1,'Name="%s"', premake.esc(prj.name))
		_p(1,'ProjectGUID="{%s}"', prj.uuid)
		if _ACTION > "vs2003" then
			_p(1,'RootNamespace="%s"', prj.name)
		end
		_p(1,'Keyword="%s"', iif(prj.flags.Managed, "ManagedCProj", "Win32Proj"))
		_p(1,'>')

		-- list the target platforms
		vc200x.Platforms(prj)

		if _ACTION > "vs2003" then
			_p(1,'<ToolFiles>')
			_p(1,'</ToolFiles>')
		end

		_p(1,'<Configurations>')
		for _, cfginfo in ipairs(prj.solution.vstudio_configs) do
			if cfginfo.isreal then
				local cfg = premake.getconfig(prj, cfginfo.src_buildcfg, cfginfo.src_platform)
		
				-- Start a configuration
				vc200x.Configuration(cfginfo.name, cfg)
				for _, block in ipairs(getsections(_ACTION, cfginfo.src_platform)) do
				
					if vc200x.toolmap[block] then
						vc200x.toolmap[block](cfg)

					-- Xbox 360 custom sections --
					elseif block == "VCX360DeploymentTool" then
						_p(3,'<Tool')
						_p(4,'Name="VCX360DeploymentTool"')
						_p(4,'DeploymentType="0"')
						if #cfg.deploymentoptions > 0 then
							_p(4,'AdditionalOptions="%s"', table.concat(premake.esc(cfg.deploymentoptions), " "))
						end
						_p(3,'/>')

					elseif block == "VCX360ImageTool" then
						_p(3,'<Tool')
						_p(4,'Name="VCX360ImageTool"')
						if #cfg.imageoptions > 0 then
							_p(4,'AdditionalOptions="%s"', table.concat(premake.esc(cfg.imageoptions), " "))
						end
						if cfg.imagepath ~= nil then
							_p(4,'OutputFileName="%s"', premake.esc(path.translate(cfg.imagepath)))
						end
						_p(3,'/>')
						
					elseif block == "DebuggerTool" then
						_p(3,'<DebuggerTool')
						_p(3,'/>')
					
					-- End Xbox 360 custom sections --
						
					else
						_p(3,'<Tool')
						_p(4,'Name="%s"', block)
						_p(3,'/>')
					end
					
				end

				_p(2,'</Configuration>')
			end
		end
		_p(1,'</Configurations>')

		_p(1,'<References>')
		_p(1,'</References>')
		
		_p(1,'<Files>')
		vc200x.Files(prj)
		_p(1,'</Files>')
		
		_p(1,'<Globals>')
		_p(1,'</Globals>')
		_p('</VisualStudioProject>')
	end



-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs200x_vcproj.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs200x_vcproj_user.lua
--
-- vs200x_vcproj_user.lua
-- Generate a Visual Studio 2002-2008 C/C++ project .user file
-- Copyright (c) 2011 Jason Perkins and the Premake project
--


--
-- Set up namespaces
--

	local vc200x = premake.vstudio.vc200x


--
-- Generate the .vcproj.user file
--

	function vc200x.generate_user(prj)
		vc200x.header('VisualStudioUserFile')
		
		_p(1,'ShowAllFiles="false"')
		_p(1,'>')
		_p(1,'<Configurations>')
		
		for _, cfginfo in ipairs(prj.solution.vstudio_configs) do
			if cfginfo.isreal then
				local cfg = premake.getconfig(prj, cfginfo.src_buildcfg, cfginfo.src_platform)
		
				_p(2,'<Configuration')
				_p(3,'Name="%s"', premake.esc(cfginfo.name))
				_p(3,'>')
				
				vc200x.debugdir(cfg)
				
				_p(2,'</Configuration>')
			end
		end		
		
		_p(1,'</Configurations>')
		_p('</VisualStudioUserFile>')
	end


--
-- Output the debug settings element
--
	function vc200x.environmentargs(cfg)
		if cfg.environmentargs and #cfg.environmentargs > 0 then
			_p(4,'Environment="%s"', string.gsub(table.concat(cfg.environmentargs, "&#x0A;"),'"','&quot;'))
			if cfg.flags.EnvironmentArgsDontMerge then
				_p(4,'EnvironmentMerge="false"')
			end
		end
	end
	
	function vc200x.debugdir(cfg)
		_p(3,'<DebugSettings')
		
		if cfg.debugdir then
			_p(4,'WorkingDirectory="%s"', path.translate(cfg.debugdir, '\\'))
		end
		
		if #cfg.debugargs > 0 then
			_p(4,'CommandArguments="%s"', table.concat(cfg.debugargs, " "))
		end

			vc200x.environmentargs(cfg)
				
		_p(3,'/>')
	end
-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs200x_vcproj_user.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs2003_solution.lua
--
-- vs2003_solution.lua
-- Generate a Visual Studio 2003 solution.
-- Copyright (c) 2009-2011 Jason Perkins and the Premake project
--

	premake.vstudio.sln2003 = { }
	local vstudio = premake.vstudio
	local sln2003 = premake.vstudio.sln2003


	function sln2003.generate(sln)
		io.indent = nil -- back to default
		io.eol = '\r\n'

		-- Precompute Visual Studio configurations
		sln.vstudio_configs = premake.vstudio.buildconfigs(sln)

		_p('Microsoft Visual Studio Solution File, Format Version 8.00')

		-- Write out the list of project entries
		for prj in premake.solution.eachproject(sln) do
			local projpath = path.translate(path.getrelative(sln.location, vstudio.projectfile(prj)))
			_p('Project("{%s}") = "%s", "%s", "{%s}"', vstudio.tool(prj), prj.name, projpath, prj.uuid)
			
			local deps = premake.getdependencies(prj)
			if #deps > 0 then
				_p('\tProjectSection(ProjectDependencies) = postProject')
				for _, dep in ipairs(deps) do
					_p('\t\t{%s} = {%s}', dep.uuid, dep.uuid)
				end
				_p('\tEndProjectSection')
			end
			
			_p('EndProject')
		end

		_p('Global')
		_p('\tGlobalSection(SolutionConfiguration) = preSolution')
		for _, cfgname in ipairs(sln.configurations) do
			_p('\t\t%s = %s', cfgname, cfgname)
		end
		_p('\tEndGlobalSection')
		
		_p('\tGlobalSection(ProjectDependencies) = postSolution')
		_p('\tEndGlobalSection')
		
		_p('\tGlobalSection(ProjectConfiguration) = postSolution')
		for prj in premake.solution.eachproject(sln) do
			for _, cfgname in ipairs(sln.configurations) do
				_p('\t\t{%s}.%s.ActiveCfg = %s|%s', prj.uuid, cfgname, cfgname, vstudio.arch(prj))
				_p('\t\t{%s}.%s.Build.0 = %s|%s', prj.uuid, cfgname, cfgname, vstudio.arch(prj))
			end
		end
		_p('\tEndGlobalSection')

		_p('\tGlobalSection(ExtensibilityGlobals) = postSolution')
		_p('\tEndGlobalSection')
		_p('\tGlobalSection(ExtensibilityAddIns) = postSolution')
		_p('\tEndGlobalSection')
		
		_p('EndGlobal')
	end
-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs2003_solution.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs2005_solution.lua
--
-- vs2005_solution.lua
-- Generate a Visual Studio 2005-2010 solution.
-- Copyright (c) 2009-2011 Jason Perkins and the Premake project
--

	premake.vstudio.sln2005 = { }
	local vstudio = premake.vstudio
	local sln2005 = premake.vstudio.sln2005


	function sln2005.generate(sln)
		io.indent = nil -- back to default
		io.eol = '\r\n'

		-- Precompute Visual Studio configurations
		sln.vstudio_configs = premake.vstudio.buildconfigs(sln)

		-- Mark the file as Unicode
		_p('\239\187\191')

		sln2005.header(sln)

		for prj in premake.solution.eachproject(sln) do
			sln2005.project(prj)
		end

		_p('Global')
		sln2005.platforms(sln)
		sln2005.project_platforms(sln)
		sln2005.properties(sln)
		_p('EndGlobal')
	end


--
-- Generate the solution header
--

	function sln2005.header(sln)
		local action = premake.action.current()
		_p('Microsoft Visual Studio Solution File, Format Version %d.00', action.vstudio.solutionVersion)
		_p('# Visual Studio %s', _ACTION:sub(3))
	end


--
-- Write out an entry for a project
--

	function sln2005.project(prj)
		-- Build a relative path from the solution file to the project file
		local projpath = path.translate(path.getrelative(prj.solution.location, vstudio.projectfile(prj)), "\\")

		_p('Project("{%s}") = "%s", "%s", "{%s}"', vstudio.tool(prj), prj.name, projpath, prj.uuid)
		sln2005.projectdependencies(prj)
		_p('EndProject')
	end


--
-- Write out the list of project dependencies for a particular project.
--

	function sln2005.projectdependencies(prj)
		local deps = premake.getdependencies(prj)
		if #deps > 0 then
			_p('\tProjectSection(ProjectDependencies) = postProject')
			for _, dep in ipairs(deps) do
				_p('\t\t{%s} = {%s}', dep.uuid, dep.uuid)
			end
			_p('\tEndProjectSection')
		end
	end


--
-- Write out the contents of the SolutionConfigurationPlatforms section, which
-- lists all of the configuration/platform pairs that exist in the solution.
--

	function sln2005.platforms(sln)
		_p('\tGlobalSection(SolutionConfigurationPlatforms) = preSolution')
		for _, cfg in ipairs(sln.vstudio_configs) do
			_p('\t\t%s = %s', cfg.name, cfg.name)
		end
		_p('\tEndGlobalSection')
	end

--
-- Write a single solution to project mapping (ActiveCfg and Build.0 lines)
--

	function sln2005.project_platforms_sln2prj_mapping(sln, prj, cfg, mapped)
		_p('\t\t{%s}.%s.ActiveCfg = %s|%s', prj.uuid, cfg.name, cfg.buildcfg, mapped)
		if mapped == cfg.platform or cfg.platform == "Mixed Platforms" then
			_p('\t\t{%s}.%s.Build.0 = %s|%s',  prj.uuid, cfg.name, cfg.buildcfg, mapped)
		end
	end

--
-- Write out the contents of the ProjectConfigurationPlatforms section, which maps
-- the configuration/platform pairs into each project of the solution.
--

	function sln2005.project_platforms(sln)
		_p('\tGlobalSection(ProjectConfigurationPlatforms) = postSolution')
		for prj in premake.solution.eachproject(sln) do
			for _, cfg in ipairs(sln.vstudio_configs) do

				-- .NET projects always map to the "Any CPU" platform (for now, at
				-- least). For C++, "Any CPU" and "Mixed Platforms" map to the first
				-- C++ compatible target platform in the solution list.
				local mapped
				if premake.isdotnetproject(prj) then
					mapped = "Any CPU"
				else
					if cfg.platform == "Any CPU" or cfg.platform == "Mixed Platforms" then
						mapped = sln.vstudio_configs[3].platform
					else
						mapped = cfg.platform
					end
				end
				sln2005.project_platforms_sln2prj_mapping(sln, prj, cfg, mapped)
			end
		end
		_p('\tEndGlobalSection')
	end



--
-- Write out contents of the SolutionProperties section; currently unused.
--

	function sln2005.properties(sln)
		_p('\tGlobalSection(SolutionProperties) = preSolution')
		_p('\t\tHideSolutionNode = FALSE')
		_p('\tEndGlobalSection')
	end
-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs2005_solution.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs2005_csproj.lua
--
-- vs2005_csproj.lua
-- Generate a Visual Studio 2005/2008 C# project.
-- Copyright (c) 2009-2011 Jason Perkins and the Premake project
--

--
-- Set up namespaces
--

	premake.vstudio.cs2005 = { }
	local vstudio = premake.vstudio
	local cs2005  = premake.vstudio.cs2005


--
-- Figure out what elements a particular source code file need in its item
-- block, based on its build action and any related files in the project.
--

	local function getelements(prj, action, fname)

		if action == "Compile" and fname:endswith(".cs") then
			if fname:endswith(".Designer.cs") then
				-- is there a matching *.cs file?
				local basename = fname:sub(1, -13)
				local testname = basename .. ".cs"
				if premake.findfile(prj, testname) then
					return "Dependency", testname
				end
				-- is there a matching *.resx file?
				testname = basename .. ".resx"
				if premake.findfile(prj, testname) then
					return "AutoGen", testname
				end
			elseif fname:endswith(".xaml.cs") then
				-- is there a matching *.cs file?
				local basename = fname:sub(1, -9)
				local testname = basename .. ".xaml"
				if premake.findfile(prj, testname) then
					return "SubTypeCode", path.getname(testname)
				end       
			else
				-- is there a *.Designer.cs file?
				local basename = fname:sub(1, -4)
				local testname = basename .. ".Designer.cs"
				if premake.findfile(prj, testname) then
					return "SubTypeForm"
				end
			end
		end

		if action == "EmbeddedResource" and fname:endswith(".resx") then
			-- is there a matching *.cs file?
			local basename = fname:sub(1, -6)
			local testname = path.getname(basename .. ".cs")
			if premake.findfile(prj, testname) then
				if premake.findfile(prj, basename .. ".Designer.cs") then
					return "DesignerType", testname
				else
					return "Dependency", testname
				end
			else
				-- is there a matching *.Designer.cs?
				testname = path.getname(basename .. ".Designer.cs")
				if premake.findfile(prj, testname) then
					return "AutoGenerated"
				end
			end
		end
		
		if fname:endswith(".xaml") then
			return "XamlDesigner"
		end

		if action == "Content" then
			return "CopyNewest"
		end

		return "None"
	end


--
-- Return the Visual Studio architecture identification string. The logic
-- to select this is getting more complicated in VS2010, but I haven't
-- tackled all the permutations yet.
--

	function cs2005.arch(prj)
		return "AnyCPU"
	end


--
-- Write out the <Files> element.
--

	function cs2005.files(prj)
		local tr = premake.project.buildsourcetree(prj)
		premake.tree.traverse(tr, {
			onleaf = function(node)
				local action = premake.dotnet.getbuildaction(node.cfg)
				local fname  = path.translate(premake.esc(node.cfg.name), "\\")
				local elements, dependency = getelements(prj, action, node.path)

				if elements == "None" then
					_p('    <%s Include="%s" />', action, fname)
				else
					_p('    <%s Include="%s">', action, fname)
					if elements == "AutoGen" then
						_p('      <AutoGen>True</AutoGen>')
					elseif elements == "AutoGenerated" then
						_p('      <SubType>Designer</SubType>')
						_p('      <Generator>ResXFileCodeGenerator</Generator>')
						_p('      <LastGenOutput>%s.Designer.cs</LastGenOutput>', premake.esc(path.getbasename(node.name)))
					elseif elements == "SubTypeDesigner" then
						_p('      <SubType>Designer</SubType>')
					elseif elements == "SubTypeForm" then
						_p('      <SubType>Form</SubType>')
					elseif elements == "SubTypeCode" then
						_p('      <SubType>Code</SubType>')
					elseif elements == "XamlDesigner" then
						_p('      <SubType>Designer</SubType>')
						_p('      <Generator>MSBuild:Compile</Generator>')
					elseif elements == "PreserveNewest" then
						_p('      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>')
					end
					if dependency then
						_p('      <DependentUpon>%s</DependentUpon>', path.translate(premake.esc(dependency), "\\"))
					end
					_p('    </%s>', action)
				end
			end
		}, false)
	end


--
-- Write the opening <Project> element.
--

	function cs2005.projectelement(prj)
		local action = premake.action.current()

		local toolversion = ''
		if action.vstudio.toolsVersion then
			toolversion = string.format(' ToolsVersion="%s"', action.vstudio.toolsVersion)
		end

		if _ACTION > "vs2008" then
			_p('<?xml version="1.0" encoding="utf-8"?>')
		end
		_p('<Project%s DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">', toolversion)
	end


--
-- Write the opening PropertyGroup, which contains the project-level settings.
--

	function cs2005.projectsettings(prj)
		_p('  <PropertyGroup>')
		_p('    <Configuration Condition=" \'$(Configuration)\' == \'\' ">%s</Configuration>', premake.esc(prj.solution.configurations[1]))
		_p('    <Platform Condition=" \'$(Platform)\' == \'\' ">%s</Platform>', cs2005.arch(prj))

		local action = premake.action.current()
		if action.vstudio.productVersion then
			_p('    <ProductVersion>%s</ProductVersion>', action.vstudio.productVersion)
		end

		if _ACTION < "vs2012" then
			_p('    <SchemaVersion>2.0</SchemaVersion>')
		end

		_p('    <ProjectGuid>{%s}</ProjectGuid>', prj.uuid)
		_p('    <OutputType>%s</OutputType>', premake.dotnet.getkind(prj))
		_p('    <AppDesignerFolder>Properties</AppDesignerFolder>')
		_p('    <RootNamespace>%s</RootNamespace>', prj.buildtarget.basename)
		_p('    <AssemblyName>%s</AssemblyName>', prj.buildtarget.basename)

		local framework = prj.framework or action.vstudio.targetFramework
		if framework then
			_p('    <TargetFrameworkVersion>v%s</TargetFrameworkVersion>', framework)
		end

		if _ACTION == 'vs2010' then
			_p('    <TargetFrameworkProfile></TargetFrameworkProfile>')
		end

		if _ACTION >= "vs2010" then
			_p('    <FileAlignment>512</FileAlignment>')
		end

		_p('  </PropertyGroup>')
	end


--
-- Write the PropertyGroup element for a specific configuration block.
--

	function cs2005.propertygroup(cfg)
		_p('  <PropertyGroup Condition=" \'$(Configuration)|$(Platform)\' == \'%s|%s\' ">', premake.esc(cfg.name), cs2005.arch(cfg))
		if _ACTION > "vs2008" then
			_p('    <PlatformTarget>%s</PlatformTarget>', cs2005.arch(cfg))
		end
	end

--
-- Write the build events groups.
--

	function cs2005.buildevents(cfg)
		if #cfg.prebuildcommands > 0 then
			_p('  <PropertyGroup>')
			_p('    <PreBuildEvent>%s</PreBuildEvent>', premake.esc(table.implode(cfg.prebuildcommands, "", "", "\r\n")))
			_p('  </PropertyGroup>')
		end
		if #cfg.postbuildcommands > 0 then
			_p('  <PropertyGroup>')
			_p('    <PostBuildEvent>%s</PostBuildEvent>', premake.esc(table.implode(cfg.postbuildcommands, "", "", "\r\n")))
			_p('  </PropertyGroup>')
		end
	end


--
-- The main function: write the project file.
--

	function cs2005.generate(prj)
		io.eol = "\r\n"

		cs2005.projectelement(prj)

		if _ACTION > "vs2010" then
			_p('  <Import Project="$(MSBuildExtensionsPath)\\$(MSBuildToolsVersion)\\Microsoft.Common.props" Condition="Exists(\'$(MSBuildExtensionsPath)\\$(MSBuildToolsVersion)\\Microsoft.Common.props\')" />')
		end

		cs2005.projectsettings(prj)

		for cfg in premake.eachconfig(prj) do
			cs2005.propertygroup(cfg)

			if cfg.flags.Symbols then
				_p('    <DebugSymbols>true</DebugSymbols>')
				_p('    <DebugType>full</DebugType>')
			else
				_p('    <DebugType>pdbonly</DebugType>')
			end
			_p('    <Optimize>%s</Optimize>', iif(cfg.flags.Optimize or cfg.flags.OptimizeSize or cfg.flags.OptimizeSpeed, "true", "false"))
			_p('    <OutputPath>%s</OutputPath>', cfg.buildtarget.directory)
			_p('    <DefineConstants>%s</DefineConstants>', table.concat(premake.esc(cfg.defines), ";"))
			_p('    <ErrorReport>prompt</ErrorReport>')
			_p('    <WarningLevel>4</WarningLevel>')
			if cfg.flags.Unsafe then
				_p('    <AllowUnsafeBlocks>true</AllowUnsafeBlocks>')
			end
			if cfg.flags.FatalWarnings then
				_p('    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>')
			end
			_p('  </PropertyGroup>')
		end

		_p('  <ItemGroup>')
		for _, ref in ipairs(premake.getlinks(prj, "siblings", "object")) do
			_p('    <ProjectReference Include="%s">', path.translate(path.getrelative(prj.location, vstudio.projectfile(ref)), "\\"))
			_p('      <Project>{%s}</Project>', ref.uuid)
			_p('      <Name>%s</Name>', premake.esc(ref.name))
			_p('    </ProjectReference>')
		end
		for _, linkname in ipairs(premake.getlinks(prj, "system", "name")) do
			_p('    <Reference Include="%s" />', premake.esc(linkname))
		end
		_p('  </ItemGroup>')

		_p('  <ItemGroup>')
		cs2005.files(prj)
		_p('  </ItemGroup>')

		local msbuild = iif(_ACTION < "vs2012", "Bin", "Tools")
		_p('  <Import Project="$(MSBuild%sPath)\\Microsoft.CSharp.targets" />', msbuild)

		-- build events
		cs2005.buildevents(prj)

		_p('  <!-- To modify your build process, add your task inside one of the targets below and uncomment it.')
		_p('       Other similar extension points exist, see Microsoft.Common.targets.')
		_p('  <Target Name="BeforeBuild">')
		_p('  </Target>')
		_p('  <Target Name="AfterBuild">')
		_p('  </Target>')
		_p('  -->')
		_p('</Project>')

	end

-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs2005_csproj.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs2005_csproj_user.lua
--
-- vs2005_csproj_user.lua
-- Generate a Visual Studio 2005/2008 C# .user file.
-- Copyright (c) 2009 Jason Perkins and the Premake project
--

	local cs2005 = premake.vstudio.cs2005


	function cs2005.generate_user(prj)
		io.eol = "\r\n"
		
		_p('<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">')
		_p('  <PropertyGroup>')
		
		local refpaths = table.translate(prj.libdirs, function(v) return path.getabsolute(prj.location .. "/" .. v) end)
		_p('    <ReferencePath>%s</ReferencePath>', path.translate(table.concat(refpaths, ";"), "\\"))
		_p('  </PropertyGroup>')
		_p('</Project>')
		
	end
-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs2005_csproj_user.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs2010_vcxproj.lua
--
-- vs2010_vcxproj.lua
-- Generate a Visual Studio 2010 C/C++ project.
-- Copyright (c) 2009-2011 Jason Perkins and the Premake project
--

	premake.vstudio.vc2010 = { }
	local vc2010 = premake.vstudio.vc2010
	local vstudio = premake.vstudio


	local function vs2010_config(prj)
		_p(1,'<ItemGroup Label="ProjectConfigurations">')
		for _, cfginfo in ipairs(prj.solution.vstudio_configs) do
				_p(2,'<ProjectConfiguration Include="%s">', premake.esc(cfginfo.name))
					_p(3,'<Configuration>%s</Configuration>',cfginfo.buildcfg)
					_p(3,'<Platform>%s</Platform>',cfginfo.platform)
				_p(2,'</ProjectConfiguration>')
		end
		_p(1,'</ItemGroup>')
	end

	local function vs2010_globals(prj)
		_p(1,'<PropertyGroup Label="Globals">')
			_p(2,'<ProjectGuid>{%s}</ProjectGuid>',prj.uuid)
			_p(2,'<RootNamespace>%s</RootNamespace>',prj.name)
		--if prj.flags is required as it is not set at project level for tests???
		--vs200x generator seems to swap a config for the prj in test setup
		if prj.flags and prj.flags.Managed then
			_p(2,'<TargetFrameworkVersion>v4.0</TargetFrameworkVersion>')
			_p(2,'<Keyword>ManagedCProj</Keyword>')
		else
			_p(2,'<Keyword>Win32Proj</Keyword>')
		end
		_p(1,'</PropertyGroup>')
	end

	function vc2010.config_type(config)
		local t =
		{
			SharedLib = "DynamicLibrary",
			StaticLib = "StaticLibrary",
			ConsoleApp = "Application",
			WindowedApp = "Application"
		}
		return t[config.kind]
	end



	local function if_config_and_platform()
		return 'Condition="\'$(Configuration)|$(Platform)\'==\'%s\'"'
	end

	local function optimisation(cfg)
		local result = "Disabled"
		for _, value in ipairs(cfg.flags) do
			if (value == "Optimize") then
				result = "Full"
			elseif (value == "OptimizeSize") then
				result = "MinSpace"
			elseif (value == "OptimizeSpeed") then
				result = "MaxSpeed"
			end
		end
		return result
	end


--
-- This property group describes a particular configuration: what
-- kind of binary it produces, and some global settings.
--

	function vc2010.configurationPropertyGroup(cfg, cfginfo)
		_p(1,'<PropertyGroup '..if_config_and_platform() ..' Label="Configuration">'
				, premake.esc(cfginfo.name))
		_p(2,'<ConfigurationType>%s</ConfigurationType>',vc2010.config_type(cfg))
		_p(2,'<UseDebugLibraries>%s</UseDebugLibraries>', iif(optimisation(cfg) == "Disabled","true","false"))
		_p(2,'<CharacterSet>%s</CharacterSet>',iif(cfg.flags.Unicode,"Unicode","MultiByte"))

		local toolsets = { vs2012 = "v110", vs2013 = "v120" }
		local toolset = toolsets[_ACTION]
		if toolset then
			_p(2,'<PlatformToolset>%s</PlatformToolset>', toolset)
		end

		if cfg.flags.MFC then
			_p(2,'<UseOfMfc>%s</UseOfMfc>', iif(cfg.flags.StaticRuntime, "Static", "Dynamic"))
		end

		if cfg.flags.ATL or cfg.flags.StaticATL then
			_p(2,'<UseOfAtl>%s</UseOfAtl>', iif(cfg.flags.StaticATL, "Static", "Dynamic"))
		end

		if cfg.flags.Managed then
			_p(2,'<CLRSupport>true</CLRSupport>')
		end
		_p(1,'</PropertyGroup>')
	end


	local function import_props(prj)
		for _, cfginfo in ipairs(prj.solution.vstudio_configs) do
			local cfg = premake.getconfig(prj, cfginfo.src_buildcfg, cfginfo.src_platform)
			_p(1,'<ImportGroup '..if_config_and_platform() ..' Label="PropertySheets">'
					,premake.esc(cfginfo.name))
				_p(2,'<Import Project="$(UserRootDir)\\Microsoft.Cpp.$(Platform).user.props" Condition="exists(\'$(UserRootDir)\\Microsoft.Cpp.$(Platform).user.props\')" Label="LocalAppDataPlatform" />')
			_p(1,'</ImportGroup>')
		end
	end

	function vc2010.outputProperties(prj)
			for _, cfginfo in ipairs(prj.solution.vstudio_configs) do
				local cfg = premake.getconfig(prj, cfginfo.src_buildcfg, cfginfo.src_platform)
				local target = cfg.buildtarget

				_p(1,'<PropertyGroup '..if_config_and_platform() ..'>', premake.esc(cfginfo.name))

				_p(2,'<OutDir>%s\\</OutDir>', premake.esc(target.directory))

				if cfg.platform == "Xbox360" then
					_p(2,'<OutputFile>$(OutDir)%s</OutputFile>', premake.esc(target.name))
				end

				_p(2,'<IntDir>%s\\</IntDir>', premake.esc(cfg.objectsdir))
				_p(2,'<TargetName>%s</TargetName>', premake.esc(path.getbasename(target.name)))
				_p(2,'<TargetExt>%s</TargetExt>', premake.esc(path.getextension(target.name)))

				if cfg.kind == "SharedLib" then
					local ignore = (cfg.flags.NoImportLib ~= nil)
					 _p(2,'<IgnoreImportLibrary>%s</IgnoreImportLibrary>', tostring(ignore))
				end

				if cfg.kind ~= "StaticLib" then
					_p(2,'<LinkIncremental>%s</LinkIncremental>', tostring(premake.config.isincrementallink(cfg)))
				end

				if cfg.flags.NoManifest then
					_p(2,'<GenerateManifest>false</GenerateManifest>')
				end

				_p(1,'</PropertyGroup>')
			end

	end

	local function runtime(cfg)
		local runtime
		local flags = cfg.flags
		if premake.config.isdebugbuild(cfg) then
			runtime = iif(flags.StaticRuntime and not flags.Managed, "MultiThreadedDebug", "MultiThreadedDebugDLL")
		else
			runtime = iif(flags.StaticRuntime and not flags.Managed, "MultiThreaded", "MultiThreadedDLL")
		end
		return runtime
	end

	local function precompiled_header(cfg)
      	if not cfg.flags.NoPCH and cfg.pchheader then
			_p(3,'<PrecompiledHeader>Use</PrecompiledHeader>')
			_p(3,'<PrecompiledHeaderFile>%s</PrecompiledHeaderFile>', cfg.pchheader)
		else
			_p(3,'<PrecompiledHeader></PrecompiledHeader>')
		end
	end

	local function preprocessor(indent,cfg)
		if #cfg.defines > 0 then
			_p(indent,'<PreprocessorDefinitions>%s;%%(PreprocessorDefinitions)</PreprocessorDefinitions>'
				,premake.esc(table.concat(cfg.defines, ";")))
		else
			_p(indent,'<PreprocessorDefinitions></PreprocessorDefinitions>')
		end
	end

	local function include_dirs(indent,cfg)
		if #cfg.includedirs > 0 then
			_p(indent,'<AdditionalIncludeDirectories>%s;%%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>'
					,premake.esc(path.translate(table.concat(cfg.includedirs, ";"), '\\')))
		end
	end

	local function resinclude_dirs(indent,cfg)
		if #cfg.includedirs > 0 or #cfg.resincludedirs > 0 then
			local dirs = table.join(cfg.includedirs, cfg.resincludedirs)
			_p(indent,'<AdditionalIncludeDirectories>%s;%%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>'
					,premake.esc(path.translate(table.concat(dirs, ";"), '\\')))
		end
	end

	local function resource_compile(cfg)
		_p(2,'<ResourceCompile>')
			preprocessor(3,cfg)
			resinclude_dirs(3,cfg)
		_p(2,'</ResourceCompile>')

	end

	local function exceptions(cfg)
		if cfg.flags.NoExceptions then
			_p(2,'<ExceptionHandling>false</ExceptionHandling>')
		elseif cfg.flags.SEH then
			_p(2,'<ExceptionHandling>Async</ExceptionHandling>')
		--SEH is not required for Managed and is implied
		end
	end

	local function rtti(cfg)
		if cfg.flags.NoRTTI and not cfg.flags.Managed then
			_p(3,'<RuntimeTypeInfo>false</RuntimeTypeInfo>')
		end
	end

	local function wchar_t_buildin(cfg)
		if cfg.flags.NativeWChar then
			_p(3,'<TreatWChar_tAsBuiltInType>true</TreatWChar_tAsBuiltInType>')
		elseif cfg.flags.NoNativeWChar then
			_p(3,'<TreatWChar_tAsBuiltInType>false</TreatWChar_tAsBuiltInType>')
		end
	end

	local function sse(cfg)
		if cfg.flags.EnableSSE then
			_p(3,'<EnableEnhancedInstructionSet>StreamingSIMDExtensions</EnableEnhancedInstructionSet>')
		elseif cfg.flags.EnableSSE2 then
			_p(3,'<EnableEnhancedInstructionSet>StreamingSIMDExtensions2</EnableEnhancedInstructionSet>')
		end
	end

	local function floating_point(cfg)
	     if cfg.flags.FloatFast then
			_p(3,'<FloatingPointModel>Fast</FloatingPointModel>')
		elseif cfg.flags.FloatStrict and not cfg.flags.Managed then
			_p(3,'<FloatingPointModel>Strict</FloatingPointModel>')
		end
	end


	local function debug_info(cfg)
	--
	--	EditAndContinue /ZI
	--	ProgramDatabase /Zi
	--	OldStyle C7 Compatable /Z7
	--
		local debug_info = ''
		if cfg.flags.Symbols then
			if cfg.platform == "x64"
				or cfg.flags.Managed
				or premake.config.isoptimizedbuild(cfg.flags)
				or cfg.flags.NoEditAndContinue
			then
					debug_info = "ProgramDatabase"
			else
				debug_info = "EditAndContinue"
			end
		end

		_p(3,'<DebugInformationFormat>%s</DebugInformationFormat>',debug_info)
	end

	local function minimal_build(cfg)
		if premake.config.isdebugbuild(cfg) and not cfg.flags.NoMinimalRebuild then
			_p(3,'<MinimalRebuild>true</MinimalRebuild>')
		else
			_p(3,'<MinimalRebuild>false</MinimalRebuild>')
		end
	end

	local function compile_language(cfg)
		if cfg.language == "C" then
			_p(3,'<CompileAs>CompileAsC</CompileAs>')
		end
	end

	local function vs10_clcompile(cfg)
		_p(2,'<ClCompile>')

		if #cfg.buildoptions > 0 then
			_p(3,'<AdditionalOptions>%s %%(AdditionalOptions)</AdditionalOptions>',
					table.concat(premake.esc(cfg.buildoptions), " "))
		end

			_p(3,'<Optimization>%s</Optimization>',optimisation(cfg))

			include_dirs(3,cfg)
			preprocessor(3,cfg)
			minimal_build(cfg)

		if  not premake.config.isoptimizedbuild(cfg.flags) then
			if not cfg.flags.Managed then
				_p(3,'<BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>')
			end

			if cfg.flags.ExtraWarnings then
				_p(3,'<SmallerTypeCheck>true</SmallerTypeCheck>')
			end
		else
			_p(3,'<StringPooling>true</StringPooling>')
		end

			_p(3,'<RuntimeLibrary>%s</RuntimeLibrary>', runtime(cfg))

			_p(3,'<FunctionLevelLinking>true</FunctionLevelLinking>')

			precompiled_header(cfg)

		if cfg.flags.ExtraWarnings then
			_p(3,'<WarningLevel>Level4</WarningLevel>')
		else
			_p(3,'<WarningLevel>Level3</WarningLevel>')
		end

		if cfg.flags.FatalWarnings then
			_p(3,'<TreatWarningAsError>true</TreatWarningAsError>')
		end

			exceptions(cfg)
			rtti(cfg)
			wchar_t_buildin(cfg)
			sse(cfg)
			floating_point(cfg)
			debug_info(cfg)

		if cfg.flags.Symbols then
			_p(3,'<ProgramDataBaseFileName>$(OutDir)%s.pdb</ProgramDataBaseFileName>'
				, path.getbasename(cfg.buildtarget.name))
		end

		if cfg.flags.NoFramePointer then
			_p(3,'<OmitFramePointers>true</OmitFramePointers>')
		end

			compile_language(cfg)

		_p(2,'</ClCompile>')
	end


	local function event_hooks(cfg)
		if #cfg.postbuildcommands> 0 then
		    _p(2,'<PostBuildEvent>')
				_p(3,'<Command>%s</Command>',premake.esc(table.implode(cfg.postbuildcommands, "", "", "\r\n")))
			_p(2,'</PostBuildEvent>')
		end

		if #cfg.prebuildcommands> 0 then
		    _p(2,'<PreBuildEvent>')
				_p(3,'<Command>%s</Command>',premake.esc(table.implode(cfg.prebuildcommands, "", "", "\r\n")))
			_p(2,'</PreBuildEvent>')
		end

		if #cfg.prelinkcommands> 0 then
		    _p(2,'<PreLinkEvent>')
				_p(3,'<Command>%s</Command>',premake.esc(table.implode(cfg.prelinkcommands, "", "", "\r\n")))
			_p(2,'</PreLinkEvent>')
		end
	end

	local function additional_options(indent,cfg)
		if #cfg.linkoptions > 0 then
				_p(indent,'<AdditionalOptions>%s %%(AdditionalOptions)</AdditionalOptions>',
					table.concat(premake.esc(cfg.linkoptions), " "))
		end
	end

	local function link_target_machine(index,cfg)
		local platforms = {x32 = 'MachineX86', x64 = 'MachineX64'}
		if platforms[cfg.platform] then
			_p(index,'<TargetMachine>%s</TargetMachine>', platforms[cfg.platform])
		end
	end

	local function item_def_lib(cfg)
       -- The Xbox360 project files are stored in another place in the project file.
		if cfg.kind == 'StaticLib' and cfg.platform ~= "Xbox360" then
			_p(1,'<Lib>')
				_p(2,'<OutputFile>$(OutDir)%s</OutputFile>',cfg.buildtarget.name)
				additional_options(2,cfg)
				link_target_machine(2,cfg)
			_p(1,'</Lib>')
		end
	end



	local function import_lib(cfg)
		--Prevent the generation of an import library for a Windows DLL.
		if cfg.kind == "SharedLib" then
			local implibname = cfg.linktarget.fullpath
			_p(3,'<ImportLibrary>%s</ImportLibrary>',iif(cfg.flags.NoImportLib, cfg.objectsdir .. "\\" .. path.getname(implibname), implibname))
		end
	end


--
-- Generate the <Link> element and its children.
--

	function vc2010.link(cfg)
		_p(2,'<Link>')
		_p(3,'<SubSystem>%s</SubSystem>', iif(cfg.kind == "ConsoleApp", "Console", "Windows"))
		_p(3,'<GenerateDebugInformation>%s</GenerateDebugInformation>', tostring(cfg.flags.Symbols ~= nil))

		if premake.config.isoptimizedbuild(cfg.flags) then
			_p(3,'<EnableCOMDATFolding>true</EnableCOMDATFolding>')
			_p(3,'<OptimizeReferences>true</OptimizeReferences>')
		end

		if cfg.kind ~= 'StaticLib' then
			vc2010.additionalDependencies(cfg)
			_p(3,'<OutputFile>$(OutDir)%s</OutputFile>', cfg.buildtarget.name)

			if #cfg.libdirs > 0 then
				_p(3,'<AdditionalLibraryDirectories>%s;%%(AdditionalLibraryDirectories)</AdditionalLibraryDirectories>',
						premake.esc(path.translate(table.concat(cfg.libdirs, ';'), '\\')))
			end

			if vc2010.config_type(cfg) == 'Application' and not cfg.flags.WinMain and not cfg.flags.Managed then
				_p(3,'<EntryPointSymbol>mainCRTStartup</EntryPointSymbol>')
			end

			import_lib(cfg)

			local deffile = premake.findfile(cfg, ".def")
			if deffile then
				_p(3,'<ModuleDefinitionFile>%s</ModuleDefinitionFile>', deffile)
			end

			link_target_machine(3,cfg)
			additional_options(3,cfg)
		end

		_p(2,'</Link>')
	end


--
-- Generate the <Link/AdditionalDependencies> element, which links in system
-- libraries required by the project (but not sibling projects; that's handled
-- by an <ItemGroup/ProjectReference>).
--

	function vc2010.additionalDependencies(cfg)
		local links = premake.getlinks(cfg, "system", "fullpath")
		if #links > 0 then
			_p(3,'<AdditionalDependencies>%s;%%(AdditionalDependencies)</AdditionalDependencies>',
						table.concat(links, ";"))
		end
	end


	local function item_definitions(prj)
		for _, cfginfo in ipairs(prj.solution.vstudio_configs) do
			local cfg = premake.getconfig(prj, cfginfo.src_buildcfg, cfginfo.src_platform)
			_p(1,'<ItemDefinitionGroup ' ..if_config_and_platform() ..'>'
					,premake.esc(cfginfo.name))
				vs10_clcompile(cfg)
				resource_compile(cfg)
				item_def_lib(cfg)
				vc2010.link(cfg)
				event_hooks(cfg)
			_p(1,'</ItemDefinitionGroup>')


		end
	end



--
-- Retrieve a list of files for a particular build group, one of
-- "ClInclude", "ClCompile", "ResourceCompile", and "None".
--

	function vc2010.getfilegroup(prj, group)
		local sortedfiles = prj.vc2010sortedfiles
		if not sortedfiles then
			sortedfiles = {
				ClCompile = {},
				ClInclude = {},
				None = {},
				ResourceCompile = {},
			}

			for file in premake.project.eachfile(prj) do
				if path.iscppfile(file.name) then
					table.insert(sortedfiles.ClCompile, file)
				elseif path.iscppheader(file.name) then
					table.insert(sortedfiles.ClInclude, file)
				elseif path.isresourcefile(file.name) then
					table.insert(sortedfiles.ResourceCompile, file)
				else
					table.insert(sortedfiles.None, file)
				end
			end

			-- Cache the sorted files; they are used several places
			prj.vc2010sortedfiles = sortedfiles
		end

		return sortedfiles[group]
	end


--
-- Write the files section of the project file.
--

	function vc2010.files(prj)
		vc2010.simplefilesgroup(prj, "ClInclude")
		vc2010.compilerfilesgroup(prj)
		vc2010.simplefilesgroup(prj, "None")
		vc2010.simplefilesgroup(prj, "ResourceCompile")
	end


	function vc2010.simplefilesgroup(prj, section)
		local files = vc2010.getfilegroup(prj, section)
		if #files > 0  then
			_p(1,'<ItemGroup>')
			for _, file in ipairs(files) do
				_p(2,'<%s Include=\"%s\" />', section, path.translate(file.name, "\\"))
			end
			_p(1,'</ItemGroup>')
		end
	end


	function vc2010.compilerfilesgroup(prj)
		local configs = prj.solution.vstudio_configs
		local files = vc2010.getfilegroup(prj, "ClCompile")
		if #files > 0  then
			local config_mappings = {}
			for _, cfginfo in ipairs(configs) do
				local cfg = premake.getconfig(prj, cfginfo.src_buildcfg, cfginfo.src_platform)
				if cfg.pchheader and cfg.pchsource and not cfg.flags.NoPCH then
					config_mappings[cfginfo] = path.translate(cfg.pchsource, "\\")
				end
			end

			_p(1,'<ItemGroup>')
			for _, file in ipairs(files) do
				local translatedpath = path.translate(file.name, "\\")
				_p(2,'<ClCompile Include=\"%s\">', translatedpath)
				for _, cfginfo in ipairs(configs) do
					if config_mappings[cfginfo] and translatedpath == config_mappings[cfginfo] then
						_p(3,'<PrecompiledHeader '.. if_config_and_platform() .. '>Create</PrecompiledHeader>', premake.esc(cfginfo.name))
						config_mappings[cfginfo] = nil  --only one source file per pch
					end
				end
				_p(2,'</ClCompile>')
			end
			_p(1,'</ItemGroup>')
		end
	end


--
-- Output the VC2010 project file header
--

	function vc2010.header(targets)
		io.eol = "\r\n"
		_p('<?xml version="1.0" encoding="utf-8"?>')

		local t = ""
		if targets then
			t = ' DefaultTargets="' .. targets .. '"'
		end

		_p('<Project%s ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">', t)
	end


--
-- Output the VC2010 C/C++ project file
--

	function premake.vs2010_vcxproj(prj)
		io.indent = "  "
		vc2010.header("Build")

			vs2010_config(prj)
			vs2010_globals(prj)

			_p(1,'<Import Project="$(VCTargetsPath)\\Microsoft.Cpp.Default.props" />')

			for _, cfginfo in ipairs(prj.solution.vstudio_configs) do
				local cfg = premake.getconfig(prj, cfginfo.src_buildcfg, cfginfo.src_platform)
				vc2010.configurationPropertyGroup(cfg, cfginfo)
			end

			_p(1,'<Import Project="$(VCTargetsPath)\\Microsoft.Cpp.props" />')

			--check what this section is doing
			_p(1,'<ImportGroup Label="ExtensionSettings">')
			_p(1,'</ImportGroup>')


			import_props(prj)

			--what type of macros are these?
			_p(1,'<PropertyGroup Label="UserMacros" />')

			vc2010.outputProperties(prj)

			item_definitions(prj)

			vc2010.files(prj)
			vc2010.projectReferences(prj)

			_p(1,'<Import Project="$(VCTargetsPath)\\Microsoft.Cpp.targets" />')
			_p(1,'<ImportGroup Label="ExtensionTargets">')
			_p(1,'</ImportGroup>')

		_p('</Project>')
	end


--
-- Generate the list of project dependencies.
--

	function vc2010.projectReferences(prj)
		local deps = premake.getdependencies(prj)
		if #deps > 0 then
			_p(1,'<ItemGroup>')
			for _, dep in ipairs(deps) do
				local deppath = path.getrelative(prj.location, vstudio.projectfile(dep))
				_p(2,'<ProjectReference Include=\"%s\">', path.translate(deppath, "\\"))
				_p(3,'<Project>{%s}</Project>', dep.uuid)
				_p(2,'</ProjectReference>')
			end
			_p(1,'</ItemGroup>')
		end
	end


--
-- Generate the .vcxproj.user file
--

	function vc2010.debugdir(cfg)
		if cfg.debugdir then
			_p('    <LocalDebuggerWorkingDirectory>%s</LocalDebuggerWorkingDirectory>', path.translate(cfg.debugdir, '\\'))
			_p('    <DebuggerFlavor>WindowsLocalDebugger</DebuggerFlavor>')
		end
		if cfg.debugargs then
			_p('    <LocalDebuggerCommandArguments>%s</LocalDebuggerCommandArguments>', table.concat(cfg.debugargs, " "))
		end
	end

	function vc2010.debugenvs(cfg)
		if cfg.debugenvs and #cfg.debugenvs > 0 then
			_p(2,'<LocalDebuggerEnvironment>%s%s</LocalDebuggerEnvironment>',table.concat(cfg.debugenvs, "\n")
					,iif(cfg.flags.DebugEnvsInherit,'\n$(LocalDebuggerEnvironment)','')
				)
			if cfg.flags.DebugEnvsDontMerge then
				_p(2,'<LocalDebuggerMergeEnvironment>false</LocalDebuggerMergeEnvironment>')
			end
		end
	end

	function premake.vs2010_vcxproj_user(prj)
		io.indent = "  "
		vc2010.header()
		for _, cfginfo in ipairs(prj.solution.vstudio_configs) do
			local cfg = premake.getconfig(prj, cfginfo.src_buildcfg, cfginfo.src_platform)
			_p('  <PropertyGroup '.. if_config_and_platform() ..'>', premake.esc(cfginfo.name))
			vc2010.debugdir(cfg)
			vc2010.debugenvs(cfg)
			_p('  </PropertyGroup>')
		end
		_p('</Project>')
	end



-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs2010_vcxproj.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs2010_vcxproj_filters.lua
--
-- vs2010_vcxproj_filters.lua
-- Generate a Visual Studio 2010 C/C++ filters file.
-- Copyright (c) 2009-2011 Jason Perkins and the Premake project
--

	local vc2010 = premake.vstudio.vc2010
	local project = premake.project
	

--
-- The first portion of the filters file assigns unique IDs to each
-- directory or virtual group. Would be cool if we could automatically
-- map vpaths like "**.h" to an <Extensions>h</Extensions> element.
--

	function vc2010.filteridgroup(prj)
		local filters = { }
		local filterfound = false

		for file in project.eachfile(prj) do
			-- split the path into its component parts
			local folders = string.explode(file.vpath, "/", true)
			local path = ""
			for i = 1, #folders - 1 do
				-- element is only written if there *are* filters
				if not filterfound then
					filterfound = true
					_p(1,'<ItemGroup>')
				end
				
				path = path .. folders[i]

				-- have I seen this path before?
				if not filters[path] then
					filters[path] = true
					_p(2, '<Filter Include="%s">', path)
					_p(3, '<UniqueIdentifier>{%s}</UniqueIdentifier>', os.uuid())
					_p(2, '</Filter>')
				end

				-- prepare for the next subfolder
				path = path .. "\\"
			end
		end
		
		if filterfound then
			_p(1,'</ItemGroup>')
		end
	end


--
-- The second portion of the filters file assigns filters to each source
-- code file, as needed. Section is one of "ClCompile", "ClInclude", 
-- "ResourceCompile", or "None".
--

	function vc2010.filefiltergroup(prj, section)
		local files = vc2010.getfilegroup(prj, section)
		if #files > 0 then
			_p(1,'<ItemGroup>')
			for _, file in ipairs(files) do
				local filter
				if file.name ~= file.vpath then
					filter = path.getdirectory(file.vpath)
				else
					filter = path.getdirectory(file.name)
				end				
				
				if filter ~= "." then
					_p(2,'<%s Include=\"%s\">', section, path.translate(file.name, "\\"))
						_p(3,'<Filter>%s</Filter>', path.translate(filter, "\\"))
					_p(2,'</%s>', section)
				else
					_p(2,'<%s Include=\"%s\" />', section, path.translate(file.name, "\\"))
				end
			end
			_p(1,'</ItemGroup>')
		end
	end


--
-- Output the VC2010 filters file
--
	
	function vc2010.generate_filters(prj)
		io.indent = "  "
		vc2010.header()
			vc2010.filteridgroup(prj)
			vc2010.filefiltergroup(prj, "None")
			vc2010.filefiltergroup(prj, "ClInclude")
			vc2010.filefiltergroup(prj, "ClCompile")
			vc2010.filefiltergroup(prj, "ResourceCompile")
		_p('</Project>')
	end
-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs2010_vcxproj_filters.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs2012.lua
--
-- vs2012.lua
-- Baseline support for Visual Studio 2012.
-- Copyright (c) 2013 Jason Perkins and the Premake project
--

	premake.vstudio.vc2012 = {}
	local vc2012 = premake.vstudio.vc2012
	local vstudio = premake.vstudio


---
-- Register a command-line action for Visual Studio 2012.
---

	newaction
	{
		trigger         = "vs2012",
		shortname       = "Visual Studio 2012",
		description     = "Generate Microsoft Visual Studio 2012 project files",
		os              = "windows",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib" },

		valid_languages = { "C", "C++", "C#"},

		valid_tools     = {
			cc     = { "msc"   },
			dotnet = { "msnet" },
		},

		onsolution = function(sln)
			premake.generate(sln, "%%.sln", vstudio.sln2005.generate)
		end,

		onproject = function(prj)
			if premake.isdotnetproject(prj) then
				premake.generate(prj, "%%.csproj", vstudio.cs2005.generate)
				premake.generate(prj, "%%.csproj.user", vstudio.cs2005.generate_user)
			else
			premake.generate(prj, "%%.vcxproj", premake.vs2010_vcxproj)
			premake.generate(prj, "%%.vcxproj.user", premake.vs2010_vcxproj_user)
			premake.generate(prj, "%%.vcxproj.filters", vstudio.vc2010.generate_filters)
			end
		end,


		oncleansolution = premake.vstudio.cleansolution,
		oncleanproject  = premake.vstudio.cleanproject,
		oncleantarget   = premake.vstudio.cleantarget,

		vstudio = {
			solutionVersion = "12",
			targetFramework = "4.5",
			toolsVersion    = "4.0",
		}
	}

-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs2012.lua
-- AMALGAMATE FILE HEAD : /src/actions/vstudio/vs2013.lua
--
-- vs2013.lua
-- Baseline support for Visual Studio 2013.
-- Copyright (c) 2013 Jason Perkins and the Premake project
--

	premake.vstudio.vc2013 = {}
	local vc2013 = premake.vstudio.vc2013
	local vstudio = premake.vstudio
  

---
-- Register a command-line action for Visual Studio 2013.
---

	newaction
	{
		trigger         = "vs2013",
		shortname       = "Visual Studio 2013",
		description     = "Generate Microsoft Visual Studio 2013 project files",
		os              = "windows",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib" },

		valid_languages = { "C", "C++", "C#"},

		valid_tools     = {
			cc     = { "msc"   },
			dotnet = { "msnet" },
		},

		onsolution = function(sln)
			premake.generate(sln, "%%.sln", vstudio.sln2005.generate)
		end,

		onproject = function(prj)
			if premake.isdotnetproject(prj) then
				premake.generate(prj, "%%.csproj", vstudio.cs2005.generate)
				premake.generate(prj, "%%.csproj.user", vstudio.cs2005.generate_user)
			else
			premake.generate(prj, "%%.vcxproj", premake.vs2010_vcxproj)
			premake.generate(prj, "%%.vcxproj.user", premake.vs2010_vcxproj_user)
			premake.generate(prj, "%%.vcxproj.filters", vstudio.vc2010.generate_filters)
			end
		end,


		oncleansolution = premake.vstudio.cleansolution,
		oncleanproject  = premake.vstudio.cleanproject,
		oncleantarget   = premake.vstudio.cleantarget,

		vstudio = {
			solutionVersion = "12",
			targetFramework = "4.5",
			toolsVersion    = "12.0",
		}
	}
-- AMALGAMATE FILE TAIL : /src/actions/vstudio/vs2013.lua
-- AMALGAMATE FILE HEAD : /src/actions/xcode/_xcode.lua
--
-- _xcode.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2009 Jason Perkins and the Premake project
--

	premake.xcode = { }
	
	newaction 
	{
		trigger         = "xcode3",
		shortname       = "Xcode 3",
		description     = "Generate Apple Xcode 3 project files (experimental)",
		os              = "macosx",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "SharedLib", "StaticLib" },
		
		valid_languages = { "C", "C++" },
		
		valid_tools     = {
			cc     = { "gcc" },
		},

		valid_platforms = { 
			Native = "Native", 
			x32 = "Native 32-bit", 
			x64 = "Native 64-bit", 
			Universal32 = "32-bit Universal", 
			Universal64 = "64-bit Universal", 
			Universal = "Universal",
		},
		
		default_platform = "Universal",
		
		onsolution = function(sln)
			-- Assign IDs needed for inter-project dependencies
			premake.xcode.preparesolution(sln)
		end,
		
		onproject = function(prj)
			premake.generate(prj, "%%.xcodeproj/project.pbxproj", premake.xcode.project)
		end,
		
		oncleanproject = function(prj)
			premake.clean.directory(prj, "%%.xcodeproj")
		end,
		
		oncheckproject = function(prj)
			-- Xcode can't mix target kinds within a project
			local last
			for cfg in premake.eachconfig(prj) do
				if last and last ~= cfg.kind then
					error("Project '" .. prj.name .. "' uses more than one target kind; not supported by Xcode", 0)
				end
				last = cfg.kind
			end
		end,
	}

	newaction 
	{
		trigger         = "xcode4",
		shortname       = "Xcode 4",
		description     = "Generate Apple Xcode 4 project files (experimental)",
		os              = "macosx",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "SharedLib", "StaticLib" },
		
		valid_languages = { "C", "C++" },
		
		valid_tools     = {
			cc     = { "gcc" },
		},

		valid_platforms = { 
			Native = "Native", 
			x32 = "Native 32-bit", 
			x64 = "Native 64-bit", 
			Universal32 = "32-bit Universal", 
			Universal64 = "64-bit Universal", 
			Universal = "Universal",
		},
		
		default_platform = "Universal",
		
		onsolution = function(sln)
			premake.generate(sln, "%%.xcworkspace/contents.xcworkspacedata", premake.xcode4.workspace_generate)
		end,
		
		onproject = function(prj)
			premake.generate(prj, "%%.xcodeproj/project.pbxproj", premake.xcode.project)
		end,
		
		oncleanproject = function(prj)
			premake.clean.directory(prj, "%%.xcodeproj")
			premake.clean.directory(prj, "%%.xcworkspace")
		end,
		
		oncheckproject = function(prj)
			-- Xcode can't mix target kinds within a project
			local last
			for cfg in premake.eachconfig(prj) do
				if last and last ~= cfg.kind then
					error("Project '" .. prj.name .. "' uses more than one target kind; not supported by Xcode", 0)
				end
				last = cfg.kind
			end
		end,
	}


-- AMALGAMATE FILE TAIL : /src/actions/xcode/_xcode.lua
-- AMALGAMATE FILE HEAD : /src/actions/xcode/xcode_common.lua
--
-- xcode_common.lua
-- Functions to generate the different sections of an Xcode project.
-- Copyright (c) 2009-2011 Jason Perkins and the Premake project
--

	local xcode = premake.xcode
	local tree  = premake.tree


--
-- Return the Xcode build category for a given file, based on the file extension.
--
-- @param node
--    The node to identify.
-- @returns
--    An Xcode build category, one of "Sources", "Resources", "Frameworks", or nil.
--

	function xcode.getbuildcategory(node)
		local categories = {
			[".a"] = "Frameworks",
			[".c"] = "Sources",
			[".cc"] = "Sources",
			[".cpp"] = "Sources",
			[".cxx"] = "Sources",
			[".dylib"] = "Frameworks",
			[".framework"] = "Frameworks",
			[".m"] = "Sources",
			[".mm"] = "Sources",
			[".strings"] = "Resources",
			[".nib"] = "Resources",
			[".xib"] = "Resources",
			[".icns"] = "Resources",
			[".bmp"] = "Resources",
			[".wav"] = "Resources",
		}
		return categories[path.getextension(node.name)]
	end


--
-- Return the displayed name for a build configuration, taking into account the
-- configuration and platform, i.e. "Debug 32-bit Universal".
--
-- @param cfg
--    The configuration being identified.
-- @returns
--    A build configuration name.
--

	function xcode.getconfigname(cfg)
		local name = cfg.name
		if #cfg.project.solution.xcode.platforms > 1 then
			name = name .. " " .. premake.action.current().valid_platforms[cfg.platform]
		end
		return name
	end


--
-- Return the Xcode type for a given file, based on the file extension.
--
-- @param fname
--    The file name to identify.
-- @returns
--    An Xcode file type, string.
--

	function xcode.getfiletype(node)
		local types = {
			[".c"]         = "sourcecode.c.c",
			[".cc"]        = "sourcecode.cpp.cpp",
			[".cpp"]       = "sourcecode.cpp.cpp",
			[".css"]       = "text.css",
			[".cxx"]       = "sourcecode.cpp.cpp",
			[".framework"] = "wrapper.framework",
			[".gif"]       = "image.gif",
			[".h"]         = "sourcecode.c.h",
			[".html"]      = "text.html",
			[".lua"]       = "sourcecode.lua",
			[".m"]         = "sourcecode.c.objc",
			[".mm"]        = "sourcecode.cpp.objc",
			[".nib"]       = "wrapper.nib",
			[".pch"]       = "sourcecode.c.h",
			[".plist"]     = "text.plist.xml",
			[".strings"]   = "text.plist.strings",
			[".xib"]       = "file.xib",
			[".icns"]      = "image.icns",
			[".bmp"]       = "image.bmp",
			[".wav"]       = "audio.wav",
		}
		return types[path.getextension(node.path)] or "text"
	end


--
-- Return the Xcode product type, based target kind.
--
-- @param node
--    The product node to identify.
-- @returns
--    An Xcode product type, string.
--

	function xcode.getproducttype(node)
		local types = {
			ConsoleApp  = "com.apple.product-type.tool",
			WindowedApp = "com.apple.product-type.application",
			StaticLib   = "com.apple.product-type.library.static",
			SharedLib   = "com.apple.product-type.library.dynamic",
		}
		return types[node.cfg.kind]
	end


--
-- Return the Xcode target type, based on the target file extension.
--
-- @param node
--    The product node to identify.
-- @returns
--    An Xcode target type, string.
--

	function xcode.gettargettype(node)
		local types = {
			ConsoleApp  = "\"compiled.mach-o.executable\"",
			WindowedApp = "wrapper.application",
			StaticLib   = "archive.ar",
			SharedLib   = "\"compiled.mach-o.dylib\"",
		}
		return types[node.cfg.kind]
	end


--
-- Return a unique file name for a project. Since Xcode uses .xcodeproj's to 
-- represent both solutions and projects there is a likely change of a name
-- collision. Tack on a number to differentiate them.
--
-- @param prj
--    The project being queried.
-- @returns
--    A uniqued file name
--

	function xcode.getxcodeprojname(prj)
		-- if there is a solution with matching name, then use "projectname1.xcodeproj"
		-- just get something working for now
		local fname = premake.project.getfilename(prj, "%%.xcodeproj")
		return fname
	end


--
-- Returns true if the file name represents a framework.
--
-- @param fname
--    The name of the file to test.
--

	function xcode.isframework(fname)
		return (path.getextension(fname) == ".framework")
	end


--
-- Retrieves a unique 12 byte ID for an object. This function accepts and ignores two
-- parameters 'node' and 'usage', which are used by an alternative implementation of
-- this function for testing.
--
-- @returns
--    A 24-character string representing the 12 byte ID.
--

	function xcode.newid()
		return string.format("%04X%04X%04X%04X%04X%04X",
			math.random(0, 32767),
			math.random(0, 32767),
			math.random(0, 32767),
			math.random(0, 32767),
			math.random(0, 32767),
			math.random(0, 32767))
	end


--
-- Create a product tree node and all projects in a solution; assigning IDs 
-- that are needed for inter-project dependencies.
--
-- @param sln
--    The solution to prepare.
--

	function xcode.preparesolution(sln)
		-- create and cache a list of supported platforms
		sln.xcode = { }
		sln.xcode.platforms = premake.filterplatforms(sln, premake.action.current().valid_platforms, "Universal")
		
		for prj in premake.solution.eachproject(sln) do
			-- need a configuration to get the target information
			local cfg = premake.getconfig(prj, prj.configurations[1], sln.xcode.platforms[1])

			-- build the product tree node
			local node = premake.tree.new(path.getname(cfg.buildtarget.bundlepath))
			node.cfg = cfg
			node.id = premake.xcode.newid(node, "product")
			node.targetid = premake.xcode.newid(node, "target")
			
			-- attach it to the project
			prj.xcode = {}
			prj.xcode.projectnode = node
		end
	end


--
-- Print out a list value in the Xcode format.
--
-- @param list
--    The list of values to be printed.
-- @param tag
--    The Xcode specific list tag.
--

	function xcode.printlist(list, tag)
		if #list > 0 then
			_p(4,'%s = (', tag)
			for _, item in ipairs(list) do
				local escaped_item = item:gsub("\"", "\\\"")
				_p(5, '"%s",', escaped_item)
			end
			_p(4,');')
		end
	end


---------------------------------------------------------------------------
-- Section generator functions, in the same order in which they appear
-- in the .pbxproj file
---------------------------------------------------------------------------

	function xcode.Header()
		_p('// !$*UTF8*$!')
		_p('{')
		_p(1,'archiveVersion = 1;')
		_p(1,'classes = {')
		_p(1,'};')
		_p(1,'objectVersion = 45;')
		_p(1,'objects = {')
		_p('')
	end


	function xcode.PBXBuildFile(tr)
		_p('/* Begin PBXBuildFile section */')
		tree.traverse(tr, {
			onnode = function(node)
				if node.buildid then
					_p(2,'%s /* %s in %s */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };', 
						node.buildid, node.name, xcode.getbuildcategory(node), node.id, node.name)
				end
			end
		})
		_p('/* End PBXBuildFile section */')
		_p('')
	end


	function xcode.PBXContainerItemProxy(tr)
		if #tr.projects.children > 0 then
			_p('/* Begin PBXContainerItemProxy section */')
			for _, node in ipairs(tr.projects.children) do
				_p(2,'%s /* PBXContainerItemProxy */ = {', node.productproxyid)
				_p(3,'isa = PBXContainerItemProxy;')
				_p(3,'containerPortal = %s /* %s */;', node.id, path.getname(node.path))
				_p(3,'proxyType = 2;')
				_p(3,'remoteGlobalIDString = %s;', node.project.xcode.projectnode.id)
				_p(3,'remoteInfo = "%s";', node.project.xcode.projectnode.name)
				_p(2,'};')
				_p(2,'%s /* PBXContainerItemProxy */ = {', node.targetproxyid)
				_p(3,'isa = PBXContainerItemProxy;')
				_p(3,'containerPortal = %s /* %s */;', node.id, path.getname(node.path))
				_p(3,'proxyType = 1;')
				_p(3,'remoteGlobalIDString = %s;', node.project.xcode.projectnode.targetid)
				_p(3,'remoteInfo = "%s";', node.project.xcode.projectnode.name)
				_p(2,'};')
			end
			_p('/* End PBXContainerItemProxy section */')
			_p('')
		end
	end


	function xcode.PBXFileReference(tr)
		_p('/* Begin PBXFileReference section */')
		
		tree.traverse(tr, {
			onleaf = function(node)
				-- I'm only listing files here, so ignore anything without a path
				if not node.path then
					return
				end
				
				-- is this the product node, describing the output target?
				if node.kind == "product" then
					_p(2,'%s /* %s */ = {isa = PBXFileReference; explicitFileType = %s; includeInIndex = 0; name = "%s"; path = "%s"; sourceTree = BUILT_PRODUCTS_DIR; };',
						node.id, node.name, xcode.gettargettype(node), node.name, path.getname(node.cfg.buildtarget.bundlepath))
						
				-- is this a project dependency?
				elseif node.parent.parent == tr.projects then
					local relpath = path.getrelative(tr.project.location, node.parent.project.location)
					_p(2,'%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = "wrapper.pb-project"; name = "%s"; path = "%s"; sourceTree = SOURCE_ROOT; };',
						node.parent.id, node.parent.name, node.parent.name, path.join(relpath, node.parent.name))
					
				-- something else
				else
					local pth, src
					if xcode.isframework(node.path) then
						--respect user supplied paths
						-- look for special variable-starting paths for different sources
						local nodePath = node.path
						local _, matchEnd, variable = string.find(nodePath, "^%$%((.+)%)/")
						if variable then
							-- by skipping the last '/' we support the same absolute/relative
							-- paths as before
							nodePath = string.sub(nodePath, matchEnd + 1)
						end
						if string.find(nodePath,'/')  then
							if string.find(nodePath,'^%.')then
								error('relative paths are not currently supported for frameworks')
							end
							pth = nodePath
						else
							pth = "/System/Library/Frameworks/" .. nodePath
						end
						-- if it starts with a variable, use that as the src instead
						if variable then
							src = variable
							-- if we are using a different source tree, it has to be relative
							-- to that source tree, so get rid of any leading '/'
							if string.find(pth, '^/') then
								pth = string.sub(pth, 2)
							end
						else
							src = "<absolute>"
						end
					else
						-- something else; probably a source code file
						src = "<group>"

						-- if the parent node is virtual, it won't have a local path
						-- of its own; need to use full relative path from project
						if node.parent.isvpath then
							pth = node.cfg.name
						else
							pth = tree.getlocalpath(node)
						end
					end
					
					_p(2,'%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = %s; name = "%s"; path = "%s"; sourceTree = "%s"; };',
						node.id, node.name, xcode.getfiletype(node), node.name, pth, src)
				end
			end
		})
		
		_p('/* End PBXFileReference section */')
		_p('')
	end


	function xcode.PBXFrameworksBuildPhase(tr)
		_p('/* Begin PBXFrameworksBuildPhase section */')
		_p(2,'%s /* Frameworks */ = {', tr.products.children[1].fxstageid)
		_p(3,'isa = PBXFrameworksBuildPhase;')
		_p(3,'buildActionMask = 2147483647;')
		_p(3,'files = (')
		
		-- write out library dependencies
		tree.traverse(tr.frameworks, {
			onleaf = function(node)
				_p(4,'%s /* %s in Frameworks */,', node.buildid, node.name)
			end
		})
		
		-- write out project dependencies
		tree.traverse(tr.projects, {
			onleaf = function(node)
				_p(4,'%s /* %s in Frameworks */,', node.buildid, node.name)
			end
		})
		
		_p(3,');')
		_p(3,'runOnlyForDeploymentPostprocessing = 0;')
		_p(2,'};')
		_p('/* End PBXFrameworksBuildPhase section */')
		_p('')
	end


	function xcode.PBXGroup(tr)
		_p('/* Begin PBXGroup section */')

		tree.traverse(tr, {
			onnode = function(node)
				-- Skip over anything that isn't a proper group
				if (node.path and #node.children == 0) or node.kind == "vgroup" then
					return
				end
				
				-- project references get special treatment
				if node.parent == tr.projects then
					_p(2,'%s /* Products */ = {', node.productgroupid)
				else
					_p(2,'%s /* %s */ = {', node.id, node.name)
				end
				
				_p(3,'isa = PBXGroup;')
				_p(3,'children = (')
				for _, childnode in ipairs(node.children) do
					_p(4,'%s /* %s */,', childnode.id, childnode.name)
				end
				_p(3,');')
				
				if node.parent == tr.projects then
					_p(3,'name = Products;')
				else
					_p(3,'name = "%s";', node.name)
					if node.path and not node.isvpath then
						local p = node.path
						if node.parent.path then
							p = path.getrelative(node.parent.path, node.path)
						end
						_p(3,'path = "%s";', p)
					end
				end
				
				_p(3,'sourceTree = "<group>";')
				_p(2,'};')
			end
		}, true)
				
		_p('/* End PBXGroup section */')
		_p('')
	end	


	function xcode.PBXNativeTarget(tr)
		_p('/* Begin PBXNativeTarget section */')
		for _, node in ipairs(tr.products.children) do
			local name = tr.project.name
			
			-- This function checks whether there are build commands of a specific
			-- type to be executed; they will be generated correctly, but the project
			-- commands will not contain any per-configuration commands, so the logic
			-- has to be extended a bit to account for that.
			local function hasBuildCommands(which)
				-- standard check...this is what existed before
				if #tr.project[which] > 0 then
					return true
				end
				-- what if there are no project-level commands? check configs...
				for _, cfg in ipairs(tr.configs) do
					if #cfg[which] > 0 then
						return true
					end
				end
			end
			
			_p(2,'%s /* %s */ = {', node.targetid, name)
			_p(3,'isa = PBXNativeTarget;')
			_p(3,'buildConfigurationList = %s /* Build configuration list for PBXNativeTarget "%s" */;', node.cfgsection, name)
			_p(3,'buildPhases = (')
			if hasBuildCommands('prebuildcommands') then
				_p(4,'9607AE1010C857E500CD1376 /* Prebuild */,')
			end
			_p(4,'%s /* Resources */,', node.resstageid)
			_p(4,'%s /* Sources */,', node.sourcesid)
			if hasBuildCommands('prelinkcommands') then
				_p(4,'9607AE3510C85E7E00CD1376 /* Prelink */,')
			end
			_p(4,'%s /* Frameworks */,', node.fxstageid)
			if hasBuildCommands('postbuildcommands') then
				_p(4,'9607AE3710C85E8F00CD1376 /* Postbuild */,')
			end
			_p(3,');')
			_p(3,'buildRules = (')
			_p(3,');')
			
			_p(3,'dependencies = (')
			for _, node in ipairs(tr.projects.children) do
				_p(4,'%s /* PBXTargetDependency */,', node.targetdependid)
			end
			_p(3,');')
			
			_p(3,'name = "%s";', name)
			
			local p
			if node.cfg.kind == "ConsoleApp" then
				p = "$(HOME)/bin"
			elseif node.cfg.kind == "WindowedApp" then
				p = "$(HOME)/Applications"
			end
			if p then
				_p(3,'productInstallPath = "%s";', p)
			end
			
			_p(3,'productName = "%s";', name)
			_p(3,'productReference = %s /* %s */;', node.id, node.name)
			_p(3,'productType = "%s";', xcode.getproducttype(node))
			_p(2,'};')
		end
		_p('/* End PBXNativeTarget section */')
		_p('')
	end


	function xcode.PBXProject(tr)
		_p('/* Begin PBXProject section */')
		_p(2,'08FB7793FE84155DC02AAC07 /* Project object */ = {')
		_p(3,'isa = PBXProject;')
		_p(3,'buildConfigurationList = 1DEB928908733DD80010E9CD /* Build configuration list for PBXProject "%s" */;', tr.name)
		_p(3,'compatibilityVersion = "Xcode 3.2";')
		_p(3,'hasScannedForEncodings = 1;')
		_p(3,'mainGroup = %s /* %s */;', tr.id, tr.name)
		_p(3,'projectDirPath = "";')
		
		if #tr.projects.children > 0 then
			_p(3,'projectReferences = (')
			for _, node in ipairs(tr.projects.children) do
				_p(4,'{')
				_p(5,'ProductGroup = %s /* Products */;', node.productgroupid)
				_p(5,'ProjectRef = %s /* %s */;', node.id, path.getname(node.path))
				_p(4,'},')
			end
			_p(3,');')
		end
		
		_p(3,'projectRoot = "";')
		_p(3,'targets = (')
		for _, node in ipairs(tr.products.children) do
			_p(4,'%s /* %s */,', node.targetid, node.name)
		end
		_p(3,');')
		_p(2,'};')
		_p('/* End PBXProject section */')
		_p('')
	end


	function xcode.PBXReferenceProxy(tr)
		if #tr.projects.children > 0 then
			_p('/* Begin PBXReferenceProxy section */')
			tree.traverse(tr.projects, {
				onleaf = function(node)
					_p(2,'%s /* %s */ = {', node.id, node.name)
					_p(3,'isa = PBXReferenceProxy;')
					_p(3,'fileType = %s;', xcode.gettargettype(node))
					_p(3,'path = "%s";', node.path)
					_p(3,'remoteRef = %s /* PBXContainerItemProxy */;', node.parent.productproxyid)
					_p(3,'sourceTree = BUILT_PRODUCTS_DIR;')
					_p(2,'};')
				end
			})
			_p('/* End PBXReferenceProxy section */')
			_p('')
		end
	end
	

	function xcode.PBXResourcesBuildPhase(tr)
		_p('/* Begin PBXResourcesBuildPhase section */')
		for _, target in ipairs(tr.products.children) do
			_p(2,'%s /* Resources */ = {', target.resstageid)
			_p(3,'isa = PBXResourcesBuildPhase;')
			_p(3,'buildActionMask = 2147483647;')
			_p(3,'files = (')
			tree.traverse(tr, {
				onnode = function(node)
					if xcode.getbuildcategory(node) == "Resources" then
						_p(4,'%s /* %s in Resources */,', node.buildid, node.name)
					end
				end
			})
			_p(3,');')
			_p(3,'runOnlyForDeploymentPostprocessing = 0;')
			_p(2,'};')
		end
		_p('/* End PBXResourcesBuildPhase section */')
		_p('')
	end
	
	function xcode.PBXShellScriptBuildPhase(tr)
		local wrapperWritten = false

		local function doblock(id, name, which)
			-- start with the project-level commands (most common)
			local prjcmds = tr.project[which]
			local commands = table.join(prjcmds, {})

			-- see if there are any config-specific commands to add
			for _, cfg in ipairs(tr.configs) do
				local cfgcmds = cfg[which]
				if #cfgcmds > #prjcmds then
					table.insert(commands, 'if [ "${CONFIGURATION}" = "' .. xcode.getconfigname(cfg) .. '" ]; then')
					for i = #prjcmds + 1, #cfgcmds do
						table.insert(commands, cfgcmds[i])
					end
					table.insert(commands, 'fi')
				end
			end
			
			if #commands > 0 then
				if not wrapperWritten then
					_p('/* Begin PBXShellScriptBuildPhase section */')
					wrapperWritten = true
				end
				_p(2,'%s /* %s */ = {', id, name)
				_p(3,'isa = PBXShellScriptBuildPhase;')
				_p(3,'buildActionMask = 2147483647;')
				_p(3,'files = (')
				_p(3,');')
				_p(3,'inputPaths = (');
				_p(3,');');
				_p(3,'name = %s;', name);
				_p(3,'outputPaths = (');
				_p(3,');');
				_p(3,'runOnlyForDeploymentPostprocessing = 0;');
				_p(3,'shellPath = /bin/sh;');
				_p(3,'shellScript = "%s";', table.concat(commands, "\\n"):gsub('"', '\\"'))
				_p(2,'};')
			end
		end
				
		doblock("9607AE1010C857E500CD1376", "Prebuild", "prebuildcommands")
		doblock("9607AE3510C85E7E00CD1376", "Prelink", "prelinkcommands")
		doblock("9607AE3710C85E8F00CD1376", "Postbuild", "postbuildcommands")
		
		if wrapperWritten then
			_p('/* End PBXShellScriptBuildPhase section */')
		end
	end
	
	
	function xcode.PBXSourcesBuildPhase(tr)
		_p('/* Begin PBXSourcesBuildPhase section */')
		for _, target in ipairs(tr.products.children) do
			_p(2,'%s /* Sources */ = {', target.sourcesid)
			_p(3,'isa = PBXSourcesBuildPhase;')
			_p(3,'buildActionMask = 2147483647;')
			_p(3,'files = (')
			tree.traverse(tr, {
				onleaf = function(node)
					if xcode.getbuildcategory(node) == "Sources" then
						_p(4,'%s /* %s in Sources */,', node.buildid, node.name)
					end
				end
			})
			_p(3,');')
			_p(3,'runOnlyForDeploymentPostprocessing = 0;')
			_p(2,'};')
		end
		_p('/* End PBXSourcesBuildPhase section */')
		_p('')
	end


	function xcode.PBXVariantGroup(tr)
		_p('/* Begin PBXVariantGroup section */')
		tree.traverse(tr, {
			onbranch = function(node)
				if node.kind == "vgroup" then
					_p(2,'%s /* %s */ = {', node.id, node.name)
					_p(3,'isa = PBXVariantGroup;')
					_p(3,'children = (')
					for _, lang in ipairs(node.children) do
						_p(4,'%s /* %s */,', lang.id, lang.name)
					end
					_p(3,');')
					_p(3,'name = %s;', node.name)
					_p(3,'sourceTree = "<group>";')
					_p(2,'};')
				end
			end
		})
		_p('/* End PBXVariantGroup section */')
		_p('')
	end


	function xcode.PBXTargetDependency(tr)
		if #tr.projects.children > 0 then
			_p('/* Begin PBXTargetDependency section */')
			tree.traverse(tr.projects, {
				onleaf = function(node)
					_p(2,'%s /* PBXTargetDependency */ = {', node.parent.targetdependid)
					_p(3,'isa = PBXTargetDependency;')
					_p(3,'name = "%s";', node.name)
					_p(3,'targetProxy = %s /* PBXContainerItemProxy */;', node.parent.targetproxyid)
					_p(2,'};')
				end
			})
			_p('/* End PBXTargetDependency section */')
			_p('')
		end
	end


	function xcode.XCBuildConfiguration_Target(tr, target, cfg)
		local cfgname = xcode.getconfigname(cfg)
		
		_p(2,'%s /* %s */ = {', cfg.xcode.targetid, cfgname)
		_p(3,'isa = XCBuildConfiguration;')
		_p(3,'buildSettings = {')
		_p(4,'ALWAYS_SEARCH_USER_PATHS = NO;')

		if not cfg.flags.Symbols then
			_p(4,'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";')
		end
		
		if cfg.kind ~= "StaticLib" and cfg.buildtarget.prefix ~= "" then
			_p(4,'EXECUTABLE_PREFIX = %s;', cfg.buildtarget.prefix)
		end
		
		if cfg.targetextension then
			local ext = cfg.targetextension
			ext = iif(ext:startswith("."), ext:sub(2), ext)
			_p(4,'EXECUTABLE_EXTENSION = %s;', ext)
		end

		local outdir = path.getdirectory(cfg.buildtarget.bundlepath)
		if outdir ~= "." then
			_p(4,'CONFIGURATION_BUILD_DIR = %s;', outdir)
		end

		_p(4,'GCC_DYNAMIC_NO_PIC = NO;')
		_p(4,'GCC_MODEL_TUNING = G5;')

		if tr.infoplist then
			_p(4,'INFOPLIST_FILE = "%s";', tr.infoplist.cfg.name)
		end

		installpaths = {
			ConsoleApp = '/usr/local/bin',
			WindowedApp = '"$(HOME)/Applications"',
			SharedLib = '/usr/local/lib',
			StaticLib = '/usr/local/lib',
		}
		_p(4,'INSTALL_PATH = %s;', installpaths[cfg.kind])

		_p(4,'PRODUCT_NAME = "%s";', cfg.buildtarget.basename)
		_p(3,'};')
		_p(3,'name = "%s";', cfgname)
		_p(2,'};')
	end
	
	
	function xcode.XCBuildConfiguration_Project(tr, cfg)
		local cfgname = xcode.getconfigname(cfg)

		_p(2,'%s /* %s */ = {', cfg.xcode.projectid, cfgname)
		_p(3,'isa = XCBuildConfiguration;')
		_p(3,'buildSettings = {')
		
		local archs = {
			Native = "$(NATIVE_ARCH_ACTUAL)",
			x32    = "i386",
			x64    = "x86_64",
			Universal32 = "$(ARCHS_STANDARD_32_BIT)",
			Universal64 = "$(ARCHS_STANDARD_64_BIT)",
			Universal = "$(ARCHS_STANDARD_32_64_BIT)",
		}
		_p(4,'ARCHS = "%s";', archs[cfg.platform])
		
		local targetdir = path.getdirectory(cfg.buildtarget.bundlepath)
		if targetdir ~= "." then
			_p(4,'CONFIGURATION_BUILD_DIR = "$(SYMROOT)";');
		end
		
		_p(4,'CONFIGURATION_TEMP_DIR = "$(OBJROOT)";')
		
		if cfg.flags.Symbols then
			_p(4,'COPY_PHASE_STRIP = NO;')
		end
		
		_p(4,'GCC_C_LANGUAGE_STANDARD = gnu99;')
		
		if cfg.flags.NoExceptions then
			_p(4,'GCC_ENABLE_CPP_EXCEPTIONS = NO;')
		end
		
		if cfg.flags.NoRTTI then
			_p(4,'GCC_ENABLE_CPP_RTTI = NO;')
		end
		
		if _ACTION ~= "xcode4" and cfg.flags.Symbols and not cfg.flags.NoEditAndContinue then
			_p(4,'GCC_ENABLE_FIX_AND_CONTINUE = YES;')
		end
		
		if cfg.flags.NoExceptions then
			_p(4,'GCC_ENABLE_OBJC_EXCEPTIONS = NO;')
		end
		
		if cfg.flags.Optimize or cfg.flags.OptimizeSize then
			_p(4,'GCC_OPTIMIZATION_LEVEL = s;')
		elseif cfg.flags.OptimizeSpeed then
			_p(4,'GCC_OPTIMIZATION_LEVEL = 3;')
		else
			_p(4,'GCC_OPTIMIZATION_LEVEL = 0;')
		end
		
		if cfg.pchheader and not cfg.flags.NoPCH then
			_p(4,'GCC_PRECOMPILE_PREFIX_HEADER = YES;')
			_p(4,'GCC_PREFIX_HEADER = "%s";', cfg.pchheader)
		end
		
		xcode.printlist(cfg.defines, 'GCC_PREPROCESSOR_DEFINITIONS')

		_p(4,'GCC_SYMBOLS_PRIVATE_EXTERN = NO;')
		
		if cfg.flags.FatalWarnings then
			_p(4,'GCC_TREAT_WARNINGS_AS_ERRORS = YES;')
		end
		
		_p(4,'GCC_WARN_ABOUT_RETURN_TYPE = YES;')
		_p(4,'GCC_WARN_UNUSED_VARIABLE = YES;')

		xcode.printlist(cfg.includedirs, 'HEADER_SEARCH_PATHS')
		xcode.printlist(cfg.libdirs, 'LIBRARY_SEARCH_PATHS')
		xcode.printlist(cfg.frameworkdirs, 'FRAMEWORK_SEARCH_PATHS')
		
		_p(4,'OBJROOT = "%s";', cfg.objectsdir)

		_p(4,'ONLY_ACTIVE_ARCH = %s;',iif(premake.config.isdebugbuild(cfg),'YES','NO'))
		
		-- build list of "other" C/C++ flags
		local checks = {
			["-ffast-math"]          = cfg.flags.FloatFast,
			["-ffloat-store"]        = cfg.flags.FloatStrict,
			["-fomit-frame-pointer"] = cfg.flags.NoFramePointer,
		}
			
		local flags = { }
		for flag, check in pairs(checks) do
			if check then
				table.insert(flags, flag)
			end
		end
		xcode.printlist(table.join(flags, cfg.buildoptions), 'OTHER_CFLAGS')

		-- build list of "other" linked flags. All libraries that aren't frameworks
		-- are listed here, so I don't have to try and figure out if they are ".a"
		-- or ".dylib", which Xcode requires to list in the Frameworks section
		flags = { }
		for _, lib in ipairs(premake.getlinks(cfg, "system")) do
			if not xcode.isframework(lib) then
				table.insert(flags, "-l" .. lib)
			end
		end
		flags = table.join(flags, cfg.linkoptions)
		xcode.printlist(flags, 'OTHER_LDFLAGS')
		
		if cfg.flags.StaticRuntime then
			_p(4,'STANDARD_C_PLUS_PLUS_LIBRARY_TYPE = static;')
		end
		
		if targetdir ~= "." then
			_p(4,'SYMROOT = "%s";', targetdir)
		end
		
		if cfg.flags.ExtraWarnings then
			_p(4,'WARNING_CFLAGS = "-Wall";')
		end
		
		_p(3,'};')
		_p(3,'name = "%s";', cfgname)
		_p(2,'};')
	end


	function xcode.XCBuildConfiguration(tr)
		_p('/* Begin XCBuildConfiguration section */')
		for _, target in ipairs(tr.products.children) do
			for _, cfg in ipairs(tr.configs) do
				xcode.XCBuildConfiguration_Target(tr, target, cfg)
			end
		end
		for _, cfg in ipairs(tr.configs) do
			xcode.XCBuildConfiguration_Project(tr, cfg)
		end
		_p('/* End XCBuildConfiguration section */')
		_p('')
	end


	function xcode.XCBuildConfigurationList(tr)
		local sln = tr.project.solution
		
		_p('/* Begin XCConfigurationList section */')
		for _, target in ipairs(tr.products.children) do
			_p(2,'%s /* Build configuration list for PBXNativeTarget "%s" */ = {', target.cfgsection, target.name)
			_p(3,'isa = XCConfigurationList;')
			_p(3,'buildConfigurations = (')
			for _, cfg in ipairs(tr.configs) do
				_p(4,'%s /* %s */,', cfg.xcode.targetid, xcode.getconfigname(cfg))
			end
			_p(3,');')
			_p(3,'defaultConfigurationIsVisible = 0;')
			_p(3,'defaultConfigurationName = "%s";', xcode.getconfigname(tr.configs[1]))
			_p(2,'};')
		end
		_p(2,'1DEB928908733DD80010E9CD /* Build configuration list for PBXProject "%s" */ = {', tr.name)
		_p(3,'isa = XCConfigurationList;')
		_p(3,'buildConfigurations = (')
		for _, cfg in ipairs(tr.configs) do
			_p(4,'%s /* %s */,', cfg.xcode.projectid, xcode.getconfigname(cfg))
		end
		_p(3,');')
		_p(3,'defaultConfigurationIsVisible = 0;')
		_p(3,'defaultConfigurationName = "%s";', xcode.getconfigname(tr.configs[1]))
		_p(2,'};')
		_p('/* End XCConfigurationList section */')
		_p('')
	end


	function xcode.Footer()
		_p(1,'};')
		_p('\trootObject = 08FB7793FE84155DC02AAC07 /* Project object */;')
		_p('}')
	end
-- AMALGAMATE FILE TAIL : /src/actions/xcode/xcode_common.lua
-- AMALGAMATE FILE HEAD : /src/actions/xcode/xcode_project.lua
--
-- xcode_project.lua
-- Generate an Xcode C/C++ project.
-- Copyright (c) 2009 Jason Perkins and the Premake project
--

	local xcode = premake.xcode
	local tree = premake.tree

--
-- Create a tree corresponding to what is shown in the Xcode project browser
-- pane, with nodes for files and folders, resources, frameworks, and products.
--
-- @param prj
--    The project being generated.
-- @returns
--    A tree, loaded with metadata, which mirrors Xcode's view of the project.
--

	function xcode.buildprjtree(prj)
		local tr = premake.project.buildsourcetree(prj)
		
		-- create a list of build configurations and assign IDs
		tr.configs = {}
		for _, cfgname in ipairs(prj.solution.configurations) do
			for _, platform in ipairs(prj.solution.xcode.platforms) do
				local cfg = premake.getconfig(prj, cfgname, platform)
				cfg.xcode = {}
				cfg.xcode.targetid = xcode.newid(prj.xcode.projectnode, cfgname)
				cfg.xcode.projectid = xcode.newid(tr, cfgname)
				table.insert(tr.configs, cfg)
			end
		end
		
		-- convert localized resources from their filesystem layout (English.lproj/MainMenu.xib)
		-- to Xcode's display layout (MainMenu.xib/English).
		tree.traverse(tr, {
			onbranch = function(node)
				if path.getextension(node.name) == ".lproj" then
					local lang = path.getbasename(node.name)  -- "English", "French", etc.
					
					-- create a new language group for each file it contains
					for _, filenode in ipairs(node.children) do
						local grpnode = node.parent.children[filenode.name]
						if not grpnode then
							grpnode = tree.insert(node.parent, tree.new(filenode.name))
							grpnode.kind = "vgroup"
						end
						
						-- convert the file node to a language node and add to the group
						filenode.name = path.getbasename(lang)
						tree.insert(grpnode, filenode)
					end
					
					-- remove this directory from the tree
					tree.remove(node)
				end
			end
		})
		
		-- the special folder "Frameworks" lists all linked frameworks
		tr.frameworks = tree.new("Frameworks")
		for cfg in premake.eachconfig(prj) do
			for _, link in ipairs(premake.getlinks(cfg, "system", "fullpath")) do
				local name = path.getname(link)
				if xcode.isframework(name) and not tr.frameworks.children[name] then
					node = tree.insert(tr.frameworks, tree.new(name))
					node.path = link
				end
			end
		end
		
		-- only add it to the tree if there are frameworks to link
		if #tr.frameworks.children > 0 then 
			tree.insert(tr, tr.frameworks)
		end
		
		-- the special folder "Products" holds the target produced by the project; this
		-- is populated below
		tr.products = tree.insert(tr, tree.new("Products"))

		-- the special folder "Projects" lists sibling project dependencies
		tr.projects = tree.new("Projects")
		for _, dep in ipairs(premake.getdependencies(prj, "sibling", "object")) do
			-- create a child node for the dependency's xcodeproj
			local xcpath = xcode.getxcodeprojname(dep)
			local xcnode = tree.insert(tr.projects, tree.new(path.getname(xcpath)))
			xcnode.path = xcpath
			xcnode.project = dep
			xcnode.productgroupid = xcode.newid(xcnode, "prodgrp")
			xcnode.productproxyid = xcode.newid(xcnode, "prodprox")
			xcnode.targetproxyid  = xcode.newid(xcnode, "targprox")
			xcnode.targetdependid = xcode.newid(xcnode, "targdep")
			
			-- create a grandchild node for the dependency's link target
			local cfg = premake.getconfig(dep, prj.configurations[1])
			node = tree.insert(xcnode, tree.new(cfg.linktarget.name))
			node.path = cfg.linktarget.fullpath
			node.cfg = cfg
		end

		if #tr.projects.children > 0 then
			tree.insert(tr, tr.projects)
		end

		-- Final setup
		tree.traverse(tr, {
			onnode = function(node)
				-- assign IDs to every node in the tree
				node.id = xcode.newid(node)
				
				-- assign build IDs to buildable files
				if xcode.getbuildcategory(node) then
					node.buildid = xcode.newid(node, "build")
				end

				-- remember key files that are needed elsewhere
				if string.endswith(node.name, "Info.plist") then
					tr.infoplist = node
				end						
			end
		}, true)

		-- Plug in the product node into the Products folder in the tree. The node
		-- was built in xcode.preparesolution() in xcode_common.lua; it contains IDs
		-- that are necessary for inter-project dependencies
		node = tree.insert(tr.products, prj.xcode.projectnode)
		node.kind = "product"
		node.path = node.cfg.buildtarget.fullpath
		node.cfgsection = xcode.newid(node, "cfg")
		node.resstageid = xcode.newid(node, "rez")
		node.sourcesid  = xcode.newid(node, "src")
		node.fxstageid  = xcode.newid(node, "fxs")

		return tr
	end


--
-- Generate an Xcode .xcodeproj for a Premake project.
--
-- @param prj
--    The Premake project to generate.
--

	function premake.xcode.project(prj)
		local tr = xcode.buildprjtree(prj)
		xcode.Header(tr)
		xcode.PBXBuildFile(tr)
		xcode.PBXContainerItemProxy(tr)
		xcode.PBXFileReference(tr)
		xcode.PBXFrameworksBuildPhase(tr)
		xcode.PBXGroup(tr)
		xcode.PBXNativeTarget(tr)
		xcode.PBXProject(tr)
		xcode.PBXReferenceProxy(tr)
		xcode.PBXResourcesBuildPhase(tr)
		xcode.PBXShellScriptBuildPhase(tr)
		xcode.PBXSourcesBuildPhase(tr)
		xcode.PBXVariantGroup(tr)
		xcode.PBXTargetDependency(tr)
		xcode.XCBuildConfiguration(tr)
		xcode.XCBuildConfigurationList(tr)
		xcode.Footer(tr)
	end
-- AMALGAMATE FILE TAIL : /src/actions/xcode/xcode_project.lua
-- AMALGAMATE FILE HEAD : /src/actions/xcode/xcode4_workspace.lua
premake.xcode4 = {}

local xcode4 = premake.xcode4

function xcode4.workspace_head()
	_p('<?xml version="1.0" encoding="UTF-8"?>')
	_p('<Workspace')
		_p(1,'version = "1.0">')

end

function xcode4.workspace_tail()
	_p('</Workspace>')
end

function xcode4.workspace_file_ref(prj)

		local projpath = path.getrelative(prj.solution.location, prj.location)
		if projpath == '.' then projpath = '' 
		else projpath = projpath ..'/' 
		end
		_p(1,'<FileRef')
			_p(2,'location = "group:%s">',projpath .. prj.name .. '.xcodeproj')
		_p(1,'</FileRef>')
end

function xcode4.workspace_generate(sln)
	premake.xcode.preparesolution(sln)

	xcode4.workspace_head()

	for prj in premake.solution.eachproject(sln) do
		xcode4.workspace_file_ref(prj)
	end
	
	xcode4.workspace_tail()
end



-- AMALGAMATE FILE TAIL : /src/actions/xcode/xcode4_workspace.lua
-- AMALGAMATE FILE HEAD : /src/actions/clean/_clean.lua
--
-- _clean.lua
-- The "clean" action: removes all generated files.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--

	premake.clean = { }


--
-- Clean a solution or project specific directory. Uses information in the
-- project object to build the target path.
--
-- @param obj
--    A solution or project object.
-- @param pattern
--    A filename pattern to clean; see premake.project.getfilename() for
--    a description of the format.
--

	function premake.clean.directory(obj, pattern)
		local fname = premake.project.getfilename(obj, pattern)
		os.rmdir(fname)
	end


--
-- Clean a solution or project specific file. Uses information in the project
-- object to build the target filename.
--
-- @param obj
--    A solution or project object.
-- @param pattern
--    A filename pattern to clean; see premake.project.getfilename() for
--    a description of the format.
--

	function premake.clean.file(obj, pattern)
		local fname = premake.project.getfilename(obj, pattern)
		os.remove(fname)
	end


--
-- Register the "clean" action.
--

	newaction {
		trigger     = "clean",
		description = "Remove all binaries and generated files",

		onsolution = function(sln)
			for action in premake.action.each() do
				if action.oncleansolution then
					action.oncleansolution(sln)
				end
			end
		end,
		
		onproject = function(prj)
			for action in premake.action.each() do
				if action.oncleanproject then
					action.oncleanproject(prj)
				end
			end

			if (prj.objectsdir) then
				premake.clean.directory(prj, prj.objectsdir)
			end

			-- build a list of supported target platforms that also includes a generic build
			local platforms = prj.solution.platforms or { }
			if not table.contains(platforms, "Native") then
				platforms = table.join(platforms, { "Native" })
			end

			for _, platform in ipairs(platforms) do
				for cfg in premake.eachconfig(prj, platform) do
					premake.clean.directory(prj, cfg.objectsdir)

					-- remove all permutations of the target binary
					premake.clean.file(prj, premake.gettarget(cfg, "build", "posix", "windows", "windows").fullpath)
					premake.clean.file(prj, premake.gettarget(cfg, "build", "posix", "posix", "linux").fullpath)
					premake.clean.file(prj, premake.gettarget(cfg, "build", "posix", "posix", "macosx").fullpath)
					premake.clean.file(prj, premake.gettarget(cfg, "build", "posix", "PS3", "windows").fullpath)
					if cfg.kind == "WindowedApp" then
						premake.clean.directory(prj, premake.gettarget(cfg, "build", "posix", "posix", "linux").fullpath .. ".app")
					end

					-- if there is an import library, remove that too
					premake.clean.file(prj, premake.gettarget(cfg, "link", "windows", "windows", "windows").fullpath)
					premake.clean.file(prj, premake.gettarget(cfg, "link", "posix", "posix", "linux").fullpath)

					-- call action.oncleantarget() with the undecorated target name
					local target = path.join(premake.project.getfilename(prj, cfg.buildtarget.directory), cfg.buildtarget.basename)
					for action in premake.action.each() do
						if action.oncleantarget then
							action.oncleantarget(target)
						end
					end
				end
			end
		end
	}
-- AMALGAMATE FILE TAIL : /src/actions/clean/_clean.lua
-- AMALGAMATE FILE HEAD : /src/_premake_main.lua
--
-- _premake_main.lua
-- Script-side entry point for the main program logic.
-- Copyright (c) 2002-2011 Jason Perkins and the Premake project
--

	local lfs = require("lfs")

	local scriptfile    = "premake4.lua"
	local shorthelp     = "Type 'puremake --help' for help"
	local versionhelp   = "puremake (Premake Build Script Generator) %s"
	
	_WORKING_DIR        = lfs.currentdir()


--
-- Inject a new target platform into each solution; called if the --platform
-- argument was specified on the command line.
--

	local function injectplatform(platform)
		if not platform then return true end
		platform = premake.checkvalue(platform, premake.fields.platforms.allowed)
		
		for sln in premake.solution.each() do
			local platforms = sln.platforms or { }
			
			-- an empty table is equivalent to a native build
			if #platforms == 0 then
				table.insert(platforms, "Native")
			end
			
			-- the solution must provide a native build in order to support this feature
			if not table.contains(platforms, "Native") then
				return false, sln.name .. " does not target native platform\nNative platform settings are required for the --platform feature."
			end
			
			-- add it to the end of the list, if it isn't in there already
			if not table.contains(platforms, platform) then
				table.insert(platforms, platform)
			end
			
			sln.platforms = platforms
		end
		
		return true
	end
	

--
-- Script-side program entry point.
--

	function _premake_main(scriptpath)
		
		-- if running off the disk (in debug mode), load everything 
		-- listed in _manifest.lua; the list divisions make sure
		-- everything gets initialized in the proper order.
		
		if (scriptpath) then
			local scripts  = dofile(scriptpath .. "/_manifest.lua")
			for _,v in ipairs(scripts) do
				dofile(scriptpath .. "/" .. v)
			end
		end
		

		-- Now that the scripts are loaded, I can use path.getabsolute() to properly
		-- canonicalize the executable path.
		
		_PREMAKE_COMMAND = path.getabsolute(_PREMAKE_COMMAND)


		-- Set up the environment for the chosen action early, so side-effects
		-- can be picked up by the scripts.

		premake.action.set(_ACTION)

		
		-- Seed the random number generator so actions don't have to do it themselves
		
		math.randomseed(os.time())
		
		
		-- If there is a project script available, run it to get the
		-- project information, available options and actions, etc.
		
		local fname = _OPTIONS["file"] or scriptfile
		if (os.isfile(fname)) then
			dofile(fname)
		end


		-- Process special options
		
		if (_OPTIONS["version"]) then
			printf(versionhelp, _PREMAKE_VERSION)
			return 1
		end
		
		if (_OPTIONS["help"]) then
			premake.showhelp()
			return 1
		end
		
			
		-- If no action was specified, show a short help message
		
		if (not _ACTION) then
			print(shorthelp)
			return 1
		end

		
		-- If there wasn't a project script I've got to bail now
		
		if (not os.isfile(fname)) then
			error("No Premake script ("..scriptfile..") found!", 2)
		end

		
		-- Validate the command-line arguments. This has to happen after the
		-- script has run to allow for project-specific options
		
		action = premake.action.current()
		if (not action) then
			error("Error: no such action '" .. _ACTION .. "'", 0)
		end

		ok, err = premake.option.validate(_OPTIONS)
		if (not ok) then error("Error: " .. err, 0) end
		

		-- Sanity check the current project setup

		ok, err = premake.checktools()
		if (not ok) then error("Error: " .. err, 0) end
		
		
		-- If a platform was specified on the command line, inject it now

		ok, err = injectplatform(_OPTIONS["platform"])
		if (not ok) then error("Error: " .. err, 0) end

		
		-- work-in-progress: build the configurations
		print("Building configurations...")
		premake.bake.buildconfigs()
		
		ok, err = premake.checkprojects()
		if (not ok) then error("Error: " .. err, 0) end
		
		
		-- Hand over control to the action
		printf("Running action '%s'...", action.trigger)
		premake.action.call(action.trigger)

		print("Done.")
		return 0

	end
	
-- AMALGAMATE FILE TAIL : /src/_premake_main.lua
-- AMALGAMATE FILE HEAD : /src/host/main.lua

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

-- AMALGAMATE FILE TAIL : /src/host/main.lua
