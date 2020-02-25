BASEPATH="$( cd "$(dirname "$0")" ; pwd -P )"

if [ -z "$PUREMAKE_LUA" ]; then 
 if command -v luajit; then
  PUREMAKE_LUA=luajit
 elif command -v lua; then 
  PUREMAKE_LUA=lua
 else
  printf "This program requires lua or luajit to be installed\n" 1>&2
  exit 1
 fi
fi

$PUREMAKE_LUA $BASEPATH/src/host/premake.lua $*
