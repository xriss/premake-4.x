


local pmstring=require("puremake.string")
local pmos=require("puremake.os")


local M={} ; package.loaded[(...)]=M ; M.module_name=(...)
local path=M






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
local wpath={}

-- a soft require of lfs so lfs can be nil
local lfs=select(2,pcall( function() return require("lfs_any") end ))


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
		local i = pmstring.findlast(name,".", true)
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
		local i = pmstring.findlast(p,"/", true)
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
		local i = pmstring.findlast(p,".", true)
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
		local i = pmstring.findlast(p,"[/\\]")
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


