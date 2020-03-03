
local M={} ; package.loaded[(...)]=M ; M.module_name=(...)
setmetatable(M,{__index=string}) -- use string as prototype
local pmstring=M

pmstring.startswith=function(a,b)

--	os.print("FUNCTION","string."..debug.getinfo(1).name,a,b,b==a:sub(1,#b))
	
	if a and b then
		return b==a:sub(1,#b)
	end
	
end

pmstring.endswith=function(a,b)

--	os.print("FUNCTION","string."..debug.getinfo(1).name,a,b,b==a:sub(-#b))

	if a and b then
		return b==a:sub(-#b)
	end
end



--
-- pmstring.lua
-- Additions to Lua's built-in pmstring functions.
-- Copyright (c) 2002-2008 Jason Perkins and the Premake project
--


--
-- Returns an array of pmstrings, each of which is a subpmstring of s
-- formed by splitting on boundaries formed by `pattern`.
-- 

	function pmstring.explode(s, pattern, plain)
		if (pattern == '') then return false end
		local pos = 0
		local arr = { }
		for st,sp in function() return s:find(pattern, pos, plain) end do
			table.insert(arr, s:sub(pos, st-1))
			pos = sp + 1
		end
		table.insert(arr, s:sub(pos))
		return arr
	end
	


--
-- Find the last instance of a pattern in a pmstring.
--

	function pmstring.findlast(s, pattern, plain)
		local curr = 0
		repeat
			local next = s:find(pattern, curr + 1, plain)
			if (next) then curr = next end
		until (not next)
		if (curr > 0) then
			return curr
		end	
	end



--
-- Returns true if `haystack` starts with the sequence `needle`.
--

	function pmstring.startswith(haystack, needle)
		return (haystack:find(needle, 1, true) == 1)
	end
