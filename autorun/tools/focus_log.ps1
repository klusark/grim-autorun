# Logs which window has the focus every few seconds, and whether the window of the original game is the one (and whether it is minimized or hidden):
#   powershell -File focus_log.ps1 <log file> [seconds between lines]
# To see afterwards if a failure of the original came with the game in the background (the story of a run is in logs/orig_all.txt).
param([string]$Log, [int]$Every = 5, [switch]$Nudge)

Add-Type -TypeDefinition @"
using System; using System.Text; using System.Runtime.InteropServices;
public class Fg {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  // tells every window of a process that its program was activated (what the game waits for to go on with its movies while another window has the focus)
  public static int Activate(uint pid) {
    int n = 0;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid) { PostMessage(h, 0x001C, (IntPtr)1, IntPtr.Zero); PostMessage(h, 0x0006, (IntPtr)1, IntPtr.Zero); n++; }
      return true;
    }, IntPtr.Zero);
    return n;
  }
}
"@

while ($true) {
    $fg = [Fg]::GetForegroundWindow()
    $pid1 = [uint32]0
    [Fg]::GetWindowThreadProcessId($fg, [ref]$pid1) | Out-Null
    $sb = New-Object System.Text.StringBuilder 256
    [Fg]::GetWindowText($fg, $sb, 256) | Out-Null
    $p = Get-Process -Id $pid1 -ErrorAction SilentlyContinue
    $game = Get-Process GRIMFANDANGO -ErrorAction SilentlyContinue | Select-Object -First 1
    $state = 'no game'
    if ($game) {
        $h = $game.MainWindowHandle
        $focused = ($game.Id -eq $pid1)
        $state = "game focused=$focused minimized=$([Fg]::IsIconic($h)) visible=$([Fg]::IsWindowVisible($h))"
        if ($Nudge -and -not $focused) { $state += " nudged=$([Fg]::Activate([uint32]$game.Id))" }
    }
    $line = "{0} foreground={1} '{2}' | {3}" -f (Get-Date -Format 'MM-dd HH:mm:ss'), $(if ($p) { $p.ProcessName } else { '?' }), $sb.ToString(), $state
    Add-Content -Path $Log -Value $line
    Start-Sleep -Seconds $Every
}
