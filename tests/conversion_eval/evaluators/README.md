# Evaluators

建议按下面顺序实现：

1. `normalize/`
   - 换行统一
   - 空白折叠
   - markdown 轻量归一

2. `anchors/`
   - must_include
   - must_not_include
   - min_chars / min_lines

3. `metrics/`
   - markdown similarity
   - NID / normalized Levenshtein
   - 聚合得分

4. `ast_compare/`
   - block type sequence
   - heading level
   - inline semantics
   - 文本相似度

5. `table_compare/`
   - 行列数
   - 表头
   - 关键单元格
