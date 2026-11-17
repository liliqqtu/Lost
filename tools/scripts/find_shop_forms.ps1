$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)

$types = $asm.GetTypes()
$shopTypes = $types | Where-Object { $_.Name -like "*Shop*" -or $_.Name -like "*Portrait*" -or $_.Name -like "*ImageBG*" }
foreach ($t in $shopTypes) {
    Write-Output "TYPE: $($t.FullName)"
}
