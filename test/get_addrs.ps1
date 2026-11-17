$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$program = $asm.GetType("FEBuilderGBA.Program")
$loadRomMethod = $program.GetMethod("LoadROM", [System.Reflection.BindingFlags]'Public,Static', $null, @([string], [string]), $null)
$loadRomMethod.Invoke($null, @("E:\FFB\ROM\fire-emblem-sacred-stones-cn.gba", "")) | Out-Null
$rom = $program.GetProperty("ROM").GetValue($null, $null)
$info = $rom.RomInfo
Write-Output ("system_icon_pointer: 0x" + $info.system_icon_pointer.ToString("X"))
Write-Output ("system_icon_palette_pointer: 0x" + $info.system_icon_palette_pointer.ToString("X"))
Write-Output ("system_icon addr in ROM: 0x" + $rom.p32($info.system_icon_pointer).ToString("X"))
Write-Output ("system_icon pal in ROM: 0x" + $rom.p32($info.system_icon_palette_pointer).ToString("X"))
Write-Output ("unit_icon_palette_address: 0x" + $info.unit_icon_palette_address.ToString("X"))
Write-Output ("unit_icon_enemypalette_address: 0x" + $info.unit_icon_enemypalette_address.ToString("X"))
Write-Output ("unit_icon_npcpalette_address: 0x" + $info.unit_icon_npcpalette_address.ToString("X"))
