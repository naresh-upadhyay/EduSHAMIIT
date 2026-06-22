@echo off
echo ============================================
echo  EduSHAMIIT - Fast Chrome Launch
echo ============================================
echo.

:: Kill any stale Flutter Chrome debug instances
echo [1/3] Killing stale Chrome debug instances...
taskkill /F /FI "WINDOWTITLE eq *127.0.0.1*" >nul 2>&1

:: Clean build cache if it seems corrupted (> 50MB dill file)
for %%F in (build\*.cache.dill.track.dill) do (
    if exist "%%F" (
        echo [2/3] Cleaning stale build cache...
        call flutter clean
        call flutter pub get
        goto :run
    )
)
echo [2/3] Build cache OK, skipping clean.

:run
echo [3/3] Starting Flutter Web (IPv4, clean)...
echo.
flutter run -d chrome --web-launch-url http://127.0.0.1:63307
