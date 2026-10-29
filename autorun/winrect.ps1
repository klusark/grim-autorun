param([string]$name = "scummvm")
Add-Type @'
using System; using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  public struct RECT { public int L, T, R, B; }
  public struct POINT { public int X, Y; }
}
'@
$p = Get-Process $name -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if ($p) {
  $r = New-Object W+RECT; [W]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
  $c = New-Object W+RECT; [W]::GetClientRect($p.MainWindowHandle, [ref]$c) | Out-Null
  $pt = New-Object W+POINT; [W]::ClientToScreen($p.MainWindowHandle, [ref]$pt) | Out-Null
  "title=[$($p.MainWindowTitle)] window=$($r.L),$($r.T) $($r.R - $r.L)x$($r.B - $r.T) client=$($c.R)x$($c.B) at $($pt.X),$($pt.Y)"
} else { "no window" }
