BASEPATH="$( cd "$(dirname "$0")/.." ; pwd -P )"

cd `dirname $0`/../tests && luajit $BASEPATH/src/host/premake.lua /file=./premake4.lua /scripts=.. $1 $2 $3 test


