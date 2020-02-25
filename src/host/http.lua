
http=http or {}

http.get=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
http.post=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
http.download=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
