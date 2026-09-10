# AI_S9150

AMD FirePro S9150 / Hawaii (GCN2) compatibility work for llama.cpp Vulkan.

Current target: llama.cpp tag `b10894`, Qwen2.5-Coder 7B Q4_K_M, Windows 10, Vulkan.

Observed baseline:
- CPU (`-ngl 0`): correct output.
- Vulkan full offload + Flash Attention ON: corrupted tokens/output.
- Vulkan full offload + Flash Attention OFF: correct output, about 25 tok/s on the tested S9150.

Development branches contain experimental Hawaii-specific patches.
