@echo off
chcp 65001 >nul
title Interlocked - Auto-Updater

:: ===================== НАСТРОЙКИ =====================
set "GODOT_PATH=C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\Godot_v4.6-stable_win64.exe"
:: ====================================================

echo ============================================
echo   Interlocked - Обновление и запуск
echo ============================================
echo.

:: Проверяем Godot
if not exist "%GODOT_PATH%" (
    echo [ОШИБКА] Godot не найден по пути:
    echo   %GODOT_PATH%
    echo Открой .bat в Блокноте и поправь GODOT_PATH.
    echo.
    pause
    exit /b 1
)

:: Проверяем git
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [ОШИБКА] git не установлен.
    echo Скачай с https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)

:: Обновляем проект
echo [1/3] Получаю обновления...
git pull
if not %errorlevel% == 0 (
    echo [ОШИБКА] git pull не удался.
    echo.
    pause
    exit /b 1
)
echo       Готово!
echo.

:: Первый запуск — импорт ассетов
if not exist ".godot\editor\editor_metadata.cfg" (
    echo [2/3] Первый запуск — импорт ассетов...
    echo       Дождись завершения, закрой редактор, запусти снова.
    echo.
    start "" "%GODOT_PATH%" --editor --path "%~dp0."
    pause
    exit /b 0
)

:: Запускаем игру
echo [2/3] Запускаю игру...
start "" "%GODOT_PATH%" --path "%~dp0."

echo [3/3] Готово! Игра запущена.
echo.
pause