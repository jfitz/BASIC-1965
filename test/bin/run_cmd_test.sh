echo
TESTNAME=$1
echo Start test $TESTNAME

# create testbed
echo Creating testbed...
mkdir tests/$TESTNAME
cp bin/* test/data/$TESTNAME/* tests/$TESTNAME
echo testbed ready

# execute program
echo Running program...
cd tests/$TESTNAME
ruby -I. basic.rb --notiming --echo-input <stdin.txt >stdout.txt 2>&1
cd ../..
echo run finished

# compare results
ECODE=0
echo Comparing stdout...
diff tests/$TESTNAME/stdout.txt test/ref/$TESTNAME/stdout.txt
((ECODE+=$?))
echo compare done

echo End test $TESTNAME
exit $ECODE

