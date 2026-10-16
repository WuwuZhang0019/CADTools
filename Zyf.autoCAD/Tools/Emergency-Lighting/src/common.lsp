;; AutoCAD 2020 trial, GB2312 source and system-codepage data. Pure functions shared by CAD and host checks.
(defun EL:Get (key data) (cdr (assoc key data)))
(defun EL:Put (key value data / old)
  (if (setq old (assoc key data))
    (subst (cons key value) old data)
    (append data (list (cons key value)))))
(defun EL:Unique (items / out item)
  (foreach item items (if (not (member item out)) (setq out (cons item out))))
  (reverse out))
(defun EL:Issue (code object detail)
  (list (cons 'code code) (cons 'object object) (cons 'detail detail)))
(defun EL:Number (x) (and (numberp x) (= x x) (< (abs x) 1.0e100)))
(defun EL:NonNegative (x) (and (EL:Number x) (>= x 0)))
(defun EL:Point (p)
  (and (listp p) (= (length p) 3)
       (EL:Number (car p)) (EL:Number (cadr p)) (EL:Number (caddr p))))
(defun EL:Point3 (p) (list (car p) (cadr p) (cond ((caddr p)) (T 0.0))))
(defun EL:V+ (a b) (mapcar '+ a b))
(defun EL:V- (a b) (mapcar '- a b))
(defun EL:V* (s a) (mapcar '(lambda (v) (* s v)) a))
(defun EL:Dot (a b) (apply '+ (mapcar '* a b)))
(defun EL:Cross (a b) (- (* (car a) (cadr b)) (* (cadr a) (car b))))
(defun EL:Norm (v) (sqrt (EL:Dot v v)))
(defun EL:Unit (v / n)
  (if (> (setq n (EL:Norm v)) 1.0e-9) (EL:V* (/ 1.0 n) v)))
(defun EL:Last (xs) (car (reverse xs)))
(defun EL:Strings (xs / ok x)
  (setq ok (listp xs))
  (foreach x xs (if (not (equal (type x) 'STR)) (setq ok nil))) ok)
(defun EL:ParamsValid (p / ok key)
  (setq ok T)
  (foreach key '(eps_touch eps_boundary eps_perp eps_z theta_max R0 Dmax)
    (if (not (EL:NonNegative (EL:Get key p))) (setq ok nil)))
  (and ok (or (not (assoc 'eps_device p)) (EL:NonNegative (EL:Get 'eps_device p)))
       (< (EL:Get 'theta_max p) (/ pi 2.0))
       (> (EL:Get 'R0 p) 0) (<= (EL:Get 'R0 p) (EL:Get 'Dmax p))
       (> (EL:Get 'Dmax p) (EL:Get 'eps_touch p))))
(defun EL:LayerAllowed (a b config)
  (and (member a (EL:Get 'wire-layers config))
       (member b (EL:Get 'wire-layers config))
       (or (equal a b) (member (list a b) (EL:Get 'layer-pairs config))
           (member (list b a) (EL:Get 'layer-pairs config)))))
(defun EL:Hash (s / h n)
  (setq h 5381)
  (foreach n (vl-string->list s) (setq h (rem (+ (* h 33.0) n) 2147483629.0)))
  (rtos h 2 0))
(defun EL:StableData (data / tail items result item)
  ;; Date: 2026-10-09. Iterate list tails: stack depth follows nesting, not entity count.
  (cond ((equal (type data) 'ENAME) (list 'handle (cdr (assoc 5 (entget data)))))
        ;; Date: 2026-10-15. Native list traversal avoids rebuilding every
        ;; proper-list tail twice. Dotted tails retain the exact legacy path.
        ((and (listp data) (vl-list-length data))
          (mapcar '(lambda (item) (if (member (type item) '(LIST ENAME))
            (EL:StableData item) item)) data))
        ((listp data)
          (setq tail data)
          (while (and tail (listp tail))
            ;; Date: 2026-10-15. Atomic values already have their exact stable
            ;; representation. Recurse only for nested lists and entity names.
            (setq item (car tail)
              items (cons (if (member (type item) '(LIST ENAME))
                (EL:StableData item) item) items) tail (cdr tail)))
          (setq result (if (equal (type tail) 'ENAME) (EL:StableData tail) tail))
          (foreach item items (setq result (cons item result))) result)
        (T data)))
(defun EL:Signature (data) (vl-prin1-to-string (EL:StableData data)))
(defun EL:StableSnapshot (snapshot / owner epoch)
  ;; Date: 2026-10-15. Builders retain immutable alist rows. Convert each
  ;; identical row once inside this synchronous recognition pass, including
  ;; unknown fields. Changed rows, writes, interaction and DWG changes miss.
  (if (and *EL:RecognitionPass* (vl-list-length snapshot))
    (progn
      (setq owner (namedobjdict) epoch *EL:FreshEpoch*)
      (if (not (and (equal owner *EL:StableSnapshotOwner*) (equal epoch *EL:StableSnapshotEpoch*)))
        (setq *EL:StableSnapshotMemo* nil *EL:StableSnapshotOwner* owner *EL:StableSnapshotEpoch* epoch))
      (mapcar 'EL:StableSnapshotRow snapshot))
    (EL:StableData snapshot)))
(defun EL:StableSnapshotRow (row / saved value)
  (if (setq saved (vl-some '(lambda (item) (if (eq row (car item)) item)) *EL:StableSnapshotMemo*))
    (cadr saved)
    (progn
      (setq value (EL:StableData row)
        *EL:StableSnapshotMemo* (cons (list row value) *EL:StableSnapshotMemo*)) value)))
(defun EL:RecognitionRules (cfg / rows key)
  (foreach key '(wire-styles auto-panel concentrated-trunk circuit-starts wire-layers panel-layers device-layers leader-layers panel-names device-names leader-names
      layer-pairs params calibrated gap-pairs leader-pairs roles exits)
    (setq rows (cons (cons key (EL:Get key cfg)) rows)))
  ;; Date: 2026-10-13. Older recognition must be rebuilt for exact reachable traversal.
  (cons '(reachable-contact-policy . 2) (cons '(junction-policy . 1) (cons '(number-branch-policy . 1)
    (cons '(simple-gap-policy . 1) (cons '(box-policy . 20) (cons '(gap-policy . 10) (reverse rows))))))))
;; Date: 2026-10-11. Report which freshness condition failed.
(defun EL:SourceSignatureCore (signature)
  (if (and (listp signature) (equal (car signature) 'EL_FIXED_SOURCE_V1))
    (list 'EL_FIXED_SOURCE_V1 (vl-remove-if '(lambda (row) (equal (car row) 'network-proof)) (cadr signature)))
    signature))
(defun EL:SourceCurrent (result cfg fresh / drawing rules snapshot)
  (setq drawing (equal (EL:Get 'drawing result) (EL:Get 'drawing cfg))
    rules (equal (EL:Get 'rules result) (EL:RecognitionRules cfg))
    snapshot (equal (EL:SourceSignatureCore (EL:Get 'signature fresh))
      (EL:SourceSignatureCore (EL:Get 'signature (EL:Get 'snapshot result)))))
  (if (not (and drawing rules snapshot))
    (EL:LogEvent "SOURCE_COMPARE_FAILED" (list (cons 'drawing-equal drawing)
      (cons 'rules-equal rules) (cons 'snapshot-equal snapshot))))
  (if (not snapshot) (EL:LogSnapshotDifference (EL:Get 'snapshot result) fresh))
  (and drawing rules snapshot))
(defun EL:OptionLabel (option)
  (cond ((equal option 'cap300) "0.3kW") ((equal option 'cap600) "0.6kW") ((equal option 'cap1000) "1kW")
        ((equal option 'normal) "普通") ((equal option 'ground) "地面") ((equal option 'reserve) "预留") (T "未选择")))
(defun EL:OnlyKeys (data keys / ok row seen)
  (setq ok (listp data))
  (foreach row data
    (if (or (not (listp row)) (not (member (car row) keys)) (member (car row) seen))
      (setq ok nil))
    (setq seen (cons (car row) seen))) ok)
(princ)

(defun EL:Tick (/ value)
  (setq value (vl-catch-all-apply 'getvar (list "MILLISECS")))
  (if (numberp value) value 0))
(defun EL:Elapsed (start) (max 0 (- (EL:Tick) start)))

;; Date: 2026-10-11. Command-scoped P0 counters, independent of business logs.
;; Inclusive stages overlap; user intervals are a union and are never summed twice.
(defun EL:PerfDelta (start stop)
  (if (< stop start) (+ (- stop start) 4294967296.0) (- stop start)))
(defun EL:PerfSet (key value)
  (if *EL:PerfActive* (setq *EL:PerfMetrics* (EL:Put key value *EL:PerfMetrics*))) nil)
(defun EL:PerfCount (key amount)
  (if *EL:PerfActive*
    (EL:PerfSet key (+ (cond ((EL:Get key *EL:PerfMetrics*)) (T 0)) amount))) nil)
(defun EL:PerfWaiting (/ elapsed)
  (setq elapsed *EL:PerfWaitMS*)
  (if (> *EL:PerfWaitDepth* 0)
    (setq elapsed (+ elapsed (EL:PerfDelta *EL:PerfWaitStart* (EL:Tick))))) elapsed)
(defun EL:PerfStart (commandname / stamp tick key)
  (if (not *EL:PerfActive*)
    (progn
      (setq tick (vl-catch-all-apply 'getvar (list "MILLISECS")))
      (setq *EL:PerfActive* T *EL:PerfCommand* commandname *EL:PerfStarted* (if (numberp tick) tick 0)
        *EL:DiagnosticsDeferred* nil *EL:DeferredLogEvents* nil
        *EL:PerfMetrics* nil *EL:PerfStages* nil *EL:PerfPending* nil *EL:PerfMarks* nil *EL:StoreReadCache* nil *EL:NetworkMemo* nil *EL:CollectMemo* nil *EL:StatisticsMemo* nil *EL:SplitCache* nil *EL:DLCache* nil *EL:DLSessionSnapshot* nil
        *EL:PerfWaitMS* 0 *EL:PerfWaitDepth* 0 *EL:PerfSerial* 0 *EL:PerfOutcome* nil
        *EL:StoreReadScope* (1+ (cond (*EL:StoreReadScope*) (T 0))))
      (setq stamp (vl-catch-all-apply 'getvar (list "CDATE")))
      (setq *EL:MonitorRows* nil *EL:MonitorError* nil *EL:MonitorUIStack* nil
        *EL:MonitorStamp* (if (numberp stamp) (rtos stamp 2 6) "unavailable"))
      (EL:PerfSet "date" (if (numberp stamp) stamp "unavailable"))
      (EL:PerfSet "clock-available" (if (numberp tick) T nil))
      (foreach key '("recognize-fixed-calls" "store-read-calls" "store-write-calls"
          "entity-write-attempts" "entity-write-returned" "master-write-attempts"
          "block-create-attempts" "text-create-attempts" "transaction-starts"
          "transaction-failures" "log-open-attempts" "log-write-attempts" "log-close-attempts" "panel-submits"
          "store-read-cache-hits" "store-read-cache-misses"
          "source-collect-calls" "source-selection-entities" "source-block-bounds-reads"
          "source-native-entity-checks" "source-native-bounds-checks" "source-derived-reuses"
          "source-wire-record-reads" "device-contour-reads" "device-template-reuses"
          "network-build-calls" "network-verified-reuses" "network-geometry-checks"
          "number-scopes" "number-source-handles" "number-problems"
          "number-source-read-attempts" "number-source-read-failures" "number-freshness-checks"
          "device-library-loads" "device-library-writes" "device-library-matches" "device-library-unknown"
          "device-legend-loads" "device-legend-builds")
        (EL:PerfSet key 0)) T)))
(defun EL:PerfBegin (stage / token wait parent paused)
  (if *EL:PerfActive*
    (progn
      ;; Date: 2026-10-13. DCL callbacks do work inside start_dialog.
      ;; Pause its input clock until the callback returns, including error unwind.
      (if (and (equal stage "UI_ACTION") (> *EL:PerfWaitDepth* 0))
        (setq paused *EL:PerfWaitDepth*
          *EL:PerfWaitMS* (EL:PerfWaiting) *EL:PerfWaitDepth* 0))
      (setq wait (member stage '("USER_INPUT" "PLACEMENT_INPUT"))
        parent (if *EL:PerfPending* (EL:Get 'stage (car *EL:PerfPending*)))
        *EL:PerfSerial* (1+ *EL:PerfSerial*)
        token (list (cons 'id *EL:PerfSerial*) (cons 'stage stage) (cons 'start (EL:Tick))
          (cons 'wait-before (EL:PerfWaiting)) (cons 'interactive (if wait T nil)) (cons 'parent parent)
          (cons 'parent-id (if *EL:PerfPending* (EL:Get 'id (car *EL:PerfPending*)) 0))
          (cons 'label *EL:MonitorLabel*) (cons 'resume-wait paused)))
      (if wait
        (progn
          (if (= *EL:PerfWaitDepth* 0) (setq *EL:PerfWaitStart* (EL:Get 'start token)))
          (setq *EL:PerfWaitDepth* (1+ *EL:PerfWaitDepth*))))
      (setq *EL:PerfPending* (cons token *EL:PerfPending*)) token)))
(defun EL:PerfEnd (token status / stage row elapsed waited key parents)
  (if (and *EL:PerfActive* token (member token *EL:PerfPending*))
    (progn
      (if (EL:Get 'interactive token)
        (progn
          (setq *EL:PerfWaitDepth* (1- *EL:PerfWaitDepth*))
          (if (= *EL:PerfWaitDepth* 0)
            (setq *EL:PerfWaitMS* (+ *EL:PerfWaitMS* (EL:PerfDelta *EL:PerfWaitStart* (EL:Tick)))))))
      (setq stage (EL:Get 'stage token) row (EL:Get stage *EL:PerfStages*)
        elapsed (EL:PerfDelta (EL:Get 'start token) (EL:Tick))
        waited (max 0 (- (EL:PerfWaiting) (EL:Get 'wait-before token))))
      (foreach key (list (cons 'calls 1) (cons 'inclusive-ms elapsed)
          (cons 'program-ms (max 0 (- elapsed waited))) (cons 'interrupted (if (equal status 'returned) 0 1)))
        (setq row (EL:Put (car key) (+ (cond ((EL:Get (car key) row)) (T 0)) (cdr key)) row)))
      (setq parents (EL:Get 'parents row))
      (if (and (EL:Get 'parent token) (not (member (EL:Get 'parent token) parents)))
        (setq row (EL:Put 'parents (cons (EL:Get 'parent token) parents) row)))
      (setq *EL:PerfStages* (EL:Put stage row *EL:PerfStages*)
        *EL:MonitorRows* (cons (append token (list (cons 'elapsed-ms elapsed)
          (cons 'program-ms (max 0 (- elapsed waited))) (cons 'status status))) *EL:MonitorRows*)
        *EL:PerfPending* (vl-remove token *EL:PerfPending*))
      (if (EL:Get 'resume-wait token)
        (setq *EL:PerfWaitDepth* (EL:Get 'resume-wait token) *EL:PerfWaitStart* (EL:Tick))))) nil)
(defun EL:PerfUnwind (checkpoint)
  (while (and *EL:PerfPending* (not (equal checkpoint *EL:PerfPending*)))
    (EL:PerfEnd (car *EL:PerfPending*) 'interrupted)) nil)
(defun EL:FreshBoundary ()
  ;; Date: 2026-10-11. Input, native commands, writes and unknown callbacks
  ;; invalidate the current operation's sampled source; never cache a command.
  (setq *EL:FreshProofContext* nil *EL:FreshEpoch* (1+ (cond (*EL:FreshEpoch*) (T 0)))) nil)
(defun EL:PerfCall (stage function arguments / token result *EL:MonitorLabel*)
  (if (member stage '("USER_INPUT" "PLACEMENT_INPUT" "PANEL_DIALOG")) (EL:FreshBoundary))
  (if (and *EL:PerfActive* (or (member stage
      '("USER_INPUT" "PLACEMENT_INPUT" "PANEL_DIALOG" "RECOGNIZE_FIXED_RUN" "LOAD_ROOT" "LOAD_LIBRARY" "PICK_PANEL" "PICK_TRUNK"
        "LOAD_ROOT_SEARCH" "LOAD_RUNTIME" "LOAD_RUNTIME_TEXT" "LOAD_RUNTIME_ASSETS"
        "PANEL_START_LOAD" "PANEL_START_NEW" "PANEL_START_INIT" "PANEL_START_BUTTONS" "PANEL_START_WAIT"
        "PANEL_HISTORY_READ" "PANEL_HISTORY_RESTORE" "PANEL_FILL" "PREPARE_PANEL" "NEW_RECORD" "READ_STORE"
        "RECOGNIZE_FIXED" "RECOGNIZE_TRUNK" "SAVE_GENERATION_DRAFT" "STORE_REPLACE_PAYLOAD"
        "UNDO_BEGIN" "UNDO_END" "TX_MARKER_CREATE" "RECOVERY_UNDO_END"
        "SIMPLE_COLLECT" "SIMPLE_NETWORK" "SOURCE_NATIVE_VERIFY" "NETWORK_VERIFY_GEOMETRY" "NETWORK_BUILD" "SPLIT_NETWORK" "CIRCUIT_NUMBER_SCOPE"
        "COMPARE_SOURCE_NUMBER" "PRE_GENERATE_FRESH" "FRESH_SOURCE_SCAN"
        "CCKK2" "CCKK2_CREATE" "SAVE_CREATED_DIAGRAM" "COMPONENT_INDEX" "STORE_CURRENT_BOX"
        "TX_WRITE" "STORE_READ" "STORE_DECODE" "STORE_CACHE_CHECK" "STORE_SERIALIZE"
        "STORE_PARSE" "STORE_READBACK" "STORE_CONTEXT_COMMIT" "STORE_CONTEXT_READ"
        "STORE_MIGRATE_BACKUP" "STORE_STAGE_BUILD"
        "STORE_COMPACT" "STORE_PACK_INTS" "STORE_NATIVE_ENCODE" "STORE_NATIVE_DECODE" "STORE_EXPAND"
        "STORE_UNPACK_INTS" "STORE_VALUE_DECODE"
        "DIAGRAM_VIEW" "DIAGNOSTIC_EXPORT" "DEVICE_LIBRARY_LOAD" "DEVICE_LEGEND"))
      (and *EL:PerfDetail* (member stage
        '("STORE_SCHEMA" "STORE_REPLACE_PAYLOAD" "CCKK2_INSERT_BLOCK" "CCKK_POWER_TEXT"
          "TAG_ENTITY" "UNDO_BEGIN" "UNDO_END" "COMPARE_SOURCE" "SNAPSHOT_SIGNATURE" "CIRCUIT_TRACE")))))
    (progn
      (setq *EL:MonitorLabel* (if (equal (type function) 'SYM) (vl-symbol-name function) stage))
      (if (and (equal stage "USER_INPUT") (equal (type (car arguments)) 'STR))
        (setq *EL:MonitorLabel* (strcat *EL:MonitorLabel* " " (car arguments))))
      (setq token (EL:PerfBegin stage))))
  ;; Keep native return values and exceptions. Caught transactions unwind their frames.
  (setq result (apply function arguments))
  ;; A callback may sample the source and then change it during this input.
  ;; That sample cannot survive the return to the enclosing operation.
  (if (member stage '("USER_INPUT" "PLACEMENT_INPUT" "PANEL_DIALOG")) (EL:FreshBoundary))
  (EL:PerfEnd token 'returned)
  (if (and result (equal stage "PLACEMENT_INPUT")) (EL:PerfMark "placement-confirmed")) result)
(defun EL:PerfInput (function arguments)
  (EL:PerfCall "USER_INPUT" function arguments))
(defun EL:PerfWrite (function arguments / result)
  ;; Attempts count the actual interface invocation, including nil/error returns.
  (EL:FreshBoundary)
  (EL:PerfCount "entity-write-attempts" 1)
  (if *EL:PerfDetail* (EL:PerfCount (strcat "write/" (vl-symbol-name function)) 1))
  (setq result (apply function arguments))
  (EL:FreshBoundary)
  (EL:PerfCount "entity-write-returned" 1) result)
(defun EL:PerfMark (key)
  (if *EL:PerfActive*
    (setq *EL:PerfMarks* (EL:Put key (list (EL:Tick) (EL:PerfWaiting)) *EL:PerfMarks*))) nil)
(defun EL:PerfMarkDuration (key / mark elapsed)
  (if (setq mark (EL:Get key *EL:PerfMarks*))
    (progn (setq elapsed (EL:PerfDelta (car mark) (EL:Tick)))
      (list (cons 'inclusive-ms elapsed)
        (cons 'program-ms (max 0 (- elapsed (- (EL:PerfWaiting) (cadr mark)))))))))
(defun EL:PerfAppend (path line / file result closed)
  (if (setq file (open path "a"))
    (progn
      (setq result (vl-catch-all-apply 'write-line (list line file))
        closed (vl-catch-all-apply 'close (list file)))
      (and (not (vl-catch-all-error-p result)) (not (vl-catch-all-error-p closed))))))
(defun EL:PerfReport (summary / path line written folder)
  (setq line (strcat "PERF | " (vl-prin1-to-string summary)))
  (if (and (equal (type *EL:Root*) 'STR) (/= *EL:Root* ""))
    (progn
      (vl-catch-all-apply 'vl-mkdir (list (strcat *EL:LiteDataRoot* "output")))
      (setq path (strcat *EL:LiteDataRoot* "output/ELPERF.log")
        written (vl-catch-all-apply 'EL:PerfAppend (list path line)))))
  (if (or (vl-catch-all-error-p written) (not written))
    (progn
      (setq folder (vl-catch-all-apply 'getvar (list "TEMPPREFIX")))
      (if (and (equal (type folder) 'STR) (/= folder ""))
        (setq path (strcat folder "ELPERF.log")
          written (vl-catch-all-apply 'EL:PerfAppend (list path line))))))
  (princ (strcat "\n性能汇总：总区间 " (itoa (fix (EL:Get 'total-ms summary)))
    " ms，交互区间 " (itoa (fix (EL:Get 'interaction-ms summary)))
    " ms，程序区间 " (itoa (fix (EL:Get 'program-ms summary))) " ms。"))
  (if (and (not (vl-catch-all-error-p written)) written)
    (princ (strcat "\n性能记录：" path))
    (princ "\n性能记录写入失败；汇总保留在 *EL:PerfLastSummary*。")) nil)
(defun EL:PerfFinish (status / elapsed waited summary)
  (if *EL:PerfActive*
    (progn
      (EL:PerfUnwind nil)
      (setq elapsed (EL:PerfDelta *EL:PerfStarted* (EL:Tick)) waited (EL:PerfWaiting)
        summary (list '(schema . 1) (cons 'command *EL:PerfCommand*) (cons 'status status)
          (cons 'last-outcome *EL:PerfOutcome*) (cons 'package *EL:PackageMarker*)
          (cons 'detail (if *EL:PerfDetail* T nil)) (cons 'business-logs (if *EL:PerfLogsOff* 'off 'on))
          (cons 'total-ms elapsed) (cons 'interaction-ms waited) (cons 'program-ms (max 0 (- elapsed waited)))
          (cons 'after-submit (EL:PerfMarkDuration "panel-submit"))
          (cons 'after-placement (EL:PerfMarkDuration "placement-confirmed"))
          (cons 'after-graphics (EL:PerfMarkDuration "graphics-complete"))
          (cons 'metrics *EL:PerfMetrics*) (cons 'stages *EL:PerfStages*)))
      ;; Snapshot before reporting: summary I/O is outside all business measurements.
      (setq *EL:PerfLastSummary* summary *EL:PerfActive* nil *EL:PerfPending* nil
        *EL:PerfMetrics* nil *EL:PerfStages* nil *EL:PerfMarks* nil *EL:PerfLogOwner* nil *EL:StoreReadCache* nil)
      (if *EL:DiagnosticsDeferred*
        ;; Date: 2026-10-15. Do not format or write diagnostics on the exit
        ;; path. Keep one completed run per open drawing for the export button.
        (if (or *EL:MonitorError* (EL:Get 'after-submit summary)
            (> (cond ((EL:Get "recognize-fixed-calls" (EL:Get 'metrics summary))) (T 0)) 0)
            (not (EL:Get (namedobjdict) *EL:DiagnosticRuns*)))
          (setq *EL:DiagnosticRuns* (EL:Put (namedobjdict)
          (list (cons 'summary summary) (cons 'rows *EL:MonitorRows*)
            (cons 'origin *EL:PerfStarted*) (cons 'stamp *EL:MonitorStamp*)
            (cons 'error *EL:MonitorError*) (cons 'events *EL:DeferredLogEvents*)
            (cons 'load-summary *EL:MonitorLoadSummary*) (cons 'load-rows *EL:MonitorLoadRows*)
            (cons 'load-origin *EL:MonitorLoadOrigin*) (cons 'load-stamp *EL:MonitorLoadStamp*))
          *EL:DiagnosticRuns*)))
        (progn
          (vl-catch-all-apply 'EL:PerfReport (list summary))
          (EL:MonitorReport summary)))))
  (setq *EL:StoreReadCache* nil *EL:NetworkMemo* nil *EL:CollectMemo* nil *EL:StatisticsMemo* nil *EL:SplitCache* nil *EL:DLCache* nil *EL:DLSessionSnapshot* nil) nil)
(defun c:ELPERF (/ option)
  (if *EL:PerfActive* (princ "\n请结束当前统计或生成后再调整性能采样。")
    (progn
      (princ (strcat "\n性能采样：" (if *EL:PerfDetail* "细分" "汇总")
        "；业务日志：" (if *EL:PerfLogsOff* "关闭（仅对照测量）" "开启")))
      (initget "LogsOn LogsOff Detail Summary")
      (setq option (getkword "\n[LogsOn开启日志/LogsOff关闭日志对照/Detail细分计量/Summary汇总计量] <保持>："))
      (cond ((equal option "LogsOn") (setq *EL:PerfLogsOff* nil))
        ((equal option "LogsOff") (setq *EL:PerfLogsOff* T))
        ((equal option "Detail") (setq *EL:PerfDetail* T))
        ((equal option "Summary") (setq *EL:PerfDetail* nil)))
      (princ "\n仅影响本次加载会话的测量；ELPERF.log 独立保留，日志对照结束后请恢复 LogsOn。"))) (princ))

;; Date: 2026-10-09. Diagnostics never change recognition or propagate I/O errors.
(defun EL:LogText (value / textdata)
  (setq textdata (vl-catch-all-apply 'vl-prin1-to-string (list value)))
  (if (vl-catch-all-error-p textdata) "<unprintable>"
    (if (> (strlen textdata) 16000) (strcat (substr textdata 1 16000) " <truncated>") textdata)))
(defun EL:LogAppend (line / logfile result closed started)
  (EL:PerfCount "log-open-attempts" 1)
  (if (and *EL:PerfActive* *EL:PerfDetail*) (setq started (EL:Tick)))
  (if (setq logfile (open *EL:LogPath* "a"))
    (progn
      (EL:PerfCount "log-write-attempts" 1)
      (setq result (vl-catch-all-apply 'write-line (list line logfile)))
      (setq closed (vl-catch-all-apply 'close (list logfile)))
      (EL:PerfCount "log-close-attempts" 1)
      (if started (EL:PerfCount "log-io-ms" (EL:PerfDelta started (EL:Tick))))
      (and (not (vl-catch-all-error-p result)) (not (vl-catch-all-error-p closed))))))
;; Date: 2026-10-10. Retry in TEMP when the runtime output is unavailable.
(defun EL:LogFallback (line / folder previous result)
  (if (not *EL:LogFallbackUsed*)
    (progn
      (setq *EL:LogFallbackUsed* T previous *EL:LogPath*
        folder (vl-catch-all-apply 'getvar (list "TEMPPREFIX")))
      (if (and (equal (type folder) 'STR) (/= folder ""))
        (progn
          (setq *EL:LogPath* (strcat folder "ELTRACE-debug.log"))
          (setq result (vl-catch-all-apply 'EL:LogAppend
            (list (strcat "LOG_FALLBACK | original-path=" (EL:LogText previous)
              " | last-context=" (EL:LogText *EL:LogLast*) " | stack=" (EL:LogText *EL:LogStack*)))))
          (if (and (not (vl-catch-all-error-p result)) result)
            (setq result (vl-catch-all-apply 'EL:LogAppend (list line))))
          (and (not (vl-catch-all-error-p result)) result))))))
(defun EL:LogVisible (stage)
  (or *EL:LogVerbose* (not (member stage
    '("POLYLINE_DXF_ROW" "POLYLINE_SEGMENT" "POLYLINE_INPUT" "POLYLINE_DATA_RESULT"
      "ENTER POLYLINE_TRANS" "LEAVE POLYLINE_TRANS" "POLYLINE_TRANS_RESULT"
      "ENTER CURVE_TRANS" "LEAVE CURVE_TRANS" "CURVE_TRANS_RESULT"
      "ENTER INSERT_TRANS" "LEAVE INSERT_TRANS" "INSERT_TRANS_RESULT" "INSERT_MATRIX_INPUT"
      "ENTER SOLID_TRANS" "LEAVE SOLID_TRANS" "SOLID_TRANS_RESULT" "POLYLINE_NORMAL"
      "CONTOUR_ENTITY" "CONTOUR_FILTER_INPUT" "CONTOUR_NEXT"
      "ENTER CONTOUR_TRANSFORM" "LEAVE CONTOUR_TRANSFORM" "CONTOUR_TRANSFORM_RESULT")))))
(defun EL:LogEvent (stage context / line result started)
  (if *EL:LogActive*
    (progn
      (setq *EL:LogSequence* (1+ *EL:LogSequence*)
            *EL:LogLast* (list stage context))
      ;; Keep current failure context in memory; avoid per-vertex file I/O by default.
      (if (and (not *EL:PerfLogsOff*) *EL:DiagnosticsDeferred* (EL:LogVisible stage))
        (setq *EL:DeferredLogEvents* (cons (list *EL:LogSequence* stage context) *EL:DeferredLogEvents*)))
      (if (and (not *EL:PerfLogsOff*) (not *EL:DiagnosticsDeferred*) *EL:LogPath* (EL:LogVisible stage))
        (progn
          (if (and *EL:PerfActive* *EL:PerfDetail*) (setq started (EL:Tick)))
          (setq line (strcat (itoa *EL:LogSequence*) " | " stage " | " (EL:LogText context)))
          (if started (EL:PerfCount "log-format-ms" (EL:PerfDelta started (EL:Tick))))
          (setq result (vl-catch-all-apply 'EL:LogAppend (list line)))
          (if (or (and (not (vl-catch-all-error-p result)) result) (EL:LogFallback line)) (setq *EL:LogWritten* T)
            (setq *EL:LogIOFailed* T *EL:LogPath* nil))))))
  nil)
(defun EL:LogStart (/ stamp)
  (setq *EL:PerfLogOwner* (EL:PerfStart "ELSTAT/ELTRACE/ELPOWER"))
  (setq *EL:LogActive* T *EL:LogPath* nil *EL:LogStack* nil *EL:LogLast* nil
        *EL:LogSequence* 0 *EL:LogWritten* nil *EL:LogIOFailed* nil *EL:LogFallbackUsed* nil)
  (EL:LogAttach)
  (setq stamp (vl-catch-all-apply 'getvar (list "CDATE")))
  (EL:LogEvent "BEGIN" (list (cons 'command "ELSTAT/ELTRACE/ELPOWER") (cons 'diagnostics "031") (cons 'verbose *EL:LogVerbose*)
    (cons 'date (if (numberp stamp) stamp "unavailable")))))
(defun EL:LogAttach (/ stamp)
  (if (and *EL:LogActive* (not *EL:DiagnosticsDeferred*) (not *EL:LogPath*) (not *EL:LogIOFailed*)
           (equal (type *EL:Root*) 'STR) (/= *EL:Root* ""))
    (progn
      (vl-catch-all-apply 'vl-mkdir (list (strcat *EL:LiteDataRoot* "output")))
      (setq *EL:LogPath* (strcat *EL:LiteDataRoot* "output/ELTRACE-debug.log")
            stamp (vl-catch-all-apply 'getvar (list "CDATE")))
      (EL:LogEvent "ATTACH" (list (cons 'diagnostics "031")
        (cons 'date (if (numberp stamp) stamp "unavailable")))))))
(defun EL:LogCall (stage context function arguments / result started)
  ;; Leave the stack intact on an AutoLISP error; the command's *error* records it.
  (if *EL:LogActive*
    (progn (setq *EL:LogStack* (cons (list stage context) *EL:LogStack*))
      (EL:LogEvent (strcat "ENTER " stage) context)))
  (setq started (if *EL:LogActive* (EL:Tick)) result (EL:PerfCall stage function arguments))
  (if *EL:LogActive*
    (progn
      (EL:LogEvent (strcat "LEAVE " stage) (list (cons 'elapsed-ms (EL:Elapsed started)) (cons 'result-type (type result))))
      (setq *EL:LogStack* (cdr *EL:LogStack*))))
  result)
(defun EL:MeasuredCatch (function arguments / pending stack result)
  ;; Date: 2026-10-13. Close only the frames created inside this catch.
  (setq pending *EL:PerfPending* stack *EL:LogStack*
    result (vl-catch-all-apply function arguments))
  (if (vl-catch-all-error-p result)
    (progn
      (EL:LogEvent "CAUGHT_ERROR" (list (cons 'message (vl-catch-all-error-message result))
        (cons 'frames *EL:LogStack*)))
      (EL:PerfUnwind pending)
      (setq *EL:LogStack* stack))) result)
(defun EL:LogEntity (entity)
  (EL:LogEntityData (entget entity)))
(defun EL:LogEntityData (data)
  ;; Date: 2026-10-15. Reuse the same fresh DXF read for diagnostic context.
  (list (cons 'handle (cdr (assoc 5 data))) (cons 'type (cdr (assoc 0 data)))
    (cons 'layer (cdr (assoc 8 data))) (cons 'block (cdr (assoc 2 data)))
    (cons 'dxf (vl-remove-if-not '(lambda (pair) (member (car pair)
      '(0 2 5 8 10 11 38 40 41 42 43 50 51 60 70 90 210 410))) data))))
(defun EL:LogFinish (status)
  (if *EL:PerfActive* (setq *EL:PerfOutcome* status))
  (if *EL:LogActive*
    (progn
      (EL:LogEvent "END" status)
      (cond
        (*EL:DiagnosticsDeferred* nil)
        (*EL:PerfLogsOff* nil)
        (*EL:LogIOFailed* (princ "\n诊断日志写入失败；请保留命令行的失败阶段和上下文。"))
        (*EL:LogWritten* (princ (strcat "\n诊断日志：" *EL:LogPath*)))
        (T (princ "\n未建立日志文件；请保留命令行信息。")))))
  (setq *EL:LogActive* nil *EL:LogStack* nil)
  (if *EL:PerfLogOwner* (EL:PerfFinish status)))
(defun EL:LogFailure (message / laststate stack)
  (setq *EL:MonitorError* message)
  (setq laststate *EL:LogLast* stack *EL:LogStack*)
  (EL:LogEvent "ERROR" (list (cons 'message message) (cons 'stack stack) (cons 'last-event laststate)))
  (princ (strcat "\n原始错误：" (EL:LogText message)
    "\n失败阶段：" (EL:LogText stack) "\n最后上下文：" (EL:LogText laststate)))
  (EL:LogFinish 'failed))

;; Date: 2026-10-09. Managed outputs never enter source recognition.
(defun EL:DiagramTag (entity / data)
  (if entity
    (progn (setq data (entget entity '("EL_FIXED_V1")))
      (cdr (assoc "EL_FIXED_V1" (cdr (assoc -3 data)))))))
(defun EL:ManagedEntity (entity) (if (EL:DiagramTag entity) T nil))

;; Date: 2026-10-11. Display numbers never replace persistent panel identity.
(defun EL:PanelNumber (data / value)
  (setq value (EL:Get 'panel-number data))
  (if (and (equal (type value) 'STR) (/= (vl-string-trim " \t\r\n" value) ""))
    value "暂无编号"))

;; Date: 2026-10-11. Bounded evidence for exact snapshot differences, without parsing long strings.
(defun EL:StringDifference (before after / index start)
  (if (and (equal (type before) 'STR) (equal (type after) 'STR))
    (progn
      (setq index (cond ((vl-string-mismatch before after)) (T 0)) start (max 1 (- (1+ index) 100)))
      (list (cons 'offset index) (cons 'before-length (strlen before)) (cons 'after-length (strlen after))
        (cons 'before (substr before start 240)) (cons 'after (substr after start 240))))
    (list (cons 'before-type (type before)) (cons 'after-type (type after)))))
(defun EL:LogSnapshotDifference (before after / key a b keys typed)
  (setq typed (or
    (and (listp (EL:Get 'signature before)) (equal (car (EL:Get 'signature before)) 'EL_FIXED_SOURCE_V1))
    (and (listp (EL:Get 'signature after)) (equal (car (EL:Get 'signature after)) 'EL_FIXED_SOURCE_V1))))
  (setq keys (EL:Unique (append (mapcar 'car before) (mapcar 'car after))))
  (foreach key keys
    (setq a (EL:Get key before) b (EL:Get key after))
    (if (not (equal a b))
      (EL:LogEvent "SOURCE_FIELD_DIFFERENCE" (list (cons 'field key)
        (cons 'difference
          (if typed
            ;; Reuse bounded typed readback diagnostics; never reprint the failing snapshot.
            (EL:StoreDifference a b (list key))
            (EL:StringDifference
              (if (equal (type a) 'STR) a (EL:Signature a))
              (if (equal (type b) 'STR) b (EL:Signature b))))))))))

;; Date: 2026-10-13. Bounded business-stage timeline; no per-entity file I/O.
(defun EL:MonitorTitle (stage / name)
  (setq name (cdr (assoc stage
    '(("USER_INPUT" . "等待拾取或面板操作") ("PLACEMENT_INPUT" . "等待系统图放置")
      ("UI_ACTION" . "处理面板动作") ("LOAD_MODULE" . "加载源码模块")
      ("LOAD_ROOT" . "确认目录及释放内置资源") ("LOAD_LIBRARY" . "初始化默认设备库")
      ("LOAD_ROOT_SEARCH" . "查找并确认交付目录") ("LOAD_RUNTIME" . "建立本地运行目录")
      ("LOAD_RUNTIME_TEXT" . "释放并回读源码与界面") ("LOAD_RUNTIME_ASSETS" . "释放并回读默认设备资源")
      ("LOAD_BOOTSTRAP" . "加载启动入口及公共函数")
      ("PICK_PANEL" . "拾取配电箱并处理回路") ("PICK_TRUNK" . "拾取集中引出线并处理回路")
      ("PICK_STARTS" . "拾取回路起始端导线") ("RECOGNIZE_STARTS" . "沿起始导线识别回路")
      ("PANEL_START_LOAD" . "读取面板文件") ("PANEL_START_NEW" . "创建面板")
      ("PANEL_START_INIT" . "初始化面板") ("PANEL_START_BUTTONS" . "绘制拾取按钮")
      ("PANEL_START_WAIT" . "首屏面板会话") ("PANEL_DIALOG" . "回路设置面板会话")
      ("PANEL_FILL" . "填充回路及图块") ("PANEL_HISTORY_READ" . "加载保存记录")
      ("PANEL_HISTORY_RESTORE" . "恢复保存记录中的回路与图块")
      ("READ_STORE" . "读取本图记录") ("STORE_READ" . "读取本图记录")
      ("STORE_CURRENT_BOX" . "读取当前配电箱保存数据")
      ("STORE_DECODE" . "解码记录") ("STORE_CACHE_CHECK" . "核对记录缓存")
      ("NEW_RECORD" . "创建配电箱记录") ("PREPARE_PANEL" . "准备面板数据")
      ("RECOGNIZE_FIXED" . "识别配电箱回路") ("RECOGNIZE_TRUNK" . "识别集中引出线")
      ("RECOGNIZE_FIXED_RUN" . "执行整箱识别") ("SIMPLE_COLLECT" . "收集图纸候选对象")
      ("COLLECT_ENTITY_READ" . "读取候选实体") ("COLLECT_CANDIDATES" . "过滤候选对象")
      ("SIMPLE_NETWORK" . "准备连接网络") ("NETWORK_BUILD" . "建立连接网络")
      ("COMPONENT_INDEX" . "建立连通关系索引")
      ("NETWORK_WIRE_CONTACT" . "检查导线接触") ("NETWORK_CANDIDATE_SCOPE" . "筛选设备范围")
      ("NETWORK_DEVICE_CONTACT" . "检查设备接触") ("NETWORK_GAPS" . "检查断线连接")
      ("NETWORK_REACHABLE_TRACE" . "沿起始导线搜索真实连接")
      ("NETWORK_CONTACT_NODES" . "合并同一接点的重复连接")
      ("NETWORK_SIGNATURE" . "整理去重后的几何证据") ("NETWORK_VERIFY_GEOMETRY" . "核对网络几何")
      ("SOURCE_NATIVE_VERIFY" . "核对源图原生对象与范围")
      ("SPLIT_NETWORK" . "拆分回路") ("CIRCUIT_NUMBER_SCOPE" . "识别回路编号范围")
      ("COMPARE_SOURCE_NUMBER" . "核对回路编号") ("PRE_GENERATE_FRESH" . "生成前核对源图")
      ("FRESH_SOURCE_SCAN" . "核对当前源图") ("CCKK2" . "生成新配电箱系统图")
      ("CCKK2_CREATE" . "创建配电箱系统图") ("SAVE_CREATED_DIAGRAM" . "保存生成的系统图记录")
      ("TX_WRITE" . "写入系统图及保存记录") ("STORE_SERIALIZE" . "序列化保存记录")
      ("STORE_PARSE" . "解析并核对序列化数据") ("STORE_REPLACE_PAYLOAD" . "写入图纸记录载荷")
      ("STORE_MIGRATE_BACKUP" . "备份旧版完整记录") ("STORE_STAGE_BUILD" . "构建最终待保存记录")
      ("STORE_COMPACT" . "整理完整记录数据") ("STORE_PACK_INTS" . "压缩整数数据")
      ("STORE_NATIVE_ENCODE" . "编码图纸原生字段") ("STORE_NATIVE_DECODE" . "解码图纸原生字段")
      ("STORE_EXPAND" . "还原完整记录数据")
      ("STORE_UNPACK_INTS" . "展开整数数据") ("STORE_VALUE_DECODE" . "还原记录字段结构")
      ("STORE_READBACK" . "回读核对保存内容") ("STORE_CONTEXT_COMMIT" . "核对提交后的上下文")
      ("STORE_CONTEXT_READ" . "读取提交后的上下文") ("SAVE_GENERATION_DRAFT" . "保存生成草稿")
      ("UNDO_BEGIN" . "开始撤销组") ("UNDO_END" . "结束撤销组")
      ("TX_MARKER_CREATE" . "建立事务标记") ("DIAGRAM_VIEW" . "定位完整系统图")
      ("DEVICE_LIBRARY_LOAD" . "读取设备库") ("DEVICE_LEGEND" . "加载设备图例")
      ("DIAGNOSTIC_EXPORT" . "导出诊断数据")))))
  (if name name stage))
(defun EL:MonitorActionTile (key code)
  ;; Keep original callback expressions in the same DCL scope, including $value.
  (action_tile key (strcat "(EL:MonitorUIBegin $key $value) " code " (EL:MonitorUIEnd)")))
(defun EL:MonitorUIBegin (key value / *EL:MonitorLabel* title)
  (setq title (cdr (assoc key
    '(("p_pick" . "拾取配电箱") ("p_trunk" . "拾取回路起始端导线")
      ("accept" . "保存或确定")
      ("p_block_library_open" . "打开系统图块文件夹")
      ("cancel" . "取消或退出") ("p_generate" . "生成新系统图") ("p_diagnostic" . "导出诊断日志")
      ("f_preview" . "查看全部回路")
      ("p_capacity" . "修改配电箱容量")
      ("dl_rows" . "选择设备库条目") ("dl_query" . "搜索设备库")
      ("dl_new" . "新增设备") ("dl_pick" . "拾取设备入库")
      ("dl_open" . "打开设备库参数文件所在位置")
      ("dl_save" . "保存设备并核对结果")
      ("dl_import" . "导入设备库") ("dl_export" . "导出设备库")
      ("dl_watts" . "修改设备功率并自动保存") ("dl_delete" . "删除设备")
      ("dl_restore" . "恢复设备") ("dl_refresh" . "刷新设备库")
      ("dl_close" . "关闭设备库")))))
  (if (not title) (setq title "修改控件或执行按钮"))
  (setq *EL:MonitorLabel* (strcat title " [" key "]=" (if value (substr value 1 160) ""))
    *EL:MonitorUIStack* (cons (EL:PerfBegin "UI_ACTION") *EL:MonitorUIStack*)))
(defun EL:MonitorUIEnd ()
  (EL:PerfEnd (car *EL:MonitorUIStack*) 'returned)
  (setq *EL:MonitorUIStack* (cdr *EL:MonitorUIStack*)))
(defun EL:MonitorSeconds (milliseconds / fraction)
  ;; DIMZIN must not strip the leading/trailing zeroes in timing columns.
  (setq fraction (strcat "00" (itoa (fix (rem milliseconds 1000)))))
  (strcat (rtos (fix (/ milliseconds 1000.0)) 2 0) "." (substr fraction (- (strlen fraction) 2))))
(defun EL:MonitorCell (value / text)
  (setq text (cond ((equal (type value) 'STR) value) (value (vl-prin1-to-string value)) (T "-")))
  (vl-string-translate "|\r\n" "/  " text))
(defun EL:MonitorTable (file rows origin / row start duration)
  (EL:MonitorLine "|序号|父动作|开始秒|结束秒|耗时秒|程序秒|交互秒|动作内容|阶段|结果|" file)
  (EL:MonitorLine "|---:|---:|---:|---:|---:|---:|---:|---|---|---|" file)
  (foreach row (vl-sort rows '(lambda (a b) (< (EL:Get 'id a) (EL:Get 'id b))))
    (setq start (EL:PerfDelta origin (EL:Get 'start row)) duration (EL:Get 'elapsed-ms row))
    (EL:MonitorLine (strcat "|" (itoa (EL:Get 'id row)) "|" (itoa (EL:Get 'parent-id row))
      "|" (EL:MonitorSeconds start) "|" (EL:MonitorSeconds (+ start duration))
      "|" (EL:MonitorSeconds duration) "|" (EL:MonitorSeconds (EL:Get 'program-ms row))
      "|" (EL:MonitorSeconds (- duration (EL:Get 'program-ms row)))
      "|" (EL:MonitorTitle (EL:Get 'stage row)) " " (EL:MonitorCell (EL:Get 'label row))
      "|" (EL:Get 'stage row) "|" (if (equal (EL:Get 'status row) 'returned) "已返回" "中断") "|") file)))
(defun EL:MonitorWriteBody (file summary / stamp row)
  (setq stamp *EL:MonitorStamp*)
  (EL:MonitorLine "# 应急照明全过程动作耗时" file)
  (EL:MonitorLine (strcat "日期：" (substr stamp 1 4) "-" (substr stamp 5 2) "-" (substr stamp 7 2)) file)
  (EL:MonitorLine (strcat "状态：" (EL:MonitorCell (EL:Get 'status summary))
    "；业务结果：" (EL:MonitorCell (EL:Get 'last-outcome summary))) file)
  (EL:MonitorLine (strcat "启动时间 CDATE：" stamp "；命令：" (EL:Get 'command summary)
    "；交付版本：" (EL:MonitorCell (EL:Get 'package summary))) file)
  (EL:MonitorLine "" file)
  (EL:MonitorLine "单位为秒，保留三位小数。父动作包含子动作，不可将各行相加。交互秒是输入等待区间，已扣除本插件面板回调处理；原生鼠标放置包含 CAD 自身处理。未单独设点的工作保留在父动作及总时间中。" file)
  (EL:MonitorLine "记录用户动作和业务阶段；导线、实体、顶点等循环按批次计时，不逐对象写文件。开始代表进入函数，已返回只表示函数返回，业务成功与否以业务结果为准。" file)
  (if (and *EL:MonitorLoadSummary* (not (equal (EL:Get 'command summary) "APPLOAD")))
    (progn
      (EL:MonitorLine "" file) (EL:MonitorLine "## 最近一次插件加载" file)
      (EL:MonitorLine (strcat "加载时间 CDATE：" *EL:MonitorLoadStamp* "；加载耗时："
        (EL:MonitorSeconds (EL:Get 'total-ms *EL:MonitorLoadSummary*)) " 秒。加载结束至输入命令的空闲间隔不计入程序耗时。") file)
      (EL:MonitorTable file *EL:MonitorLoadRows* *EL:MonitorLoadOrigin*)))
  (EL:MonitorLine "" file) (EL:MonitorLine "## 本次执行至退出" file)
  (EL:MonitorLine (strcat "总耗时 " (EL:MonitorSeconds (EL:Get 'total-ms summary))
    " 秒；程序 " (EL:MonitorSeconds (EL:Get 'program-ms summary)) " 秒；交互 "
    (EL:MonitorSeconds (EL:Get 'interaction-ms summary)) " 秒。") file)
  (if (EL:Get 'after-graphics summary)
    (EL:MonitorLine (strcat "全部图块和文字完成后的收尾："
      (EL:MonitorSeconds (EL:Get 'inclusive-ms (EL:Get 'after-graphics summary))) " 秒。") file))
  (if *EL:MonitorError* (EL:MonitorLine (strcat "错误或取消原因：" (EL:MonitorCell *EL:MonitorError*)) file))
  (EL:MonitorLine "动作 0：命令开始，相对时间 0.000 秒。" file)
  (EL:MonitorTable file *EL:MonitorRows* *EL:PerfStarted*)
  (EL:MonitorLine (strcat "退出：" (EL:MonitorSeconds (EL:Get 'total-ms summary)) " 秒。") file)
  (EL:MonitorLine "" file) (EL:MonitorLine "## 工作量及计数" file)
  (foreach row (EL:Get 'metrics summary)
    (EL:MonitorLine (strcat "- " (car row) "：" (EL:MonitorCell (cdr row))) file))
  (if *EL:DiagnosticLogEvents*
    (progn
      (EL:MonitorLine "" file) (EL:MonitorLine "## 诊断事件" file)
      (foreach row (reverse *EL:DiagnosticLogEvents*)
        (EL:MonitorLine (strcat (itoa (car row)) " | " (cadr row) " | "
          (EL:MonitorCell (EL:LogText (caddr row)))) file)))))
(defun EL:MonitorLine (text ignored)
  (setq *EL:MonitorLines* (cons (strcat text "\r\n") *EL:MonitorLines*)))
(defun EL:MonitorJoin (parts / joined)
  (while (cdr parts)
    (setq joined nil)
    (while parts
      (setq joined (cons (if (cdr parts) (strcat (car parts) (cadr parts)) (car parts)) joined)
        parts (cddr parts)))
    (setq parts (reverse joined)))
  (if parts (car parts) ""))
(defun EL:MonitorStreamWrite (stream path text)
  ;; Explicit UTF-8 even with LISPSYS=0 and GB2312-loaded source.
  (vlax-put-property stream 'Type 2)
  (vlax-put-property stream 'Charset "utf-8")
  (vlax-invoke-method stream 'Open nil 0 -1 "" "")
  (vlax-invoke-method stream 'WriteText text 0)
  (vlax-invoke-method stream 'SaveToFile path 1) T)
(defun EL:MonitorWrite (path summary / stream result closed tmp started *EL:MonitorLines*)
  (setq started (EL:Tick) tmp (strcat path ".tmp"))
  (EL:MonitorWriteBody nil summary)
  (EL:MonitorLine "本文输出位于业务计时之外；monitor-export-ms 包含流写出、关闭和文件发布。" nil)
  (setq result (vl-catch-all-apply '(lambda ()
    (setq stream (vlax-create-object "ADODB.Stream"))
    (EL:MonitorStreamWrite stream tmp (EL:MonitorJoin (reverse *EL:MonitorLines*)))) nil))
  (if stream
    (progn
      (setq closed (vl-catch-all-apply 'vlax-invoke-method (list stream 'Close)))
      (vlax-release-object stream)))
  (if (and (not (vl-catch-all-error-p result)) result
      (not (vl-catch-all-error-p closed)))
    (setq result (vl-catch-all-apply 'vl-file-rename (list tmp path)))
    (setq result nil))
  (if (or (not result) (vl-catch-all-error-p result))
    (progn (vl-catch-all-apply 'vl-file-delete (list tmp)) (setq result nil)))
  (setq *EL:MonitorExportMS* (EL:PerfDelta started (EL:Tick))) result)
(defun EL:MonitorReport (summary / folder path result suffix)
  ;; One write per completed command; retain memory on I/O failure.
  (setq *EL:MonitorLastRows* *EL:MonitorRows*)
  (if (equal (EL:Get 'command summary) "APPLOAD")
    (setq *EL:MonitorLoadRows* *EL:MonitorRows* *EL:MonitorLoadSummary* summary
      *EL:MonitorLoadOrigin* *EL:PerfStarted* *EL:MonitorLoadStamp* *EL:MonitorStamp*))
  (setq result (vl-catch-all-apply 'EL:MonitorSave (list summary nil)))
  (if (or (vl-catch-all-error-p result) (not result))
    (setq result (vl-catch-all-apply 'EL:MonitorSave (list summary T))))
  (if (and result (not (vl-catch-all-error-p result)))
    (progn (setq *EL:PerfLastSummary* (EL:Put 'monitor-export-ms *EL:MonitorExportMS* *EL:PerfLastSummary*))
      (princ (strcat "\n全过程耗时文档：" *EL:MonitorPath* "；输出耗时 " (EL:MonitorSeconds *EL:MonitorExportMS*) " 秒。")))
    (princ "\n全过程文档写入失败；动作保留在 *EL:MonitorLastRows*，汇总保留在 *EL:PerfLastSummary*。")) nil)
(defun EL:MonitorSave (summary fallback / folder path suffix base)
  (setq folder (if (or fallback (not *EL:Root*)) (getvar "TEMPPREFIX") (strcat *EL:LiteDataRoot* "output/")))
  (vl-mkdir folder)
  (setq base (strcat folder "ELMONITOR-" *EL:MonitorStamp* "-" (EL:Get 'command summary)) suffix 0
    path (strcat base ".md"))
  (while (findfile path)
    (setq suffix (1+ suffix) path (strcat base "-" (itoa suffix) ".md")))
  (if (EL:MonitorWrite path summary) (setq *EL:MonitorPath* path)))
(defun EL:ExportDiagnosticRun (/ run path
    *EL:MonitorRows* *EL:PerfStarted* *EL:MonitorStamp* *EL:MonitorError* *EL:DiagnosticLogEvents*
    *EL:MonitorLoadSummary* *EL:MonitorLoadRows* *EL:MonitorLoadOrigin* *EL:MonitorLoadStamp*)
  ;; Date: 2026-10-15. Restore the completed run locally; exporting while a
  ;; new panel is open must neither replace nor finish that panel's timer.
  (if (setq run (EL:Get (namedobjdict) *EL:DiagnosticRuns*))
    (progn
      (setq *EL:MonitorRows* (EL:Get 'rows run) *EL:PerfStarted* (EL:Get 'origin run)
        *EL:MonitorStamp* (EL:Get 'stamp run) *EL:MonitorError* (EL:Get 'error run)
        *EL:DiagnosticLogEvents* (EL:Get 'events run)
        *EL:MonitorLoadSummary* (EL:Get 'load-summary run) *EL:MonitorLoadRows* (EL:Get 'load-rows run)
        *EL:MonitorLoadOrigin* (EL:Get 'load-origin run) *EL:MonitorLoadStamp* (EL:Get 'load-stamp run))
      (setq path (EL:MeasuredCatch 'EL:MonitorSave (list (EL:Get 'summary run) nil)))
      (if (or (vl-catch-all-error-p path) (not path))
        (setq path (EL:MeasuredCatch 'EL:MonitorSave (list (EL:Get 'summary run) T))))
      (EL:Require (and (not (vl-catch-all-error-p path)) path)
        "全过程诊断日志导出失败；内存记录已保留，请检查输出目录权限。")
      (if path (princ (strcat "\n全过程诊断日志已导出：" (vl-string-translate "/" "\\" path)))) path)))
(defun EL:MonitorLoadBegin (started / token)
  ;; Date: 2026-10-13. Finish the old clock before a reload changes its origin.
  ;; A cancelled command must never become the parent of later APPLOAD events.
  (if *EL:PerfActive*
    (progn
      (setq *EL:MonitorError* "RELOADED: 上次执行被重新加载中断")
      (EL:LogFinish 'interrupted-by-load)
      (EL:PerfFinish 'interrupted-by-load)))
  (EL:PerfStart "APPLOAD")
  (setq *EL:PerfStarted* started token (EL:PerfBegin "LOAD_BOOTSTRAP"))
  (setq *EL:PerfPending* (vl-remove token *EL:PerfPending*) token (EL:Put 'start started token)
    *EL:PerfPending* (cons token *EL:PerfPending*))
  (EL:PerfEnd token 'returned)
  (setq *EL:MonitorOldError* *error*)
  (defun *error* (message)
    (setq *EL:MonitorError* message *error* *EL:MonitorOldError*)
    (EL:PerfFinish 'load-failed)
    (princ (strcat "\n插件加载失败：" message)) (princ)))
(defun EL:MonitorLoadEnd (status)
  (setq *error* *EL:MonitorOldError*)
  (EL:PerfFinish status))
