$ErrorActionPreference='Stop'
$asm=[System.Reflection.Assembly]::Load([System.IO.File]::ReadAllBytes('E:/FFB/FEBuilderGBA.exe'))
$romType=$asm.GetType('FEBuilderGBA.ROM');$rom=[System.Activator]::CreateInstance($romType)
$ok=$romType.GetMethod('LoadForceVersion').Invoke($rom,@('E:/FFB/ROM/fire-emblem-sacred-stones-cn.gba','FE8J'))
if(-not $ok){throw 'ROM load failed'}
$asm.GetType('FEBuilderGBA.Program').GetProperty('ROM').SetValue($null,$rom,$null)
$draw=$asm.GetType('FEBuilderGBA.ImageItemIconForm').GetMethod('DrawIconWhereID')
$raw=Join-Path (Get-Location) 'tools/raw_assets/fe8_items'
$out=Join-Path $raw 'rom_icons';[void][IO.Directory]::CreateDirectory($out)
$c=[IO.File]::ReadAllText((Join-Path $raw 'data_items.c'))
$matches=[regex]::Matches($c,'\[(ITEM_\w+)\]\s*=\s*\{(.*?)\n\s*\}',[Text.RegularExpressions.RegexOptions]::Singleline)
$count=0
foreach($m in $matches){
 $im=[regex]::Match($m.Groups[2].Value,'\.iconId\s*=\s*0x([0-9a-fA-F]+)')
 if(-not $im.Success){continue}
 [uint32]$id=[Convert]::ToUInt32($im.Groups[1].Value,16)
 $bmp=$draw.Invoke($null,@($id))
 $bmp.Save((Join-Path $out ($m.Groups[1].Value+'.png')),[Drawing.Imaging.ImageFormat]::Png)
 $bmp.Dispose();$count++
}
Write-Output "Exported $count exact ROM icons"
[Environment]::Exit(0)
