param(
[string]$TESTROOT,
[string]$TESTBED,
[string]$TESTGROUP,
[string]$TESTNAME,
[string[]]$OPTIONS
)

Write-Output ""
Write-Output "Start test $TESTNAME"

If (Test-Path -Path "$TESTBED/$TESTNAME") {
} else {
    # create testbed
    Write-Output "Creating testbed..."
    New-Item -Path "$TESTBED/$TESTNAME" -ItemType Directory | Out-Null
}
Copy-Item -Path bin\* -Destination "$TESTBED\$TESTNAME"
Copy-Item -Path "$TESTROOT\$TESTGROUP\$TESTNAME\data\*" -Destination "$TESTBED\$TESTNAME"
Write-Output "testbed ready"

Set-Variable -Name ECOUNT -Value 0

# execute program
Write-Output "Running program..."
Set-Location "$TESTBED\$TESTNAME"
Get-Content stdin.txt | ruby basic.rb --no-timing --print-width 0 --echo-input | Out-File stdout.txt
Set-Location ..\..
Write-Output "run finished"

# compare results
Write-Output "Comparing stdout..."
$HREF = Get-FileHash "$TESTBED\$TESTNAME\stdout.txt"
$HREFH = $HREF.Hash
$HACT = Get-FileHash "$TESTROOT\$TESTGROUP\$TESTNAME\ref\stdout.txt"
$HACTH = $HACT.Hash
If ($HACTH -ne $HREFH) {
    Write-Output "Difference"
    Copy-Item -Path "$TESTBED\$TESTNAME\stdout.txt" -Destination "$TESTROOT\$TESTGROUP\$TESTNAME\ref\stdout.txt"
    $ECOUNT++
}
Write-Output "compare done"

If (Test-Path "test\$TESTGROUP\$TESTNAME\ref\out_files.txt") {
    ForEach ($F in Get-Content test/$TESTGROUP/$TESTNAME/ref/out_files.txt) {
 	    Write-Output "Compare $F..."
        $HREF = Get-FileHash "$TESTROOT\$TESTGROUP\$TESTNAME\ref\$F"
        $HREFH = $HREF.Hash
        $HACT = Get-FileHash "$TESTBED\$TESTNAME\$F"
        $HACTH = $HACT.Hash
        If ($HACTH -ne $HREFH) {
            Write-Output "Difference"
	        Copy-Item -Path "$TESTBED\$TESTNAME\$F" -Destination "$TESTROOT\$TESTGROUP\$TESTNAME\ref\$F"
            $ECOUNT++
	    }
    }
}

Write-Output "End test $TESTNAME $ECOUNT"
Exit $ECOUNT