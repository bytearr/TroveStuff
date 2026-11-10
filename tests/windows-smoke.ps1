$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$runtime = Join-Path $env:RUNNER_TEMP 'autohotkey-1.1.37.02'
New-Item -ItemType Directory -Force $runtime | Out-Null
Invoke-WebRequest 'https://github.com/AutoHotkey/AutoHotkey/releases/download/v1.1.37.02/AutoHotkey_1.1.37.02.zip' -OutFile "$runtime/runtime.zip"
Expand-Archive "$runtime/runtime.zip" $runtime -Force
$ahk = Join-Path $runtime 'AutoHotkeyU64.exe'
$profiles = Start-Process $ahk -ArgumentList @('/ErrorStdOut', "`"$PSScriptRoot/profile_test.ahk`"") -PassThru -Wait
if ($profiles.ExitCode -ne 0) { throw 'Profile tests failed' }
$ready = Join-Path $PSScriptRoot 'dashboard-ready.txt'
Remove-Item $ready -ErrorAction SilentlyContinue
$process = Start-Process $ahk -ArgumentList @('/ErrorStdOut', "`"$PSScriptRoot/dashboard_smoke.ahk`"") -PassThru
try {
    $deadline = (Get-Date).AddSeconds(30)
    while (!(Test-Path $ready) -and !$process.HasExited -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 100
    }
    if (Test-Path $ready) {
        Add-Type -AssemblyName System.Drawing
        Add-Type -AssemblyName System.Windows.Forms
        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $image = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
        $graphics = [System.Drawing.Graphics]::FromImage($image)
        try {
            $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
            $image.Save((Join-Path $root 'dashboard-windows.png'))
        } finally { $graphics.Dispose(); $image.Dispose() }
    }
    if (!$process.WaitForExit(10000)) { throw 'Dashboard smoke test timed out' }
    if ($process.ExitCode -ne 0) { throw 'Dashboard smoke tests failed' }
} finally {
    if (!$process.HasExited) { $process.Kill() }
    Get-Process Trove -ErrorAction SilentlyContinue | Stop-Process -Force
}
