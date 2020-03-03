
local pmos=require("puremake.os")

for n,v in pairs(pmos) do os[n]=os[n] or v end
