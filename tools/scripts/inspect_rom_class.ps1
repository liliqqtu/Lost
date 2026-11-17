$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)

$romType = $asm.GetType("FEBuilderGBA.ROM")
Write-Output "=== ROM Constructors ==="
$romType.GetConstructors([System.Reflection.BindingFlags]'Public,NonPublic,Instance') | ForEach-Object {
    $p = $_.GetParameters() | ForEach-Object { "$($_.ParameterType.Name) $($_.Name)" }
    Write-Output "  ROM($([string]::Join(', ', $p)))"
}

Write-Output "=== ROM Methods ==="
$romType.GetMethods([System.Reflection.BindingFlags]'Public,NonPublic,Instance') | Where-Object { $_.Name -like "*Load*" -or $_.Name -like "*Open*" } | ForEach-Object {
    $p = $_.GetParameters() | ForEach-Object { "$($_.ParameterType.Name) $($_.Name)" }
    Write-Output "  $($_.Name)($([string]::Join(', ', $p)))"
}
