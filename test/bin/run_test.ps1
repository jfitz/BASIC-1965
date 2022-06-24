param(
[string]$TESTROOT,
[string]$TESTBED,
[string]$TESTGROUP,
[string]$TESTNAME,
[string[]]$OPTIONS
)

function Split-Arguments {
    param(
        [string[]]$list
    )

    $new_list = @()

    ForEach($line in $list) {
        if ($line.Length -gt 0) {
            if ($line[0] -eq '-') {
                $parts = $line.split(' ')
                ForEach($part in $parts) {
                    $new_list += $part
                }
            } else {
                $new_list += $line
            }
        }
    }

    return $new_list
}

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

If (Test-Path -Path "$TESTBED\$TESTNAME") {
} else {
    # create testbed
    Write-Output "Creating testbed..."
    New-Item -Path "$TESTBED\$TESTNAME" -ItemType Directory | Out-Null
}
Copy-Item -Path bin\* -Destination "$TESTBED\$TESTNAME"
Copy-Item -Path "$TESTROOT\$TESTGROUP\$TESTNAME\data\*" -Destination "$TESTBED\$TESTNAME"
Write-Output "testbed ready"

If (Test-Path "$TESTROOT\$TESTGROUP\options.txt") {
    $GROUP_OPTIONS = Split-Arguments(Get-Content "$TESTROOT\$TESTGROUP\options.txt")
}

If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\data\options.txt") {
    $TEST_OPTIONS = Split-Arguments(Get-Content "$TESTROOT\$TESTGROUP\$TESTNAME\data\options.txt")
}

# execute program
Set-Variable -Name ECOUNT -Value 0

If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\ref\list.txt") {
    Write-Output "List program with options $GROUP_OPTIONS $TEST_OPTIONS"
    Set-Location "$TESTBED\$TESTNAME"
    ruby basic.rb --list "$TESTNAME.bas" --no-heading --print-width 0 >list.txt $GROUP_OPTIONS $TEST_OPTIONS
    Set-Location ..\..

    Write-Output "Compare list..."
    $FILEA = "$TESTBED\$TESTNAME\list.txt"
    $FILEB = "$TESTROOT\$TESTGROUP\$TESTNAME\ref\list.txt"
    If (Compare-Files -filea $FILEA -fileb $FILEB) {
    } else {
        Write-Output "Difference"
    	$ECOUNT++
        Copy-Item -Path $FILEA -Destination $FILEB
    }
}

If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\ref\parse.txt") {
    If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\data\parse_options.txt") {
    	$PARSE_OPTIONS = Split-Arguments(Get-Content "$TESTROOT\$TESTGROUP\$TESTNAME\data\parse_options.txt")
    }

    Write-Output "Parse program with options $GROUP_OPTIONS $TEST_OPTIONS $PARSE_OPTIONS"
    Set-Location "$TESTBED\$TESTNAME"
    ruby basic.rb --parse "$TESTNAME.bas" --no-heading --print-width 0 >parse.txt $GROUP_OPTIONS $TEST_OPTIONS $PARSE_OPTIONS
    Set-Location ..\..

    Write-Output "Compare parse..."
    $FILEA = "$TESTBED\$TESTNAME\parse.txt"
    $FILEB = "$TESTROOT\$TESTGROUP\$TESTNAME\ref\parse.txt"
    If (Compare-Files -filea $FILEA -fileb $FILEB) {
    } else {
        Write-Output "Difference"
    	$ECOUNT++
        Copy-Item -Path $FILEA -Destination $FILEB
    }
}

If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\ref\analyze.txt") {
    If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\data\analyze_options.txt") {
	    $ANALYZE_OPTIONS = Split-Arguments(Get-Content "$TESTROOT\$TESTGROUP\$TESTNAME\data\analyze_options.txt")
    }

    Write-Output "Analyze program with options $GROUP_OPTIONS $TEST_OPTIONS $ANALYZE_OPTIONS"
    Set-Location "$TESTBED\$TESTNAME"
    ruby basic.rb --analyze "$TESTNAME.bas" --no-heading --print-width 0 >analyze.txt 2>analyze.err $GROUP_OPTIONS $TEST_OPTIONS $ANALYZE_OPTIONS
    Set-Location ..\..

    Write-Output "Compare analyze stdout..."
    $FILEA = "$TESTBED\$TESTNAME\analyze.txt"
    $FILEB = "$TESTROOT\$TESTGROUP\$TESTNAME\ref\analyze.txt"
    If (Compare-Files -filea $FILEA -fileb $FILEB) {
    } else {
        Write-Output "Difference"
    	$ECOUNT++
        Copy-Item -Path $FILEA -Destination $FILEB
    }

    If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\ref\analyze.err") {
        Write-Output "Compare analyze stderr..."
        $FILEA = "$TESTBED\$TESTNAME\analyze.err"
        $FILEB = "$TESTROOT\$TESTGROUP\$TESTNAME\ref\analyze.err"
        If (Compare-Files -filea $FILEA -fileb $FILEB) {
        } else {
            Write-Output "Difference"
            $ECOUNT++
            Copy-Item -Path $FILEA -Destination $FILEB
        }
    }
}

If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\ref\pretty.txt") {
    If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\data\pretty_options.txt") {
    	$PRETTY_OPTIONS = Split-Arguments(Get-Content "$TESTROOT\$TESTGROUP\$TESTNAME\data\pretty_options.txt")
    }

    Write-Output "Pretty program with options $GROUP_OPTIONS $TEST_OPTIONS $PRETTY_OPTIONS"
    Set-Location "$TESTBED\$TESTNAME"
    ruby basic.rb --pretty "$TESTNAME.bas" --no-heading --print-width 0 >pretty.txt $GROUP_OPTIONS $TEST_OPTIONS $PRETTY_OPTIONS
    Set-Location ..\..

    Write-Output "Compare pretty..."
    $FILEA = "$TESTBED\$TESTNAME\pretty.txt"
    $FILEB = "$TESTROOT\$TESTGROUP\$TESTNAME\ref\pretty.txt"
    If (Compare-Files -filea $FILEA -fileb $FILEB) {
    } else {
        Write-Output "Difference"
    	$ECOUNT++
        Copy-Item -Path $FILEA -Destination $FILEB
    }
}

If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\ref\crossref.txt") {
    Write-Output "Crossref program with options $GROUP_OPTIONS $TEST_OPTIONS"
    Set-Location "$TESTBED\$TESTNAME"
    ruby basic.rb --crossref "$TESTNAME.bas" --no-heading --print-width 0 >crossref.txt $GROUP_OPTIONS $TEST_OPTIONS
    Set-Location ..\..

    Write-Output "Compare crossref..."
    $FILEA = "$TESTBED\$TESTNAME\crossref.txt"
    $FILEB = "$TESTROOT\$TESTGROUP\$TESTNAME\ref\crossref.txt"
    If (Compare-Files -filea $FILEA -fileb $FILEB) {
    } else {
        Write-Output "Difference"
    	$ECOUNT++
        Copy-Item -Path $FILEA -Destination $FILEB
    }
}

If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\ref\stdout.txt") {
    If (Test-Path "$TESTROOT\$TESTGROUP\run_options.txt") {
    	$GROUP_RUN_OPTIONS = Split-Arguments(Get-Content "$TESTROOT\$TESTGROUP\run_options.txt")
    }

    If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\data\run_options.txt") {
    	$RUN_OPTIONS = Split-Arguments(Get-Content "$TESTROOT\$TESTGROUP\$TESTNAME\data\run_options.txt")
    }

    Write-Output "Run program with options $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS"

    If (Test-Path "$TESTBED\$TESTNAME\stdin.txt") {
    	Set-Location "$TESTBED\$TESTNAME"
	    Get-Content stdin.txt | ruby basic.rb --no-timing --profile $OPTIONS --run "$TESTNAME.bas" --print-width 0 --no-heading >stdout.txt $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS
	    Set-Location ..\..
    } else {
    	Set-Location "$TESTBED\$TESTNAME"
	    ruby basic.rb --no-timing --profile $OPTIONS --run "$TESTNAME.bas" --print-width 0 --no-heading >stdout.txt $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS
	    Set-Location ..\..
    }

    Write-Output "Compare stdout..."
    $FILEA = "$TESTBED\$TESTNAME\stdout.txt"
    $FILEB = "$TESTROOT\$TESTGROUP\$TESTNAME\ref\stdout.txt"
    If (Compare-Files -filea $FILEA -fileb $FILEB) {
    } else {
        Write-Output "Difference"
    	$ECOUNT++
        Copy-Item -Path $FILEA -Destination $FILEB
    }
}

If (Test-Path "test\$TESTGROUP\$TESTNAME\ref\out_files.txt") {
    ForEach ($F in Get-Content test\$TESTGROUP\$TESTNAME\ref\out_files.txt) {
        Write-Output "Compare $F..."
        $FILEA = "$TESTBED\$TESTNAME\$F"
        $FILEB = "$TESTROOT\$TESTGROUP\$TESTNAME\ref\$F"
        If (Compare-Files -filea $FILEA -fileb $FILEB) {
        } else {
            Write-Output "Difference"
            $ECOUNT++
            Copy-Item -Path $FILEA -Destination $FILEB
        }
    }
}

If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\ref\trace.txt") {
    If (Test-Path "$TESTROOT\$TESTGROUP\run_options.txt") {
    	$GROUP_RUN_OPTIONS = Split-Arguments(Get-Content "$TESTROOT\$TESTGROUP\run_options.txt")
    }

    If (Test-Path "$TESTROOT\$TESTGROUP\$TESTNAME\data\run_options.txt") {
    	$RUN_OPTIONS = Split-Arguments(Get-Content "$TESTROOT\$TESTGROUP\$TESTNAME\data\run_options.txt")
    }

    Write-Output "Trace program with options $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS"

    If (Test-Path "$TESTBED\$TESTNAME\stdin.txt") {
    	Set-Location "$TESTBED\$TESTNAME"
	    Get-Content stdin.txt | ruby basic.rb --no-timing $OPTIONS --run "$TESTNAME.bas" --print-width 0 --no-heading --trace >trace.txt $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS
	    Set-Location ..\..
    } else {
    	Set-Location "$TESTBED\$TESTNAME"
	    ruby basic.rb --no-timing $OPTIONS --run "$TESTNAME.bas" --print-width 0 --no-heading --trace >trace.txt $GROUP_OPTIONS $TEST_OPTIONS $GROUP_RUN_OPTIONS $RUN_OPTIONS
	    Set-Location ..\..
    }

    Write-Output "Compare trace..."
    $FILEA = "$TESTBED\$TESTNAME\trace.txt"
    $FILEB = "$TESTROOT\$TESTGROUP\$TESTNAME\ref\trace.txt"
    If (Compare-Files -filea $FILEA -fileb $FILEB) {
    } else {
        Write-Output "Difference"
    	$ECOUNT++
        Copy-Item -Path $FILEA -Destination $FILEB
    }
}

Write-Output "End test $TESTNAME"
exit $ECOUNT
