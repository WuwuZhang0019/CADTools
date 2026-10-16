;; Date: 2026-10-15. Common publication/synchronization entry points.
(defun EL:PowerInputPath (panel / drawing)
  (if (and panel *EL:Root* (setq drawing (EL:DrawingID)))
    (strcat *EL:LiteDataRoot* "config/power-input-" (EL:Hash (strcat drawing "/" panel)) ".eld")))
(defun EL:RememberPanelPowers (result powers / path)
  (if (assoc 'device-library result) (EL:DLRememberInputs result powers)
  (if (setq path (EL:PowerInputPath (EL:Get 'panel result)))
    (EL:WriteData path (list '(version . 1) (cons 'powers
      (vl-remove-if-not '(lambda (row) (numberp (cdr row))) powers)))))))
(defun EL:FixedPowers (record / data powers row path remembered)
  ;; Date: 2026-10-11. Shared defaults come only from ELDEVLIB; DWG values remain local.
  (setq powers (EL:Get 'powers record))
  (if (and (setq path (EL:PowerInputPath (EL:Get 'source-panel-handle record)))
      (setq remembered (EL:ReadData path)) (EL:SimplePowersValid remembered))
    (foreach row (EL:Get 'powers remembered) (setq powers (EL:Put (car row) (cdr row) powers))))
  (if (setq remembered (EL:DLLoadInputs (EL:Get 'source-panel-handle record)))
    (foreach row (EL:Get 'device-overrides remembered)
      (if (EL:Get 'watts-set (cdr row)) (setq powers (EL:Put (car row) (EL:Get 'watts (cdr row)) powers)))))
  powers)
(defun EL:SaveNamePowers (powers / data row merged)
  (if (setq data (EL:SimpleLoadPowers))
    (progn
      (setq merged (EL:Get 'powers data))
      (foreach row powers
        (if (numberp (cdr row)) (setq merged (EL:Put (car row) (cdr row) merged))))
      (EL:WriteData (strcat *EL:LiteDataRoot* "config/block-powers.eld") (list '(version . 1) (cons 'powers merged))))))
(defun EL:SaveDraft (result cfg powers capacity / store record context)
  (setq *EL:LastSavedDraftId* nil)
  (if (assoc 'effective-powers result) (setq powers (EL:Get 'effective-powers result)))
  (setq capacity (EL:CapacityDefault capacity))
  (if (not (EL:Get 'capacity-source result)) (setq result (EL:Put 'capacity-source 'default result)))
  (setq store (cond ((EL:StoreForResult result)) (T (EL:StoreInitial)))
    record (cond ((EL:RecordForResult result store)) (T (EL:NewRecord (EL:Get 'panel result) store))))
  ;; Date: 2026-10-14. Saving inputs must not revise an earlier output's
  ;; record. A new draft becomes the latest entry for the source box.
  (if (EL:Get 'panel-output-handle record)
    ;; A new input record has no formal output of its own.
    (setq record (EL:NewRecord (EL:Get 'panel result) store)))
  ;; Date: 2026-10-15. Fresh inputs and their config use the same current template.
  ;; Historical records for other panels retain their own verified templates.
  (setq record (EL:Put 'template (EL:Get 'template cfg) record))
  (setq
    record (EL:Put 'draft-circuits (EL:Get 'circuits result) (EL:Put 'draft-capacity capacity
      (EL:Put 'powers powers (EL:Put 'config cfg (EL:Put 'engine (EL:Get 'engine result) record))))))
  (setq record (EL:Put 'panel-number (EL:PanelNumber result) record))
  (setq record (EL:RecordNumberInputs record result T))
  (setq record (EL:DLPersist result record))
  ;; Date: 2026-10-14. Preserve legacy ground choices, but no hidden
  ;; device/exit exclusions in the new directed-pick flow.
  (if (assoc 'block-ground result)
    (setq record (EL:Put 'block-ground (EL:Get 'block-ground result) record)))
  (setq record (EL:Put 'candidate-keys (EL:Get 'candidate-keys result)
    (EL:Put 'draft-capacity-source (EL:Get 'capacity-source result) record)))
  (if (not (EL:Get 'panel-output-handle record))
    (setq record (EL:RecordNumberInputs (EL:Put 'rows (EL:Get 'circuits result)
      (EL:Put 'capacity-source (EL:Get 'capacity-source result) (EL:Put 'capacity-option capacity record))) result nil)))
  (if (or (not (EL:Get 'can-generate result)) (not (EL:CircuitNumbersReady result)) (not (EL:SelectionsReady result capacity)))
    (setq record (EL:Put 'status 'stale record)))
  ;; Date: 2026-10-14. A saved draft has not yet generated its own diagram.
  (if (EL:Get 'panel-output-handle record)
    (setq record (EL:Put 'stale-reason 'draft-saved (EL:Put 'status 'stale record))))
  (if (EL:TemplateReady (EL:Get 'template cfg) cfg)
    (setq store (EL:Put 'fixed-template (EL:Get 'template cfg) store)))
  (EL:Require (or (and (not (EL:Get 'can-generate result))
      (EL:Get 'load-error (EL:Get 'device-library result))) (EL:DLSubmissionCurrent result))
    "设备库已变化，当前输入保留；请刷新库并重新核对后保存。")
  (setq record (EL:InputRecord record)
    context (EL:TransactionVerifiedStore 'EL:StoreWrite (list (EL:StorePutDiagram record store))))
  (if (and (equal T (EL:Get 'outcome context))
      (equal record (EL:DiagramForPanel (EL:Get 'panel result) (EL:TransactionVerifiedRead context))))
    (progn (setq *EL:LastSavedDraftId* (EL:Get 'diagram-id record)) T)))
(defun EL:InvokeCCKK2 (result cfg powers capacity / *EL:CCKK2Request*)
  (setq *EL:CCKK2Request* (list result cfg powers capacity)) (c:CCKK2))
(defun EL:CCKK2FromPanel (request / result)
  (setq result (car request))
  (princ (strcat "\n调用 CCKK2：" (itoa (length (EL:Get 'circuits result)))
    " 条实际回路，功率采用本次统计；无需再输入回路数。"))
  (EL:LogCall "CCKK2" (list (cons 'circuits (length (EL:Get 'circuits result)))
      (cons 'watts (mapcar '(lambda (row) (EL:Get 'watts row)) (EL:Get 'circuits result))))
    'EL:SyncDiagram (append request '(T T))))
(defun EL:EditPanel (result cfg / next context)
  ;; Date: 2026-10-14. Device editing remains in the circuit panel.
  (while result
    (EL:RememberStartPanel (EL:Get 'panel result) (EL:PanelNumber result))
    (setq *EL:StartPickContext* (EL:Put 'record
      (EL:DiagramForPanel (EL:Get 'panel result) (EL:StoreForResult result)) *EL:StartPickContext*))
    (setq *EL:Result* result *EL:FixedConfig* cfg)
    (setq next (EL:EditPanelOnce result cfg))
    (if (setq context (EL:Get 'library-suspended next))
      (setq *EL:DLParentContext* context *EL:DLParentContinue* 'EL:DLResumePanel))
    (setq result nil))
  next)
(defun EL:EditPanelOnce (result cfg / *error* store record powers capacity edited prepared saved ownlog syncable template resolved *EL:GenerationPreflight* *EL:LastSavedDraftId* *EL:LastGeneratedId* *EL:PlacementOnly*)
  (defun *error* (msg)
    (EL:LogFailure msg)
    (vl-catch-all-apply 'EL:ClearGapPreview nil)
    (vl-catch-all-apply 'EL:ClearPickHighlights nil)
    (vl-catch-all-apply 'EL:ReleasePowerUI nil)
    (if msg (princ (strcat "\n主面板已停止；已保存的输入仍在本图：" msg)))
    (EL:PerfFinish 'failed) (princ))
  (setq ownlog (not *EL:LogActive*))
  (if ownlog (EL:LogStart))
  (EL:LogEvent "EDIT_PANEL" (list (cons 'panel (EL:Get 'panel result))))
  (setq store (cond ((EL:LogCall "READ_STORE" nil 'EL:StoreForResult (list result))) (T (EL:StoreInitial)))
    record (cond ((EL:RecordForResult result store)) (T (EL:NewRecord (EL:Get 'panel result) store))))
  (if (and *EL:DLResume* (equal (EL:Get 'panel (EL:Get 'result *EL:DLResume*)) (EL:Get 'panel result)))
    (setq prepared (EL:Get 'result *EL:DLResume*) powers (EL:Get 'powers *EL:DLResume*)
      cfg (EL:Get 'config *EL:DLResume*) capacity (EL:Get 'capacity *EL:DLResume*)
      *EL:DLResume* nil)
    (progn
      (setq powers (EL:FixedPowers record)
        prepared (EL:LogCall "PREPARE_PANEL" (list (cons 'diagram-id (EL:Get 'diagram-id record)))
          'EL:PreparedResult (list result
            (if (EL:Get 'draft-circuits record) (EL:Put 'rows (EL:Get 'draft-circuits record) record) record))))
      (setq capacity (EL:CapacityDefault
        (if (EL:Get 'draft-circuits record) (EL:Get 'draft-capacity record) (EL:Get 'capacity-option record)))
        template (EL:Get 'template cfg))
      (if (not (EL:TemplateReady template cfg))
        (setq template (if (EL:TemplateReady (EL:Get 'template (EL:Get 'config record)) cfg)
          (EL:Get 'template (EL:Get 'config record)) (EL:Get 'template record))))
      (if (not (EL:TemplateReady template cfg)) (setq template (EL:Get 'fixed-template store)))
      (setq cfg (EL:Put 'template template cfg))))
  (setq *EL:DLSessionSnapshot* (EL:DLSnapshot)
    resolved (EL:DLPrepare prepared powers *EL:DLSessionSnapshot* nil)
    prepared (EL:Get 'result resolved) powers (EL:Get 'powers resolved))
  (setq edited (EL:LogCall "PANEL_DIALOG" (list (cons 'panel (EL:Get 'panel result)))
    'EL:PanelDialog (list prepared cfg powers capacity)))
  (if (and edited (not (EL:Get 'pick-panel edited)) (not (EL:Get 'library-suspended edited)))
    (progn
      (setq result (EL:Get 'result edited) powers (EL:Get 'powers edited)
        capacity (EL:Get 'capacity edited) cfg (EL:Get 'config edited)
        syncable (and (EL:Get 'can-generate result) (EL:CircuitNumbersReady result)
          (EL:SelectionsReady result capacity) (EL:TemplateReady (EL:Get 'template cfg) cfg)))
      (EL:LogEvent "PANEL_SUBMIT" (list (cons 'generate (EL:Get 'generate edited))
        (cons 'syncable syncable) (cons 'panel (EL:Get 'panel result))))
      (EL:PerfMark "panel-submit") (EL:PerfCount "panel-submits" 1)
      (EL:PerfSet "actual-circuits" (length (EL:Get 'circuits result)))
      (EL:RememberPanelPowers result powers)
      (if (and (not (assoc 'device-library result)) (not (EL:SaveNamePowers powers)))
        (princ "\n功率库写入失败，请保留当前窗口数值并检查插件目录写入权限。"))
      (if (and (EL:DLSubmissionCurrent result)
          (or (not (EL:Get 'generate edited)) (EL:NumberInputsCurrent result)))
        (progn
          ;; Date: 2026-10-15. Save inputs once before placement. A successful
          ;; placement keeps output associations in memory for explicit export.
          (setq *EL:Result* result *EL:FixedConfig* cfg
            saved (EL:SaveDraft result cfg powers capacity))
          (if (and saved (EL:Get 'generate edited))
            (if syncable
              (progn
                (setq *EL:GenerationPreflight* (list (namedobjdict) result cfg)
                  *EL:PlacementOnly* T)
                (setq saved (EL:InvokeCCKK2 result cfg powers capacity)))
              (progn
                (princ "\n生成未执行：回路、功率或模板校验未通过；当前输入已保存，请核对后重试。")
                (EL:MarkStale (EL:Get 'panel result) 'review-or-template-pending))))
          (if saved
            (princ (if (EL:Get 'load-error (EL:Get 'device-library result))
              "\n当前输入已保存；设备库恢复前不生成系统图。关闭图纸前请保存 DWG。"
              "\n当前输入已保存到本图；关闭图纸前请保存 DWG。"))
            (princ "\n本次保存或生成未完成；请查看上方原因后重试。")))
        (progn
          (EL:MarkStale (EL:Get 'panel result) 'source-changed)
          (EL:PerfInput 'alert (list (if (EL:DLSubmissionCurrent result)
            "平面编号已变化，请重新拾取；当前功率已尝试单独记住。"
            "设备库已变化，请打开设备库并重新核对；当前功率已尝试单独记住。")))))))
  (EL:ClearPickHighlights)
  (if ownlog (EL:LogFinish (if edited 'panel-accepted 'panel-cancelled)))
  (if (or (EL:Get 'pick-panel edited) (EL:Get 'library-suspended edited)) edited))
(defun EL:PublishDiagram (result cfg / store record powers capacity)
  (setq store (EL:StoreForResult result) record (EL:RecordForResult result store))
  (if record
    (progn
      (setq capacity (cond ((EL:Get 'capacity-option record)) (T 'cap300)) powers (EL:Get 'powers record))
      (if (equal (EL:Get 'engine result) 'fixed)
        (setq powers (EL:FixedPowers record) result (EL:PanelCompute result powers cfg))
        (setq result (EL:BoxStatistics result cfg (EL:LoadLibrary) nil)))
      ;; Date: 2026-10-14. Background statistics retain a draft. Only an
      ;; explicit Generate action places a new system diagram.
      (EL:SaveDraft result cfg powers capacity))) result)
;; Date: 2026-10-10. Empty recognition is a user-visible outcome, not a panel error.
(defun EL:PickedDevicesReady (result / ids circuit message)
  (foreach circuit (EL:Get 'circuits result) (setq ids (append ids (EL:Get 'devices circuit))))
  (if ids T
    (progn
      (setq message "未识别到连接设备：当前配电箱出线只有导线或未接到可识别设备。请检查导线连接及设备图块后重新拾取；本次未保存或生成系统图。")
      (EL:LogEvent "NO_CONNECTED_DEVICES" (list (cons 'panel (EL:Get 'panel result))
        (cons 'circuits (length (EL:Get 'circuits result))) (cons 'message message)))
      (princ (strcat "\n" message)) (EL:PerfInput 'alert (list message)) nil)))
;; Date: 2026-10-13. Do not silently create a second diagram when old source binding is absent.
(defun EL:RepickRecord (panel store / record)
  ;; Date: 2026-10-14. The current source draft alone supplies prior inputs.
  (if (not store) (setq store (EL:StoreInitial)))
  (setq record (EL:DiagramForPanel panel store))
  (EL:LogEvent "SOURCE_DRAFT" (list (cons 'source-panel panel)
    (cons 'diagram-id (EL:Get 'diagram-id record))))
  record)
(defun EL:RepickConfig (cfg record panel / trunk)
  (if (setq trunk (EL:Get 'concentrated-trunk (EL:Get 'config record)))
    (progn
      (EL:Require (handent trunk) "已保存的集中引出线不存在，请重新拾取集中引出线；原系统图保留。")
      (setq cfg (EL:Put 'concentrated-trunk trunk (EL:Put 'auto-panel panel cfg)))))
  (if (EL:Get 'template (EL:Get 'config record))
    (setq cfg (EL:Put 'template (EL:Get 'template (EL:Get 'config record)) cfg))) cfg)
;; Date: 2026-10-13. Panel identity and explicit circuit starts share one flow.
(defun EL:StartPickContext ()
  (if (and *EL:StartPickContext* (equal (EL:Get 'owner *EL:StartPickContext*) (namedobjdict))
      (handent (EL:Get 'panel *EL:StartPickContext*))) *EL:StartPickContext*))
(defun EL:RememberStartPanel (panel number / record)
  (if (and (EL:StartPickContext) (equal panel (EL:Get 'panel *EL:StartPickContext*)))
    (setq record (EL:Get 'record *EL:StartPickContext*)))
  (setq *EL:StartPickContext* (list (cons 'owner (namedobjdict))
    (cons 'panel panel) (cons 'number number) (cons 'record record))))
(defun EL:PickStartPanel (/ pick panel number record)
  (if (setq pick (EL:PickModel 'panel "\n拾取配电箱："))
    (progn
      (setq panel (cdr (assoc 5 (entget (car pick)))))
      (EL:Require (not (EL:ManagedEntity (car pick))) "请选择平面图配电箱，不能统计系统图输出。")
      (setq number (EL:PickPanelNumber))
      (setq record (EL:RepickRecord panel (EL:StoreIndex)))
      (if (and (equal number "暂无编号") (EL:Get 'panel-number record))
        (setq number (EL:Get 'panel-number record)))
      (EL:RememberStartPanel panel number)
      (setq *EL:StartPickContext* (EL:Put 'record record *EL:StartPickContext*))
      (setq *EL:StartPickResume* nil *EL:Result* nil *EL:DeviceResult* nil) T)))
(defun EL:StartPickReturn ()
  (if (and *EL:StartPickResume* (EL:StartPickContext)
      (equal (EL:Get 'panel (EL:Get 'result *EL:StartPickResume*))
        (EL:Get 'panel (EL:StartPickContext))))
    (progn (setq *EL:DLResume* *EL:StartPickResume* *EL:StartPickResume* nil)
      (EL:EditPanel (EL:Get 'result *EL:DLResume*) (EL:Get 'config *EL:DLResume*)))))
(defun EL:FixedStatPick (/ *error* outcome)
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
        (progn (EL:LogFailure (vl-catch-all-error-message outcome)) (setq outcome nil)))
      (if outcome (EL:FixedStartPick)
        (progn (EL:LogFinish 'panel-pick-cancelled) (EL:StartPickReturn))))))
(defun EL:StartPickEnd (wire point / a b da db)
  (setq a (car (EL:Get 'ends wire)) b (cadr (EL:Get 'ends wire))
    da (EL:Norm (EL:V- point (EL:Get 'point a))) db (EL:Norm (EL:V- point (EL:Get 'point b))))
  (if (> (abs (- da db)) (EL:GapEpsilon)) (if (< da db) a b)))
(defun EL:StartPickArrow (wire ep / segment a b v tip wing)
  (setq segment (if (equal (cadr (EL:Get 'key ep)) 'start) (car (EL:Get 'segments wire))
    (reverse (EL:Last (EL:Get 'segments wire))))
    a (car segment) b (cadr segment) v (EL:V* 0.35 (EL:V- b a)) tip (EL:V+ a v)
    wing (EL:V* 0.25 (list (- (cadr v)) (car v) 0.0)))
  (EL:DrawTransient a tip 2)
  (EL:DrawTransient tip (EL:V+ (EL:V- tip (EL:V* 0.3 v)) wing) 2)
  (EL:DrawTransient tip (EL:V- (EL:V- tip (EL:V* 0.3 v)) wing) 2))
(defun EL:PickCircuitStarts (cfg / pick data wire point ep row starts styles layers)
  (princ "\n连续拾取各回路起始导线：靠近箱体或集中干线的一端点选，黄色箭头朝设备端；重复拾取可修改方向，Enter 完成。")
  (while (setq pick (EL:PickModel 'wire "\n拾取回路起始端导线，靠近起点一端（Enter 完成）："))
    (setq data (entget (car pick)) wire (EL:WireRecord (car pick) cfg) ep nil)
    (cond
      ((or (EL:ManagedEntity (car pick)) (equal (cdr (assoc 60 data)) 1)
          (not (EL:PresetMember (cdr (assoc 8 data)) (EL:Get 'wire-layers cfg))))
        (princ "\n请选择预设导线图层上的可见平面导线。"))
      ((or (EL:Get 'issues wire) (/= (length (EL:Get 'ends wire)) 2))
        (princ "\n请选择有效的 LINE 或开放多段线。"))
      (T
        (setq point (trans (cadr pick) 1 0) ep (EL:StartPickEnd wire point))
        (while (and (not ep) (setq point (EL:PerfInput 'getpoint
            (list "\n方向不明确，请在靠近箱体或集中干线的端点附近点一下（Enter 跳过）："))))
          (setq ep (EL:StartPickEnd wire (trans point 1 0))))
        (if ep
          (progn
            (setq row (list (cons 'wire (EL:Get 'id wire)) (cons 'end (cadr (EL:Get 'key ep)))
              (cons 'point (EL:Get 'point ep)))
              starts (append (vl-remove-if '(lambda (old) (equal (EL:Get 'wire old) (EL:Get 'wire row))) starts) (list row))
              styles (EL:Unique (cons (EL:WireStyle data) styles))
              layers (EL:Unique (cons (cdr (assoc 8 data)) layers)))
            (EL:LogEvent "CIRCUIT_START_PICK" row)
            (princ (strcat "\n已选 " (itoa (length starts)) " 条回路起始导线。"))))))
    (EL:ClearGapPreview) (EL:ClearPickHighlights)
    (foreach row starts
      (EL:HighlightPick (handent (EL:Get 'wire row)))
      (setq wire (EL:WireRecord (handent (EL:Get 'wire row)) cfg)
        ep (EL:By 'key (list (EL:Get 'wire row) (EL:Get 'end row)) (EL:Get 'ends wire)))
      (EL:StartPickArrow wire ep)))
  (if starts (EL:Put 'circuit-starts starts (EL:Put 'concentrated-trunk nil
    (EL:Put 'wire-styles styles (EL:Put 'wire-layers layers cfg))))))
(defun EL:StartPickRun (/ context panel cfg result record saved-config)
  (setq context (EL:StartPickContext) panel (EL:Get 'panel context) record (EL:Get 'record context))
  (EL:Require context "请先点击“拾取配电箱”，选择箱体和编号。")
  (EL:Require (and (equal (cdr (assoc 0 (entget (handent panel)))) "INSERT")
    (not (EL:ManagedEntity (handent panel)))) "配电箱已失效，请重新拾取配电箱。")
  (setq saved-config (EL:LoadConfig)
    cfg (EL:Put 'roles (EL:Get 'roles saved-config) (EL:Put 'auto-panel panel (EL:Put 'template (EL:Get 'template saved-config)
    (EL:Put 'params (EL:FixedRecognitionParams saved-config) (EL:PresetConfig (EL:DefaultConfig (EL:DrawingID))))))))
  (if (EL:Get 'template (EL:Get 'config record))
    (setq cfg (EL:Put 'template (EL:Get 'template (EL:Get 'config record)) cfg)))
  (if (and (setq cfg (EL:PresetReady (handent panel) cfg)) (setq cfg (EL:PickCircuitStarts cfg)))
    (progn
      (EL:ClearGapPreview) (EL:ClearPickHighlights)
      (EL:LogEvent "PICKS" (list (cons 'panel panel) (cons 'circuit-starts (EL:Get 'circuit-starts cfg))))
      (setq result (EL:LogCall "RECOGNIZE_STARTS" (list panel) 'EL:RecognizeFixed (list cfg panel))
        result (EL:Put 'panel-number (EL:Get 'number context) result))
      (if (EL:PickedDevicesReady result) (list result cfg)))))
(defun EL:StartPickResumeResult (result cfg / context old record key store)
  (if (and (setq context *EL:StartPickResume*)
      (equal (EL:Get 'panel (setq old (EL:Get 'result context))) (EL:Get 'panel result)))
    (progn
      (setq store (cond ((EL:StoreForResult result)) (T (EL:StoreInitial)))
        record (cond ((EL:RecordForResult result store))
          (T (EL:NewRecord (EL:Get 'panel result) store)))
        record (EL:Put 'draft-circuits (EL:Get 'circuits old)
          (EL:Put 'powers (EL:Get 'powers context) (EL:DLPersist old record))))
      (foreach key '(block-ground capacity-source)
        (if (assoc key old) (setq result (EL:Put key (EL:Get key old) result))))
      (setq result (EL:PreparedResult result record)
        *EL:DLResume* (EL:Put 'result result (EL:Put 'config cfg context))))) result)
(defun EL:FixedStartPick (/ *error* outcome next)
  (defun *error* (msg)
    (EL:LogFailure msg) (vl-catch-all-apply 'EL:ClearGapPreview nil)
    (vl-catch-all-apply 'EL:ClearPickHighlights nil) (vl-catch-all-apply 'EL:ReleasePowerUI nil)
    (if msg (princ (strcat "\n拾取已停止，配电箱和编号保留：" msg))) (EL:PerfFinish 'failed) (princ))
  (if (not *EL:LogActive*) (EL:LogStart))
  (if (EL:EnsureRoot)
    (progn (EL:LogAttach)
      (setq outcome (EL:MeasuredCatch 'EL:StartPickRun nil))
      (EL:ClearGapPreview) (EL:ClearPickHighlights)
      (if (vl-catch-all-error-p outcome)
        (progn (EL:LogFailure (vl-catch-all-error-message outcome))
          (princ (strcat "\n拾取已停止，配电箱和编号保留：" (vl-catch-all-error-message outcome))) (setq outcome nil)))
      (if outcome
        (progn
          (setq outcome (list (EL:StartPickResumeResult (car outcome) (cadr outcome)) (cadr outcome))
            *EL:StartPickResume* nil next (EL:EditPanel (car outcome) (cadr outcome))))
        (setq next (EL:StartPickReturn)))
      (EL:LogFinish 'command-finished) next)))
;; Date: 2026-10-10. Reuse an exact saved trunk association; first use identifies the real panel.
(defun EL:TrunkSavedPanel (trunk store / ids row)
  (foreach row (EL:Get 'diagrams store)
    (if (equal trunk (EL:Get 'concentrated-trunk (EL:Get 'config row)))
      (setq ids (cons (EL:Get 'source-panel-handle row) ids))))
  (setq ids (EL:Unique ids))
  (if (= (length ids) 1) (car ids)))
(defun EL:FixedTrunkPick (/ *error* pick trunk panel cfg result record next data id number saved-config)
  (defun *error* (msg)
    (EL:LogFailure msg)
    (vl-catch-all-apply 'EL:ClearPickHighlights nil)
    (vl-catch-all-apply 'EL:ReleasePowerUI nil)
    (if msg (princ (strcat "\n集中引出线统计已停止：" msg))) (EL:PerfFinish 'failed) (princ))
  (setq *EL:Result* nil *EL:DeviceResult* nil)
  (EL:LogStart)
  (if (and (EL:EnsureRoot) (progn (EL:LogAttach) T)
      (setq pick (EL:PickModel 'wire "\n拾取与各回路出线相接的集中干线：")))
    (progn
      (setq trunk (car pick) data (entget trunk) id (cdr (assoc 5 data)))
      (EL:Require (and (not (EL:ManagedEntity trunk)) (not (equal (cdr (assoc 60 data)) 1)))
        "请选择平面图中可见的集中干线。")
      (setq panel (EL:TrunkSavedPanel id (EL:StoreRead)))
      (if (or (not panel) (not (handent panel)))
        (progn
          (princ "\n首次使用此干线，请补点实际配电箱；保存后自动复用关联。")
          (setq pick (EL:PickModel 'panel "\n拾取此集中干线所属的配电箱（Enter 取消）：")
            panel (if pick (cdr (assoc 5 (entget (car pick))))))))
      (if panel
        (progn
          (EL:Require (and (equal (cdr (assoc 0 (entget (handent panel)))) "INSERT")
            (not (EL:ManagedEntity (handent panel)))) "来源配电箱无效或为系统图输出。")
          (setq number (EL:PickPanelNumber))
          (setq saved-config (EL:LoadConfig)
            cfg (EL:Put 'roles (EL:Get 'roles saved-config) (EL:Put 'template (EL:Get 'template saved-config)
              (EL:Put 'params (EL:FixedRecognitionParams saved-config) (EL:PresetConfig (EL:DefaultConfig (EL:DrawingID)))))))
          (EL:Require (EL:PresetMember (cdr (assoc 8 data)) (EL:Get 'wire-layers cfg))
            "集中干线不在预设导线图层，请运行 ELPRESET 核对。")
          (if (setq cfg (EL:PresetReady (handent panel) cfg))
            (progn
              (setq cfg (EL:Put 'concentrated-trunk id (EL:Put 'auto-panel panel
                  (EL:Put 'wire-styles (list (EL:WireStyle data))
                    (EL:Put 'wire-layers (list (cdr (assoc 8 data))) cfg))))
                result (EL:LogCall "RECOGNIZE_TRUNK" (list panel id) 'EL:RecognizeFixed (list cfg panel))
                result (EL:Put 'panel-number number result))
              (princ (strcat "\n集中干线已识别 " (itoa (length (EL:Get 'circuits result)))
                " 条出线，箱侧连接段已排除；请用查看全部回路核对。"))
              (setq *EL:Result* result *EL:FixedConfig* cfg)
              (if (EL:PickedDevicesReady result) (setq next (EL:EditPanel result cfg))
                (setq *EL:Result* nil next nil)))
            (progn (EL:ClearPickHighlights) (setq next nil)))))))
  (EL:ClearPickHighlights) (EL:LogFinish 'command-finished) next)
(defun c:ELGEN (/ *error* cfg result record powers capacity perfowner)
  (defun *error* (msg)
    (redraw) (EL:ClearPickHighlights)
    (if *EL:Result* (vl-catch-all-apply 'EL:MarkStale (list (EL:Get 'panel *EL:Result*) 'update-failed)))
    (if msg (princ (strcat "\n生成新系统图停止：" msg))) (EL:PerfFinish 'failed) (princ))
  (setq perfowner (EL:PerfStart "ELGEN") *EL:DiagnosticsDeferred* T)
  (if (and *EL:Result* (EL:EnsureRoot))
    (progn
      (setq result *EL:Result* record (EL:RecordForResult result (EL:StoreRead)))
      (if (equal (EL:Get 'engine result) 'fixed)
        (progn
          (setq cfg *EL:FixedConfig* powers (EL:FixedPowers record) result (EL:PanelCompute result powers cfg))
          (if (not (EL:Get 'template cfg)) (setq cfg (EL:Put 'template (EL:Get 'template (EL:LoadConfig)) cfg))))
        (progn
          (princ "\n本次使用高级流程按身份保存的功率；不会写入按块名共享功率库。")
          (setq cfg (EL:LoadConfig) result (EL:BoxStatistics result cfg (EL:LoadLibrary) nil))))
      (setq capacity (cond ((EL:Get 'capacity-option record)) (T 'cap300)))
      (if (equal (EL:Get 'engine result) 'fixed)
        (EL:EditPanel result cfg)
        (EL:SyncDiagram result cfg powers capacity T T)))
    (princ "\n请先运行 ELSTAT 或 ELTRACE。"))
  (if perfowner (EL:PerfFinish 'command-finished)) (princ))

(defun EL:FixedStat (/ *error* next perfowner context)
  (defun *error* (msg)
    (EL:LogFailure msg)
    (vl-catch-all-apply 'EL:ReleasePowerUI nil)
    (if msg (princ (strcat "\n统计已停止：" msg)))
    (EL:PerfFinish 'failed) (princ))
  (setq perfowner (EL:PerfStart "ELSTAT") *EL:DiagnosticsDeferred* T)
  ;; Date: 2026-10-14. Open the unified panel before asking for a CAD pick.
  (if (EL:EnsureRoot)
    (setq next (EL:PerfCall "PANEL_HOME" 'EL:PanelDialog (list nil nil nil nil))))
  (if (setq context (EL:Get 'library-suspended next))
    (progn (setq *EL:DLParentContext* context *EL:DLParentContinue* 'EL:DLResumeHome)
      (setq next nil)))
  (while (EL:Get 'pick-panel next)
    (setq next (if (equal (EL:Get 'pick-panel next) 'trunk)
      (EL:PerfCall "PICK_STARTS" 'EL:FixedStartPick nil)
      (EL:PerfCall "PICK_PANEL" 'EL:FixedStatPick nil))))
  (if perfowner (EL:PerfFinish 'command-finished)) (princ))
;; Date: 2026-10-14. Continue the same opening panel after an async graphic pick.
(defun EL:DLResumeHome ()
  (setq *EL:DLParentContext* nil *EL:DLParentContinue* nil *EL:DLSessionSnapshot* nil)
  (EL:FixedStat))
(defun EL:RememberDiagramDiagnostic (record store)
  ;; Date: 2026-10-15. One successful output per open DWG, no file or XRecord
  ;; write. A failed/cancelled placement never replaces the previous output.
  (setq *EL:DiagramDiagnostics* (EL:Put (namedobjdict)
    (list (cons 'record record) (cons 'store
      (list '(schema-version . 1) (cons 'drawing-uuid (EL:Get 'drawing-uuid store)))))
    *EL:DiagramDiagnostics*)) nil)
(defun EL:DiagnosticRequire (condition message)
  ;; Preserve the actionable reason when AutoLISP EXIT becomes a generic abort.
  (if (not condition) (setq *EL:DiagnosticError* message))
  (EL:Require condition message))
(defun EL:DiagnosticFailure (outcome)
  (if *EL:DiagnosticError* *EL:DiagnosticError* (vl-catch-all-error-message outcome)))
(defun EL:DiagnosticRecord (store / record pick tag handle)
  (if *EL:Result*
    (setq record (EL:DiagramForPanel (EL:Get 'panel *EL:Result*) store)))
  (if (and record (not (EL:Get 'panel-output-handle record))) (setq record nil))
  (if (not record)
    (if (setq pick (EL:PickEntity "\n选择要导出的受管系统图箱体、回路或文字（Enter 取消）："))
      (progn
        (setq handle (cdr (assoc 5 (entget (car pick)))) tag (EL:DiagramTag (car pick))
          record (EL:By 'diagram-id (cdr (nth 1 tag)) (EL:Get 'diagrams store)))
        (EL:DiagnosticRequire (and record (equal (cdr (car tag)) (EL:Get 'drawing-uuid store))
          (equal (cdr (nth 4 tag)) handle)
          (EL:OwnedEntity handle store record (cdr (nth 2 tag)) (cdr (nth 3 tag)))
          (member (list handle (cdr (nth 2 tag)) (cdr (nth 3 tag))) (EL:DiagramOutputRefs record)))
          "不是本图原始受管成员；复制或外来对象不能导出关联记录。")))) record)
(defun EL:DiagnosticRecordValid (record store / ref entity)
  (EL:DiagnosticRequire (and (equal (type (EL:Get 'diagram-id record)) 'STR)
    (/= (EL:Get 'diagram-id record) "")
    (equal (type (EL:Get 'source-panel-handle record)) 'STR)
    (/= (EL:Get 'source-panel-handle record) "")
    (equal (type (EL:Get 'panel-output-handle record)) 'STR)
    (/= (EL:Get 'panel-output-handle record) "")
    (equal (type (EL:Get 'drawing-uuid store)) 'STR)
    (/= (EL:Get 'drawing-uuid store) "")
    (EL:UniqueDiagram store record)) "系统图身份不完整或有复制关联，未导出诊断副本。")
  (foreach ref (EL:DiagramOutputRefs record)
    (setq entity (EL:OwnedEntity (car ref) store record (cadr ref) (caddr ref)))
    ;; Exporting is read-only, so a locked layer does not prevent diagnostics.
    (EL:DiagnosticRequire (and entity (equal (cdr (assoc 410 (entget entity))) "Model"))
      "系统图成员缺失或归属失配，未导出诊断副本。")) T)
(defun EL:DiagnosticWindowsPath (path)
  (if path (vl-string-translate "/" "\\" path)))
(defun EL:DiagnosticWriteText (path textdata / stream result closed)
  ;; Date: 2026-10-15. All new diagnostic snapshots are UTF-8, including CAD2020.
  (setq result (vl-catch-all-apply '(lambda ()
    (setq stream (vlax-create-object "ADODB.Stream"))
    (EL:MonitorStreamWrite stream path textdata)) nil))
  (if stream
    (progn
      (setq closed (vl-catch-all-apply 'vlax-invoke-method (list stream 'Close)))
      (vlax-release-object stream)))
  (EL:DiagnosticRequire (and result (not (vl-catch-all-error-p result))
    (not (vl-catch-all-error-p closed)))
    (strcat "诊断文件写入失败，内存资料已保留：" (EL:DiagnosticWindowsPath path))) T)
(defun EL:DiagnosticProgress (stage / file)
  ;; Date: 2026-10-15. Flush a small checkpoint before each potentially slow file.
  (setq *EL:DiagnosticStage* stage)
  (if *EL:DiagnosticProgressPath*
    (progn
      (princ (strcat "\n诊断导出：" stage))
      (if (setq file (open *EL:DiagnosticProgressPath* "a"))
        (progn (write-line (strcat (rtos (EL:Tick) 2 0) " " stage) file) (close file))))) nil)
(defun EL:DiagnosticNativeCharset () "gb2312")
(defun EL:DiagnosticNativeText (path / stream outcome)
  ;; Native PRINT writes directly to disk; ADO performs the codepage conversion
  ;; in native code instead of constructing a multi-megabyte LISP print string.
  (setq outcome (vl-catch-all-apply '(lambda ()
    (setq stream (vlax-create-object "ADODB.Stream"))
    (vlax-put-property stream 'Type 2)
    (vlax-put-property stream 'Charset (EL:DiagnosticNativeCharset))
    (vlax-invoke-method stream 'Open nil 0 -1 "" "")
    (vlax-invoke-method stream 'LoadFromFile path)
    (vlax-invoke-method stream 'ReadText -1)) nil))
  (if stream
    (progn (vl-catch-all-apply 'vlax-invoke-method (list stream 'Close))
      (vlax-release-object stream)))
  (EL:DiagnosticRequire (not (vl-catch-all-error-p outcome))
    (strcat "诊断临时文件读取失败：" (EL:DiagnosticWindowsPath path))) outcome)
(defun EL:DiagnosticWriteData (path data / tmp file outcome closed)
  ;; Date: 2026-10-15. Do not VL-PRIN1-TO-STRING the entire live graph/store.
  (EL:DiagnosticProgress (strcat "FILE_BEGIN " (vl-filename-base path)))
  (setq tmp (strcat path ".native.tmp")
    outcome (vl-catch-all-apply '(lambda ()
      (setq file (open tmp "w"))
      (EL:DiagnosticRequire file "无法创建诊断临时文件。")
      (prin1 data file) (write-line "" file)) nil))
  (if file (setq closed (vl-catch-all-apply 'close (list file))))
  (if (and (not (vl-catch-all-error-p outcome)) (not (vl-catch-all-error-p closed)))
    (setq outcome (vl-catch-all-apply '(lambda ()
      (EL:DiagnosticWriteText path (EL:DiagnosticNativeText tmp))) nil))
    (setq outcome nil))
  (if (findfile tmp) (vl-catch-all-apply 'vl-file-delete (list tmp)))
  (EL:DiagnosticRequire (and (not (vl-catch-all-error-p outcome)) outcome)
    (strcat "诊断数据写出失败，已完成资料保留在原目录：" (EL:DiagnosticWindowsPath path)))
  (EL:DiagnosticProgress (strcat "FILE_DONE " (vl-filename-base path))) T)
(defun EL:DiagnosticFields (data keys / result key row)
  (foreach key keys (if (setq row (assoc key data)) (setq result (cons row result))))
  (reverse result))
(defun EL:DiagnosticResult (result / snapshot circuits circuit)
  ;; The persisted input/association is exported separately in full. Live caches
  ;; and expanded geometry are not a second diagnostic record of that input.
  (if result
    (progn
      (setq snapshot (EL:Get 'snapshot result))
      (foreach circuit (EL:Get 'circuits result)
        (setq circuits (cons (EL:DiagnosticFields circuit
          '(id circuit-uid circuit-number number-status watts total-watts complete
            issues wires devices objects seed-key output-order rows groups)) circuits)))
      (append (EL:DiagnosticFields result '(panel drawing engine complete total-watts
          capacity-option capacity-source diagram-id excluded-seeds))
        (list '(diagnostic-scope . business-fields)
          '(omitted-live-fields snapshot-geometry network-proof device-library caches)
          (cons 'snapshot-summary (list (cons 'drawing (EL:Get 'drawing snapshot))
            (cons 'wire-count (length (EL:Get 'wires snapshot)))
            (cons 'block-count (length (EL:Get 'blocks snapshot)))
            (cons 'end-count (length (EL:Get 'ends snapshot)))
            (cons 'issue-count (length (EL:Get 'issues snapshot)))))
          (cons 'circuits (reverse circuits)))))))
(defun EL:DiagnosticFolderAt (base / folder index)
  (setq base (strcat (EL:NormalizeRoot base) "ELDIAG-" (rtos (getvar "CDATE") 2 6))
    folder base index 0)
  (while (or (vl-file-directory-p folder) (findfile (strcat folder ".zip"))
      (findfile (strcat folder ".zip.partial")) (findfile (strcat folder ".zip.status"))
      (findfile (strcat folder ".zip.status.tmp")) (findfile (strcat folder ".zip.cancel")))
    (setq index (1+ index) folder (strcat base "-" (itoa index))))
  (if (vl-mkdir folder) folder))
(defun EL:DiagnosticFolder (/ folder)
  (setq folder (vl-catch-all-apply 'EL:DiagnosticFolderAt (list (strcat *EL:LiteDataRoot* "output/"))))
  (if (or (not folder) (vl-catch-all-error-p folder))
    (setq folder (vl-catch-all-apply 'EL:DiagnosticFolderAt (list (getvar "TEMPPREFIX")))))
  (EL:DiagnosticRequire (and folder (not (vl-catch-all-error-p folder))) "无法创建诊断目录；请检查输出目录或临时目录的写入权限。")
  folder)
(defun EL:DiagnosticPSQuote (value / index)
  (setq index 0)
  (while (setq index (vl-string-search "'" value index))
    (setq value (strcat (substr value 1 index) "''" (substr value (+ index 2))) index (+ index 2)))
  (strcat "'" value "'"))
(defun EL:DiagnosticEncodedCommand (textdata / stream xml node result object)
  ;; No user path is interpolated into a shell command. PowerShell receives
  ;; UTF-16LE Base64, avoiding WScript expansion of percent signs in paths.
  (setq result (vl-catch-all-apply '(lambda ()
    (setq stream (vlax-create-object "ADODB.Stream"))
    (vlax-put-property stream 'Type 2) (vlax-put-property stream 'Charset "unicode")
    (vlax-invoke-method stream 'Open nil 0 -1 "" "")
    (vlax-invoke-method stream 'WriteText textdata 0)
    (vlax-put-property stream 'Position 0) (vlax-put-property stream 'Type 1)
    (vlax-put-property stream 'Position 2)
    (setq xml (vlax-create-object "MSXML2.DOMDocument.6.0")
      node (EL:StartupUnwrap (vlax-invoke-method xml 'createElement "binary")))
    (vlax-put-property node 'dataType "bin.base64")
    (vlax-put-property node 'nodeTypedValue (vlax-invoke-method stream 'Read -1))
    (vlax-get-property node 'text)) nil))
  (if stream (vl-catch-all-apply 'vlax-invoke-method (list stream 'Close)))
  (foreach object (list stream node xml)
    (if object (vl-catch-all-apply 'vlax-release-object (list object))))
  (EL:DiagnosticRequire (not (vl-catch-all-error-p result))
    (strcat "无法准备诊断压缩命令："
      (if (vl-catch-all-error-p result) (vl-catch-all-error-message result) "")))
  (foreach object '("\r" "\n" " " "\t")
    (while (vl-string-search object result) (setq result (vl-string-subst "" object result)))) result)
(defun EL:DiagnosticScriptText (/ path file line parts)
  ;; Date: 2026-10-15. Source installs read the helper; delivered modules
  ;; embed its text so startup never needs to write a PowerShell file.
  (if (and *EL:Root* (setq path (findfile (strcat *EL:Root* "src/diagnostic-bundle.ps1")))
      (setq file (open path "r")))
    (progn
      (while (setq line (read-line file)) (setq parts (cons (strcat line "\r\n") parts)))
      (close file) (EL:MonitorJoin (reverse parts)))))
(defun EL:DiagnosticWait (path milliseconds / started echo outcome file polls)
  ;; Date: 2026-10-15. Only explicit export waits; stop as soon as the worker finishes.
  (setq started (EL:Tick) echo (getvar "CMDECHO") polls 0)
  (setvar "CMDECHO" 0)
  (setq outcome (vl-catch-all-apply '(lambda ()
    (while (and (not (findfile path)) (< polls (/ milliseconds 50))
        (< (EL:PerfDelta started (EL:Tick)) milliseconds))
      (vl-cmdf "_.DELAY" 50) (setq polls (1+ polls)))
    (if (findfile path)
      (progn
        (setq file (open path "r"))
        (EL:DiagnosticRequire file "无法读取诊断压缩状态文件。")
        (read-line file)))) nil))
  (if file (vl-catch-all-apply 'close (list file)))
  (setvar "CMDECHO" echo)
  (EL:DiagnosticRequire (not (vl-catch-all-error-p outcome))
    (if (vl-catch-all-error-p outcome) (EL:DiagnosticFailure outcome) "")) outcome)
(defun EL:DiagnosticCancelZip (path / file)
  ;; An abandoned worker checks this marker before publishing a ZIP.
  (if (setq file (open path "w")) (progn (write-line "CANCEL" file) (close file))))
(defun EL:DiagnosticZip (folder / script powershell command result path status outcome)
  (EL:DiagnosticProgress "ZIP_PREPARE")
  (setq script (EL:DiagnosticScriptText)
    powershell (strcat (getenv "SystemRoot") "/System32/WindowsPowerShell/v1.0/powershell.exe")
    path (strcat folder ".zip") status (strcat path ".status"))
  (EL:DiagnosticRequire (and script (findfile powershell)) "诊断压缩工具缺失，请使用完整交付包和 Windows PowerShell。")
  (EL:DiagnosticProgress "ZIP_ENCODE")
  (setq command (EL:DiagnosticEncodedCommand (strcat "& {\r\n" script "\r\n} -SourceDirectory "
    (EL:DiagnosticPSQuote (EL:DiagnosticWindowsPath folder)))))
  ;; Date: 2026-10-15. CAD2020 fails in WScript.Shell creation/Run on site.
  ;; STARTAPP uses the CAD process launcher, with no WScript COM dependency.
  (EL:DiagnosticProgress "ZIP_LAUNCH STARTAPP")
  (setq result (vl-catch-all-apply 'startapp
    (list (EL:DiagnosticWindowsPath powershell)
      (strcat "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand " command))))
  (EL:DiagnosticRequire (and (not (vl-catch-all-error-p result))
    (equal (type result) 'INT) (> result 0))
    (strcat "无法启动诊断压缩程序："
      (if (vl-catch-all-error-p result) (vl-catch-all-error-message result) "STARTAPP 未成功启动")
      "；原始资料保留在：" (EL:DiagnosticWindowsPath folder)))
  ;; Do not append to snapshot files while the worker hashes/compresses them.
  (setq *EL:DiagnosticStage* "ZIP_WAIT")
  (setq outcome (vl-catch-all-apply 'EL:DiagnosticWait (list status 30000)))
  (if (or (vl-catch-all-error-p outcome) (not outcome))
    (vl-catch-all-apply 'EL:DiagnosticCancelZip (list (strcat path ".cancel"))))
  (if (not outcome) (EL:DiagnosticProgress "ZIP_TIMEOUT"))
  (EL:DiagnosticRequire (and outcome (not (vl-catch-all-error-p outcome)))
    (if (vl-catch-all-error-p outcome) (EL:DiagnosticFailure outcome)
      (strcat "诊断压缩等待超过 30 秒，已停止等待；原始资料保留在：" (EL:DiagnosticWindowsPath folder))))
  (if (findfile status) (vl-catch-all-apply 'vl-file-delete (list status)))
  (EL:DiagnosticRequire (and (equal outcome "OK") (findfile path) (> (vl-file-size path) 0))
    (strcat "诊断压缩失败（" outcome "）："
      (if (equal outcome "OK") "ZIP 文件不存在或为空" "详细原因见本目录 bundle-error.txt")
      "；原始资料保留在：" (EL:DiagnosticWindowsPath folder)))
  (EL:DiagnosticWindowsPath path))
(defun EL:DiagnosticBundle (record store logpath issue / folder run files entry source target notes stamp metadata
    *EL:DiagnosticProgressPath*)
  (setq folder (EL:DiagnosticFolder) *EL:DiagnosticExportPath* (EL:DiagnosticWindowsPath folder)
    stamp (rtos (getvar "CDATE") 2 6)
    run (EL:Get (namedobjdict) *EL:DiagnosticRuns*) files '("progress.log")
    *EL:DiagnosticProgressPath* (strcat folder "/progress.log"))
  (EL:DiagnosticProgress "BUNDLE_BEGIN")
  (foreach entry (list (cons "run.eld" run)
      (cons "load.eld" (if *EL:MonitorLoadSummary* (list
        (cons 'summary *EL:MonitorLoadSummary*) (cons 'rows *EL:MonitorLoadRows*)
        (cons 'origin *EL:MonitorLoadOrigin*) (cons 'stamp *EL:MonitorLoadStamp*))))
      (cons "association.eld" record)
      (cons "drawing-store.eld" store) (cons "current-result.eld" (EL:DiagnosticResult *EL:Result*)))
    (if (cdr entry)
      (progn (EL:DiagnosticWriteData (strcat folder "/" (car entry)) (cdr entry))
        (setq files (cons (car entry) files)))
      (setq notes (cons (strcat (car entry) "：本次会话没有可用资料。\r\n") notes))))
  ;; Historical shared logs are explicitly named; never collect DWGs, assets,
  ;; previous diagnostic archives or unrelated files by a recursive scan.
  (foreach entry (list (cons "timeline.md" logpath)
      (cons "runtime-ELTRACE-debug.log" (strcat *EL:LiteDataRoot* "output/ELTRACE-debug.log"))
      (cons "runtime-ELPERF.log" (strcat *EL:LiteDataRoot* "output/ELPERF.log"))
      (cons "active-ELTRACE-debug.log" *EL:LogPath*)
      (cons "temp-ELTRACE-debug.log" (strcat (getvar "TEMPPREFIX") "ELTRACE-debug.log"))
      (cons "temp-ELPERF.log" (strcat (getvar "TEMPPREFIX") "ELPERF.log")))
    (setq source (cdr entry) target (strcat folder "/" (car entry)))
    (if (and source (findfile source))
      (progn
        (EL:DiagnosticProgress (strcat "COPY_BEGIN " (car entry)))
        (EL:DiagnosticRequire (vl-file-copy source target)
          (strcat "无法复制诊断日志：" (EL:DiagnosticWindowsPath source)))
        (setq files (cons (car entry) files))
        (EL:DiagnosticProgress (strcat "COPY_DONE " (car entry))))
      (setq notes (cons (strcat (car entry) "：本次未产生或文件不存在。\r\n") notes))))
  (setq metadata (list '(export-format . directory) (cons 'export-time stamp) (cons 'package *EL:PackageMarker*)
    (cons 'drawing (getvar "DWGNAME")) (cons 'drawing-folder (getvar "DWGPREFIX"))
    (cons 'acad-version (getvar "ACADVER")) (cons 'association-status (if record 'verified 'unavailable))
    (cons 'association-issue issue) (cons 'files (append '("README.md" "manifest.eld") (reverse files)))))
  (EL:DiagnosticWriteData (strcat folder "/manifest.eld") metadata)
  (EL:DiagnosticWriteText (strcat folder "/README.md")
    (strcat "# 应急照明诊断资料\r\n日期：" (substr stamp 1 4) "-" (substr stamp 5 2) "-" (substr stamp 7 2)
      "\r\n状态：诊断快照已收集；关联核对状态见 manifest.eld\r\n\r\n"
      "将此文件夹中的资料发给分析人员即可，也可自行压缩。导出不修改图纸。\r\n"
      "timeline.md：当前图纸最近有效运行的耗时、错误、事件及加载时间轴。\r\n"
      "run.eld：同一次运行的完整事件和计时原始数据，未做日志文本截断。\r\n"
      "load.eld：本次会话最近一次插件加载的计时和原始动作；可能晚于 run.eld。\r\n"
      "association.eld：当前图纸最近成功出图或选中旧系统图的已核对关联。\r\n"
      "drawing-store.eld：当前图纸已保存记录的只读快照，不代表所有旧图成员已核对。\r\n"
      "current-result.eld：当前识别结果的业务字段与源图数量；可能与最近一次成功出图不同。\r\n"
      "完整保存记录和出图关联保留在 drawing-store.eld / association.eld，不重复展开内存几何、网络证明及设备库缓存。\r\n"
      "progress.log：逐文件导出检查点；中断时可定位最后进入的阶段。\r\n"
      "runtime / active / temp 日志：已有共享历史文件，可能含此前命令或其他图纸；以 run.eld 为本次运行依据。\r\n"
      "manifest.eld：版本、图纸、导出时间、关联状态和文件清单。\r\n"
      "本次生成的 .eld / .md 为 UTF-8；复制的历史 .log 保持原编码。\r\n"
      "内存记录在关闭图纸后不再保留，缺少资料不会伪造补全。\r\n\r\n"
      (if issue (strcat "关联读取或核对问题：" issue "\r\n") "")
      (EL:MonitorJoin (reverse notes))))
  ;; Date: 2026-10-15. Export completes without a child process or ZIP dependency.
  (EL:DiagnosticProgress "BUNDLE_DONE")
  (EL:DiagnosticWindowsPath folder))
(defun EL:DiagnosticOpenFolder (path / outcome)
  (if (and path (or (vl-file-directory-p path) (findfile path)))
    (progn
      (setq outcome (vl-catch-all-apply 'startapp
        (list "explorer.exe" (strcat (if (vl-file-directory-p path) "\"" "/select,\"")
          (EL:DiagnosticWindowsPath path) "\""))))
      (if (or (not outcome) (vl-catch-all-error-p outcome))
        "无法打开文件夹，请按命令行中的完整路径手动打开。" "已打开诊断文件所在位置。"))
    "诊断资料不存在，请重新导出。"))
(defun EL:DiagnosticExport (/ store record path session logpath issue checked)
  (setq *EL:DiagnosticExportMessage* nil *EL:DiagnosticExportPath* nil *EL:DiagnosticError* nil
    *EL:DiagnosticStage* "EXPORT_BEGIN")
  (if (EL:EnsureRoot)
    (progn
      (setq logpath (EL:ExportDiagnosticRun)
        session (EL:Get (namedobjdict) *EL:DiagramDiagnostics*))
      (setq store (EL:MeasuredCatch 'EL:StoreRead nil))
      (if (vl-catch-all-error-p store)
        (setq issue (vl-catch-all-error-message store) store nil))
      (if session
        (setq record (EL:Get 'record session))
        (if (vl-some '(lambda (row) (EL:Get 'panel-output-handle row)) (EL:Get 'diagrams store))
          (progn
            (setq record (EL:MeasuredCatch 'EL:DiagnosticRecord (list store)))
            (if (vl-catch-all-error-p record)
              (setq issue (EL:DiagnosticFailure record) record nil)))))
      (if record
        (progn
          (setq checked (EL:MeasuredCatch 'EL:DiagnosticRecordValid
            (list record (if session (EL:Get 'store session) store))))
          (if (vl-catch-all-error-p checked)
            (setq issue (EL:DiagnosticFailure checked) record nil))))
      (setq *EL:DiagnosticError* nil)
      (setq path (EL:PerfCall "DIAGNOSTIC_EXPORT" 'EL:DiagnosticBundle (list record store logpath issue)))
      (EL:DiagnosticRequire (and (equal (type path) 'STR) (/= path "")) "诊断资料目录未生成，内存资料已保留。")
      (setq
        *EL:DiagnosticExportPath* path
        *EL:DiagnosticExportMessage* (if issue "已导出诊断资料文件夹；关联异常原因已收入其中。" "已导出诊断资料文件夹，可复制路径或打开查看。"))
      (EL:LogEvent "DIAGNOSTIC_EXPORTED" (list (cons 'path path) (cons 'association-issue issue)))
      (princ (strcat "\n诊断资料文件夹：" path)) path)))
(defun EL:DiagnosticSaveFailure (message / saved stamp notice)
  ;; Date: 2026-10-15. Keep the original failure even if saving its report fails.
  (setq saved *EL:DiagnosticError* stamp (rtos (getvar "CDATE") 2 6)
    notice (strcat "诊断导出失败：" message)
    *EL:DiagnosticExportMessage* notice)
  (if (and *EL:DiagnosticExportPath* (vl-file-directory-p *EL:DiagnosticExportPath*))
    (vl-catch-all-apply 'EL:DiagnosticWriteText
      (list (strcat *EL:DiagnosticExportPath* "\\export-error.txt")
        (strcat "日期：" (substr stamp 1 4) "-" (substr stamp 5 2) "-" (substr stamp 7 2)
          "\r\n状态：导出失败；已完成资料保留\r\n"
          "export-time: " stamp "\r\npackage: " (vl-prin1-to-string *EL:PackageMarker*)
          "\r\nstage: " (cond (*EL:DiagnosticStage*) (T "UNKNOWN"))
          "\r\n" notice "\r\n"))))
  (setq *EL:DiagnosticError* saved)
  (princ (strcat "\n" notice)) notice)
(defun EL:PanelDiagnosticExport (/ outcome)
  ;; Export outside the DCL callback, then reopen with the same input values.
  ;; Date: 2026-10-16. A retained partial directory is not a successful export.
  (setq *EL:DiagnosticExportSucceeded* nil
    outcome (EL:MeasuredCatch 'EL:DiagnosticExport nil)
    *EL:DiagnosticExportSucceeded* (and (not (vl-catch-all-error-p outcome))
      outcome (equal outcome *EL:DiagnosticExportPath*)))
  (cond
    ((vl-catch-all-error-p outcome)
      (EL:DiagnosticSaveFailure (EL:DiagnosticFailure outcome)))
    (*EL:DiagnosticExportMessage*)
    (T "诊断导出未完成，请查看命令行原因。")))
(defun c:ELDIAG (/ *error* perfowner outcome checkpoint failed)
  (defun *error* (message)
    (EL:PerfUnwind checkpoint) (EL:ClearPickHighlights)
    (EL:LogFailure message) (if perfowner (EL:PerfFinish 'failed)) (princ))
  (setq perfowner (EL:PerfStart "ELDIAG") checkpoint *EL:PerfPending*)
  (EL:LogStart)
  (setq outcome (vl-catch-all-apply 'EL:LogCall
    (list "DIAGNOSTIC_COMMAND" nil 'EL:DiagnosticExport nil)))
  (if (vl-catch-all-error-p outcome)
    (progn
      (setq failed T) (EL:PerfUnwind checkpoint)
      (EL:DiagnosticSaveFailure (EL:DiagnosticFailure outcome))
      (EL:LogFailure (EL:DiagnosticFailure outcome)))
    (EL:LogFinish (if outcome 'diagnostic-exported 'diagnostic-not-exported)))
  (EL:ClearPickHighlights)
  (if perfowner (EL:PerfFinish (if failed 'failed (if outcome 'diagnostic-exported 'diagnostic-not-exported)))) (princ))

(defun EL:DiagnosticScriptText () (EL:MonitorJoin '(
"# Date: 2026-10-15. Status: implemented; invoked only by explicit diagnostic export.\nparam([Parameter(Mandatory = $true)][string]$SourceDirectory)\n$ErrorActionPreference = 'Stop'\n$stage = $nul"
"l\n$partial = $null\n$statusPath = $null\n$published = $false\nfunction Complete-ELDiagnostic([string]$result) {\n    [IO.File]::WriteAllText($statusPath + '.tmp', $result, [Text.Encoding]::ASCII)\n"
"    [IO.File]::Move($statusPath + '.tmp', $statusPath)\n}\ntry {\n    $stage = [IO.Path]::GetFullPath($SourceDirectory).TrimEnd('\\', '/')\n    if (-not [IO.Directory]::Exists($stage) -or\n        ["
"IO.Path]::GetFileName($stage) -notmatch '^ELDIAG-[0-9.-]+$') {\n        throw 'Invalid diagnostic staging directory.'\n    }\n    $zipPath = $stage + '.zip'\n    $partial = $zipPath + '.partial'\n "
"   $statusPath = $zipPath + '.status'\n    $cancelPath = $zipPath + '.cancel'\n    if ([IO.File]::Exists($statusPath) -or [IO.File]::Exists($statusPath + '.tmp')) {\n        throw 'Diagnostic com"
"pletion status already exists.'\n    }\n    Add-Type -AssemblyName System.IO.Compression\n    Add-Type -AssemblyName System.IO.Compression.FileSystem\n    if ([IO.File]::Exists($zipPath) -or [IO.F"
"ile]::Exists($partial)) {\n        throw 'Diagnostic archive already exists; nothing was overwritten.'\n    }\n    $files = @([IO.Directory]::GetFiles($stage) | Sort-Object)\n    if ($files.Count "
"-eq 0 -or [IO.Directory]::GetDirectories($stage).Length -ne 0 -or\n        -not [IO.File]::Exists([IO.Path]::Combine($stage, 'README.md'))) {\n        throw 'Incomplete diagnostic staging direct"
"ory.'\n    }\n    # The source is a dedicated snapshot, never the package root or a recursive scan.\n    $stream = [IO.File]::Open($partial, [IO.FileMode]::CreateNew)\n    try {\n        $archive ="
" New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create, $true)\n        try {\n            foreach ($file in $files) {\n                [IO.Compression.ZipFileExte"
"nsions]::CreateEntryFromFile($archive, $file,\n                    [IO.Path]::GetFileName($file), [IO.Compression.CompressionLevel]::Optimal) | Out-Null\n            }\n        } finally { $archi"
"ve.Dispose() }\n    } finally { $stream.Dispose() }\n    # Read every archived byte and compare SHA256 before publishing the final ZIP.\n    $archive = [IO.Compression.ZipFile]::OpenRead($partial"
")\n    try {\n        if ($archive.Entries.Count -ne $files.Count) { throw 'Archive entry count mismatch.' }\n        foreach ($file in $files) {\n            $entry = $archive.GetEntry([IO.Path]:"
":GetFileName($file))\n            if ($null -eq $entry -or $entry.Length -ne (Get-Item -LiteralPath $file).Length) {\n                throw 'Archive entry length mismatch.'\n            }\n       "
"     $sha = [Security.Cryptography.SHA256]::Create()\n            $original = [IO.File]::OpenRead($file)\n            try { $expected = [Convert]::ToBase64String($sha.ComputeHash($original)) }\n "
"           finally { $original.Dispose() }\n            $packed = $entry.Open()\n            try { $actual = [Convert]::ToBase64String($sha.ComputeHash($packed)) }\n            finally { $packed."
"Dispose(); $sha.Dispose() }\n            if ($expected -ne $actual) { throw 'Archive entry hash mismatch.' }\n        }\n    } finally { $archive.Dispose() }\n    if ([IO.File]::Exists($cancelPath"
")) { throw 'Diagnostic export cancelled or timed out.' }\n    [IO.File]::Move($partial, $zipPath)\n    $published = $true\n    # Remove only the known files after publication. No recursive deleti"
"on.\n    foreach ($file in $files) { [IO.File]::Delete($file) }\n    [IO.Directory]::Delete($stage, $false)\n    Complete-ELDiagnostic 'OK'\n    exit 0\n} catch {\n    # A completed verified ZIP is "
"still successful if snapshot cleanup was blocked.\n    if ($published) { Complete-ELDiagnostic 'OK'; exit 0 }\n    try {\n        if ($statusPath -and [IO.Directory]::Exists($stage)) {\n          "
"  [IO.File]::WriteAllText([IO.Path]::Combine($stage, 'bundle-error.txt'),\n                $_.Exception.ToString(), (New-Object Text.UTF8Encoding($false)))\n        }\n    } finally {\n        if "
"($statusPath -and -not [IO.File]::Exists($statusPath)) { Complete-ELDiagnostic 'ERROR' }\n    }\n    exit 1\n}\n"
)))
