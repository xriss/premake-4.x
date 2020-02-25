
os=os or {}

os.mkdir=function(s)
	return lfs.mkdir(s)
end

os.chdir=function(s)
	return lfs.chdir(s)
end

os.isdir=function(s)
	local a=lfs.attributes(s)
	if a and a.mode=="directory" then return true end
	return false
end

os.pathsearch=function(name,...)

	for i,p in ipairs({...}) do
	
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
			if os.isfile(t) then return t end
		end
		
	end
--[[
int os_pathsearch(lua_State* L)
{
	int i;
	for (i = 2; i <= lua_gettop(L); ++i)
	{
		const char* path;

		if (lua_isnil(L, i))
			continue;

		path = luaL_checkstring(L, i);
		do
		{
			const char* split;

			/* look for the closest path separator ; or : */
			/* can't use : on windows because it breaks on C:\path */
			const char* semi = strchr(path, ';');
#if !defined(PLATFORM_WINDOWS)
			const char* full = strchr(path, ':');
#else
			const char* full = NULL;
#endif

			if (!semi)
			{
				split = full;
			}
			else if (!full)
			{
				split = semi;
			}
			else
			{
				split = (semi < full) ? semi : full;
			}

			/* push this piece of the full search string onto the stack */
			if (split)
			{
				lua_pushlstring(L, path, split - path);
			}
			else
			{
				lua_pushstring(L, path);
			}

			/* keep an extra copy around, so I can return it if I have a match */
			lua_pushvalue(L, -1);

			/* append the filename to make the full test path */
			lua_pushstring(L, "/");
			lua_pushvalue(L, 1);
			lua_concat(L, 3);

			/* test it - if it exists return the path */
			if (do_isfile(lua_tostring(L, -1)))
			{
				lua_pop(L, 1);
				return 1;
			}

			/* no match, set up the next try */
			lua_pop(L, 2);
			path = (split) ? split + 1 : NULL;
		}
		while (path);
	}

	return 0;
}
]]


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
			if it.filename:match(it.pf) then return true end -- a match
		end
	end
	
end

os.matchname=function(it)

--	os.print("FUNCTION","os."..debug.getinfo(1).name,it.pd..it.filename)
	
	return it.filename	

end



os.matchisfile=function(it)

--	os.print("FUNCTION","os."..debug.getinfo(1).name,it.pd..it.filename,os.isfile( os.matchname(it)))
	
	return os.isfile( it.pd..it.filename )

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


	
	

