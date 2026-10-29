# Starts the original Grim Fandango and sends Backspace+F12 once it is up, which runs grimpatch.bin
param([int]$BootSeconds = 25)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class K {
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
"@
$dir = "C:\GOG Games\GRIMDATA"
$p = Start-Process -FilePath "$dir\GRIMFANDANGO.exe" -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds $BootSeconds
$p.Refresh()
Write-Output ("window handle: " + $p.MainWindowHandle + " responding: " + $p.Responding)
[K]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 500
[K]::keybd_event(0x08, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 300
[K]::keybd_event(0x7B, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 100
[K]::keybd_event(0x7B, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 300
[K]::keybd_event(0x08, 0, 2, [UIntPtr]::Zero)
Write-Output ("sent, pid " + $p.Id)
