
buffered=buffered or {}

buffered.new=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
buffered.write=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
buffered.writeln=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
buffered.tostring=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
buffered.close=function() os.print("FUNCTION","os."..debug.getinfo(1).name) end
