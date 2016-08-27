echo Removing old directory
if [ -d tests ] ; then rm -r tests ; fi

echo Creating directory tests
mkdir tests

echo Running all tests...
ECODE=0

bash test/bin/run_test.sh unit remark_1
((ECODE+=$?))
bash test/bin/run_test.sh unit remark_2
((ECODE+=$?))

bash test/bin/run_test.sh unit values
((ECODE+=$?))
bash test/bin/run_test.sh unit values_2
((ECODE+=$?))

bash test/bin/run_test.sh unit dataread
((ECODE+=$?))
bash test/bin/run_test.sh unit datarestore
((ECODE+=$?))

bash test/bin/run_test.sh unit input
((ECODE+=$?))

bash test/bin/run_test.sh unit ifthen_ge
((ECODE+=$?))
bash test/bin/run_test.sh unit ifthen_gt
((ECODE+=$?))
bash test/bin/run_test.sh unit ifthen_le
((ECODE+=$?))
bash test/bin/run_test.sh unit ifthen_lt
((ECODE+=$?))
bash test/bin/run_test.sh unit ifthen_ne
((ECODE+=$?))
bash test/bin/run_test.sh unit ifthen_eq
((ECODE+=$?))
bash test/bin/run_test.sh unit ifthen_eq_error_1
((ECODE+=$?))

bash test/bin/run_test.sh unit print_1
((ECODE+=$?))
bash test/bin/run_test.sh unit print_2
((ECODE+=$?))
bash test/bin/run_test.sh unit print_3
((ECODE+=$?))
bash test/bin/run_test.sh unit print_4
((ECODE+=$?))
bash test/bin/run_test.sh unit print_5
((ECODE+=$?))
bash test/bin/run_test.sh unit print_6
((ECODE+=$?))
bash test/bin/run_test.sh unit print_7
((ECODE+=$?))
bash test/bin/run_test.sh unit print_8
((ECODE+=$?))
bash test/bin/run_test.sh unit print_9 --implied-semicolon
((ECODE+=$?))

bash test/bin/run_test.sh unit let_n
((ECODE+=$?))
bash test/bin/run_test.sh unit let_n_plus_n
((ECODE+=$?))
bash test/bin/run_test.sh unit let_n_plus_v
((ECODE+=$?))
bash test/bin/run_test.sh unit let_n_minus_n
((ECODE+=$?))
bash test/bin/run_test.sh unit let_n_times_n
((ECODE+=$?))
bash test/bin/run_test.sh unit let_n_divide_n
((ECODE+=$?))
bash test/bin/run_test.sh unit let_v_plus_n
((ECODE+=$?))
bash test/bin/run_test.sh unit let_v_power_n
((ECODE+=$?))
bash test/bin/run_test.sh unit let_parens
((ECODE+=$?))
bash test/bin/run_test.sh unit let_n_uni_plus
((ECODE+=$?))
bash test/bin/run_test.sh unit let_n_uni_minus
((ECODE+=$?))
bash test/bin/run_test.sh unit let_error_1
((ECODE+=$?))
bash test/bin/run_test.sh unit let_targets
((ECODE+=$?))

bash test/bin/run_test.sh unit two_subscripts
((ECODE+=$?))

bash test/bin/run_test.sh unit gosub_1
((ECODE+=$?))
bash test/bin/run_test.sh unit return_no_gosub
((ECODE+=$?))

bash test/bin/run_test.sh unit fornext_1
((ECODE+=$?))
bash test/bin/run_test.sh unit fornext_2
((ECODE+=$?))
bash test/bin/run_test.sh unit fornext_3
((ECODE+=$?))
bash test/bin/run_test.sh unit fornext_4
((ECODE+=$?))
bash test/bin/run_test.sh unit fornext_5
((ECODE+=$?))
bash test/bin/run_test.sh unit fornext_no_start
((ECODE+=$?))
bash test/bin/run_test.sh unit fornext_no_end
((ECODE+=$?))
bash test/bin/run_test.sh unit fornext_no_to
((ECODE+=$?))

bash test/bin/run_test.sh unit syntax_error_1
((ECODE+=$?))
bash test/bin/run_test.sh unit syntax_error_2
((ECODE+=$?))
bash test/bin/run_test.sh unit syntax_error_3
((ECODE+=$?))
bash test/bin/run_test.sh unit syntax_error_4
((ECODE+=$?))
bash test/bin/run_test.sh unit bracket_mismatch_1
((ECODE+=$?))
bash test/bin/run_test.sh unit bracket_mismatch_2
((ECODE+=$?))

bash test/bin/run_test.sh unit function_int
((ECODE+=$?))
bash test/bin/run_test.sh unit function_int_floor --int-floor
((ECODE+=$?))
bash test/bin/run_test.sh unit function_sin
((ECODE+=$?))
bash test/bin/run_test.sh unit function_cos
((ECODE+=$?))
bash test/bin/run_test.sh unit function_tan
((ECODE+=$?))
bash test/bin/run_test.sh unit function_atn
((ECODE+=$?))
bash test/bin/run_test.sh unit function_sgn
((ECODE+=$?))
bash test/bin/run_test.sh unit function_exp
((ECODE+=$?))

bash test/bin/run_test.sh unit function_trn
((ECODE+=$?))
bash test/bin/run_test.sh unit function_idn
((ECODE+=$?))
bash test/bin/run_test.sh unit function_zer
((ECODE+=$?))
bash test/bin/run_test.sh unit function_con
((ECODE+=$?))
bash test/bin/run_test.sh unit function_det
((ECODE+=$?))
bash test/bin/run_test.sh unit function_inv
((ECODE+=$?))
bash test/bin/run_test.sh unit random_0
((ECODE+=$?))
bash test/bin/run_test.sh unit random_1
((ECODE+=$?))
bash test/bin/run_test.sh unit random_10 --ignore-rnd-arg
((ECODE+=$?))

bash test/bin/run_test.sh unit sqrabs
((ECODE+=$?))
bash test/bin/run_test.sh unit annular
((ECODE+=$?))

bash test/bin/run_test.sh unit define_2
((ECODE+=$?))
bash test/bin/run_test.sh unit define_error
((ECODE+=$?))

bash test/bin/run_test.sh unit mat_print_1
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_print_2
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_print_3
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_print_4
((ECODE+=$?))

bash test/bin/run_test.sh unit mat_let_1
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_let_uni_plus
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_let_uni_minus
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_let_targets
((ECODE+=$?))

bash test/bin/run_test.sh unit mat_add_m_m
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_subtract_m_m
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_multiply_m_m
((ECODE+=$?))

bash test/bin/run_test.sh unit mat_multiply_m_a
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_multiply_a_m
((ECODE+=$?))

bash test/bin/run_test.sh unit mat_add_s_m
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_subtract_s_m
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_multiply_s_m
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_divide_s_m
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_power_s_m
((ECODE+=$?))

bash test/bin/run_test.sh unit mat_add_v_m
((ECODE+=$?))

bash test/bin/run_test.sh unit mat_add_m_s
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_subtract_m_s
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_multiply_m_s
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_divide_m_s
((ECODE+=$?))
bash test/bin/run_test.sh unit mat_power_m_s
((ECODE+=$?))

bash test/bin/run_test.sh unit trace
((ECODE+=$?))

bash test/bin/run_test.sh unit celcius_to_fahrenheit
((ECODE+=$?))
bash test/bin/run_test.sh unit celcius_2
((ECODE+=$?))

echo
echo Failures: $ECODE

