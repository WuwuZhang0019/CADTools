; 图号文字递增、递减 V2.2
; 日期：2026-11-03
; THDZ 递增，THDJ 递减；保留专业前缀、前导零及已有字母的大小写。

; 从末尾识别同一大小写的字母、数字和阶段，兼容中文字符及旧版字节索引。
(defun THDZ:Parse (text / end number-end revision code marker marker-length)
  (if (and (eq (type text) 'STR) (> (strlen text) 0))
    (progn
      (setq end (strlen text)
            revision "")
      (while (and (> end 0)
                  (setq code (ascii (substr text end 1)))
                  (or (and (>= code 65) (<= code 90))
                      (and (>= code 97) (<= code 122))))
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
               (or (equal revision (strcase revision))
                   (equal revision (strcase revision T)))
               (equal (substr text (1+ (- end marker-length)) marker-length)
                      marker))
        (list (substr text 1 (- end marker-length))
              (substr text (1+ end) (- number-end end))
              revision)
      )
    )
  )
)

; 空后缀默认从 A 开始；Z -> AA、z -> aa，保留已有后缀的大小写。
(defun THDZ:NextRevision (revision / index code result carry base)
  (setq index (strlen revision)
        result ""
        carry T
        base (if (and (> index 0) (>= (ascii revision) 97)) 97 65))
  (while (> index 0)
    (setq code (ascii (substr revision index 1)))
    (if carry
      (if (= code (+ base 25))
        (setq code base)
        (setq code (1+ code)
              carry nil)
      )
    )
    (setq result (strcat (chr code) result)
          index (1- index))
  )
  (if carry (strcat (chr base) result) result)
)

; AA -> Z、aa -> z；A 或 a 返回空后缀，由文字转换逻辑还原为施。
(defun THDZ:PreviousRevision (revision / index code result borrow base)
  (if (> (strlen revision) 0)
    (progn
      (setq index (strlen revision)
            result ""
            borrow T
            base (if (>= (ascii revision) 97) 97 65))
      (while (> index 0)
        (setq code (ascii (substr revision index 1)))
        (if borrow
          (if (= code base)
            (setq code (+ base 25))
            (setq code (1- code)
                  borrow nil)
          )
        )
        (setq result (strcat (chr code) result)
              index (1- index))
      )
      (if borrow
        (if (> (strlen result) 1) (substr result 2) "")
        result)
    )
  )
)

(defun THDZ:NextText (text / parts)
  (if (setq parts (THDZ:Parse text))
    (strcat (car parts) "变-" (cadr parts)
            (THDZ:NextRevision (caddr parts)))
  )
)

(defun THDZ:PreviousText (text / parts revision)
  (if (setq parts (THDZ:Parse text))
    (if (equal (caddr parts) "")
      text
      (progn
        (setq revision (THDZ:PreviousRevision (caddr parts)))
        (strcat (car parts) (if (equal revision "") "施-" "变-")
                (cadr parts) revision)
      )
    )
  )
)

(defun THDZ:Run (direction / *error* label pick entity data kind old-text new-text)
  (defun *error* (message)
    (if (and message
             (not (member (strcase message)
                          '("FUNCTION CANCELLED" "QUIT / EXIT ABORT" "CONSOLE BREAK"))))
      (princ (strcat "\n图号" label "中断: " message))
    )
    (princ)
  )
  (setq label (if (< direction 0) "递减" "递增"))
  (princ (strcat "\n图号文字" label " V2.2 (2026-11-03)"))
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
        ((not (setq new-text (if (< direction 0)
                               (THDZ:PreviousText (cdr old-text))
                               (THDZ:NextText (cdr old-text)))))
          (princ "\n图号格式不支持，请使用如电施-01、电装变-001A或建变-01a的格式；后缀大小写须一致。"))
        ((equal new-text (cdr old-text))
          (princ "\n当前图号尚未变更，已是施图编号，未修改图号。"))
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

(defun c:thdz () (THDZ:Run 1))
(defun c:thdj () (THDZ:Run -1))

; 加载时仅注册命令，由菜单入口或用户调用对应方向，避免重复执行。
(princ "\n图号文字递增、递减 V2.2 已加载：THDZ 递增，THDJ 递减。")
(princ)
