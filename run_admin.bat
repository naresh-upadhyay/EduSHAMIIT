@echo off
echo ===================================================
echo Starting EduSHAMIIT Admin Suite App
echo ===================================================
cd /d "%~dp0edu_shamiit_admin"
flutter run -d web-server --web-port 8081
pause
