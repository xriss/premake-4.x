
local pmio = require("puremake.io")

for n,v in pairs(pmio) do io[n]=io[n] or v end
