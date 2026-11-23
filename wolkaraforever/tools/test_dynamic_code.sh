#!/bin/bash
# Host-owned code fixtures only. No application files or device required.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build
work=$(mktemp -d "$PWD/build/dynamic-code-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT
xcrun clang -std=c11 -D_DARWIN_C_SOURCE -Wall -Wextra -Werror -O1 -g \
    -fsanitize=address,undefined -fno-omit-frame-pointer \
    -Iplatform/runtime -Iwolkaraforever/Runtime \
    wolkaraforever/Runtime/CodeRemap.c wolkaraforever/Runtime/tests/test_code_remap.c \
    -o "$work/code-remap"
"$work/code-remap"

xcrun clang -std=c11 -D_DARWIN_C_SOURCE -Wall -Wextra -Werror -O1 -g \
    -fsanitize=address,undefined -fno-omit-frame-pointer \
    -Iwolkaraforever/Runtime wolkaraforever/Runtime/MemoryTrace.c \
    wolkaraforever/Runtime/tests/test_memory_trace.c -o "$work/memory-trace"
"$work/memory-trace"
