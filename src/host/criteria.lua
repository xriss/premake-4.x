
criteria=criteria or {}


criteria._delete=function() print("FUNCTION","criteria."..debug.getinfo(1).name) end


criteria._compile=function(input)

	local patterns={}

--	print("FUNCTION START","criteria."..debug.getinfo(1).name)
	
	for i,v in ipairs(input) do
		local pattern={}--{prefixed=false,files=0}
		patterns[i]=pattern
		for i,v in ipairs(v) do
--			local test={unpack(v)}
			pattern[i]={unpack(v)}
--			test.word,test.prefix,test.assertion,test.wildcard=
--			if test.prefix=="files" then pattern.files=pattern.files+1 end
--			if test.prefix then pattern.prefixed=true end
--print(test.word,test.prefix,test.assertion,test.wildcard,pattern.files,pattern.prefixed)
		end
	end

--	print("FUNCTION END","criteria."..debug.getinfo(1).name)
	
	
	return patterns
end


local compare=function(str,word)

	if word[4] then
		return str==str:match(word[1])
	else
		return str==word[1]
	end
	
end

local compare_all -- recursive compare

compare_all=function(val,word)
	if type(val)=="table" then -- recurse
		for i=1,#val do v=val[i]
			if compare_all(v,word) then return true end
		end
		return false
	end	
	return cmp(tostring(val),word)
end

criteria.matches=function(patterns, context)

--	print("FUNCTION","criteria."..debug.getinfo(1).name,patterns,context)
--for n,v in pairs(context) do print(n,v) end

	local matched=false


	for ip=1,#patterns do local pattern=patterns[ip] -- all patterns

		for iw=1,#pattern do local word=pattern[iw] -- must match any word

			if word[2] then -- prefix ( look in a context.table recursively )
				matched=compare_all( context[ word[2] ] , word )
			else -- no prefix, check entire context recursively
				matched=compare_all( context , word )
			end

			if matched then break end -- found a word

		end
		
		if not matched then break end -- give up as that pattern failed
		
	end


	return matched

--[[
int criteria_matches(lua_State* L)
{
	/* stack [1] = criteria */
	/* stack [2] = context */

	struct Patterns* patterns;
	const char* filename;
	int i, j, fileMatched;
	int matched = 1;

	/* filename = context.files */
	lua_pushstring(L, "files");
	lua_rawget(L, 2);
	filename = lua_tostring(L, -1);
	lua_pop(L, 1);

	/* fetch the patterns to be tested */
	lua_pushstring(L, "data");
	lua_rawget(L, 1);
	patterns = (struct Patterns*)lua_touserdata(L, -1);
	lua_pop(L, 1);

	/* if a file is being matched, the pattern must be able to match it */
	if (patterns->prefixed && filename != NULL && patterns->filePatterns == 0) {
		return 0;
	}

	/* Cache string.match on the stack (at index 4) to save time in matches() later */

	lua_getglobal(L, "string");
	lua_getfield(L, -1, "match");

	/* if there is no file to consider, consider it matched */
	fileMatched = (filename == NULL);

	/* all patterns must match to pass */
	for (i = 0; matched && i < patterns->n; ++i) {
		struct Pattern* pattern = &patterns->pattern[i];

		/* only one word needs to match for the pattern to pass */
		matched = 0;

		for (j = 0; !matched && j < pattern->n; ++j) {
			struct Word* word = &pattern->word[j];
			if (word->prefix) {
				matched = testWithPrefix(L, word, filename, &fileMatched);
			}
			else {
				matched = testNoPrefix(L, word, filename, &fileMatched);
			}
		}
	}

	/* if a file name was provided in the context, it must be matched */
	if (filename && !fileMatched) {
		matched = 0;
	}

	lua_pushboolean(L, matched);
	return 1;
}
]]

end



