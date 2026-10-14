; Tianzheng wire-label native double-click entry probe. Read-only.
; Date: 2026-10-14
; APPLOAD starts capture. Double-click the label, finish native edit,
; then run TZDBLCLKSTOP to save TZDBLCLKDBG.txt under TEMP.
(vl-load-com)

(defun TZDB:Remember (kind args)
  (setq *TZDB:Events* (cons (list kind args) *TZDB:Events*))
  (princ)
)

(defun TZDB:DoubleClick (reactor args)
  (TZDB:Remember "DOUBLE_CLICK" args)
)

(defun TZDB:WillStart (reactor args)
  (TZDB:Remember "COMMAND_START" args)
)

(defun TZDB:Ended (reactor args)
  (TZDB:Remember "COMMAND_END" args)
)

(defun TZDB:Cancelled (reactor args)
  (TZDB:Remember "COMMAND_CANCEL" args)
)

(defun TZDB:Failed (reactor args)
  (TZDB:Remember "COMMAND_FAIL" args)
)

(defun TZDB:Unknown (reactor args)
  (TZDB:Remember "UNKNOWN_COMMAND" args)
)

(defun TZDB:Remove ()
  (if *TZDB:MouseReactor*
    (progn
      (vl-catch-all-apply 'vlr-remove (list *TZDB:MouseReactor*))
      (setq *TZDB:MouseReactor* nil)
    )
  )
  (if *TZDB:CommandReactor*
    (progn
      (vl-catch-all-apply 'vlr-remove (list *TZDB:CommandReactor*))
      (setq *TZDB:CommandReactor* nil)
    )
  )
)

(defun c:TZDBLCLKSTART ()
  (TZDB:Remove)
  (setq *TZDB:Events* (list (list "START" nil)))
  (setq *TZDB:MouseReactor*
    (vlr-mouse-reactor nil
      '((:vlr-beginDoubleClick . TZDB:DoubleClick))
    )
  )
  (setq *TZDB:CommandReactor*
    (vlr-command-reactor nil
      '((:vlr-unknownCommand . TZDB:Unknown)
        (:vlr-commandWillStart . TZDB:WillStart)
        (:vlr-commandEnded . TZDB:Ended)
        (:vlr-commandCancelled . TZDB:Cancelled)
        (:vlr-commandFailed . TZDB:Failed))
    )
  )
  (princ "\n已开始记录双击和命令事件。请双击回路标注完成原生编辑，再运行 TZDBLCLKSTOP。")
  (princ)
)

(defun c:TZDBLCLKSTOP (/ temp-path output-path stream event)
  (TZDB:Remove)
  (TZDB:Remember "STOP" nil)
  (setq temp-path (getenv "TEMP"))
  (if (not temp-path)
    (setq temp-path (getvar "DWGPREFIX"))
  )
  (setq output-path (strcat temp-path "\\TZDBLCLKDBG.txt"))
  (setq stream (open output-path "w"))
  (if stream
    (progn
      (write-line "TZDBLCLKDBG 2026-10-14" stream)
      (foreach event (reverse *TZDB:Events*)
        (write-line
          (strcat (car event) " " (vl-prin1-to-string (cadr event)))
          stream
        )
      )
      (close stream)
      (princ (strcat "\n探测日志已保存: " output-path))
    )
    (princ (strcat "\n无法写入探测日志: " output-path))
  )
  (princ)
)

(c:TZDBLCLKSTART)
(princ)
