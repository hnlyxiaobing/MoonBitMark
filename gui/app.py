# MoonBitMark GUI - app.py
# 主窗口：主题切换 + 转换按钮 + 状态栏
import customtkinter as ctk
import os
import tkinter.filedialog as fd
from datetime import datetime
from converter import (
    find_main_exe, get_version, convert_file,
    is_supported, SUPPORTED_EXTENSIONS,
)
from ui_components import DropZone, FileListPanel, DiagPanel

# ============================================================
# 配置
# ============================================================
APP_NAME = 'MoonBitMark'
WINDOW_W, WINDOW_H = 860, 640
SIDEBAR_W = 230

# ============================================================
# 主应用类
# ============================================================
class MoonBitMarkApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title(APP_NAME)
        self.geometry(f'{WINDOW_W}x{WINDOW_H}')
        self.minsize(700, 500)
        self._center()

        # 查找 main.exe
        self.main_exe = find_main_exe()
        if self.main_exe:
            self.app_version = get_version(self.main_exe)
        else:
            self.app_version = 'MoonBitMark (main.exe 未找到)'

        # 转换状态
        self.is_converting = False
        self._active_threads = []
        self._diag_count = 0

        self._setup_ui()
        self._bind_shortcuts()

    def _center(self):
        self.update_idletasks()
        sw = self.winfo_screenwidth()
        sh = self.winfo_screenheight()
        x = (sw - WINDOW_W) // 2
        y = (sh - WINDOW_H) // 2
        self.geometry(f'{WINDOW_W}x{WINDOW_H}+{x}+{y}')

    # --------------------------------------------------------
    # UI 布局
    # --------------------------------------------------------
    def _setup_ui(self):
        self.grid_rowconfigure(0, weight=1)
        self.grid_columnconfigure(1, weight=1)

        self._build_sidebar()
        self._build_main()
        self._build_statusbar()

    def _build_sidebar(self):
        sidebar = ctk.CTkFrame(self, width=SIDEBAR_W, corner_radius=0)
        sidebar.grid(row=0, column=0, sticky='nsew')
        sidebar.grid_rowconfigure(3, weight=1)

        # Logo / 标题
        logo_frame = ctk.CTkFrame(sidebar, fg_color='transparent')
        logo_frame.grid(row=0, column=0, sticky='ew', padx=16, pady=(20, 10))
        ctk.CTkLabel(
            logo_frame, text='📄', font=('Segoe UI Emoji', 32)
        ).pack(side='left', padx=(0, 8))
        ctk.CTkLabel(
            logo_frame, text=APP_NAME,
            font=ctk.CTkFont(size=18, weight='bold'),
        ).pack(side='left')

        version_label = ctk.CTkLabel(
            sidebar, text=self.app_version,
            font=ctk.CTkFont(size=10),
            text_color=('gray50', 'gray60'),
            anchor='w',
        )
        version_label.grid(row=1, column=0, sticky='ew', padx=16, pady=(0, 16))

        # 分隔线
        sep = ctk.CTkFrame(sidebar, height=1, fg_color=('gray80', '#3a3a3a'))
        sep.grid(row=2, column=0, sticky='ew', padx=12)

        # 输出目录
        output_frame = ctk.CTkFrame(sidebar, fg_color='transparent')
        output_frame.grid(row=3, column=0, sticky='nsew', padx=12, pady=12)
        output_frame.columnconfigure(0, weight=1)

        ctk.CTkLabel(
            output_frame, text='输出目录',
            font=ctk.CTkFont(size=12, weight='bold'),
        ).grid(row=0, column=0, columnspan=2, sticky='w', pady=(0, 6))

        self.output_dir_var = ctk.StringVar(
            value=os.path.expanduser(r'~\Documents')
        )
        output_entry = ctk.CTkEntry(
            output_frame, textvariable=self.output_dir_var,
            placeholder_text='选择输出目录...',
            height=30,
        )
        output_entry.grid(row=1, column=0, sticky='ew')

        browse_btn = ctk.CTkButton(
            output_frame, text='📁', width=36, height=30,
            fg_color=('gray80', '#3a3a3a'), hover_color=('gray70', '#4a4a4a'),
            command=self._browse_output_dir,
        )
        browse_btn.grid(row=1, column=1, sticky='e', padx=(4, 0))

        # 选项
        options_frame = ctk.CTkFrame(sidebar, fg_color='transparent')
        options_frame.grid(row=4, column=0, sticky='ew', padx=12, pady=(0, 12))

        ctk.CTkLabel(
            options_frame, text='选项',
            font=ctk.CTkFont(size=12, weight='bold'),
        ).pack(anchor='w', pady=(0, 6))

        self.frontmatter_var = ctk.BooleanVar(value=True)
        ctk.CTkCheckBox(
            options_frame, text='包含 YAML Frontmatter',
            variable=self.frontmatter_var, onvalue=True, offvalue=False,
        ).pack(anchor='w', pady=2)

        self.plain_text_var = ctk.BooleanVar(value=False)
        ctk.CTkCheckBox(
            options_frame, text='纯文本模式（跳过 Markdown 后处理）',
            variable=self.plain_text_var, onvalue=True, offvalue=False,
        ).pack(anchor='w', pady=2)

        # 主题切换
        sep2 = ctk.CTkFrame(sidebar, height=1, fg_color=('gray80', '#3a3a3a'))
        sep2.grid(row=5, column=0, sticky='ew', padx=12, pady=(0, 0))

        theme_frame = ctk.CTkFrame(sidebar, fg_color='transparent')
        theme_frame.grid(row=6, column=0, sticky='ew', padx=12, pady=12)

        ctk.CTkLabel(theme_frame, text='主题', font=ctk.CTkFont(size=11)
        ).grid(row=0, column=0, sticky='w', pady=(0, 4))

        # 只创建一个 SegmentedButton，包含三个选项
        self.theme_var = ctk.StringVar(value='Dark')
        self.theme_btn = ctk.CTkSegmentedButton(
            theme_frame, values=['Light', 'Dark', 'System'],
            variable=self.theme_var, command=self._on_theme_change,
            width=190, height=32, font=ctk.CTkFont(size=12),
        )
        self.theme_btn.grid(row=1, column=0, sticky='w', padx=0)

        # 默认设置
        ctk.set_appearance_mode('dark')

        # 存储 sidebar 引用
        self.sidebar = sidebar
        self.version_label = version_label
        self.output_entry = output_entry

    def _build_main(self):
        main = ctk.CTkFrame(self, corner_radius=0)
        main.grid(row=0, column=1, sticky='nsew')
        main.grid_rowconfigure(2, weight=1)
        main.grid_columnconfigure(0, weight=1)

        # 工具栏
        toolbar = ctk.CTkFrame(main, height=48, corner_radius=0, fg_color='transparent')
        toolbar.grid(row=0, column=0, sticky='ew', padx=12, pady=(8, 4))
        toolbar.columnconfigure(0, weight=1)

        self.title_bar = ctk.CTkLabel(
            toolbar, text=f'{APP_NAME} - 文档转 Markdown 工具',
            font=ctk.CTkFont(size=14, weight='bold'),
        )
        self.title_bar.grid(row=0, column=0, sticky='w')

        self.action_btn = ctk.CTkButton(
            toolbar, text='🔄 开始转换', width=140, height=34,
            font=ctk.CTkFont(size=13, weight='bold'),
            command=self._start_conversion,
        )
        self.action_btn.grid(row=0, column=1, sticky='e', padx=(8, 0))

        self.clear_btn = ctk.CTkButton(
            toolbar, text='清空列表', width=90, height=34,
            fg_color=('gray80', '#3a3a3a'), hover_color=('gray70', '#4a4a4a'),
            command=self._clear_all,
        )
        self.clear_btn.grid(row=0, column=2, sticky='e', padx=(4, 0))

        # 拖拽区
        self.drop_zone = DropZone(
            main,
            on_files_dropped=self._on_files_dropped,
            height=140,
            corner_radius=10,
            border_width=1,
            border_color=('gray70', '#3a3a3a'),
        )
        self.drop_zone.grid(row=1, column=0, sticky='ew', padx=12, pady=6)

        # 文件列表
        self.file_list = FileListPanel(
            main,
            on_remove=self._on_remove_file,
            corner_radius=8,
            border_width=1,
            border_color=('gray80', '#2a2a2a'),
        )
        self.file_list.grid(row=2, column=0, sticky='nsew', padx=12, pady=6)

        # 诊断面板
        self.diag_panel = DiagPanel(
            main,
            height=120,
            corner_radius=8,
            border_width=1,
            border_color=('gray80', '#2a2a2a'),
        )
        self.diag_panel.grid(row=3, column=0, sticky='ew', padx=12, pady=(4, 8))

        self.main_frame = main

    def _build_statusbar(self):
        self.statusbar = ctk.CTkLabel(
            self, text='就绪',
            font=ctk.CTkFont(size=11),
            anchor='w',
            height=24,
            corner_radius=0,
        )
        self.statusbar.grid(row=1, column=0, columnspan=2, sticky='ew')

    # --------------------------------------------------------
    # 事件处理
    # --------------------------------------------------------
    def _on_files_dropped(self, paths: list[str]):
        """处理拖拽或选择进来的文件"""
        valid = [p for p in paths if is_supported(p)]
        if not valid:
            self._set_status('未找到支持的文件', 'warn')
            return
        self.file_list.add_files(valid)
        self._set_status(f'已添加 {len(valid)} 个文件（共 {len(self.file_list._files)} 个待转换）')
        if self.diag_panel:
            self.diag_panel.clear()
            self.diag_panel.append(f'已添加 {len(valid)} 个文件:', 'info')
            for p in valid:
                self.diag_panel.append(f'  + {os.path.basename(p)}', 'info')

    def _on_remove_file(self, index: int):
        self._set_status('已移除文件')

    def _browse_output_dir(self):
        dir_ = fd.askdirectory(title='选择输出目录')
        if dir_:
            self.output_dir_var.set(dir_)

    def _clear_all(self):
        self.file_list.clear()
        self.diag_panel.clear()
        self._set_status('列表已清空')

    def _on_theme_change(self, value: str):
        ctk.set_appearance_mode(value)

    def _start_conversion(self):
        if self.is_converting:
            return
        pending = self.file_list.get_pending()
        if not pending:
            self._set_status('请先添加要转换的文件', 'warn')
            return
        if not self.main_exe:
            self._set_status('未找到 main.exe，转换失败', 'error')
            return

        output_dir = self.output_dir_var.get()
        if not os.path.isdir(output_dir):
            self._set_status(f'输出目录无效: {output_dir}', 'error')
            return

        self.is_converting = True
        self.action_btn.configure(state='disabled', text='🔄 转换中...')
        self.clear_btn.configure(state='disabled')
        self._set_status(f'正在转换 {len(pending)} 个文件...')
        self.diag_panel.clear()
        self.diag_panel.append('=' * 40, 'info')
        self.diag_panel.append(f'开始转换 {len(pending)} 个文件', 'info')
        self.diag_panel.append(f'输出目录: {output_dir}', 'info')
        self.diag_panel.append('=' * 40, 'info')

        self._convert_next(pending, output_dir)

    def _convert_next(self, pending: list[dict], output_dir: str, index: int = 0):
        """递归处理每个待转换文件"""
        if index >= len(pending):
            # 全部完成
            self._conversion_done(len(pending))
            return

        f = pending[index]
        # 更新状态为 running
        file_idx = self.file_list._files.index(f)
        self.file_list.update_status(file_idx, 'running')

        self.diag_panel.append(f'\n[{index+1}/{len(pending)}] {os.path.basename(f["path"])}', 'info')

        def done_callback(result):
            from converter import ConversionResult
            # 使用 self.after 确保 UI 更新在主线程中执行
            self.after(0, lambda: self._on_conversion_done(result, pending, output_dir, index))

        import converter as conv_mod
        from converter import convert_file_async
        convert_file_async(
            input_path=f['path'],
            output_dir=output_dir,
            exe_path=self.main_exe,
            use_frontmatter=self.frontmatter_var.get(),
            use_plain_text=self.plain_text_var.get(),
            progress_callback=lambda s: self.after(0, lambda: self.diag_panel.append(f'  {s}', 'info')),
            done_callback=done_callback,
        )

    def _on_conversion_done(self, result, pending, output_dir, index):
        """在主线程中处理转换完成"""
        try:
            f = pending[index]
            success_idx = self.file_list._files.index(f)
            if result.success:
                self.file_list.update_status(success_idx, 'success', result)
                self.diag_panel.append(f'  ✅ 成功 -> {result.output_path}', 'success')
            else:
                self.file_list.update_status(success_idx, 'error', result)
                self.diag_panel.append(f'  ❌ 失败: {result.error}', 'error')
        except Exception as e:
            self.diag_panel.append(f'  ❌ 处理结果时出错: {str(e)}', 'error')
        
        # 下一个
        self._convert_next(pending, output_dir, index + 1)

        import converter as conv_mod
        from converter import convert_file_async
        convert_file_async(
            input_path=f['path'],
            output_dir=output_dir,
            exe_path=self.main_exe,
            use_frontmatter=self.frontmatter_var.get(),
            use_plain_text=self.plain_text_var.get(),
            progress_callback=lambda s: self.diag_panel.append(f'  {s}', 'info'),
            done_callback=done_callback,
        )

    def _conversion_done(self, total: int):
        self.is_converting = False
        self.action_btn.configure(state='normal', text='🔄 开始转换')
        self.clear_btn.configure(state='normal')
        self._set_status(f'✅ 全部完成！已成功转换 {total} 个文件')
        self.diag_panel.append(f'\n🎉 全部完成 ({total} 个文件)', 'success')

    def _set_status(self, msg: str, level: str = 'info'):
        icon = {'info': '', 'warn': '⚠️', 'error': '❌', 'success': '✅'}.get(level, '')
        self.statusbar.configure(text=f'{icon} {msg}'.strip())

    # --------------------------------------------------------
    # 快捷键
    # --------------------------------------------------------
    def _bind_shortcuts(self):
        self.bind('<F5>', lambda e: self._start_conversion())
        self.bind('<Control-o>', lambda e: self._browse_output_dir())
        self.bind('<Control-d>', lambda e: self._clear_all())

# ============================================================
# 入口
# ============================================================
def main():
    ctk.set_appearance_mode('dark')
    ctk.set_default_color_theme('blue')

    app = MoonBitMarkApp()
    app.mainloop()

if __name__ == '__main__':
    main()
