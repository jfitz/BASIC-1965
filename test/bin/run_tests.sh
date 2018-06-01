#!/bin/bash

TESTROOT=test
TESTBED=tests
TESTGROUP=$1

echo Removing old directory
if [ -d "$TESTBED" ] ; then rm -r "$TESTBED" ; fi

echo Creating directory $TESTBED
mkdir "$TESTBED"

echo Running all tests...
ECODE=0

for F in "$TESTROOT/$TESTGROUP"/*; do
    bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" "$TESTGROUP" ${F##*/}
    ((ECODE+=$?))
done

echo
echo Failures: $ECODE
