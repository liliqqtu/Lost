$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$program = $asm.GetType("FEBuilderGBA.Program")

# Set IsCommandLine to true if needed, or just LoadROM
$loadRomMethod = $program.GetMethod("LoadROM", [System.Reflection.BindingFlags]'Public,Static')
$result = $loadRomMethod.Invoke($null, @("E:\FFB\ROM\fire-emblem-sacred-stones-cn.gba", ""))
Write-Output "LoadROM result: $result"

$rom = $program.GetProperty("ROM").GetValue($null, $null)
Write-Output "ROM Version: $($rom.RomInfo.Version)"

# Now instantiate ImageSystemIconForm or call its methods
$formType = $asm.GetType("FEBuilderGBA.ImageSystemIconForm")
$formInstance = [System.Activator]::CreateInstance($formType)

# BaseImage
$baseImgMethod = $formType.GetMethod("BaseImage", [System.Reflection.BindingFlags]'Public,NonPublic,Instance')
$bmp = $baseImgMethod.Invoke($formInstance, $null)
if ($bmp -ne $null) {
    $outPath = "E:\Dream\Lost\test\system_icon_base.png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "Saved BaseImage to $outPath (Size: $($bmp.Width)x$($bmp.Height))"
}

# BaseAllowImage
$baseAllowMethod = $formType.GetMethod("BaseAllowImage", [System.Reflection.BindingFlags]'Public,NonPublic,Instance')
if ($baseAllowMethod -ne $null) {
    $bmpAllow = $baseAllowMethod.Invoke($formInstance, $null)
    if ($bmpAllow -ne $null) {
        $outPath = "E:\Dream\Lost\test\system_allow_base.png"
        $bmpAllow.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "Saved BaseAllowImage to $outPath"
    }
}

# DrawUnits
$drawUnitsMethod = $formType.GetMethod("DrawUnits", [System.Reflection.BindingFlags]'Public,NonPublic,Instance')
if ($drawUnitsMethod -ne $null) {
    $bmpUnits = $drawUnitsMethod.Invoke($formInstance, $null)
    if ($bmpUnits -ne $null) {
        $outPath = "E:\Dream\Lost\test\unit_icon.png"
        $bmpUnits.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "Saved DrawUnits to $outPath"
    }
}

# DrawUnits2
$drawUnits2Method = $formType.GetMethod("DrawUnits2", [System.Reflection.BindingFlags]'Public,NonPublic,Instance')
if ($drawUnits2Method -ne $null) {
    $bmpUnits2 = $drawUnits2Method.Invoke($formInstance, $null)
    if ($bmpUnits2 -ne $null) {
        $outPath = "E:\Dream\Lost\test\unit_icon2.png"
        $bmpUnits2.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "Saved DrawUnits2 to $outPath"
    }
}
