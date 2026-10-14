; Tianzheng text probe for maa
; Date: 2026-10-14
; Usage: APPLOAD this file, run TZTXTDBG, choose an output TXT file, then
; select the five samples with labels 1..5. Press Enter at the label prompt to end.
; Labels: 1/2/3 = three annotation text kinds; 4 = Tianzheng single-line;
; 5 = Tianzheng multi-line. This command only reads drawing data.

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

(defun TZD:DumpEntity (stream title entity / data)
  (if (and entity (eq (type entity) 'ENAME))
    (progn
      (setq data (TZD:Entget entity T))
      (TZD:Write stream (strcat title "_entget_all_xdata") data)
      (TZD:DumpDictionary stream entity data)
      (TZD:DumpAttributes stream entity data)
    )
  )
)

(defun c:TZTXTDBG (/ path stream label selection containers index)
  (setq path (getfiled "Save Tianzheng text probe log"
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
          (while (setq label (getint "\nSample label 1..5 <Enter to finish>: "))
            (if (and (>= label 1) (<= label 5))
              (progn
                (setq selection (nentsel "\nSelect text or annotation: "))
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
                    (princ (strcat "\nSample " (itoa label) " recorded."))
                  )
                  (princ "\nNo object selected; choose a label to retry.")
                )
              )
              (princ "\nUse a label from 1 to 5.")
            )
          )
          (close stream)
          (princ (strcat "\nProbe log saved: " path))
        )
        (princ "\nCould not open the selected log file.")
      )
    )
    (princ "\nProbe cancelled.")
  )
  (princ)
)

(princ "\nLoaded TZTXTDBG. Run it to inspect five Tianzheng text samples.")
(princ)
