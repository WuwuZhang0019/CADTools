;;; =====================================================================
;;; one-click-simsun.lsp
;;; 一键统一宋体（YJST）：将当前图纸文字字体统一为宋体（SimSun）
;;;
;;; 日期：2026-10-13
;;; 状态：实现完成，待原生 AutoCAD 验收（见 docs/AutoCAD验收记录.md）
;;; 编码：开发源码 UTF-8（无 BOM）；CAD 加载请使用 output/gb2312/ 交付文件
;;;
;;; 依据：docs/AutoLISP一键统一宋体实施方案.md
;;; 命令：APPLOAD 加载本文件后执行 YJST
;;; 约定：所有函数使用 OCS: 前缀（用户命令为 c:YJST）
;;;
;;; 只改变字体定义与文字内容中的有效字体切换指令；
;;; 不改字高、宽度、旋转、对齐、图层、颜色等任何其他数据；
;;; 不执行 ATTSYNC / ResetBlock / EXPLODE / SAVEAS / 自动保存；
;;; 不修改 FONTALT / FONTMAP / SECURELOAD / LISPSYS；
;;; 外部参照及其依赖样式跳过，不打开、不改写外部文件。
;;; =====================================================================

(vl-load-com)

;;; =====================================================================
;;; AutoLISP 辅助函数：不依赖 Common Lisp 的 consp/stringp/error。
;;; Blocks 是 ActiveX 属性，直接调用 vla-get-Blocks 验证。
;;; 不能凭这些函数或属性/方法探针结果判断 CAD 厂商。
;;; =====================================================================

;; consp：(and (listp x) (not (atom x)))
;;   原子（数/串/符号/T/nil）会被 atom 视为 T，正好让空表 () 通过，
;;   标准 AutoLISP 里空表是 nil（atom=nil=()），consp 返 nil，
;;   我们的实现 (and (listp nil) (not (atom nil))) = (and T (not T)) = nil，一致。
(defun OCS:consp (x)
  (and (listp x) (not (atom x)))
)

;; stringp：用 type 返回的符号判断。各引擎行为不一，先探测再缓存。
;; 探测方法：(type "x") 的返回值比较。标准 AutoLISP 返回 SYM一笔 STR。
;; 无 type 时回退到：不是数、不是符号、不是 nil、能 strlen 则当作字符串。
(setq *OCS:StrType* nil)
(if (not (boundp '*OCS:StrType*))
  (setq *OCS:StrType* nil))
;; 探测：求 (type "abc")，若返回符号 STR 则用 type 判别；否则用回退法。
(if (not *OCS:StrType*)
  (progn
    (setq *OCS:StrType* (vl-catch-all-apply 'type (list "abc")))
    (if (vl-catch-all-error-p *OCS:StrType*)
      (setq *OCS:StrType* nil))
  )
)
(defun OCS:stringp (x)
  (if *OCS:StrType*
    (equal (type x) *OCS:StrType*)
    (and (not (numberp x))
         (not (atom x))
         (not (listp x))))
)

;; error：用 (exit) 硬退（引擎无 error 函数时）
(defun OCS:fail (msg)
  (setq *OCS:FailureMessage* msg)
  (princ (strcat "\nOCS 错误：" msg))
  (exit)
)

;; vlax-method-applicable-p 在某些克隆引擎上返 NIL 但方法实际可用：
;; OCS:methodOk 用试调一空参列表替代：能调通即认为可用。
(defun OCS:methodOk (obj meth / r)
  (setq r (vl-catch-all-apply meth (list obj)))
  (not (vl-catch-all-error-p r))
)
;; 改写预检里的接口检查；it was: (if (not (vlax-method-applicable-p doc 'GetBlocks))
;;   (setq res (OCS:addProblem res "error" "Blocks 集合接口不可用")))

;;; ------------------------- 全局状态 -------------------------
(setq *OCS:Version*      "0.2.10")
(setq *OCS:CollectReverse* nil)
(setq *OCS:ClockStart* nil *OCS:PhaseStart* nil *OCS:PhaseName* nil *OCS:PhaseTimes* nil)
(setq *OCS:CheckOnly* nil *OCS:LastCheckReport* nil)
(setq *OCS:Stage* "初始化")
(setq *OCS:FailureMessage* nil *OCS:ProbeStyle* nil *OCS:UndoAttempted* nil)
(setq *OCS:Plan*         nil)   ; 修改计划
(setq *OCS:Report*       nil)   ; 结构化报告
(setq *OCS:LastReport*   nil)   ; 最近一次运行（供调试/自动验收读取）
(setq *OCS:Running*      nil)   ; 重入保护
(setq *OCS:UndoMark*     nil)   ; 本次 Undo 分组标记
(setq *OCS:Wrote*        nil)   ; 分组内至少一次写入成功，才允许撤销
(setq *OCS:TempState*    nil)   ; 临时状态（锁定层、表格再生、OSMODE 等）
(setq *OCS:EscRequested* nil)   ; Esc/取消请求
(setq *OCS:FaultPoint*   nil)   ; 故障注入点（OCS:TestFault 用）

;;; 日期：2026-10-13。每次命令独立落盘；日志失败不得改变业务结果。
(setq *OCS:LogPath* nil *OCS:LogEncoding* nil *OCS:LogError* nil)
(setq *OCS:LogTail* nil *OCS:LogSeq* 0 *OCS:TraceActive* nil)
(setq *OCS:LogPending* nil *OCS:LogPendingCount* 0)

(defun OCS:logVar (name / result)
  (setq result (vl-catch-all-apply 'getvar (list name)))
  (if (vl-catch-all-error-p result) nil result)
)

(defun OCS:logOpen (path mode)
  (if (= *OCS:LogEncoding* "UTF-8")
    (open path mode "utf8")
    (open path mode))
)

(defun OCS:logWriteBatch (lines fd / line)
  (foreach line lines (write-line line fd))
)

(defun OCS:logWriteLines (lines / fd result closed)
  (setq fd (OCS:logOpen *OCS:LogPath* "a"))
  (if fd
    (progn
      (setq result (vl-catch-all-apply 'OCS:logWriteBatch (list lines fd)))
      ;; 批次内写入失败也关闭文件，保留已写入的前序记录。
      (setq closed (vl-catch-all-apply 'close (list fd)))
      (cond
        ((vl-catch-all-error-p result) (vl-catch-all-error-message result))
        ((vl-catch-all-error-p closed) (vl-catch-all-error-message closed))
        (T nil)))
    "无法打开日志文件")
)

(defun OCS:logFlush ( / lines problem)
  (setq lines (reverse *OCS:LogPending*) *OCS:LogPending* nil *OCS:LogPendingCount* 0)
  (if (and lines *OCS:LogPath* (not *OCS:LogError*))
    (progn
      (setq problem (vl-catch-all-apply 'OCS:logWriteLines (list lines)))
      (if (vl-catch-all-error-p problem) (setq problem (vl-catch-all-error-message problem)))
      (if problem (setq *OCS:LogError* problem))))
  nil
)

(defun OCS:traceBody (event data / line)
  (setq *OCS:LogSeq* (1+ *OCS:LogSeq*))
  (setq line (vl-prin1-to-string
    (list *OCS:LogSeq* (OCS:logVar "MILLISECS") event *OCS:Stage* data)))
  (setq *OCS:LogTail* (append *OCS:LogTail* (list line)))
  (if (> (length *OCS:LogTail*) 40) (setq *OCS:LogTail* (cdr *OCS:LogTail*)))
  (setq *OCS:LogPending* (cons line *OCS:LogPending*)
        *OCS:LogPendingCount* (1+ *OCS:LogPendingCount*))
  ;; 日期：2026-10-13。普通读取每 64 条落盘；失败、恢复、阶段边界和结束立即落盘。
  (if (or (>= *OCS:LogPendingCount* 64)
          (member event (list "RUN_BEGIN" "RUN_RESULT" "RUN_END" "RUN_TIMING" "PHASE_TIME"
            "CALL_ERROR" "ERROR" "REPORT_ERROR" "ROLLBACK_BEGIN" "ROLLBACK_END" "RECOVERY_RESULT")))
    (OCS:logFlush))
  nil
)

(defun OCS:trace (event data / result)
  (if *OCS:TraceActive*
    (progn
      (setq result (vl-catch-all-apply 'OCS:traceBody (list event data)))
      (if (vl-catch-all-error-p result)
        (setq *OCS:LogError* (vl-catch-all-error-message result)))))
  nil
)

(defun OCS:setStage (stage)
  (setq *OCS:Stage* stage)
  (OCS:trace "STAGE" stage)
  stage
)

(defun OCS:logStartBody ( / dirs dir stamp day path index fd result name value)
  (setq dirs (list (OCS:logVar "TEMPPREFIX") (getenv "TEMP") (OCS:logVar "DWGPREFIX")))
  (setq stamp (OCS:logVar "CDATE"))
  (setq stamp (if (numberp stamp) (rtos stamp 2 8) "unknown-date"))
  (setq day (if (= stamp "unknown-date") stamp
    (strcat (substr stamp 1 4) "-" (substr stamp 5 2) "-" (substr stamp 7 2))))
  (foreach dir dirs
    (if (and (not *OCS:LogPath*) (OCS:stringp dir) (> (strlen dir) 0))
      (progn
        (if (not (member (substr dir (strlen dir) 1) (list "/" "\\")))
          (setq dir (strcat dir "/")))
        (setq index 0 path (strcat dir "YJST-" stamp ".log"))
        ;; 不使用 mktemp：其生成的文件会在 CAD 退出时被自动删除。
        (while (findfile path)
          (setq index (1+ index) path (strcat dir "YJST-" stamp "-" (itoa index) ".log")))
        (setq *OCS:LogEncoding* "UTF-8")
        (setq fd (vl-catch-all-apply 'open (list path "w" "utf8")))
        ;; 旧 AutoLISP 不接受编码参数，沿用引擎文本编码并写入编码标记。
        (if (or (vl-catch-all-error-p fd) (not fd))
          (progn
            (setq *OCS:LogEncoding* "CAD-legacy")
            (setq fd (vl-catch-all-apply 'open (list path "w")))))
        (if (and (not (vl-catch-all-error-p fd)) fd)
          (progn
            (setq result (vl-catch-all-apply 'close (list fd)))
            (if (not (vl-catch-all-error-p result)) (setq *OCS:LogPath* path)))))))
  (if (not *OCS:LogPath*) (setq *OCS:LogError* "日志目录不可写，仅保留最近 40 条内存记录"))
  (OCS:trace "RUN_BEGIN" (list "version" *OCS:Version* "date" day "cdate" stamp "encoding" *OCS:LogEncoding*))
  (foreach name (list "ACADVER" "PRODUCT" "PLATFORM" "LISPSYS" "DWGPREFIX" "DWGNAME" "DWGTITLED" "UNDOCTL")
    (setq value (OCS:logVar name))
    (OCS:trace "ENV" (list name value)))
  (princ (if *OCS:LogPath* (strcat "\n排查日志：" *OCS:LogPath*) "\n排查日志无法落盘，运行后输入 YJSTLOG 查看记录。"))
)

(defun OCS:logStart ( / result)
  (setq *OCS:LogPath* nil *OCS:LogError* nil *OCS:LogEncoding* nil
        *OCS:LogTail* nil *OCS:LogSeq* 0 *OCS:TraceActive* T *OCS:Stage* "初始化日志"
        *OCS:LogPending* nil *OCS:LogPendingCount* 0)
  (setq result (vl-catch-all-apply 'OCS:logStartBody nil))
  (if (vl-catch-all-error-p result)
    (progn
      (setq *OCS:LogError* (vl-catch-all-error-message result))
      (princ "\n日志初始化失败，运行后输入 YJSTLOG 查看记录。")))
  nil
)

(defun c:YJSTLOG ( / line)
  (if *OCS:LogPath* (princ (strcat "\n最近一次排查日志：" *OCS:LogPath*))
    (princ "\n最近一次运行没有可用日志文件。"))
  (if *OCS:LogError*
    (progn
      (princ (strcat "\n日志写入异常：" *OCS:LogError* "；以下为最近 40 条内存记录："))
      (foreach line *OCS:LogTail* (princ (strcat "\n" line)))))
  (princ)
)

;; 调用参数只记录短标量和类型，避免把长篇图纸正文或 COM 对象展开到日志。
(defun OCS:logArgs (args / out value)
  (setq out nil)
  (foreach value args
    (setq out (cons
      (cond ((OCS:stringp value)
             (if (> (strlen value) 160) (strcat "<text-length=" (itoa (strlen value)) ">") value))
            ((or (numberp value) (null value) (equal (type value) 'SYM)) value)
            (T (strcat "<" (vl-symbol-name (type value)) ">"))) out)))
  (reverse out)
)

(defun OCS:tracedCall (fn args / result detail)
  (if *OCS:TraceActive*
    (progn
      (setq detail (vl-catch-all-apply 'OCS:logArgs (list args)))
      (if (vl-catch-all-error-p detail) (setq detail "<参数摘要不可用>"))
      (OCS:trace "CALL_BEGIN" (list (vl-symbol-name fn) detail))
      ;; 写入接口前保存调用上下文；普通读取批量落盘。
      (if (not (or (= (substr (strcase (vl-symbol-name fn)) 1 8) "VLA-GET-")
                   (member (strcase (vl-symbol-name fn)) (list "VLA-ITEM" "VLA-GETFONT"))))
        (OCS:logFlush))))
  (setq result (vl-catch-all-apply fn args))
  (if (vl-catch-all-error-p result)
    (OCS:trace "CALL_ERROR" (list (vl-symbol-name fn) (vl-catch-all-error-message result)))
    (OCS:trace "CALL_OK" (vl-symbol-name fn)))
  result
)

;;; ------------------------- 小工具 -------------------------

;; 字符串包含
(defun OCS:strContains (s sub / ls lsub i result)
  (setq ls (strlen s) lsub (strlen sub))
  (if (or (= lsub 0) (< ls lsub))
    (= s sub)
    (progn
      (setq i 1 result nil)
      (while (and (<= i (1+ (- ls lsub))) (not result))
        (if (= (substr s i lsub) sub) (setq result T))
        (setq i (1+ i))
      )
      result
    )
  )
)

;; 字符串中第 n 次出现 sub 的起始位置，找不到返回 nil
(defun OCS:strFindNth (s sub n / ls lsub i c)
  (setq ls (strlen s) lsub (strlen sub) i 1 c 0)
  (if (= lsub 0) nil
    (progn
      (while (and (<= i (1+ (- ls lsub))) (< c n))
        (if (= (substr s i lsub) sub) (setq c (1+ c)))
        (if (< c n) (setq i (1+ i)))
      )
      (if (= c n) i nil)
    )
  )
)

;; 是否为十六进制字符
(defun OCS:isHexChar (ch)
  (and (= (strlen ch) 1)
       (or (and (>= ch "0") (<= ch "9"))
           (and (>= ch "a") (<= ch "f"))
           (and (>= ch "A") (<= ch "F"))))
)

;; 键入十进制整数 → 十六进制字符串（用于 1071 打包）
(defun OCS:toHex (n / digits map out q r)
  (setq digits "0123456789ABCDEF" out "")
  (if (< n 0) (setq n (+ n 4294967296)))  ; 有符号 → 无符号 32 位
  (if (= n 0) "0"
    (progn
      (while (> n 0)
        (setq q (fix (/ n 16)) r (- n (* q 16)))
        (setq out (strcat (substr digits (1+ r) 1) out))
        (setq n q)
      )
      out
    )
  )
)

;; 十六进制字符串 → 整数
(defun OCS:fromHex (s / digits n i p)
  (setq digits "0123456789ABCDEF" n 0 i 1)
  (while (<= i (strlen s))
    (setq p (vl-position (substr s i 1) (OCS:splitChars digits)))
    (if p (setq n (+ (* n 16) p)))
    (setq i (1+ i))
  )
  n
)

(defun OCS:splitChars (s / out i)
  (setq out nil i 1)
  (while (<= i (strlen s))
    (setq out (append out (list (substr s i 1))))
    (setq i (1+ i))
  )
  out
)

;; 打包 1071：低 8 位 charset，位 8 bold，位 9 italic，
;; 位 16-23 pitch/family（参考 DXF 1071 与 SetFont 参数）
(defun OCS:pack1071 (charSet bold italic pitchFamily / v)
  (setq v (logand charSet 255))
  (if bold   (setq v (logior v 256)))
  (if italic (setq v (logior v 512)))
  (setq v (logior v (lsh (logand pitchFamily 255) 16)))
  v
)

(defun OCS:unpack1071 (v / charSet bold italic pf)
  (setq charSet (logand v 255)
        bold    (/= 0 (logand v 256))
        italic  (/= 0 (logand v 512))
        pf      (logand (lsh v -16) 255))
  (list charSet bold italic pf)
)

;; 关联列表取值（无则默认）
(defun OCS:assocd (key lst default / pair found value)
  ;; 数字键只用于 DXF 点对；业务数据使用字符串键的扁平 plist。
  (if (numberp key)
    (if (setq pair (assoc key lst)) (cdr pair) default)
    (progn
      (setq found nil value default)
      (while (and lst (not found))
        (if (OCS:consp (car lst))
          (setq lst (cdr lst)) ; 跳过 problem 三元组
          (progn
            (if (and (equal (car lst) key) (cdr lst))
              (setq found T value (cadr lst)))
            (setq lst (cdr (cdr lst)))
          )
        )
      )
      value
    )
  )
)

;; 注意：不使用 defmacro / 反引号宏。部分 CAD 引擎不把 defmacro 当特殊形式，
;; 加载时会把 (fn &rest args) 参数表当普通调用求值，报 "no function definition: FN"。
;; 报错包装直接用 vl-catch-all-apply（见各调用点），此处只保留 errp/errmsg。

;; 报错判断
(defun OCS:errp (x)
  (and (OCS:consp x) (equal (car x) "error"))
)

;; 错误信息取文本
(defun OCS:errmsg (x)
  (if (OCS:errp x) (cdr x) "")
)

;;; =====================================================================
;;; 纯函数：字体格式扫描器 OCS:NormalizeFontRuns
;;; （方案第 5 节；不访问任何 CAD 对象）
;;; =====================================================================

;; 内部状态 plist：(:i 位置 :issues 问题列表 :changes 修改计数)
;; 返回新 plist。

;; 读取字段范围 %< ... >%（支持转义与嵌套 %< >%），返回 (新位置 结束位置)
;; 若字段未闭合，记录 UNTERMINATED_FIELD 并把位置推到串尾。
(defun OCS:scanField (s i len st / depth c j closed)
  (setq j (+ i 2) depth 1 closed nil)
  (while (and (<= j len) (not closed))
    (setq c (substr s j 1))
    (cond
      ((= c "\\")
       (setq j (+ j 2)))
      ((and (= c "%") (< j len) (= (substr s (1+ j) 1) "<"))
       (setq depth (1+ depth) j (+ j 2)))
      ((and (= c ">") (< j len) (= (substr s (1+ j) 1) "%"))
       (setq depth (1- depth) j (+ j 2))
       (if (<= depth 0) (setq closed T)))
      ((= c ">") (setq j (1+ j)))
      (T (setq j (1+ j)))
    )
  )
  (if (not closed)
    (progn
      (setq st (OCS:addIssue st "UNTERMINATED_FIELD" i "字段 %<...>% 未闭合"))
      (setq j (1+ len))
    )
  )
  (list (1- j) j)  ; 返回 (字段结束位置(含) 下一扫描位置)
)

;; 读取字体描述至 ;（识别转义与嵌套花括号），返回 (描述 结束后位置 err)
(defun OCS:readFontDesc (s i len / j c depth buf err closed)
  (setq j i depth 0 buf "" err nil closed nil)
  (while (and (<= j len) (not err) (not closed))
    (setq c (substr s j 1))
    (cond
      ((= c "\\")
       (if (< j len)
         (progn (setq buf (strcat buf c (substr s (1+ j) 1))) (setq j (+ j 2)))
         (progn (setq err "字体描述以孤立反斜杠结尾") (setq j (1+ j)))
       ))
      ((= c "{") (setq depth (1+ depth) buf (strcat buf c) j (1+ j)))
      ((= c "}")
       (if (> depth 0)
         (progn (setq depth (1- depth) buf (strcat buf c) j (1+ j)))
         (progn (setq err "字体描述中出现多余的 }") (setq j (1+ j)))
       ))
      ((= c ";")
       (if (= depth 0)
         (setq closed T j (1+ j))              ; 遇到分号立即结束
         (progn (setq buf (strcat buf c) j (1+ j)))
       ))
      (T (setq buf (strcat buf c) j (1+ j)))
    )
  )
  (if (and (not err) (> depth 0))
    (setq err "字体描述中花括号未闭合")
  )
  (if (and (not err) (not closed))
    ;; 循环退出但没遇到 ';'：说明串已耗尽
    (setq err "字体指令不完整（缺少分号）")
  )
  (list buf (1- j) err)
)

(defun OCS:chompDesc (s)
  ;; 去掉尾部空白
  (while (and (> (strlen s) 0)
              (OCS:isSpaceChar (substr s (strlen s) 1)))
    (setq s (substr s 1 (1- (strlen s))))
  )
  s
)

(defun OCS:isSpaceChar (c)
  (or (= c " ") (= c "\t") (= c "\n") (= c "\r"))
)

(defun OCS:strEndsWithChar (s c)
  (and (> (strlen s) 0) (= (substr s (strlen s) 1) c))
)

;; 分割字体描述参数 a|b|c  → ("a" "b" "c")
(defun OCS:splitDesc (desc / out i pos start)
  (setq out nil i 1 start 1)
  (while (<= i (strlen desc))
    (if (= (substr desc i 1) "|")
      (progn
        (setq out (append out (list (substr desc start (- i start)))))
        (setq start (1+ i))
      )
    )
    (setq i (1+ i))
  )
  (setq out (append out (list (substr desc start (1+ (- (strlen desc) start))))))
  out
)

;; 应用目标字体规则：保留 b/i，重写 charset 与 pitch/family（若描述中已带）
;; 返回新描述（无 ;）
(defun OCS:applyFamily (desc family target / parts out head p kv first)
  (setq parts (OCS:splitDesc desc) out nil head nil)
  (foreach p parts
    (cond
      ((= p "") nil)
      ((and (= (substr p 1 1) "b") (OCS:allDigits (substr p 2 100)) (not head))
       nil)  ; 位置参数在后面统一处理
      ((and (= (substr p 1 1) "i") (OCS:allDigits (substr p 2 100)) (not head))
       nil)
      ((not head) (setq head p))
      (T nil)
    )
  )
  ;; 重新按原始顺序构造：head 替换为 family；保留 b、i、c、pf 并按目标覆盖 c/pf
  (setq out nil)
  (setq first T)
  (foreach p parts
    (cond
      ((= p "") nil)
      (first
        (setq out (list family))
        (setq first nil)
        ;; 同一 token 可能是 "Arial|b1" 风格吗？不，已按 | 分割
      )
      ((and (= (substr p 1 1) "b") (OCS:allDigits (substr p 2 100)))
       (setq out (append out (list p))))
      ((and (= (substr p 1 1) "i") (OCS:allDigits (substr p 2 100)))
       (setq out (append out (list p))))
      ((and (= (substr p 1 1) "c") (OCS:allDigits (substr p 2 100)))
       (setq out (append out (list (strcat "c" (itoa (OCS:targetCharSet target)))))))
      ((and (= (substr p 1 1) "p") (= (substr p 2 1) "f") (OCS:allDigits (substr p 3 100)))
       (setq out (append out (list (strcat "pf" (itoa (OCS:targetPitchFamily target)))))))
      (T (setq out (append out (list p))))
    )
  )
  ;; 若描述原本没有任何 c/pf 参数，按目标规则补上（目标字体参数）
  (if (OCS:targetAppendParams target)
    (progn
      (if (not (OCS:hasParam out "c"))
        (setq out (append out (list (strcat "c" (itoa (OCS:targetCharSet target)))))))
      (if (not (OCS:hasParam out "pf"))
        (setq out (append out (list (strcat "pf" (itoa (OCS:targetPitchFamily target)))))))
    )
  )
  ;; 拼接
  (setq kv "")
  (foreach p out
    (if (= kv "") (setq kv p) (setq kv (strcat kv "|" p)))
  )
  kv
)

(defun OCS:hasParam (lst prefix / found p)
  (setq found nil)
  (foreach p lst
    (if (and (not found) (> (strlen p) 0)
             (= (substr p 1 (strlen prefix)) prefix))
      (setq found T)
    )
  )
  found
)

(defun OCS:allDigits (s / i ok ch)
  (setq ok T i 1)
  (if (= s "") (setq ok nil))
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (if (not (and (>= ch "0") (<= ch "9"))) (setq ok nil))
    (setq i (1+ i))
  )
  ok
)

;; 目标字体参数（S01 结果通过 *OCS:FontTarget* 注入；缺省为已验证的
;; SimSun 规则：charset=134，pitch/family=22(0x16)=2|16|4）
(defun OCS:targetCharSet (target)
  (OCS:assocd "charSet" target 134)
)
(defun OCS:targetPitchFamily (target)
  (OCS:assocd "pitchFamily" target 22)
)
(defun OCS:targetAppendParams (target)
  (OCS:assocd "appendParams" target T)
)

;; 追加解析问题
(defun OCS:addIssue (st code pos msg)
  (list "i"   (OCS:assocd "i" st 1)
        "issues" (append (OCS:assocd "issues" st nil)
                        (list (list code pos (OCS:assocd "len" st 0) msg)))
        "changes" (OCS:assocd "changes" st 0)
        "len" (OCS:assocd "len" st 0))
)

;; 判断字体族是否已是目标族（不区分大小写；接受“宋体”）
(defun OCS:isTargetFamily (fam target / tf)
  (setq tf (OCS:assocd "family" target "SimSun"))
  (or (OCS:equalsIgnoreCase fam tf)
      (and (OCS:equalsIgnoreCase tf "SimSun")
           (or (OCS:equalsIgnoreCase fam "宋体")
               (OCS:equalsIgnoreCase fam "sim sun")
               (OCS:equalsIgnoreCase fam "SimSun")))
      (OCS:equalsIgnoreCase fam "宋体"))
)

(defun OCS:equalsIgnoreCase (a b)
  (= (OCS:lower a) (OCS:lower b))
)

(defun OCS:lower (s / out i ch up lo p)
  (setq up "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        lo "abcdefghijklmnopqrstuvwxyz"
        out "" i 1)
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (setq p (vl-position ch (OCS:splitChars up)))
    (if p
      (setq out (strcat out (substr lo (1+ p) 1)))
      (setq out (strcat out ch))
    )
    (setq i (1+ i))
  )
  out
)

;;; 主扫描器（纯函数）
;;; 输入：
;;;   s       ： 文字原始内容（MTEXT 全量原始串 / 属性内容等）
;;;   target  ： (list (cons :family "SimSun") (cons :charSet 134)
;;;                     (cons :pitchFamily 36) (cons :appendParams T))
;;; 输出 plist：
;;;   (:text 新内容 :changes 修改数 :issues ((code pos len msg)...) )
;;; 规则（方案第 5 节）：
;;;   - 仅替换有效 \f、\F 指令中的字体族；
;;;   - %<...>% 字段整体保护（其中 \f 不是字体指令）；
;;;   - 转义 \\ 与 \{ \} 不作为格式开关；
;;;   - 保留其他一切格式码与原文字符；
;;;   - 解析失败只记录问题，不删除任何段落。
;;; =====================================================================
(defun OCS:NormalizeFontRuns (s target / st len out i c r desc endp err fam newDesc next)
  (if (not (OCS:stringp s))
    (list "text" s "changes" 0 "issues" (list (list "BAD_INPUT" 0 0 "输入不是字符串")))
    (progn
      (setq len (strlen s))
      (setq st  (list "i" 1 "issues" nil "changes" 0 "len" len))
      (setq out "")
      (setq i 1)
      (while (<= i len)
        (setq c (substr s i 1))
        (cond
          ;; 转义序列（\\、\{、\}、\; 等）：整体原样输出，不作为格式开关
          ;; 注意顺序：先判断转义，再判断 \f/\F（\f 也是合法转义之一，
          ;; 但作为格式指令时其后是描述文本，不会整体走转义分支）
          ((and (= c "\\") (< i len) (OCS:isEscapable (substr s (1+ i) 1)))
           (setq out (strcat out c (substr s (1+ i) 1)))
           (setq i (+ i 2))
          )
          ;; 字段范围保护：%< ... >% 整体原样输出
          ((and (= c "%") (< i len) (= (substr s (1+ i) 1) "<"))
           (setq next (OCS:scanFieldEnd s i len))
           (setq st (OCS:scanFieldSt s i len st))
           (setq out (strcat out (substr s i (- next i))))
           (setq i next)
          )
          ;; 字体名称可以以英文字母开头，如 Arial。
          ((and (= c "\\") (< i len)
                (or (= (substr s (1+ i) 1) "f") (= (substr s (1+ i) 1) "F")))
           (setq r (OCS:readFontDesc s (+ i 2) len))
           (setq desc (car r) endp (cadr r) err (caddr r))
           (if err
             (progn
               (setq st (OCS:addIssue st "UNTERMINATED_FONT" i err))
               ;; 保留原文，不删除任何段落（本指令按原样输出）
               (setq out (strcat out c (substr s (1+ i) 1)))
               (setq i (+ i 2))
             )
             (progn
               (setq fam (car (OCS:splitDesc (OCS:chompDesc desc))))
               (if (or (= fam "") (OCS:isTargetFamily fam target))
                 (progn
                   ;; 已是目标族：原样保留（幂等，不重复追加参数）
                   (setq out (strcat out c (substr s (1+ i) 1) desc ";"))
                   (setq i (1+ endp))
                 )
                 (progn
                   (setq newDesc (OCS:rewriteDesc (OCS:chompDesc desc) target))
                   (setq out (strcat out c (substr s (1+ i) 1) newDesc ";"))
                   (setq st (OCS:bumpChanges st))
                   (setq i (1+ endp))
                 )
               )
             )
           )
          )
          (T
           (setq out (strcat out c))
           (setq i (1+ i))
          )
        )
      )
      (list "text" out
            "changes" (OCS:assocd "changes" st 0)
            "issues" (OCS:assocd "issues" st nil))
    )
  )
)

;; 字母判断工具（字体名称允许英文字母开头）
(defun OCS:alphaChar (ch)
  (and (= (strlen ch) 1)
       (or (and (>= ch "a") (<= ch "z"))
           (and (>= ch "A") (<= ch "Z"))))
)

;; 转义字符：\ 后面这些字符属于“合法转义”，整体原样保留
;; 注意：f/F 不在此列，\f \F 要走字体指令分支（由 NormalizeFontRuns 的
;; 顺序保证：转义分支已排除 \f \F 后随非字母的情形）
(defun OCS:isEscapable (ch / lst)
  (setq lst (list "\\" "{" "}" ";" "P" "p" "H" "W" "T" "Q" "C" "c"
                   "S" "s" "A" "a" "L" "l" "~" "-" "+" " " "n" "^"))
  (and (= (strlen ch) 1) (vl-position ch lst))
)

;; 计算字段 %< ... >% 的结束位置：返回“下一扫描位置”（1-based，字段之后）
;; 若未闭合，返回 (1+ len)
(defun OCS:scanFieldEnd (s i len / depth c j closed)
  (setq j (+ i 2) depth 1 closed nil)
  (while (and (<= j len) (not closed))
    (setq c (substr s j 1))
    (cond
      ((= c "\\") (setq j (+ j 2)))
      ((and (= c "%") (< j len) (= (substr s (1+ j) 1) "<"))
       (setq depth (1+ depth) j (+ j 2)))
      ((and (= c ">") (< j len) (= (substr s (1+ j) 1) "%"))
       (setq depth (1- depth) j (+ j 2))
       (if (<= depth 0) (setq closed T)))
      (T (setq j (1+ j)))
    )
  )
  (if closed j (1+ len))
)

;; 带状态版本的字段扫描
(defun OCS:scanFieldSt (s i len st / depth c j closed)
  (setq j (+ i 2) depth 1 closed nil)
  (while (and (<= j len) (not closed))
    (setq c (substr s j 1))
    (cond
      ((= c "\\") (setq j (+ j 2)))
      ((and (= c "%") (< j len) (= (substr s (1+ j) 1) "<"))
       (setq depth (1+ depth) j (+ j 2)))
      ((and (= c ">") (< j len) (= (substr s (1+ j) 1) "%"))
       (setq depth (1- depth) j (+ j 2))
       (if (<= depth 0) (setq closed T)))
      (T (setq j (1+ j)))
    )
  )
  (if (not closed)
    (setq st (OCS:addIssue st "UNTERMINATED_FIELD" i "字段 %<...>% 未闭合"))
  )
  st
)

(defun OCS:bumpChanges (st)
  (list "i" (OCS:assocd "i" st 1)
        "issues" (OCS:assocd "issues" st nil)
        "changes" (1+ (OCS:assocd "changes" st 0))
        "len" (OCS:assocd "len" st 0))
)

;; 重写字体描述：替换族名，保留 b/i，按目标覆盖/追加 c、pf
(defun OCS:rewriteDesc (desc target / parts out first p fam kv)
  (setq parts (OCS:splitDesc desc) out nil first T fam nil)
  (foreach p parts
    (cond
      ((= p "") nil)
      (first
        (setq fam p)
        (setq out (list (OCS:assocd "family" target "SimSun")))
        (setq first nil)
      )
      ((and (= (substr p 1 1) "b") (OCS:allDigits (substr p 2 100)))
       (setq out (append out (list p))))
      ((and (= (substr p 1 1) "i") (OCS:allDigits (substr p 2 100)))
       (setq out (append out (list p))))
      ((and (= (substr p 1 1) "c") (OCS:allDigits (substr p 2 100)))
       (setq out (append out (list (strcat "c" (itoa (OCS:targetCharSet target)))))))
      ((and (= (substr p 1 1) "p") (= (substr p 2 1) "f") (OCS:allDigits (substr p 3 100)))
       (setq out (append out (list (strcat "pf" (itoa (OCS:targetPitchFamily target)))))))
      (T (setq out (append out (list p))))
    )
  )
  ;; 补目标参数
  (if (not (OCS:hasParam out "c"))
    (setq out (append out (list (strcat "c" (itoa (OCS:targetCharSet target)))))))
  (if (not (OCS:hasParam out "pf"))
    (setq out (append out (list (strcat "pf" (itoa (OCS:targetPitchFamily target)))))))
  ;; 拼接
  (setq kv "")
  (foreach p out
    (if (= kv "") (setq kv p) (setq kv (strcat kv "|" p)))
  )
  kv
)

;;; =====================================================================
;;; 预检：OCS:Preflight / OCS:ResolveSongFont
;;; =====================================================================

;; 目标字体解析（方案第 3 节）：
;; 1) 检测系统与 CAD 字体目录中的 SimSun 字体文件；
;; 2) 生成试验样式，写入 FontFile + SetFont，读回验证；
;; 3) 清空大字体并读回确认；
;; 4) 任一失败 → 在业务写入之前退出。
(defun OCS:ResolveSongFont ( / f res )
  ;; 扁平 plist（与 makeReport 一致）
  (setq res (list "ok" nil "family" "SimSun" "charSet" 134 "pitchFamily" 22
                  "fontFile" nil "fontFileSource" nil "bigFontEmpty" nil
                  "problems" nil "appendParams" T))
  ;; 候选字体文件（顺序即优先级；不接受 NSimSun/SimHei/STSong 顶替）
  (setq res (OCS:addProblem res "info" "候选字体文件扫描"))
  (setq f (OCS:findSimSunFile))
  (if (not f)
    (setq res (OCS:addProblem res "error"
      "未找到 SimSun 字体文件（simsun.ttc / simsun.ttf / SIMSUN.TTF），不能用其他字体替代"))
    (progn
      (setq res (OCS:putPair res "fontFile" f))
      (setq res (OCS:putPair res "fontFileSource" (OCS:fontFileSource f)))
    )
  )
  ;; 试验样式写入验证
  (setq res (OCS:putPair res "ok" (not (OCS:hasError res))))
  res
)

(defun OCS:addProblem (res level msg)
  (append res (list (list "problem" level msg)))
)
(defun OCS:putPair (res key val / out done item)
  (setq out nil done nil)
  (while res
    (setq item (car res))
    (cond
      ((OCS:consp item)
       (setq out (append out (list item)) res (cdr res)))
      ((and (not done) (equal item key))
       (setq out (append out (list key val)))
       (setq done T)
       (setq res (cdr (cdr res)))
      )
      (T
       (setq out (append out (list item (cadr res))))
       (setq res (cdr (cdr res)))
      )
    )
  )
  (if (not done) (setq out (append out (list key val))))
  out
)
(defun OCS:getVal (res key default / i n)
  ;; 固定三个参数：所有调用显式传入缺省值。
  (OCS:assocd key res default)
)

(defun OCS:findSimSunFile ( / winDir f)
  (setq winDir (getenv "WinDir"))
  (cond
    ((findfile "simsun.ttc")        (list (findfile "simsun.ttc") "simsun.ttc"))
    ((findfile "SIMSUN.TTC")        (list (findfile "SIMSUN.TTC") "SIMSUN.TTC"))
    ((findfile "simsun.ttf")        (list (findfile "simsun.ttf") "simsun.ttf"))
    ((and winDir (findfile (strcat winDir "\\Fonts\\simsun.ttc")))
     (list (findfile (strcat winDir "\\Fonts\\simsun.ttc")) "simsun.ttc"))
    ((and winDir (findfile (strcat winDir "\\Fonts\\simsun.ttf")))
     (list (findfile (strcat winDir "\\Fonts\\simsun.ttf")) "simsun.ttf"))
    (T nil)
  )
)

;; 字体文件来源：用于报告的原始名称；写入时优先使用 findfile 解析路径。
(defun OCS:fontFileSource ( pair )
  (if (OCS:consp pair) (cadr pair) pair)
)

;;; 日期：2026-10-13。试写和正式写入共用；接口成功必须再核对实际读回。
(defun OCS:songFontFileP (file)
  (and (OCS:stringp file) (> (strlen file) 0)
       (= (strcase (vl-filename-base file)) "SIMSUN")
       (member (strcase (vl-filename-extension file)) (list ".TTC" ".TTF")))
)

(defun OCS:fontState (obj phase / state data)
  (setq data (entget (vlax-vla-object->ename obj)))
  (setq state (list "file" (OCS:requireProp obj 'FontFile)
                    "font" (OCS:getStyleFont obj)
                    "dxf3" (OCS:assocd 3 data "") "dxf4" (OCS:assocd 4 data "")
                    "acadXdata" (assoc -3 (entget (vlax-vla-object->ename obj) '("ACAD")))))
  (setq state (OCS:putPair state "bindingMode" (OCS:fontBindingMode state)))
  (OCS:trace "FONT_STATE" (list "phase" phase "style" (OCS:safeProp obj 'Name) "state" state))
  state
)

;; 日期：2026-10-13。TTC 可由 SetFont 描述符绑定，此时两处文件名均为空。
;; 只允许两处均为宋体文件或均为空；非空错误文件和接口不一致仍拒绝。
(defun OCS:fontBindingMode (state / file dxf)
  (setq file (OCS:assocd "file" state nil) dxf (OCS:assocd "dxf3" state nil))
  (cond
    ((and (OCS:songFontFileP file) (OCS:songFontFileP dxf)) "file")
    ((and (equal file "") (equal dxf "")) "typeface")
    (T nil))
)

(defun OCS:fontStateMatches (state bold italic / font family)
  (setq font (OCS:assocd "font" state nil) family (OCS:assocd "family" font ""))
  (and (OCS:fontBindingMode state)
       (OCS:stringp family) (OCS:isTargetFamily family nil)
       (equal bold (OCS:assocd "bold" font nil))
       (equal italic (OCS:assocd "italic" font nil))
       (= 134 (OCS:assocd "charSet" font 0))
       (= 22 (OCS:assocd "pitchFamily" font 0)))
)

(defun OCS:fontStateStable (expected actual / font)
  (setq font (OCS:assocd "font" expected nil))
  (and (OCS:fontStateMatches actual (OCS:assocd "bold" font nil) (OCS:assocd "italic" font nil))
       (equal (OCS:fontBindingMode expected) (OCS:fontBindingMode actual)))
)

(defun OCS:writeSongFont (obj spec bold italic / files face faces selected path result state order answer errors preferred ent name)
  (setq files (OCS:assocd "fontFile" spec nil))
  (if (not (listp files)) (setq files (list files)))
  (setq preferred (OCS:assocd "setFontFamily" spec "SimSun"))
  (setq faces (list preferred (if (= preferred "宋体") "SimSun" "宋体")) answer nil errors nil)
  ;; 日期：2026-10-13。entmod 会重置部分 CAD 的字体描述符，必须先清大字体。
  ;; bold/italic 已由调用者在任何写入之前保存；SetFont 后只允许只读核对。
  (setq ent (vlax-vla-object->ename obj) name (OCS:requireProp obj 'Name))
  (setq result (OCS:clearBigFont ent name))
  (if (OCS:errp result)
    (setq faces nil errors (list (strcat "大字体预清空失败：" (OCS:errmsg result)))))
  (foreach face faces
    (if (not answer)
      (progn
        (setq selected nil)
        ;; findfile 解析到的完整路径优先；不再先试现场已失败的裸文件名。
        (foreach path files
          (if (and (not selected) (OCS:stringp path) (> (strlen path) 0))
            (progn
              (setq result (OCS:writeCall 'vla-put-FontFile (list obj path)))
              (if (vl-catch-all-error-p result)
                (setq errors (cons (vl-catch-all-error-message result) errors))
                (setq selected path)))))
        (if selected
          (progn
            (OCS:fontState obj "after-FontFile")
            (setq result (OCS:writeCall 'vla-SetFont (list obj face bold italic 134 22)))
            (if (vl-catch-all-error-p result)
              (setq errors (cons (vl-catch-all-error-message result) errors))
              (progn
                (setq state (OCS:fontState obj "after-SetFont") order "clearBigFont -> FontFile -> SetFont")
                ;; 不再重写 FontFile：现场证据显示这会清空已正确解析的宋体描述符。
                (if (and (not (vl-catch-all-error-p result)) (OCS:fontStateMatches state bold italic))
                  (setq answer (list "ok" T "setFontFamily" face "fontFileApplied" selected "writeOrder" order "state" state))
                  (setq errors (cons (strcat face "：字体文件、字体族、字符集或粗斜体读回不匹配") errors))))))))))
  (if answer
    (progn
      (setq result (OCS:checkBigFontEmpty ent name))
      (if (OCS:errp result)
        (setq answer nil errors (cons (strcat "设置宋体后大字体校验失败：" (OCS:errmsg result)) errors)))))
  (if (not answer)
    (setq answer (list "ok" nil "error" (strcat "宋体写入读回失败：" (OCS:fmt (reverse errors))))))
  (OCS:trace "FONT_WRITE_RESULT" answer)
  answer
)

;; 在临时样式上验证写入/读回
(defun OCS:probeFontBody (res name / ent obj created writeResult key expected)
  (setq created (OCS:writeCall 'entmake
    (list (list (cons 0 "STYLE") (cons 100 "AcDbSymbolTableRecord")
      (cons 100 "AcDbTextStyleTableRecord") (cons 2 name) (cons 70 0)
      (cons 40 0.0) (cons 41 1.0) (cons 50 0.0) (cons 71 0) (cons 42 0.2)
      (cons 3 (OCS:styleBaseFont)) (cons 4 "")))))
  (setq ent (tblobjname "STYLE" name))
  (if (or (vl-catch-all-error-p created) (not ent))
    (OCS:addProblem res "error" "创建试验文字样式失败")
    (progn
      (setq *OCS:Wrote* T obj (vlax-ename->vla-object ent))
      (setq writeResult (OCS:writeSongFont obj res :vlax-false :vlax-false))
      (if (not (OCS:assocd "ok" writeResult nil))
        (setq res (OCS:addProblem res "error" (OCS:assocd "error" writeResult "宋体试写失败")))
        (progn
          (foreach key (list "setFontFamily" "fontFileApplied" "writeOrder")
            (setq res (OCS:putPair res key (OCS:assocd key writeResult nil))))
          (setq res (OCS:verifyBigFontClear res ent name))
          (setq expected (OCS:assocd "state" writeResult nil))
          (if (not (OCS:fontStateStable expected (OCS:fontState obj "probe-after-check")))
            (setq res (OCS:addProblem res "error" "临时样式只读复核后宋体绑定不匹配")))
          (if (not (OCS:hasError res))
            (progn
              (OCS:mustCall 'vla-Regen (list (OCS:activeDoc) 1))
              (if (not (OCS:fontStateStable expected (OCS:fontState obj "probe-after-regen")))
                (setq res (OCS:addProblem res "error" "临时样式再生后宋体绑定读回不匹配")))))))
      ;; 清理由 verifyFontWrite 的统一出口执行。
      res))
)

(defun OCS:hasError (res / p)
  ;; 扫描列表中是否有 error 级 problem（foreach+consp，避免 assoc 对扁平裸字符串报错）
  (OCS:findError res)
)
(defun OCS:findError (res / found item)
  (setq found nil)
  (foreach item res
    (if (and (OCS:consp item) (equal (car item) "problem")
             (OCS:consp (cdr item)) (equal (cadr item) "error"))
      (setq found T)
    )
  )
  found
)

(defun OCS:tempStyleName ()
  (OCS:unusedStyleName "OCS_TMP_VERIFY_STYLE" 0)
)

(defun OCS:unusedStyleName (prefix index / name)
  (setq name (strcat prefix "_" (itoa index)))
  (while (tblobjname "STYLE" name)
    (setq index (1+ index) name (strcat prefix "_" (itoa index))))
  name
)

(defun OCS:styleBaseFont ()
  ;; 样式基字体使用普通 txt，若不可用退回 romans；与目标字体无关
  (if (findfile "txt.shx") "txt.shx" (if (findfile "romans.shx") "romans.shx" "simplex.shx"))
)

(defun OCS:deleteStyleIfExists (name / ent)
  (setq ent (tblobjname "STYLE" name))
  (if ent
    (vla-Delete (vlax-ename->vla-object ent))
  )
)

;; 日期：2026-10-13。写入由 writeSongFont 前置清理完成，此处只读。
(defun OCS:verifyBigFontClear (res ent name / r)
  (setq r (OCS:checkBigFontEmpty ent name))
  (if (OCS:errp r)
    (setq res (OCS:addProblem res "error"
                (strcat "大字体只读校验失败：" (OCS:errmsg r))))
    (setq res (OCS:putPair res "bigFontEmpty" T)))
  res
)

(defun OCS:ensureBigFont4 (e val / o r)
  (setq o (vlax-ename->vla-object (cdr (assoc -1 e))))
  (setq r (OCS:writeCall 'vla-put-BigFontFile (list o val)))
  (if (vl-catch-all-error-p r)
    ;; 文档不允许空字符串，但允许非空；写入失败则用 entmod 补组码 4
    (vl-catch-all-apply 'entmod (list (OCS:substDxf4 val e)))
  )
  T
)

;; 替换组码 4（无则追加），返回新 entlist；entmod 错误以 (:error . msg) 表示
(defun OCS:substDxf4 (val e / out found r pair)
  (setq out nil found nil)
  (foreach pair e
    (if (= (car pair) 4)
      (progn
        (setq found T)
        (setq out (append out (list (cons 4 val))))
      )
      (setq out (append out (list pair)))
    )
  )
  (if (not found)
    (setq out (append out (list (cons 4 val))))
  )
  (setq r (OCS:writeCall 'entmod (list out)))
  (if (vl-catch-all-error-p r)
    (cons "error" (vl-catch-all-error-message r))
    (if (null r) (cons "error" "entmod 返回 nil") out)
  )
)

;;; =====================================================================
;;; 环境预检 OCS:Preflight
;;; =====================================================================

(defun OCS:Preflight ( / res acadObj undoctl)
  (setq res (list "ok" nil))
  ;; 1. AutoLISP/Visual LISP/ActiveX（只探测，不执行任何命令）
  (setq res (OCS:putPair res "acadver" (getvar "ACADVER")))
  (setq res (OCS:putPair res "product"  (getvar "PRODUCT")))
  (setq res (OCS:putPair res "lispys"   (getvar "LISPSYS")))
  (setq res (OCS:putPair res "platform" (getvar "PLATFORM")))
  (setq acadObj (vl-catch-all-apply 'vlax-get-acad-object nil))
  (if (vl-catch-all-error-p acadObj)
    (setq res (OCS:addProblem res "error" "Visual LISP/ActiveX 不可用"))
  )
  ;; 2. 撤销可用性（UNDOCTL 位 0 = UNDO 开启）
  (setq undoctl (getvar "UNDOCTL"))
  (setq res (OCS:putPair res "undoctl" undoctl))
  (if (= 0 (logand undoctl 1))
    (setq res (OCS:addProblem res "error" "图纸撤销（UNDO）不可用，不能保证一次 U 恢复"))
  )
  (if (/= 0 (logand undoctl 8))
    (setq res (OCS:addProblem res "error" "已有外部撤销分组，不能保证只撤销本次操作")))
  ;; 3. 文档可写（锁定/只读）
  (setq res (OCS:checkDocWritable res))
  ;; 4. 字体解析
  (setq res (OCS:putPair res "font" (OCS:ResolveSongFont)))
  (if (OCS:findError (OCS:getVal res "font" nil))
    (setq res (OCS:addProblem res "error" "宋体字体解析失败（详见 :font）"))
  )
  ;; 5. 关键接口存在性
  (setq res (OCS:checkInterfaces res))
  (setq res (OCS:putPair res "ok" (not (OCS:findError res))))
  res
)

(defun OCS:checkDocWritable (res / doc ro)
  (setq doc (OCS:activeDoc))
  (if (not doc)
    (OCS:addProblem res "error" "无法获取活动文档")
    (progn
      (setq ro (vl-catch-all-apply 'vla-get-ReadOnly (list doc)))
      ;; 只读降级为警告：部分克隆引擎（天正/浩辰内核）该属性存根恒返 TRUE，
      ;; 若图纸真只读，后续写入会被 vl-catch-all 拦截并走回滚，不会损坏图纸。
      (if (and (not (vl-catch-all-error-p ro)) (equal ro :vlax-true))
        (OCS:addProblem res "warn" "文档报告为只读（引擎可能误报；写入失败将自动回滚）")
        res
      )
    )
  )
)

(defun OCS:checkInterfaces (res / doc)
  (setq doc (OCS:activeDoc))
  (if (not doc)
    (OCS:addProblem res "error" "ActiveX 文档不可用")
    (progn
      (if (not (OCS:methodOk doc 'vla-get-Blocks))
        (setq res (OCS:addProblem res "error" "Blocks 集合接口不可用")))
      res
    )
  )
)

(defun OCS:activeDoc ( / acad doc)
  (setq acad (vl-catch-all-apply 'vlax-get-acad-object nil))
  (if (vl-catch-all-error-p acad) nil
    (progn
      (setq doc (vl-catch-all-apply 'vla-get-ActiveDocument (list acad)))
      (if (vl-catch-all-error-p doc) nil doc)
    )
  )
)
(defun OCS:activeDoc* ()
  (vla-get-ActiveDocument (vlax-get-acad-object))
)

;;; =====================================================================
;;; 样式收集 OCS:CollectStyles
;;; 方案第 3 节：DXF 70 位 1 = 形文件记录，位 16 = 外参依赖；
;;; 不按名称含 "|" 判断；Standard 与注释性样式照常处理。
;;; =====================================================================

(defun OCS:CollectStyles ( / res ent lst e flg name)
  (setq res (list "normal" nil "shape" nil "xref" nil "vertical" nil "count" 0))
  (OCS:setStage "读取文字样式表 STYLE")
  (setq ent (tblnext "STYLE" T))
  (while ent
    (setq flg (OCS:assocd 70 ent 0)
          name (OCS:assocd 2 ent ""))
    (OCS:setStage (strcat "扫描文字样式 " name))
    (cond
      ((/= 0 (logand flg 1))
       ;; 形文件记录（LOAD 请求）→ 跳过并分类记录
       (setq res (OCS:lstAppend res "shape" name))
      )
      ((/= 0 (logand flg 16))
       ;; 外部参照依赖记录 → 跳过并分类记录
       (setq res (OCS:lstAppend res "xref" name))
      )
      (T
       (setq res (OCS:lstAppend res "normal"
                  (list "name" name
                        "flags" flg
                        "vertical" (/= 0 (logand flg 4))
                        "annotative" (OCS:isAnnotativeStyle (tblobjname "STYLE" name))
                        "bigFontBefore" (OCS:assocd 4 ent "")
                        "fontFileBefore" (OCS:assocd 3 ent "")
                        "before" (OCS:styleSnapshot (tblobjname "STYLE" name))
                        "fontBefore" (OCS:getStyleFont (vlax-ename->vla-object (tblobjname "STYLE" name)))
                        "dxf" ent)))
      )
    )
    (setq ent (tblnext "STYLE" nil))
  )
  (setq res (OCS:putPair res "count" (length (OCS:getVal res "normal" nil))))
  res
)

(defun OCS:lstAppend (res key val)
  (OCS:putPair res key (if *OCS:CollectReverse*
    (cons val (OCS:getVal res key nil))
    (append (OCS:getVal res key nil) (list val))))
)

;; 注释性判断：组码 1071 不含注释位；注释性在组码 70 无位，
;; 通过扩展数据/对象模型的 Annotative 属性判断；此处用
;; entget 的 1071 之外，另查 (assoc 1071 ...) 不可靠 → 用对象接口。
(defun OCS:isAnnotativeStyle (ent / o r)
  (setq o (vlax-ename->vla-object ent))
  (setq r (vl-catch-all-apply 'vla-get-Annotative (list o)))
  (if (vl-catch-all-error-p r) nil
    (equal r :vlax-true)
  )
)

;;; =====================================================================
;;; 图块与宿主收集 OCS:CollectHosts
;;; 方案第 4 节：以 Blocks 集合为主入口；按句柄去重；
;;; 遇外参块停止进入；动态块同时扫描原始定义与匿名表示；
;;; 标注/表格等生成的匿名显示块按来源分类处理。
;;; =====================================================================

(defun OCS:CollectHosts ( / res doc blocks count i blk key *OCS:CollectReverse*)
  (setq *OCS:CollectReverse* T)
  (setq res (list "blocks" 0 "xrefBlocks" 0 "displayBlocks" 0
                  "entities" 0 "attribs" 0 "unknown" 0
                  "blockList" nil "skipped" nil))
  (setq doc (OCS:activeDoc))
  (if (not doc)
    (OCS:addProblem res "error" "无法获取活动文档")
    (progn
      (OCS:setStage "读取图块集合 Blocks")
      (setq blocks (OCS:requireProp doc 'Blocks)
            count (OCS:requireProp blocks 'Count))
      (setq i 1)
      (while (<= i count)
        (OCS:setStage (strcat "读取图块集合 Blocks，索引 " (itoa (1- i))))
        (setq blk (OCS:safeItem blocks i))
        (if blk
          (setq res (OCS:collectBlock res doc blk))
        )
        (setq i (1+ i))
      )
      (foreach key (list "hosts" "skipped" "blockList" "tchCandidates")
        (setq res (OCS:putPair res key (reverse (OCS:getVal res key nil)))))
      res
    )
  )
)

(defun OCS:safeItem (coll i)
  (OCS:mustCall 'vla-Item (list coll (1- i)))
)

(defun OCS:collectBlock (res doc blk / name isXref ownerH handle btype)
  (setq name (OCS:requireProp blk 'Name)
        handle (OCS:requireProp blk 'Handle))
  (if (not name)
    res
    (progn
      (OCS:setStage (strcat "扫描图块 " name " [" handle "]"))
      (setq isXref (OCS:boolProp blk 'IsXRef))
      ;; 匿名块分类：动态块表示(*U...)、标注/表格显示缓存(*D.../*T...)、其他
      (setq btype (OCS:classifyBlockName name))
      (cond
        ;; 外部参照块：停止进入，不跨外部数据库
        ((or isXref (OCS:strContains name "|"))
         (setq res (OCS:putPair res "xrefBlocks" (1+ (OCS:getVal res "xrefBlocks" 0))))
         (setq res (OCS:lstAppend res "skipped" (list "XREF_BLOCK" handle name)))
        )
        ((equal btype "display-cache")
         ;; 标注/表格等的显示缓存：交由其源宿主处理，不直接改写
         (setq res (OCS:putPair res "displayBlocks" (1+ (OCS:getVal res "displayBlocks" 0))))
         (setq res (OCS:lstAppend res "skipped" (list "DISPLAY_CACHE" handle name)))
        )
        (T
         (setq res (OCS:putPair res "blocks" (1+ (OCS:getVal res "blocks" 0))))
         (setq res (OCS:lstAppend res "blockList" (list "name" name "handle" handle "obj" blk)))
         ;; 扫描块内实体
         (setq res (OCS:scanBlockContents res doc blk name handle))
        )
      )
      res
    )
  )
)

;; 匿名块来源分类（方案第 4 节第 6 条）
(defun OCS:classifyBlockName (name / n)
  (setq n (strcase name))
  (cond
    ((= (substr n 1 2) "*U") "dynamic-repr")
    ((or (= (substr n 1 2) "*D") (= (substr n 1 2) "*T")) "display-cache")
    (T "named")
  )
)

(defun OCS:scanBlockContents (res doc blk bname bhandle / ents count i e label)
  (setq ents blk) ; Block 本身就是实体集合
  (setq label (strcat "扫描图块 " bname " [" bhandle "]"))
  (OCS:setStage label)
  (setq count (OCS:requireProp ents 'Count) i 1)
  (while (<= i count)
    (OCS:setStage (strcat label "，实体索引 " (itoa (1- i))))
    (setq e (OCS:safeItem ents i))
    (if e (setq res (OCS:visitEntity res doc e (list "block" bname bhandle))))
    (setq i (1+ i))
  )
  res
)

;; 实体访问（去重按句柄）
(defun OCS:visitEntity (res doc e ctx / typ handle seen)
  (setq typ (OCS:safeProp e 'ObjectName))
  (if (not typ)
    (progn
      (setq res (OCS:putPair res "unknown" (1+ (OCS:getVal res "unknown" 0))))
      (setq res (OCS:lstAppend res "skipped" (list "UNKNOWN_OBJECT" "?" (OCS:ctxStr ctx))))
    )
    (progn
      (setq handle (OCS:requireProp e 'Handle))
      (setq seen (OCS:seenP res handle))
      (if (not seen)
        (progn
          (setq res (OCS:markSeen res handle))
          (OCS:setStage (strcat "扫描实体 " typ " [" handle "] " (OCS:ctxStr ctx)))
          (setq res (OCS:handleEntity res doc e typ ctx handle))
        )
      )
      res
    )
  )
)

(defun OCS:ctxStr (ctx)
  (if (null ctx) "-"
    (if (= (car ctx) "block")
      (strcat "块:" (cadr ctx))
      (strcat "空间:" (cadr ctx))
    )
  )
)

;; 记录处理
(defun OCS:seenP (res h)
  (and h (vl-position h (OCS:getVal res "seen" nil)))
)
(defun OCS:markSeen (res h)
  (if h
    (OCS:putPair res "seen" (cons h (OCS:getVal res "seen" nil)))
    res
  )
)

;; 按对象类型分发
(defun OCS:handleEntity (res doc e typ ctx handle / cls)
  (setq cls (if *OCS:CheckOnly* "other" (OCS:mapClass typ)))
  (OCS:trace "ENTITY" (list "handle" handle "type" typ "class" cls "context" ctx "layer" (OCS:safeProp e 'Layer)))
  (cond
    ((equal cls "text")     (OCS:collectTextHost res doc e ctx handle typ))
    ((equal cls "mtext")    (OCS:collectTextHost res doc e ctx handle typ))
    ((equal cls "attrib")   (OCS:collectAttrib res doc e ctx handle typ))
    ((equal cls "attdef")   (OCS:collectAttrib res doc e ctx handle typ))
    ((equal cls "dim")      (OCS:collectDim res doc e ctx handle typ))
    ((equal cls "mleader")  (OCS:collectMLeader res doc e ctx handle typ))
    ((equal cls "leader")   (OCS:collectLeader res doc e ctx handle typ))
    ((equal cls "table")    (OCS:collectTable res doc e ctx handle typ))
    ((equal cls "tolerance")(OCS:collectTolerance res doc e ctx handle typ))
    ((equal cls "blockref") (OCS:collectBlockRef res doc e ctx handle typ))
    ((equal cls "attribute-dest") res) ; 由 blockref 处理
    (T
     ;; 专业/代理对象：记录为未覆盖
     (if (OCS:isUnknownClass typ)
       (progn
         (if (and *OCS:CheckOnly* (OCS:tchKind typ))
           (setq res (OCS:lstAppend res "tchCandidates"
             (list "obj" e "type" typ "handle" handle "ctx" ctx))))
         (setq res (OCS:putPair res "unknown" (1+ (OCS:getVal res "unknown" 0))))
         (OCS:trace "UNSUPPORTED_OBJECT" (list handle typ ctx))
         (setq res (OCS:lstAppend res "skipped"
                      (list "PROXY_OR_PRO" handle (strcat typ "@" (OCS:ctxStr ctx)))))
       )
     )
     res
    )
  )
)

(defun OCS:isUnknownClass (typ)
  (not (OCS:knownClass typ))
)

(defun OCS:knownClass (typ)
  (or (/= (OCS:mapClass typ) "other")
      (member (strcase typ)
        (list "ACDBLINE" "ACDBARC" "ACDBCIRCLE" "ACDBELLIPSE" "ACDBSPLINE"
              "ACDBPOLYLINE" "ACDB2DPOLYLINE" "ACDB3DPOLYLINE" "ACDBPOINT"
              "ACDBHATCH" "ACDBSOLID" "ACDB3DSOLID" "ACDBFACE" "ACDBTRACE"
              "ACDBRAY" "ACDBXLINE" "ACDBREGION" "ACDBVIEWPORT" "ACDBMLINE"
              "ACDBRASTERIMAGE" "ACDBWIPEOUT" "ACDBOLE2FRAME" "ACDBPDFREFERENCE")))
)

;; 类型 → 分类（DXF/ObjectName 映射）
(defun OCS:mapClass (typ / clsName)
  (setq clsName (OCS:lower typ))
  (cond
    ((or (= clsName "acad_text")   (= clsName "acdbtext"))          "text")
    ((or (= clsName "acad_mtext")  (= clsName "acdbmtext"))         "mtext")
    ((or (= clsName "acad_attribute") (= clsName "acdbattribute"))  "attrib")
    ((or (= clsName "acad_attributereference") (= clsName "acdbattributereference")) "attrib")
    ((or (= clsName "acad_attributedefinition") (= clsName "acdbattributedefinition")) "attdef")
    ;; 日期：2026-10-13。类名含关键字不能证明支持原生接口，天正标注会误报 TextOverride。
    ((member clsName (list "acdbaligneddimension" "acdbrotateddimension"
       "acdb2lineangulardimension" "acdb3pointangulardimension"
       "acdbdiametricdimension" "acdbradialdimension" "acdbradialdimensionlarge"
       "acdbarcdimension" "acdbordinatedimension" "acdbdimension"
       "acad_dimension")) "dim")
    ;; 专业对象名称含 Leader 不代表具备普通引线接口，必须匹配原生类名。
    ((member clsName (list "acdbmleader" "acad_mleader"))      "mleader")
    ((member clsName (list "acdbleader" "acad_leader"))       "leader")
    ((member clsName (list "acdbtable" "acad_table"))         "table")
    ((member clsName (list "acdbtolerance" "acad_tolerance")) "tolerance")
    ((or (= clsName "acad_blockreference") (= clsName "acdbblockreference")) "blockref")
    (T "other")
  )
)

;;; ---------------------------------------------------------------------
;;; 各宿主“读”：收集进计划（只读阶段）
;;; ---------------------------------------------------------------------

(defun OCS:collectTextHost (res doc e ctx handle typ)
  (setq res (OCS:putPair res "entities" (1+ (OCS:getVal res "entities" 0))))
  (OCS:lstAppend res "hosts"
    (list "kind" (OCS:mapClass typ) "obj" e "handle" handle "ctx" ctx "type" typ))
)

(defun OCS:collectAttrib (res doc e ctx handle typ / isAttdef)
  (setq res (OCS:putPair res "attribs" (1+ (OCS:getVal res "attribs" 0))))
  (setq res (OCS:lstAppend res "hosts"
              (list "kind" (if (OCS:strContains (OCS:lower typ) "definition") "attdef" "attrib")
                    "obj" e "handle" handle "ctx" ctx "type" typ)))
  res
)

(defun OCS:collectDim (res doc e ctx handle typ)
  (OCS:lstAppend res "hosts"
    (list "kind" "dim" "obj" e "handle" handle "ctx" ctx "type" typ))
)

(defun OCS:collectMLeader (res doc e ctx handle typ)
  (OCS:lstAppend res "hosts"
    (list "kind" "mleader" "obj" e "handle" handle "ctx" ctx "type" typ))
)

(defun OCS:collectLeader (res doc e ctx handle typ / ann)
  (setq ann (OCS:requireProp e 'Annotation))
  (if ann (OCS:visitEntity res doc ann ctx) res)
)

(defun OCS:collectTable (res doc e ctx handle typ)
  (OCS:lstAppend res "hosts"
    (list "kind" "table" "obj" e "handle" handle "ctx" ctx "type" typ))
)

(defun OCS:collectTolerance (res doc e ctx handle typ)
  (OCS:lstAppend res "hosts"
    (list "kind" "tolerance" "obj" e "handle" handle "ctx" ctx "type" typ))
)

;; 块引用：额外处理属性实例（GetAttributes / GetConstantAttributes）
(defun OCS:collectBlockRef (res doc e ctx handle typ / blk name has attrs a meth label)
  (setq name (OCS:requireProp e 'Name))
  (setq label (strcat "读取块引用 " name " [" handle "]"))
  (OCS:setStage label)
  (setq blk (OCS:mustCall 'vla-Item (list (OCS:requireProp doc 'Blocks) name)))
  (if (not (or (OCS:boolProp blk 'IsXRef) (OCS:strContains name "|")))
    (progn
      (setq has (OCS:boolProp e 'HasAttributes))
      (if has
        (foreach meth (list 'vla-GetAttributes 'vla-GetConstantAttributes)
          (OCS:setStage (strcat label " / " (vl-symbol-name meth)))
          (setq attrs (OCS:variantToList (OCS:mustCall meth (list e))))
          (foreach a attrs (setq res (OCS:visitEntity res doc a ctx)))))
    )
  )
  res
)

;;; =====================================================================
;;; 安全 COM 访问
;;; =====================================================================

(defun OCS:safeProp (obj prop / r)
  (if (null obj) nil
    (progn
      (setq r (vl-catch-all-apply (read (strcat "vla-get-" (vl-symbol-name prop))) (list obj)))
      (if (vl-catch-all-error-p r)
        (progn
          (OCS:trace "OPTIONAL_PROPERTY_ERROR" (list (vl-symbol-name prop) (vl-catch-all-error-message r)))
          nil)
        r)
    )
  )
)

(defun OCS:safeMethod (obj meth args / r)
  (if (null obj) (cons "error" "nil object")
    (progn
      (setq r (vl-catch-all-apply (read (strcat "vla-" (vl-symbol-name meth))) (cons obj args)))
      (if (vl-catch-all-error-p r)
        (cons "error" (vl-catch-all-error-message r))
        r
      )
    )
  )
)

;; 空 SAFEARRAY 是合法返回值，但直接转列表可报 ActiveX 无效索引。
;; 仅在成功读取各维边界后判空；真实读取错误不得伪装成没有属性。
(defun OCS:safeArrayToList (value / dims dim lo hi empty)
  (setq dims (OCS:mustCall 'vlax-safearray-get-dim (list value)))
  (if (or (not (numberp dims)) (< dims 1) (/= dims (fix dims)))
    (OCS:fail "SAFEARRAY 维数无效"))
  (setq dim 1 empty nil)
  (while (<= dim dims)
    (setq lo (OCS:mustCall 'vlax-safearray-get-l-bound (list value dim))
          hi (OCS:mustCall 'vlax-safearray-get-u-bound (list value dim)))
    (if (or (not (numberp lo)) (not (numberp hi)))
      (OCS:fail "SAFEARRAY 上下界无效"))
    (if (< hi lo) (setq empty T))
    (setq dim (1+ dim)))
  (if empty nil (OCS:mustCall 'vlax-safearray->list (list value)))
)

;; Variant/SafeArray 解包（64 位 ObjectID 不转 32 位整数）
(defun OCS:variantToList (v / r)
  (cond
    ((null v) nil)
    ((listp v) v)
    ((equal (type v) 'VARIANT) (OCS:variantToList (OCS:mustCall 'vlax-variant-value (list v))))
    ((equal (type v) 'SAFEARRAY) (OCS:safeArrayToList v))
    (T (list v))
  )
)

;;; =====================================================================
;;; 修改计划 OCS:BuildPlan
;;; =====================================================================

(defun OCS:BuildPlan ( / plan styles hosts targets host data new scan partial item)
  (setq styles (OCS:CollectStyles) hosts (OCS:CollectHosts) targets nil)
  (if (OCS:hasError hosts) (OCS:fail (OCS:fmt (OCS:problemsOf hosts))))
  (foreach host (OCS:assocd "hosts" hosts nil)
    (OCS:setStage (strcat "读取宿主 " (OCS:assocd "type" host "?") " ["
                         (OCS:assocd "handle" host "?") "] " (OCS:ctxStr (OCS:assocd "ctx" host nil))))
    (setq data (OCS:ReadHost host))
    (if (OCS:assocd "error" data nil) (OCS:fail (OCS:assocd "error" data "")))
    (setq partial (OCS:assocd "partial" data nil))
    (if (not (OCS:assocd "skip" data nil))
      (progn
        (if (= (OCS:assocd "kind" data "") "table")
          (setq new data)
          (progn
            (setq scan (OCS:NormalizeFontRuns (OCS:assocd "text" data "") (OCS:fontTarget)))
            (if (OCS:assocd "issues" scan nil)
              (OCS:fail (strcat "内容解析失败：" (OCS:fmt (OCS:assocd "issues" scan nil)))))
            (setq new (OCS:putPair data "newText" (OCS:assocd "text" scan "")))
            (setq new (OCS:putPair new "changes" (OCS:assocd "changes" scan 0)))))
        (if (> (OCS:assocd "changes" new 0) 0)
          (if (OCS:assocd "protected" data nil)
            (setq partial (append partial (list "含字段的宿主保留原始字段关联，未改局部字体")))
            (progn
              (setq new (OCS:putPair new "before" (OCS:hostSnapshot (OCS:assocd "obj" host nil))))
              (setq new (OCS:putPair new "host" host))
              (setq targets (cons new targets)))))))
    (foreach item partial
      (setq hosts (OCS:putPair hosts "unknown" (1+ (OCS:assocd "unknown" hosts 0))))
      (setq hosts (OCS:lstAppend hosts "skipped" (list "PROTECTED_CONTENT" (OCS:assocd "handle" host "?") item)))))
  (list "styles" (OCS:assocd "normal" styles nil) "shape" (OCS:assocd "shape" styles nil)
        "xrefStyle" (OCS:assocd "xref" styles nil) "hosts" (OCS:assocd "hosts" hosts nil)
        "stats" hosts "targets" (reverse targets))
)

;;; =====================================================================
;;; 应用样式修改 OCS:ApplyStyle
;;; =====================================================================

(defun OCS:ApplyStyle (doc st / name ent obj font before after result bold italic expected state)
  (setq name (OCS:assocd "name" st "") ent (tblobjname "STYLE" name))
  (if (not ent)
    (list "ok" nil "name" name "error" "STYLE 记录未找到")
    (progn
      (setq obj (vlax-ename->vla-object ent) font (OCS:getStyleFont obj)
            bold (OCS:assocd "bold" font :vlax-false) italic (OCS:assocd "italic" font :vlax-false)
            before (OCS:styleSnapshot ent))
      (setq result (OCS:writeSongFont obj (OCS:assocd "font" *OCS:Plan* nil) bold italic))
      (if (not (OCS:assocd "ok" result nil))
        (list "ok" nil "name" name "error" (OCS:assocd "error" result "宋体写入失败"))
        (progn
          (setq expected (OCS:assocd "state" result nil))
          (setq result (OCS:checkBigFontEmpty ent name))
          (if (OCS:errp result)
            (list "ok" nil "name" name "error" (strcat "大字体清空失败：" (OCS:errmsg result)))
            (progn
              (setq after (OCS:styleSnapshot (tblobjname "STYLE" name)))
              (setq state (OCS:fontState obj "style-after-check"))
              (cond
                ((not (OCS:fontStateStable expected state))
                 (list "ok" nil "name" name "error" "样式只读复核后宋体绑定或粗斜体不匹配"))
                ((not (OCS:styleReadbackOk before after))
                 (list "ok" nil "name" name "error" "样式读回校验失败（非字体参数被改变）"))
                (T (list "ok" T "name" name "before" before "after" after "fontExpected" state)))))))))
)

(defun OCS:getStyleFont (obj / family bold italic charset pitch)
  (OCS:mustCall 'vla-GetFont (list obj 'family 'bold 'italic 'charset 'pitch))
  (list "family" family "bold" bold "italic" italic "charSet" charset "pitchFamily" pitch)
)

(defun OCS:styleIsTarget (ent / font state)
  (setq state (OCS:fontState (vlax-ename->vla-object ent) "target-check")
        font (OCS:assocd "font" state nil))
  (and (OCS:fontStateMatches state (OCS:assocd "bold" font nil) (OCS:assocd "italic" font nil))
       (= (OCS:assocd "dxf4" state "") "")
       (not (OCS:errp (OCS:checkBigFontEmpty ent (OCS:assocd 2 (entget ent) "")))))
)

(defun OCS:writeCall (fn args / r)
  (setq r (OCS:tracedCall fn args))
  (if (and *OCS:UndoMark* (not (vl-catch-all-error-p r)))
    (setq *OCS:Wrote* T))
  r
)

(defun OCS:styleTargetFontFile (doc / f)
  (setq f (OCS:getVal (OCS:getVal *OCS:Plan* "font" nil) "fontFile" nil))
  (if (OCS:consp f) (car f) f)
)

;; 样式非字体参数快照（40/41/50/70/71 + 未知组码计数）
(defun OCS:styleSnapshot (ent / e out)
  (if (not ent) nil
    (progn
      (setq e (entget ent))
      (list
        "h"     (OCS:assocd 5 e "")
        "name"  (OCS:assocd 2 e "")
        "dxf40"    (OCS:assocd 40 e nil)
        "dxf41"    (OCS:assocd 41 e nil)
        "dxf50"    (OCS:assocd 50 e nil)
        "dxf70"    (OCS:assocd 70 e nil)
        "dxf71"    (OCS:assocd 71 e nil)
        "dxf1071"  (OCS:assocd 1071 e nil)
        "xdata" (OCS:nonFontXdata (entget ent '("*")))
      )
    )
  )
)

(defun OCS:xdataKeys (e / keys pair)
  (setq keys nil)
  (foreach pair e
    (if (and (OCS:consp pair) (numberp (car pair)) (>= (car pair) 1000))
      (setq keys (cons (car pair) keys))
    )
  )
  keys
)

(defun OCS:styleReadbackOk (before after / ok key)
  (setq ok T)
  (foreach key (list "name" "dxf40" "dxf41" "dxf50" "dxf70" "dxf71" "xdata")
    (if (not (equal (OCS:assocd key before nil) (OCS:assocd key after nil) 1e-9))
      (setq ok nil)
    )
  )
  ok
)

;; 日期：2026-10-13。只读检查同时覆盖 DXF 和 COM，缺失组码也不能跳过 COM。
(defun OCS:checkBigFontEmpty (ent name / dxf com)
  (setq dxf (OCS:assocd 4 (entget ent) "")
        com (OCS:requireProp (vlax-ename->vla-object ent) 'BigFontFile))
  (OCS:trace "BIGFONT_CHECK" (list "style" name "dxf4" dxf "com" com))
  (if (and (equal dxf "") (equal com "")) T
    (cons "error" (strcat "大字体读回非空或不一致：" (OCS:fmt (list dxf com)))))
)

;; 仅在设置宋体之前调用；空值不执行 entmod，保留所有应用的 XData。
(defun OCS:clearBigFont (ent name / e r dxf com)
  (setq e (entget ent '("*")) dxf (OCS:assocd 4 e "")
        com (OCS:requireProp (vlax-ename->vla-object ent) 'BigFontFile))
  (OCS:trace "BIGFONT_CLEAR" (list "style" name "dxf4" dxf "com" com
    "action" (if (and (equal dxf "") (equal com "")) "skip-empty" "entmod-before-font")))
  (if (and (equal dxf "") (equal com "")) T
    (progn
      (setq r (OCS:substDxf4 "" e))
      (if (OCS:errp r) r (OCS:checkBigFontEmpty ent name))))
)

;;; =====================================================================
;;; 宿主读写 OCS:ReadHost / OCS:WriteHost
;;; =====================================================================

;; 读取宿主内容与必须保留的数据 → plist
(defun OCS:ReadHost (host / kind e)
  (setq kind (OCS:assocd "kind" host nil)
        e (OCS:assocd "obj" host nil))
  (cond
    ((or (equal kind "text") (equal kind "mtext"))
     (OCS:readTextLike host e))
    ((or (equal kind "attrib") (equal kind "attdef"))
     (OCS:readAttr host e))
    ((equal kind "dim")
     (OCS:readDim host e))
    ((equal kind "mleader")
     (OCS:readMLeader host e))
    ((equal kind "leader")
     (OCS:readLeader host e))
    ((equal kind "table")
     (OCS:readTable host e))
    ((equal kind "tolerance")
     (OCS:readTolerance host e))
    ((equal kind "blockref")
     (list "kind" kind "obj" e "skip" T))
    (T (list "kind" kind "obj" e "skip" T))
  )
)

;; TEXT/MTEXT：完整原始内容
(defun OCS:readTextLike (host e / kind data raw)
  (setq kind (OCS:assocd "kind" host nil))
  (setq data (OCS:readContent e kind 'TextString))
  (if (= kind "text")
    (OCS:putPair data "skip" T) ; TEXT 中的反斜杠是字面内容。
    (progn
      (setq raw (OCS:mustCall 'vla-FieldCode (list e)))
      (if (not (OCS:stringp raw)) (OCS:fail "FieldCode 未返回原始文本"))
      (setq data (OCS:putPair data "text" raw))
      (OCS:putPair data "protected" (or (OCS:assocd "protected" data nil) (OCS:containsField raw)))))
)

(defun OCS:readAttr (host e / kind mt data)
  (setq kind (OCS:assocd "kind" host nil) mt (OCS:boolProp e 'MTextAttribute))
  (setq data (OCS:readContent e kind (if mt 'MTextAttributeContent 'TextString)))
  (setq data (OCS:putPair data "multiline" mt))
  (if mt
    data
    (OCS:putPair data "skip" T))
)

(defun OCS:readDim (host e)
  (OCS:readContent e "dim" 'TextOverride)
)

(defun OCS:readMLeader (host e / content)
  (setq content (OCS:requireProp e 'ContentType))
  (cond
    ((= content 2) (OCS:readContent e "mleader" 'TextString))
    ((or (= content 0) (= content 1)) (list "kind" "mleader" "obj" e "skip" T))
    (T (OCS:fail "未知多重引线 ContentType")))
)

(defun OCS:readLeader (host e / ann)
  ;; 普通引线的关联注释对象
  (setq ann (OCS:leaderAnnotation e))
  (list "kind" "leader" "obj" e "annotation" ann)
)

(defun OCS:leaderAnnotation (e / r)
  (setq r (OCS:safeProp e 'Annotation))
  r
)

(defun OCS:readTable (host e / rows cols row col data cell edits partial changes)
  (setq rows (OCS:requireProp e 'Rows) cols (OCS:requireProp e 'Columns))
  (if (or (not (numberp rows)) (not (numberp cols)) (< rows 0) (< cols 0))
    (OCS:fail "表格行列数无效"))
  (setq row 0 edits nil partial nil changes 0)
  (while (< row rows)
    (setq col 0)
    (while (< col cols)
      (setq cell (OCS:tableReadCell e row col))
      (setq edits (append edits (OCS:assocd "edits" cell nil)))
      (setq partial (append partial (OCS:assocd "partial" cell nil)))
      (setq changes (+ changes (OCS:assocd "changes" cell 0)))
      (setq col (1+ col)))
    (setq row (1+ row)))
  (list "kind" "table" "obj" e "rows" rows "cols" cols "edits" edits
        "changes" changes "partial" partial "layout" (OCS:tableLayout e rows cols)
        "suppressed" (OCS:requireProp e 'RegenerateTableSuppressed))
)

(defun OCS:readTolerance (host e)
  (OCS:readContent e "tolerance" 'TextString)
)

;;; 写回宿主
(defun OCS:WriteHost (host data / kind e)
  (setq kind (OCS:assocd "kind" data (OCS:assocd "kind" host nil))
        e (OCS:assocd "obj" data (OCS:assocd "obj" host nil)))
  (cond
    ((or (equal kind "text") (equal kind "mtext"))
     (OCS:writeTextLike e data))
    ((or (equal kind "attrib") (equal kind "attdef"))
     (OCS:writeAttr e data))
    ((equal kind "dim")
     (OCS:writeDim e data))
    ((equal kind "mleader")
     (OCS:writeMLeader e data))
    ((equal kind "leader")
     (OCS:writeLeader e data))
    ((equal kind "table")
     (OCS:writeTable e data))
    ((equal kind "tolerance")
     (OCS:writeTolerance e data))
    (T (list "ok" nil "error" "未知宿主类型"))
  )
)

(defun OCS:writeTextLike (e data / txt r before)
  (setq txt (OCS:assocd "text" data nil))
  (if (null txt)
    (list "ok" nil "error" "无内容")
    (progn
      (setq before (OCS:assocd "before" data (OCS:hostSnapshot e)))
      (setq r (OCS:writeCall 'vla-put-TextString (list e txt)))
      (if (vl-catch-all-error-p r)
        (list "ok" nil "error" (vl-catch-all-error-message r))
        (OCS:verifyHost e before (list "text" txt))
      )
    )
  )
)

(defun OCS:writeAttr (e data / txt r before mt w r2)
  (setq txt (OCS:assocd "text" data nil))
  (if (null txt)
    (list "ok" nil "error" "无内容")
    (progn
      (setq before (OCS:assocd "before" data (OCS:hostSnapshot e)))
      (setq mt (OCS:safeProp e 'MTextAttribute))
      (if (equal mt :vlax-true)
        (progn
          (setq r (OCS:writeCall 'vla-put-MTextAttributeContent (list e txt)))
          (if (vl-catch-all-error-p r)
            (setq r (cons "error" (vl-catch-all-error-message r)))
            (progn
              ;; 多行属性：按可用接口更新显示
              (setq r2 (vl-catch-all-apply 'vla-UpdateMTextAttribute (list e)))
              (if (vl-catch-all-error-p r2)
                (setq r (cons "error" (strcat "UpdateMTextAttribute 失败：" (vl-catch-all-error-message r2))))
              )
            )
          )
        )
        (progn
          (setq r (OCS:writeCall 'vla-put-TextString (list e txt)))
          (if (vl-catch-all-error-p r)
            (setq r (cons "error" (vl-catch-all-error-message r)))
          )
        )
      )
      (if (OCS:errp r)
        (list "ok" nil "error" (OCS:errmsg r))
        (OCS:verifyHost e before (list "text" txt "property" (if (equal mt :vlax-true) 'MTextAttributeContent 'TextString)))
      )
    )
  )
)

(defun OCS:writeDim (e data / txt r before)
  (setq txt (OCS:assocd "text" data nil))
  (if (null txt)
    (list "ok" nil "error" "无内容")
    (progn
      (setq before (OCS:assocd "before" data (OCS:hostSnapshot e)))
      (setq r (OCS:writeCall 'vla-put-TextOverride (list e txt)))
      (if (vl-catch-all-error-p r)
        (list "ok" nil "error" (vl-catch-all-error-message r))
        (OCS:verifyHost e before (list "text" txt "property" 'TextOverride))
      )
    )
  )
)

(defun OCS:writeMLeader (e data / txt r before)
  (setq txt (OCS:assocd "text" data nil))
  (if (null txt)
    ;; 块内容：块内文字由块定义转换覆盖，无需改写
    (list "ok" T "skip" T)
    (progn
      (setq before (OCS:assocd "before" data (OCS:hostSnapshot e)))
      (setq r (OCS:writeCall 'vla-put-TextString (list e txt)))
      (if (vl-catch-all-error-p r)
        (list "ok" nil "error" (vl-catch-all-error-message r))
        (OCS:verifyHost e before (list "text" txt))
      )
    )
  )
)

(defun OCS:writeLeader (e data / ann r txt before)
  ;; 关联注释对象单独处理（可能为 TEXT/MTEXT/块）
  (setq ann (OCS:assocd "annotation" data nil))
  (if (null ann)
    (list "ok" T "skip" T)
    (progn
      (setq txt (OCS:assocd "text" data nil))
      (if (null txt)
        (list "ok" T "skip" T)
        (progn
          (setq before (OCS:hostSnapshot ann))
          (setq r (OCS:writeCall 'vla-put-TextString (list ann txt)))
          (if (vl-catch-all-error-p r)
            (list "ok" nil "error" (vl-catch-all-error-message r))
            (OCS:verifyHost ann before (list "text" txt))
          )
        )
      )
    )
  )
)

(defun OCS:writeTolerance (e data / txt r before)
  (setq txt (OCS:assocd "text" data nil))
  (if (null txt)
    (list "ok" T "skip" T)
    (progn
      (setq before (OCS:assocd "before" data (OCS:hostSnapshot e)))
      (setq r (OCS:writeCall 'vla-put-TextString (list e txt)))
      (if (vl-catch-all-error-p r)
        (list "ok" nil "error" (vl-catch-all-error-message r))
        (OCS:verifyHost e before (list "text" txt "property" 'TextString))
      )
    )
  )
)

;; 表格：保留数据语义（方案第 6、8 节）
;; - 临时抑制再生，结束时恢复
;; - 枚举行列与内容项（不假定只有 0 项）
;; - 字段/公式/数据链接不以显示值回写；仅普通文本参与字体指令替换
(defun OCS:writeTable (e data / r restore prev item)
  (setq prev (OCS:assocd "suppressed" data :vlax-false))
  (setq item (list "table" T "obj" e "value" prev))
  (setq *OCS:TempState* (cons item *OCS:TempState*))
  (setq r (OCS:writeCall 'vla-put-RegenerateTableSuppressed (list e :vlax-true)))
  (if (not (vl-catch-all-error-p r))
    (setq r (vl-catch-all-apply 'OCS:tableProcess
      (list e (OCS:assocd "rows" data 0) (OCS:assocd "cols" data 0) data))))
  (setq restore (OCS:writeCall 'vla-put-RegenerateTableSuppressed (list e prev)))
  (cond
    ((vl-catch-all-error-p r) (list "ok" nil "error" (OCS:errorText r)))
    ((or (vl-catch-all-error-p restore)
         (not (equal prev (OCS:requireProp e 'RegenerateTableSuppressed))))
     (list "ok" nil "error" "表格再生状态恢复失败"))
    ((not (equal (OCS:assocd "layout" data nil)
                 (OCS:tableLayout e (OCS:assocd "rows" data 0) (OCS:assocd "cols" data 0)) 1e-9))
     (list "ok" nil "error" "表格行高、列宽或合并关系变化"))
    ((not (equal (OCS:assocd "before" data nil) (OCS:hostSnapshot e) 1e-9))
     (list "ok" nil "error" "表格非字体参数变化"))
    (T r))
)

(defun OCS:tableProcess (e rows cols data / edit r count)
  (setq count 0)
  (foreach edit (OCS:assocd "edits" data nil)
    (OCS:TestFault "table-write")
    (setq r (OCS:tableSetText e (OCS:assocd "row" edit 0) (OCS:assocd "col" edit 0)
      (OCS:assocd "content" edit 0) (OCS:assocd "after" edit "")))
    (if (OCS:errp r) (OCS:fail (OCS:errmsg r)))
    (if (not (equal (OCS:assocd "meta" edit nil)
         (OCS:tableMeta e (OCS:assocd "row" edit 0) (OCS:assocd "col" edit 0) (OCS:assocd "content" edit 0)) 1e-9))
      (OCS:fail "表格单元格非字体格式变化"))
    (setq count (1+ count)))
  (list "ok" T "contents" count)
)

;; tableGetText 返回 (cons :error (list :code .. :msg ..))
(defun OCS:errmsgList (r / lst)
  (setq lst (OCS:errmsg r))
  (if (listp lst) lst (list "msg" lst))
)

(defun OCS:tableGetText (e row col content)
  (OCS:tracedCall 'vla-GetTextString (list e row col content))
)

(defun OCS:tableSetText (e row col content txt / r)
  (setq r (OCS:writeCall 'vla-SetTextString (list e row col content txt)))
  (cond ((vl-catch-all-error-p r) (cons "error" (vl-catch-all-error-message r)))
        ((not (equal txt (OCS:mustCall 'vla-GetTextString (list e row col content))))
         (cons "error" "表格文字读回不一致"))
        (T T))
)

(defun OCS:containsField (s)
  (and (OCS:strContains s "%<") (OCS:strContains s ">%"))
)

(defun OCS:fontTarget ()
  (OCS:getVal *OCS:Plan* "font"
    (list "family" "SimSun" "charSet" 134 "pitchFamily" 22 "appendParams" T))
)

;; 宿主快照（写后校验：非字体字段必须一致）
(defun OCS:hostSnapshot (e / out prop value)
  (setq out nil)
  (foreach prop (list 'Height 'Width 'Rotation 'Layer 'Color 'StyleName 'TagString
                      'InsertionPoint 'TextAlignmentPoint 'Alignment 'AttachmentPoint
                      'Normal 'ObliqueAngle 'ScaleFactor 'TextHeight 'TextWidth 'TextRotation
                      'MTextBoundaryWidth 'LineSpacingFactor 'LineSpacingStyle 'DrawingDirection)
    (if (vlax-property-available-p e prop)
      (progn
        (setq value (OCS:normalValue (OCS:requireProp e prop)))
        (setq out (append out (list (vl-symbol-name prop) value))))))
  out
)

(defun OCS:verifyHost (e before expect / after ok prop data)
  (setq after (OCS:hostSnapshot e) ok (equal before after 1e-9))
  (setq prop (OCS:assocd "property" expect 'TextString))
  (if (not (equal (OCS:assocd "text" expect nil) (OCS:requireProp e prop))) (setq ok nil))
  (if ok (list "ok" T) (list "ok" nil "error" "文字或非字体参数读回不一致"))
)

;;; =====================================================================
;;; 图层临时解锁（方案第 7 节）
;;; 仅临时解锁确有需要的本图图层，完成/异常时恢复；
;;; 关闭、冻结状态保持不动；外参图层保持原状。
;;; =====================================================================

(defun OCS:lockLayersNeeded ( / doc layers target name lay seen)
  (setq doc (OCS:activeDoc) layers (vla-get-Layers doc) seen nil)
  (foreach target (OCS:assocd "targets" *OCS:Plan* nil)
    (setq name (OCS:requireProp (OCS:assocd "obj" target nil) 'Layer))
    (if (OCS:isXrefLayer name) (OCS:fail "拒绝修改外参图层上的宿主"))
    (if (not (member name seen))
      (progn
        (setq seen (cons name seen) lay (OCS:mustCall 'vla-Item (list layers name)))
        (if (OCS:boolProp lay 'Lock)
          (setq *OCS:TempState* (cons (list "layer" name "obj" lay "value" :vlax-true) *OCS:TempState*))))))
  *OCS:TempState*
)

(defun OCS:isXrefLayer (name)
  (OCS:strContains name "|")
)

(defun OCS:unlockTempLayers ( / item obj r)
  (foreach item *OCS:TempState*
    (if (= (car item) "layer")
      (progn
        (setq obj (OCS:assocd "obj" item nil))
        (setq r (OCS:writeCall 'vla-put-Lock (list obj :vlax-false)))
        (if (or (vl-catch-all-error-p r) (OCS:boolProp obj 'Lock))
          (OCS:fail "无法临时解锁目标文字图层")))))
)

(defun OCS:restoreTempLayers ( / item)
  (foreach item *OCS:TempState*
    (if (and (OCS:consp item) (equal (car item) "layer"))
      (OCS:writeCall 'vla-put-Lock (list (OCS:assocd "obj" item nil) :vlax-true))
    )
  )
)

;;; =====================================================================
;;; 报告构造辅助
;;; =====================================================================

(defun OCS:makeReport (status)
  ;; 扁平 plist (K V K V ...)，全项目统一；getVal/assocd/putPair/reportSet 已改为扁平实现
  (list "status" (if status status "进行中")
        "errors" 0
        "errorDetail" nil
        "uncovered" 0
        "uncoveredDetail" nil
        "recoverFailed" 0
        "stylesScanned" 0 "stylesModified" 0 "stylesXref" 0 "stylesShape" 0
        "hostsScanned" 0 "fontRunsChanged" 0 "attribs" 0 "tableContents" 0
        "blocks" 0 "xrefBlocks" 0 "displayBlocks" 0
        "dwg" (getvar "DWGPREFIX")
        "cadver" (getvar "ACADVER")
        "family" "SimSun")
)

(defun OCS:appendError (report where msg / errs detail)
  (OCS:trace "ERROR" (list where msg))
  (setq errs  (1+ (OCS:assocd "errors" report 0))
        detail (append (OCS:assocd "errorDetail" report nil)
                       (list (list where msg))))
  (OCS:reportSet report
    (list (cons "errors" errs) (cons "errorDetail" detail))
  )
)

(defun OCS:appendErrors (report msgs / errs detail m)
  (setq errs (+ (OCS:assocd "errors" report 0) (length msgs))
        detail (OCS:assocd "errorDetail" report nil))
  (foreach m msgs
    (setq detail (append detail (list (list "PREFLIGHT" m))))
  )
  (OCS:reportSet report
    (list (cons "errors" errs) (cons "errorDetail" detail))
  )
)

;; 用新值替换 plist 中已存在的键（不产生重复键）
(defun OCS:reportSet (report pairs / pair)
  (foreach pair pairs
    (setq report (OCS:putPair report (car pair) (cdr pair))))
  report
)

(defun OCS:problemsOf (res / out item)
  (setq out nil)
  (foreach item res
    (if (and (OCS:consp item) (equal (car item) "problem")
             (OCS:consp (cdr item)) (equal (cadr item) "error"))
      (setq out (append out (list (caddr item))))
    )
  )
  ;; 字体解析中的问题
  (foreach item (OCS:getVal res "font" nil)
    (if (and (OCS:consp item) (equal (car item) "problem")
             (OCS:consp (cdr item)) (equal (cadr item) "error"))
      (setq out (append out (list (caddr item))))
    )
  )
  out
)

;;; =====================================================================
;;; 再生与读回 OCS:VerifyDrawing
;;; =====================================================================

(defun OCS:VerifyDrawing ( / doc r)
  (setq doc (OCS:activeDoc))
  (if (not doc)
    (list "ok" nil "error" "无法获取活动文档")
    (progn
      (setq r (vl-catch-all-apply 'vla-Regen (list doc 1))) ; acAllViewports
      (if (vl-catch-all-error-p r)
        (list "ok" nil "error" (strcat "再生失败：" (vl-catch-all-error-message r)))
        (progn
          (setq r (OCS:readbackStyles))
          (if (OCS:assocd "ok" r nil) (OCS:readbackHosts) r))
      )
    )
  )
)

;; 样式读回：字体族为宋体、大字体为空、原参数一致
(defun OCS:readbackStyles ( / ok details st ent e expected)
  (setq ok T details nil)
  (foreach st (OCS:assocd "styles" *OCS:Plan* nil)
    (setq ent (tblobjname "STYLE" (OCS:assocd "name" st "")))
    (if ent
      (progn
        (setq e (entget ent))
        (if (not (OCS:styleIsTarget ent))
          (progn (setq ok nil)
                 (setq details (append details (list (list "FONT_NOT_SIMSUN" (OCS:assocd 2 e "")))))))
        (setq expected (OCS:assocd "fontExpected" st nil))
        (if (and expected (not (OCS:fontStateStable expected
                               (OCS:fontState (vlax-ename->vla-object ent) "style-after-regen"))))
          (progn (setq ok nil)
                 (setq details (append details (list (list "FONT_BINDING_CHANGED" (OCS:assocd 2 e "")))))))
        (if (/= "" (OCS:assocd 4 e ""))
          (progn (setq ok nil)
                 (setq details (append details
                   (list (list "BIGFONT_NOT_EMPTY" (OCS:assocd 2 e "")))))))
        (if (OCS:assocd "before" st nil)
          (if (not (OCS:styleReadbackOk (OCS:assocd "before" st nil)
                                         (OCS:styleSnapshot ent)))
            (progn (setq ok nil)
                   (setq details (append details
                     (list (list "PARAM_CHANGED" (OCS:assocd 2 e "")))))))
        )
      )
      (progn (setq ok nil)
             (setq details (append details
               (list (list "STYLE_MISSING" (OCS:assocd "name" st ""))))))
    )
  )
  (list "ok" ok "details" details "error" (if ok nil (OCS:fmt details)))
)

;;; =====================================================================
;;; 回滚 OCS:Rollback（仅回滚本次操作）
;;; 回滚只作用于本次命令建立的 Undo 分组：结束分组后执行一次撤销，
;;; 绝不无条件 UNDO Back 撤销用户上一条命令。
;;; =====================================================================

(defun OCS:Rollback ( / r ok changed)
  (OCS:trace "ROLLBACK_BEGIN" (list "undoMark" *OCS:UndoMark* "wrote" *OCS:Wrote*))
  (setq changed (and *OCS:UndoMark* *OCS:Wrote*))
  (setq ok (OCS:restoreTempState))
  (if (not (OCS:endUndoGroup))
    nil ; 未能关闭本次分组时，绝不向用户历史发出 U。
    (progn
      (if changed
        (if *OCS:UndoAttempted* (setq ok nil)
          (progn
            (setq *OCS:UndoAttempted* T)
            (setq r (vl-catch-all-apply 'command-s (list "_.U")))
            (if (vl-catch-all-error-p r) (setq ok nil)))))
      (if (not (OCS:restoreTempState)) (setq ok nil))
      (if (not (OCS:rollbackReadbackOk)) (setq ok nil))
      (OCS:trace "ROLLBACK_END" (list "ok" ok "undoAttempted" *OCS:UndoAttempted*))
      (setq *OCS:Wrote* nil)
      ok))
)

;; 回滚后读回：本次计划中的样式不得残留空大字体之外的转换痕迹
(defun OCS:rollbackReadbackOk ( / ok st ent e target host data edit)
  (setq ok T)
  (foreach st (OCS:assocd "styles" *OCS:Plan* nil)
    (setq ent (tblobjname "STYLE" (OCS:assocd "name" st "")))
    (if (not ent) (setq ok nil)
      (progn
        (setq e (entget ent))
        (if (or (not (equal (OCS:assocd 3 e "") (OCS:assocd "fontFileBefore" st "")))
                (not (equal (OCS:assocd 4 e "") (OCS:assocd "bigFontBefore" st "")))
                (not (equal (OCS:assocd "fontBefore" st nil) (OCS:getStyleFont (vlax-ename->vla-object ent))))
                (not (OCS:styleReadbackOk (OCS:assocd "before" st nil) (OCS:styleSnapshot ent))))
          (setq ok nil)))))
  (foreach target (OCS:assocd "targets" *OCS:Plan* nil)
    (setq e (OCS:assocd "obj" target nil))
    (if (not (equal (OCS:assocd "before" target nil) (OCS:hostSnapshot e) 1e-9)) (setq ok nil))
    (if (= (OCS:assocd "kind" target "") "table")
      (progn
        (foreach edit (OCS:assocd "edits" target nil)
          (if (not (equal (OCS:assocd "before" edit "")
                (OCS:mustCall 'vla-GetTextString (list e (OCS:assocd "row" edit 0)
                  (OCS:assocd "col" edit 0) (OCS:assocd "content" edit 0))))) (setq ok nil)))
        (if (not (equal (OCS:assocd "layout" target nil)
              (OCS:tableLayout e (OCS:assocd "rows" target 0) (OCS:assocd "cols" target 0)) 1e-9)) (setq ok nil)))
      (if (not (equal (OCS:assocd "text" target "")
            (OCS:assocd "text" (OCS:ReadHost (OCS:assocd "host" target nil)) ""))) (setq ok nil))))
  ok
)

(defun OCS:endUndoGroup ( / r)
  (if (not *OCS:UndoMark*) T
    (progn
      (setq r (vl-catch-all-apply 'vla-EndUndoMark (list (OCS:activeDoc))))
      (if (vl-catch-all-error-p r) nil
        (progn (setq *OCS:UndoMark* nil) T))))
)

(defun OCS:restoreTempState ( / ok item obj r pending prop value)
  (setq ok T pending nil)
  (foreach item *OCS:TempState*
    (setq obj (OCS:assocd "obj" item nil))
    (setq prop (if (= (car item) "table") 'RegenerateTableSuppressed 'Lock))
    (setq value (OCS:assocd "value" item :vlax-true))
    (setq r (OCS:writeCall (read (strcat "vla-put-" (vl-symbol-name prop))) (list obj value)))
    (if (or (vl-catch-all-error-p r) (not (equal (OCS:safeProp obj prop) value)))
      (setq ok nil pending (cons item pending))))
  (setq *OCS:TempState* (reverse pending))
  (if *OCS:ProbeStyle*
    (progn
      (setq r (vl-catch-all-apply 'OCS:deleteStyleIfExists (list *OCS:ProbeStyle*)))
      (if (or (vl-catch-all-error-p r) (tblobjname "STYLE" *OCS:ProbeStyle*))
        (setq ok nil) (setq *OCS:ProbeStyle* nil))))
  ok
)

;;; =====================================================================
;;; 报告 OCS:Report
;;; =====================================================================

(defun OCS:Report (report / f d)
  (setq *OCS:LastReport* report)
  (setq *OCS:Report* report)
  ;; 中文命令行摘要
  (princ "\n")
  (princ (strcat "\n==== 一键统一宋体（YJST）===="))
  (princ (strcat "\n状态：" (OCS:assocd "status" report "?")))
  (princ (strcat "\n图纸：" (OCS:assocd "dwg" report "?")))
  (princ (strcat "\nCAD 版本：" (OCS:assocd "cadver" report "?")))
  (princ (strcat "\n目标字体族：" (OCS:assocd "family" report "SimSun")))
  (princ (strcat "\n扫描文字样式：" (itoa (OCS:assocd "stylesScanned" report 0))
                 "　修改：" (itoa (OCS:assocd "stylesModified" report 0))
                 "　外参依赖跳过：" (itoa (OCS:assocd "stylesXref" report 0))
                 "　形文件跳过：" (itoa (OCS:assocd "stylesShape" report 0))))
  (princ (strcat "\n扫描文字宿主：" (itoa (OCS:assocd "hostsScanned" report 0))
                 "　修改字体段：" (itoa (OCS:assocd "fontRunsChanged" report 0))
                 "　属性实例：" (itoa (OCS:assocd "attribs" report 0))
                 "　表格内容项：" (itoa (OCS:assocd "tableContents" report 0))))
  (princ (strcat "\n扫描块定义：" (itoa (OCS:assocd "blocks" report 0))
                 "　外参块跳过：" (itoa (OCS:assocd "xrefBlocks" report 0))
                 "　匿名显示块：" (itoa (OCS:assocd "displayBlocks" report 0))))
  (princ (strcat "\n专业对象未覆盖：" (itoa (OCS:assocd "uncovered" report 0))
                 "　错误：" (itoa (OCS:assocd "errors" report 0))
                 "　恢复失败：" (itoa (OCS:assocd "recoverFailed" report 0))))
  (if (OCS:assocd "tchChecked" report nil)
    (princ (strcat "\n天正公开字体核验：通过 " (itoa (OCS:assocd "tchPassed" report 0))
      "　不一致 " (itoa (OCS:assocd "tchMismatch" report 0))
      "　无法核验 " (itoa (OCS:assocd "tchUnknown" report 0))
      "（仅公开样式与可读内容）")))
  (if (OCS:assocd "errorDetail" report nil)
    (progn
      (princ "\n错误明细：")
      (foreach d (OCS:assocd "errorDetail" report nil)
        (princ (strcat "\n  " (OCS:fmt d))))
    )
  )
  (princ "\n天正字体核查未执行；需要时输入 YJSTCHECK。未覆盖明细仅保留在日志中。")
  (princ (strcat "\n详细记录：*OCS:LastReport*"))
  (princ)
  report
)

(defun OCS:fmt (x / out i)
  (cond
    ((OCS:stringp x) x)
    ((numberp x) (rtos x 2 6))
    ((null x) "nil")
    ((listp x)
     (setq out "")
     (foreach i x
       (if (= out "") (setq out (OCS:fmt i))
         (setq out (strcat out " | " (OCS:fmt i)))))
     (strcat "(" out ")"))
    (T (vl-symbol-name x))
  )
)

;;; =====================================================================
;;; 用户命令 c:YJST：方案第 8 节流程
;;; =====================================================================

;;; 诊断命令 c:OCS_TEST：逐项跑预检步骤，精确定位哪一步挂了
(defun c:OCS_TEST ( / res acadObj undoctl doc ro font probs okv)
  (princ "\n==== OCS 预检分步诊断 ====")
  ;; 复刻 OCS:Preflight 每一步，逐步打印
  (setq res (list "ok" nil))
  (princ (strcat "\n[1] ACADVER = " (getvar "ACADVER")))
  (princ (strcat "\n[2] PRODUCT  = " (getvar "PRODUCT")))
  (princ (strcat "\n[3] LISPSYS  = " (vl-prin1-to-string (getvar "LISPSYS"))))
  (princ (strcat "\n[4] PLATFORM = " (getvar "PLATFORM")))
  (setq acadObj (vl-catch-all-apply 'vlax-get-acad-object nil))
  (if (vl-catch-all-error-p acadObj)
    (princ "\n[5] vlax-get-acad-object = ERROR: Visual LISP/ActiveX 不可用")
    (princ "\n[5] vlax-get-acad-object = OK")
  )
  (setq undoctl (getvar "UNDOCTL"))
  (princ (strcat "\n[6] UNDOCTL = " (itoa undoctl)))
  (if (= 0 (logand undoctl 1))
    (princ "\n[7] UNDO 检查 = 失败（撤销不可用）")
    (princ "\n[7] UNDO 检查 = OK")
  )
  (setq doc (vl-catch-all-apply 'vla-get-ActiveDocument (list acadObj)))
  (if (vl-catch-all-error-p doc)
    (princ "\n[8] ActiveDocument = ERROR")
    (progn
      (princ "\n[8] ActiveDocument = OK")
      (setq ro (vl-catch-all-apply 'vla-get-ReadOnly (list doc)))
      (if (vl-catch-all-error-p ro)
        (princ "\n[9] ReadOnly = ERROR（接口可能不存在）")
        (princ (strcat "\n[9] ReadOnly = " (if ro "TRUE(只读)" "FALSE(可写)")))
      )
    )
  )
  ;; 字体解析
  (setq font (vl-catch-all-apply 'OCS:ResolveSongFont nil))
  (if (vl-catch-all-error-p font)
    (princ (strcat "\n[10] ResolveSongFont = ERROR: " (vl-catch-all-error-message font)))
    (princ (strcat "\n[10] ResolveSongFont = " (vl-prin1-to-string font)))
  )
  ;; Blocks 接口
  (if (vl-catch-all-error-p doc)
    (princ "\n[11] GetBlocks = 跳过（无文档）")
    (progn
      (setq okv (vl-catch-all-apply 'vlax-method-applicable-p (list doc "GetBlocks")))
      (if (vl-catch-all-error-p okv)
        (princ "\n[11a] vlax-method-applicable-p(字符串) = ERROR")
        (princ (strcat "\n[11a] applicable-p \"GetBlocks\" = " (if okv "T" "NIL")))
      )
      (setq okv (vl-catch-all-apply 'vlax-method-applicable-p (list doc 'GetBlocks)))
      (if (vl-catch-all-error-p okv)
        (princ "\n[11b] vlax-method-applicable-p(符号) = ERROR")
        (princ (strcat "\n[11b] applicable-p 'GetBlocks = " (if okv "T" "NIL")))
      )
      (setq okv (vl-catch-all-apply 'vla-get-Blocks (list doc)))
      (if (vl-catch-all-error-p okv)
        (princ (strcat "\n[11c] vla-get-Blocks = ERROR: " (vl-catch-all-error-message okv)))
        (progn
          (princ "\n[11c] vla-get-Blocks = OK")
          (setq okv (vl-catch-all-apply 'vla-get-Count (list okv)))
          (if (vl-catch-all-error-p okv)
            (princ "\n[11d] vla-get-Count = ERROR")
            (princ (strcat "\n[11d] Blocks Count = " (itoa okv)))
          )
        )
      )
    )
  )
  (princ "\n==== 诊断结束；把以上输出发给开发 ====")
  (princ)
)

;; 日期：2026-10-13。最后一行显示执行结果，保留部分完成与回滚的真实状态。
(defun OCS:elapsedSeconds (start finish / delta)
  (if (and (numberp start) (numberp finish))
    (progn
      ;; 使用实数减法避免 32 位整数溢出，支持 MILLISECS 一次回绕。
      (setq delta (- (+ 0.0 finish) start))
      (if (< delta 0.0) (setq delta (+ delta 4294967296.0)))
      (/ delta 1000.0))
    nil)
)

(defun OCS:timerStart ()
  (setq *OCS:ClockStart* (OCS:logVar "MILLISECS")
        *OCS:PhaseStart* *OCS:ClockStart* *OCS:PhaseName* "初始化"
        *OCS:PhaseTimes* nil)
)

(defun OCS:timerPhase (name / now seconds)
  (setq now (OCS:logVar "MILLISECS")
        seconds (OCS:elapsedSeconds *OCS:PhaseStart* now))
  (if *OCS:PhaseName*
    (progn
      (setq *OCS:PhaseTimes* (cons (list *OCS:PhaseName* seconds) *OCS:PhaseTimes*))
      (OCS:trace "PHASE_TIME" (list "phase" *OCS:PhaseName* "seconds" seconds))))
  (setq *OCS:PhaseStart* now *OCS:PhaseName* name)
)

(defun OCS:timerFinish (report / seconds)
  (OCS:timerPhase nil)
  (setq seconds (OCS:elapsedSeconds *OCS:ClockStart* (OCS:logVar "MILLISECS")))
  (setq report (OCS:putPair report "elapsedSeconds" seconds))
  (setq report (OCS:putPair report "phaseTimes" (reverse *OCS:PhaseTimes*)))
  (OCS:trace "RUN_TIMING" (list "elapsedSeconds" seconds "phaseTimes" (reverse *OCS:PhaseTimes*)))
  (princ (if (numberp seconds)
    (strcat "\n总耗时：" (rtos seconds 2 2) " 秒。")
    "\n总耗时：当前 CAD 未提供可用计时值。"))
  (princ "\nby张裕锋-20261013")
  report
)

(defun OCS:finishMessage (report / status uncovered)
  (setq status (OCS:assocd "status" report "结果未知")
        uncovered (OCS:assocd "uncovered" report 0))
  (cond
    ((or (> (OCS:assocd "errors" report 0) 0)
         (> (OCS:assocd "recoverFailed" report 0) 0)
         (not (member status (list "已完成" "无需修改" "部分完成"))))
     (strcat "\n==== YJST 执行失败：" status "，请查看上方错误明细和日志。 ===="))
    ((or (= status "部分完成") (> uncovered 0))
     (strcat "\n==== YJST 执行成功（部分完成）：仍有 " (itoa uncovered)
             " 个专业对象未覆盖，详情见日志；可输入 YJSTCHECK 核查。 ===="))
    ((= status "无需修改") "\n==== YJST 执行成功：无需修改。 ====")
    (T "\n==== YJST 执行成功。 ====")))

(defun c:YJST ( / r report)
  (cond
    (*OCS:Running* (princ "\nYJST 执行失败：上一次运行尚未结束，本次未启动。"))
    (*OCS:UndoMark* (princ "\nYJST 执行失败：上次撤销分组未能关闭，本次未启动，请先检查恢复失败明细。"))
    (T
      (OCS:timerStart)
      (setq *OCS:Running* T *OCS:Plan* nil *OCS:TempState* nil *OCS:Wrote* nil
            *OCS:UndoAttempted* nil *OCS:FailureMessage* nil *OCS:ProbeStyle* nil)
      (princ (strcat "\nYJST v" *OCS:Version* " 开始执行。"))
      (OCS:logStart)
      (setq r (vl-catch-all-apply 'OCS:mainFlow nil))
      (if (vl-catch-all-error-p r)
        (progn
          (setq report (OCS:appendError (OCS:runStats (OCS:makeReport "预检失败") nil nil)
                                       *OCS:Stage* (OCS:errorText r)))
          (if *OCS:UndoMark* (setq report (OCS:recoverReport report))))
        (setq report r))
      (OCS:timerPhase "结果输出")
      (setq report (OCS:putPair report "logPath" *OCS:LogPath*))
      (setq *OCS:LastReport* report)
      (OCS:trace "RUN_RESULT" report)
      (setq r (vl-catch-all-apply 'OCS:Report (list report)))
      (if (vl-catch-all-error-p r)
        (OCS:trace "REPORT_ERROR" (vl-catch-all-error-message r)))
      (c:YJSTLOG)
      (princ (OCS:finishMessage report))
      (setq report (OCS:timerFinish report) *OCS:LastReport* report *OCS:Report* report)
      (OCS:trace "RUN_END" (OCS:assocd "status" report "?"))
      (setq *OCS:TraceActive* nil *OCS:Running* nil)))
  (princ)
)

(defun OCS:mainFlow ( / pre plan)
  (OCS:timerPhase "环境与字体预检")
  (OCS:setStage "环境与字体预检")
  (princ "\n[1/3] 检查环境与宋体字体...")
  (setq pre (OCS:Preflight))
  (if (not (OCS:assocd "ok" pre nil))
    (OCS:appendErrors (OCS:makeReport "预检失败") (OCS:problemsOf pre))
    (progn
      (OCS:timerPhase "扫描与生成计划")
      (OCS:setStage "扫描与生成计划")
      (princ "\n[2/3] 读取原始内容并生成修改计划...")
      (setq plan (OCS:BuildPlan))
      (setq *OCS:Plan* (OCS:putPair plan "font" (OCS:assocd "font" pre nil)))
      (OCS:trace "PLAN_READY" (list "styles" (length (OCS:assocd "styles" plan nil))
        "hosts" (length (OCS:assocd "hosts" plan nil)) "targets" (length (OCS:assocd "targets" plan nil))
        "uncovered" (OCS:assocd "unknown" (OCS:assocd "stats" plan nil) 0)))
      (if (and (OCS:hasPlannedWrites) (not (OCS:beginUndoGroup)))
        (OCS:appendError (OCS:makeReport "预检失败") "UNDO" "无法建立撤销分组，未写入业务数据")
        (progn
          (OCS:timerPhase "更新字体与校验")
          (OCS:setStage "写入与校验")
          (princ "\n[3/3] 更新字体并读回校验...")
          (OCS:executeWrites)))))
)

(defun OCS:beginUndoGroup ( / doc r)
  (setq doc (OCS:activeDoc))
  (if (not doc) nil
    (progn
      (setq r (vl-catch-all-apply 'vla-StartUndoMark (list doc)))
      (if (vl-catch-all-error-p r) nil
        (progn (setq *OCS:UndoMark* T *OCS:Wrote* nil) T)
      )
    )
  )
)

;; 执行写入与检查（含回滚路径）
(defun OCS:executeWrites ( / report stylesRes hostsRes verifyRes probe)
  (setq report (OCS:makeReport "进行中"))
  (if (OCS:hasPlannedWrites)
    (progn
      (OCS:setStage "分组内字体试写")
      (setq probe (OCS:verifyFontWrite (OCS:assocd "font" *OCS:Plan* nil)))
      (if (OCS:hasError probe) (OCS:fail (OCS:fmt (OCS:problemsOf probe))))
      (setq *OCS:Plan* (OCS:putPair *OCS:Plan* "font" probe))))
  (OCS:lockLayersNeeded)
  (OCS:unlockTempLayers)
  (OCS:setStage "写入样式")
  (setq stylesRes (OCS:applyAllStyles))
  (if (OCS:assocd "error" stylesRes nil)
    (setq report (OCS:appendError report "STYLE" (OCS:assocd "error" stylesRes "")))
    (setq hostsRes (OCS:applyAllHosts)))
  (if (OCS:assocd "error" hostsRes nil)
    (setq report (OCS:appendError report "HOST" (OCS:assocd "error" hostsRes ""))))
  (setq report (OCS:runStats report stylesRes hostsRes))
  (OCS:setStage "恢复临时状态")
  (if (not (OCS:restoreTempState))
    (setq report (OCS:appendError report "RESTORE" "临时状态恢复失败")))
  (if (= (OCS:assocd "errors" report 0) 0)
    (progn
      (OCS:timerPhase "再生与读回校验")
      (OCS:setStage "再生与校验")
      (OCS:TestFault "regen-check")
      (setq verifyRes (OCS:VerifyDrawing))
      (if (not (OCS:assocd "ok" verifyRes nil))
        (setq report (OCS:appendError report "VERIFY" (OCS:assocd "error" verifyRes "读回失败"))))))
  (if (> (OCS:assocd "errors" report 0) 0)
    (OCS:recoverReport report)
    (if (not (OCS:endUndoGroup))
      (OCS:recoverReport (OCS:appendError report "UNDO" "关闭撤销分组失败"))
      (progn
        ;; 日期：2026-10-13。额外天正核查由 YJSTCHECK 按需执行，转换读回与回滚校验仍保留。
        (OCS:putPair report "status"
          (cond ((> (OCS:assocd "uncovered" report 0) 0) "部分完成")
                ((and (= (OCS:assocd "stylesModified" report 0) 0)
                      (= (OCS:assocd "fontRunsChanged" report 0) 0)) "无需修改")
                (T "已完成"))))))
)

;;; 日期：2026-10-13。天正公开字体只读核验；未知结构不推断通过。
(defun OCS:checkFlow ( / stats report)
  ;; 重新枚举当前文档，不能复用上次 YJST 的对象引用或转换前状态。
  (setq stats (OCS:CollectHosts))
  (if (OCS:hasError stats) (OCS:fail (OCS:fmt (OCS:problemsOf stats))))
  (setq *OCS:Plan* (list "stats" stats))
  (setq report (OCS:verifyTchReport (OCS:runStats (OCS:makeReport "核查完成") nil nil)))
  (if (or (> (OCS:assocd "tchMismatch" report 0) 0)
          (> (OCS:assocd "tchUnknown" report 0) 0))
    (OCS:putPair report "status" "核查完成，存在不一致或无法核验项")
    report)
)

(defun c:YJSTCHECK ( / r report *OCS:CheckOnly* *OCS:Plan* *OCS:FailureMessage*)
  (cond
    (*OCS:Running* (princ "\nYJSTCHECK 未启动：上一次运行尚未结束。"))
    (*OCS:UndoMark* (princ "\nYJSTCHECK 未启动：请先处理上次恢复失败。"))
    (T
      (OCS:timerStart)
      (setq *OCS:Running* T *OCS:CheckOnly* T)
      (princ (strcat "\nYJSTCHECK v" *OCS:Version* " 开始只读核查当前图纸的天正公开字体..."))
      (OCS:logStart)
      (OCS:trace "COMMAND" "YJSTCHECK")
      (OCS:timerPhase "天正公开字体核查")
      (setq r (vl-catch-all-apply 'OCS:checkFlow nil))
      (setq report (if (vl-catch-all-error-p r)
        (OCS:appendError (OCS:makeReport "核查失败") *OCS:Stage* (OCS:errorText r)) r))
      (OCS:timerPhase "结果输出")
      (setq report (OCS:putPair report "logPath" *OCS:LogPath*)
            *OCS:LastCheckReport* report)
      (OCS:trace "RUN_RESULT" report)
      (princ (strcat "\n天正公开字体核查：通过 " (itoa (OCS:assocd "tchPassed" report 0))
        "　不一致 " (itoa (OCS:assocd "tchMismatch" report 0))
        "　无法核验 " (itoa (OCS:assocd "tchUnknown" report 0))
        "　错误 " (itoa (OCS:assocd "errors" report 0))))
      (princ "\n仅核查公开样式与可读内容；未覆盖及核查明细见日志或 *OCS:LastCheckReport*。")
      (c:YJSTLOG)
      (princ (strcat "\n==== YJSTCHECK " (OCS:assocd "status" report "核查失败") " ==== "))
      (setq report (OCS:timerFinish report) *OCS:LastCheckReport* report)
      (OCS:trace "RUN_END" (OCS:assocd "status" report "核查失败"))
      (setq *OCS:TraceActive* nil *OCS:Running* nil)))
  (princ)
)

(defun OCS:tchKind (typ)
  (cond ((= (strcase typ) "TDBTEXT") "TCH_TEXT")
        ((= (strcase typ) "TDBMTEXT") "TCH_MTEXT")
        ((= (strcase typ) "TDBDRAWINGNAME") "TCH_DRAWINGNAME")
        ((= (strcase typ) "TDBSYMBMULTILEADER") "TCH_MULTILEADER")
        ((= (strcase typ) "TDBDIMENSION2") "TCH_DIMENSION2")
        (T nil))
)

;; 只取指定子类内的字段，不把其他子类和 XData 混入内容或样式。
(defun OCS:tchSection (data section / active out p)
  (setq active nil out nil)
  (foreach p data
    (cond ((= (car p) 100) (setq active (= (cdr p) section)))
          ((>= (car p) 1000) (setq active nil))
          (active (setq out (cons p out)))))
  (reverse out)
)

(defun OCS:tchOne (data code / values p)
  (setq values nil)
  (foreach p data (if (= (car p) code) (setq values (cons (cdr p) values))))
  (if (= (length values) 1) (car values) nil)
)

(defun OCS:checkTchObject (item / data kind section refs texts codes code val ent st scan reason status names)
  (setq data (entget (vlax-vla-object->ename (OCS:assocd "obj" item nil)))
        kind (OCS:tchKind (OCS:assocd "type" item ""))
        refs nil texts nil reason nil status "pass" names nil)
  (if (= kind "TCH_DIMENSION2")
    (list "status" "unknown" "reason" "天正标注未适配可完整核验的公开字体结构，未调用 TextOverride")
    (if (or (not data) (not (equal (OCS:assocd 0 data "") kind)))
    (list "status" "unknown" "reason" "entget 未返回匹配的天正公开记录")
    (progn
      (cond
        ((= kind "TCH_DRAWINGNAME")
         (setq section (OCS:tchSection data "TDbDrawingName") codes (list 1 2))
         (foreach code (list 340 341)
           (setq val (OCS:tchOne section code))
           (setq ent (if (OCS:stringp val) (handent val) val))
           (setq refs (cons ent refs))))
        ((= kind "TCH_MULTILEADER")
         (setq val (OCS:tchOne (OCS:tchSection data "TDbSymbWithText") 7))
         (setq refs (list (if (and (OCS:stringp val) (/= val "")) (tblobjname "STYLE" val) nil)))
         (setq section (OCS:tchSection data "TDbSymbMultiLeader") codes (list 1 2)))
        (T
         (setq section (OCS:tchSection data "TDbText") codes (list 1))
         (setq val (OCS:tchOne section 7))
         (setq refs (list (if (and (OCS:stringp val) (/= val "")) (tblobjname "STYLE" val) nil)))
         (if (and (= kind "TCH_MTEXT") (not (OCS:tchSection data "TDbMText")))
           (setq reason "缺少 TDbMText 子类数据" status "unknown"))))
      (foreach code codes
        (setq val (OCS:tchOne section code))
        (if (not (OCS:stringp val))
          (setq reason "文字字段缺失或重复" status "unknown")
          (setq texts (cons val texts))))
      ;; 未知分段内容不只检查第一段；字段表达式也不猜测显示字体。
      (if (assoc 3 section) (setq reason "存在尚未适配的分段文字" status "unknown"))
      (foreach val texts
        (if (OCS:containsField val)
          (setq reason "含字段表达式，无法完整核验" status "unknown")
          (progn
            (setq scan (OCS:NormalizeFontRuns val (OCS:fontTarget)))
            (cond ((OCS:assocd "issues" scan nil)
                   (setq reason "文字格式无法完整解析" status "unknown"))
                  ((and (> (OCS:assocd "changes" scan 0) 0) (/= status "unknown"))
                   (setq reason "可读文字含非宋体局部字体覆盖" status "mismatch"))))))
      (foreach ent refs
        (setq st (if ent (entget ent) nil))
        (if (not (equal (OCS:assocd 0 st "") "STYLE"))
          (setq reason "样式引用缺失或未指向 STYLE" status "unknown")
          (progn
            (setq names (cons (OCS:assocd 2 st "?") names))
            (if (and (not (OCS:styleIsTarget ent)) (/= status "unknown"))
              (setq reason "引用样式不是目标宋体或大字体非空" status "mismatch")))))
      (list "status" status "reason" (if reason reason "公开样式引用与可读内容符合宋体要求")
            "styles" (reverse names)))))
)

(defun OCS:verifyTchReport (report / candidates item r saved passed mismatch unknown details issues handles entry kept count)
  (setq candidates (OCS:assocd "tchCandidates" (OCS:assocd "stats" *OCS:Plan* nil) nil)
        passed 0 mismatch 0 unknown 0 details nil issues nil handles nil)
  (foreach item candidates
    (OCS:setStage (strcat "天正公开字体核验 [" (OCS:assocd "handle" item "?") "]"))
    (setq saved *OCS:FailureMessage*)
    (setq r (vl-catch-all-apply 'OCS:checkTchObject (list item)))
    (setq *OCS:FailureMessage* saved)
    (if (vl-catch-all-error-p r)
      (setq r (list "status" "unknown" "reason" (vl-catch-all-error-message r))))
    (setq r (OCS:putPair r "handle" (OCS:assocd "handle" item "?")))
    (setq r (OCS:putPair r "type" (OCS:assocd "type" item "?")))
    (setq r (OCS:putPair r "location" (OCS:ctxStr (OCS:assocd "ctx" item nil))))
    (OCS:trace "TCH_VERIFY" r)
    (setq details (cons r details))
    (cond ((= (OCS:assocd "status" r "") "pass")
           (setq passed (1+ passed) handles (cons (OCS:assocd "handle" item "?") handles)))
          ((= (OCS:assocd "status" r "") "mismatch") (setq mismatch (1+ mismatch)))
          (T (setq unknown (1+ unknown))))
    (if (/= (OCS:assocd "status" r "") "pass") (setq issues (cons r issues))))
  (setq kept nil count 0)
  (foreach entry (OCS:assocd "uncoveredDetail" report nil)
    (if (and (= (car entry) "PROXY_OR_PRO") (member (cadr entry) handles))
      (setq count (1+ count)) (setq kept (cons entry kept))))
  (setq report (OCS:putPair report "uncovered" (- (OCS:assocd "uncovered" report 0) count)))
  (setq report (OCS:putPair report "uncoveredDetail" (reverse kept)))
  (setq report (OCS:putPair report "tchChecked" T))
  (setq report (OCS:putPair report "tchPassed" passed))
  (setq report (OCS:putPair report "tchMismatch" mismatch))
  (setq report (OCS:putPair report "tchUnknown" unknown))
  (setq report (OCS:putPair report "tchDetails" (reverse details)))
  (OCS:putPair report "tchIssues" (reverse issues))
)

(defun OCS:applyAllStyles ( / modified err r st ent updated)
  (setq modified 0 err nil updated nil)
  (foreach st (OCS:assocd "styles" *OCS:Plan* nil)
    (OCS:setStage (strcat "写入样式 " (OCS:assocd "name" st "?")))
    (setq ent (tblobjname "STYLE" (OCS:assocd "name" st "")))
    (if (and (not err) (not (and ent (OCS:styleIsTarget ent))))
      (progn
        (OCS:TestFault "style-write")
        (setq r (OCS:ApplyStyle (OCS:activeDoc) st))
        (if (OCS:assocd "ok" r nil)
          (progn
            (setq modified (1+ modified))
            (setq st (OCS:putPair st "fontExpected" (OCS:assocd "fontExpected" r nil))))
          (setq err (OCS:assocd "error" r "未知错误"))
        )
      )
    )
    ;; 未修改的目标样式也记录本轮基线，防止宿主写入/再生改变字体表示或粗斜体。
    (if (and (not err) ent (not (OCS:assocd "fontExpected" st nil)))
      (setq st (OCS:putPair st "fontExpected" (OCS:fontState (vlax-ename->vla-object ent) "style-unchanged"))))
    (setq updated (cons st updated))
  )
  (setq *OCS:Plan* (OCS:putPair *OCS:Plan* "styles" (reverse updated)))
  (list "modified" modified "error" err)
)

(defun OCS:applyAllHosts ( / changes tableContents target host data r err)
  (setq changes 0 tableContents 0 err nil)
  (foreach target (OCS:assocd "targets" *OCS:Plan* nil)
    (if (not err)
      (progn
        (setq host (OCS:assocd "host" target nil))
        (OCS:setStage (strcat "写入宿主 " (OCS:assocd "handle" host "?")))
        (OCS:TestFault "content-write")
        (setq data target)
        (if (/= (OCS:assocd "kind" data "") "table")
          (setq data (OCS:putPair data "text" (OCS:assocd "newText" data ""))))
        (setq r (OCS:WriteHost host data))
        (if (OCS:assocd "ok" r nil)
          (progn
            (setq changes (+ changes (OCS:assocd "changes" target 0)))
            (setq tableContents (+ tableContents (OCS:assocd "contents" r 0))))
          (setq err (strcat (OCS:assocd "handle" host "?") ": " (OCS:assocd "error" r "写入失败")))))))
  (list "changes" changes "tableContents" tableContents "error" err)
)

;;; ----------------------------------------------------------------------
;;; 故障注入（仅测试入口，正常运行不受影响）
;;; ----------------------------------------------------------------------
(defun OCS:TestFault (point)
  (if (and *OCS:FaultPoint* (= *OCS:FaultPoint* point))
    (progn
      (setq *OCS:FaultPoint* nil)
      (OCS:fail (strcat "OCS 故障注入：" point))
    )
  )
)

;;; ----------------------------------------------------------------------
;;; 自检入口（纯函数部分，不依赖 CAD 环境）：OCS:SelfTest
;;; ----------------------------------------------------------------------
(defun OCS:SelfTest ( / cases pass fail c in n out r want wantN)
  (setq cases (OCS:selfTestCases) pass 0 fail 0)
  (foreach c cases
    (progn
      (setq in  (car c) want (cadr c) wantN (caddr c))
      (setq r (OCS:NormalizeFontRuns in (list "family" "SimSun" "charSet" 134 "pitchFamily" 22 "appendParams" T)))
      (setq out (OCS:assocd "text" r ""))
      (setq n  (OCS:assocd "changes" r 0))
      (if (and (= out want) (= n wantN))
        (setq pass (1+ pass))
        (progn
          (setq fail (1+ fail))
          (princ (strcat "\nFAIL in=[" in "] got=[" out "] want=[" want "]"))
        )
      )
    )
  )
  (princ (strcat "\nOCS:SelfTest 通过 " (itoa pass) " / 失败 " (itoa fail)))
  ;; 注意：结尾不能写 (setq fail)：目标引擎读入器不接受单参数 setq（实测语法错误），
  ;; 裸符号作为最后表达式返回值，语义相同。
  fail
)

(defun OCS:selfTestCases ( / long1 acc n)
  ;; 与 tests/font-format-cases.json 一一对应：
  ;; C01-plain-inherit, C02-font-arial-bold-italic, C03-height-nested-fonts,
  ;; C04-paragraph-codes, C05-stack-diameter-tolerance, C06-field-code-protected,
  ;; C07-escaped-backslash-brace, C08-long-mixed-text, C09-already-simsun,
  ;; C10-incomplete-code-error, C11-nested-two-fonts, C12-underline-color-preserved,
  ;; C13-second-run-zero, C14-chinese-font-name-in-body, C15-nested-field-inside-format
  (setq long1 "")
  (setq n 0)
  (while (< n 60)
    (setq long1 (strcat long1 "英文 ABC 与中文 宋体测试"))
    (setq n (1+ n))
  )
  (list
    ;; C01
    (list "本页统一使用黑体，字高 3.5。" "本页统一使用黑体，字高 3.5。" 0)
    ;; C02
    (list "{\\fArial|b1|i0;标题正文}" "{\\fSimSun|b1|i0|c134|pf22;标题正文}" 1)
    ;; C03
    (list "{\\H0.7x;\\fSimHei|b0|i1;说明段落}" "{\\H0.7x;\\fSimSun|b0|i1|c134|pf22;说明段落}" 1)
    ;; C04
    (list "\\pl1;第一段\\P第二段\\fTimes New Roman;第三段"
          "\\pl1;第一段\\P第二段\\fSimSun|c134|pf22;第三段" 1)
    ;; C05
    (list "%%c12 \\fISOCPEUR;\\S1/2; 完"
          "%%c12 \\fSimSun|c134|pf22;\\S1/2; 完" 1)
    ;; C06 字段保护（示例字段内容，\f 位于 %<...>% 内）
    (list "值 %<\\f\\H0.5x;\\C1;\\f% \\pr \"0.00\";.Measured|%fml \\f+1; >%结束"
          "值 %<\\f\\H0.5x;\\C1;\\f% \\pr \"0.00\";.Measured|%fml \\f+1; >%结束" 0)
    ;; C07 转义
    (list "路径 C:\\temp\\{图} 与 \\fArial 不变"
          "路径 C:\\temp\\{图} 与 \\fArial 不变" 0)
    ;; C08 长文本（应无修改，完整往返）
    (list long1 long1 0)
    ;; C09 已是宋体
    (list "{\\fSimSun|b0|i0|c134|pf22;已统一}" "{\\fSimSun|b0|i0|c134|pf22;已统一}" 0)
    ;; C10 不完整指令 → 不修改原文（错误由 :issues 报告）
    (list "前面{\\fArial" "前面{\\fArial" 0)
    ;; C11 嵌套两个字体
    (list "{\\fArial|b1|i0;标题}\\P{\\H0.7x;\\fSimHei|b0|i1;说明}"
          "{\\fSimSun|b1|i0|c134|pf22;标题}\\P{\\H0.7x;\\fSimSun|b0|i1|c134|pf22;说明}" 2)
    ;; C12 颜色与字距保持
    (list "\\C3;\\fCourier New;固定\\fSimSun;字宽\\Q5;尾"
          "\\C3;\\fSimSun|c134|pf22;固定\\fSimSun;字宽\\Q5;尾" 1)
    ;; C13 幂等
    (list "{\\fSimSun|b1|i0|c134|pf22;幂等}" "{\\fSimSun|b1|i0|c134|pf22;幂等}" 0)
    ;; C14 正文中的字体名不改
    (list "本页统一使用黑体与 Arial 字体名说明"
          "本页统一使用黑体与 Arial 字体名说明" 0)
    ;; C15 字段嵌套在格式作用域内
    (list "{\\fArial|b1;i;前 %<\\\\AcVar \\f\\\\H;>%后}"
          "{\\fSimSun|b1|c134|pf22;i;前 %<\\\\AcVar \\f\\\\H;>%后}" 1)
  )
)

;;; =====================================================================

;;; 必需数据读取失败时停止，不把异常当作空值。
(defun OCS:mustCall (fn args / r)
  (setq r (OCS:tracedCall fn args))
  (if (vl-catch-all-error-p r)
    (OCS:fail (strcat (vl-symbol-name fn) "：" (vl-catch-all-error-message r))))
  r
)
(defun OCS:requireProp (obj prop)
  (OCS:mustCall (read (strcat "vla-get-" (vl-symbol-name prop))) (list obj))
)
(defun OCS:boolProp (obj prop / value)
  (setq value (OCS:requireProp obj prop))
  (cond ((equal value :vlax-true) T) ((equal value :vlax-false) nil)
        (T (OCS:fail (strcat "无效的布尔属性：" (vl-symbol-name prop)))))
)
(defun OCS:readContent (obj kind prop / text)
  (setq text (OCS:requireProp obj prop))
  (if (not (OCS:stringp text)) (OCS:fail "文字属性未返回字符串"))
  (list "obj" obj "kind" kind "text" text "property" prop
        "protected" (or (OCS:containsField text) (OCS:hasFieldDictionary obj)))
)


(defun OCS:normalValue (value)
  (cond ((equal (type value) 'VARIANT) (OCS:normalValue (OCS:mustCall 'vlax-variant-value (list value))))
        ((equal (type value) 'SAFEARRAY) (OCS:safeArrayToList value))
        (T value))
)


(defun OCS:tableMerge (e row col / merged minrow maxrow mincol maxcol)
  (setq merged (OCS:mustCall 'vla-IsMergedCell (list e row col 'minrow 'maxrow 'mincol 'maxcol)))
  (if (equal merged :vlax-true) (list minrow maxrow mincol maxcol) nil)
)
(defun OCS:tableLayout (e rows cols / row col out)
  (if (or (/= rows (OCS:requireProp e 'Rows)) (/= cols (OCS:requireProp e 'Columns)))
    (OCS:fail "表格行列数变化"))
  (setq row 0 col 0 out (list rows cols))
  (while (< row rows)
    (setq out (append out (list (vla-GetRowHeight e row))) col 0)
    (while (< col cols)
      (setq out (append out (list (OCS:tableMerge e row col))))
      (setq col (1+ col)))
    (setq row (1+ row)))
  (setq col 0)
  (while (< col cols)
    (setq out (append out (list (vla-GetColumnWidth e col))))
    (setq col (1+ col)))
  out
)
(defun OCS:tableMeta (e row col content)
  (list (vla-GetTextStyle2 e row col content) (vla-GetTextHeight2 e row col content)
        (vla-GetCellAlignment e row col) (OCS:colorSnapshot (vla-GetCellContentColor e row col)))
)
(defun OCS:indexErrorP (r / msg)
  (and (vl-catch-all-error-p r)
    (progn
      (setq msg (strcase (vl-catch-all-error-message r)))
      (or (OCS:strContains msg "8002000B") (OCS:strContains msg "INVALID INDEX")
          (OCS:strContains msg "INDEX OUT OF RANGE") (OCS:strContains msg "INVALID INPUT")
          (OCS:strContains msg "无效索引") (OCS:strContains msg "无效的索引")
          (OCS:strContains msg "索引超出范围") (OCS:strContains msg "输入无效"))))
)
(defun OCS:tableEndP (e row col content r / check)
  ;; 文本读取失败不是终点。至少已读到一个内容，且独立索引访问也必须确认越界。
  (and (> content 0) (OCS:indexErrorP r)
       (OCS:indexErrorP (vl-catch-all-apply 'vla-GetTextStyle2 (list e row col content)))
       (OCS:indexErrorP (vl-catch-all-apply 'vla-GetFieldId2 (list e row col content))))
)
(defun OCS:tableReadCell (e row col / state typ merge label edits partial n done raw new fid formula changes edit)
  (setq label (strcat "单元格[" (itoa row) "," (itoa col) "]")
        edits nil partial nil changes 0)
  (OCS:trace "TABLE_CELL" (list row col))
  (setq merge (OCS:tableMerge e row col))
  (if (not (and merge (or (/= row (car merge)) (/= col (nth 2 merge)))))
    (progn
      (setq state (OCS:mustCall 'vla-GetCellState (list e row col)))
      (setq typ (OCS:mustCall 'vla-GetContentType (list e row col)))
      (cond
        ((equal (OCS:mustCall 'vla-IsEmpty (list e row col)) :vlax-true) nil)
        ((or (/= 0 (logand state 31)) (/= typ 1))
         (setq partial (list (strcat label "：链接、锁定、字段或块内容保持原状"))))
        (T
          (setq n 0 done nil)
          (while (and (not done) (< n 1024))
            (setq raw (OCS:tableGetText e row col n))
            (if (vl-catch-all-error-p raw)
              (if (OCS:tableEndP e row col n raw)
                (setq done T)
                (OCS:fail (strcat label " 内容项 " (itoa n) " 读取失败：" (vl-catch-all-error-message raw))))
              (progn
                (if (not (OCS:stringp raw)) (OCS:fail (strcat label " 未返回字符串")))
                (setq fid (OCS:mustCall 'vla-GetFieldId2 (list e row col n)))
                (setq formula (OCS:mustCall 'vla-GetHasFormula (list e row col n)))
                (if (or (/= fid 0) (equal formula :vlax-true) (OCS:containsField raw))
                  (setq partial (cons (strcat label "：字段或公式内容保持原状") partial))
                  (progn
                    (setq new (OCS:NormalizeFontRuns raw (OCS:fontTarget)))
                    (if (OCS:assocd "issues" new nil) (OCS:fail (strcat label " 字体格式不完整")))
                    (if (> (OCS:assocd "changes" new 0) 0)
                      (progn
                        (setq edit (list "row" row "col" col "content" n "before" raw
                          "after" (OCS:assocd "text" new raw) "meta" (OCS:tableMeta e row col n)))
                        (setq edits (cons edit edits) changes (+ changes (OCS:assocd "changes" new 0)))))))
                (setq n (1+ n)))))
          (if (not done) (OCS:fail (strcat label " 内容项达到 1024 上限，停止以免漏改")))))))
  (list "edits" (reverse edits) "partial" partial "changes" changes)
)


(defun OCS:errorText (r)
  (if *OCS:FailureMessage* *OCS:FailureMessage* (vl-catch-all-error-message r))
)
(defun OCS:verifyFontWrite (res / name r cleanup)
  (setq name (OCS:tempStyleName) *OCS:ProbeStyle* name)
  (setq r (vl-catch-all-apply 'OCS:probeFontBody (list res name)))
  (setq cleanup (vl-catch-all-apply 'OCS:deleteStyleIfExists (list name)))
  (if (vl-catch-all-error-p r) (setq r (OCS:addProblem res "error" (OCS:errorText r))))
  (if (or (vl-catch-all-error-p cleanup) (tblobjname "STYLE" name))
    (setq r (OCS:addProblem r "error" "临时字体样式清理失败"))
    (setq *OCS:ProbeStyle* nil))
  r
)
(defun OCS:hasPlannedWrites ( / needed st ent)
  (setq needed (not (null (OCS:assocd "targets" *OCS:Plan* nil))))
  (foreach st (OCS:assocd "styles" *OCS:Plan* nil)
    (setq ent (tblobjname "STYLE" (OCS:assocd "name" st "")))
    (if (or (not ent) (not (OCS:styleIsTarget ent))) (setq needed T)))
  needed
)
(defun OCS:recoverReport (report / r)
  (setq r (vl-catch-all-apply 'OCS:Rollback nil))
  (OCS:trace "RECOVERY_RESULT" (if (vl-catch-all-error-p r) (vl-catch-all-error-message r) r))
  (if (and (not (vl-catch-all-error-p r)) r)
    (OCS:putPair report "status" "失败已回滚")
    (progn
      (setq report (OCS:putPair report "recoverFailed" 1))
      (setq report (OCS:appendError report "RECOVERY" "自动恢复未通过校验，请检查原图与撤销记录"))
      (OCS:putPair report "status" "恢复失败")))
)
(defun OCS:runStats (report styles hosts / stats key)
  (setq stats (OCS:assocd "stats" *OCS:Plan* nil))
  (foreach key (list "attribs" "blocks" "xrefBlocks" "displayBlocks")
    (setq report (OCS:putPair report key (OCS:assocd key stats 0))))
  (OCS:reportSet report
    (list (cons "stylesScanned" (length (OCS:assocd "styles" *OCS:Plan* nil)))
          (cons "stylesModified" (OCS:assocd "modified" styles 0))
          (cons "stylesXref" (length (OCS:assocd "xrefStyle" *OCS:Plan* nil)))
          (cons "stylesShape" (length (OCS:assocd "shape" *OCS:Plan* nil)))
          (cons "hostsScanned" (length (OCS:assocd "hosts" *OCS:Plan* nil)))
          (cons "fontRunsChanged" (OCS:assocd "changes" hosts 0))
          (cons "tableContents" (OCS:assocd "contents" hosts (OCS:assocd "tableContents" hosts 0)))
          (cons "uncovered" (OCS:assocd "unknown" stats 0))
          (cons "uncoveredDetail" (OCS:assocd "skipped" stats nil))))
)

;;; 加载提示（防御式：版本号取不到时不触发 strcat 类型错误）
;;; =====================================================================


;; 日期：2026-10-13。只读扩展字典，不能调用会创建字典的 GetExtensionDictionary。
(defun OCS:hasFieldDictionary (obj / e ext)
  (setq e (entget (vlax-vla-object->ename obj)) ext (OCS:assocd 360 e nil))
  (and ext (dictsearch ext "ACAD_FIELD"))
)
(defun OCS:nonFontXdata (e / out pair app)
  (setq out nil)
  (foreach pair e
    (if (= (car pair) -3)
      (foreach app (cdr pair)
        ;; ACAD 中的字体名/字体位由 SetFont 维护，其余应用扩展数据原样比较。
        (if (/= (strcase (car app)) "ACAD") (setq out (cons app out))))))
  (reverse out)
)
(defun OCS:colorSnapshot (color)
  (list (vla-get-ColorMethod color) (vla-get-ColorIndex color)
        (vla-get-Red color) (vla-get-Green color) (vla-get-Blue color)
        (vla-get-BookName color) (vla-get-ColorName color))
)
(defun OCS:readbackHosts ( / ok target e edit)
  (setq ok T)
  (foreach target (OCS:assocd "targets" *OCS:Plan* nil)
    (setq e (OCS:assocd "obj" target nil))
    (if (not (equal (OCS:assocd "before" target nil) (OCS:hostSnapshot e) 1e-9)) (setq ok nil))
    (if (= (OCS:assocd "kind" target "") "table")
      (progn
        (foreach edit (OCS:assocd "edits" target nil)
          (if (or (not (equal (OCS:assocd "after" edit "")
                (vla-GetTextString e (OCS:assocd "row" edit 0) (OCS:assocd "col" edit 0) (OCS:assocd "content" edit 0))))
              (not (equal (OCS:assocd "meta" edit nil)
                (OCS:tableMeta e (OCS:assocd "row" edit 0) (OCS:assocd "col" edit 0) (OCS:assocd "content" edit 0)) 1e-9)))
            (setq ok nil)))
        (if (or (not (equal (OCS:assocd "suppressed" target nil) (vla-get-RegenerateTableSuppressed e)))
                (not (equal (OCS:assocd "layout" target nil)
                  (OCS:tableLayout e (OCS:assocd "rows" target 0) (OCS:assocd "cols" target 0)) 1e-9)))
          (setq ok nil)))
      (if (not (equal (OCS:assocd "newText" target "")
            (OCS:assocd "text" (OCS:ReadHost (OCS:assocd "host" target nil)) ""))) (setq ok nil))))
  (list "ok" ok "error" (if ok nil "再生后文字内容或非字体参数与计划不一致"))
)

(if (and (boundp '*OCS:Version*) *OCS:Version*)
(princ (strcat "\n一键统一宋体（YJST）v" *OCS:Version*
                 " 已加载。YJST 转换，YJSTCHECK 核查，YJSTLOG 查看日志路径。"))
  (princ "\n一键统一宋体（YJST）已加载。输入 YJST 执行。")
)
(princ)
