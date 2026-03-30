# MoonBitMark GUI - converter.py
# 封装对 MoonBitMark main.exe 的调用
import subprocess
import os
import sys
import json
import threading
import re

# main.exe 搜索路径（相对 script 目录向上两级 = 项目根）
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, '..'))

# MoonBitMark 支持的文件扩展名
SUPPORTED_EXTENSIONS = {
    '.txt', '.csv', '.json', '.pdf',
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp',
    '.html', '.xhtml', '.htm', '.url',
    '.docx', '.pptx', '.xlsx', '.epub',
}

def is_supported(file_path: str) -> bool:
    """检查文件是否被支持"""
    _, ext = os.path.splitext(file_path)
    return ext.lower() in SUPPORTED_EXTENSIONS

# 在以下位置查找 main.exe
SEARCH_PATHS = [
    os.path.join(PROJECT_ROOT, '_build', 'native', 'release', 'build', 'cmd', 'main', 'main.exe'),
    os.path.join(PROJECT_ROOT, '_build', 'native', 'debug',   'build', 'cmd', 'main', 'main.exe'),
    os.path.join(PROJECT_ROOT, '_build', 'native', 'release', 'build', 'cmd', 'main', 'MoonBitMark.exe'),
]

def find_main_exe() -> str | None:
    """在已知位置查找 main.exe"""
    for path in SEARCH_PATHS:
        if os.path.exists(path):
            return path
    return None

def get_version(exe_path: str) -> str:
    """获取 MoonBitMark 版本信息"""
    try:
        result = subprocess.run(
            [exe_path, '--help'],
            capture_output=True, timeout=10,
            text=False, encoding='utf-8', errors='replace'
        )
        out = result.stdout.decode('utf-8', errors='replace')
        # 第一行通常是 "MoonBitMark vX.X.X ..."
        match = re.search(r'MoonBitMark\s+v?([\d.]+)', out)
        if match:
            return match.group(0)
    except Exception:
        pass
    return 'MoonBitMark (unknown version)'

class ConversionResult:
    """转换结果数据类"""
    def __init__(self, success: bool, output_path: str = '', error: str = '', markdown: str = ''):
        self.success = success
        self.output_path = output_path
        self.error = error
        self.markdown = markdown

    def to_dict(self):
        return {
            'success': self.success,
            'output_path': self.output_path,
            'error': self.error,
            'markdown': self.markdown,
        }

def convert_file(
    input_path: str,
    output_dir: str,
    exe_path: str,
    use_frontmatter: bool = True,
    use_plain_text: bool = False,
    progress_callback=None,
    diag_callback=None,
) -> ConversionResult:
    """
    调用 main.exe 将单个文件转换为 Markdown

    参数:
        input_path:      源文件路径
        output_dir:      输出目录
        exe_path:        main.exe 路径
        use_frontmatter: 包含 YAML frontmatter
        use_plain_text:  纯文本模式
        progress_callback: (status: str) -> None
        diag_callback:   (diag: dict) -> None

    返回:
        ConversionResult
    """
    if not os.path.exists(input_path):
        return ConversionResult(success=False, error=f'文件不存在: {input_path}')
    if not os.path.exists(exe_path):
        return ConversionResult(success=False, error=f'未找到 main.exe: {exe_path}')
    if not os.path.isdir(output_dir):
        return ConversionResult(success=False, error=f'输出目录无效: {output_dir}')

    # 构建输出文件名
    base = os.path.splitext(os.path.basename(input_path))[0]
    output_path = os.path.join(output_dir, base + '.md')

    cmd = [
        exe_path,
        input_path,
        output_path,
        '--diag-json',
    ]
    if use_frontmatter:
        cmd.append('--frontmatter')
    if use_plain_text:
        cmd.append('--plain-text')

    if progress_callback:
        progress_callback(f'正在转换: {os.path.basename(input_path)}')

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            timeout=120,           # 2 分钟超时
            text=False,
            encoding='utf-8',
            errors='replace',
        )
    except subprocess.TimeoutExpired:
        return ConversionResult(success=False, error='转换超时（超过 2 分钟）')
    except Exception as e:
        return ConversionResult(success=False, error=str(e))

    # 尝试解析诊断 JSON
    diag_raw = result.stdout.strip().split('\n')
    diag_text = ''
    md_text = ''

    for line in diag_raw:
        try:
            diag = json.loads(line)
            if diag_callback:
                diag_callback(diag)
            diag_text = json.dumps(diag, indent=2, ensure_ascii=False)
        except json.JSONDecodeError:
            md_text += line + '\n'

    if result.returncode == 0 and os.path.exists(output_path):
        if progress_callback:
            progress_callback(f'转换完成: {os.path.basename(output_path)}')
        return ConversionResult(
            success=True,
            output_path=output_path,
            markdown=diag_text,
        )
    else:
        err = result.stderr.decode('utf-8', errors='replace') if isinstance(result.stderr, bytes) else result.stderr
        return ConversionResult(
            success=False,
            error=err or f'转换失败 (exit code {result.returncode})',
            markdown=diag_text,
        )

def convert_file_async(
    input_path: str,
    output_dir: str,
    exe_path: str,
    use_frontmatter: bool = True,
    use_plain_text: bool = False,
    progress_callback=None,
    diag_callback=None,
    done_callback=None,
):
    """异步执行转换（在新线程中）"""
    def _run():
        try:
            result = convert_file(
                input_path, output_dir, exe_path,
                use_frontmatter, use_plain_text,
                progress_callback, diag_callback,
            )
        except Exception as e:
            result = ConversionResult(success=False, error=f'转换异常: {str(e)}')
        
        if done_callback:
            done_callback(result)
    
    t = threading.Thread(target=_run, daemon=True)
    t.start()
    return t

