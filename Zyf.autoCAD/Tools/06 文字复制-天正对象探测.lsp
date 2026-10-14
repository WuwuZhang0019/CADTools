; 天正文字探测脚本，供 maa 改造前确认文字内容所在字段。
; 日期：2026-10-14
; 用法：APPLOAD 后运行 TZTXTDBG，选择日志路径，按 1 至 5 标记样本。
; 1/2/3 为三种标注文字，4 为天正单行文字，5 为天正多行文字。
; 本命令只读取图纸数据，不修改对象。

(vl-load-com)

; Keep the log ASCII (and therefore valid UTF-8) in both legacy and Unicode
; AutoLISP engines. In legacy engines \u00XX represents an original codepage byte.
(defun TZD:Hex (number width / digits result)
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

(defun TZD:Ascii (value / result code)
  (setq result "")
  (foreach code (vl-string->list (vl-prin1-to-string value))
    (setq result
      (strcat result
        (if (and (>= code 32) (<= code 126))
          (chr code)
          (strcat "\\u" (TZD:Hex code 4))
        )
      )
    )
  )
  result
)

(defun TZD:Write (stream title value)
  (write-line (strcat title " = " (TZD:Ascii value)) stream)
)

(defun TZD:Entget (entity all / result)
  (setq result
    (vl-catch-all-apply
      'entget
      (if all (list entity '("*")) (list entity))
    )
  )
  (if (vl-catch-all-error-p result)
    (list (cons "READ_ERROR" (vl-catch-all-error-message result)))
    result
  )
)

(defun TZD:DumpDictionary (stream entity data / pair dictionary result item count)
  (setq pair (assoc 360 data))
  (if (and pair (eq (type (cdr pair)) 'ENAME))
    (progn
      (setq dictionary (cdr pair))
      (TZD:Write stream "extension_dictionary" (TZD:Entget dictionary nil))
      (setq result (vl-catch-all-apply 'dictnext (list dictionary T))
            count 0)
      (while (and (not (vl-catch-all-error-p result)) result (< count 100))
        (setq count (1+ count))
        (TZD:Write stream (strcat "dictionary_entry_" (itoa count)) result)
        (setq item (cdr (assoc -1 result)))
        (if (and item (eq (type item) 'ENAME))
          (TZD:Write stream
            (strcat "dictionary_entity_" (itoa count))
            (TZD:Entget item T)
          )
        )
        (setq result (vl-catch-all-apply 'dictnext (list dictionary)))
      )
      (if (vl-catch-all-error-p result)
        (TZD:Write stream "dictionary_error"
          (vl-catch-all-error-message result))
      )
      (if (= count 100)
        (write-line "dictionary_truncated_after_100_entries" stream)
      )
    )
  )
)

(defun TZD:DumpAttributes (stream entity data / next child count done)
  (if (and (equal (cdr (assoc 0 data)) "INSERT")
           (equal (cdr (assoc 66 data)) 1))
    (progn
      (setq next (entnext entity) count 0 done nil)
      (while (and next (not done) (< count 100))
        (setq child (TZD:Entget next T)
              count (1+ count))
        (TZD:Write stream (strcat "insert_child_" (itoa count)) child)
        (setq done (equal (cdr (assoc 0 child)) "SEQEND")
              next (if done nil (entnext next)))
      )
      (if (= count 100)
        (write-line "insert_children_truncated_after_100" stream)
      )
    )
  )
)

(defun TZD:ComResult (value)
  (if (vl-catch-all-error-p value)
    (strcat "ERROR: " (vl-catch-all-error-message value))
    value
  )
)

; Follow XData handle links one level, without changing the referenced entity.
(defun TZD:DumpHandles (stream title data / xdata app field handle linked count)
  (setq xdata (cdr (assoc -3 data)) count 0)
  (foreach app xdata
    (foreach field (cdr app)
      (if (and (= (car field) 1005) (eq (type (cdr field)) 'STR)
               (< count 20))
        (progn
          (setq count (1+ count)
                handle (cdr field)
                linked (vl-catch-all-apply 'handent (list handle)))
          (TZD:Write stream (strcat title "_handle_" (itoa count))
            (list (car app) handle))
          (if (vl-catch-all-error-p linked)
            (TZD:Write stream (strcat title "_handle_error_" (itoa count))
              (vl-catch-all-error-message linked))
            (if linked
              (TZD:Write stream (strcat title "_linked_entget_" (itoa count))
                (TZD:Entget linked T))
              (write-line "linked_handle_not_found" stream)
            )
          )
        )
      )
    )
  )
)

; Query public COM properties only. Writable means an exposed setter exists;
; it does not prove that setting a Tianzheng object is safe or persistent.
(defun TZD:DumpCom (stream title entity / obj prop available writable)
  (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list entity)))
  (if (vl-catch-all-error-p obj)
    (TZD:Write stream (strcat title "_com_error") (TZD:ComResult obj))
    (progn
      (TZD:Write stream (strcat title "_com_object_name")
        (TZD:ComResult
          (vl-catch-all-apply 'vlax-get-property (list obj 'ObjectName))))
      (foreach prop '(TextString Text Content Contents Text1 Text2 LineNum WireName)
        (setq available (TZD:ComResult
                          (vl-catch-all-apply 'vlax-property-available-p
                            (list obj prop)))
              writable (TZD:ComResult
                         (vl-catch-all-apply 'vlax-property-available-p
                           (list obj prop T))))
        (TZD:Write stream
          (strcat title "_com_" (vl-symbol-name prop))
          (list "available" available "writable" writable))
      )
      (vlax-release-object obj)
    )
  )
)

(defun TZD:DumpEntity (stream title entity / data)
  (if (and entity (eq (type entity) 'ENAME))
    (progn
      (setq data (TZD:Entget entity T))
      (TZD:Write stream (strcat title "_entget_all_xdata") data)
      (TZD:DumpDictionary stream entity data)
      (TZD:DumpAttributes stream entity data)
      (TZD:DumpHandles stream title data)
      (TZD:DumpCom stream title entity)
    )
  )
)

(defun c:TZTXTDBG (/ path stream label selection containers index)
  (setq path (getfiled "保存天正文字探测日志"
                      (strcat (getvar "DWGPREFIX") "TZTXTDBG.txt")
                      "txt" 1))
  (if path
    (progn
      (setq stream (open path "w"))
      (if stream
        (progn
          (TZD:Write stream "acadver" (getvar "ACADVER"))
          (TZD:Write stream "dwgname" (getvar "DWGNAME"))
          (write-line
            "labels: 1/2/3=annotation kinds, 4=single-line, 5=multi-line"
            stream)
          (write-line
            "non-ASCII is escaped as \\uXXXX; legacy engine values may be codepage bytes"
            stream)
          (while (setq label (getint "\n输入样本类别 1..5 <回车结束>: "))
            (if (and (>= label 1) (<= label 5))
              (progn
                (setq selection (nentsel "\n点选文字或标注: "))
                (if selection
                  (progn
                    (write-line (strcat "=== SAMPLE " (itoa label) " ===") stream)
                    (TZD:Write stream "nentsel_result" selection)
                    (TZD:DumpEntity stream "picked" (car selection))
                    (setq containers (cadddr selection) index 0)
                    (if (listp containers)
                      (foreach entity containers
                        (setq index (1+ index))
                        (TZD:DumpEntity stream
                          (strcat "container_" (itoa index)) entity)
                      )
                    )
                    (write-line "=== END SAMPLE ===" stream)
                    (princ (strcat "\n样本 " (itoa label) " 已记录。"))
                  )
                  (princ "\n未选中对象，请重新输入类别。")
                )
              )
              (princ "\n类别请输入 1 至 5。")
            )
          )
          (close stream)
          (princ (strcat "\n探测日志已保存: " path))
        )
        (princ "\n无法打开所选日志文件。")
      )
    )
    (princ "\n已取消探测。")
  )
  (princ)
)

(princ "\n已加载 TZTXTDBG，可探测五类天正文字样本。")
(princ)
