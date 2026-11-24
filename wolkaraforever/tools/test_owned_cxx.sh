#!/bin/bash
# Run original fixtures, never game code; no device or downloaded client required.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build
work=$(mktemp -d "$PWD/build/cxx-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT
source=wolkaraforever/Cxx
python3 "$source/build.py" macos "$work/module"
cc=(xcrun clang -std=c11 -D_DARWIN_C_SOURCE -Wall -Wextra -Werror -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer -Iplatform/runtime -I"$source")
objects=()
for file in platform/runtime/GuestMemory.c platform/runtime/GuestImage.c platform/runtime/GuestFixups.c platform/runtime/GuestLink.c "$source/NativeCxx.c"; do
    object="$work/$(basename "$file").o"
    "${cc[@]}" -c "$file" -o "$object"
    objects+=("$object")
done
"${cc[@]}" "${objects[@]}" "$source/tests/policy.c" -o "$work/policy"
"$work/policy"
"${cc[@]}" -c "$source/tests/loader_probe.c" -o "$work/loader.o"
xcrun clang++ -std=c++17 -Wall -Wextra -Werror -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer \
    "${objects[@]}" "$work/loader.o" "$source/tests/host_strings.cpp" -o "$work/loader"
xcrun clang++ -std=c++17 -Wall -Wextra -Werror -O0 -Wl,-export_dynamic \
    "$source/tests/allocator_fixture.cpp" -o "$work/fixture"
"$work/fixture"
"$work/fixture" threads
# A baseline failure is required: otherwise this would merely test the implementation.
for scenario in strings threads; do
    if "$work/loader" "$work/fixture" legacy "$scenario" > "$work/legacy-$scenario.log" 2>&1; then
        echo "FAIL: legacy $scenario did not reproduce the allocator discrepancy" >&2;exit 1
    else
        result=$?
    fi
    [ "$result" -eq 1 ]
    grep -q 'loader fixture_result=1' "$work/legacy-$scenario.log"
    cat "$work/legacy-$scenario.log"
done
for scenario in direct strings threads; do
    "$work/loader" "$work/fixture" "$work/module/wkOwnedCxx.dylib" "$scenario" > "$work/fixed-$scenario.log" 2>&1
    grep -q 'untracked_releases=0' "$work/fixed-$scenario.log"
    grep -q 'loader fixture_result=0' "$work/fixed-$scenario.log"
    grep -q 'host_unchanged=1' "$work/fixed-$scenario.log"
    cat "$work/fixed-$scenario.log"
done
if "$work/loader" "$work/fixture" "$work/missing.dylib" strings > "$work/missing.log" 2>&1; then
    echo 'FAIL: missing ownership adapter was accepted' >&2;exit 1
else
    [ "$?" -eq 2 ]
fi
grep -q 'isolated C++ adapter could not be loaded' "$work/missing.log"
if grep -Eq 'ERROR: AddressSanitizer|runtime error:' "$work/"*.log; then
    echo 'FAIL: sanitizer reported an error' >&2;exit 1
fi
echo 'PASS: C++ allocator ownership, strings, threads/future exit, host isolation, no-custom path and fail-closed preparation (Mac arm64)'
