# MoonBitMark GUI - ui_components.py
# 可复用 UI 组件：拖拽区、文件列表、路径选择器、诊断面板
import customtkinter as ctk
import os
from typing import Callable

# ============================================================
# 拖拽区组件
# ============================================================
SUPPORTED_EXTENSIONS = {
    '.txt', '.csv', '.json', '.pdf',
    '.png', '.jpg', '.jpeg', '.bmp', '.gif', '.tif', '.tiff', '.webp',
    '.html', '.htm', '.xhtml',
    '.docx', '.pptx', '.xlsx', '.epub',
}

EXT_LABELS = {
    '.pdf': 'PDF', '.docx': 'Word', '.pptx': 'PPT',
    '.xlsx': 'Excel', '.epub': 'EPUB', '.html': 'HTML',
    '.txt': 'TXT', '.csv': 'CSV', '.json': 'JSON',
    '.png': 'PNG', '.jpg': 'JPG', '.jpeg': 'JPEG',
    '.bmp': 'BMP', '.gif': 'GIF', '.tif': 'TIF', '.tiff': 'TIFF',
    '.webp': 'WebP', '.htm': 'HTML',
}

def get_ext_label(path: str) -> str:
    _, ext = os.path.splitext(path)
    return EXT_LABELS.get(ext.lower(), ext.upper()[1:] or 'FILE')

def is_supported(path: str) -> bool:
    _, ext = os.path.splitext(path)
    return ext.lower() in SUPPORTED_EXTENSIONS

class DropZone(ctk.CTkFrame):
    """文件拖拽区域"""

    def __init__(
        self,
        master,
        on_files_dropped: Callable[[list[str]], None] = None,
        **kwargs
    ):
        super().__init__(master, **kwargs)
        self.on_files_dropped = on_files_dropped
        self._click_btn = None
        self._inner = None
        self._parent_bg = self._get_bg_color()
        self._setup_ui()

    def _get_bg_color(self) -> str:
        """获取父组件的背景色（兼容 light/dark 模式）"""
        try:
            import customtkinter as ctk
            # CustomTkinter 默认颜色
            if ctk.get_appearance_mode() == 'Dark':
                return '#1e1e1e'  # dark mode 默认背景
            else:
                return '#f9f9f9'  # light mode 默认背景
        except Exception:
            return '#1e1e1e'  # 默认为 dark

    def _is_dark_mode(self) -> bool:
        """检测是否为深色模式"""
        try:
            import customtkinter as ctk
            return ctk.get_appearance_mode() == 'Dark'
        except Exception:
            return False

    def _setup_ui(self):
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(0, weight=1)

        self._inner = ctk.CTkFrame(self, fg_color='transparent')
        self._inner.grid(row=0, column=0, sticky='nsew', padx=8, pady=8)
        self._inner.bind('<Button-1>', lambda e: self._open_file_dialog())

        # 使用透明按钮覆盖整个区域来捕获点击
        self._click_btn = ctk.CTkButton(
            self._inner, text='', fg_color='transparent', hover_color=('gray90', '#2a2a2a'),
            border_width=0, height=120, command=self._open_file_dialog
        )
        self._click_btn.pack(fill='both', expand=True, padx=16, pady=16)
        self._click_btn.bind('<Enter>', lambda e: self._highlight(True))
        self._click_btn.bind('<Leave>', lambda e: self._highlight(False))

        icon_font = ('Segoe UI Emoji', 36)
        self.icon_label = ctk.CTkLabel(
            self._inner, text='📄', font=icon_font,
            text_color=('gray50', 'gray60')
        )
        self.icon_label.place(relx=0.5, rely=0.35, anchor='center')

        self.title_label = ctk.CTkLabel(
            self._inner, text='点击选择文件',
            font=ctk.CTkFont(size=15, weight='bold'),
        )
        self.title_label.place(relx=0.5, rely=0.5, anchor='center')

        self.sub_label = ctk.CTkLabel(
            self._inner, text='或拖拽文件到此处',
            font=ctk.CTkFont(size=12),
            text_color=('gray50', 'gray60'),
        )
        self.sub_label.place(relx=0.5, rely=0.62, anchor='center')

        formats_text = '支持: ' + ' / '.join(sorted(set(EXT_LABELS.values())))
        self.formats_label = ctk.CTkLabel(
            self._inner, text=formats_text,
            font=ctk.CTkFont(size=10),
            text_color=('gray50', 'gray60'),
            wraplength=480,
        )
        self.formats_label.place(relx=0.5, rely=0.8, anchor='center')


    def _highlight(self, on: bool):
        if on:
            self.configure(border_color=('#3b8ed6', '#1f6aa5'), border_width=2)
            if self._click_btn:
                self._click_btn.configure(fg_color=('#e8f4fc', '#1a2a3a'))
        else:
            self.configure(border_color=('gray70', 'gray30'), border_width=1)
            if self._click_btn:
                self._click_btn.configure(fg_color='transparent')

    def _parse_drop(self, data: str) -> list[str]:
        """解析 DND 数据，Windows 上通常是带花括号的路径列表"""
        import tkinter as tk
        try:
            root = self.winfo_toplevel()
            while not isinstance(root, tk.Tk):
                root = root.master
        except Exception:
            return []
        
        if hasattr(root, 'tk'):
            paths = root.tk.splitlist(data)
            return [p for p in paths if os.path.isfile(p)]
        return []

    def _open_file_dialog(self):
        import tkinter.filedialog as fd
        filetypes = [
            ('支持的文档', ' '.join('*' + ext for ext in SUPPORTED_EXTENSIONS)),
            ('PDF 文件', '*.pdf'),
            ('Word 文档', '*.docx'),
            ('PowerPoint', '*.pptx'),
            ('Excel 文件', '*.xlsx'),
            ('EPUB 电子书', '*.epub'),
            ('HTML 文件', '*.html *.htm *.xhtml'),
            ('图片文件', '*.png *.jpg *.jpeg *.bmp *.gif *.tif *.tiff *.webp'),
            ('文本文件', '*.txt *.csv *.json'),
            ('所有文件', '*.*'),
        ]
        files = fd.askopenfilenames(
            title='选择要转换的文件',
            filetypes=filetypes,
        )
        if files and self.on_files_dropped:
            self.on_files_dropped(list(files))

    def set_active(self, active: bool):
        if active:
            self._highlight(True)
        else:
            self._highlight(False)


# ============================================================
# 文件列表组件
# ============================================================
class FileListPanel(ctk.CTkFrame):
    """待转换文件列表"""

    STATUS_ICONS = {
        'pending':  '⏳',
        'running':  '🔄',
        'success':  '✅',
        'error':     '❌',
    }

    def __init__(self, master, on_remove: Callable[[int], None] = None, **kwargs):
        super().__init__(master, **kwargs)
        self.on_remove = on_remove
        self._files: list[dict] = []
        self._rows: list[ctk.CTkFrame] = []
        self._setup_ui()

    def _setup_ui(self):
        self.columnconfigure(0, weight=1)

        header = ctk.CTkFrame(self, fg_color='transparent')
        header.grid(row=0, column=0, sticky='ew', padx=12, pady=(8, 4))
        header.columnconfigure(1, weight=1)
        ctk.CTkLabel(header, text='文件', font=ctk.CTkFont(weight='bold'), width=260).grid(row=0, column=0, sticky='w')
        ctk.CTkLabel(header, text='格式', font=ctk.CTkFont(weight='bold'), width=60).grid(row=0, column=1, sticky='w', padx=(4, 0))

        self.canvas = ctk.CTkCanvas(self, bg='#1e1e1e', bd=0, highlightthickness=0)
        self.scrollbar = ctk.CTkScrollbar(self, command=self.canvas.yview)
        self.canvas.configure(yscrollcommand=self.scrollbar.set)

        self.list_frame = ctk.CTkFrame(self.canvas, fg_color='transparent')
        self.canvas.window = self.canvas.create_window((0, 0), window=self.list_frame, anchor='nw')

        self.list_frame.bind('<Configure>', lambda e: self.canvas.configure(scrollregion=self.canvas.bbox('all')))
        self.canvas.bind('<Configure>', lambda e: self.canvas.itemconfig(self.canvas.window, width=e.width))

        self.canvas.grid(row=1, column=0, sticky='nsew', padx=(4, 0))
        self.scrollbar.grid(row=1, column=1, sticky='ns')
        self.rowconfigure(1, weight=1)

    def add_files(self, paths: list[str]):
        for path in paths:
            if not os.path.isfile(path):
                continue
            # 避免重复
            if any(f['path'] == path for f in self._files):
                continue
            self._files.append({
                'path': path,
                'status': 'pending',
                'result': None,
            })
        self._render()

    def remove_file(self, index: int):
        if 0 <= index < len(self._files):
            self._files.pop(index)
            self._render()

    def update_status(self, index: int, status: str, result=None):
        if 0 <= index < len(self._files):
            self._files[index]['status'] = status
            self._files[index]['result'] = result
            self._render_item(index)

    def clear(self):
        self._files.clear()
        self._render()

    def get_pending(self) -> list[dict]:
        return [f for f in self._files if f['status'] == 'pending']

    def _render(self):
        for w in self._rows:
            w.destroy()
        self._rows.clear()
        for i, f in enumerate(self._files):
            self._add_row(i, f)

    def _add_row(self, i: int, f: dict):
        row = ctk.CTkFrame(self.list_frame, fg_color=('gray95', '#2a2a2a'), height=36)
        row.pack(fill='x', padx=4, pady=2)
        row.pack_propagate(False)
        row.grid_columnconfigure(1, weight=1)

        icon = ctk.CTkLabel(row, text=self.STATUS_ICONS.get(f['status'], '❓'), width=32, font=('Segoe UI Emoji', 14))
        icon.grid(row=0, column=0, padx=(8, 4), sticky='w')

        name = os.path.basename(f['path'])
        name_label = ctk.CTkLabel(
            row, text=name, anchor='w', font=ctk.CTkFont(size=12),
            text_color=('green' if f['status'] == 'success' else 'red' if f['status'] == 'error' else 'auto'),
            width=260,
        )
        name_label.grid(row=0, column=1, sticky='w', padx=(4, 8))

        ext_label = ctk.CTkLabel(row, text=get_ext_label(f['path']), width=60, font=ctk.CTkFont(size=10))
        ext_label.grid(row=0, column=2, sticky='w', padx=(0, 8))

        if f['status'] == 'pending':
            remove_btn = ctk.CTkButton(
                row, text='✕', width=28, height=28,
                fg_color='transparent', text_color=('gray40', 'gray60'),
                hover_color=('gray90', '#3a3a3a'),
                command=lambda idx=i: self._do_remove(idx),
            )
            remove_btn.grid(row=0, column=3, padx=4, sticky='e')
        elif f['status'] == 'running':
            spin = ctk.CTkLabel(row, text='⟳', font=('Segoe UI Symbol', 14), text_color='#3b8ed6')
            spin.grid(row=0, column=3, padx=4)

        self._rows.append(row)

    def _render_item(self, i: int):
        if i < len(self._rows):
            self._rows[i].destroy()
            self._rows[i] = None
            if i < len(self._files):
                self._add_row(i, self._files[i])

    def _do_remove(self, index: int):
        if self.on_remove:
            self.on_remove(index)
        self.remove_file(index)


# ============================================================
# 诊断结果面板
# ============================================================
class DiagPanel(ctk.CTkFrame):
    """显示转换诊断信息"""

    def __init__(self, master, **kwargs):
        super().__init__(master, **kwargs)
        self._setup_ui()

    def _setup_ui(self):
        self.rowconfigure(1, weight=1)
        self.columnconfigure(0, weight=1)

        header = ctk.CTkFrame(self, fg_color='transparent')
        header.grid(row=0, column=0, sticky='ew', padx=8, pady=(6, 4))
        header.columnconfigure(0, weight=1)
        ctk.CTkLabel(header, text='诊断信息', font=ctk.CTkFont(weight='bold')).grid(row=0, column=0, sticky='w')

        self.clear_btn = ctk.CTkButton(
            header, text='清空', width=50, height=22,
            fg_color=('gray80', '#3a3a3a'), hover_color=('gray70', '#4a4a4a'),
            command=self.clear,
        )
        self.clear_btn.grid(row=0, column=1, sticky='e')

        self.textbox = ctk.CTkTextbox(self, wrap='word', font=('Consolas', 11))
        self.textbox.grid(row=1, column=0, sticky='nsew', padx=8, pady=(0, 8))

    def append(self, text: str, tag: str = 'info'):
        color = {
            'info': ('#007acc', '#4fc1ff'),
            'success': ('#2e7d32', '#66bb6a'),
            'error': ('#c62828', '#ef5350'),
            'warn': ('#f57c00', '#ffa726'),
        }.get(tag, ('auto', 'auto'))
        self.textbox.insert('end', text + '\n', (tag,))
        self.textbox.tag_config(tag, text_color=color[0])
        self.textbox.see('end')

    def clear(self):
        self.textbox.delete('1.0', 'end')

    def set_diag(self, diag_data: dict):
        import json
        self.clear()
        self.append(json.dumps(diag_data, indent=2, ensure_ascii=False), 'info')
