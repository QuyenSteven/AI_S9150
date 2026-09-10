# AI_S9150 — llama.cpp b10894 Hawaii V1

Experimental AMD FirePro S9150 / Hawaii (GCN2) compatibility patch for llama.cpp Vulkan on Windows 10 x64.

## Target

- llama.cpp tag `b10894`
- AMD FirePro S9150 / Hawaii GCN2
- Vulkan full offload
- Qwen2.5-Coder 7B Q4_K_M
- Windows 10 x64

Observed baseline on the test machine:

- CPU (`-ngl 0`): correct output.
- Vulkan full offload + Flash Attention ON: corrupted output / `????`.
- Vulkan full offload + Flash Attention OFF: coherent output at about 25 tok/s.

## Hawaii V1 patch

V1 keeps Flash Attention enabled but changes only the scalar Flash Attention tuning path for `VK_VENDOR_ID_AMD + AMD_GCN`:

```cpp
result.row_split = 1;
result.disable_subgroups = true;
result.limit_occupancy_shmem = 0;
```

Important: V1 deliberately does **not** overwrite `result.subgroup_size`. Upstream b10894 already converts `disable_subgroups=true` into `SubGroupSize == 0` when building the FA pipeline state. This keeps the real hardware subgroup size available while `workgroup_size` and `d_split` are calculated, but makes `flash_attn.comp` use its shared-memory reduction fallback.

## Files

- `setup_b10894_hawaii_v1.bat` — full Windows preflight + clone + patch + Vulkan build.
- `apply_hawaii_v1.ps1` — PowerShell source patcher. Python is not required.
- `run_test_hawaii_v1.bat` — launches the patched server with the known-safe test settings.

## Requirements

The full setup script checks these before touching the source:

- Git for Windows
- Windows PowerShell
- Visual Studio 2022/2019 C++ Build Tools (`Desktop development with C++`)
- CMake 3.19 or newer
- LunarG Vulkan SDK x64, including `glslc.exe`, Vulkan headers and `vulkan-1.lib`

The script auto-detects common Visual Studio, CMake and `C:\VulkanSDK\...` installation locations. It also loads `VsDevCmd.bat` automatically, so `cl.exe` does not need to be manually added to PATH.

Python is **not required**.

## Build

From this branch:

```bat
git pull
setup_b10894_hawaii_v1.bat
```

The script performs:

1. complete prerequisite precheck,
2. clone or reset llama.cpp to exact tag `b10894`,
3. apply the Hawaii V1 patch,
4. verify the patch marker,
5. configure a clean x64 Visual Studio Vulkan build,
6. build `llama-server` Release.

If a prerequisite is missing, the window remains open and prints the exact missing component and installation page.

## Test

Default model path:

```text
F:\AI\models\qwen2.5-coder-7b-instruct-q4_k_m.gguf
```

Run:

```bat
run_test_hawaii_v1.bat
```

Default parameters:

```text
--device Vulkan0
-ngl 99
-fa on
-c 4096
-b 512
-ub 128
--host 127.0.0.1
--port 8080
```

Recommended functional prompt:

```text
Trả lời bằng tiếng Việt, không JSON. Viết chương trình STM32F103C8T6 nháy LED PC13 bằng CMSIS, không dùng HAL.
```

V1 success criterion: output remains coherent with Flash Attention ON and no `????`/garbage-token corruption. Performance tuning comes after correctness is confirmed.
