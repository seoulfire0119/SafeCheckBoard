@echo off
echo [1/3] Flutter 빌드 중...
call C:\Users\user\.puro\flutter_direct.bat build web --release
if %errorlevel% neq 0 (
    echo 빌드 실패
    pause
    exit /b 1
)

echo [2/3] 서비스 워커 비활성화 중...
node -e "const fs=require('fs'); const f='build/web/flutter_bootstrap.js'; let c=fs.readFileSync(f,'utf8'); c=c.replace(/_flutter\.loader\.load\(\{[\s\S]*?\}\);/, '_flutter.loader.load({});'); fs.writeFileSync(f,c); console.log('완료');"
if %errorlevel% neq 0 (
    echo 패치 실패
    pause
    exit /b 1
)

echo [3/3] Firebase 배포 중...
C:\Users\user\AppData\Roaming\npm\firebase.cmd deploy --only hosting
if %errorlevel% neq 0 (
    echo 배포 실패
    pause
    exit /b 1
)

echo.
echo 배포 완료! https://safecheckboard.web.app
pause
