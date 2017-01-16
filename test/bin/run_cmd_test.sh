echo
TESTROOT=$1
TESTBED=$2
TESTNAME=$3
echo Start test $TESTNAME

# create testbed
echo Creating testbed...
mkdir "$TESTBED/$TESTNAME"
cp bin/* "$TESTROOT/cmd/data/$TESTNAME"/* "$TESTBED/$TESTNAME"
echo testbed ready

# execute program
echo Running program...
cd "$TESTBED/$TESTNAME"
ruby basic.rb --notiming --echo-input <stdin.txt >stdout.txt 2>&1
cd ../..
echo run finished

# compare results
ECODE=0
echo Comparing stdout...
diff "$TESTBED/$TESTNAME/stdout.txt" "$TESTROOT/cmd/ref/$TESTNAME/stdout.txt"
((ECODE+=$?))
echo compare done

echo End test $TESTNAME
exit $ECODE

