echo Removing old directory
if [ -d tests ] ; then rm -r tests ; fi

echo Creating directory tests
mkdir tests

echo Running all tests...
ECODE=0

bash test/bin/run_unit_test.sh remark_1
((ECODE+=$?))
bash test/bin/run_unit_test.sh remark_2
((ECODE+=$?))

bash test/bin/run_unit_test.sh values
((ECODE+=$?))
bash test/bin/run_unit_test.sh values_2
((ECODE+=$?))

bash test/bin/run_unit_test.sh dataread
((ECODE+=$?))
bash test/bin/run_unit_test.sh datarestore
((ECODE+=$?))

bash test/bin/run_unit_test.sh input
((ECODE+=$?))

bash test/bin/run_unit_test.sh ifthen_ge
((ECODE+=$?))
bash test/bin/run_unit_test.sh ifthen_gt
((ECODE+=$?))
bash test/bin/run_unit_test.sh ifthen_le
((ECODE+=$?))
bash test/bin/run_unit_test.sh ifthen_lt
((ECODE+=$?))
bash test/bin/run_unit_test.sh ifthen_ne
((ECODE+=$?))
bash test/bin/run_unit_test.sh ifthen_eq
((ECODE+=$?))
bash test/bin/run_unit_test.sh ifthen_eq_error_1
((ECODE+=$?))

bash test/bin/run_unit_test.sh print_1
((ECODE+=$?))
bash test/bin/run_unit_test.sh print_2
((ECODE+=$?))
bash test/bin/run_unit_test.sh print_3
((ECODE+=$?))
bash test/bin/run_unit_test.sh print_4
((ECODE+=$?))
bash test/bin/run_unit_test.sh print_5
((ECODE+=$?))
bash test/bin/run_unit_test.sh print_6
((ECODE+=$?))
bash test/bin/run_unit_test.sh print_7
((ECODE+=$?))

bash test/bin/run_unit_test.sh let_n
((ECODE+=$?))
bash test/bin/run_unit_test.sh let_n_plus_n
((ECODE+=$?))
bash test/bin/run_unit_test.sh let_n_plus_v
((ECODE+=$?))
bash test/bin/run_unit_test.sh let_n_minus_n
((ECODE+=$?))
bash test/bin/run_unit_test.sh let_n_times_n
((ECODE+=$?))
bash test/bin/run_unit_test.sh let_n_divide_n
((ECODE+=$?))
bash test/bin/run_unit_test.sh let_v_plus_n
((ECODE+=$?))
bash test/bin/run_unit_test.sh let_v_power_n
((ECODE+=$?))
bash test/bin/run_unit_test.sh let_parens
((ECODE+=$?))
bash test/bin/run_unit_test.sh let_n_uni_plus
((ECODE+=$?))
bash test/bin/run_unit_test.sh let_n_uni_minus
((ECODE+=$?))
bash test/bin/run_unit_test.sh let_error_1
((ECODE+=$?))

bash test/bin/run_unit_test.sh two_subscripts
((ECODE+=$?))

bash test/bin/run_unit_test.sh gosub_1
((ECODE+=$?))
bash test/bin/run_unit_test.sh return_no_gosub
((ECODE+=$?))

bash test/bin/run_unit_test.sh fornext_1
((ECODE+=$?))
bash test/bin/run_unit_test.sh fornext_2
((ECODE+=$?))
bash test/bin/run_unit_test.sh fornext_3
((ECODE+=$?))
bash test/bin/run_unit_test.sh fornext_4
((ECODE+=$?))
bash test/bin/run_unit_test.sh fornext_5
((ECODE+=$?))
bash test/bin/run_unit_test.sh fornext_no_start
((ECODE+=$?))
bash test/bin/run_unit_test.sh fornext_no_end
((ECODE+=$?))
bash test/bin/run_unit_test.sh fornext_no_to
((ECODE+=$?))

bash test/bin/run_unit_test.sh syntax_error_1
((ECODE+=$?))
bash test/bin/run_unit_test.sh syntax_error_2
((ECODE+=$?))
bash test/bin/run_unit_test.sh syntax_error_3
((ECODE+=$?))
bash test/bin/run_unit_test.sh syntax_error_4
((ECODE+=$?))

bash test/bin/run_unit_test.sh function_int
((ECODE+=$?))
bash test/bin/run_unit_test.sh function_sin
((ECODE+=$?))
bash test/bin/run_unit_test.sh function_cos
((ECODE+=$?))
bash test/bin/run_unit_test.sh function_tan
((ECODE+=$?))
bash test/bin/run_unit_test.sh function_atn
((ECODE+=$?))
bash test/bin/run_unit_test.sh function_sgn
((ECODE+=$?))
bash test/bin/run_unit_test.sh function_exp
((ECODE+=$?))

bash test/bin/run_unit_test.sh function_trn
((ECODE+=$?))
bash test/bin/run_unit_test.sh function_idn
((ECODE+=$?))
bash test/bin/run_unit_test.sh function_zer
((ECODE+=$?))
bash test/bin/run_unit_test.sh function_con
((ECODE+=$?))
bash test/bin/run_unit_test.sh function_det
((ECODE+=$?))
bash test/bin/run_unit_test.sh function_inv
((ECODE+=$?))
bash test/bin/run_unit_test.sh random_0
((ECODE+=$?))
bash test/bin/run_unit_test.sh random_1
((ECODE+=$?))

bash test/bin/run_unit_test.sh define_2
((ECODE+=$?))
bash test/bin/run_unit_test.sh define_error
((ECODE+=$?))

bash test/bin/run_unit_test.sh mat_print_1
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_print_2
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_print_3
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_print_4
((ECODE+=$?))

bash test/bin/run_unit_test.sh mati-0
((ECODE+=$?))
bash test/bin/run_unit_test.sh mati-1
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_let_1
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_let_uni_plus
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_let_uni_minus
((ECODE+=$?))

bash test/bin/run_unit_test.sh mat_add_m_m
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_subtract_m_m
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_multiply_m_m
((ECODE+=$?))

bash test/bin/run_unit_test.sh mat_multiply_m_a
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_multiply_a_m
((ECODE+=$?))

bash test/bin/run_unit_test.sh mat_add_s_m
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_subtract_s_m
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_multiply_s_m
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_divide_s_m
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_power_s_m
((ECODE+=$?))

bash test/bin/run_unit_test.sh mat_add_v_m
((ECODE+=$?))

bash test/bin/run_unit_test.sh mat_add_m_s
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_subtract_m_s
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_multiply_m_s
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_divide_m_s
((ECODE+=$?))
bash test/bin/run_unit_test.sh mat_power_m_s
((ECODE+=$?))

bash test/bin/run_unit_test.sh trace
((ECODE+=$?))

bash test/bin/run_unit_test.sh celcius_to_fahrenheit
((ECODE+=$?))
bash test/bin/run_unit_test.sh celcius_2
((ECODE+=$?))

echo
echo Failures: $ECODE

