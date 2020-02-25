BASEPATH="$( cd "$(dirname "$0")/.." ; pwd -P )"
luajit $BASEPATH/src/host/premake.lua $*



