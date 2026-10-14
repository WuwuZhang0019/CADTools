; 天正回路标注刷新探测，分别记录原生编辑前后的标注和关联导线。
; 日期：2026-10-14
; 命令：TZWIREDIM1、TZWIREDIM2。只读取图纸，不修改对象。
(vl-load-com)

(defun TZWD:Hex (number width / digits result)
  (setq digits "0123456789ABCDEF" result "")
  (while (> number 0)
    (setq result (strcat (substr digits (1+ (rem number 16)) 1) result)
          number (fix (/ number 16)))
  )
  (while (< (strlen result) width)
    (setq result (strcat "0" result))
  )
  result
)

; 旧版 AutoLISP 的非 ASCII 字符按原始代码页字节转义，日志本身保持 ASCII。
(defun TZWD:Ascii (value / result code)
  (setq result "")
  (foreach code (vl-string->list (vl-prin1-to-string value))
    (setq result
      (strcat result
        (if (and (>= code 32) (<= code 126))
          (chr code)
          (strcat "\\u" (TZWD:Hex code 4))
        )
      )
    )
  )
  result
)

(defun TZWD:Owner (data / app field refs wire)
  (setq refs nil)
  (foreach app (cdr (assoc -3 data))
    (if (equal (car app) "KeyOwnWireId")
      (foreach field (cdr app)
        (if (and (= (car field) 1005) (eq (type (cdr field)) 'STR))
          (setq refs (cons (cdr field) refs))
        )
      )
    )
  )
  (if (= (length refs) 1)
    (progn
      (setq wire (handent (car refs)))
      (if (and wire (equal (cdr (assoc 0 (entget wire))) "LWPOLYLINE"))
        wire
        nil
      )
    )
  )
)

(defun TZWD:MethodFlags (entity / obj method flags available)
  (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list entity)))
  (if (vl-catch-all-error-p obj)
    nil
    (progn
      (setq flags nil)
      (foreach method '(Update Regen Refresh Rebuild Recalculate SetText SetWireName)
        (setq available
          (vl-catch-all-apply 'vlax-method-applicable-p (list obj method)))
        (setq flags
          (cons (list method (if (vl-catch-all-error-p available) nil available)) flags))
      )
      (vlax-release-object obj)
      (reverse flags)
    )
  )
)

(defun TZWD:Snapshot (label / picked entity data wire)
  (setq picked (nentsel (strcat "\n点选" label "的天正回路标注: ")))
  (if picked
    (progn
      (setq entity (car picked)
            data (entget entity '("*")))
      (if (equal (cdr (assoc 0 data)) "TCH_WIREDIM2")
        (progn
          (setq wire (TZWD:Owner data))
          (if wire
            (list
              (cons 'target-handle (cdr (assoc 5 data)))
              (cons 'target-data data)
              (cons 'target-methods (TZWD:MethodFlags entity))
              (cons 'wire-handle (cdr (assoc 5 (entget wire))))
              (cons 'wire-data (entget wire '("*")))
            )
            (progn (princ "\n关联导线未确认。") nil)
          )
        )
        (progn (princ "\n所选对象不是 TCH_WIREDIM2。") nil)
      )
    )
  )
)

(defun TZWD:WriteSnapshot (stream title snapshot / pair)
  (write-line (strcat "=== " title " ===") stream)
  (foreach pair snapshot
    (write-line
      (strcat (vl-symbol-name (car pair)) " = " (TZWD:Ascii (cdr pair)))
      stream
    )
  )
)

(defun c:TZWIREDIM1 ()
  (setq *TZWD:Before* (TZWD:Snapshot "原生编辑前"))
  (if *TZWD:Before*
    (princ "\n已记录修改前状态。请在测试图副本中用天正界面编辑该标注或关联导线，确认图面文字变化，再运行 TZWIREDIM2。")
  )
  (princ)
)

(defun c:TZWIREDIM2 (/ after path stream)
  (if *TZWD:Before*
    (progn
      (setq after (TZWD:Snapshot "原生编辑后"))
      (if after
        (progn
          (setq path
            (getfiled "保存回路标注刷新对比日志"
              (strcat (getvar "DWGPREFIX") "TZWIREDIM-DIFF.txt") "txt" 1))
          (if path
            (progn
              (setq stream (open path "w"))
              (if stream
                (progn
                  (write-line "TZWIREDIM before/after; ASCII escaped output" stream)
                  (write-line (strcat "acadver = " (TZWD:Ascii (getvar "ACADVER"))) stream)
                  (write-line (strcat "dwgname = " (TZWD:Ascii (getvar "DWGNAME"))) stream)
                  (TZWD:WriteSnapshot stream "BEFORE" *TZWD:Before*)
                  (TZWD:WriteSnapshot stream "AFTER" after)
                  (close stream)
                  (princ (strcat "\n对比日志已保存: " path))
                )
                (princ "\n无法写入日志文件。")
              )
            )
          )
        )
      )
    )
    (princ "\n请先运行 TZWIREDIM1。")
  )
  (princ)
)

(princ "\n已加载 TZWIREDIM1 / TZWIREDIM2，只读记录天正回路标注原生编辑前后状态。")
(princ)
