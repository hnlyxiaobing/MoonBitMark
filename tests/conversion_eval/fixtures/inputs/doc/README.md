# DOC fixtures

Word 97-2003 二进制（`.doc`）与 WPS Writer 二进制（`.wps`）样本，供 `doc_*` eval case
使用。

这些文件是**手工合成的 OLE2/CFB 容器**，不是任何上游语料的拷贝，因此没有对应的
remote 基准条目，也不出现在 `source_manifest.json` 中。同样因为它们不是抓取产物，
生成脚本没有保留在仓库里。

白盒测试（`src/formats/doc/converter_wbtest.mbt`）里另有同类的 base64 内嵌样本
（`word_english_b64` / `word95_b64` / `word_multipiece_b64` 等），用于在无文件系统
IO 的前提下驱动 `convert_bytes`。

覆盖的场景：

- `word_english.doc` / `word_multipiece.doc` / `word95.doc`：标题、段落、列表、pipe 表格
- `word_chinese.doc` / `wps_chinese.wps`：UTF-16LE piece（中文）
- `word_encrypted.doc`：加密文档，应被拒绝
- `corrupt_magic.doc` / `truncated.doc` / `word_empty.doc`：损坏 / 截断 / 空输入

如需替换或新增样本，请用 Word/WPS 另存为 `.doc` / `.wps`，或自行构造
CFB + FIB + piece table。
