param(
    [string]$AssetRoot = "",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-AssetDir([string]$Root, [string[]]$Names) {
    foreach ($name in $Names) {
        $candidate = Join-Path $Root $name
        if (Test-Path -LiteralPath $candidate -PathType Container) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    return $null
}

if ([string]::IsNullOrWhiteSpace($AssetRoot)) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select the original PvZ asset folder (the folder containing reanim and images)'
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host 'Cancelled; no assets were changed.'
        exit 1
    }
    $AssetRoot = $dialog.SelectedPath
}

$AssetRoot = (Resolve-Path -LiteralPath $AssetRoot).Path
$SourceReanim = Resolve-AssetDir $AssetRoot @('reanim', 'datafiles\parts\reanim', 'parts\reanim')
$SourceImages = Resolve-AssetDir $AssetRoot @('images', 'datafiles\parts\images', 'parts\images')
if (-not $SourceReanim -and -not $SourceImages) {
    throw "Could not find reanim/ or images/ under '$AssetRoot'. Select the 'pvz files' directory or a directory containing those subfolders."
}

$DestinationReanim = Join-Path $ProjectRoot 'datafiles\parts\reanim'
$DestinationImages = Join-Path $ProjectRoot 'datafiles\parts\images'
New-Item -ItemType Directory -Force -Path $DestinationReanim, $DestinationImages | Out-Null

# These are authentic original parts referenced by the decompiled Zombie.cpp and the runtime.
# Only named variants are copied; no general asset-folder replacement occurs.
$ReanimFiles = @(
    'Zombie_screendoor2.png', 'Zombie_screendoor3.png',
    'Zombie_paper_paper2.png', 'Zombie_paper_paper3.png', 'Zombie_paper_madhead.png',
    'Zombie_football_helmet2.png', 'Zombie_football_helmet3.png', 'zombie_football_leftarm_upper2.png',
    'Zombie_pogo_outerarm_upper2.png', 'Zombie_pogo_stickdamage1.png', 'Zombie_pogo_stickdamage2.png',
    'Zombie_pogo_stick2damage1.png', 'Zombie_pogo_stick2damage2.png', 'Zombie_pogo_stickhands2.png',
    'Zombie_flag3.png',
    'Zombie_gargantuar_body1_2.png', 'Zombie_gargantuar_body1_3.png',
    'Zombie_gargantuar_outerarm_lower2.png', 'Zombie_gargantuar_foot2.png',
    'Zombie_gargantuar_head2.png', 'Zombie_gargantuar_head2_redeye.png',
    'Zombie_catapult_siding_damage.png', 'Zombie_catapult_pole_damage.png', 'Zombie_catapult_pole_damage_withball.png',
    'Zombie_zamboni_1_damage1.png', 'Zombie_zamboni_1_damage2.png',
    'Zombie_zamboni_2_damage1.png', 'Zombie_zamboni_2_damage2.png',
    'Zombie_ladder_1_damage1.png', 'Zombie_ladder_1_damage2.png', 'Zombie_ladder_5.png',
    'Zombie_digger_hardhat2.png', 'Zombie_digger_hardhat3.png',
    'Zombie_digger_outerarm_upper2.png', 'Zombie_ladder_outerarm_upper2.png',
    'Zombie_dolphinrider_outerarm_upper2.png', 'Zombie_bobsled_outerarm_upper2.png',
    'Zombie_imp_arm1_bone.png', 'Zombie_imp_arm2.png', 'Zombie_yeti_outerarm_upper2.png',
    'Zombie_snorkle_outerarm_upper2.png', 'Zombie_paper_leftarm_upper2.png',
    'Zombie_football_leftarm_upper2.png', 'Zombie_questionmark.png'
)
$ImageFiles = @(
    'Zombie_bobsled1.png', 'Zombie_bobsled2.png', 'Zombie_bobsled3.png',
    'Zombie_bobsled4.png', 'Zombie_bobsled_inside.png'
)

$copied = 0; $skipped = 0; $missing = New-Object System.Collections.Generic.List[string]
function Copy-SelectedAsset([string]$SourceDir, [string]$DestDir, [string]$FileName) {
    if (-not $SourceDir) { $script:missing.Add($FileName); return }
    $source = Join-Path $SourceDir $FileName
    $dest = Join-Path $DestDir $FileName
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { $script:missing.Add($FileName); return }
    if ((Test-Path -LiteralPath $dest -PathType Leaf) -and -not $Force) { $script:skipped++; return }
    Copy-Item -LiteralPath $source -Destination $dest -Force
    $script:copied++
}

foreach ($file in $ReanimFiles) { Copy-SelectedAsset $SourceReanim $DestinationReanim $file }
foreach ($file in $ImageFiles) { Copy-SelectedAsset $SourceImages $DestinationImages $file }

Write-Host "Original zombie asset install finished."
Write-Host "Copied: $copied"
Write-Host "Already present and left unchanged: $skipped"
Write-Host "Unavailable in selected source folder: $($missing.Count)"
if ($missing.Count -gt 0) {
    Write-Host 'Missing files (their corresponding visual stages remain dependent on the source bundle):'
    $missing | Sort-Object -Unique | ForEach-Object { Write-Host "  - $_" }
}
if (-not $Force) { Write-Host 'Existing project assets were not overwritten. Re-run with -Force only if you explicitly want to replace those named files.' }
