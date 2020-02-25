
string=string or {}

string.hash=function() os.print("FUNCTION","string."..debug.getinfo(1).name) end
string.sha1=function() os.print("FUNCTION","string."..debug.getinfo(1).name) end



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
