@echo off
chcp 65001 >nul
title Interlocked - Auto-Updater

:: ===================== НАСТРОЙКИ =====================
:: Путь к Godot (Steam-версия) — ИЗМЕНИ если путь другой
set GODOT_PATH=C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\Godot_v4.6-stable_win64.exe
:: ====================================================

echo ============================================
echo   Interlocked - Обновление и запуск
echo ============================================
echo.

:: Проверяем Godot
if not exist "%GODOT_PATH%" (
    echo [ОШИБКА] Godot не найден:
    echo   %GODOT_PATH%
    echo.
    echo Отредактируй GODOT_PATH в этом скрипте.
    pause
    exit /b 1
)

:: Обновляем проект
echo [1/3] Получаю обновления...
git pull
if %errorlevel% neq 0 (
    echo [ОШИБКА] git pull не удался. Проверь интернет.
    pause
    exit /b 1
)
echo       Готово!
echo.

:: Первый запуск — нужен импорт ассетов
if not exist ".godot\editor\editor_metadata.cfg" (
    echo [2/3] Первый запуск — импорт ассетов...
    echo       Откроется редактор. Дождись завершения импорта,
    echo       закрой редактор и запусти скрипт снова.
    echo.
    start "" "%GODOT_PATH%" --editor --path "%~dp0."
    pause
    exit /b 0
)

:: Запускаем игру
echo [2/3] Запускаю игру...
start "" "%GODOT_PATH%" --path "%~dp0."

echo [3/3] Готово! Игра запущена.
timeout /t 5 >nul
