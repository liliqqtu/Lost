param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string[]]$Cases = @()
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path $PSScriptRoot '.runtime_saves'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$stdoutPath = Join-Path $logDirectory 'suite.stdout.log'
$stderrPath = Join-Path $logDirectory 'suite.stderr.log'
$arguments = @('--headless', '--path', ('"{0}"' -f $projectRoot), 'res://tests/test_suite.tscn', '--') + $Cases
$process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
while (-not $process.HasExited) {
    $process.WaitForExit(1000) | Out-Null
}
$process.WaitForExit()
$output = Get-Content -LiteralPath $stdoutPath -Raw -Encoding utf8
$errors = Get-Content -LiteralPath $stderrPath -Raw -Encoding utf8
Write-Output $output
# GDScript 错误可能仍以 0 退出；同时检查错误日志和完整结束标记。
$unexpectedErrors = $errors -split "`r?`n" | Where-Object {
    $_ -match 'SCRIPT ERROR:|ERROR:' -and $_ -notmatch '\.NET: Assemblies not found|resources still in use at exit|RID allocations'
}
if ($process.ExitCode -ne 0 -or $unexpectedErrors -or $output -notmatch 'SUITE ALL PASSED') {
    Write-Output $errors
    exit 1
}
Write-Output 'Verified: suite completed with no script errors.'
exit 0
