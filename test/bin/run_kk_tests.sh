TESTROOT=test
TESTBED=tests

echo Removing old directory
if [ -d "$TESTBED" ] ; then rm -r "$TESTBED" ; fi

echo Creating directory $TESTBED
mkdir "$TESTBED"

echo Running all tests...
ECODE=0

# chapter 1
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk convert
((ECODE+=$?))

# chapter 2
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk loop
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk loop1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk binom
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk table
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk roots
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk lrgfct
((ECODE+=$?))

# chapter 3
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk sales
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk income
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk order
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk rc-sum
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk inverse_7
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk inverse_9
((ECODE+=$?))

# chapter 4
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk define
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk trig
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk trig2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk subr
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk truth
((ECODE+=$?))

# chapter 5
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk degree
((ECODE+=$?))

# chapter 6

# chapter 7
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk trig-1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk trig-2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk trig-3
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk zero-1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk zero-2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk zero-3
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk zero-4
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk plot
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk plotxy
((ECODE+=$?))

# chapter 8
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk factor
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk euclid
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk china
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk add300
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk mpy300
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk prim-1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk primes
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk hgpr
((ECODE+=$?))

# chapter 9
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk random_float
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk random_int
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk dice
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk deal
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk bridge
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk needle
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk dodger
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk knight
((ECODE+=$?))

# chapter 10
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk batnum
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk nim
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk tictac
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk tic-2
((ECODE+=$?))

# chapter 11
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk comp-1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk comp-2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk tax-1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk tax-2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk tax-3
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk decide
((ECODE+=$?))

# chapter 12
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk stat
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk linreg
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk contin
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk 2-by-2
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk rnksum
((ECODE+=$?))

# chapter 13
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk mati-0
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk mati-1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk matops
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk matmpy
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk matpwr
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk matinv
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk linequ
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk net
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk tchain
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk echain
((ECODE+=$?))

# chapter 14
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk poly
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk integr
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk taylor
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk diffeq
((ECODE+=$?))

# chapter 15
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk teachm
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk code
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk foxrab
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk fxrb-1
((ECODE+=$?))
bash "$TESTROOT/bin/run_test.sh" "$TESTROOT" "$TESTBED" kk music
((ECODE+=$?))

echo
echo Failures: $ECODE

