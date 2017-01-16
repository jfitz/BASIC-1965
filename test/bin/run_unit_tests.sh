TESTROOT=test
TESTBED=tests

echo Removing old directory
if [ -d "$TESTBED" ] ; then rm -r "$TESTBED" ; fi

echo Creating directory $TESTBED
mkdir "$TESTBED"

echo Running all tests...
ECODE=0

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit remark_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit remark_2
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit values
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit values_2
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit dataread
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit datarestore
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit input
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit input_2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit input_3
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit input_4
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit ifthen_ge
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit ifthen_gt
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit ifthen_le
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit ifthen_lt
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit ifthen_ne
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit ifthen_eq
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit ifthen_eq_error_1
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit print_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit print_2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit print_3
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit print_4
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit print_5
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit print_6
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit print_7
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit print_8
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit print_9 --implied-semicolon
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_n
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_n_plus_n
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_n_plus_v
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_n_minus_n
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_n_times_n
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_n_divide_n
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_v_plus_n
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_v_power_n
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_parens
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_n_uni_plus
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_n_uni_minus
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_error_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit let_targets
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit two_subscripts
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit gosub_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit return_no_gosub
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit fornext_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit fornext_2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit fornext_3
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit fornext_4
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit fornext_5
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit fornext_no_start
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit fornext_no_end
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit fornext_no_to
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit break_token
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit syntax_error_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit syntax_error_2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit syntax_error_3
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit syntax_error_4
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit syntax_error_5
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit bracket_mismatch_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit bracket_mismatch_2
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_int
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_int_floor --int-floor
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_sin
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_cos
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_tan
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_atn
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_sgn
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_exp
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_trn
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_idn
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_zer
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_con
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_det
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit function_inv
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit random_0
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit random_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit random_10 --ignore-rnd-arg
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit sqrabs
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit annular
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit define_2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit define_error
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_read
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_print_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_print_2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_print_3
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_let_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_let_uni_plus
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_let_uni_minus
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_let_targets
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_add_a_a
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_add_a_s
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_add_s_a
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_add_v_a
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_subtract_a_a
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_subtract_a_s
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_subtract_s_a
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_multiply_a_a
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_multiply_a_s
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_multiply_s_a
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_divide_a_a
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_divide_a_s
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_divide_s_a
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_power_a_a
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_power_a_s
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit arr_power_s_a
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_print_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_print_2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_print_3
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_print_4
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_let_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_let_uni_plus
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_let_uni_minus
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_let_targets
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_add_m_m
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_subtract_m_m
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_multiply_m_m
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_multiply_m_a
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_multiply_a_m
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_add_s_m
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_subtract_s_m
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_multiply_s_m
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_divide_s_m
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_power_s_m
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_add_v_m
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_add_m_s
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_subtract_m_s
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_multiply_m_s
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_divide_m_s
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit mat_power_m_s
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit files_no_file
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit files_print_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit files_print_2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit files_read_1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit files_read_2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit files_read_3
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit files_read_4
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit files_read_end
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit trace
((ECODE+=$?))

bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit celcius_to_fahrenheit
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" unit celcius_2
((ECODE+=$?))

echo
echo Failures: $ECODE

