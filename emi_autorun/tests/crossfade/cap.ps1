param([string]$out, [string]$proc = "scummvm", [string]$match = "kitlever", [int]$n = 1, [int]$gap = 150)
# Captures a window's own pixels (PrintWindow with PW_RENDERFULLCONTENT), even when other windows cover it: the client area only
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W2 { [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
public struct RECT { public int l, t, r, b; } public struct POINT { public int x, y; } }
"@
[W2]::SetProcessDPIAware() | Out-Null
if ($proc -eq "scummvm") { $id = (Get-CimInstance Win32_Process -Filter "Name='scummvm.exe'" | Where-Object { $_.CommandLine -like "*$match*" } | Select-Object -First 1).ProcessId }
else { $id = (Get-CimInstance Win32_Process -Filter "Name='Monkey4.exe'" | Where-Object { $_.ExecutablePath -like "*\emi_autorun\orig\Monkey4.exe" } | Select-Object -First 1).ProcessId }
$h = (Get-Process -Id $id).MainWindowHandle
for ($i = 0; $i -lt $n; $i++) {
  $wr = New-Object W2+RECT; [W2]::GetWindowRect($h, [ref]$wr) | Out-Null
  $cr = New-Object W2+RECT; [W2]::GetClientRect($h, [ref]$cr) | Out-Null
  $pt = New-Object W2+POINT; [W2]::ClientToScreen($h, [ref]$pt) | Out-Null
  $bmp = New-Object System.Drawing.Bitmap ($wr.r - $wr.l), ($wr.b - $wr.t)
  $g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
  [W2]::PrintWindow($h, $hdc, 2) | Out-Null
  $g.ReleaseHdc($hdc); $g.Dispose()
  $client = $bmp.Clone((New-Object System.Drawing.Rectangle ($pt.x - $wr.l), ($pt.y - $wr.t), $cr.r, $cr.b), $bmp.PixelFormat)
  $client.Save("$out$i.png"); $client.Dispose(); $bmp.Dispose()
  Start-Sleep -Milliseconds $gap
}
