$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$program = $asm.GetType("FEBuilderGBA.Program")

$m = $program.GetMethod("LoadROM", [System.Reflection.BindingFlags]'Public,Static', $null, @([string], [string]), $null)
$body = $m.GetMethodBody()
$il = $body.GetILAsByteArray()
$module = $m.Module

for ($i = 0; $i -lt [Math]::Min($il.Length, 120); $i++) {
    $op = $il[$i]
    if ($op -eq 0x28 -or $op -eq 0x6F) {
        $token = [System.BitConverter]::ToInt32($il, $i + 1)
        try {
            $called = $module.ResolveMethod($token)
            Write-Output "  offset $i : CALL $($called.DeclaringType.Name).$($called.Name)"
        } catch {}
        $i += 4
    }
}
