$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$t = $asm.GetType("FEBuilderGBA.SystemIconPictureBox")

Write-Output "=== SystemIconPictureBox nested types ==="
$t.GetNestedTypes() | ForEach-Object {
    Write-Output "Nested: $($_.FullName)"
    if ($_.IsEnum) {
        [System.Enum]::GetNames($_) | ForEach-Object {
            Write-Output "  $_"
        }
    }
}

Write-Output "=== SystemIconPictureBox methods ==="
$t.GetMethods([System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance,DeclaredOnly') | ForEach-Object {
    Write-Output "$($_.ReturnType.Name) $($_.Name)"
}
