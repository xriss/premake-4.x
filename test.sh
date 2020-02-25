BASEPATH="$( cd "$(dirname "$0")" ; pwd -P )"

cd $BASEPATH/tests && $BASEPATH/puremake.sh /scripts=.. $* test

