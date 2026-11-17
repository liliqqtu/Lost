$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)

$types = $asm.GetTypes()
$forms = $types | Where-Object { $_.Name -like "*SystemIcon*" -or $_.Name -like "*UnitIcon*" }
foreach ($f in $forms) {
    Write-Output "TYPE: $($f.FullName)"
    $f.GetFields([System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance') | ForEach-Object {
        Write-Output "  FIELD: $($_.FieldType.Name) $($_.Name)"
    }
    $f.GetMethods([System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance,DeclaredOnly') | ForEach-Object {
        Write-Output "  METHOD: $($_.ReturnType.Name) $($_.Name)($([string]::Join(', ', ($_.GetParameters() | ForEach-Object { $_.ParameterType.Name + ' ' + $_.Name }))))"
    }
}
