# AI_S9150 — b10894 Hawaii V1

Experimental AMD FirePro S9150 / Hawaii (GCN2) compatibility patch for llama.cpp Vulkan.

Target baseline:
- llama.cpp tag `b10894`
- Windows 10 x64
- AMD FirePro S9150 / Hawaii GCN2
- Qwen2.5-Coder 7B Q4_K_M
- Vulkan full offload

Observed before patch:
- CPU (`-ngl 0`): correct output.
- Vulkan full offload + Flash Attention ON: corrupted tokens/output.
- Vulkan full offload + Flash Attention OFF: correct output, about 25 tok/s on the tested S9150.

## What V1 changes

V1 keeps Flash Attention enabled, but for `VK_VENDOR_ID_AMD + AMD_GCN` it forces the scalar Flash Attention shader onto its shared-memory reduction path instead of subgroup-based reduction.

The injected compatibility block sets:

```cpp
result.row_split = 1;
result.disable_subgroups = true;
result.subgroup_size = 0;
result.limit_occupancy_shmem = 0;
```

`flash_attn.comp` already defines `SubGroupSize == 0` as the shared-memory reduction fallback, so V1 deliberately reuses the upstream safe path instead of replacing the shader.

## Build on Windows

Checkout this branch, then run:

```bat
setup_b10894_hawaii_v1.bat
```

The script:
1. clones upstream llama.cpp if missing,
2. checks out exact tag `b10894`,
3. applies `apply_hawaii_v1.py`,
4. configures `GGML_VULKAN=ON`,
5. builds `llama-server` Release.

Requirements: Git, Python 3, CMake, a C++ build toolchain, and Vulkan SDK/runtime suitable for building llama.cpp Vulkan.

## Test

The default test launcher expects the model at:

```text
F:\AI\models\qwen2.5-coder-7b-instruct-q4_k_m.gguf
```

Run:

```bat
run_test_hawaii_v1.bat
```

It launches full GPU offload with Flash Attention ON:

```text
-ngl 99 -fa on -c 4096 -b 512 -ub 128
```

Recommended functional prompt:

```text
Trả lời bằng tiếng Việt, không JSON. Viết chương trình STM32F103C8T6 nháy LED PC13 bằng CMSIS, không dùng HAL.
```

Success criterion for V1: no `????`/garbage-token corruption while keeping Flash Attention ON. Performance is secondary until correctness is confirmed.
