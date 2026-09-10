@echo off
setlocal
cd /d "%~dp0"

set MODEL=F:\AI\models\qwen2.5-coder-7b-instruct-q4_k_m.gguf
set PORT=8080

set EXE=llama.cpp\build-hawaii-v1\bin\Release\llama-server.exe
if not exist "%EXE%" set EXE=llama.cpp\build-hawaii-v1\bin\llama-server.exe
if not exist "%EXE%" (
    echo ERROR: llama-server.exe not found. Run setup_b10894_hawaii_v1.bat first.
    exit /b 1
)

if not exist "%MODEL%" (
    echo ERROR: model not found:
    echo %MODEL%
    exit /b 1
)

rem Clear old diagnostic overrides so this test measures only Hawaii V1.
set GGML_VK_DISABLE_MMVQ=
set GGML_VK_DISABLE_INTEGER_DOT_PRODUCT=
set GGML_VK_DISABLE_F16=
set GGML_VK_DISABLE_COOPMAT=
set GGML_VK_DISABLE_COOPMAT2=
set GGML_VK_DISABLE_DOT2=
set GGML_VK_DISABLE_FUSION=
set GGML_VK_DISABLE_ASYNC=
set GGML_VK_SERIALIZE_SUBMISSIONS=
set GGML_VK_DISABLE_GRAPH_OPTIMIZE=

"%EXE%" --device Vulkan0 ^
-m "%MODEL%" ^
-ngl 99 ^
-fa on ^
-c 4096 ^
-b 512 ^
-ub 128 ^
--host 127.0.0.1 ^
--port %PORT%

endlocal
