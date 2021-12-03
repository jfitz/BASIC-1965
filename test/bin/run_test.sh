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
    diff "$TESTROOT/$TESTGROUP/$TESTNAME/ref/list.txt" "$TESTBED/$TESTNAME/list.txt"
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
    diff "$TESTROOT/$TESTGROUP/$TESTNAME/ref/parse.txt" "$TESTBED/$TESTNAME/parse.txt"
    ((ECODE=$?))

    if [ $ECODE -ne 0 ]
    then
	((NUM_FAIL+=1))
	cp "$TESTBED/$TESTNAME/parse.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/parse.txt"
    fi
fi

if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/analyze.txt" ]
then
    if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/data/analyze_options.txt" ]
    then
	ANALYZE_OPTIONS=$(<"$TESTROOT/$TESTGROUP/$TESTNAME/data/analyze_options.txt")
    fi

    echo Analyze program with options $GROUP_OPTIONS $TEST_OPTIONS $ANALYZE_OPTIONS
    cd "$TESTBED/$TESTNAME"
    ruby basic.rb --analyze $TESTNAME.bas --no-heading --print-width 0 >analyze.txt 2>analyze.err $GROUP_OPTIONS $TEST_OPTIONS $ANALYZE_OPTIONS
    cd ../..

    echo Compare analyze stdout...
    diff "$TESTROOT/$TESTGROUP/$TESTNAME/ref/analyze.txt" "$TESTBED/$TESTNAME/analyze.txt"
    ((ECODE=$?))

    if [ $ECODE -ne 0 ]
    then
	((NUM_FAIL+=1))
	cp "$TESTBED/$TESTNAME/analyze.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/analyze.txt"
    fi

    if [ -e "$TESTROOT/$TESTGROUP/$TESTNAME/ref/analyze.err" ]
    then
	echo Compare analyze stderr...
	diff "$TESTROOT/$TESTGROUP/$TESTNAME/ref/analyze.err" "$TESTBED/$TESTNAME/analyze.err"
	((ECODE=$?))

	if [ $ECODE -ne 0 ]
	then
	    ((NUM_FAIL+=1))
	    cp "$TESTBED/$TESTNAME/analyze.err" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/analyze.err"
	fi
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
    diff "$TESTROOT/$TESTGROUP/$TESTNAME/ref/pretty.txt" "$TESTBED/$TESTNAME/pretty.txt"
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
    diff "$TESTROOT/$TESTGROUP/$TESTNAME/ref/crossref.txt" "$TESTBED/$TESTNAME/crossref.txt"
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
	ruby basic.rb --no-timing --profile $OPTIONS --run $TESTNAME.bas --print-width 0 --no-heading --echo-input <stdin.txt >stdout.txt $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS
	cd ../..
    else
	cd "$TESTBED/$TESTNAME"
	ruby basic.rb --no-timing --profile $OPTIONS --run $TESTNAME.bas --print-width 0 --no-heading >stdout.txt $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS
	cd ../..
    fi

    echo Compare stdout...
    diff "$TESTROOT/$TESTGROUP/$TESTNAME/ref/stdout.txt" "$TESTBED/$TESTNAME/stdout.txt"
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
	diff "$TESTROOT/$TESTGROUP/$TESTNAME/ref/$F" "$TESTBED/$TESTNAME/$F"
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
    diff "$TESTROOT/$TESTGROUP/$TESTNAME/ref/trace.txt" "$TESTBED/$TESTNAME/trace.txt"
    ((ECODE=$?))

    if [ $ECODE -ne 0 ]
    then
	((NUM_FAIL+=1))
	cp "$TESTBED/$TESTNAME/trace.txt" "$TESTROOT/$TESTGROUP/$TESTNAME/ref/trace.txt"
    fi
fi

echo End test $TESTNAME
exit $NUM_FAIL
