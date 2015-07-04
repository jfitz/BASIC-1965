echo Removing old directory
if [ -d tests ] ; then rm -r tests ; fi

echo Creating directory tests
mkdir tests

echo Running all tests...
bash test/bin/run_one_test.sh remark_1
bash test/bin/run_one_test.sh remark_2
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
bash test/bin/run_one_test.sh print_6

bash test/bin/run_one_test.sh let_n
bash test/bin/run_one_test.sh let_n_plus_n
bash test/bin/run_one_test.sh let_n_plus_v
bash test/bin/run_one_test.sh let_n_minus_n
bash test/bin/run_one_test.sh let_n_times_n
bash test/bin/run_one_test.sh let_n_divide_n
bash test/bin/run_one_test.sh let_v_plus_n
bash test/bin/run_one_test.sh let_v_power_n
bash test/bin/run_one_test.sh let_parens

bash test/bin/run_one_test.sh two_subscripts

bash test/bin/run_one_test.sh gosub_1
bash test/bin/run_one_test.sh return_no_gosub
bash test/bin/run_one_test.sh fornext_1
bash test/bin/run_one_test.sh fornext_2
bash test/bin/run_one_test.sh fornext_3
bash test/bin/run_one_test.sh fornext_4

bash test/bin/run_one_test.sh syntax_error_1
bash test/bin/run_one_test.sh syntax_error_2

bash test/bin/run_one_test.sh function_int
bash test/bin/run_one_test.sh function_sin
bash test/bin/run_one_test.sh function_cos
bash test/bin/run_one_test.sh function_tan
bash test/bin/run_one_test.sh function_atn
bash test/bin/run_one_test.sh function_sgn

bash test/bin/run_one_test.sh mat_print_1

bash test/bin/run_one_test.sh celcius_to_fahrenheit
bash test/bin/run_one_test.sh celcius_2

bash test/bin/run_one_test.sh binom
bash test/bin/run_one_test.sh convert
bash test/bin/run_one_test.sh lrgfct
bash test/bin/run_one_test.sh roots
bash test/bin/run_one_test.sh sales
bash test/bin/run_one_test.sh sqrabs
bash test/bin/run_one_test.sh table
bash test/bin/run_one_test.sh income
bash test/bin/run_one_test.sh rc-sum
bash test/bin/run_one_test.sh inverse_7
bash test/bin/run_one_test.sh inverse_9
bash test/bin/run_one_test.sh define
bash test/bin/run_one_test.sh trig-1
bash test/bin/run_one_test.sh trig-2
bash test/bin/run_one_test.sh trig-3
bash test/bin/run_one_test.sh zero-1
bash test/bin/run_one_test.sh zero-2
bash test/bin/run_one_test.sh zero-3
bash test/bin/run_one_test.sh zero-4
bash test/bin/run_one_test.sh plot
bash test/bin/run_one_test.sh plotxy

