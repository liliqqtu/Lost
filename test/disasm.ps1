$bytes = [System.IO.File]::ReadAllBytes("E:\FFB\FEBuilderGBA.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$t = $asm.GetType("FEBuilderGBA.ImageSystemIconForm")

function DisasmMethod($method) {
    Write-Output "--- Method: $($method.Name) ---"
    $body = $method.GetMethodBody()
    if ($null -eq $body) { return }
    $il = $body.GetILAsByteArray()
    $module = $method.Module

    # simple scan for tokens
    for ($i = 0; $i -lt $il.Length; $i++) {
        $op = $il[$i]
        # check for call/callvirt (0x28, 0x6F) or ldfld/stfld (0x7B, 0x7D, 0x7E, 0x80) or ldstr (0x72)
        if ($op -eq 0x28 -or $op -eq 0x6F) {
            $token = [System.BitConverter]::ToInt32($il, $i + 1)
            try {
                $m = $module.ResolveMethod($token)
                Write-Output "  offset $i : CALL $($m.DeclaringType.Name).$($m.Name)"
            } catch {}
            $i += 4
        } elseif ($op -eq 0x7B -or $op -eq 0x7D -or $op -eq 0x7E -or $op -eq 0x80) {
            $token = [System.BitConverter]::ToInt32($il, $i + 1)
            try {
                $f = $module.ResolveField($token)
                Write-Output "  offset $i : FIELD $($f.DeclaringType.Name).$($f.Name)"
            } catch {}
            $i += 4
        } elseif ($op -eq 0x72) {
            $token = [System.BitConverter]::ToInt32($il, $i + 1)
            try {
                $s = $module.ResolveString($token)
                Write-Output "  offset $i : STRING '$s'"
            } catch {}
            $i += 4
        }
    }
}

DisasmMethod ($t.GetMethod("DrawUnits", [System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance'))
DisasmMethod ($t.GetMethod("DrawUnits2", [System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance'))
DisasmMethod ($t.GetMethod("BaseImage", [System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance'))
DisasmMethod ($t.GetMethod("unit_icon_Export_Click", [System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance'))
DisasmMethod ($t.GetMethod("system_icon_Export_Click", [System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance'))
