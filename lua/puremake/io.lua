

local M={} ; package.loaded[(...)]=M ; M.module_name=(...)
setmetatable(M,{__index=io}) -- use io as prototype
local pmio=M



--
-- pmio.lua
-- Additpmions to the I/O namespace.
-- Copyright (c) 2008-2009 Jason Perkins and the Premake project
--


--
-- Prepare to capture the output from all subsequent calls to pmio.printf(), 
-- used for automated testing of the generators.
--

	function pmio.capture()
		pmio.captured = ''
	end
	
	
	
--
-- Returns the captured text and stops capturing.
--

	function pmio.endcapture()
		local captured = pmio.captured
		pmio.captured = nil
		return captured
	end
	
	
--
-- Open an overload of the pmio.open() function, which will create any missing
-- subdirectories in the filename if "mode" is set to writeable.
--

	local builtin_open = pmio.open
	function pmio.open(fname, mode)
		if (mode) then
			if (mode:find("w")) then
				local dir = path.getdirectory(fname)
				ok, err = os.mkdir(dir)
				if (not ok) then
					error(err, 0)
				end
			end
		end
		return builtin_open(fname, mode)
	end



-- 
-- A shortcut for printing formatted output to an output stream.
--

	function pmio.printf(msg, ...)
		if not pmio.eol then
			pmio.eol = "\n"
		end

		if not pmio.indent then
			pmio.indent = "\t"
		end

		if type(msg) == "number" then
			s = string.rep( (io.indent or pmio.indent) , msg) .. string.format(...)
		else
			s = string.format(msg,...)
		end
		
		if pmio.captured then
			pmio.captured = pmio.captured .. s .. (io.eol or pmio.eol)
		else
			pmio.write(s)
			pmio.write((io.eol or pmio.eol))
		end
	end


--
-- Because I use pmio.printf() so often in the generators, create a terse shortcut
-- for it. This saves me typing, and also reduces the size of the executable.
--

	_p = pmio.printf
