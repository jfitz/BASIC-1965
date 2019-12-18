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
    echo RUBOCOP of $F
    rubocop $F | tee "$TESTBED"/$FN.txt | grep offenses | sed -e "s/^.*,//"
done
