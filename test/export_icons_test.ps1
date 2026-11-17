$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$program = $asm.GetType("FEBuilderGBA.Program")

$initMethod = $program.GetMethod("InitSystem", [System.Reflection.BindingFlags]'Public,NonPublic,Static')
if ($initMethod -ne $null) {
    $initMethod.Invoke($null, $null)
    Write-Output "InitSystem done."
}

$loadRomMethod = $program.GetMethod("LoadROM", [System.Reflection.BindingFlags]'Public,Static', $null, @([string], [string]), $null)
$result = $loadRomMethod.Invoke($null, @("E:\FFB\ROM\fire-emblem-sacred-stones-cn.gba", ""))
Write-Output "LoadROM result: $result"

$rom = $program.GetProperty("ROM").GetValue($null, $null)
Write-Output "ROM Version: $($rom.RomInfo.VersionString)"

$formType = $asm.GetType("FEBuilderGBA.ImageSystemIconForm")

# BaseImage
$baseImgMethod = $formType.GetMethod("BaseImage", [System.Reflection.BindingFlags]'Public,NonPublic,Static')
$bmp = $baseImgMethod.Invoke($null, $null)
if ($bmp -ne $null) {
    $outPath = "E:\Dream\Lost\test\system_icon_base.png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "Saved BaseImage to $outPath (Size: $($bmp.Width)x$($bmp.Height))"
}

# BaseAllowImage
$baseAllowMethod = $formType.GetMethod("BaseAllowImage", [System.Reflection.BindingFlags]'Public,NonPublic,Static')
if ($baseAllowMethod -ne $null) {
    $bmpAllow = $baseAllowMethod.Invoke($null, $null)
    if ($bmpAllow -ne $null) {
        $outPath = "E:\Dream\Lost\test\system_allow_base.png"
        $bmpAllow.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "Saved BaseAllowImage to $outPath (Size: $($bmpAllow.Width)x$($bmpAllow.Height))"
    }
}

# DrawUnits for different palettes
$formInstance = [System.Activator]::CreateInstance($formType)
$drawUnitsMethod = $formType.GetMethod("DrawUnits", [System.Reflection.BindingFlags]'Public,NonPublic,Instance')
if ($drawUnitsMethod -ne $null) {
    # Palette 0: Blue/Player, 1: Red/Enemy, 2: Green/NPC, 3: Purple/Four, 4: Gray
    for ($p = 0; $p -le 4; $p++) {
        $bmpUnits = $drawUnitsMethod.Invoke($formInstance, @($p))
        if ($bmpUnits -ne $null) {
            $outPath = "E:\Dream\Lost\test\unit_icon_pal$p.png"
            $bmpUnits.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Output "Saved DrawUnits pal $p to $outPath (Size: $($bmpUnits.Width)x$($bmpUnits.Height))"
        }
    }
}
