$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$program = $asm.GetType("FEBuilderGBA.Program")

$program.GetMethods([System.Reflection.BindingFlags]'Public,Static') | Where-Object { $_.Name -like "*Load*" -or $_.Name -like "*Open*" -or $_.Name -like "*Init*" } | ForEach-Object {
    Write-Output "$($_.ReturnType.Name) $($_.Name)($([string]::Join(', ', ($_.GetParameters() | ForEach-Object { $_.ParameterType.Name + ' ' + $_.Name }))))"
}
