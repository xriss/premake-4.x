
local M={} ; package.loaded[(...)]=M ; M.module_name=(...)
setmetatable(M,{__index=os}) -- use os as prototype
local pmos=M


pmos.mkdir=function(s)
	return lfs.mkdir(s)
end

pmos.chdir=function(s)
--pmos.print("CD",s)
	return lfs.chdir(s)
end

pmos.isdir=function(s)
	local a=lfs.attributes(s)
	if a and a.mode=="directory" then return true end
	return false
end

pmos.pathsearch=function(name,...)
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
				if pmos.isfile(t) then return n end
			end
		end
	end

-- pmos.print("FUNCTION","pmos."..debug.getinfo(1).name)

end


pmos.matchstart=function(p)
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

--	pmos.print("FUNCTION","pmos."..debug.getinfo(1).name,p,it.pd,it.pf)
		
	return it
end
pmos.matchdone=function()end

pmos.matchnext=function(it)
--	pmos.print("FUNCTION","pmos."..debug.getinfo(1).name,it)
	
	if not it.dir_func then return nil end -- no dir
	
	while true do
		it.filename=it.dir_func(it.dir_data)


		if not it.filename then return nil end -- end

		if it.filename~="." and it.filename~=".." then 
			if it.filename:match(it.pf) then
--				pmos.print(it.filename)
				return true
			end -- a match
		end
	end
	
end

pmos.matchname=function(it)

--	pmos.print("FUNCTION","pmos."..debug.getinfo(1).name,it.pd..it.filename)
	
	return it.filename	

end



pmos.matchisfile=function(it)

--	pmos.print("FUNCTION","pmos."..debug.getinfo(1).name,it.pd..it.filename,pmos.isfile( pmos.matchname(it)))
	
	return pmos.isfile( path.join( it.pd , it.filename) )

end

pmos.uuid=function()

	local r=string.format("%04X%04X-%04X-%04X-%04X-%04X%04X%04X",
		math.random(0,0xffff),math.random(0,0xffff),
		math.random(0,0xffff),math.random(0,0xffff),math.random(0,0xffff),
		math.random(0,0xffff),math.random(0,0xffff),math.random(0,0xffff))
		
--	pmos.print("FUNCTION","pmos."..debug.getinfo(1).name,r)

	return r
end



pmos.getcwd=function()

--	pmos.print("FUNCTION","pmos."..debug.getinfo(1).name)
	
	return lfs.currentdir()
	
end

pmos.isfile=function(a)

	local r=lfs.attributes(a,'mode')=="file"

--	pmos.print("FUNCTION","pmos."..debug.getinfo(1).name,a,r)
	
	return r
end


pmos.locate=function(...)

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
--	pmos.print("FUNCTION","pmos."..debug.getinfo(1).name,a,r)

	return nil
end




--
-- pmos.lua
-- Additions to the pmos namespace.
-- Copyright (c) 2002-2011 Jason Perkins and the Premake project
--


--
-- Same as pmos.execute(), but accepts string formatting arguments.
--

	function pmos.executef(cmd, ...)
		cmd = string.format(cmd,...)
		return pmos.execute(cmd)
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
					local includes = pmos.matchfiles(include_glob)
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

	function pmos.findlib(libname)
		local path, formats

		-- assemble a search path, depending on the platform
		if pmos.is("windows") then
			formats = { "%s.dll", "%s" }
			path = pmos.getenv("PATH")
		elseif pmos.is("haiku") then
			formats = { "lib%s.so", "%s.so" }
			path = pmos.getenv("LIBRARY_PATH")
		else
			if pmos.is("macpmosx") then
				formats = { "lib%s.dylib", "%s.dylib" }
				path = pmos.getenv("DYLD_LIBRARY_PATH")
			else
				formats = { "lib%s.so", "%s.so" }
				path = pmos.getenv("LD_LIBRARY_PATH") or ""

				for _, v in ipairs(parse_ld_so_conf("/etc/ld.so.conf")) do
					path = path .. ":" .. v
				end
			end

			table.insert(formats, "%s")
			path = path or ""
			if pmos.is64bit() then
				path = path .. ":/lib64:/usr/lib64/:usr/local/lib64"
			end
			path = path .. ":/lib:/usr/lib:/usr/local/lib"
		end

		for _, fmt in ipairs(formats) do
			local name = string.format(fmt, libname)
			local result = pmos.pathsearch(name, path)
			if result then return result end
		end
	end



--
-- Retrieve the current operating system ID string.
--

	function pmos.get()
		return _OPTIONS.os or _OS
	end



--
-- Check the current operating system; may be set with the /pmos command line flag.
--

	function pmos.is(id)
		return (pmos.get():lower() == id:lower())
	end



--
-- Determine if the current system is running a 64-bit architecture
--

	local _64BitHpmostTypes = {
		"x86_64",
		"ia64",
		"amd64",
		"ppc64",
		"powerpc64",
		"sparc64"
	}

	function pmos.is64bit()
		-- Call the native code implementation. If this returns true then
		-- we're 64-bit, otherwise do more checking locally
--		if (pmos._is64bit()) then
--			return true
--		end

		-- Identify the system
		local arch
		if _pmos == "windows" then
			arch = pmos.getenv("PROCESSOR_ARCHITECTURE")
		elseif _pmos == "macpmosx" then
			arch = pmos.outputof("echo $HpmosTTYPE")
		else
			arch = pmos.outputof("uname -m")
		end

		-- Check our known 64-bit identifiers
		arch = arch:lower()
		for _, hpmosttype in ipairs(_64BitHpmostTypes) do
			if arch:find(hpmosttype) then
				return true
			end
		end
		return false
	end



--
-- The pmos.matchdirs() and pmos.matchfiles() functions
--

	local function domatch(result, mask, wantfiles)
		-- need to remove extraneous path info from the mask to ensure a match
		-- against the paths returned by the pmos. Haven't come up with a good
		-- way to do it yet, so will handle cases as they come up
		if mask:startswith("./") then
			mask = mask:sub(3)
		end

		-- strip off any leading directory information to find out
		-- where the search should take place
		local basedir = mask
		local starppmos = mask:find("%*")
		if starppmos then
			basedir = basedir:sub(1, starppmos - 1)
		end
		basedir = path.getdirectory(basedir)

		-- recurse into subdirectories?
		local recurse = mask:find("**", nil, true)

		-- convert mask to a Lua pattern
		mask = path.wildcards(mask)

		local function matchwalker(basedir)
			local wildcard = path.join(basedir, "*")
			-- retrieve files from pmos and test against mask
			local m = pmos.matchstart(wildcard)
			while (pmos.matchnext(m)) do
				local isfile = pmos.matchisfile(m)
				if ((wantfiles and isfile) or (not wantfiles and not isfile)) then
					local basename = pmos.matchname(m)
					local fullname = path.join(basedir, basename)
					if basename ~= ".." and fullname:match(mask) == fullname then
						table.insert(result, fullname)
					end
				end
			end
			pmos.matchdone(m)

			-- check subdirectories
			if recurse then
				m = pmos.matchstart(wildcard)
				while (pmos.matchnext(m)) do
					if not pmos.matchisfile(m) then
						local dirname = pmos.matchname(m)
						if (not dirname:startswith(".")) then
							matchwalker(path.join(basedir, dirname))
						end
					end
				end
				pmos.matchdone(m)
			end
		end

		matchwalker(basedir)
	end

	function pmos.matchdirs(...)
		local result = { }
		for _, mask in ipairs({...}) do
			domatch(result, mask, false)
		end
		return result
	end

	function pmos.matchfiles(...)
		local result = { }
		for _, mask in ipairs({...}) do
			domatch(result, mask, true)
		end
		return result
	end



--
-- An overload of the pmos.mkdir() function, which will create any missing
-- subdirectories along the path.
--

	local builtin_mkdir = pmos.mkdir
	function pmos.mkdir(p)
		local dir = iif(p:startswith("/"), "/", "")
		for part in p:gmatch("[^/]+") do
			dir = dir .. part

			if (part ~= "" and not path.isabsolute(part) and not pmos.isdir(dir)) then
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

	function pmos.outputof(cmd)
		local pipe = io.popen(cmd)
		local result = pipe:read('*a')
		pipe:close()
		return result
	end


--
-- Remove a directory, along with any contained files or subdirectories.
--

	local builtin_rmdir = pmos.rmdir
	function pmos.rmdir(p)
		-- recursively remove subdirectories
		local dirs = pmos.matchdirs(p .. "/*")
		for _, dname in ipairs(dirs) do
			pmos.rmdir(dname)
		end

		-- remove any files
		local files = pmos.matchfiles(p .. "/*")
		for _, fname in ipairs(files) do
			pmos.remove(fname)
		end

		-- remove this directory
		builtin_rmdir(p)
	end


	
	

