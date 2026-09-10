$ErrorActionPreference = 'Stop'

$Target = Join-Path $PSScriptRoot 'llama.cpp\ggml\src\ggml-vulkan\ggml-vulkan.cpp'
$Marker = '// HAWAII_V1_SHARED_MEMORY_FA'
$Func = 'static vk_fa_tuning_params get_fa_tuning_params_scalar('

$Patch = @'

    // HAWAII_V1_SHARED_MEMORY_FA
    // AMD Hawaii / GCN2 compatibility path for the proprietary Vulkan driver.
    // Keep the modern scalar Flash Attention shader, but disable subgroup reductions
    // so get_fa_pipeline_state() passes SubGroupSize == 0 to flash_attn.comp.
    // IMPORTANT: keep result.subgroup_size at the real hardware subgroup size here;
    // it has already been used to compute workgroup_size and d_split safely.
    if (device->vendor_id == VK_VENDOR_ID_AMD &&
        device->architecture == AMD_GCN) {
        result.row_split = 1;
        result.disable_subgroups = true;
        result.limit_occupancy_shmem = 0;
    }
'@

if (-not (Test-Path $Target)) {
    Write-Host "ERROR: target file not found:" -ForegroundColor Red
    Write-Host $Target
    exit 2
}

$text = [System.IO.File]::ReadAllText($Target, [System.Text.Encoding]::UTF8)

if ($text.Contains($Marker)) {
    Write-Host 'Hawaii V1 patch already applied.' -ForegroundColor Yellow
    exit 0
}

$start = $text.IndexOf($Func, [System.StringComparison]::Ordinal)
if ($start -lt 0) {
    Write-Host 'ERROR: get_fa_tuning_params_scalar() was not found.' -ForegroundColor Red
    exit 3
}

$brace = $text.IndexOf('{', $start)
if ($brace -lt 0) {
    Write-Host 'ERROR: function opening brace not found.' -ForegroundColor Red
    exit 4
}

$depth = 0
$end = -1
for ($i = $brace; $i -lt $text.Length; $i++) {
    $c = $text[$i]
    if ($c -eq '{') { $depth++ }
    elseif ($c -eq '}') {
        $depth--
        if ($depth -eq 0) {
            $end = $i
            break
        }
    }
}

if ($end -lt 0) {
    Write-Host 'ERROR: matching function brace not found.' -ForegroundColor Red
    exit 5
}

$body = $text.Substring($brace, $end - $brace)
$retRel = $body.LastIndexOf('return result;', [System.StringComparison]::Ordinal)
if ($retRel -lt 0) {
    Write-Host "ERROR: final 'return result;' not found in scalar FA tuning function." -ForegroundColor Red
    exit 6
}

$insertAt = $brace + $retRel
$backup = "$Target.hawaii-v1.orig"
[System.IO.File]::WriteAllText($backup, $text, (New-Object System.Text.UTF8Encoding($false)))

$patched = $text.Substring(0, $insertAt) + $Patch + $text.Substring($insertAt)
[System.IO.File]::WriteAllText($Target, $patched, (New-Object System.Text.UTF8Encoding($false)))

Write-Host 'Applied Hawaii V1 patch successfully.' -ForegroundColor Green
Write-Host "Patched: $Target"
Write-Host "Backup : $backup"
exit 0
