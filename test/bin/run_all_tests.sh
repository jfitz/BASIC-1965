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
bash test/bin/run_one_test.sh let_n
bash test/bin/run_one_test.sh let_n_plus_n
bash test/bin/run_one_test.sh let_n_minus_n
bash test/bin/run_one_test.sh let_n_times_n
bash test/bin/run_one_test.sh let_n_divide_n
bash test/bin/run_one_test.sh let_v_plus_n
bash test/bin/run_one_test.sh let_n_plus_v
bash test/bin/run_one_test.sh gosub_1
bash test/bin/run_one_test.sh return_no_gosub
bash test/bin/run_one_test.sh fornext_1
bash test/bin/run_one_test.sh fornext_2
bash test/bin/run_one_test.sh celcius_to_fahrenheit