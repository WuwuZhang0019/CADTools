; 图号文字递增 V2.1 独立测试版
; 测试命令：THDZTEST；APPLOAD 加载后输入该命令开始测试。
; 日期：2026-11-03
; 保留任意长度的专业前缀和数字，施转变后按 A、B 至 Z、AA、AB 递增。

; 从末尾识别字母、数字和阶段，不依赖中文占一个字符还是两个字节。
(defun THDZTEST:Parse (text / end number-end revision code marker marker-length)
  (if (and (eq (type text) 'STR) (> (strlen text) 0))
    (progn
      (setq end (strlen text)
            revision "")
      (while (and (> end 0)
                  (setq code (ascii (substr text end 1)))
                  (>= code 65) (<= code 90))
        (setq revision (strcat (substr text end 1) revision)
              end (1- end))
      )
      (setq number-end end)
      (while (and (> end 0)
                  (setq code (ascii (substr text end 1)))
                  (>= code 48) (<= code 57))
        (setq end (1- end))
      )
      (setq marker (if (equal revision "") "施-" "变-")
            marker-length (strlen marker))
      (if (and (< end number-end)
               (> end marker-length)
               (equal (substr text (1+ (- end marker-length)) marker-length)
                      marker))
        (list (substr text 1 (- end marker-length))
              (substr text (1+ end) (- number-end end))
              revision)
      )
    )
  )
)

; 按字母进位：Z -> AA，AZ -> BA，ZZ -> AAA；空后缀从 A 开始。
(defun THDZTEST:NextRevision (revision / index code result carry)
  (setq index (strlen revision)
        result ""
        carry T)
  (while (> index 0)
    (setq code (ascii (substr revision index 1)))
    (if carry
      (if (= code 90)
        (setq code 65)
        (setq code (1+ code)
              carry nil)
      )
    )
    (setq result (strcat (chr code) result)
          index (1- index))
  )
  (if carry (strcat "A" result) result)
)

(defun THDZTEST:NextText (text / parts)
  (if (setq parts (THDZTEST:Parse text))
    (strcat (car parts) "变-" (cadr parts)
            (THDZTEST:NextRevision (caddr parts)))
  )
)

(defun c:thdztest (/ *error* pick entity data kind old-text new-text)
  (defun *error* (message)
    (if (and message
             (not (member (strcase message)
                          '("FUNCTION CANCELLED" "QUIT / EXIT ABORT" "CONSOLE BREAK"))))
      (princ (strcat "\n图号递增中断: " message))
    )
    (princ)
  )
  (princ "\n图号文字递增 V2.1 测试版 [THDZTEST] (2026-11-03)")
  (setq pick (entsel "\n选择图号文字，按 Enter 或 Esc 退出: "))
  (if pick
    (progn
      (setq entity (car pick)
            data (entget entity)
            kind (cdr (assoc 0 data))
            old-text (assoc 1 data))
      (cond
        ((not (member kind '("TEXT" "MTEXT" "ATTRIB")))
          (princ "\n请选择普通文字、多行文字或属性文字。"))
        ((and (equal kind "MTEXT") (assoc 3 data))
          (princ "\n该多行文字包含分段内容，请使用独立的图号文字。"))
        ((not (setq new-text (THDZTEST:NextText (cdr old-text))))
          (princ "\n图号格式不支持，请使用如电施-01、电装施-001或建变-01A的格式。"))
        ((entmod (subst (cons 1 new-text) old-text data))
          (entupd entity)
          (princ (strcat "\n" (cdr old-text) " -> " new-text)))
        (T
          (princ "\n图号写入失败，请检查对象或图层是否允许修改。"))
      )
    )
  )
  (princ)
)

; 加载时仅注册测试命令，不立即选择或修改对象。
(princ "\n图号文字递增 V2.1 测试版已加载，输入 THDZTEST 开始测试。")
(princ)
