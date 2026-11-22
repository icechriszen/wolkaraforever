#!/usr/bin/env python3
"""Build the isolated, signed-by-the-normal-packager C++ adapter from source."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile


def run(args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('platform', choices=('macos', 'ios', 'iossim'))
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    source = Path(__file__).resolve().parent
    sdk, target = {'macos': ('macosx', 'arm64-apple-macos14.0'),
                   'ios': ('iphoneos', 'arm64-apple-ios17.0'),
                   'iossim': ('iphonesimulator', 'arm64-apple-ios17.0-simulator')}[args.platform]
    args.output.mkdir(parents=True, exist_ok=True)
    common = ['xcrun', '--sdk', sdk, 'clang++', '-target', target, '-isysroot',
              run(['xcrun', '--sdk', sdk, '--show-sdk-path']).strip(), '-std=c++17',
              '-O1', '-g', '-Wall', '-Wextra', '-Werror', '-Wno-deprecated-declarations',
              '-D_LIBCPP_BUILDING_LIBRARY', '-I', str(source)]
    originals = json.loads((source / 'vendor/SOURCE.json').read_text())
    for name, digest in originals['sha256'].items():
        if hashlib.sha256((source / 'vendor' / name).read_bytes()).hexdigest() != digest:
            raise SystemExit('Vendored libc++ source changed: ' + name)
    with tempfile.TemporaryDirectory(prefix='owned-cxx-', dir=args.output.parent) as temp:
        temp = Path(temp)
        objects, names = [], set()
        for name in ('Allocator.cpp', 'vendor/string.cpp', 'vendor/thread.cpp'):
            obj = temp / (Path(name).stem + '.o')
            run(common + ['-c', str(source / name), '-o', str(obj)])
            objects.append(str(obj))
            if name == 'Allocator.cpp':
                continue
            for symbol in run(['xcrun', 'nm', '-gUj', str(obj)]).splitlines():
                if re.match(r'__ZNK?St3__1(?:12basic_string|21__basic_string_common|9to_string|10to_wstring|pl|15__thread_struct|19__thread_local_data)', symbol):
                    names.add(symbol)
        if not names:
            raise SystemExit('No isolated C++ definitions were built')
        names = sorted(names)
        lines = ['#include <stddef.h>', '#include <string.h>']
        for i, symbol in enumerate(names):
            lines.append(f'extern void symbol_{i}(void) __asm__("{symbol}");')
        lines.append('static const struct { const char *name; void *address; } symbols[] = {')
        for i, symbol in enumerate(names):
            lines.append(f'{{"{symbol[1:]}",(void *)&symbol_{i}}},')
        lines += ['};', 'void *WKLookupOwnedCxx(const char *name) {',
                  'if(!name)return NULL;', 'size_t low=0,high=sizeof symbols/sizeof *symbols;',
                  'while(low<high){size_t middle=low+(high-low)/2; int order=strcmp(name,symbols[middle].name);',
                  'if(!order)return symbols[middle].address; if(order<0)high=middle;else low=middle+1;}',
                  'return NULL;}']
        lookup = temp / 'Lookup.c'
        lookup.write_text('\n'.join(lines) + '\n')
        lookup_object = temp / 'Lookup.o'
        c = common.copy()
        c[c.index('clang++')] = 'clang'
        c[c.index('-std=c++17')] = '-std=c11'
        run(c + ['-c', str(lookup), '-o', str(lookup_object)])
        objects.append(str(lookup_object))
        exports = temp / 'exports.txt'
        exports.write_text('_WKGetOwnedCxxAPI\n')
        output = args.output / 'wkOwnedCxx.dylib'
        run(common + ['-dynamiclib', *objects, '-Wl,-install_name,@rpath/wkOwnedCxx.dylib',
                      '-Wl,-exported_symbols_list,' + str(exports), '-o', str(output)])
        exported = run(['xcrun', 'nm', '-gUj', str(output)]).splitlines()
        if exported != ['_WKGetOwnedCxxAPI']:
            raise SystemExit('Isolated module exposed C++ symbols: ' + str(exported))
        imports = run(['xcrun', 'nm', '-guj', str(output)]).splitlines()
        if any(re.match(r'__Z[nd][al]', name) for name in imports):
            raise SystemExit('Isolated module still imports a host new/delete operator')
        print(f'Owned C++ adapter: {len(names)} isolated APIs; only its C interface is exported')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.output) from error
