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
cp bin/* "$TESTROOT/$TESTGROUP/$TESTNAME/data"/* "$TESTBED/$TESTNAME"
echo testbed ready

# execute program
ECODE=0

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/list.txt" ]
then
  echo List program...
  cd "$TESTBED/$TESTNAME"
  ruby basic.rb -l $TESTNAME.bas >list.txt
  cd ../..
  echo Comparing list...
  diff "$TESTBED/$TESTNAME/list.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/list.txt"
  ((ECODE+=$?))
fi

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/pretty.txt" ]
then
  echo Pretty program...
  cd "$TESTBED/$TESTNAME"
  ruby basic.rb -p $TESTNAME.bas >pretty.txt
  cd ../..
  echo Comparing pretty...
  diff "$TESTBED/$TESTNAME/pretty.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/pretty.txt"
  ((ECODE+=$?))
fi

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/stdout.txt" ]
then
  if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/data/run_options.txt" ]
  then
    RUN_OPTIONS=$(<"$TESTROOT/$TESTGROUP/$TESTNAME/data/run_options.txt")
  fi
  cd "$TESTBED/$TESTNAME"
  echo Running program...
  if [ -e stdin.txt ]
  then
    ruby basic.rb --notiming $OPTIONS -r $TESTNAME.bas --echo-input <stdin.txt >stdout.txt $RUN_OPTIONS
  else
    ruby basic.rb --notiming $OPTIONS -r $TESTNAME.bas >stdout.txt $RUN_OPTIONS
  fi
  cd ../..
  echo Comparing stdout...
  diff "$TESTBED/$TESTNAME/stdout.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/stdout.txt"
  ((ECODE+=$?))
fi

if [ -e "test/$TESTGROUP/$TESTNAME/ref/out_files.txt" ]
then
  while read F ; do
    echo Comparing $F...
    diff "$TESTBED/$TESTNAME/$F" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/$F"
    ((ECODE+=$?))
  done <"$TESTROOT/$TESTGROUP/$TESTNAME/ref/out_files.txt"
fi

echo End test $TESTNAME
exit $ECODE
