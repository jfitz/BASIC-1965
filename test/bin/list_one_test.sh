echo
TESTNAME=$1
TESTDIR=$1_list
echo Start test $TESTDIR

# create testbed
echo Creating testbed...
mkdir tests/$TESTDIR
cp bin/* test/data/$TESTNAME/* tests/$TESTDIR
echo testbed ready

# execute program
echo Running program...
cd tests/$TESTDIR
ruby -I. basic.rb -l $TESTNAME.bas >stdout.txt 2>stderr.txt
cd ../..
echo run finished

# compare results
ECODE=0
echo Comparing stdout...
diff tests/$TESTDIR/stdout.txt test/ref/$TESTNAME/list_stdout.txt
((ECODE+=$?))
echo compare done
echo Comparing stderr...
diff tests/$TESTDIR/stderr.txt test/ref/$TESTNAME/list_stderr.txt
((ECODE+=$?))
echo compare done

echo End test $TESTNAME
exit $ECODE

