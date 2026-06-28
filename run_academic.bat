@echo off
echo ===================================================
echo Starting EduSHAMIIT Academic App (Student & Teacher)
echo ===================================================
cd /d "%~dp0edu_shamiit_academic"
flutter run -d web-server --web-port 8080
pause
