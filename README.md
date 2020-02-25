puremake is a version of premake4 in pure lua
---------------------------------------------

See https://premake.github.io/ for premake4 documentation.

I've renamed it to puremake so as not to confuse it with premake5. My 
intent is to keep it compatible with premake4 but wrap it up into more 
of a lua module or rock for easy install.

The only binary dependency is a version of lua(JIT) and the 
lua-filesystem (lfs) library.

Prebuilt lua and lfs binaries for various OS exist and are easily 
available as they have been stable for years.

For example

	./apt-get-install.sh

will install luajit+lfs using apt-get

	./puremake.sh

will run premake4 using the installed luajit

I'm happy to including a snapshot of premake4 lua code in my larger 
projects, but I'm less happy with the extra dependency of requiring a 
premake binary.

It all depends on your needs, maybe the standard premake4 fat 
executable is best for you, but I think it is nice to have puremake as 
a pure lua premake4 option that reduces the complexity of my builds.
