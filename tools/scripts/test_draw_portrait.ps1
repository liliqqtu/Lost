$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$program = $asm.GetType("FEBuilderGBA.Program")

$initMethod = $program.GetMethod("InitSystem", [System.Reflection.BindingFlags]'Public,NonPublic,Static')
if ($initMethod -ne $null) {
    try { $initMethod.Invoke($null, $null) } catch {}
}

$romType = $asm.GetType("FEBuilderGBA.ROM")
$rom = [System.Activator]::CreateInstance($romType)
$rom.LoadForceVersion("E:\FFB\ROM\fire-emblem-sacred-stones-cn.gba", "FE8")
$program.GetProperty("ROM").SetValue($null, $rom, $null)

Write-Output "ROM: $($rom.RomInfo.VersionString)"

$ptType = $asm.GetType("FEBuilderGBA.ImagePortraitForm")
$drawMethod = $ptType.GetMethod("DrawPortraitAuto", [System.Reflection.BindingFlags]'Public,Static', $null, @([uint32]), $null)

foreach ($id in @(0x65, 0x66, 0x68)) {
    try {
        $bmp = $drawMethod.Invoke($null, @([uint32]$id))
        if ($bmp -ne $null) {
            $path = "E:\Dream\Lost\tools\raw_assets\portrait_0x{0:X2}.png" -f $id
            $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Output "Saved portrait 0x{0:X2} to $path (Size: {1}x{2})" -f $id, $bmp.Width, $bmp.Height
        } else {
            Write-Output "Portrait 0x{0:X2} returned null" -f $id
        }
    } catch {
        Write-Output "Error portrait 0x{0:X2}: $_" -f $id
    }
}
