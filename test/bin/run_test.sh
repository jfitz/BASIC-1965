echo
TESTROOT=$1
TESTBED=$2
TESTGROUP=$3
TESTNAME=$4
OPTIONS=$5
echo Start test $TESTNAME

# create testbed
echo Creating testbed...
mkdir "$TESTBED/$TESTNAME"
cp bin/* "$TESTROOT/$TESTGROUP/data/$TESTNAME"/* "$TESTBED/$TESTNAME"
echo testbed ready

# execute program
ECODE=0

if [ -e "$TESTROOT/$TESTGROUP/ref/$TESTNAME/list.txt" ]
then
echo List program...
cd "$TESTBED/$TESTNAME"
ruby basic.rb -l $TESTNAME.bas >list.txt
cd ../..
echo Comparing list...
diff "$TESTBED/$TESTNAME/list.txt" "$TESTROOT/$TESTGROUP/ref/$TESTNAME/list.txt"
((ECODE+=$?))
fi

if [ -e "$TESTROOT/$TESTGROUP/ref/$TESTNAME/pretty.txt" ]
then
echo Pretty program...
cd "$TESTBED/$TESTNAME"
ruby basic.rb -p $TESTNAME.bas >pretty.txt
cd ../..
echo Comparing pretty...
diff "$TESTBED/$TESTNAME/pretty.txt" "$TESTROOT/$TESTGROUP/ref/$TESTNAME/pretty.txt"
((ECODE+=$?))
fi

if [ -e "$TESTROOT/$TESTGROUP/ref/$TESTNAME/stdout.txt" ]
then
cd "$TESTBED/$TESTNAME"
echo Running program...
if [ -e stdin.txt ]
then
ruby basic.rb --notiming $OPTIONS -r $TESTNAME.bas --echo-input <stdin.txt >stdout.txt
else
ruby basic.rb --notiming $OPTIONS -r $TESTNAME.bas >stdout.txt
fi
cd ../..
echo Comparing stdout...
diff "$TESTBED/$TESTNAME/stdout.txt" "$TESTROOT/$TESTGROUP/ref/$TESTNAME/stdout.txt"
((ECODE+=$?))
fi
if [ -e test/$TESTGROUP/ref/$TESTNAME/out_files.txt ]
then
while read F ; do
  echo Comparing $F...
  diff "$TESTBED/$TESTNAME/$F" "$TESTROOT/$TESTGROUP/ref/$TESTNAME/$F"
  ((ECODE+=$?))
done <"$TESTROOT/$TESTGROUP/ref/$TESTNAME/out_files.txt"
fi

echo End test $TESTNAME
exit $ECODE

