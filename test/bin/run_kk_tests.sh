echo Removing old directory
if [ -d tests ] ; then rm -r tests ; fi

echo Creating directory tests
mkdir tests

echo Running all tests...
ECODE=0

# chapter 1
bash test/bin/run_test.sh kk convert
((ECODE+=$?))

# chapter 2
bash test/bin/run_test.sh kk loop
((ECODE+=$?))
bash test/bin/run_test.sh kk loop1
((ECODE+=$?))
bash test/bin/run_test.sh kk binom
((ECODE+=$?))
bash test/bin/run_test.sh kk table
((ECODE+=$?))
bash test/bin/run_test.sh kk roots
((ECODE+=$?))
bash test/bin/run_test.sh kk lrgfct
((ECODE+=$?))

# chapter 3
bash test/bin/run_test.sh kk sales
((ECODE+=$?))
bash test/bin/run_test.sh kk income
((ECODE+=$?))
bash test/bin/run_test.sh kk order
((ECODE+=$?))
bash test/bin/run_test.sh kk rc-sum
((ECODE+=$?))
bash test/bin/run_test.sh kk inverse_7
((ECODE+=$?))
bash test/bin/run_test.sh kk inverse_9
((ECODE+=$?))

# chapter 4
bash test/bin/run_test.sh kk define
((ECODE+=$?))
bash test/bin/run_test.sh kk trig
((ECODE+=$?))
bash test/bin/run_test.sh kk trig2
((ECODE+=$?))
bash test/bin/run_test.sh kk subr
((ECODE+=$?))
bash test/bin/run_test.sh kk truth
((ECODE+=$?))

# chapter 5
bash test/bin/run_test.sh kk degree
((ECODE+=$?))

# chapter 6

# chapter 7
bash test/bin/run_test.sh kk trig-1
((ECODE+=$?))
bash test/bin/run_test.sh kk trig-2
((ECODE+=$?))
bash test/bin/run_test.sh kk trig-3
((ECODE+=$?))
bash test/bin/run_test.sh kk zero-1
((ECODE+=$?))
bash test/bin/run_test.sh kk zero-2
((ECODE+=$?))
bash test/bin/run_test.sh kk zero-3
((ECODE+=$?))
bash test/bin/run_test.sh kk zero-4
((ECODE+=$?))
bash test/bin/run_test.sh kk plot
((ECODE+=$?))
bash test/bin/run_test.sh kk plotxy
((ECODE+=$?))

# chapter 8
bash test/bin/run_test.sh kk factor
((ECODE+=$?))
bash test/bin/run_test.sh kk euclid
((ECODE+=$?))
bash test/bin/run_test.sh kk china
((ECODE+=$?))
bash test/bin/run_test.sh kk add300
((ECODE+=$?))
bash test/bin/run_test.sh kk mpy300
((ECODE+=$?))
bash test/bin/run_test.sh kk prim-1
((ECODE+=$?))
bash test/bin/run_test.sh kk primes
((ECODE+=$?))
bash test/bin/run_test.sh kk hgpr
((ECODE+=$?))

# chapter 9
bash test/bin/run_test.sh kk random_float
((ECODE+=$?))
bash test/bin/run_test.sh kk random_int
((ECODE+=$?))
bash test/bin/run_test.sh kk dice
((ECODE+=$?))
bash test/bin/run_test.sh kk deal
((ECODE+=$?))
bash test/bin/run_test.sh kk bridge
((ECODE+=$?))
bash test/bin/run_test.sh kk needle
((ECODE+=$?))
bash test/bin/run_test.sh kk dodger
((ECODE+=$?))
bash test/bin/run_test.sh kk knight
((ECODE+=$?))

# chapter 10
bash test/bin/run_test.sh kk batnum
((ECODE+=$?))
bash test/bin/run_test.sh kk nim
((ECODE+=$?))
bash test/bin/run_test.sh kk tictac
((ECODE+=$?))
bash test/bin/run_test.sh kk tic-2
((ECODE+=$?))

# chapter 11
bash test/bin/run_test.sh kk comp-1
((ECODE+=$?))
bash test/bin/run_test.sh kk comp-2
((ECODE+=$?))
bash test/bin/run_test.sh kk tax-1
((ECODE+=$?))
bash test/bin/run_test.sh kk tax-2
((ECODE+=$?))
bash test/bin/run_test.sh kk tax-3
((ECODE+=$?))
bash test/bin/run_test.sh kk decide
((ECODE+=$?))

# chapter 12
bash test/bin/run_test.sh kk stat
((ECODE+=$?))
bash test/bin/run_test.sh kk linreg
((ECODE+=$?))
bash test/bin/run_test.sh kk contin
((ECODE+=$?))
bash test/bin/run_test.sh kk 2-by-2
((ECODE+=$?))
bash test/bin/run_test.sh kk rnksum
((ECODE+=$?))

# chapter 13
bash test/bin/run_test.sh kk mati-0
((ECODE+=$?))
bash test/bin/run_test.sh kk mati-1
((ECODE+=$?))
bash test/bin/run_test.sh kk matops
((ECODE+=$?))
bash test/bin/run_test.sh kk matmpy
((ECODE+=$?))
bash test/bin/run_test.sh kk matpwr
((ECODE+=$?))
bash test/bin/run_test.sh kk matinv
((ECODE+=$?))
bash test/bin/run_test.sh kk linequ
((ECODE+=$?))
bash test/bin/run_test.sh kk net
((ECODE+=$?))
bash test/bin/run_test.sh kk tchain
((ECODE+=$?))
bash test/bin/run_test.sh kk echain
((ECODE+=$?))

# chapter 14
bash test/bin/run_test.sh kk poly
((ECODE+=$?))
bash test/bin/run_test.sh kk integr
((ECODE+=$?))
bash test/bin/run_test.sh kk taylor
((ECODE+=$?))
bash test/bin/run_test.sh kk diffeq
((ECODE+=$?))

# chapter 15
bash test/bin/run_test.sh kk teachm
((ECODE+=$?))
bash test/bin/run_test.sh kk code
((ECODE+=$?))
bash test/bin/run_test.sh kk foxrab
((ECODE+=$?))
bash test/bin/run_test.sh kk fxrb-1
((ECODE+=$?))
bash test/bin/run_test.sh kk music
((ECODE+=$?))

echo
echo Failures: $ECODE

