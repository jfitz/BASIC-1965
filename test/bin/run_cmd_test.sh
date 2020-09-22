#!/bin/bash

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

echo Running program...
cd "$TESTBED/$TESTNAME"
ruby basic.rb --no-timing --print-width 0 --echo-input <stdin.txt >stdout.txt 2>&1
cd ../..
echo run finished

# compare results
echo Comparing stdout...
diff "$TESTROOT/$TESTGROUP/$TESTNAME/ref/stdout.txt" "$TESTBED/$TESTNAME/stdout.txt"
((ECODE+=$?))

if [ $ECODE -ne 0 ]
then
   cp "$TESTBED/$TESTNAME/stdout.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/stdout.txt"
fi
echo compare done

if [ -e "test/$TESTGROUP/$TESTNAME/ref/out_files.txt" ]
then
    while read F ; do
	echo Compare $F...
	diff "$TESTROOT/$TESTGROUP/$TESTNAME/ref/$F" "$TESTBED/$TESTNAME/$F"
	((ECODE=$?))

	if [ $ECODE -ne 0 ]
	then
	    ((NUM_FAIL+=1))
	    cp "$TESTBED/$TESTNAME/$F" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/$F"
	fi
    done <"$TESTROOT/$TESTGROUP/$TESTNAME/ref/out_files.txt"
fi

echo End test $TESTNAME
exit $ECODE
