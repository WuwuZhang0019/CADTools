; 文字复制命令 maa
; 日期：2026-10-20
; 回路标注与天正多行目标禁写；可作为来源。
(vl-load-com)

; 回路标注的 KeyOwnWireId 只指向一条标准导线；不改天正对象本身。
(defun MAA:WireOwner (data / app field refs linked linked-data)
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
      (setq linked (handent (car refs)))
      (if linked
        (progn
          (setq linked-data (entget linked))
          (if (equal (cdr (assoc 0 linked-data)) "LWPOLYLINE") linked nil)
        )
      )
    )
  )
)

; 只接受该测试图确认过的单个 (1000 . 编号) 结构。
(defun MAA:LineNumApp (data / apps app fields)
  (setq apps (cdr (assoc -3 data)))
  (if (= (length apps) 1)
    (progn
      (setq app (car apps) fields (cdr app))
      (if (and (equal (strcase (car app)) "LINENUM")
               (= (length fields) 1)
               (= (caar fields) 1000)
               (eq (type (cdar fields)) 'STR))
        app
        nil
      )
    )
  )
)

(defun MAA:WireText (data / wire app)
  (setq wire (MAA:WireOwner data))
  (if wire
    (progn
      (setq app (MAA:LineNumApp (entget wire '("linenum"))))
      (if app (cdr (cadr app)) nil)
    )
  )
)

; TCH_WIREDIM2 target writes are disabled until native display sync is confirmed.
(defun MAA:LeaderCode (data pick / base angle point dx dy offset)
  (setq base (cdr (assoc 11 data))
        angle (cdr (assoc 52 data)))
  (if (and (listp base) (listp pick)
           (numberp (car base)) (numberp (cadr base)))
    (progn
      (setq point (vl-catch-all-apply 'trans (list pick 1 0)))
      (if (not (vl-catch-all-error-p point))
        (progn
          (if (not (numberp angle)) (setq angle 0.0))
          (setq dx (- (car point) (car base))
                dy (- (cadr point) (cadr base))
                offset (- (* dy (cos angle)) (* dx (sin angle))))
          (cond ((> offset 0.0) 1)
                ((< offset 0.0) 2)
                (T nil))
        )
      )
    )
  )
)

(defun MAA:LeaderPickedText (data pick / code)
  (setq code (MAA:LeaderCode data pick))
  (if code (cdr (assoc code data)) nil)
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

; 普通 MTEXT 用 \P 表示换行；天正组码 1 的 CRLF 不能原样写入。
(defun MAA:MTextValue (value / i n ch out)
  (setq i 1 n (strlen value) out "")
  (while (<= i n)
    (setq ch (substr value i 1))
    (cond
      ((equal ch (chr 13))
        (setq out (strcat out "\\P"))
        (if (and (< i n) (equal (substr value (1+ i) 1) (chr 10)))
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

; 只写拾取到的引线文字字段，另一字段必须保持不变。
(defun MAA:WriteLeader (entity data code value / prop other-code obj writable
                        before result after readback success old-other)
  (if (and (member code '(1 2))
           (assoc code data)
           (assoc (if (= code 1) 2 1) data))
    (progn
      (setq prop (if (= code 1) 'UpText 'DownText)
            other-code (if (= code 1) 2 1)
            old-other (cdr (assoc other-code data))
            obj (vl-catch-all-apply 'vlax-ename->vla-object (list entity)))
      (if (not (vl-catch-all-error-p obj))
        (progn
          (setq writable
            (vl-catch-all-apply 'vlax-property-available-p (list obj prop T)))
          (if (eq writable T)
            (progn
              (setq before (vl-catch-all-apply 'vlax-get-property (list obj prop)))
              (if (equal before (cdr (assoc code data)))
                (progn
                  (setq result
                    (vl-catch-all-apply 'vlax-put-property (list obj prop value)))
                  (if (not (vl-catch-all-error-p result))
                    (progn
                      (vl-catch-all-apply 'vla-update (list obj))
                      (setq after (vl-catch-all-apply 'vlax-get-property (list obj prop))
                            readback (vl-catch-all-apply 'entget (list entity)))
                      (if (and (equal after value)
                               (not (vl-catch-all-error-p readback))
                               (equal (cdr (assoc code readback)) value)
                               (equal (cdr (assoc other-code readback)) old-other))
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
    )
  )
  (if success T nil)
)

(defun MAA:SourceText (data pick / kind part text)
  (setq kind (cdr (assoc 0 data)))
  (cond
    ; 天正图名只读取左侧图名（组码 1），不读取右侧比例（组码 2）。
    ((member kind '("TEXT" "ATTRIB" "TCH_TEXT" "TCH_MTEXT" "TCH_DRAWINGNAME"))
      (cdr (assoc 1 data)))
    ((equal kind "TCH_WIREDIM2")
      (MAA:WireText data))
    ((equal kind "TCH_MULTILEADER")
      (MAA:LeaderPickedText data pick))
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

; redraw 3/4 只改变屏幕亮显，退出时必须恢复。
(defun MAA:Highlight (entity mode)
  (if entity (vl-catch-all-apply 'redraw (list entity mode)))
)

(defun c:maa (/ *error* source-pick source-entity source-data source-kind source-text
                 target-pick target target-data target-kind target-code old-text
                 result readback write-text lines)
  (defun *error* (msg)
    (MAA:Highlight source-entity 4)
    (if (and msg
             (not (member (strcase msg) '("FUNCTION CANCELLED" "QUIT / EXIT ABORT"))))
      (princ (strcat "\n文字复制中断: " msg))
    )
    (princ)
  )
  (setq source-pick (nentsel "\n选择源文字: "))
  (if source-pick
    (progn
      (setq source-data (entget (car source-pick) '("*"))
            source-kind (cdr (assoc 0 source-data))
            source-text (MAA:SourceText source-data (cadr source-pick)))
      (if (not (eq (type source-text) 'STR))
        (princ "\n源对象的文字字段尚未确认，未修改图纸。")
        (progn
          (setq source-entity (car source-pick))
          (MAA:Highlight source-entity 3)
          (setq target-pick nil)
          (while (not target-pick)
            (setq target-pick (nentsel "\n选择目标文字，按 Esc 退出: "))
            (cond
              ((null target-pick)
                (princ "\n未选中目标文字，请继续选择。"))
              ((not (member (cdr (assoc 0 (entget (car target-pick))))
                            '("TEXT" "MTEXT" "ATTRIB" "TCH_TEXT" "TCH_MTEXT"
                              "TCH_MULTILEADER" "TCH_WIREDIM2")))
                (princ "\n目标不是可处理的文字，请重新选择。")
                (setq target-pick nil))
            )
          )
          (if target-pick
            (progn
              (setq target (car target-pick)
                    target-data (entget target)
                    target-kind (cdr (assoc 0 target-data))
                    old-text (assoc 1 target-data)
                    lines (MAA:Lines source-text))
              (cond
                ((not (member target-kind '("TEXT" "MTEXT" "ATTRIB" "TCH_TEXT" "TCH_MTEXT" "TCH_MULTILEADER" "TCH_WIREDIM2")))
                  (princ "\n天正或其他自定义目标尚无已验证的安全写入接口，未修改图纸。"))
                ((equal target-kind "TCH_MTEXT")
                  (princ "\n不支持此种操作"))
                ((equal target-kind "TCH_WIREDIM2")
                  (princ "\n不支持此种操作"))
                ((and (equal source-kind "TCH_MULTILEADER")
                      (equal target-kind "TCH_TEXT"))
                  (princ "\n不支持此种操作"))
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
                  (setq target-code
                    (MAA:LeaderCode target-data (cadr target-pick)))
                  (cond
                    ((not target-code)
                      (princ "\n无法根据拾取点判断引线上下行，未修改图纸。"))
                    ((> (length lines) 1)
                      (princ "\n多行内容不能写入引线的单独一行，未修改图纸。"))
                    ((MAA:WriteLeader target target-data target-code source-text)
                      (princ "\n文字复制完成。"))
                    (T
                      (princ "\n引线目标属性不可用或读回校验失败，请检查目标文字。"))
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
  (MAA:Highlight source-entity 4)
  (princ)
)

(c:maa)
(princ)
