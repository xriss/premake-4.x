

local pmstring=require("puremake.string")

for n,v in pairs(pmstring) do string[n]=string[n] or v end
