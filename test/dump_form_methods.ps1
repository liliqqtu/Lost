$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$t = $asm.GetType("FEBuilderGBA.ImageSystemIconForm")

Write-Output "=== ImageSystemIconForm METHODS ==="
$t.GetMethods([System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance') | ForEach-Object {
    Write-Output "$($_.ReturnType.Name) $($_.Name)"
}
