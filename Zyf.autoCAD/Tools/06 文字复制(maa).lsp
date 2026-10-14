; 文字复制命令 maa
; 日期：2026-10-14
; 天正目标对象只使用已探测到的公开 COM 属性；不对自定义对象调用 entmod。
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

; 引线标注的两个文字字段位于 TDbSymbMultiLeader 子类。
(defun MAA:LeaderText (data / active upper lower part)
  (setq active nil upper nil lower nil)
  (foreach part data
    (cond
      ((= (car part) 100)
        (setq active (equal (cdr part) "TDbSymbMultiLeader")))
      ((and active (= (car part) 1)) (setq upper (cdr part)))
      ((and active (= (car part) 2)) (setq lower (cdr part)))
    )
  )
  (if (and (eq (type upper) 'STR) (eq (type lower) 'STR))
    (cond
      ((equal upper "") lower)
      ((equal lower "") upper)
      (T (strcat upper (chr 13) (chr 10) lower))
    )
  )
)

; 普通 MTEXT 用 \P 表示换行；天正组码 1 的 CRLF 不能原样写入。
(defun MAA:MTextValue (value / i n ch out)
  (setq i 1 n (strlen value) out "")
  (while (<= i n)
    (setq ch (substr value i 1))
    (cond
      ((= ch (chr 13))
        (setq out (strcat out "\\P"))
        (if (and (< i n) (= (substr value (1+ i) 1) (chr 10)))
          (setq i (1+ i))
        )
      )
      ((= ch (chr 10)) (setq out (strcat out "\\P")))
      (T (setq out (strcat out ch)))
    )
    (setq i (1+ i))
  )
  out
)

; 天正单行文字只通过其公开 Text 属性写入，写后核对 COM 和 DXF。
(defun MAA:WriteTchText (entity value / obj before result after data success)
  (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list entity)))
  (cond
    ((vl-catch-all-error-p obj) nil)
    ((not (vlax-property-available-p obj 'Text T))
      (vlax-release-object obj)
      nil)
    (T
      (setq before (vl-catch-all-apply 'vlax-get-property (list obj 'Text)))
      (if (vl-catch-all-error-p before)
        (setq result nil)
        (progn
          (setq result (vl-catch-all-apply 'vlax-put-property (list obj 'Text value)))
          (if (not (vl-catch-all-error-p result))
            (progn
              (vl-catch-all-apply 'vla-update (list obj))
              (setq after (vl-catch-all-apply 'vlax-get-property (list obj 'Text))
                    data (entget entity))
              (if (and (equal after value)
                       (equal (cdr (assoc 1 data)) value))
                (setq success T)
                (progn
                  (vl-catch-all-apply 'vlax-put-property (list obj 'Text before))
                  (vl-catch-all-apply 'vla-update (list obj))
                )
              )
            )
          )
        )
      )
      (vlax-release-object obj)
      (if success T nil)
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
    ((equal kind "TCH_MULTILEADER")
      (MAA:LeaderText data))
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
                 target-data target-kind old-text result readback write-text)
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
                ((not (member target-kind '("TEXT" "MTEXT" "ATTRIB" "TCH_TEXT")))
                  (princ "\n天正或其他自定义目标尚无已验证的安全写入接口，未修改图纸。"))
                ((not old-text)
                  (princ "\n目标没有 DXF 组码 1，未修改图纸。"))
                ((and (equal target-kind "MTEXT") (assoc 3 target-data))
                  (princ "\n目标多行文字含分段组码 3，暂不写入以免残留旧内容。"))
                ((and (not (equal target-kind "MTEXT"))
                      (or (vl-string-search "\n" source-text)
                          (vl-string-search "\r" source-text)))
                  (princ "\n多行内容不能写入单行目标，未修改图纸。"))
                ((equal target-kind "TCH_TEXT")
                  (if (MAA:WriteTchText target source-text)
                    (princ "\n文字复制完成。")
                    (princ "\n天正单行文字写入或读回校验失败，请检查目标文字。")
                  )
                )
                (T
                  (setq write-text
                    (if (equal target-kind "MTEXT")
                      (MAA:MTextValue source-text)
                      source-text))
                  (setq result
                    (vl-catch-all-apply 'entmod
                      (list (subst (cons 1 write-text) old-text target-data))))
                  (if (or (vl-catch-all-error-p result) (null result))
                    (princ "\n普通文字写入失败，目标未确认更新。")
                    (progn
                      (setq readback (entget target))
                      (if (equal (cdr (assoc 1 readback)) write-text)
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
