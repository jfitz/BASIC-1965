echo Removing old directory
if [ -d tests ] ; then rm -r tests ; fi

echo Creating directory tests
mkdir tests

echo Running all tests...
ECODE=0

# chapter 1
bash test/bin/run_kk_test.sh convert
((ECODE+=$?))

# chapter 2
bash test/bin/run_kk_test.sh binom
((ECODE+=$?))
bash test/bin/run_kk_test.sh table
((ECODE+=$?))
bash test/bin/run_kk_test.sh roots
((ECODE+=$?))
bash test/bin/run_kk_test.sh lrgfct
((ECODE+=$?))

# chapter 3
bash test/bin/run_kk_test.sh sales
((ECODE+=$?))
bash test/bin/run_kk_test.sh income
((ECODE+=$?))
bash test/bin/run_kk_test.sh order
((ECODE+=$?))
bash test/bin/run_kk_test.sh rc-sum
((ECODE+=$?))
bash test/bin/run_kk_test.sh inverse_7
((ECODE+=$?))
bash test/bin/run_kk_test.sh inverse_9
((ECODE+=$?))

# chapter 4
bash test/bin/run_kk_test.sh define
((ECODE+=$?))
bash test/bin/run_kk_test.sh trig
((ECODE+=$?))
bash test/bin/run_kk_test.sh trig2
((ECODE+=$?))
bash test/bin/run_kk_test.sh subr
((ECODE+=$?))
bash test/bin/run_kk_test.sh truth
((ECODE+=$?))

# chapter 5
bash test/bin/run_kk_test.sh degree
((ECODE+=$?))

# chapter 6

# chapter 7
bash test/bin/run_kk_test.sh trig-1
((ECODE+=$?))
bash test/bin/run_kk_test.sh trig-2
((ECODE+=$?))
bash test/bin/run_kk_test.sh trig-3
((ECODE+=$?))
bash test/bin/run_kk_test.sh zero-1
((ECODE+=$?))
bash test/bin/run_kk_test.sh zero-2
((ECODE+=$?))
bash test/bin/run_kk_test.sh zero-3
((ECODE+=$?))
bash test/bin/run_kk_test.sh zero-4
((ECODE+=$?))
bash test/bin/run_kk_test.sh plot
((ECODE+=$?))
bash test/bin/run_kk_test.sh plotxy
((ECODE+=$?))

# chapter 8
# factor
# euclid
bash test/bin/run_kk_test.sh china
((ECODE+=$?))
# add300
# mpy300
# prim-1
# primes
# hgpr

# chapter 9
bash test/bin/run_kk_test.sh random_float
((ECODE+=$?))
bash test/bin/run_kk_test.sh random_int
((ECODE+=$?))
bash test/bin/run_kk_test.sh dice
((ECODE+=$?))
bash test/bin/run_kk_test.sh deal
((ECODE+=$?))
# bridge
bash test/bin/run_kk_test.sh needle
((ECODE+=$?))
#dodger
bash test/bin/run_kk_test.sh knight
((ECODE+=$?))

# chapter 10
# batnum
# nim
# tictac
# tic-2

# chapter 11
# comp-1
# comp-2
# tax-1
# tax-2
# tax-3
# decide

# chapter 12
# stat
# linreg
# contin
# 2-by-2
# rnksum

# chapter 13
bash test/bin/run_kk_test.sh mati-0
((ECODE+=$?))
bash test/bin/run_kk_test.sh mati-1
((ECODE+=$?))
bash test/bin/run_kk_test.sh matops
((ECODE+=$?))
bash test/bin/run_kk_test.sh matmpy
((ECODE+=$?))
bash test/bin/run_kk_test.sh matpwr
((ECODE+=$?))
bash test/bin/run_kk_test.sh matinv
((ECODE+=$?))
bash test/bin/run_kk_test.sh linequ
((ECODE+=$?))
# net
# tchain
# echain

# chapter 14
# poly
# integr
# taylor
# diffeq

# chapter 15
# teachm
# code
# foxrab
# fxrb-1
# music

bash test/bin/run_kk_test.sh sqrabs
((ECODE+=$?))
bash test/bin/run_kk_test.sh annular
((ECODE+=$?))

echo
echo Failures: $ECODE

