
os=os or {}

os.chdir=function() print("FUNCTION","os."..debug.getinfo(1).name) end
os.chmod=function() print("FUNCTION","os."..debug.getinfo(1).name) end
os.copyfile=function() print("FUNCTION","os."..debug.getinfo(1).name) end
os._is64bit=function() print("FUNCTION","os."..debug.getinfo(1).name) end
os.isdir=function() print("FUNCTION","os."..debug.getinfo(1).name) end

os.getversion=function() print("FUNCTION","os."..debug.getinfo(1).name) end

os.islink=function() print("FUNCTION","os."..debug.getinfo(1).name) end


os.mkdir=function() print("FUNCTION","os."..debug.getinfo(1).name) end
os.pathsearch=function() print("FUNCTION","os."..debug.getinfo(1).name) end
os.realpath=function() print("FUNCTION","os."..debug.getinfo(1).name) end
os.rmdir=function() print("FUNCTION","os."..debug.getinfo(1).name) end
os.stat=function() print("FUNCTION","os."..debug.getinfo(1).name) end
os.writefile_ifnotequal=function() print("FUNCTION","os."..debug.getinfo(1).name) end

os.matchstart=function(p)
	local it={}
	
	it.p=p
	it.pd,it.pf=path._splitpath(p)
	pcall( function() it.dir_func,it.dir_data=lfs.dir(it.pd) end )

-- very very simple glob hack, any other special character will messup
	it.pf=it.pf:gsub("%.","%.")
	it.pf=it.pf:gsub("%*",".*")
	it.pf=it.pf:gsub("%?",".")

--	print("FUNCTION","os."..debug.getinfo(1).name,p,it.pd,it.pf)
		
	return it
end
os.matchdone=function()end

os.matchnext=function(it)
--	print("FUNCTION","os."..debug.getinfo(1).name,it)
	
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

--	print("FUNCTION","os."..debug.getinfo(1).name,it.pd..it.filename)
	
	return it.filename	

end



os.matchisfile=function(it)

--	print("FUNCTION","os."..debug.getinfo(1).name,it.pd..it.filename,os.isfile( os.matchname(it)))
	
	return os.isfile( it.pd..it.filename )

end

os.uuid=function()

	local r=string.format("%04X%04X-%04X-%04X-%04X-%04X%04X%04X",
		math.random(0,0xffff),math.random(0,0xffff),
		math.random(0,0xffff),math.random(0,0xffff),math.random(0,0xffff),
		math.random(0,0xffff),math.random(0,0xffff),math.random(0,0xffff))
		
--	print("FUNCTION","os."..debug.getinfo(1).name,r)

	return r
end



os.getcwd=function()

--	print("FUNCTION","os."..debug.getinfo(1).name)
	
	return lfs.currentdir()
	
end

os.isfile=function(a)

	local r=lfs.attributes(a,'mode')=="file"

--	print("FUNCTION","os."..debug.getinfo(1).name,a,r)
	
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
--	print("FUNCTION","os."..debug.getinfo(1).name,a,r)

	return nil
end


	
	

