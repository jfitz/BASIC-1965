Set-Variable -Name TESTROOT -Value "test"
Set-Variable -Name TESTBED -Value "tests"
Set-Variable -Name TESTGROUP -Value "cmd"

Write-Output "Removing old directory"
if (Test-Path -Path "$TESTBED") {
    Remove-Item -Path "$TESTBED" -Recurse
}

Write-Output "Creating directory $TESTBED"
New-Item -Path "$TESTBED" -Type Directory | Out-Null

Write-Output "Running all tests..."
Set-Variable -Name ECODE -Value 0

Get-ChildItem -Path "$TESTROOT/$TESTGROUP" |
ForEach-Object {
    Set-Variable -Name FILENAME -Value $_.BaseName
    & $TESTROOT/bin/run_cmd_test.ps1 $TESTROOT $TESTBED $TESTGROUP $FILENAME
    If ($LASTEXITCODE -gt 0) {
        $ECODE++
    }
}

Write-Output ""
Write-Output "Failures: $ECODE"
