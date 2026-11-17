$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$formType = $asm.GetType("FEBuilderGBA.ImageSystemIconForm")

foreach ($name in @("BaseImage", "BaseAllowImage", "DrawUnits", "DrawUnits2", "GetSystemIconImageSize")) {
    $methods = $formType.GetMethods([System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance') | Where-Object { $_.Name -eq $name }
    foreach ($m in $methods) {
        $p = $m.GetParameters() | ForEach-Object { "$($_.ParameterType.Name) $($_.Name)" }
        $pStr = [string]::Join(", ", $p)
        Write-Output "$($m.IsStatic) $($m.ReturnType.Name) $($m.Name)($pStr)"
    }
}
