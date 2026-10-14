; 文字复制命令 maa
; 日期：2026-10-14
; 天正目标对象的安全写入接口未核实前，禁止对其调用 entmod。
(vl-load-com)

; 从回路标注的 KeyOwnWireId 只读关联导线上的 linenum。
(defun MAA:WireText (data / apps app field refs linked wire-data nums value)
  (setq apps (cdr (assoc -3 data)) refs nil nums nil)
  (foreach app apps
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
      (setq linked (handent (car refs)))
      (if linked
        (progn
          (setq wire-data (entget linked '("*")))
          (foreach app (cdr (assoc -3 wire-data))
            (if (equal (strcase (car app)) "LINENUM")
              (setq nums (cons app nums))
            )
          )
          (if (= (length nums) 1)
            (progn
              (setq value (cdr (assoc 1000 (cdr (car nums)))))
              (if (eq (type value) 'STR) value nil)
            )
          )
        )
      )
    )
  )
)

(defun MAA:SourceText (data / kind part text)
  (setq kind (cdr (assoc 0 data)))
  (cond
    ((member kind '("TEXT" "ATTRIB" "TCH_TEXT" "TCH_MTEXT"))
      (cdr (assoc 1 data)))
    ((equal kind "TCH_WIREDIM2")
      (MAA:WireText data))
    ((equal kind "MTEXT")
      (setq text "")
      (foreach part data
        (if (and (member (car part) '(1 3)) (eq (type (cdr part)) 'STR))
          (setq text (strcat text (cdr part)))
        )
      )
      text)
    (T nil)
  )
)

(defun c:maa (/ source-pick source-data source-text target-pick target
                 target-data target-kind old-text result readback)
  (setq source-pick (nentsel "\n选择源文字: "))
  (if source-pick
    (progn
      (setq source-data (entget (car source-pick) '("*"))
            source-text (MAA:SourceText source-data))
      (if (not (eq (type source-text) 'STR))
        (princ "\n源对象的文字字段尚未确认，未修改图纸。")
        (progn
          (setq target-pick (nentsel "\n选择目标文字: "))
          (if target-pick
            (progn
              (setq target (car target-pick)
                    target-data (entget target)
                    target-kind (cdr (assoc 0 target-data))
                    old-text (assoc 1 target-data))
              (cond
                ((not (member target-kind '("TEXT" "MTEXT" "ATTRIB")))
                  (princ "\n天正或其他自定义目标尚无已验证的安全写入接口，未修改图纸。"))
                ((not old-text)
                  (princ "\n目标没有 DXF 组码 1，未修改图纸。"))
                ((and (equal target-kind "MTEXT") (assoc 3 target-data))
                  (princ "\n目标多行文字含分段组码 3，暂不写入以免残留旧内容。"))
                ((and (not (equal target-kind "MTEXT"))
                      (or (vl-string-search "\n" source-text)
                          (vl-string-search "\r" source-text)))
                  (princ "\n多行内容不能写入单行目标，未修改图纸。"))
                (T
                  (setq result
                    (vl-catch-all-apply 'entmod
                      (list (subst (cons 1 source-text) old-text target-data))))
                  (if (or (vl-catch-all-error-p result) (null result))
                    (princ "\n普通文字写入失败，目标未确认更新。")
                    (progn
                      (setq readback (entget target))
                      (if (equal (cdr (assoc 1 readback)) source-text)
                        (progn (entupd target) (princ "\n文字复制完成。"))
                        (princ "\n写入后读取不一致，请检查目标文字。"))
                    )
                  )
                )
              )
            )
            (princ "\n已取消目标选择。")
          )
        )
      )
    )
    (princ "\n已取消源文字选择。")
  )
  (princ)
)

(c:maa)
(princ)
