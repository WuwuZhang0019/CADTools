; 文字复制命令 maa
; 日期：2026-10-14
; 天正目标只在公开 COM 属性与 DXF 字段对应时写入，不对自定义对象调用 entmod。
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

; 统一识别 CRLF/LF 与普通 MTEXT 的 \P，避免把多行内容写入单行目标。
(defun MAA:Lines (value / i n ch next current lines)
  (setq i 1 n (strlen value) current "" lines nil)
  (while (<= i n)
    (setq ch (substr value i 1)
          next (if (< i n) (substr value (1+ i) 1) ""))
    (cond
      ((equal ch (chr 13))
        (setq lines (cons current lines) current "")
        (if (equal next (chr 10)) (setq i (1+ i)))
      )
      ((equal ch (chr 10))
        (setq lines (cons current lines) current "")
      )
      ((and (equal ch "\\") (equal next "P"))
        (setq lines (cons current lines) current "" i (1+ i))
      )
      ((and (equal ch "\\") (equal next "\\"))
        (setq current (strcat current ch next) i (1+ i))
      )
      (T (setq current (strcat current ch)))
    )
    (setq i (1+ i))
  )
  (reverse (cons current lines))
)

(defun MAA:TchMTextValue (value / lines result line)
  (setq lines (MAA:Lines value) result (car lines))
  (foreach line (cdr lines)
    (setq result (strcat result (chr 13) (chr 10) line))
  )
  result
)

; 普通 MTEXT 用 \P 表示换行；天正组码 1 的 CRLF 不能原样写入。
(defun MAA:MTextValue (value / i n ch out)
  (setq i 1 n (strlen value) out "")
  (while (<= i n)
    (setq ch (substr value i 1))
    (cond
      ((equal ch (chr 13))
        (setq out (strcat out "\\P"))
        (if (and (< i n) (= (substr value (1+ i) 1) (chr 10)))
          (setq i (1+ i))
        )
      )
      ((equal ch (chr 10)) (setq out (strcat out "\\P")))
      (T (setq out (strcat out ch)))
    )
    (setq i (1+ i))
  )
  out
)

; COM 属性写前必须与已读 DXF 字段相同；写后核对 COM 与 DXF，失败则恢复。
(defun MAA:WriteComText (entity prop value old-text / obj writable before result after data success)
  (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list entity)))
  (if (not (vl-catch-all-error-p obj))
    (progn
      (setq writable
        (vl-catch-all-apply 'vlax-property-available-p (list obj prop T)))
      (if (eq writable T)
        (progn
          (setq before (vl-catch-all-apply 'vlax-get-property (list obj prop)))
          (if (equal before old-text)
            (progn
              (setq result
                (vl-catch-all-apply 'vlax-put-property (list obj prop value)))
              (if (not (vl-catch-all-error-p result))
                (progn
                  (vl-catch-all-apply 'vla-update (list obj))
                  (setq after (vl-catch-all-apply 'vlax-get-property (list obj prop))
                        data (vl-catch-all-apply 'entget (list entity)))
                  (if (and (equal after value)
                           (not (vl-catch-all-error-p data))
                           (equal (cdr (assoc 1 data)) value))
                    (setq success T)
                  )
                )
              )
              (if (not success)
                (progn
                  (vl-catch-all-apply 'vlax-put-property (list obj prop before))
                  (vl-catch-all-apply 'vla-update (list obj))
                )
              )
            )
          )
        )
      )
      (vlax-release-object obj)
    )
  )
  (if success T nil)
)

; 引线的上下文字分别对应 UpText/DownText；两项都可写才修改。
(defun MAA:WriteLeader (entity data lines / obj up down before-up before-down
                        result after-up after-down readback success new-up new-down)
  (if (and (<= (length lines) 2)
           (assoc 1 data) (assoc 2 data))
    (progn
      (setq new-up (car lines)
            new-down (if (cadr lines) (cadr lines) "")
            obj (vl-catch-all-apply 'vlax-ename->vla-object (list entity)))
      (if (not (vl-catch-all-error-p obj))
        (progn
          (setq up (vl-catch-all-apply 'vlax-property-available-p (list obj 'UpText T))
                down (vl-catch-all-apply 'vlax-property-available-p (list obj 'DownText T)))
          (if (and (eq up T) (eq down T))
            (progn
              (setq before-up (vl-catch-all-apply 'vlax-get-property (list obj 'UpText))
                    before-down (vl-catch-all-apply 'vlax-get-property (list obj 'DownText)))
              (if (and (equal before-up (cdr (assoc 1 data)))
                       (equal before-down (cdr (assoc 2 data))))
                (progn
                  (setq result
                    (vl-catch-all-apply 'vlax-put-property (list obj 'UpText new-up)))
                  (if (not (vl-catch-all-error-p result))
                    (setq result
                      (vl-catch-all-apply 'vlax-put-property (list obj 'DownText new-down)))
                  )
                  (if (not (vl-catch-all-error-p result))
                    (progn
                      (vl-catch-all-apply 'vla-update (list obj))
                      (setq after-up (vl-catch-all-apply 'vlax-get-property (list obj 'UpText))
                            after-down (vl-catch-all-apply 'vlax-get-property (list obj 'DownText))
                            readback (vl-catch-all-apply 'entget (list entity)))
                      (if (and (equal after-up new-up) (equal after-down new-down)
                               (not (vl-catch-all-error-p readback))
                               (equal (cdr (assoc 1 readback)) new-up)
                               (equal (cdr (assoc 2 readback)) new-down))
                        (setq success T)
                      )
                    )
                  )
                  (if (not success)
                    (progn
                      (vl-catch-all-apply 'vlax-put-property (list obj 'UpText before-up))
                      (vl-catch-all-apply 'vlax-put-property (list obj 'DownText before-down))
                      (vl-catch-all-apply 'vla-update (list obj))
                    )
                  )
                )
              )
            )
          )
          (vlax-release-object obj)
        )
      )
    )
  )
  (if success T nil)
)

; 不猜测天正多行文字的接口：候选属性读值须与 DXF 组码 1 完全相同。
(defun MAA:WriteTchMText (entity data value / candidates prop obj writable before chosen)
  (setq candidates '(MText MTextContent TextContent Contents Content TextString Text)
        obj (vl-catch-all-apply 'vlax-ename->vla-object (list entity)))
  (if (not (vl-catch-all-error-p obj))
    (progn
      (foreach prop candidates
        (if (not chosen)
          (progn
            (setq writable
              (vl-catch-all-apply 'vlax-property-available-p (list obj prop T)))
            (if (eq writable T)
              (progn
                (setq before (vl-catch-all-apply 'vlax-get-property (list obj prop)))
                (if (equal before (cdr (assoc 1 data)))
                  (setq chosen prop)
                )
              )
            )
          )
        )
      )
      (vlax-release-object obj)
    )
  )
  (if chosen
    (MAA:WriteComText entity chosen value (cdr (assoc 1 data)))
    nil
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
                 target-data target-kind old-text result readback write-text lines)
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
                    old-text (assoc 1 target-data)
                    lines (MAA:Lines source-text))
              (cond
                ((not (member target-kind '("TEXT" "MTEXT" "ATTRIB" "TCH_TEXT" "TCH_MTEXT" "TCH_MULTILEADER")))
                  (princ "\n天正或其他自定义目标尚无已验证的安全写入接口，未修改图纸。"))
                ((not old-text)
                  (princ "\n目标没有 DXF 组码 1，未修改图纸。"))
                ((and (equal target-kind "TCH_MULTILEADER")
                      (not (assoc 2 target-data)))
                  (princ "\n引线目标缺少下方文字字段，未修改图纸。"))
                ((and (equal target-kind "MTEXT") (assoc 3 target-data))
                  (princ "\n目标多行文字含分段组码 3，暂不写入以免残留旧内容。"))
                ((and (member target-kind '("TEXT" "ATTRIB" "TCH_TEXT"))
                      (> (length lines) 1))
                  (princ "\n多行内容不能写入单行目标，未修改图纸。"))
                ((equal target-kind "TCH_TEXT")
                  (if (MAA:WriteComText target 'Text source-text (cdr old-text))
                    (princ "\n文字复制完成。")
                    (princ "\n天正单行文字接口不可用或读回校验失败，请检查目标文字。")
                  )
                )
                ((equal target-kind "TCH_MULTILEADER")
                  (if (MAA:WriteLeader target target-data lines)
                    (princ "\n文字复制完成。")
                    (princ "\n引线文字接口不可用、超过两行或读回校验失败，未确认更新。")
                  )
                )
                ((equal target-kind "TCH_MTEXT")
                  (if (MAA:WriteTchMText target target-data
                        (MAA:TchMTextValue source-text))
                    (princ "\n文字复制完成。")
                    (princ "\n天正多行文字没有可核对的公开写入属性，未确认更新。")
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
