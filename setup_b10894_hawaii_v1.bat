@echo off
setlocal
cd /d "%~dp0"

where git >nul 2>nul || (echo ERROR: git not found & exit /b 1)
where python >nul 2>nul || (echo ERROR: python not found & exit /b 1)
where cmake >nul 2>nul || (echo ERROR: cmake not found & exit /b 1)

if not exist llama.cpp\.git (
    echo Cloning llama.cpp...
    git clone https://github.com/ggml-org/llama.cpp.git llama.cpp || exit /b 1
)

cd llama.cpp

echo Checking out exact upstream tag b10894...
git fetch --tags --force || exit /b 1
git reset --hard || exit /b 1
git clean -fd || exit /b 1
git checkout -f b10894 || exit /b 1
cd ..

echo Applying Hawaii V1 patch...
python apply_hawaii_v1.py || exit /b 1

cd llama.cpp

echo Configuring Vulkan Release build...
cmake -S . -B build-hawaii-v1 -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release || exit /b 1

echo Building llama-server...
cmake --build build-hawaii-v1 --config Release -j --target llama-server || exit /b 1

echo.
echo ==============================================
echo Hawaii V1 build completed.
echo Look under:
echo   llama.cpp\build-hawaii-v1\bin\Release
echo or:
echo   llama.cpp\build-hawaii-v1\bin
echo ==============================================
endlocal
