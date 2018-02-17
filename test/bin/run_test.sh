echo
TESTROOT=$1
TESTBED=$2
TESTGROUP=$3
TESTNAME=$4
OPTIONS=$5
echo Start test $TESTNAME

# create testbed
echo Create testbed...
mkdir "$TESTBED/$TESTNAME"
cp bin/* "$TESTROOT/$TESTGROUP/$TESTNAME/data"/* "$TESTBED/$TESTNAME"

# execute program
ECODE=0

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/list.txt" ]
then
  echo List program...
  cd "$TESTBED/$TESTNAME"
  ruby basic.rb --list $TESTNAME.bas --no-heading --print-width 0 >list.txt
  cd ../..
  echo Compare list...
  diff "$TESTBED/$TESTNAME/list.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/list.txt"
  ((ECODE+=$?))
fi

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/pretty.txt" ]
then
  echo Pretty program...
  cd "$TESTBED/$TESTNAME"
  ruby basic.rb --pretty $TESTNAME.bas --no-heading --print-width 0 >pretty.txt
  cd ../..
  echo Compare pretty...
  diff "$TESTBED/$TESTNAME/pretty.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/pretty.txt"
  ((ECODE+=$?))
fi

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/crossref.txt" ]
then
  echo Crossref program...
  cd "$TESTBED/$TESTNAME"
  ruby basic.rb --crossref $TESTNAME.bas --no-heading --print-width 0 >crossref.txt
  cd ../..
  echo Compare crossref...
  diff "$TESTBED/$TESTNAME/crossref.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/crossref.txt"
  ((ECODE+=$?))
fi

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/stdout.txt" ]
then
  if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/data/run_options.txt" ]
  then
    RUN_OPTIONS=$(<"$TESTROOT/$TESTGROUP/$TESTNAME/data/run_options.txt")
  fi
  cd "$TESTBED/$TESTNAME"
  echo Run program...
  if [ -e stdin.txt ]
  then
    ruby basic.rb --no-timing $OPTIONS --run $TESTNAME.bas --no-heading --echo-input <stdin.txt >stdout.txt $RUN_OPTIONS
  else
    ruby basic.rb --no-timing $OPTIONS --run $TESTNAME.bas --no-heading >stdout.txt $RUN_OPTIONS
  fi
  cd ../..
  echo Compare stdout...
  diff "$TESTBED/$TESTNAME/stdout.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/stdout.txt"
  ((ECODE+=$?))
fi

if [ -e "test/$TESTGROUP/$TESTNAME/ref/out_files.txt" ]
then
  while read F ; do
    echo Compare $F...
    diff "$TESTBED/$TESTNAME/$F" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/$F"
    ((ECODE+=$?))
  done <"$TESTROOT/$TESTGROUP/$TESTNAME/ref/out_files.txt"
fi

echo End test $TESTNAME
exit $ECODE
