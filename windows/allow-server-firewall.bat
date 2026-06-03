@echo off
REM ==========================================================================
REM  Opens the Windows Firewall for the CS:S GunGame server.
REM  RIGHT-CLICK this file -> "Als Administrator ausfuehren".
REM ==========================================================================
set EXE=%~dp0srcds_win64.exe

netsh advfirewall firewall delete rule name="CSS GunGame Server" >nul 2>&1
netsh advfirewall firewall add rule name="CSS GunGame Server" dir=in action=allow program="%EXE%" enable=yes profile=any
netsh advfirewall firewall add rule name="CSS GunGame Server Port UDP" dir=in action=allow protocol=UDP localport=27015 enable=yes profile=any
netsh advfirewall firewall add rule name="CSS GunGame Server Port TCP" dir=in action=allow protocol=TCP localport=27015 enable=yes profile=any

echo.
echo Fertig. Firewall ist jetzt fuer den Server geoeffnet.
pause
