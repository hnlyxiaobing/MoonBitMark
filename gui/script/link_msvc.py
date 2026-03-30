"""MoonBitMark Link Script - 手动调用 MSVC link.exe 生成 main.exe"""
import subprocess
import os
import sys
import shutil

msvc_bin    = r'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64'
msvc_lib    = r'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\lib\x64'
ucrt_lib    = r'C:\Program Files (x86)\Windows Kits\10\lib\10.0.26100.0\ucrt\x64'
um_lib      = r'C:\Program Files (x86)\Windows Kits\10\lib\10.0.26100.0\um\x64'
build_dir   = r'D:\MySoftware\MoonBitMark\_build\native\release\build'
tmp_exe     = os.path.join(build_dir, 'cmd', 'main', 'MoonBitMark.exe')
final_exe   = os.path.join(build_dir, 'cmd', 'main', 'main.exe')

env = os.environ.copy()
env['PATH'] = msvc_bin + ';' + env.get('PATH', '')
env['LIB']  = msvc_lib + ';' + ucrt_lib + ';' + um_lib

# 只收集 main 相关 obj（跳过 demo / mcp-server）
objs = [
    os.path.join(root, f)
    for root, dirs, files in os.walk(build_dir)
    for f in files
    if f.endswith('.obj')
    and ('cmd' + os.sep + 'demo' not in os.path.join(root, f))
    and ('cmd' + os.sep + 'mcp-server' not in os.path.join(root, f))
]

# mooncakes lib
libs = [
    os.path.join(root, f)
    for root, dirs, files in os.walk(build_dir)
    for f in files
    if f.endswith('.lib')
]

cmd = [
    os.path.join(msvc_bin, 'link.exe'),
    '/NOLOGO',
    '/SUBSYSTEM:CONSOLE',
    '/OUT:' + tmp_exe,
    '/LIBPATH:' + msvc_lib,
    '/LIBPATH:' + ucrt_lib,
    '/LIBPATH:' + um_lib,
    '/LIBPATH:' + build_dir,
] + objs + libs + [
    'kernel32.lib', 'user32.lib', 'msvcrt.lib',
    'ws2_32.lib', 'winhttp.lib', 'crypt32.lib',
    'bcrypt.lib', 'advapi32.lib',
]

print('Objs:', len(objs), ' Libs:', len(libs))
print('Linking...')

p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
out, _ = p.communicate()
print(out.decode('utf-8', errors='replace'))
print('RC:', p.returncode)

if p.returncode == 0 and os.path.exists(tmp_exe):
    shutil.copy2(tmp_exe, final_exe)
    size_mb = os.path.getsize(final_exe) / 1024 / 1024
    print('SUCCESS! main.exe -> ' + final_exe + ' (' + str(round(size_mb, 1)) + ' MB)')
    sys.exit(0)
else:
    print('FAILED!')
    sys.exit(1)
