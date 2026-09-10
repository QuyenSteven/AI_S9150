@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title AI_S9150 - b10894 Hawaii V1 FULL setup

set "ROOT=%CD%"
set "LLAMA_DIR=%ROOT%\llama.cpp"
set "BUILD_NAME=build-hawaii-v1"
set "MISSING_COMPONENT="

cls
echo ================================================================
echo AI_S9150 - llama.cpp b10894 Hawaii V1 - FULL WINDOWS BUILDER
echo ================================================================
echo Root : %ROOT%
echo OS   : Windows x64 expected
echo Note : Python is NOT required.
echo ================================================================
echo.

echo [PRECHECK 1/5] Git...
call :find_git
if errorlevel 1 goto :fail

echo [PRECHECK 2/5] Windows PowerShell...
call :find_powershell
if errorlevel 1 goto :fail

echo [PRECHECK 3/5] Visual Studio C++ toolchain...
call :find_visual_studio
if errorlevel 1 goto :fail

echo [PRECHECK 4/5] CMake...
call :find_cmake
if errorlevel 1 goto :fail

echo [PRECHECK 5/5] Vulkan SDK + glslc...
call :find_vulkan
if errorlevel 1 goto :fail

echo.
echo ================================================================
echo PRECHECK PASSED
echo ================================================================
echo Git       : %GIT_EXE%
echo PowerShell: %POWERSHELL_EXE%
echo Visual C++: %VSINSTALL%
echo Generator : %CMAKE_GENERATOR%
echo CMake     : %CMAKE_EXE%
echo Vulkan SDK: %VULKAN_SDK%
echo GLSLC     : %GLSLC_EXE%
echo ================================================================
echo.

"%GIT_EXE%" --version
"%CMAKE_EXE%" --version | findstr /b /c:"cmake version"
cl 2>&1 | findstr /c:"Version"
"%GLSLC_EXE%" --version | findstr /i /c:"shaderc" /c:"glslc"
echo.

echo [1/6] Getting exact llama.cpp b10894 source...
if not exist "%LLAMA_DIR%\.git" (
    if exist "%LLAMA_DIR%" (
        echo ERROR: "%LLAMA_DIR%" exists but is not a Git repository.
        set "MISSING_COMPONENT=SOURCE_DIR_CONFLICT"
        goto :fail
    )
    "%GIT_EXE%" clone --branch b10894 --depth 1 https://github.com/ggml-org/llama.cpp.git "%LLAMA_DIR%"
    if errorlevel 1 goto :fail
) else (
    echo Existing llama.cpp repository found.
    pushd "%LLAMA_DIR%"
    "%GIT_EXE%" fetch --tags --force
    if errorlevel 1 (popd & goto :fail)
    "%GIT_EXE%" checkout -f b10894
    if errorlevel 1 (popd & goto :fail)
    "%GIT_EXE%" reset --hard b10894
    if errorlevel 1 (popd & goto :fail)
    "%GIT_EXE%" clean -fd
    if errorlevel 1 (popd & goto :fail)
    popd
)

echo.
echo [2/6] Applying Hawaii V1 Flash Attention patch...
"%POWERSHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\apply_hawaii_v1.ps1"
if errorlevel 1 goto :fail

echo.
echo [3/6] Verifying patch marker...
findstr /c:"HAWAII_V1_SHARED_MEMORY_FA" "%LLAMA_DIR%\ggml\src\ggml-vulkan\ggml-vulkan.cpp" >nul
if errorlevel 1 (
    echo ERROR: Hawaii V1 marker was not found after patching.
    goto :fail
)
echo Patch marker OK.

echo.
echo [4/6] Removing previous Hawaii V1 build directory...
if exist "%LLAMA_DIR%\%BUILD_NAME%" (
    rmdir /s /q "%LLAMA_DIR%\%BUILD_NAME%"
    if exist "%LLAMA_DIR%\%BUILD_NAME%" (
        echo ERROR: Could not remove old build directory.
        echo Close any llama-server.exe or Explorer window using that directory.
        goto :fail
    )
)
echo Build directory ready.

echo.
echo [5/6] Configuring Vulkan Release build...
pushd "%LLAMA_DIR%"
"%CMAKE_EXE%" -S . -B "%BUILD_NAME%" -G "%CMAKE_GENERATOR%" -A x64 -DGGML_VULKAN=ON "-DVulkan_ROOT=%VULKAN_SDK%" "-DCMAKE_PREFIX_PATH=%VULKAN_SDK%"
if errorlevel 1 (popd & goto :fail)

echo.
echo [6/6] Building llama-server Release...
"%CMAKE_EXE%" --build "%BUILD_NAME%" --config Release --target llama-server --parallel
if errorlevel 1 (popd & goto :fail)
popd

set "SERVER_EXE=%LLAMA_DIR%\%BUILD_NAME%\bin\Release\llama-server.exe"
if not exist "%SERVER_EXE%" set "SERVER_EXE=%LLAMA_DIR%\%BUILD_NAME%\bin\llama-server.exe"
if not exist "%SERVER_EXE%" (
    echo ERROR: Build returned success but llama-server.exe was not found.
    goto :fail
)

echo.
echo ================================================================
echo SUCCESS - HAWAII V1 BUILD COMPLETED
echo ================================================================
echo Server:
echo   %SERVER_EXE%
echo.
echo Next step:
echo   run_test_hawaii_v1.bat
echo.
echo V1 test target:
echo   -ngl 99 -fa on -c 4096 -b 512 -ub 128
echo ================================================================
echo.
pause
exit /b 0

:find_git
set "GIT_EXE="
for /f "delims=" %%I in ('where git 2^>nul') do if not defined GIT_EXE set "GIT_EXE=%%I"
if not defined GIT_EXE (
    set "MISSING_COMPONENT=GIT"
    echo ERROR: Git was not found.
    exit /b 1
)
echo   FOUND: %GIT_EXE%
exit /b 0

:find_powershell
set "POWERSHELL_EXE="
for /f "delims=" %%I in ('where powershell 2^>nul') do if not defined POWERSHELL_EXE set "POWERSHELL_EXE=%%I"
if not defined POWERSHELL_EXE if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not defined POWERSHELL_EXE (
    set "MISSING_COMPONENT=POWERSHELL"
    echo ERROR: Windows PowerShell was not found.
    exit /b 1
)
echo   FOUND: %POWERSHELL_EXE%
exit /b 0

:find_visual_studio
set "VSWHERE="
set "VSINSTALL="
set "VSYEAR="
set "VSDEVCMD="
set "CMAKE_GENERATOR="

if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not defined VSWHERE if exist "%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe" set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"

if defined VSWHERE (
    for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%I"
    for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property catalog_productLineVersion`) do set "VSYEAR=%%I"
)

if not defined VSINSTALL call :probe_vs_path "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools" 2022
if not defined VSINSTALL call :probe_vs_path "%ProgramFiles%\Microsoft Visual Studio\2022\Community" 2022
if not defined VSINSTALL call :probe_vs_path "%ProgramFiles%\Microsoft Visual Studio\2022\Professional" 2022
if not defined VSINSTALL call :probe_vs_path "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise" 2022
if not defined VSINSTALL call :probe_vs_path "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools" 2019
if not defined VSINSTALL call :probe_vs_path "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Community" 2019

if not defined VSINSTALL (
    set "MISSING_COMPONENT=MSVC"
    echo ERROR: Visual Studio C++ Build Tools were not found.
    exit /b 1
)

set "VSDEVCMD=%VSINSTALL%\Common7\Tools\VsDevCmd.bat"
if not exist "%VSDEVCMD%" (
    set "MISSING_COMPONENT=MSVC"
    echo ERROR: VsDevCmd.bat was not found under:
    echo   %VSINSTALL%
    exit /b 1
)

call "%VSDEVCMD%" -no_logo -arch=x64 -host_arch=x64 >nul
if errorlevel 1 (
    set "MISSING_COMPONENT=MSVC"
    echo ERROR: Visual Studio developer environment failed to initialize.
    exit /b 1
)

where cl >nul 2>nul
if errorlevel 1 (
    set "MISSING_COMPONENT=MSVC"
    echo ERROR: cl.exe is still unavailable after loading VsDevCmd.
    exit /b 1
)

if "%VSYEAR%"=="2022" set "CMAKE_GENERATOR=Visual Studio 17 2022"
if "%VSYEAR%"=="2019" set "CMAKE_GENERATOR=Visual Studio 16 2019"
if not defined CMAKE_GENERATOR (
    rem VS 17 is the expected current toolchain for this project.
    set "CMAKE_GENERATOR=Visual Studio 17 2022"
)

echo   FOUND: %VSINSTALL%
echo   MSVC : cl.exe available
exit /b 0

:probe_vs_path
if exist "%~1\Common7\Tools\VsDevCmd.bat" (
    set "VSINSTALL=%~1"
    set "VSYEAR=%~2"
)
exit /b 0

:find_cmake
set "CMAKE_EXE="
for /f "delims=" %%I in ('where cmake 2^>nul') do if not defined CMAKE_EXE set "CMAKE_EXE=%%I"
if not defined CMAKE_EXE if exist "%ProgramFiles%\CMake\bin\cmake.exe" set "CMAKE_EXE=%ProgramFiles%\CMake\bin\cmake.exe"
if not defined CMAKE_EXE if defined VSINSTALL if exist "%VSINSTALL%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" set "CMAKE_EXE=%VSINSTALL%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"

if not defined CMAKE_EXE (
    set "MISSING_COMPONENT=CMAKE"
    echo ERROR: CMake was not found.
    exit /b 1
)

for %%I in ("%CMAKE_EXE%") do set "PATH=%%~dpI;%PATH%"
echo   FOUND: %CMAKE_EXE%
exit /b 0

:find_vulkan
set "GLSLC_EXE="

if defined VULKAN_SDK (
    if not exist "%VULKAN_SDK%\Bin\glslc.exe" set "VULKAN_SDK="
)

if not defined VULKAN_SDK (
    for /f "delims=" %%I in ('powershell -NoLogo -NoProfile -Command "$d=Get-ChildItem -LiteralPath ''C:\VulkanSDK'' -Directory -ErrorAction SilentlyContinue ^| Sort-Object { try { [version]$_.Name } catch { [version]''0.0'' } } -Descending ^| Select-Object -First 1; if($d){$d.FullName}"') do set "VULKAN_SDK=%%I"
)

if not defined VULKAN_SDK (
    set "MISSING_COMPONENT=VULKAN"
    echo ERROR: Vulkan SDK was not found.
    exit /b 1
)

set "GLSLC_EXE=%VULKAN_SDK%\Bin\glslc.exe"
if not exist "%GLSLC_EXE%" (
    set "MISSING_COMPONENT=VULKAN"
    echo ERROR: glslc.exe is missing from Vulkan SDK:
    echo   %GLSLC_EXE%
    exit /b 1
)
if not exist "%VULKAN_SDK%\Include\vulkan\vulkan.h" (
    set "MISSING_COMPONENT=VULKAN"
    echo ERROR: Vulkan headers are missing:
    echo   %VULKAN_SDK%\Include\vulkan\vulkan.h
    exit /b 1
)
if not exist "%VULKAN_SDK%\Lib\vulkan-1.lib" (
    set "MISSING_COMPONENT=VULKAN"
    echo ERROR: Vulkan x64 library is missing:
    echo   %VULKAN_SDK%\Lib\vulkan-1.lib
    exit /b 1
)

set "PATH=%VULKAN_SDK%\Bin;%PATH%"
echo   FOUND: %VULKAN_SDK%
exit /b 0

:fail
echo.
echo ================================================================
echo SETUP / BUILD FAILED
echo ================================================================
if "%MISSING_COMPONENT%"=="GIT" (
    echo Missing: Git for Windows
    echo Install: https://git-scm.com/download/win
)
if "%MISSING_COMPONENT%"=="POWERSHELL" (
    echo Missing: Windows PowerShell
    echo Windows 10 normally includes Windows PowerShell 5.1.
)
if "%MISSING_COMPONENT%"=="MSVC" (
    echo Missing: Microsoft Visual C++ Build Tools
    echo Required workload: Desktop development with C++
    echo Required component: MSVC x64/x86 build tools + Windows SDK
    echo Install: https://visualstudio.microsoft.com/visual-cpp-build-tools/
    echo.
    where winget >nul 2>nul && echo Optional winget: winget install --id Microsoft.VisualStudio.2022.BuildTools -e
)
if "%MISSING_COMPONENT%"=="CMAKE" (
    echo Missing: CMake 3.19 or newer
    echo Install: https://cmake.org/download/
    echo During setup select: Add CMake to the system PATH
    echo.
    where winget >nul 2>nul && echo Optional winget: winget install --id Kitware.CMake -e
)
if "%MISSING_COMPONENT%"=="VULKAN" (
    echo Missing: LunarG Vulkan SDK for Windows x64
    echo llama.cpp b10894 Vulkan requires Vulkan + glslc.
    echo Install: https://vulkan.lunarg.com/sdk/home#windows
    echo After installing, open a NEW CMD window before rerunning this file.
)
if "%MISSING_COMPONENT%"=="SOURCE_DIR_CONFLICT" (
    echo Rename or delete the non-Git folder:
    echo   %LLAMA_DIR%
)
echo.
echo Send me a screenshot of this window if it still fails.
echo The window will stay open.
echo ================================================================
echo.
pause
exit /b 1
