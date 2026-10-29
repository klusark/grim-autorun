$k="HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
$n="C:\GOG Games\GRIMDATA\GRIMFANDANGO.exe"
foreach ($v in @("~ WINXPSP3", "~ WINXPSP3 DISABLEDWM", "~ DISABLEDWM", "~ WIN95", "~ WINXPSP2 DWM8And16BitMitigation")) {
  Set-ItemProperty -Path $k -Name $n -Value $v
  $p = Start-Process -FilePath "C:\GOG Games\GRIMDATA\GRIMFANDANGO.exe" -WorkingDirectory "C:\GOG Games\GRIMDATA" -PassThru
  Start-Sleep -Seconds 18
  $p.Refresh()
  if ($p.HasExited) { "$v : CRASHED " + $p.ExitCode } else { "$v : ALIVE"; Stop-Process -Id $p.Id; Start-Sleep -Seconds 2 }
}
