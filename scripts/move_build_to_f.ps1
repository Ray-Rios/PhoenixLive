# Move the big, regenerable Unreal build folders off C: onto F:, leaving
# directory junctions behind so every script and tool keeps using the same
# C:\ paths without knowing anything changed.
#
#   powershell -ExecutionPolicy Bypass -File scripts\move_build_to_f.ps1
#
# Run with the editor CLOSED and no build running. Safe to run again: a folder
# that is already a junction is skipped.
#
# What moves (all of it is build output - nothing here is source):
#   RaysSpaceSim\Intermediate\Build\Win64\x64\RSS   the Windows game compile (engine + game, grows to tens of GB)
#   RaysSpaceSim\Saved\Cooked                        cooked content
#   RaysSpaceSim\Saved\StagedBuilds                  UAT staging
#   RaysSpaceSim\Saved\ServerBuild                   server archive (Docker build context)
#   RaysSpaceSim\Saved\ClientBuild                   client archive (what the launcher publishes)
#   %LOCALAPPDATA%\UnrealEngine\Common\Zen\Data      Zen: local DDC + cooked packages
# And Unreal Build Accelerator's cache (up to 40 GB, C:\ProgramData\Epic\UnrealBuildAccelerator)
# is pointed at F: with the UBA_ROOT variable; the old cache is just deleted.

param([string]$Target = "F:\UnrealBuild")

$ErrorActionPreference = "Stop"
$Project = "C:\PhxLive\RaysSpaceSim"

$busy = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -match '^(UnrealEditor|UnrealEditor-Cmd|cl|link|UbaHost|UnrealBuildTool|AutomationTool)$' }
if ($busy) {
    Write-Host "Still running: $(($busy | Select-Object -ExpandProperty ProcessName -Unique) -join ', ')" -ForegroundColor Red
    Write-Host "Stop the build / close the editor first (Task Manager if Ctrl+C left them behind)."
    exit 1
}

function Free($drive) { [math]::Round((Get-PSDrive $drive).Free / 1GB, 1) }
Write-Host "Free before:  C: $(Free 'C') GB   F: $(Free 'F') GB"

$moves = @(
    @{ From = "$Project\Intermediate\Build\Win64\x64\RSS"; To = "$Target\Intermediate-Win64-RSS" },
    @{ From = "$Project\Saved\Cooked";                     To = "$Target\Saved-Cooked" },
    @{ From = "$Project\Saved\StagedBuilds";               To = "$Target\Saved-StagedBuilds" },
    @{ From = "$Project\Saved\ServerBuild";                To = "$Target\Saved-ServerBuild" },
    @{ From = "$Project\Saved\ClientBuild";                To = "$Target\Saved-ClientBuild" },
    # Zen: the local DDC and, since bUseZenStore=True (2026-10-14), every cooked
    # package for every platform. Grows with each platform cooked.
    @{ From = "$env:LOCALAPPDATA\UnrealEngine\Common\Zen\Data"; To = "$Target\ZenData" }
)

# Zen keeps its data folder open while it runs; it restarts on its own the next
# time the editor or a cook needs it.
$zen = Get-Process -Name zenserver -ErrorAction SilentlyContinue
if ($zen) {
    Write-Host "stopping zenserver so its data folder can move"
    $zen | Stop-Process -Force
    Start-Sleep -Seconds 2
}

New-Item -ItemType Directory -Force -Path $Target | Out-Null

foreach ($m in $moves) {
    $from = $m.From; $to = $m.To
    $item = Get-Item -LiteralPath $from -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq "Junction") {
        Write-Host "already on F:  $from -> $($item.Target)"
        continue
    }
    New-Item -ItemType Directory -Force -Path $to | Out-Null
    if ($item) {
        Write-Host "moving        $from -> $to"
        # /MOVE deletes each file from C: as it lands on F:, so space comes
        # back as it goes rather than needing both copies at once.
        robocopy $from $to /E /MOVE /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE) on $from" }
        if (Test-Path -LiteralPath $from) { Remove-Item -LiteralPath $from -Recurse -Force }
    } else {
        Write-Host "creating      $to"
        $parent = Split-Path $from -Parent
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    New-Item -ItemType Junction -Path $from -Target $to | Out-Null
    Write-Host "  junction    $from -> $to"
}

# Unreal Build Accelerator cache. UBT reads UBA_ROOT before falling back to
# C:\ProgramData\Epic\UnrealBuildAccelerator (UBAExecutor.cs).
$uba = "$Target\UBA"
New-Item -ItemType Directory -Force -Path $uba | Out-Null
[Environment]::SetEnvironmentVariable("UBA_ROOT", $uba, "User")
$oldUba = Join-Path $env:ProgramData "Epic\UnrealBuildAccelerator"
if (Test-Path $oldUba) {
    Write-Host "deleting old UBA cache $oldUba"
    Remove-Item -LiteralPath $oldUba -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "UBA_ROOT = $uba  (open a NEW terminal so builds see it)"

Write-Host "Free after:   C: $(Free 'C') GB   F: $(Free 'F') GB"
