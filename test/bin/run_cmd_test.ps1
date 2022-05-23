param(
[string]$TESTROOT,
[string]$TESTBED,
[string]$TESTGROUP,
[string]$TESTNAME,
[string[]]$OPTIONS
)

function Compare-Files {
    param(
        [string]$filea,
        [string]$fileb
    )

    $HA = Get-FileHash $filea
    $HAH = $HA.Hash
    $HB = Get-FileHash $fileb
    $HBH = $HB.Hash

    return $HBH -eq $HAH
}

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
$FILEA = "$TESTBED\$TESTNAME\stdout.txt"
$FILEB = "$TESTROOT\$TESTGROUP\$TESTNAME\ref\stdout.txt"
If (Compare-Files -filea $FILEA -fileb $FILEB) {
} else {
    Write-Output "Difference"
    Copy-Item -Path $FILEA -Destination $FILEB
    $ECOUNT++
}
Write-Output "compare done"

If (Test-Path "test\$TESTGROUP\$TESTNAME\ref\out_files.txt") {
    ForEach ($F in Get-Content test/$TESTGROUP/$TESTNAME/ref/out_files.txt) {
 	    Write-Output "Compare $F..."
        $FILEA = "$TESTBED\$TESTNAME\$F"
        $FILEB = "$TESTROOT\$TESTGROUP\$TESTNAME\ref\$F"
        If (Compare-Files -filea $FILEA -fileb $FILEB) {
        } else {
            Write-Output "Difference"
            Copy-Item -Path $FILEA -Destination $FILEB
            $ECOUNT++
	    }
    }
}

Write-Output "End test $TESTNAME $ECOUNT"
Exit $ECOUNT