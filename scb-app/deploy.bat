@echo off
chcp 65001 >nul
echo [1/3] 빌드 중...
call npm run build
if %errorlevel% neq 0 (
    echo 빌드 실패
    pause
    exit /b 1
)

echo [2/3] Firestore 규칙 올리는 중...
call firebase deploy --only firestore:rules
if %errorlevel% neq 0 (
    echo 규칙 배포 실패
    pause
    exit /b 1
)

echo [3/3] 웹앱 올리는 중...
call firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo 배포 실패
    pause
    exit /b 1
)

echo.
echo 배포 완료! https://safecheckboard.web.app
pause
