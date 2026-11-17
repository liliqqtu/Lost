$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$t = $asm.GetType("FEBuilderGBA.ImageSystemIconForm")
$m = $t.GetMethod("DrawUnits", [System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance')

$body = $m.GetMethodBody()
$il = $body.GetILAsByteArray()
Write-Output "IL length: $($il.Length)"

# Let's inspect all fields in Program.ROM or similar
$types = $asm.GetTypes()
$romType = $types | Where-Object { $_.Name -eq "Program" -or $_.Name -eq "ROM" }
foreach ($rt in $romType) {
    Write-Output "ROM Type: $($rt.FullName)"
    $rt.GetProperties() | ForEach-Object { Write-Output "  Prop: $($_.Name)" }
}
