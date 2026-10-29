# Puts the window of a process on top at x,y (physical pixels) and prints "X Y W H" of its client area in physical pixels.
param([string]$name = "scummvm", [int]$x = 40, [int]$y = 40)
Add-Type @'
using System; using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int X, int Y, int cx, int cy, uint flags);
  public struct RECT { public int L, T, R, B; }
  public struct POINT { public int X, Y; }
}
'@
[W]::SetProcessDPIAware() | Out-Null
$p = Get-Process $name -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { "none"; exit 1 }
$HWND_TOPMOST = [IntPtr](-1)
# SWP_NOSIZE 0x1 | SWP_SHOWWINDOW 0x40
[W]::SetWindowPos($p.MainWindowHandle, $HWND_TOPMOST, $x, $y, 0, 0, 0x41) | Out-Null
Start-Sleep -Milliseconds 500
$c = New-Object W+RECT; [W]::GetClientRect($p.MainWindowHandle, [ref]$c) | Out-Null
$pt = New-Object W+POINT; [W]::ClientToScreen($p.MainWindowHandle, [ref]$pt) | Out-Null
"$($pt.X) $($pt.Y) $($c.R) $($c.B)"
