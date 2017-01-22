TESTROOT=test
TESTBED=tests
TESTGROUP=$1

echo Removing old directory
if [ -d "$TESTBED" ] ; then rm -r "$TESTBED" ; fi

echo Creating directory $TESTBED
mkdir "$TESTBED"

echo Running all tests...
ECODE=0

while read F ; do
    bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" "$TESTGROUP" $F
    ((ECODE+=$?))
done <"$TESTROOT/$TESTGROUP/data/test_names.txt"

echo
echo Failures: $ECODE

