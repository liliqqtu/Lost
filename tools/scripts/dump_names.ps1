$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$program = $asm.GetType("FEBuilderGBA.Program")
$romType = $asm.GetType("FEBuilderGBA.ROM")

$rom = [System.Activator]::CreateInstance($romType)
$loadMethod = $romType.GetMethod("LoadForceVersion", [System.Reflection.BindingFlags]'Public,Instance')
$loadMethod.Invoke($rom, @("E:\FFB\ROM\fire-emblem-sacred-stones-cn.gba", "FE8"))

$program.GetProperty("ROM").SetValue($null, $rom, $null)
Write-Output "ROM loaded: $($rom.RomInfo.VersionString)"

$ptType = $asm.GetType("FEBuilderGBA.ImagePortraitForm")
$getNameMethod = $ptType.GetMethod("GetPortraitName", [System.Reflection.BindingFlags]'Public,Static', $null, @([uint32]), $null)

Write-Output "=== PORTRAITS ==="
for ($i = 0; $i -lt 256; $i++) {
    $name = $getNameMethod.Invoke($null, @([uint32]$i))
    if (-not [string]::IsNullOrEmpty($name)) {
        Write-Output ("PORTRAIT 0x{0:X2} ({0}): {1}" -f $i, $name)
    }
}

$bgType = $asm.GetType("FEBuilderGBA.ImageBGForm")
$getCommentMethod = $bgType.GetMethod("GetComment", [System.Reflection.BindingFlags]'Public,Static', $null, @([uint32]), $null)

Write-Output "=== BACKGROUNDS ==="
for ($i = 0; $i -lt 150; $i++) {
    $comment = $getCommentMethod.Invoke($null, @([uint32]$i))
    if (-not [string]::IsNullOrEmpty($comment)) {
        Write-Output ("BG 0x{0:X2} ({0}): {1}" -f $i, $comment)
    }
}
