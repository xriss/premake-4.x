
string=string or {}

string.hash=function() print("FUNCTION","string."..debug.getinfo(1).name) end
string.sha1=function() print("FUNCTION","string."..debug.getinfo(1).name) end



string.startswith=function(a,b)

--	print("FUNCTION","string."..debug.getinfo(1).name,a,b,b==a:sub(1,#b))
	
	return b==a:sub(1,#b)
	
end

string.endswith=function(a,b)

--	print("FUNCTION","string."..debug.getinfo(1).name,a,b,b==a:sub(-#b))

	return b==a:sub(-#b)
end
