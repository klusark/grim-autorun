param([int]$Seconds = 25)
$dir = "C:\GOG Games\GRIMDATA"
$p = Start-Process -FilePath "$dir\GRIMFANDANGO.exe" -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds $Seconds
$p.Refresh()
if ($p.HasExited) { "CRASHED, exit code " + $p.ExitCode } else { "alive after $Seconds s"; Stop-Process -Id $p.Id }
