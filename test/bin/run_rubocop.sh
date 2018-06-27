#!/bin/bash

TESTBED=tests/rubocop

if [ -d "$TESTBED" ]
then
    echo Removing old directory
    rm -r "$TESTBED"
fi

mkdir "$TESTBED"

for F in bin/*; do
    FP=${F##*/}
    FN=${FP%.*}
    echo RUBOCOP of $F to "$TESTBED"/$FN.txt
    rubocop $F >"$TESTBED"/$FN.txt
done
