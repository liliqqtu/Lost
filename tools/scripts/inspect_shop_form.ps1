$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)

$shopForm = $asm.GetType("FEBuilderGBA.ItemShopForm")
Write-Output "=== ItemShopForm Fields ==="
$shopForm.GetFields([System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance') | ForEach-Object {
    Write-Output "  FIELD: $($_.FieldType.Name) $($_.Name)"
}

Write-Output "=== ItemShopForm Methods ==="
$shopForm.GetMethods([System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance,DeclaredOnly') | ForEach-Object {
    Write-Output "  METHOD: $($_.ReturnType.Name) $($_.Name)"
}
