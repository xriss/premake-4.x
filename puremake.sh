BASEPATH="$( cd "$(dirname "$0")" ; pwd -P )"

# you can set PUREMAKE_LUA to the lua you wish to use, or we will try and find one

if [ -z "$PUREMAKE_LUA" ]; then 
 if command -v luajit; then
  PUREMAKE_LUA=luajit
 elif command -v lua; then 
  PUREMAKE_LUA=lua
 elif command -v gamecake; then 
  PUREMAKE_LUA=gamecake
 else
  printf "puremake requires luajit or lua or gamecake to be installed\n" 1>&2
  exit 1
 fi
fi

$PUREMAKE_LUA $BASEPATH/src/host/premake.lua $*
