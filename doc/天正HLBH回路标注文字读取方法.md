# 天正 HLBH 回路标注文字读取方法
日期：2026-10-14
状态：方法记录

## 1. 目标与已知信息

本文记录如何从天正电气 `HLBH` 回路标注中提取编号文字（例如 `ZE1`），并提供用于 AutoCAD/天正命令行的 AutoLISP 调查代码。

项目历史实现调查确认，天正回路标注相关对象类型为 `TCH_WIREDIM2`，回路号可从对象 XData 的 `linenum` 字段读取。不同天正版本、代理对象状态或图纸转换方式可能影响 DXF 类型名及 XData 细节，因此代码先检查选中对象的原始 XData，再批量提取匹配 `linenum` 的值。若实际 XData 结构不同，应以 `TZXDUMP` 输出为准调整解析逻辑。

## 2. 工作原理

1. 用 `entget` 读取实体 DXF 数据；传入 `"*"` 请求返回所有注册应用的扩展数据。
2. 从返回数据中的 `-3` 项遍历各个 XData 应用记录。
3. 在 XData 的字符串组码 `1000` 中查找字段名 `linenum`，取其后一个字符串值作为编号，例如 `ZE1`。
4. 对整张图逐实体扫描，输出含有 `linenum` 的实体句柄、DXF 类型、应用名和编号。

这里的 `linenum` 解析假设其字段名和值以相邻的 DXF 组码 `1000` 保存。第一次运行应先用 `TZXDUMP` 核对真实图纸；不要把未核实的格式假设当作所有版本的固定格式。

## 3. AutoLISP 代码

将以下代码保存为严格 GB2312、无 BOM 的 `tzh_text_extract.lsp`。在 AutoCAD/天正中用 `APPLOAD` 加载，然后运行 `TZXDUMP` 检查单个已知标注，确认输出后运行 `TZTEXT` 扫描整张图。

```lisp
(vl-load-com)

;; 打印实体类型、句柄及所有 XData 原始内容，用于确认实际数据结构。
(defun c:TZXDUMP (/ ent data xdata)
  (setq ent (car (entsel "\n选择一个天正 HLBH 回路标注对象: ")))
  (if ent
    (progn
      (setq data (entget ent '("*")))
      (princ (strcat "\nDXF 类型: " (cdr (assoc 0 data))))
      (princ (strcat "\n句柄: " (cdr (assoc 5 data))))
      (setq xdata (assoc -3 data))
      (if xdata
        (progn
          (princ "\n全部 XData (-3):")
          (prin1 (cdr xdata))
        )
        (princ "\n未读取到 XData。")
      )
    )
    (princ "\n未选择对象。")
  )
  (princ)
)

;; 在单个 XData 应用记录中读取格式为 (1000 . "linenum") 后紧跟
;; (1000 . 编号文字) 的字段；返回 (应用名 编号文字)。
(defun TZ:ReadLineNum (app-record / app fields item next result)
  (setq app (car app-record)
        fields (cdr app-record))
  (while (and fields (not result))
    (setq item (car fields)
          next (cadr fields))
    (if (and (= (car item) 1000)
             (= (strcase (cdr item)) "LINENUM")
             next
             (= (car next) 1000)
             (/= (cdr next) ""))
      (setq result (list app (cdr next)))
    )
    (setq fields (cdr fields))
  )
  result
)

;; 遍历某实体的所有 XData 应用记录，找到首个 linenum 字段。
(defun TZ:EntityLineNum (ent / data xdata apps found)
  (setq data (entget ent '("*"))
        xdata (cdr (assoc -3 data)))
  (while (and xdata (not found))
    (setq found (TZ:ReadLineNum (car xdata))
          xdata (cdr xdata))
  )
  found
)

;; 扫描整个模型空间数据库；只输出实际含有 linenum 字段的实体。
(defun c:TZTEXT (/ ent data value count)
  (setq ent (entnext)
        count 0)
  (while ent
    (setq data (entget ent)
          value (TZ:EntityLineNum ent))
    (if value
      (progn
        (setq count (1+ count))
        (princ
          (strcat
            "\n句柄=" (if (assoc 5 data) (cdr (assoc 5 data)) "?")
            " 类型=" (if (assoc 0 data) (cdr (assoc 0 data)) "?")
            " 应用=" (car value)
            " 编号=" (cadr value)
          )
        )
      )
    )
    (setq ent (entnext ent))
  )
  (princ (strcat "\n扫描完成，找到 " (itoa count) " 个含 linenum 的实体。"))
  (princ)
)

(princ "\n已加载命令：TZXDUMP（检查单个实体 XData）、TZTEXT（扫描并提取编号）")
(princ)
```

## 4. 使用步骤

1. 在一张含有已知 `ZE1` 编号的 DWG 中运行 `APPLOAD`，加载 `tzh_text_extract.lsp`。
2. 运行 `TZXDUMP`，点选图面上显示 `ZE1` 的天正标注。
3. 检查命令行输出：DXF 类型应与天正标注相符；XData 中应能看到 `linenum` 及对应的编号值。若没有 `-3` XData 或字段结构不是相邻的两个 `1000`，先保留输出并按真实结构调整代码，不要直接认定编号不存在。
4. 运行 `TZTEXT`。命令会扫描当前图纸数据库，逐项打印实体句柄、DXF 类型、XData 应用名及编号。根据单对象检查结果确认输出的 `ZE1` 与图面标注一致。
5. 如需限定范围或只保留某些标注类型，可在 `TZTEXT` 扫描阶段增加图层、实体类型、包围盒等过滤；先不要仅凭 `TCH_WIREDIM2` 字符串做 `ssget` 类型过滤，因为代理实体的 DXF 组码 `0` 可能显示为其他名称。

## 5. 解析逻辑说明与限制

- `entget` 的应用列表参数使用 `'("*")` 以读取所有已注册应用的 XData；这样不需要预先猜测 XData 应用名。
- `TZ:ReadLineNum` 仅处理 `1000 linenum` 后紧跟 `1000 编号` 的结构。如果 `TZXDUMP` 显示编号存放在其他组码、嵌套结构或扩展字典中，应按实际数据结构另写解析分支。
- `TZTEXT` 扫描数据库实体，不只处理普通 `TEXT` / `MTEXT`，这可覆盖带 XData 的代理或自定义实体；但其匹配条件是 `linenum` 字段，需通过 `TZXDUMP` 验证这是目标标注的数据。
- 若天正对象只是代理图形且编号没有保存在可读取的 XData 中，AutoLISP 可能无法直接得到原生对象属性。此时需在装有相同天正版本的环境中查询其对象接口或通过天正命令/API读取，不能用图面 OCR 或近邻文字替代属性读取并宣称完全等价。
- 本代码只读，不修改实体、标注或 XData。批量用于业务前还应处理重复值、冲突值、空值及标注和回路导线的关联，不能把回路号当作稳定唯一 ID。

## 6. 项目历史实现线索

- `TCH_WIREDIM2`：项目历史调查中识别到的天正回路标注对象类型。
- `linenum`：项目历史实现读取的回路编号字段，如 `ZE1`。
- `src/circuit-number.lsp`：项目曾使用的回路号解析模块，从回路源导线段读取编号，并处理虚拟源句柄恢复、重复/冲突/缺失值、`ZE1...` 回退及已占用编号规避。
- `circuit-uid`：稳定回路身份；显示编号可能重复或变化，不应代替唯一身份。

## 7. 验证边界

上述对象类型和字段来自项目历史调查，不保证所有天正版本、图纸转换方式或代理对象采用完全相同的数据结构。正式集成前，应在目标 AutoCAD/天正版本的真实 DWG 上核对 `TZXDUMP` 输出，并验证保存、关闭、重开后的读取结果。AutoLISP 能打印 `ZE1` 只证明该图纸该对象的读取路径有效，不等于已完成所有版本兼容或原生 CAD 验收。

