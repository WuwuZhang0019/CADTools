; 文字复制源目标类型核对，仅用于诊断，不修改图纸。
; 日期：2026-10-14
; APPLOAD 后运行 MAATYPES，按实际复制顺序点选源和目标。

(defun MAATYPES:Value (data code / item)
  (setq item (assoc code data))
  (if (and item (eq (type (cdr item)) 'STR))
    (cdr item)
    "?"
  )
)

(defun c:MAATYPES (/ source-pick target-pick source-data target-data source-kind target-kind)
  (setq source-pick (nentsel "\n选择标注内的源文字: "))
  (if source-pick
    (progn
      (setq source-data (entget (car source-pick))
            source-kind (MAATYPES:Value source-data 0))
      (setq target-pick (nentsel "\n选择外面的目标文字: "))
      (if target-pick
        (progn
          (setq target-data (entget (car target-pick))
                target-kind (MAATYPES:Value target-data 0))
          (princ (strcat "\n源类型=" source-kind
                         " 句柄=" (MAATYPES:Value source-data 5)))
          (princ (strcat "\n目标类型=" target-kind
                         " 句柄=" (MAATYPES:Value target-data 5)))
          (princ "\n按类型预计的目标处理分支: ")
          (cond
            ((member target-kind '("TCH_MTEXT" "TCH_WIREDIM2"))
              (princ "不支持此种操作"))
            ((and (equal source-kind "TCH_MULTILEADER")
                  (equal target-kind "TCH_TEXT"))
              (princ "不支持此种操作"))
            ((equal target-kind "TCH_TEXT")
              (princ "天正单行 COM Text 写入"))
            ((equal target-kind "TCH_MULTILEADER")
              (princ "天正引线 COM 属性写入"))
            ((member target-kind '("TEXT" "MTEXT" "ATTRIB"))
              (princ "普通文字 entmod 写入"))
            (T (princ "其他或不支持的对象"))
          )
          (princ "\nMAATYPES 只读检查完成，图纸未修改。")
        )
        (princ "\n已取消目标选择。")
      )
    )
    (princ "\n已取消源选择。")
  )
  (princ)
)

(princ "\n类型核对脚本已加载，输入 MAATYPES。")
(princ)
