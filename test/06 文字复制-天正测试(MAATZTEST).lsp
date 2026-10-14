; 天正文字复制独立测试副本；命令 MAATZTEST
; 日期：2026-10-14
; 回路标注目标尝试同值 Height 设置并由用户确认；天正多行目标禁写。
(vl-load-com)

; 回路标注的 KeyOwnWireId 只指向一条标准导线；不改天正对象本身。
(defun MAAT:WireOwner (data / app field refs linked linked-data)
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
(defun MAAT:LineNumApp (data / apps app fields)
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

(defun MAAT:WireText (data / wire app)
  (setq wire (MAAT:WireOwner data))
  (if wire
    (progn
      (setq app (MAAT:LineNumApp (entget wire '("linenum"))))
      (if app (cdr (cadr app)) nil)
    )
  )
)

(defun MAAT:WireNameOnlyP (data / app)
  (setq app (assoc "TG_DIMWIRE_TYPE" (cdr (assoc -3 data))))
  (if (and app
           (equal (cdr (assoc 1000 (cdr app))) "WireNameOnly"))
    T nil
  )
)

; 仅独立测试命令使用：对已确认可写的 Height 设置原值，探测标注是否重建。
; 用户按图面实际显示确认；选择 No 或直接回车时恢复原导线字段。
(defun MAAT:WriteWireText (target data value / wire before app old-text xdata changed
                          result after after-app obj height attempted update-result answer restored success)
  (setq wire (MAAT:WireOwner data))
  (if (and wire (MAAT:WireNameOnlyP data) (<= (strlen value) 127))
    (progn
      (setq before (entget wire '("linenum"))
            app (MAAT:LineNumApp before))
      (if app
        (progn
          (setq old-text (cdr (cadr app)))
          (if (equal value old-text)
            (princ "\n请选用与原回路编号不同的源文字进行刷新测试。")
            (progn
              (setq xdata (assoc -3 before)
                    changed (subst (list -3 (list (car app) (cons 1000 value)))
                                   xdata before)
                    result (vl-catch-all-apply 'entmod (list changed)))
              (if (and (not (vl-catch-all-error-p result)) result)
                (progn
                  (setq after (entget wire '("linenum"))
                        after-app (MAAT:LineNumApp after))
                  (if (and after-app (equal (cdr (cadr after-app)) value))
                    (progn
                      (vl-catch-all-apply 'entupd (list wire))
                      (setq obj (vl-catch-all-apply
                                  'vlax-ename->vla-object (list target)))
                      (if (and obj (not (vl-catch-all-error-p obj)))
                        (progn
                          (setq height
                            (vl-catch-all-apply 'vlax-get-property (list obj 'Height)))
                          (if (and (not (vl-catch-all-error-p height))
                                   (numberp height))
                            (progn
                              (setq attempted T)
                              (setq update-result
                                (vl-catch-all-apply 'vlax-put-property
                                  (list obj 'Height height)))
                              (if (not (vl-catch-all-error-p update-result))
                                (setq update-result
                                  (vl-catch-all-apply 'vla-update (list obj)))
                              )
                            )
                          )
                          (if (and attempted
                                   (not (vl-catch-all-error-p update-result)))
                            (progn
                              (initget "Yes No")
                              (setq answer
                                (vl-catch-all-apply 'getkword
                                  (list "\n图面回路标注是否显示新值? [Yes/No] <No>: ")))
                              (if (equal answer "Yes") (setq success T))
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )
              (if (not success)
                (progn
                  (vl-catch-all-apply 'entmod (list before))
                  (setq restored (MAAT:LineNumApp (entget wire '("linenum"))))
                  (if (and restored (equal (cdr (cadr restored)) old-text))
                    (princ "\n刷新测试未通过，已恢复导线原值。")
                    (princ "\n回路编号恢复失败，请检查关联导线。")
                  )
                  (vl-catch-all-apply 'entupd (list wire))
                  (if (and obj (not (vl-catch-all-error-p obj)))
                    (vl-catch-all-apply 'vla-update (list obj))
                  )
                )
              )
              (if (and obj (not (vl-catch-all-error-p obj)))
                (vlax-release-object obj)
              )
            )
          )
        )
      )
    )
  )
  (if success T nil)
)

(defun MAAT:LeaderCode (data pick / base angle point dx dy offset)
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

(defun MAAT:LeaderPickedText (data pick / code)
  (setq code (MAAT:LeaderCode data pick))
  (if code (cdr (assoc code data)) nil)
)

; 统一识别 CRLF/LF 与普通 MTEXT 的 \P，避免把多行内容写入单行目标。
(defun MAAT:Lines (value / i n ch next current lines)
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
(defun MAAT:MTextValue (value / i n ch out)
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
(defun MAAT:WriteComText (entity prop value old-text / obj writable before result after data success)
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
(defun MAAT:WriteLeader (entity data code value / prop other-code obj writable
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

(defun MAAT:SourceText (data pick / kind part text)
  (setq kind (cdr (assoc 0 data)))
  (cond
    ((member kind '("TEXT" "ATTRIB" "TCH_TEXT" "TCH_MTEXT"))
      (cdr (assoc 1 data)))
    ((equal kind "TCH_WIREDIM2")
      (MAAT:WireText data))
    ((equal kind "TCH_MULTILEADER")
      (MAAT:LeaderPickedText data pick))
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

(defun c:MAATZTEST (/ source-pick source-data source-text target-pick target
                 target-data target-kind target-code old-text result readback write-text lines)
  (setq source-pick (nentsel "\n选择源文字: "))
  (if source-pick
    (progn
      (setq source-data (entget (car source-pick) '("*"))
            source-text (MAAT:SourceText source-data (cadr source-pick)))
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
                    lines (MAAT:Lines source-text))
              (cond
                ((not (member target-kind '("TEXT" "MTEXT" "ATTRIB" "TCH_TEXT" "TCH_MTEXT" "TCH_MULTILEADER" "TCH_WIREDIM2")))
                  (princ "\n天正或其他自定义目标尚无已验证的安全写入接口，未修改图纸。"))
                ((equal target-kind "TCH_MTEXT")
                  (princ "\n不支持此种操作"))
                ((equal target-kind "TCH_WIREDIM2")
                  (if (> (length lines) 1)
                    (princ "\n多行内容不能写入回路标注，未修改图纸。")
                    (if (MAAT:WriteWireText target (entget target '("*")) source-text)
                      (princ "\n测试通过：导线编号和标注显示已同步。")
                      (princ "\n不支持此种操作")
                    )
                  )
                )
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
                  (if (MAAT:WriteComText target 'Text source-text (cdr old-text))
                    (princ "\n文字复制完成。")
                    (princ "\n天正单行文字接口不可用或读回校验失败，请检查目标文字。")
                  )
                )
                ((equal target-kind "TCH_MULTILEADER")
                  (setq target-code
                    (MAAT:LeaderCode target-data (cadr target-pick)))
                  (cond
                    ((not target-code)
                      (princ "\n无法根据拾取点判断引线上下行，未修改图纸。"))
                    ((> (length lines) 1)
                      (princ "\n多行内容不能写入引线的单独一行，未修改图纸。"))
                    ((MAAT:WriteLeader target target-data target-code source-text)
                      (princ "\n文字复制完成。"))
                    (T
                      (princ "\n引线目标属性不可用或读回校验失败，请检查目标文字。"))
                  )
                )
                (T
                  (setq write-text
                    (if (equal target-kind "MTEXT")
                      (MAAT:MTextValue source-text)
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

(princ "\n测试副本已加载，输入 MAATZTEST 开始文字复制。")
(princ)
