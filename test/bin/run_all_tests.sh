echo Removing old directory
if [ -d tests ] ; then rm -r tests ; fi

echo Creating directory tests
mkdir tests

echo Running all tests...
bash test/bin/run_one_test.sh remarks
bash test/bin/run_one_test.sh dataread
bash test/bin/run_one_test.sh ifthen_ge
bash test/bin/run_one_test.sh ifthen_gt
bash test/bin/run_one_test.sh ifthen_le
bash test/bin/run_one_test.sh ifthen_lt
bash test/bin/run_one_test.sh ifthen_ne
bash test/bin/run_one_test.sh ifthen_eq
bash test/bin/run_one_test.sh print_1
bash test/bin/run_one_test.sh print_2
bash test/bin/run_one_test.sh print_3
bash test/bin/run_one_test.sh print_4
bash test/bin/run_one_test.sh print_5
