#!/bin/bash

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

if [ -e "$TESTROOT/$TESTGROUP/options.txt" ]
then
    GROUP_OPTIONS=$(<"$TESTROOT/$TESTGROUP/options.txt")
fi

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/data/options.txt" ]
then
    TEST_OPTIONS=$(<"$TESTROOT/$TESTGROUP/$TESTNAME/data/options.txt")
fi

# execute program
NUM_FAIL=0

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/list.txt" ]
then
    echo List program with options $GROUP_OPTIONS $TEST_OPTIONS
    cd "$TESTBED/$TESTNAME"
    ruby basic.rb --list $TESTNAME.bas --no-heading --print-width 0 >list.txt $GROUP_OPTIONS $TEST_OPTIONS
    cd ../..

    echo Compare list...
    diff "$TESTBED/$TESTNAME/list.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/list.txt"
    ((ECODE=$?))

    if [ $ECODE -ne 0 ]
    then
	((NUM_FAIL+=1))
	cp "$TESTBED/$TESTNAME/list.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/list.txt"
    fi
fi

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/parse.txt" ]
then
    if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/data/parse_options.txt" ]
    then
	PARSE_OPTIONS=$(<"$TESTROOT/$TESTGROUP/$TESTNAME/data/parse_options.txt")
    fi

    echo Parse program with options $GROUP_OPTIONS $TEST_OPTIONS $PARSE_OPTIONS
    cd "$TESTBED/$TESTNAME"
    ruby basic.rb --parse $TESTNAME.bas --no-heading --print-width 0 >parse.txt $GROUP_OPTIONS $TEST_OPTIONS $PARSE_OPTIONS
    cd ../..

    echo Compare parse...
    diff "$TESTBED/$TESTNAME/parse.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/parse.txt"
    ((ECODE=$?))

    if [ $ECODE -ne 0 ]
    then
	((NUM_FAIL+=1))
	cp "$TESTBED/$TESTNAME/parse.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/parse.txt"
    fi
fi

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/pretty.txt" ]
then
    if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/data/pretty_options.txt" ]
    then
	PRETTY_OPTIONS=$(<"$TESTROOT/$TESTGROUP/$TESTNAME/data/pretty_options.txt")
    fi

    echo Pretty program with options $GROUP_OPTIONS $TEST_OPTIONS $PRETTY_OPTIONS
    cd "$TESTBED/$TESTNAME"
    ruby basic.rb --pretty $TESTNAME.bas --no-heading --print-width 0 >pretty.txt $GROUP_OPTIONS $TEST_OPTIONS $PRETTY_OPTIONS
    cd ../..

    echo Compare pretty...
    diff "$TESTBED/$TESTNAME/pretty.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/pretty.txt"
    ((ECODE=$?))

    if [ $ECODE -ne 0 ]
    then
	((NUM_FAIL+=1))
	cp "$TESTBED/$TESTNAME/pretty.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/pretty.txt"
    fi
fi

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/crossref.txt" ]
then
    echo Crossref program with options $GROUP_OPTIONS $TEST_OPTIONS
    cd "$TESTBED/$TESTNAME"
    ruby basic.rb --crossref $TESTNAME.bas --no-heading --print-width 0 >crossref.txt $GROUP_OPTIONS $TEST_OPTIONS
    cd ../..

    echo Compare crossref...
    diff "$TESTBED/$TESTNAME/crossref.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/crossref.txt"
    ((ECODE=$?))
    if [ $ECODE -ne 0 ]
    then
	((NUM_FAIL+=1))
	cp "$TESTBED/$TESTNAME/crossref.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/crossref.txt"
    fi
fi

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/stdout.txt" ]
then
    if [ -e "$TESTROOT/$TESTGROUP/run_options.txt" ]
    then
	GROUP_RUN_OPTIONS=$(<"$TESTROOT/$TESTGROUP/run_options.txt")
    fi

    if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/data/run_options.txt" ]
    then
	RUN_OPTIONS=$(<"$TESTROOT/$TESTGROUP/$TESTNAME/data/run_options.txt")
    fi

    echo Run program with options $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS

    if [ -e "$TESTBED/$TESTNAME/stdin.txt" ]
    then
	cd "$TESTBED/$TESTNAME"
	ruby basic.rb --no-timing $OPTIONS --run $TESTNAME.bas --print-width 0 --no-heading --echo-input <stdin.txt >stdout.txt $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS
	cd ../..
    else
	cd "$TESTBED/$TESTNAME"
	ruby basic.rb --no-timing $OPTIONS --run $TESTNAME.bas --print-width 0 --no-heading >stdout.txt $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS
	cd ../..
    fi

    echo Compare stdout...
    diff "$TESTBED/$TESTNAME/stdout.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/stdout.txt"
    ((ECODE=$?))

    if [ $ECODE -ne 0 ]
    then
	((NUM_FAIL+=1))
	cp "$TESTBED/$TESTNAME/stdout.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/stdout.txt"
    fi
fi

if [ -e "test/$TESTGROUP/$TESTNAME/ref/out_files.txt" ]
then
    while read F ; do
	echo Compare $F...
	diff "$TESTBED/$TESTNAME/$F" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/$F"
	((ECODE=$?))

	if [ $ECODE -ne 0 ]
	then
	    ((NUM_FAIL+=1))
	    cp "$TESTBED/$TESTNAME/$F" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/$F"
	fi
    done <"$TESTROOT/$TESTGROUP/$TESTNAME/ref/out_files.txt"
fi

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/trace.txt" ]
then
    if [ -e "$TESTROOT/$TESTGROUP/run_options.txt" ]
    then
	GROUP_RUN_OPTIONS=$(<"$TESTROOT/$TESTGROUP/run_options.txt")
    fi

    if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/data/run_options.txt" ]
    then
	RUN_OPTIONS=$(<"$TESTROOT/$TESTGROUP/$TESTNAME/data/run_options.txt")
    fi

    echo Trace program with options $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS

    if [ -e "$TESTBED/$TESTNAME/stdin.txt" ]
    then
	cd "$TESTBED/$TESTNAME"
	ruby basic.rb --no-timing $OPTIONS --run $TESTNAME.bas --print-width 0 --no-heading --trace --echo-input <stdin.txt >trace.txt $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS
	cd ../..
    else
	cd "$TESTBED/$TESTNAME"
	ruby basic.rb --no-timing $OPTIONS --run $TESTNAME.bas --print-width 0 --no-heading --trace >trace.txt $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS
	cd ../..
    fi

    echo Compare trace...
    diff "$TESTBED/$TESTNAME/trace.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/trace.txt"
    ((ECODE=$?))

    if [ $ECODE -ne 0 ]
    then
	((NUM_FAIL+=1))
	cp "$TESTBED/$TESTNAME/trace.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/trace.txt"
    fi
fi

echo End test $TESTNAME
exit $NUM_FAIL
