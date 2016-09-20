echo
TESTGROUP=$1
TESTNAME=$2
OPTIONS=$3
echo Start test $TESTNAME

# create testbed
echo Creating testbed...
mkdir tests/$TESTNAME
cp bin/* test/$TESTGROUP/data/$TESTNAME/* tests/$TESTNAME
echo testbed ready

# execute program
ECODE=0

if [ -e test/$TESTGROUP/ref/$TESTNAME/list.txt ]
then
echo List program...
cd tests/$TESTNAME
ruby -I. basic.rb -l $TESTNAME.bas >list.txt
cd ../..
echo Comparing list...
diff tests/$TESTNAME/list.txt test/$TESTGROUP/ref/$TESTNAME/list.txt
((ECODE+=$?))
fi

if [ -e test/$TESTGROUP/ref/$TESTNAME/pretty.txt ]
then
echo Pretty program...
cd tests/$TESTNAME
ruby -I. basic.rb -p $TESTNAME.bas >pretty.txt
cd ../..
echo Comparing pretty...
diff tests/$TESTNAME/pretty.txt test/$TESTGROUP/ref/$TESTNAME/pretty.txt
((ECODE+=$?))
fi

if [ -e test/$TESTGROUP/ref/$TESTNAME/stdout.txt ]
then
cd tests/$TESTNAME
echo Running program...
if [ -e stdin.txt ]
then
ruby -I. basic.rb --notiming $OPTIONS -r $TESTNAME.bas --echo-input <stdin.txt >stdout.txt
else
ruby -I. basic.rb --notiming $OPTIONS -r $TESTNAME.bas >stdout.txt
fi
cd ../..
echo Comparing stdout...
diff tests/$TESTNAME/stdout.txt test/$TESTGROUP/ref/$TESTNAME/stdout.txt
((ECODE+=$?))
fi
if [ -e test/$TESTGROUP/ref/$TESTNAME/out_files.txt ]
then
while read F ; do
  diff tests/$TESTNAME/$F test/$TESTGROUP/ref/$TESTNAME/$F
  ((ECODE+=$?))
done <test/$TESTGROUP/ref/$TESTNAME/out_files.txt
fi

echo End test $TESTNAME
exit $ECODE

