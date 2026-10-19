@echo off
chcp 65001 >nul
if not "%SCB_ACCESS_MIGRATED%"=="1" (
    echo 먼저 docs\운영-권한-이전.md 의 인증 활성화와 기존 세션 이전을 완료하세요.
    echo 완료 후 set SCB_ACCESS_MIGRATED=1 을 지정하고 다시 실행하세요.
    exit /b 1
)
echo [1/3] 빌드 중...
call npm run build
if %errorlevel% neq 0 (
    echo 빌드 실패
    pause
    exit /b 1
)

echo [2/3] 로그인 설정 올리는 중...
call firebase deploy --only auth
if %errorlevel% neq 0 (
    echo 로그인 설정 배포 실패
    pause
    exit /b 1
)

echo [3/3] 웹앱과 Firestore 규칙 올리는 중...
call firebase deploy --only hosting,firestore:rules
if %errorlevel% neq 0 (
    echo 배포 실패
    pause
    exit /b 1
)

echo.
echo 배포 완료! https://safecheckboard.web.app
pause
