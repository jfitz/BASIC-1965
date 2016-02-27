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
ruby -I. basic.rb -l $TESTNAME.bas >list.txt
ruby -I. basic.rb -p $TESTNAME.bas >pretty.txt
ruby -I. basic.rb --notiming -r $TESTNAME.bas >stdout.txt
cd ../..
echo run finished

# compare results
ECODE=0
echo Comparing stdout...
diff tests/$TESTNAME/stdout.txt test/ref/$TESTNAME/stdout.txt
((ECODE+=$?))
echo Comparing list...
diff tests/$TESTNAME/list.txt test/ref/$TESTNAME/list.txt
((ECODE+=$?))
echo Comparing pretty...
diff tests/$TESTNAME/pretty.txt test/ref/$TESTNAME/pretty.txt
((ECODE+=$?))
echo compare done

echo End test $TESTNAME
exit $ECODE

