
buffered=buffered or {}

buffered.new=function() print("FUNCTION","os."..debug.getinfo(1).name) end
buffered.write=function() print("FUNCTION","os."..debug.getinfo(1).name) end
buffered.writeln=function() print("FUNCTION","os."..debug.getinfo(1).name) end
buffered.tostring=function() print("FUNCTION","os."..debug.getinfo(1).name) end
buffered.close=function() print("FUNCTION","os."..debug.getinfo(1).name) end
