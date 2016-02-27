echo Removing old directory
if [ -d tests ] ; then rm -r tests ; fi

echo Creating directory tests
mkdir tests

echo Running all tests...
ECODE=0

bash test/bin/run_one_test.sh binom
((ECODE+=$?))
bash test/bin/run_one_test.sh china
((ECODE+=$?))

bash test/bin/run_one_test.sh convert
((ECODE+=$?))
bash test/bin/run_one_test.sh lrgfct
((ECODE+=$?))

bash test/bin/run_one_test.sh roots
((ECODE+=$?))
bash test/bin/run_one_test.sh sales
((ECODE+=$?))
bash test/bin/run_one_test.sh sqrabs
((ECODE+=$?))

bash test/bin/run_one_test.sh table
((ECODE+=$?))
bash test/bin/run_one_test.sh income
((ECODE+=$?))
bash test/bin/run_one_test.sh rc-sum
((ECODE+=$?))

bash test/bin/run_one_test.sh inverse_7
((ECODE+=$?))
bash test/bin/run_one_test.sh inverse_9
((ECODE+=$?))

bash test/bin/run_one_test.sh define
((ECODE+=$?))

bash test/bin/run_one_test.sh trig-1
((ECODE+=$?))
bash test/bin/run_one_test.sh trig-2
((ECODE+=$?))
bash test/bin/run_one_test.sh trig-3
((ECODE+=$?))

bash test/bin/run_one_test.sh zero-1
((ECODE+=$?))
bash test/bin/run_one_test.sh zero-2
((ECODE+=$?))
bash test/bin/run_one_test.sh zero-3
((ECODE+=$?))
bash test/bin/run_one_test.sh zero-4
((ECODE+=$?))

bash test/bin/run_one_test.sh matops
((ECODE+=$?))
bash test/bin/run_one_test.sh matmpy
((ECODE+=$?))
bash test/bin/run_one_test.sh matpwr
((ECODE+=$?))
bash test/bin/run_one_test.sh matinv
((ECODE+=$?))
bash test/bin/run_one_test.sh linequ
((ECODE+=$?))

bash test/bin/run_one_test.sh plot
((ECODE+=$?))
bash test/bin/run_one_test.sh plotxy
((ECODE+=$?))

echo
echo Failures: $ECODE

