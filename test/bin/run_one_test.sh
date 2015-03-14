echo
echo Start test $1

# create testbed
echo Creating testbed...
mkdir tests/$1
cp bin/* test/data/$1/* tests/$1
echo testbed ready

# execute program
echo Running program...
cd tests/$1
ruby -I. basic.rb -notiming $1.bas >stdout.txt 2>stderr.txt
cd ../..
echo run finished

# compare results
echo Comparing stdout...
diff tests/$1/stdout.txt test/ref/$1/stdout.txt
echo compare done
echo Comparing stderr...
diff tests/$1/stderr.txt test/ref/$1/stderr.txt
echo compare done

echo End test $1
