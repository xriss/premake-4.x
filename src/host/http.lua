
http=http or {}

http.get=function() print("FUNCTION","os."..debug.getinfo(1).name) end
http.post=function() print("FUNCTION","os."..debug.getinfo(1).name) end
http.download=function() print("FUNCTION","os."..debug.getinfo(1).name) end
