puremake is a version of premake4 in pure lua
---------------------------------------------

See https://premake.github.io/ for premake4 documentation.

I've renamed it to puremake so as not to confuse it with premake5. My 
intent is to keep it compatible with premake4 but wrap it up into more 
of a lua module or rock for easy install. The code currently injects 
functions into the string table for instance so this will be removed in 
the future behind a backwards compatible option for premake4 scripts.

The only binary dependency is a version of luaJIT or a version of Lua 
and the lua-filesystem (lfs) library. When we run under LuaJIT we can 
use an FFI implimentation of lfs which is why it is only required for 
Lua.

Prebuilt luajot or lua and lfs binaries for various OS exist and are 
easily available as they have been stable for years so it should be 
easy to get this script to run.

For example

	sudo apt-get -y install luajit

will install luajit using apt-get, you will need to adjust that into an 
appropriate action for you operating system. For instance OSX would be 
```brew install luajit``` assuming you have brew installed.

	./puremake.sh

will run premake4 using the installed luajit

	./puremake.lua

will also run premake4 but this file is a completely self contained lua 
script containing amalgamated files from the src directory and is 
generated by the ```./build.sh``` script. This *single* lua file can be 
taken out of this repository and used as a portable pure lua 
replacement for a premake4 binary. It's only requirement is luajit to 
run.

Personally I'm happy to include this snapshot of premake4 lua code in 
my projects rather than require premake4 to be built and made available 
in the build environment. It's just one less thing that can go wrong 
when building code.

It all depends on your needs, maybe the standard premake4 fat 
executable is best for you, but I think it is nice to have puremake as 
a pure lua premake4 option that reduces the complexity of getting my 
code to build.
