@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title AI_S9150 - Hawaii V1 setup

echo ============================================================
echo AI_S9150 - llama.cpp b10894 Hawaii V1 builder
echo Working directory: %CD%
echo ============================================================
echo.

call :check_tool git || goto :fail
call :check_tool python || goto :fail
call :check_tool cmake || goto :fail

echo.
echo [1/5] Tool versions
git --version
python --version
cmake --version | findstr /b /c:"cmake version"

echo.
echo [2/5] Getting llama.cpp source...
if not exist "llama.cpp\.git" (
    git clone https://github.com/ggml-org/llama.cpp.git llama.cpp
    if errorlevel 1 goto :fail
) else (
    echo llama.cpp already exists - reusing it.
)

pushd llama.cpp
if errorlevel 1 goto :fail

echo.
echo [3/5] Checking out exact upstream tag b10894...
git fetch --tags --force
if errorlevel 1 (popd & goto :fail)
git reset --hard
if errorlevel 1 (popd & goto :fail)
git clean -fd
if errorlevel 1 (popd & goto :fail)
git checkout -f b10894
if errorlevel 1 (popd & goto :fail)
popd

echo.
echo [4/5] Applying Hawaii V1 patch...
python apply_hawaii_v1.py
if errorlevel 1 goto :fail

pushd llama.cpp
if errorlevel 1 goto :fail

echo.
echo [5/5] Configuring Vulkan Release build...
cmake -S . -B build-hawaii-v1 -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
if errorlevel 1 (popd & goto :fail)

echo.
echo Building llama-server...
cmake --build build-hawaii-v1 --config Release --target llama-server --parallel
if errorlevel 1 (popd & goto :fail)
popd

echo.
echo ============================================================
echo SUCCESS: Hawaii V1 build completed.
echo.
echo Expected executable locations:
echo   llama.cpp\build-hawaii-v1\bin\Release\llama-server.exe
echo   llama.cpp\build-hawaii-v1\bin\llama-server.exe
echo.
echo Next: run run_test_hawaii_v1.bat
echo ============================================================
echo.
pause
exit /b 0

:check_tool
where %1 >nul 2>nul
if errorlevel 1 (
    echo ERROR: "%1" was not found in PATH.
    echo Install it or add it to PATH, then open a NEW CMD window.
    exit /b 1
)
echo FOUND: %1
exit /b 0

:fail
echo.
echo ============================================================
echo BUILD FAILED.
echo The window will stay open so you can send me a screenshot

echo of the LAST error lines above.
echo ============================================================
echo.
pause
exit /b 1
