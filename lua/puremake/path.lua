

local wpath=require("wetgenes.path")

local pmstring=require("puremake.string")
local pmos=require("puremake.os")


local M={} ; package.loaded[(...)]=M ; M.module_name=(...)
local path=M


path.getrelative=function(a,b)

	local r=wpath.relative(a,b)

--print("R",a,b,r)
	
	if r:sub(1,2)=="./" then r=r:sub(3) end
	if r:sub(-1)=="/" then r=r:sub(1,-2) end

	return r
end

path.getabsolute=function(p)

	local r
	if p:sub(1,1)=="$" then
		r=wpath.normalize(p)
	else
		r=wpath.resolve(p)
	end
	
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


