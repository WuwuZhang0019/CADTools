; 天正回路标注 COM 接口探测，只读取，不修改图纸。
; 日期：2026-10-14
; APPLOAD 加载后自动运行一次；按 F2 从文本窗口复制输出。
(vl-load-com)

(defun c:TZWIREDIMCOM (/ picked data obj result)
  (setq picked (nentsel "\n点选天正回路标注: "))
  (if picked
    (progn
      (setq data (entget (car picked)))
      (if (equal (cdr (assoc 0 data)) "TCH_WIREDIM2")
        (progn
          (setq obj (vl-catch-all-apply
                      'vlax-ename->vla-object (list (car picked))))
          (if (and obj (not (vl-catch-all-error-p obj)))
            (progn
              (princ "\n=== TZWIREDIMCOM BEGIN ===")
              (setq result (vl-catch-all-apply 'vlax-dump-object (list obj T)))
              (if (vl-catch-all-error-p result)
                (princ (strcat "\n接口枚举失败: "
                  (vl-catch-all-error-message result)))
              )
              (princ "\n=== TZWIREDIMCOM END ===")
              (vlax-release-object obj)
            )
            (princ "\n无法访问 COM 对象。")
          )
        )
        (princ "\n所选对象不是 TCH_WIREDIM2。")
      )
    )
    (princ "\n已取消选择。")
  )
  (princ)
)

(princ "\n已加载 TZWIREDIMCOM，现在请点选回路标注。")
(c:TZWIREDIMCOM)
(princ)
