puremake is a version of premake4 in pure lua.
----------------------------------------------

See https://premake.github.io/ for premake4 documentation.

I've renamed it to puremake so as not to confuse it with premake5. My 
intent is to keep it compatible with premake4 but wrap it up into more 
of a lua module or rock for easy install.

The only binary dependency is a version of lua (5.1 or above and with 
LuaJIT recommended) and the lua-filesystem (lfs) library.

Prebuilt lua(jit) and lfs binaries for various OS exist and are easily 
available as they have been stable for years.

I'm happy with including a snapshot of premake lua in my larger 
projects, but I'm less happy with the extra dependency of requiring a 
premake binary or having to build one.

It depends on your needs, maybe the standard premake4 fat executable is 
best for you, but I think it is nice to have puremake as a pure lua 
premake4 option.

