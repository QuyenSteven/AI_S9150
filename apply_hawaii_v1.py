from pathlib import Path
import sys

TARGET = Path("llama.cpp") / "ggml" / "src" / "ggml-vulkan" / "ggml-vulkan.cpp"
MARKER = "// HAWAII_V1_SHARED_MEMORY_FA"
FUNC = "static vk_fa_tuning_params get_fa_tuning_params_scalar("

PATCH = r'''

    // HAWAII_V1_SHARED_MEMORY_FA
    // AMD Hawaii / GCN2 + proprietary Vulkan driver can produce corrupted
    // Flash Attention results when subgroup-based reductions are used.
    // Keep the modern FA shader, but force its shared-memory reduction path.
    if (device->vendor_id == VK_VENDOR_ID_AMD &&
        device->architecture == AMD_GCN) {
        result.row_split = 1;
        result.disable_subgroups = true;
        // flash_attn.comp treats SubGroupSize == 0 as "shared-memory reductions only".
        // Workgroup size has already been selected above, so this does not collapse it.
        result.subgroup_size = 0;
        result.limit_occupancy_shmem = 0;
    }
'''


def find_matching_brace(text: str, open_pos: int) -> int:
    depth = 0
    for i in range(open_pos, len(text)):
        c = text[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i
    raise RuntimeError("Could not find matching function brace")


def main():
    if not TARGET.exists():
        print(f"ERROR: {TARGET} not found")
        print("Run this script from the AI_S9150 repo after setup_b10894_hawaii_v1.bat clones llama.cpp.")
        return 2

    text = TARGET.read_text(encoding="utf-8")

    if MARKER in text:
        print("Hawaii V1 patch already applied.")
        return 0

    start = text.find(FUNC)
    if start < 0:
        print("ERROR: get_fa_tuning_params_scalar() was not found. Upstream source layout changed.")
        return 3

    brace = text.find('{', start)
    if brace < 0:
        print("ERROR: function opening brace not found")
        return 4

    end = find_matching_brace(text, brace)
    body = text[brace:end]

    ret_rel = body.rfind("return result;")
    if ret_rel < 0:
        print("ERROR: final 'return result;' not found in scalar FA tuning function")
        return 5

    insert_at = brace + ret_rel
    backup = TARGET.with_suffix(TARGET.suffix + ".hawaii-v1.orig")
    backup.write_text(text, encoding="utf-8")

    patched = text[:insert_at] + PATCH + text[insert_at:]
    TARGET.write_text(patched, encoding="utf-8")

    print("Applied Hawaii V1 patch successfully.")
    print(f"Patched: {TARGET}")
    print(f"Backup : {backup}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
