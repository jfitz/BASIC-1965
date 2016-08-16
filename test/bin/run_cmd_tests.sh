echo Removing old directory
if [ -d tests ] ; then rm -r tests ; fi

echo Creating directory tests
mkdir tests

echo Running all tests...
ECODE=0

bash test/bin/run_cmd_test.sh list
((ECODE+=$?))
bash test/bin/run_cmd_test.sh list_range_1
((ECODE+=$?))
bash test/bin/run_cmd_test.sh list_range_2
((ECODE+=$?))
bash test/bin/run_cmd_test.sh list_range_3
((ECODE+=$?))
bash test/bin/run_cmd_test.sh list_range_4
((ECODE+=$?))

echo
echo Failures: $ECODE

