#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Export the immutable runtime, then apply only the diagnostic patch to this fixture.
# No prepare/build tree mutation, device, game data or game process is involved.
git archive HEAD:platform | tar -x -C "$work"
git -C "$work" apply "$PWD/wolkaraforever/patches/0072-host-tls-lifetime-diagnostics.patch"
CC=(xcrun clang -Wall -Wextra -Werror -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer)
"${CC[@]}" -fobjc-arc -Iwolkaraforever/Shell -framework Foundation \
    wolkaraforever/Shell/HostLifetimeDiagnostics.m wolkaraforever/Shell/tests/test_host_lifetime_diagnostics.m \
    -o "$work/test_host_lifetime"
"$work/test_host_lifetime"
"${CC[@]}" -std=c11 -D_DARWIN_C_SOURCE -I"$work/runtime" \
    "$work/runtime/GuestTLS.c" wolkaraforever/Shell/tests/test_host_tls_lifetime.c -o "$work/test_host_tls"
"$work/test_host_tls"
"${CC[@]}" -std=c11 -D_DARWIN_C_SOURCE -I"$work/runtime" \
    "$work/runtime/GuestTLS.c" "$work/runtime/GuestTLSArm64.S" "$work/tests/test_tls.c" "$work/tests/test_tls_arm64.S" \
    -o "$work/test_tls_abi"
"$work/test_tls_abi"
