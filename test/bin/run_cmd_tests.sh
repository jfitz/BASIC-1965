TESTROOT=test
TESTBED=tests

echo Removing old directory
if [ -d "$TESTBED" ] ; then rm -r "$TESTBED" ; fi

echo Creating directory $TESTBED
mkdir "$TESTBED"

echo Running all tests...
ECODE=0

bash "$TESTROOT/bin/run_cmd_test.sh" "$TESTROOT" "$TESTBED" list
((ECODE+=$?))
bash "$TESTROOT/bin/run_cmd_test.sh" "$TESTROOT" "$TESTBED" list_range_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_cmd_test.sh" "$TESTROOT" "$TESTBED" list_range_2
((ECODE+=$?))
bash "$TESTROOT/bin/run_cmd_test.sh" "$TESTROOT" "$TESTBED" list_range_3
((ECODE+=$?))
bash "$TESTROOT/bin/run_cmd_test.sh" "$TESTROOT" "$TESTBED" list_range_4
((ECODE+=$?))

echo
echo Failures: $ECODE

