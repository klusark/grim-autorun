# Records the window of ScummVM to a video while it plays (started after the run was started):
#   powershell -File record_window.ps1 <output .mkv> [x] [y]
# The window is moved to x,y (default 1000,100: away from the original, which sits at 0,0), the part of the desktop where its picture is gets
# recorded at 60 frames a second with the hardware encoder at a very high quality (constant quantizer 10, H.264, 4:2:0), until ScummVM ends.
# (The window of an OpenGL game cannot be taken by its title with gdigrab: it comes out black; the desktop region is what is on the screen.)
# The audio is not here: ScummVM is run with SDL_AUDIODRIVER=disk, which writes what it plays to a file; tools/record_mux.sh puts the two together.
param([string]$Out, [int]$X = 1000, [int]$Y = 100, [int]$Qp = 10, [string]$Audio = "")

Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class WinRec {
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Rr, B; }
  [StructLayout(LayoutKind.Sequential)] public struct P { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref P p);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
[WinRec]::SetProcessDPIAware() | Out-Null

# the window of ScummVM
$proc = $null
for ($i = 0; $i -lt 300 -and -not $proc; $i++) {
    $proc = Get-Process scummvm -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $proc) { Start-Sleep -Milliseconds 500 }
}
if (-not $proc) { Write-Output 'no ScummVM window'; exit 1 }
$h = $proc.MainWindowHandle
$r = New-Object WinRec+R
[WinRec]::GetWindowRect($h, [ref]$r) | Out-Null
[WinRec]::MoveWindow($h, $X, $Y, $r.Rr - $r.L, $r.B - $r.T, $true) | Out-Null
# (on top of everything, so that no other window comes between it and the recording of the screen)
[WinRec]::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 0x0003) | Out-Null
Start-Sleep -Milliseconds 800
$c = New-Object WinRec+R
[WinRec]::GetClientRect($h, [ref]$c) | Out-Null
$p = New-Object WinRec+P
[WinRec]::ClientToScreen($h, [ref]$p) | Out-Null
$w = $c.Rr; $hh = $c.B
Write-Output "recording the client area $w x $hh at $($p.X),$($p.Y) to $Out"

# (with -Audio "<dshow device>" the sound is recorded by the same ffmpeg, in the same clock as the picture: they cannot drift apart. The device that plays what the
# sound card plays is "Stereo Mix (...)"; ScummVM then plays out loud as usual.)
$ffargs = @('-hide_banner', '-y')
if ($Audio) { $ffargs += @('-f', 'dshow', '-use_wallclock_as_timestamps', '1', '-audio_buffer_size', '50', '-i', "audio=`"$Audio`"") }
$ffargs += @('-f', 'gdigrab', '-use_wallclock_as_timestamps', '1', '-framerate', '60', '-draw_mouse', '0', '-offset_x', "$($p.X)", '-offset_y', "$($p.Y)", '-video_size', "${w}x${hh}", '-i', 'desktop')
$ffargs += @('-c:v', 'h264_nvenc', '-preset', 'p7', '-tune', 'hq', '-rc', 'constqp', '-qp', "$Qp", '-profile:v', 'high', '-pix_fmt', 'yuv420p')
if ($Audio) { $ffargs += @('-c:a', 'aac', '-b:a', '256k', '-af', 'aresample=async=1') }
$ffargs += $Out
$ff = Start-Process -FilePath ffmpeg -PassThru -WindowStyle Hidden -ArgumentList $ffargs -RedirectStandardError "$Out.log"
$started = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
Set-Content -Path "$Out.start" -Value $started
Write-Output "ffmpeg started at $started"

# until ScummVM ends (the video is written as it goes: matroska survives a stop of the program)
while (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 5 }
Start-Sleep -Seconds 2
Stop-Process -Id $ff.Id -Force -ErrorAction SilentlyContinue
Write-Output 'ScummVM ended, recording stopped'
