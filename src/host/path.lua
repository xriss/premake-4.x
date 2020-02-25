
path=path or {}

path._split = function(str,div,flag)

	div=div or "/"

	if (str=='') then return {""} end
	if (str=='') or not str then error("str expected", 2) end

	local pos,arr = 0,{}

	-- for each divider found
	for st,sp in function() return string.find(str,div,pos,not flag) end do
		table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
		pos = sp + 1 -- Jump past current divider
	end

	if pos~=0 then
		table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
	else
		table.insert(arr,str) -- return entire string
	end

	return arr
end




path.getrelative=function(a,b)
--	print("FUNCTION","path."..debug.getinfo(1).name,a,b)
	
	a=path.normalize(a)
	b=path.normalize(b)
	
	if a==b then return "." end	
	if b:sub(1,1)=="$" then return b end
	
	local ap=path._splitpath(a)
	local bp=path._splitpath(b)
	
	for i=1,#ap do
	
		if ap[i]~=bp[i] then
		
			if i==1 then -- not similar at all
				return b
			else
				local pp={}
				for j=i,#ap do pp[#pp+1]=".." end
				for j=i,#bp do pp[#pp+1]=bp[i] end
				return table.concat(pp,"/")
			end
		
		end
	
	end

	return "."

end


path.translate=function(a,b)

	
	b=b or "\\"
	local r=a
	
	if b=="\\" then r=a:gsub("/" ,"\\") end
	if b=="/"  then r=a:gsub("\\","/")  end
	
--	print("FUNCTION","path."..debug.getinfo(1).name,a,b,r)

	return r
	
end


-- return pathdir,pathfile
path._splitpath=function(p)

	local idx=p:match("^.*()/")
	
	if idx then
	
		return p:sub(1,idx) , p:sub(idx+1)

	else
	
		return "",p
	
	end

end

path.join=function(...)

	local aa={...}
	
	assert(aa[1])
	if aa[1]==nil then return "." end
	if aa[1]=="" then aa[1]="." end

	local n=path.normalize(table.concat(aa,"/"))
--	print("FUNCTION","path."..debug.getinfo(1).name,n)
	
	return n
end



path.isabsolute=function(a)

	local c1=a:sub(1,1)
	local c2=a:sub(2,2)
	
	local r= ( c1=="/" or c1=="\\" or c1=="$" or (c1=="\"" and c2=="$") or (c2==":") )

--	print("FUNCTION","path."..debug.getinfo(1).name,a,r)
	
	return r
	
end

path.getabsolute=function(a)

	local r

	if path.isabsolute(a) then
		r=path.normalize(a)
	else
		r=path.normalize(lfs.currentdir().."/"..a)
	end

--	print("FUNCTION","path."..debug.getinfo(1).name,a,r)	
	return r
end


path.normalize=function(a)

	local n=a:gsub("\\","/")
	local n=n:gsub("//","/")
	local p=path._split(a)
	local i=1
	while i<=#p do
		local v=p[i]
		if v=="." and i>1 then
			table.remove(p,i)
		elseif v==".." then
			if i>1 then
				if p[i-1]:sub(1,1)=="$" then -- cant remove something that may expand
					i=i+1
				else
					i=i-1
					table.remove(p,i)
					table.remove(p,i)				
				end
			else
				i=i+1
			end
		else
			i=i+1
		end
	end
	n=table.concat(p,"/")

--	print("FUNCTION","path."..debug.getinfo(1).name,a,n)
	
	return n
end


path.wildcards=function(s)

-- escape
	local r=s

	r=r:gsub("([%+%.%-%^%$%(%)%%])",function(a) return "%"..a end)
	r=r:gsub("(%*+)",function(a) if a=="**" then return "[^/]*" end return ".*" end)

--	print("FUNCTION","path."..debug.getinfo(1).name,s,r)
	
	return s
	
end
