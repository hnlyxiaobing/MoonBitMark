# -*- mode: python ; coding: utf-8 -*-
# MoonBitMark GUI PyInstaller 打包配置

block_cipher = None

# 收集所有 Python 文件
a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=[
        # 将 main.exe 嵌入到打包文件中
        (
            r'D:\MySoftware\MoonBitMark\_build\native\release\build\cmd\main\main.exe',
            '.'
        ),
    ],
    win_no_prefer_redirects_version_info={'0000': '0, 3, 0, 0'},
    win_private_assemblies_version_info={'0000': '0, 3, 0, 0'},
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='MoonBitMark',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,          # 不显示控制台窗口（GUI 程序）
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,              # 可设置 icon
)
