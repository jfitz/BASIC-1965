param(
    [string]$TESTGROUP
)

Set-Variable -Name TESTROOT -Value "test"
Set-Variable -Name TESTBED -Value "tests"

if (Test-Path -Path "$TESTROOT") {
} else {
    New-Item -Path "$TESTROOT" -Type Directory | Out-Null
}

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
    if (Test-Path -Path $_ -PathType Container) {
        Set-Variable -Name FILENAME -Value $_.BaseName
        & $TESTROOT/bin/run_test.ps1 $TESTROOT $TESTBED $TESTGROUP $FILENAME
        $ECODE+=$LASTEXITCODE
    }
}

Write-Output ""
Write-Output "Failures: $ECODE"
