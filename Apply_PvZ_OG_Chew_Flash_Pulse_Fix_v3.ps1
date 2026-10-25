$ErrorActionPreference = 'Stop'

# Small source-accuracy fix for the plant flash while zombies eat.
# Changes only scripts\scr_pvz_lawn_runtime\scr_pvz_lawn_runtime.gml.
# 1) Refreshes the 25-tick plant flash at OG chew-animation timed events, not damage ticks.
# 2) Stops overriding anim_eat to 36/20 fps; OG PlayZombieReanim passes rate 0 and keeps the current rate.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$relativePath = Join-Path 'scripts' (Join-Path 'scr_pvz_lawn_runtime' 'scr_pvz_lawn_runtime.gml')
$candidates = @(
    (Join-Path $scriptDir $relativePath),
    (Join-Path (Get-Location).Path $relativePath),
    (Join-Path $scriptDir 'scr_pvz_lawn_runtime.gml')
)
$targetPath = $null
foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $targetPath = (Resolve-Path -LiteralPath $candidate).Path
        break
    }
}
if (-not $targetPath) {
    Write-Host 'Could not find scripts\scr_pvz_lawn_runtime\scr_pvz_lawn_runtime.gml.' -ForegroundColor Red
    Write-Host 'Extract this ZIP beside PvZ.yyp and run the BAT again.'
    exit 1
}

$bytes = [System.IO.File]::ReadAllBytes($targetPath)
$utf8 = [System.Text.UTF8Encoding]::new($false)
$text = $utf8.GetString($bytes)
$hadBom = $text.Length -gt 0 -and $text[0] -eq [char]0xFEFF
if ($hadBom) { $text = $text.Substring(1) }
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$originalPayload = $text

function Get-BraceBlock {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$StartPattern,
        [Parameter(Mandatory=$true)][string]$Label
    )
    $matches = [regex]::Matches($Source, $StartPattern)
    if ($matches.Count -ne 1) { throw "Expected exactly one $Label; found $($matches.Count). No files were changed." }
    $m = $matches[0]
    $open = $Source.IndexOf('{', $m.Index)
    if ($open -lt 0) { throw "$Label has no opening brace. No files were changed." }
    $depth = 0
    $close = -1
    for ($i = $open; $i -lt $Source.Length; $i++) {
        if ($Source[$i] -eq '{') { $depth++ }
        elseif ($Source[$i] -eq '}') {
            $depth--
            if ($depth -eq 0) { $close = $i; break }
        }
    }
    if ($close -lt 0) { throw "$Label has unbalanced braces. No files were changed." }
    $lineStart = $Source.LastIndexOf("`n", $m.Index)
    $lineStart = if ($lineStart -lt 0) { 0 } else { $lineStart + 1 }
    $indent = [regex]::Match($Source.Substring($lineStart, $m.Index - $lineStart), '^[\t ]*').Value
    return [pscustomobject]@{
        Match = $m; Start = $m.Index; Open = $open; Close = $close; End = $close + 1
        Indent = $indent; Text = $Source.Substring($m.Index, $close + 1 - $m.Index)
    }
}

function Get-ChewEvent {
    param([string]$Source)
    $pattern = '(?m)^(?<indent>[\t ]*)if\s*\(\s*_hit_t1\s*\|\|\s*_hit_t2\s*\)(?<tail>[^\r\n]*)'
    $matches = [regex]::Matches($Source, $pattern)
    if ($matches.Count -ne 1) { throw "Expected exactly one OG chew-animation event hook; found $($matches.Count). No files were changed." }
    $m = $matches[0]
    $tail = $m.Groups['tail'].Value.Trim()
    if ($tail -match '^pvz_lawn_play_random_sound\s*\(') {
        return [pscustomobject]@{ Kind = 'Inline'; Match = $m; Start = $m.Index; End = $m.Index + $m.Length; Indent = $m.Groups['indent'].Value; Text = $m.Value }
    }
    # Supports a block opener on this line or on the next line.
    $brace = $Source.IndexOf('{', $m.Index)
    $nextNewline = $Source.IndexOf("`n", $m.Index)
    if ($brace -lt 0 -or ($nextNewline -ge 0 -and $brace -gt $nextNewline + 2)) {
        throw 'The chew-event hook has an unrecognized form. No files were changed.'
    }
    $depth = 0; $close = -1
    for ($i = $brace; $i -lt $Source.Length; $i++) {
        if ($Source[$i] -eq '{') { $depth++ }
        elseif ($Source[$i] -eq '}') {
            $depth--
            if ($depth -eq 0) { $close = $i; break }
        }
    }
    if ($close -lt 0) { throw 'The chew-event block has unbalanced braces. No files were changed.' }
    return [pscustomobject]@{ Kind = 'Block'; Match = $m; Start = $m.Index; End = $close + 1; Indent = $m.Groups['indent'].Value; Text = $Source.Substring($m.Index, $close + 1 - $m.Index) }
}

try {
    # Verify and correct the eat animation rate ONLY inside Zombie::begin_eating.
    $eatFunction = Get-BraceBlock -Source $text -StartPattern '(?m)^[\t ]*function\s+pvz_lawn_zombie_begin_eating\s*\([^)]*\)\s*\{' -Label 'pvz_lawn_zombie_begin_eating function'
    $ratePattern = '(?m)^(?<indent>[\t ]*)body\.play\(\s*"anim_eat"\s*,\s*ReanimLoop\.LOOP\s*,\s*20\s*,\s*[^;\r\n]*\);'
    $rateMatches = [regex]::Matches($eatFunction.Text, $ratePattern)
    if ($rateMatches.Count -ne 1) { throw "Expected one anim_eat play call inside pvz_lawn_zombie_begin_eating; found $($rateMatches.Count). No files were changed." }
    $rateMatch = $rateMatches[0]
    $rateLine = "$($rateMatch.Groups['indent'].Value)body.play(`"anim_eat`", ReanimLoop.LOOP, 20, 0.0);"
    $eatBlockText = $eatFunction.Text.Remove($rateMatch.Index, $rateMatch.Length).Insert($rateMatch.Index, $rateLine)
    $text = $text.Remove($eatFunction.Start, $eatFunction.End - $eatFunction.Start).Insert($eatFunction.Start, $eatBlockText)

    # Remove stale refreshes on the damage tick. Preserve the refresh inside the chew event.
    $event = Get-ChewEvent -Source $text
    $assignmentPattern = '(?m)^[\t ]*target_plant\.eaten_flash_countdown\s*=\s*[^;\r\n]*;[\t ]*(?://[^\r\n]*)?(?:\r?\n|$)'
    $assignments = [regex]::Matches($text, $assignmentPattern)
    $outside = @($assignments | Where-Object { $_.Index -lt $event.Start -or $_.Index -ge $event.End } | Sort-Object Index -Descending)
    foreach ($match in $outside) { $text = $text.Remove($match.Index, $match.Length) }

    # Re-resolve event after any earlier text removal.
    $event = Get-ChewEvent -Source $text
    $canonical = 'target_plant.eaten_flash_countdown = max(target_plant.eaten_flash_countdown, 25);'
    if ($event.Kind -eq 'Inline') {
        $replacement = @(
            "$($event.Indent)if (_hit_t1 || _hit_t2) {"
            "$($event.Indent)    pvz_lawn_play_random_sound([`"chomp.ogg`", `"chomp2.ogg`"]);"
            "$($event.Indent)    // Zombie::AnimateChewEffect refreshes this on each OG timed chew event."
            "$($event.Indent)    if (instance_exists(target_plant) && target_plant.plant_health > 0) {"
            "$($event.Indent)        $canonical"
            "$($event.Indent)    }"
            "$($event.Indent)}"
        ) -join $newline
        $text = $text.Remove($event.Start, $event.Match.Length).Insert($event.Start, $replacement)
    } else {
        $eventText = $event.Text
        $insidePattern = '(?m)^[\t ]*target_plant\.eaten_flash_countdown\s*=\s*[^;\r\n]*;'
        $inside = [regex]::Matches($eventText, $insidePattern)
        if ($inside.Count -gt 1) { throw 'Found multiple plant flash assignments in the chew event. No files were changed.' }
        if ($inside.Count -eq 1) {
            $m = $inside[0]
            $indent = [regex]::Match($m.Value, '^[\t ]*').Value
            $eventText = $eventText.Remove($m.Index, $m.Length).Insert($m.Index, "$indent$canonical")
            $text = $text.Remove($event.Start, $event.End - $event.Start).Insert($event.Start, $eventText)
        } else {
            $close = $event.End - 1
            $lineStart = $text.LastIndexOf("`n", $close)
            $lineStart = if ($lineStart -lt 0) { 0 } else { $lineStart + 1 }
            $insert = @(
                "$($event.Indent)    if (instance_exists(target_plant) && target_plant.plant_health > 0) {"
                "$($event.Indent)        $canonical"
                "$($event.Indent)    }"
            ) -join $newline
            $text = $text.Insert($lineStart, $insert + $newline)
        }
    }

    # Final safety checks: exactly one flash refresh in the timed event, none on damage ticks,
    # and source-style non-overridden eat animation rate.
    $event = Get-ChewEvent -Source $text
    $eventText = $event.Text
    $insideCount = [regex]::Matches($eventText, 'target_plant\.eaten_flash_countdown\s*=\s*max\(\s*target_plant\.eaten_flash_countdown\s*,\s*25\s*\)\s*;').Count
    $allAssignmentMatches = [regex]::Matches($text, $assignmentPattern)
    $outsideCount = @($allAssignmentMatches | Where-Object { $_.Index -lt $event.Start -or $_.Index -ge $event.End }).Count
    $eatingCallCount = [regex]::Matches($eatBlockText, 'body\.play\(\s*"anim_eat"\s*,\s*ReanimLoop\.LOOP\s*,\s*20\s*,\s*0\.0\s*\);').Count
    if ($insideCount -ne 1 -or $outsideCount -ne 0 -or $eatingCallCount -ne 1) {
        throw "Final validation failed (event flash=$insideCount, damage-time refreshes=$outsideCount, source eat-rate=$eatingCallCount). No files were changed."
    }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

if ($text -eq $originalPayload) {
    Write-Host 'OG eating-flash pulse behavior is already installed. No files were changed.' -ForegroundColor Green
    exit 0
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupPath = "$targetPath.bak_$stamp"
try {
    [System.IO.File]::Copy($targetPath, $backupPath, $false)
    $finalText = if ($hadBom) { [string][char]0xFEFF + $text } else { $text }
    [System.IO.File]::WriteAllText($targetPath, $finalText, $utf8)
} catch {
    if (Test-Path -LiteralPath $backupPath) { Write-Host "Backup remains at: $backupPath" }
    Write-Host "Could not write the updated script: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host 'Applied source-style OG eating-flash pulses.' -ForegroundColor Green
Write-Host "Updated: $targetPath"
Write-Host "Backup:  $backupPath"
Write-Host 'Only scr_pvz_lawn_runtime.gml was changed.'
