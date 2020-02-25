#An attempt to provide a full version of premake in pure lua.

The only binary dependency is a version of lua (5.1 or above and with 
LuaJIT recommended) and the lua-filesystem (lfs) library this seems a 
pretty basic minimum that is generally available on most operating 
systems.

Plenty of prebuilt binaries for various OS exist and are easily 
available as most importantly they have not changed in years so are not 
going to be out of date.

Most of the important changes that happen to premake are all small lua 
script fixes and getting the version that your project needs can be a 
pain. Often the only way to be sure is to build from source.

I'm happy with including a working recent premake source in my larger 
project, but I'm less happy with the extra build step.

A pure Lua versions means there is no need to build as all of premake 
is now available in lua.

Depends on your needs, maybe the standard premake fat executable is 
best for you, but I think it is nice to have pure lua as a premake 
option.
