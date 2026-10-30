# 秒算虾料软件（鸿蒙版）软著申请材料

本目录按安卓项目 `D:\mixcalc-lab\copyright` 的结构整理，用于“秒算虾料软件（鸿蒙版）V0.1”的软件著作权登记。

## 当前文件

| 文件 | 说明 |
| --- | --- |
| `docs/03_申请表填写信息.md` | 申请表逐项填写信息（脱敏版，敏感信息不写入仓库） |
| `docs/04_材料清单与避坑.md` | 材料清单、打印装订、提交前检查、常见坑 |
| `docs/05_软件说明书.md` | 软件说明书正文，13 章，可转 PDF |
| `tools/collect_stats.py` | 统计 ArkTS/配置文件行数 |
| `tools/build_source_pdf.py` | 生成 60 页源程序 PDF（前 30 页 + 后 30 页） |
| `output/01_源程序_秒算虾料软件（鸿蒙版）V0.1.pdf` | 已生成，60 页；未提交 Git |

## 关键口径

- 软件全称：**秒算虾料软件（鸿蒙版）**
- 版本号：**V0.1**
- 著作权人：**夏卫兵**
- 开发完成日期：**2026-10-30**
- 首次发表：**未发表**
- 包名：`com.shrimpfarm.mixcalc`
- 源程序：9 个 `.ets` + 10 个 JSON/JSON5 配置，共 19 个文件
- 原始物理行：**3992**
- 原始非空行：**3721**（建议填申请表）
- 剔除注释后非空代码：**3617**
- 源程序 PDF：**60 页**，每页 50 行，前 30 页 + 后 30 页

## 生成源程序 PDF

```powershell
& 'C:\Users\Administrator\AppData\Local\Programs\Python\Python313-arm64\python.exe' `
  D:\mixcalc-harmony\copyright\tools\build_source_pdf.py
```

检查 `copyright/build/source_report.json`：

- `submitted_pages` 应为 60；
- `overflow_lines` 应为空；
- `missing_glyphs` 应为空。

## 说明书 PDF

正文已写在 `docs/05_软件说明书.md`，共 13 章。生成 PDF 时要求：

- 封面、页眉、第 13 章版本表统一为“秒算虾料软件（鸿蒙版）V0.1”；
- 页眉含软件名称、版本、页码；
- 截图使用鸿蒙版实际界面，不混用安卓截图；
- 目录页码与正文一致。

## 敏感信息

身份证号、住址、邮编、电话、邮箱**不写入本目录的公开文件**。提交时从私密材料复制到中国版权保护中心系统；不要把 `03` 的私密版、身份证照片、`output/` PDF 提交到公开仓库或公开网盘。

## Git 跟踪

- `docs/` 和 `tools/` 可以提交；
- `copyright/build/`、`copyright/output/` 已在 `.gitignore` 中忽略，避免 PDF、报告和个人材料误提交。
