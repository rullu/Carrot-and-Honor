param(
    [string[]]$TestNames = @(),
    [string]$Godot = 'godot'
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$godotExecutable = (Get-Command $Godot -ErrorAction Stop).Source
$logRoot = Join-Path $projectRoot '.godot/test_logs'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
if ($TestNames.Count -eq 0) {
    $TestNames = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests') -Filter '*_test.gd' | ForEach-Object { $_.BaseName })
}
$failed = @()
foreach ($testName in $TestNames) {
    if ($testName -notmatch '^[a-z0-9_]+_test$') { throw "Invalid test name: $testName" }
    $logPath = Join-Path $logRoot "$testName.log"
    [System.IO.File]::WriteAllText($logPath, '')
    $arguments = @('--headless', '--path', "`"$projectRoot`"", '--log-file', "`"$logPath`"", '--script', "res://tests/$testName.gd")
    $process = Start-Process -FilePath $godotExecutable -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $finished = $process.WaitForExit(120000)
    if (-not $finished) { $process.Kill(); $failed += $testName; Write-Output "TIMEOUT $testName"; continue }
    $process.Refresh()
    $output = if (Test-Path -LiteralPath $logPath) { Get-Content -Raw -LiteralPath $logPath } else { '' }
    if ($process.ExitCode -ne 0 -or $output -notmatch 'PASS' -or $output -match 'SCRIPT ERROR|Parse Error|CrashHandlerException') {
        $failed += $testName
        Write-Output "FAIL $testName (exit $($process.ExitCode))"
        Write-Output $output
    } else { Write-Output "PASS $testName" }
}
Write-Output "$($TestNames.Count - $failed.Count)/$($TestNames.Count) tests passed. Logs: $logRoot"
if ($failed.Count -gt 0) { exit 1 }
exit 0
