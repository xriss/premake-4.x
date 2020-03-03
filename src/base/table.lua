
local pmtable=require("puremake.table")

for n,v in pairs(pmtable) do table[n]=table[n] or v end

