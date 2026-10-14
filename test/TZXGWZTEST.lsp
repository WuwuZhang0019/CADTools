; Test whether XGWZ accepts the picked point of a wire annotation.
; Date: 2026-10-14
; Commands: TZXGWZTEST, TZXGWZCHECK. Use only in a copy of the DWG.
; This probe passes the pick point only. Type the new text manually if prompted.
(vl-load-com)

(defun TZX:WireOwner (data / app field refs wire)
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
      (setq wire (handent (car refs)))
      (if (and wire (equal (cdr (assoc 0 (entget wire))) "LWPOLYLINE"))
        wire
        nil
      )
    )
  )
)

(defun TZX:WireText (target / data wire app fields)
  (setq data (entget target '("*")))
  (if data
    (setq wire (TZX:WireOwner data))
  )
  (if wire
    (progn
      (setq app (assoc "linenum" (cdr (assoc -3 (entget wire '("linenum"))))))
      (if (and app (= (length (cdr app)) 1))
        (progn
          (setq fields (cdr app))
          (if (and (= (caar fields) 1000)
                   (eq (type (cdar fields)) 'STR))
            (cdar fields)
          )
        )
      )
    )
  )
)

(defun c:TZXGWZTEST (/ source-pick source-data source-kind source-text
                      target-pick target target-data before result)
  (setq source-pick (nentsel "\n选择短单行源文字: "))
  (if source-pick
    (progn
      (setq source-data (entget (car source-pick))
            source-kind (cdr (assoc 0 source-data))
            source-text (cdr (assoc 1 source-data)))
      (if (and (member source-kind '("TEXT" "TCH_TEXT" "ATTRIB"))
               (eq (type source-text) 'STR)
               (> (strlen source-text) 0)
               (<= (strlen source-text) 127))
        (progn
          (setq target-pick (nentsel "\n选择天正回路标注目标: "))
          (if target-pick
            (progn
              (setq target (car target-pick)
                    target-data (entget target '("*")))
              (if (equal (cdr (assoc 0 target-data)) "TCH_WIREDIM2")
                (progn
                  (setq before (TZX:WireText target))
                  (if (and (eq (type before) 'STR)
                           (not (equal before source-text)))
                    (progn
                      (setq *TZX:Target* target
                            *TZX:Expected* source-text
                            *TZX:Before* before)
                      (princ (strcat "\n原编号: " before "；待复制: " source-text))
                      (setq result (vl-catch-all-apply 'vl-cmdf
                                     (list "XGWZ" (cadr target-pick))))
                      (if (vl-catch-all-error-p result)
                        (princ (strcat "\nXGWZ 调用失败: "
                          (vl-catch-all-error-message result)))
                        (princ (strcat "\n已向 XGWZ 传入拾取点。若提示输入新文字，请手动输入: "
                          source-text
                          "；命令结束后运行 TZXGWZCHECK。若仍提示选择目标，请按 Esc 退出并告知结果。"))
                      )
                    )
                    (princ "\n目标编号不可读取或与源文字相同，未调用 XGWZ。")
                  )
                )
                (princ "\n目标不是 TCH_WIREDIM2，未调用 XGWZ。")
              )
            )
            (princ "\n已取消目标选择。")
          )
        )
        (princ "\n仅接受非空的短单行 TEXT、TCH_TEXT 或 ATTRIB 来源。")
      )
    )
    (princ "\n已取消源文字选择。")
  )
  (princ)
)

(defun c:TZXGWZCHECK (/ after)
  (if (and *TZX:Target* *TZX:Expected*)
    (progn
      (setq after (TZX:WireText *TZX:Target*))
      (princ (strcat "\n原编号: " *TZX:Before*
                     "；期望编号: " *TZX:Expected*
                     "；关联导线读回: "
                     (if (eq (type after) 'STR) after "<无法读取>")))
      (if (equal after *TZX:Expected*)
        (princ "\n字段已更新；请同时确认图面标注是否显示期望编号。")
        (princ "\n字段未更新；请保留命令行记录并检查图面。")
      )
    )
    (princ "\n请先运行 TZXGWZTEST。")
  )
  (princ)
)

(princ "\n已加载 XGWZ 独立测试：运行 TZXGWZTEST；完成天正提示后运行 TZXGWZCHECK。")
(princ)
