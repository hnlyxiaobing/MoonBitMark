# MoonBitMark GUI - main.py
# 程序入口，兼容 "python main.py" 和 PyInstaller 打包后运行
import sys
import os

# 确保 gui 目录在 sys.path 中
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if _SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _SCRIPT_DIR)

# 处理 PyInstaller 打包后的资源路径
def _get_main_exe_dir() -> str:
    """返回 main.exe 所在的目录（PyInstaller 打包后为 _internal）"""
    if getattr(sys, 'frozen', False):
        return os.path.join(sys._MEIPASS)
    return _SCRIPT_DIR

# 当 converter.py 需要查找 main.exe 时，需要向上找到项目根目录
import converter as _conv_mod

# PyInstaller 打包后，main.exe 就在 _internal 根目录
if getattr(sys, 'frozen', False):
    _internal_dir = _get_main_exe_dir()
    _injected_path = os.path.join(_internal_dir, 'main.exe')
    if os.path.exists(_injected_path) and _injected_path not in _conv_mod.SEARCH_PATHS:
        _conv_mod.SEARCH_PATHS.insert(0, _injected_path)

from app import main as app_main

if __name__ == '__main__':
    app_main()
