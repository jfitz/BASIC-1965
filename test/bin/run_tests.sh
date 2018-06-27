#!/bin/bash

TESTROOT=test
TESTBED=tests
TESTGROUP=$1

if [ ! -d "$TESTROOT" ]
then
    mkdir "$TESTROOT"
fi

if [ -d "$TESTBED" ]
then
    echo Removing old directory
    rm -r "$TESTBED"
fi

echo Creating directory $TESTBED
mkdir "$TESTBED"

echo Running all tests...
ECODE=0

for F in "$TESTROOT/$TESTGROUP"/*; do
    if [ -d "$F" ]; then
	bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" "$TESTGROUP" ${F##*/}
	((ECODE+=$?))
    fi
done

echo
echo Failures: $ECODE
