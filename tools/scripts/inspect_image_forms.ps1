$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)

$ptType = $asm.GetType("FEBuilderGBA.ImagePortraitForm")
Write-Output "=== ImagePortraitForm Methods ==="
$ptType.GetMethods([System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance,DeclaredOnly') | ForEach-Object {
    Write-Output "  $($_.ReturnType.Name) $($_.Name)"
}

$bgType = $asm.GetType("FEBuilderGBA.ImageBGForm")
Write-Output "=== ImageBGForm Methods ==="
$bgType.GetMethods([System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance,DeclaredOnly') | ForEach-Object {
    Write-Output "  $($_.ReturnType.Name) $($_.Name)"
}
