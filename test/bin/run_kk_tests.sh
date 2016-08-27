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
bash test/bin/run_kk_test.sh loop
((ECODE+=$?))
bash test/bin/run_kk_test.sh loop1
((ECODE+=$?))
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
bash test/bin/run_kk_test.sh factor
((ECODE+=$?))
bash test/bin/run_kk_test.sh euclid
((ECODE+=$?))
bash test/bin/run_kk_test.sh china
((ECODE+=$?))
bash test/bin/run_kk_test.sh add300
((ECODE+=$?))
bash test/bin/run_kk_test.sh mpy300
((ECODE+=$?))
bash test/bin/run_kk_test.sh prim-1
((ECODE+=$?))
bash test/bin/run_kk_test.sh primes
((ECODE+=$?))
bash test/bin/run_kk_test.sh hgpr
((ECODE+=$?))

# chapter 9
bash test/bin/run_kk_test.sh random_float
((ECODE+=$?))
bash test/bin/run_kk_test.sh random_int
((ECODE+=$?))
bash test/bin/run_kk_test.sh dice
((ECODE+=$?))
bash test/bin/run_kk_test.sh deal
((ECODE+=$?))
bash test/bin/run_kk_test.sh bridge
((ECODE+=$?))
bash test/bin/run_kk_test.sh needle
((ECODE+=$?))
bash test/bin/run_kk_test.sh dodger
((ECODE+=$?))
bash test/bin/run_kk_test.sh knight
((ECODE+=$?))

# chapter 10
bash test/bin/run_kk_test.sh batnum
((ECODE+=$?))
bash test/bin/run_kk_test.sh nim
((ECODE+=$?))
bash test/bin/run_kk_test.sh tictac
((ECODE+=$?))
bash test/bin/run_kk_test.sh tic-2
((ECODE+=$?))

# chapter 11
bash test/bin/run_kk_test.sh comp-1
((ECODE+=$?))
bash test/bin/run_kk_test.sh comp-2
((ECODE+=$?))
bash test/bin/run_kk_test.sh tax-1
((ECODE+=$?))
bash test/bin/run_kk_test.sh tax-2
((ECODE+=$?))
bash test/bin/run_kk_test.sh tax-3
((ECODE+=$?))
bash test/bin/run_kk_test.sh decide
((ECODE+=$?))

# chapter 12
bash test/bin/run_kk_test.sh stat
((ECODE+=$?))
bash test/bin/run_kk_test.sh linreg
((ECODE+=$?))
bash test/bin/run_kk_test.sh contin
((ECODE+=$?))
bash test/bin/run_kk_test.sh 2-by-2
((ECODE+=$?))
bash test/bin/run_kk_test.sh rnksum
((ECODE+=$?))

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
bash test/bin/run_kk_test.sh net
((ECODE+=$?))
bash test/bin/run_kk_test.sh tchain
((ECODE+=$?))
bash test/bin/run_kk_test.sh echain
((ECODE+=$?))

# chapter 14
bash test/bin/run_kk_test.sh poly
((ECODE+=$?))
bash test/bin/run_kk_test.sh integr
((ECODE+=$?))
bash test/bin/run_kk_test.sh taylor
((ECODE+=$?))
bash test/bin/run_kk_test.sh diffeq
((ECODE+=$?))

# chapter 15
bash test/bin/run_kk_test.sh teachm
((ECODE+=$?))
bash test/bin/run_kk_test.sh code
((ECODE+=$?))
bash test/bin/run_kk_test.sh foxrab
((ECODE+=$?))
bash test/bin/run_kk_test.sh fxrb-1
((ECODE+=$?))
bash test/bin/run_kk_test.sh music
((ECODE+=$?))

echo
echo Failures: $ECODE

