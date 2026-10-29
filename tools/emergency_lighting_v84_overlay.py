"""CADTools integration overlay for Emergency-Lighting v0.1.84.

Date: 2026-10-29.  This is embedded into the GB2312 entry, after upstream
initialization; the original delivery ZIP remains unchanged.
"""

# Keep this source in UTF-8; embedding must encode it strictly as GB2312.
OVERLAY = r'''\
;; CADTools overlay: 2026-10-29. The upstream archive remains unchanged.
;; Picking a Tianzheng panel does not need a redraw before its DXF is read.
(defun EL:CADToolsPickStage (stage message)
  (setq *EL:CADToolsPickStage* stage)
  (EL:PerfSet "cadtools-pick-stage" stage)
  (princ (strcat "\n" message)))
(defun EL:PickEntity (prompt / pick data first-panel)
  (setq first-panel (equal prompt "\n拾取配电箱："))
  (if first-panel (EL:CADToolsPickStage "waiting-for-entsel" "拾取阶段：等待选择配电箱。"))
  (setq pick (EL:PerfInput 'EL:PickEntityInput (list prompt)))
  (if (and first-panel pick)
    (EL:CADToolsPickStage "entsel-returned" "拾取阶段：已选中对象，准备读取对象信息。"))
  (if pick
    (progn
      (if (not first-panel) (EL:HighlightPick (car pick)))
      (if first-panel (EL:CADToolsPickStage "reading-entget" "拾取阶段：正在读取对象信息。"))
      (setq data (entget (car pick)))
      (if first-panel (EL:CADToolsPickStage "entget-returned" "拾取阶段：对象信息已读取。"))
      (princ (strcat "\n已拾取：" (cond ((cdr (assoc 0 data))) (T "未知类型"))
        "；图层：" (cond ((cdr (assoc 8 data))) (T "未知"))
        "；句柄：" (cond ((cdr (assoc 5 data))) (T "未知"))))))
  pick)

;; A caught failure already finishes the business log as failed. Do not
;; subsequently replace it with a normal panel-pick-cancelled outcome.
(defun EL:FixedStatPick (/ *error* outcome failed)
  (defun *error* (msg)
    (EL:LogFailure msg) (vl-catch-all-apply 'EL:ClearGapPreview nil)
    (vl-catch-all-apply 'EL:ClearPickHighlights nil) (vl-catch-all-apply 'EL:ReleasePowerUI nil)
    (if msg (princ (strcat "\n统计已停止：" msg))) (EL:PerfFinish 'failed) (princ))
  (EL:LogStart)
  (if (EL:EnsureRoot)
    (progn
      (EL:LogAttach)
      (setq outcome (EL:MeasuredCatch 'EL:PickStartPanel nil))
      (EL:ClearPickHighlights)
      (if (vl-catch-all-error-p outcome)
        (progn (setq failed T) (EL:LogFailure (vl-catch-all-error-message outcome)) (setq outcome nil)))
      (if outcome (EL:FixedStartPick)
        (progn (if (not failed) (EL:LogFinish 'panel-pick-cancelled)) (EL:StartPickReturn))))))

;; Keep the generate action available on an empty panel so it can explain why.
(defun EL:PanelHomeFill (/ i key)
  (set_tile "p_number" "配电箱编号：请先拾取配电箱")
  (setq i 0)
  (repeat 8 (set_tile (strcat "p_row" (itoa i)) "") (setq i (1+ i)))
  (set_tile "p_power_total" "总功率：未统计")
  (EL:PanelText "p_error" "")
  (set_tile "p_capacity" "p_300")
  (EL:PanelSystemFill)
  (foreach key '("p_trunk" "p_capacity" "f_preview" "p_power_review"
      "p_system_drawing" "p_system_import") (mode_tile key 1))
  (mode_tile "p_generate" 0))
(defun EL:CADToolsPanelNotice (stage message)
  (setq *EL:PanelAction* nil
    *EL:CADToolsPanelNotice* (list (cons 'owner (namedobjdict))
      (cons 'stage stage) (cons 'message message)))
  (EL:PerfSet "cadtools-generate-stage" stage)
  (EL:PanelError message))
(defun EL:PanelGenerateBody (/ limit missing)
  (EL:LogEvent "PANEL_ACTION" 'generate)
  (cond
    ((not (EL:Get 'circuits *EL:PanelDraft*))
      (EL:CADToolsPanelNotice 'no-circuits "请先拾取配电箱和实际出线，当前输入保留。"))
    ((setq limit (EL:PanelCircuitLimitText *EL:PanelDraft*))
      (EL:CADToolsPanelNotice 'too-many-circuits limit))
    (T
      (EL:PanelSystemRecord 'generate-request 'drawing nil)
      (if (and (not *EL:PanelTemplateReady*) (setq missing (EL:PanelSystemMissing)))
        (progn
          (setq *EL:PanelSystemNotice* missing)
          (EL:PanelSystemRecord 'missing-definitions 'drawing missing)
          (EL:PanelSystemFill)
          (EL:CADToolsPanelNotice 'missing-definitions missing))
        (progn
          (setq *EL:PanelSystemNotice* nil
            *EL:PanelDraft* (EL:GenerationResult *EL:PanelDraft*)
            *EL:PanelCapacity* (EL:CapacityDefault *EL:PanelCapacity*))
          (EL:GenerationVerify 'EL:DLSubmissionCurrent (list *EL:PanelDraft*) *EL:PanelDraft*
            'DEVICE_LIBRARY_CHANGED "设备库状态待核对，保留当前功率输入")
          (EL:PanelGenerationWarnings *EL:PanelDraft*)
          (setq *EL:PanelAction* 'generate)
          (EL:PerfSet "cadtools-generate-stage" 'submitted)
          (EL:PanelClose (if *EL:PanelTemplateReady* 2 4)))))))
(defun EL:PanelGenerate (/ outcome)
  (setq *EL:CADToolsPanelNotice* nil)
  ;; Empty-panel clicks must not flush or inspect an absent library draft.
  (setq outcome (vl-catch-all-apply '(lambda ()
    (if (EL:Get 'circuits *EL:PanelDraft*)
      (progn
        (setq *EL:PanelDraft* (EL:GenerationResult *EL:PanelDraft*))
        (EL:GenerationVerify 'EL:PanelLibraryFlush nil *EL:PanelDraft*
          'LIBRARY_EDIT_PENDING "设备库编辑尚未保存，原输入保留")))
    (EL:PanelGenerateBody)) nil))
  (if (vl-catch-all-error-p outcome)
    (progn
      (EL:LogEvent "PANEL_GENERATE_ERROR" (vl-catch-all-error-message outcome))
      (EL:CADToolsPanelNotice 'error
        (strcat "生成操作未完成，当前输入保留：" (vl-catch-all-error-message outcome))))))

;; Diagnostic summaries deliberately omit full persisted geometry. The ELDIAG
;; command retains the upstream full export for cases that need those records.
(defun EL:CADToolsShortValue (value / kind)
  (setq kind (type value))
  (cond ((not value) nil)
    ((member kind '(INT REAL SYM)) value)
    ((equal kind 'STR) (if (<= (strlen value) 1024) value "<内容过长，已省略>"))
    (T "<复杂内容已省略>")))
(defun EL:CADToolsEventFields (context / result row key)
  (if (equal (type context) 'STR)
    (list (cons 'message (EL:CADToolsShortValue context)))
    (progn
      (foreach key '(message error reason status panel action generate syncable stage)
        (setq row (vl-catch-all-apply 'assoc (list key context)))
        (if (and row (not (vl-catch-all-error-p row)))
          (setq result (cons (cons key (EL:CADToolsShortValue (cdr row))) result))))
      (reverse result))))
(defun EL:CADToolsEvents (events / rows event count)
  (setq count 0)
  (while (and events (< count 120))
    (setq event (car events) events (cdr events) count (1+ count)
      rows (cons (list (cons 'sequence (car event)) (cons 'stage (cadr event))
        (cons 'fields (EL:CADToolsEventFields (caddr event)))) rows)))
  (list (cons 'recent rows) (cons 'older-events-omitted (if events T nil))))
(defun EL:CADToolsRunSnapshot (summary events error / metrics)
  (setq metrics (EL:Get 'metrics summary))
  (list (cons 'summary (EL:DiagnosticFields summary
      '(schema run-id command status command-status business-outcome last-outcome package
        total-ms interaction-ms program-ms)))
    (cons 'metrics (EL:DiagnosticFields metrics
      '("panel-lifecycle-stage" "panel-not-shown-reason" "panel-return-status"
        "panel-return-action" "panel-final-status" "recognize-fixed-calls" "panel-submits"
        "actual-circuits" "entity-write-attempts" "transaction-failures"
        "cadtools-pick-stage" "cadtools-generate-stage")))
    (cons 'error (EL:CADToolsShortValue error))
    (cons 'events (EL:CADToolsEvents events))))
(defun EL:CADToolsFastDiagnostic (/ folder stamp previous active summary panel notice files entry
    *EL:DiagnosticProgressPath*)
  (EL:DiagnosticRequire (EL:EnsureRoot) "无法确认应急照明目录。")
  (setq *EL:DiagnosticExportPath* nil *EL:DiagnosticError* nil *EL:DiagnosticExportMessage* nil
    folder (EL:DiagnosticFolder) *EL:DiagnosticExportPath* (EL:DiagnosticWindowsPath folder)
    *EL:DiagnosticProgressPath* (strcat folder "/progress.log")
    stamp (rtos (getvar "CDATE") 2 6) previous (EL:Get (namedobjdict) *EL:DiagnosticRuns*)
    panel (if *EL:PanelDraft* *EL:PanelDraft* *EL:Result*)
    notice (if (equal (EL:Get 'owner *EL:CADToolsPanelNotice*) (namedobjdict))
      (EL:DiagnosticFields *EL:CADToolsPanelNotice* '(stage message))))
  (if *EL:PerfActive*
    (setq summary (list '(schema . 2) (cons 'run-id *EL:PerfRunID*)
      (cons 'command *EL:PerfCommand*) '(status . in-progress)
      '(command-status . in-progress) (cons 'business-outcome *EL:PerfOutcome*)
      (cons 'package *EL:PackageMarker*) (cons 'metrics *EL:PerfMetrics*))
      active (EL:CADToolsRunSnapshot summary *EL:DeferredLogEvents* *EL:MonitorError*)))
  (EL:DiagnosticProgress "BUNDLE_BEGIN")
  (setq files (list
    (cons "state.eld" (list '(scope . quick-summary) (cons 'package *EL:PackageMarker*)
      (cons 'export-time stamp) (cons 'drawing (getvar "DWGNAME"))
      (cons 'drawing-folder (getvar "DWGPREFIX")) (cons 'acad-version (getvar "ACADVER"))
      (cons 'panel (EL:CADToolsShortValue (EL:Get 'panel panel)))
      (cons 'circuit-count (length (EL:Get 'circuits panel)))
      (cons 'pick-stage *EL:CADToolsPickStage*) (cons 'generate-notice notice)))
    (cons "load.eld" (if *EL:MonitorLoadSummary* (list (cons 'summary *EL:MonitorLoadSummary*))))
    (cons "active-run.eld" active)
    (cons "previous-run.eld" (if previous (EL:CADToolsRunSnapshot
      (EL:Get 'summary previous) (EL:Get 'events previous) (EL:Get 'error previous))))))
  (foreach entry files
    (if (cdr entry) (EL:DiagnosticWriteData (strcat folder "/" (car entry)) (cdr entry))))
  (EL:DiagnosticWriteText (strcat folder "/README.md")
    (strcat "# 应急照明轻量诊断资料\r\n日期：" (substr stamp 1 4) "-"
      (substr stamp 5 2) "-" (substr stamp 7 2)
      "\r\n状态：轻量快照已收集\r\n\r\n"
      "state.eld：当前图纸、面板状态及最近提示。\r\n"
      "load.eld：最近加载摘要。\r\n"
      "active-run.eld：导出时仍在运行的命令摘要，不代表命令已完成。\r\n"
      "previous-run.eld：本图最近一次已完成的诊断摘要，可能不是当前操作。\r\n"
      "事件只保留最近 120 条及简要字段；未导出图纸关联和保存数据。\r\n"
      "需要完整关联时可关闭面板后运行 ELDIAG；完整导出可能耗时较长。\r\n"
      "导出不修改图纸；关闭图纸或重新加载后，内存记录可能不再可用。\r\n"))
  (EL:DiagnosticProgress "BUNDLE_DONE")
  (setq *EL:DiagnosticExportMessage* "已导出轻量诊断资料文件夹，可复制路径或打开查看。")
  (princ (strcat "\n诊断资料文件夹：" *EL:DiagnosticExportPath*))
  *EL:DiagnosticExportPath*)
(defun EL:PanelDiagnosticExport (/ outcome)
  (setq *EL:DiagnosticExportSucceeded* nil
    outcome (EL:MeasuredCatch 'EL:CADToolsFastDiagnostic nil)
    *EL:DiagnosticExportSucceeded* (and (not (vl-catch-all-error-p outcome))
      outcome (equal outcome *EL:DiagnosticExportPath*)))
  (cond ((vl-catch-all-error-p outcome)
      (EL:DiagnosticSaveFailure (EL:DiagnosticFailure outcome)))
    (*EL:DiagnosticExportMessage*)
    (T "诊断导出未完成，请查看命令行原因。")))
'''.removeprefix("\\\n")

START = ";; BEGIN CADTOOLS OVERLAY 2026-10-29\n"
END = ";; END CADTOOLS OVERLAY 2026-10-29\n"
