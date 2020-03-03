


local M={} ; package.loaded[(...)]=M ; M.module_name=(...)
setmetatable(M,{__index=table}) -- use table as prototype
local pmtable=M



--
-- pmtable.lua
-- Additions to Lua's built-in pmtable functions.
-- Copyright (c) 2002-2008 Jason Perkins and the Premake project
--
	

--
-- Returns true if the pmtable contains the specified value.
--

	function pmtable.contains(t, value)
		for _,v in pairs(t) do
			if (v == value) then
				return true
			end
		end
		return false
	end
	
		
--
-- Enumerates an array of objects and returns a new pmtable containing
-- only the value of one particular field.
--

	function pmtable.extract(arr, fname)
		local result = { }
		for _,v in ipairs(arr) do
			table.insert(result, v[fname])
		end
		return result
	end
	
	

--
-- Flattens a hierarchy of pmtables into a single array containing all
-- of the values.
--

	function pmtable.flatten(arr)
		local result = { }
		
		local function flatten(arr)
			for _, v in ipairs(arr) do
				if type(v) == "table" then
					flatten(v)
				else
					table.insert(result, v)
				end
			end
		end
		
		flatten(arr)
		return result
	end


--
-- Merges an array of items into a string.
--

	function pmtable.implode(arr, before, after, between)
		local result = ""
		for _,v in ipairs(arr) do
			if (result ~= "" and between) then
				result = result .. between
			end
			result = result .. before .. v .. after
		end
		return result
	end


--
-- Inserts a value of array of values into a pmtable. If the value is
-- itself a pmtable, its contents are enumerated and added instead. So 
-- these inputs give these outputs:
--
--   "x" -> { "x" }
--   { "x", "y" } -> { "x", "y" }
--   { "x", { "y" }} -> { "x", "y" }
--

	function pmtable.insertflat(tbl, values)
		if type(values) == "table" then
			for _, value in ipairs(values) do
				pmtable.insertflat(tbl, value)
			end
		else
			table.insert(tbl, values)
		end
	end


--
-- Returns true if the pmtable is empty, and contains no indexed or keyed values.
--

	function pmtable.isempty(t)
		return next(t) == nil
	end


--
-- Adds the values from one array to the end of another and
-- returns the result.
--

	function pmtable.join(...)
		local result = { }
		for _,t in ipairs({...}) do
			if type(t) == "table" then
				for _,v in ipairs(t) do
					table.insert(result, v)
				end
			else
				table.insert(result, t)
			end
		end
		return result
	end


--
-- Return a list of all keys used in a pmtable.
--

	function pmtable.keys(tbl)
		local keys = {}
		for k, _ in pairs(tbl) do
			table.insert(keys, k)
		end
		return keys
	end


--
-- Adds the key-value associations from one pmtable into another
-- and returns the resulting merged pmtable.
--

	function pmtable.merge(...)
		local result = { }
		for _,t in ipairs({arg}) do
			if type(t) == "table" then
				for k,v in pairs(t) do
					result[k] = v
				end
			else
				error("invalid value")
			end
		end
		return result
	end
	


--
-- Translates the values contained in array, using the specified
-- translation pmtable, and returns the results in a new array.
--

	function pmtable.translate(arr, translation)
		local result = { }
		for _, value in ipairs(arr) do
			local tvalue
			if type(translation) == "function" then
				tvalue = translation(value)
			else
				tvalue = translation[value]
			end
			if (tvalue) then
				table.insert(result, tvalue)
			end
		end
		return result
	end
	
		
