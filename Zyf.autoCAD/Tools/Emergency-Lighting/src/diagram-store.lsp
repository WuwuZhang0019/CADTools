;; Date: 2026-10-09. DWG-owned records; external .eld files are diagnostic only.
(defun EL:StoreParseRequire (condition)
  (if (not condition)
    (progn
      (EL:LogEvent "STORE_PARSE_ERROR" (list (cons 'phase *EL:StorePhase*)
        (cons 'token-index *EL:StoreTokenIndex*)
        (cons 'last-token (EL:StoreTokenSummary *EL:StoreLastToken*))
        (cons 'next-token (EL:StoreTokenSummary (car *EL:StoreTokensLeft*)))
        (cons 'text-index *EL:StoreParseIndex*)))
      (princ "\n系统图记录解析失败，具体字段已记录到诊断日志。") (exit))) condition)
(defun EL:StoreTokenSummary (pair / value)
  ;; Date: 2026-10-09. Bound every diagnostic field before printing it.
  (if pair
    (progn
      (setq value (cdr pair))
      (list (cons 'code (car pair)) (cons 'type (type value))
        (cons 'length (if (equal (type value) 'STR) (strlen value)))
        (cons 'value (if (equal (type value) 'STR) (substr value 1 96) value))))))
(defun EL:StoreParseSpace ()
  (while (and (<= *EL:StoreParseIndex* *EL:StoreParseLength*)
      (member (substr *EL:StoreParseText* *EL:StoreParseIndex* 1) '(" " "\t" "\r" "\n")))
    (setq *EL:StoreParseIndex* (1+ *EL:StoreParseIndex*))))
(defun EL:StoreJoinStrings (parts / joined)
  ;; Date: 2026-10-11. Merge adjacent pairs, copying each character at most
  ;; once per level instead of copying a growing signature for every token.
  ;; Keep native string contents and field boundaries unchanged.
  (while (cdr parts)
    (setq joined nil)
    (while parts
      (setq joined (cons (if (cdr parts) (strcat (car parts) (cadr parts)) (car parts)) joined)
        parts (cddr parts)))
    (setq parts (reverse joined)))
  (if parts (car parts) ""))
(defun EL:StoreParseString (/ value parts start end quote-index slash-index width done)
  ;; Date: 2026-10-09. READ sees only bounded fragments, including long
  ;; signatures. Keep escapes whole; native READ decodes quotes and controls.
  (setq value "" *EL:StoreParseIndex* (1+ *EL:StoreParseIndex*))
  (while (not done)
    (EL:StoreParseRequire (<= *EL:StoreParseIndex* *EL:StoreParseLength*))
    (setq start *EL:StoreParseIndex* end (min (+ start 96) (1+ *EL:StoreParseLength*))
      quote-index (vl-string-search "\"" *EL:StoreParseText* (1- start))
      slash-index (vl-string-search "\\" *EL:StoreParseText* (1- start)))
    (if quote-index (setq quote-index (1+ quote-index)))
    (if slash-index (setq slash-index (1+ slash-index)))
    (cond
      ((and quote-index (< quote-index end) (or (not slash-index) (< quote-index slash-index)))
        (setq end quote-index done T))
      ((and slash-index (< slash-index end))
        (setq width 2)
        (if (member (substr *EL:StoreParseText* (1+ slash-index) 1) '("0" "1" "2" "3" "4" "5" "6" "7"))
          (progn
            (setq width 4)
            (EL:StoreParseRequire (and
              (member (substr *EL:StoreParseText* (+ slash-index 2) 1) '("0" "1" "2" "3" "4" "5" "6" "7"))
              (member (substr *EL:StoreParseText* (+ slash-index 3) 1) '("0" "1" "2" "3" "4" "5" "6" "7"))))))
        (setq end (+ slash-index width))
        (EL:StoreParseRequire (<= end (1+ *EL:StoreParseLength*)))))
    (if (> end start)
      (setq parts (cons (read (strcat "\"" (substr *EL:StoreParseText* start (- end start)) "\"")) parts)))
    (setq *EL:StoreParseIndex* (if done (1+ end) end))) (EL:StoreJoinStrings (reverse parts)))
(defun EL:StoreParseValue (/ ch rows value done tail item start token)
  (EL:StoreParseSpace)
  (EL:StoreParseRequire (<= *EL:StoreParseIndex* *EL:StoreParseLength*))
  (setq ch (substr *EL:StoreParseText* *EL:StoreParseIndex* 1))
  (cond
    ((equal ch "\"") (EL:StoreParseString))
    ((equal ch "(")
      (setq *EL:StoreParseIndex* (1+ *EL:StoreParseIndex*))
      ;; Iterate list tails; recursion follows nesting rather than row count.
      (while (not done)
        (EL:StoreParseSpace)
        (EL:StoreParseRequire (<= *EL:StoreParseIndex* *EL:StoreParseLength*))
        (setq ch (substr *EL:StoreParseText* *EL:StoreParseIndex* 1))
        (cond
          ((equal ch ")") (setq value (reverse rows) done T))
          ((and (equal ch ".") (member (substr *EL:StoreParseText* (1+ *EL:StoreParseIndex*) 1)
              '(" " "\t" "\r" "\n" "(" ")" "\"" "")))
            (EL:StoreParseRequire rows)
            (setq *EL:StoreParseIndex* (1+ *EL:StoreParseIndex*) tail (EL:StoreParseValue))
            (EL:StoreParseSpace)
            (EL:StoreParseRequire (equal (substr *EL:StoreParseText* *EL:StoreParseIndex* 1) ")"))
            (foreach item rows (setq tail (cons item tail)))
            (setq value tail done T))
          (T (setq rows (cons (EL:StoreParseValue) rows)))))
      (setq *EL:StoreParseIndex* (1+ *EL:StoreParseIndex*)) value)
    (T
      (setq start *EL:StoreParseIndex*)
      (while (and (<= *EL:StoreParseIndex* *EL:StoreParseLength*)
          (not (member (substr *EL:StoreParseText* *EL:StoreParseIndex* 1)
            '(" " "\t" "\r" "\n" "(" ")" "\""))))
        (setq *EL:StoreParseIndex* (1+ *EL:StoreParseIndex*)))
      (EL:StoreParseRequire (and (> *EL:StoreParseIndex* start) (<= (- *EL:StoreParseIndex* start) 96)))
      (setq token (substr *EL:StoreParseText* start (- *EL:StoreParseIndex* start)))
      (EL:StoreParseRequire (and (not (equal token ".")) (not (vl-string-search "'" token))
        (not (vl-string-search ";" token)) (not (vl-string-search "\\" token))))
      (setq value (read token))
      (EL:StoreParseRequire (or (not value) (member (type value) '(INT REAL SYM)))) value)))
(defun EL:StoreParse (textdata / *EL:StoreParseText* *EL:StoreParseIndex* *EL:StoreParseLength* value)
  ;; Same V1 text/DXF format; no migration and no evaluation of stored data.
  (setq *EL:StoreParseText* textdata *EL:StoreParseIndex* 1 *EL:StoreParseLength* (strlen textdata)
    value (EL:StoreParseValue))
  (EL:StoreParseSpace)
  (EL:StoreParseRequire (> *EL:StoreParseIndex* *EL:StoreParseLength*)) value)
(defun EL:StoreStringChunks (value / size start codes block count chunks code unicode)
  ;; Date: 2026-10-14. Keep exactly the same DXF pieces, without walking
  ;; every byte of the integer tape or splitting strings that already fit.
  (setq size (strlen value))
  (cond
    ((<= size 32) (list (cons 1 value)))
    ((equal (vl-string-trim " -0123456789" value) "")
      (setq start 1)
      (while (<= start size)
        (setq chunks (cons (cons 1 (substr value start 32)) chunks) start (+ start 32)))
      (reverse chunks))
    (T
      ;; Non-ASCII strings retain the legacy multibyte boundary handling.
      (setq codes (vl-string->list value)
        unicode (vl-catch-all-apply 'getvar (list "LISPSYS")))
      (setq unicode (and (numberp unicode) (> unicode 0)))
      (while codes
        (setq block nil count 0)
        (while (and codes (< count 32))
          (setq code (car codes) codes (cdr codes) block (cons code block) count (1+ count))
          (if (and (not unicode) (>= code 128) (<= code 255) codes)
            (setq block (cons (car codes) block) codes (cdr codes) count (1+ count))))
        (setq chunks (cons (cons 1 (vl-list->string (reverse block))) chunks)))
      (reverse chunks))))
(defun EL:StoreEncodeValue (value / kind tail token pair)
  (setq kind (type value))
  (cond
    ((not value) (setq *EL:StoreTokens* (cons '(2 . "N") *EL:StoreTokens*)))
    ((equal value T) (setq *EL:StoreTokens* (cons '(2 . "T") *EL:StoreTokens*)))
    ((equal kind 'INT) (setq *EL:StoreTokens* (cons (cons 90 value) *EL:StoreTokens*)))
    ((equal kind 'REAL) (setq *EL:StoreTokens* (cons (cons 40 value) *EL:StoreTokens*)))
    ((equal kind 'STR)
      (setq *EL:StoreTokens* (cons '(2 . "S") *EL:StoreTokens*))
      (foreach pair (EL:StoreStringChunks value) (setq *EL:StoreTokens* (cons pair *EL:StoreTokens*)))
      (setq *EL:StoreTokens* (cons '(2 . "E") *EL:StoreTokens*)))
    ((equal kind 'SYM)
      (setq token (vl-symbol-name value))
      (EL:StoreParseRequire (<= (strlen token) 96))
      (setq *EL:StoreTokens* (cons (cons 3 token) *EL:StoreTokens*)))
    ((listp value)
      (setq *EL:StoreTokens* (cons '(2 . "L") *EL:StoreTokens*) tail value)
      (while (and tail (listp tail))
        (EL:StoreEncodeValue (car tail)) (setq tail (cdr tail)))
      (if tail
        (progn (setq *EL:StoreTokens* (cons '(2 . "D") *EL:StoreTokens*)) (EL:StoreEncodeValue tail)))
      (setq *EL:StoreTokens* (cons '(2 . "E") *EL:StoreTokens*)))
    (T (EL:StoreParseRequire nil))))
(defun EL:StoreEncodeNative (value marker / *EL:StoreTokens*)
  ;; Date: 2026-10-11. Native codec is shared by both wire versions. It keeps
  ;; group 40 doubles, group 90 integers and the unchanged raw string chunks.
  (setq *EL:StoreTokens* (list (cons 300 marker)))
  (EL:StoreEncodeValue value) (reverse *EL:StoreTokens*))
(defun EL:StoreEncodeLegacy (value / tokens)
  (setq tokens (EL:StoreEncodeNative value "EL_TYPED_V1"))
  (EL:PerfSet "store-wire-version" 1)
  (EL:PerfSet "store-template-pool-count" 0)
  (EL:PerfSet "store-atom-pool-count" 0)
  (EL:PerfSet "store-body-token-count" 0) tokens)
(defun EL:StoreEncode (value / packed tokens valid bodycount)
  ;; Preserve the public native-value codec contract for non-store callers.
  ;; StoreWrite separately refuses invalid/future business stores outright.
  (setq valid (vl-catch-all-apply 'EL:StoreSchemaValid (list value)))
  (if (and (not (vl-catch-all-error-p valid)) valid)
    (progn
      (setq packed (EL:PerfCall "STORE_COMPACT" 'EL:StoreCompact (list value)) bodycount (length (EL:Get 'body packed))
        packed (EL:Put 'codec 'EL_COMPACT_V2
          (EL:Put 'body (EL:PerfCall "STORE_PACK_INTS" 'EL:CompactPackIntegers (list (EL:Get 'body packed))) packed))
        tokens (EL:PerfCall "STORE_NATIVE_ENCODE" 'EL:StoreEncodeNative (list packed "EL_COMPACT_TYPED_V3")))
      (EL:PerfSet "store-wire-version" 3)
      (EL:PerfSet "store-compact-fields" (length tokens))
      (EL:PerfSet "store-template-pool-count" (length (EL:Get 'templates packed)))
      (EL:PerfSet "store-atom-pool-count" (length (EL:Get 'atoms packed)))
      (EL:PerfSet "store-body-token-count" bodycount)
      (EL:PerfSet "store-body-packed-items" (length (EL:Get 'body packed))) tokens)
    (EL:StoreEncodeLegacy value)))
(defun EL:StoreTake (/ pair)
  (EL:StoreParseRequire *EL:StoreTokensLeft*)
  (setq pair (car *EL:StoreTokensLeft*) *EL:StoreTokensLeft* (cdr *EL:StoreTokensLeft*)
    *EL:StoreTokenIndex* (1+ *EL:StoreTokenIndex*) *EL:StoreLastToken* pair) pair)
(defun EL:StoreDecodeValue (/ pair code tag value rows tail item count token)
  (setq pair (EL:StoreTake) code (car pair) tag (cdr pair))
  (cond
    ((= code 90) (EL:StoreParseRequire (equal (type tag) 'INT)) tag)
    ((= code 40) (EL:StoreParseRequire (equal (type tag) 'REAL)) tag)
    ((= code 3)
      (EL:StoreParseRequire (and (equal (type tag) 'STR) (> (strlen tag) 0) (<= (strlen tag) 96)))
      (setq value (read tag))
      (EL:StoreParseRequire (and (equal (type value) 'SYM) (equal tag (vl-symbol-name value)))) value)
    ((equal pair '(2 . "N")) nil)
    ((equal pair '(2 . "T")) T)
    ((equal pair '(2 . "S"))
      (setq value "" count 0)
      (while (and *EL:StoreTokensLeft* (= (caar *EL:StoreTokensLeft*) 1))
        (setq token (cdr (EL:StoreTake)))
        (EL:StoreParseRequire (and (equal (type token) 'STR) (<= (strlen token) 240)))
        (setq rows (cons token rows) count (1+ count)))
      (EL:StoreParseRequire (and (> count 0) (equal (EL:StoreTake) '(2 . "E"))))
      (EL:StoreJoinStrings (reverse rows)))
    ((equal pair '(2 . "L"))
      (while (and *EL:StoreTokensLeft* (not (member (car *EL:StoreTokensLeft*) '((2 . "E") (2 . "D")))))
        (setq rows (cons (EL:StoreDecodeValue) rows)))
      (if (equal (car *EL:StoreTokensLeft*) '(2 . "D"))
        (progn
          (EL:StoreParseRequire rows) (EL:StoreTake) (setq tail (EL:StoreDecodeValue))
          (EL:StoreParseRequire (and tail (not (listp tail))))
          (foreach item rows (setq tail (cons item tail))) (setq value tail))
        (setq value (reverse rows)))
      (EL:StoreParseRequire (equal (EL:StoreTake) '(2 . "E"))) value)
    (T (EL:StoreParseRequire nil))))
(defun EL:StoreDecodeNative (tokens marker / *EL:StoreTokensLeft* *EL:StoreTokenIndex* *EL:StoreLastToken* value)
  (setq *EL:StoreTokensLeft* tokens *EL:StoreTokenIndex* 0)
  (EL:StoreParseRequire (equal (EL:StoreTake) (cons 300 marker)))
  (setq value (EL:StoreDecodeValue))
  (EL:StoreParseRequire (not *EL:StoreTokensLeft*)) value)
(defun EL:StoreDecode (tokens / marker)
  ;; Read legacy records without rewriting. Future wire versions are refused.
  (setq marker (cdr (car tokens)))
  (cond
    ((equal marker "EL_TYPED_V1") (EL:StoreDecodeNative tokens marker))
    ((member marker '("EL_COMPACT_TYPED_V2" "EL_COMPACT_TYPED_V3"))
      (EL:PerfCall "STORE_EXPAND" 'EL:StoreExpand
        (list (EL:PerfCall "STORE_NATIVE_DECODE" 'EL:StoreDecodeNative (list tokens marker)))))
    (T (EL:StoreParseRequire nil))))
(defun EL:StorePayload (entry / prefix)
  ;; Date: 2026-10-13. Typed records start at group 300. Filter only the
  ;; short header, then return the COMPLETE tail without per-field Lisp calls.
  ;; Preserve unexpected fields after that marker for exact checks/decoding;
  ;; also retain data before it so malformed prefixes cannot hide corruption.
  ;; Without a typed marker, this is the original legacy text-field filter.
  (while (and entry (not (equal (caar entry) 300)))
    (if (member (caar entry) '(1 2 3 40 90)) (setq prefix (cons (car entry) prefix)))
    (setq entry (cdr entry)))
  (if entry
    (progn (EL:PerfCount "store-payload-tail-reuses" 1)
      (if prefix (append (reverse prefix) entry) entry))
    (progn (EL:PerfCount "store-payload-filter-calls" 1) (reverse prefix))))
(defun EL:StoreSchemaValid (value)
  (and (listp value) (equal (EL:Get 'schema-version value) 1)
    (equal (type (EL:Get 'drawing-uuid value)) 'STR) (listp (EL:Get 'diagrams value))))
(defun EL:StoreReadEntry (entry / textdata parts pair value valid *EL:StorePhase*)
  ;; Date: 2026-10-11. One validation path for fresh reads and actual DWG
  ;; readback. Never pass the proposed in-memory store as an entry.
  (setq *EL:StorePhase* 'dwg-read)
  (if entry
    (progn
      (if (assoc 300 entry)
        (setq value (EL:MeasuredCatch 'EL:PerfCall
          (list "STORE_DECODE" 'EL:StoreDecode (list (EL:StorePayload entry)))))
        (progn
          ;; Legacy V1 is read without rewriting; migrate only in a validated transaction.
          (foreach pair entry (if (= (car pair) 1) (setq parts (cons (cdr pair) parts))))
          (setq textdata (EL:StoreJoinStrings (reverse parts)))
          (setq value (EL:MeasuredCatch 'EL:PerfCall (list "STORE_DECODE" 'EL:StoreParse (list textdata))))))
      (EL:PerfSet "store-entry-fields" (length entry))
      (if (vl-catch-all-error-p value)
        (progn
          (EL:LogEvent "STORE_DECODE_ERROR" (list (cons 'handle (cdr (assoc 5 entry)))
            (cons 'format (cdr (assoc 300 entry))) (cons 'fields (length entry))
            (cons 'message (vl-catch-all-error-message value))))
          (princ (strcat "\nDWG 草稿读回解析失败：" (vl-catch-all-error-message value))) (exit)))
      (setq valid (EL:MeasuredCatch 'EL:PerfCall (list "STORE_SCHEMA" 'EL:StoreSchemaValid (list value))))
      (if (or (vl-catch-all-error-p valid) (not valid))
        (progn
          (EL:LogEvent "STORE_SCHEMA_ERROR" (list (cons 'handle (cdr (assoc 5 entry)))
            (cons 'value-type (type value))
            (cons 'message (if (vl-catch-all-error-p valid) (vl-catch-all-error-message valid) "invalid V1 required fields"))))
          (princ "\nDWG 草稿字段校验失败，详情已记录到诊断日志。") (exit)))
      value)))
(defun EL:StoreReadCacheValid (entry cache)
  ;; Date: 2026-10-11. A hit still checks current dictionary ownership and
  ;; both complete native payloads. Stored business data alone is reusable;
  ;; this never caches source geometry, output entities or a proposed write.
  (and *EL:PerfActive* (equal (EL:Get 'scope cache) *EL:StoreReadScope*)
    entry cache (equal (cdr (assoc 0 entry)) "XRECORD")
    (equal (cdr (assoc -1 entry)) (EL:Get 'entity cache))
    (equal (EL:StorePayload entry) (EL:Get 'payload cache))
    (EL:StoreContextValid cache)))
(defun EL:StoreReadCacheRemember (entry value / candidate valid *EL:StoreReadBusy*)
  ;; Call only with a freshly decoded actual entry, including schema checks.
  ;; Validate again after decoding: callbacks may have changed the owner/data.
  (if *EL:PerfActive*
    (progn
      (setq *EL:StoreReadCache* nil *EL:StoreReadBusy* T)
      (if (and value entry (equal (cdr (assoc 0 entry)) "XRECORD"))
        (progn
          (setq candidate (list (cons 'scope *EL:StoreReadScope*) (cons 'owner (namedobjdict))
            (cons 'entity (cdr (assoc -1 entry))) (cons 'payload (EL:StorePayload entry))
            (cons 'verified-store value))
            valid (EL:MeasuredCatch 'EL:PerfCall
              (list "STORE_CACHE_CHECK" 'EL:StoreContextValid (list candidate))))
          (if (and *EL:PerfActive* (equal (EL:Get 'scope candidate) *EL:StoreReadScope*)
              (not (vl-catch-all-error-p valid)) valid)
            (setq *EL:StoreReadCache* candidate *EL:StoreWarmCache* candidate)))))) value)
(defun EL:StoreReadCachedScope (entry lookup / *EL:StoreReadBusy* cache scope valid value)
  ;; The dynamic guard prevents a read/check callback from reusing a partially
  ;; decoded value or publishing another candidate inside the outer read.
  (setq *EL:StoreReadBusy* T cache *EL:StoreReadCache* scope *EL:StoreReadScope*)
  ;; Date: 2026-10-13. One bounded decoded legacy store may outlive a command.
  ;; Transfer only data, never timing/source proofs, and audit both native paths.
  (if (and (not cache) *EL:StoreWarmCache*)
    (setq cache (EL:Put 'scope scope *EL:StoreWarmCache*)))
  (if (and cache (equal scope (EL:Get 'scope cache)))
    (setq valid (EL:MeasuredCatch 'EL:PerfCall
      (list "STORE_CACHE_CHECK" (if lookup 'EL:StoreContextValid 'EL:StoreReadCacheValid)
        (if lookup (list cache) (list entry cache))))))
  (if (and *EL:PerfActive* (equal scope *EL:StoreReadScope*)
      (not (vl-catch-all-error-p valid)) valid)
    (progn (setq *EL:StoreReadCache* cache *EL:StoreWarmCache* cache)
      (EL:PerfCount "store-read-cache-hits" 1) (EL:Get 'verified-store cache))
    (progn
      (setq *EL:StoreReadCache* nil *EL:StoreWarmCache* nil)
      (EL:PerfCount "store-read-cache-misses" 1)
      (if lookup (setq entry (dictsearch (namedobjdict) "EL_FIXED_V1")))
      (setq value (EL:StoreReadEntry entry))
      (if (equal scope *EL:StoreReadScope*) (EL:StoreReadCacheRemember entry value)) value)))
(defun EL:StoreReadCached (entry)
  ;; Only one active top-level command owns the cache; PerfStart/Finish clear
  ;; it. Outside that scope, or during reentry, use the original fresh decoder.
  (if (and *EL:PerfActive* (not *EL:StoreReadBusy*))
    (EL:StoreReadCachedScope entry nil) (EL:StoreReadEntry entry)))
(defun EL:StoreReadMonolithic (/ value perf)
  (setq perf (EL:PerfBegin "STORE_READ"))
  (EL:PerfCount "store-read-calls" 1)
  ;; A cached read obtains its actual entry in StoreContextValid. Avoid a
  ;; redundant dictionary lookup/filter before those two mandatory routes.
  (setq value (if (and *EL:PerfActive* (not *EL:StoreReadBusy*))
    (EL:StoreReadCachedScope nil T)
    (EL:StoreReadEntry (dictsearch (namedobjdict) "EL_FIXED_V1"))))
  (EL:PerfEnd perf 'returned) value)
(defun EL:StoreStringComplete (value / codes code unicode valid)
  ;; Date: 2026-10-13. A legacy byte string may end in an orphan DBCS lead
  ;; byte after SUBSTR. Do not reuse that failed-save fallback identifier.
  (setq unicode (vl-catch-all-apply 'getvar (list "LISPSYS"))
    codes (vl-string->list value) valid T)
  (if (not (and (numberp unicode) (> unicode 0)))
    (while (and codes valid)
      (setq code (car codes) codes (cdr codes))
      (if (and (>= code 129) (<= code 254))
        (if codes (setq codes (cdr codes)) (setq valid nil))))) valid)
(defun EL:StoreRead ()
  (if *EL:SplitStorageLoaded*
    (progn (EL:PerfCount "store-read-calls" 1) (EL:PerfCall "STORE_READ" 'EL:SplitRead nil))
    (EL:StoreReadMonolithic)))
(defun EL:StoreIndex () (EL:StoreRead))
(defun EL:StoreRecord (id) (EL:By 'diagram-id id (EL:Get 'diagrams (EL:StoreRead))))
(defun EL:StoreForResult (result) (EL:StoreRead))
(defun EL:StoreWrite (store)
  (if (and *EL:SplitStorageLoaded* (not *EL:StoreLegacyWrite*))
    (progn (EL:PerfCount "store-write-calls" 1) (EL:SplitWrite store))
    (EL:StoreWriteMonolithic store)))
(defun EL:StoreContextValid (context)
  (if (assoc 'split-contexts context) (EL:SplitContextValid context)
    (EL:StoreContextMonolithicValid context)))
(defun EL:StoreInitial (/ uuid)
  ;; Date: 2026-10-13. Hash the complete drawing signature into ASCII rather
  ;; than truncating a Chinese path at byte 64. Persisted identities are read
  ;; unchanged by StoreRead; repair only an incomplete in-memory fallback.
  (setq uuid (vl-catch-all-apply 'getvar (list "FINGERPRINTGUID")))
  (if (or (not (equal (type uuid) 'STR)) (equal uuid ""))
    (progn
      (if (or (not *EL:FallbackDrawingUUID*)
          (not (EL:StoreStringComplete *EL:FallbackDrawingUUID*)))
        (setq *EL:FallbackDrawingUUID* (strcat "EL-"
          (rtos (getvar "CDATE") 2 8) "-" (itoa (getvar "MILLISECS"))
          "-" (EL:Hash (EL:Signature (EL:DrawingID))))))
      (setq uuid *EL:FallbackDrawingUUID*)))
  (list '(schema-version . 1) (cons 'drawing-uuid uuid) '(diagrams)))
(defun EL:StoreText (value / textdata tail)
  ;; Date: 2026-10-09. Legacy text for diagnostic snapshots and regression
  ;; fixtures only. DWG persistence uses StoreEncode, never RTOS formatting.
  (cond
    ((equal (type value) 'REAL) (rtos value 2 16))
    ((and value (listp value))
      (setq textdata "(" tail value)
      (while (and tail (listp tail))
        (setq textdata (strcat textdata (EL:StoreText (car tail))) tail (cdr tail))
        (if tail (setq textdata (strcat textdata " "))))
      (if tail (setq textdata (strcat textdata ". " (EL:StoreText tail))))
      (strcat textdata ")"))
    (T (vl-prin1-to-string value))))
(defun EL:StoreDifference (left right path / index found a b offset)
  (if (not (equal left right))
    (cond
      ((and left right (listp left) (listp right)
          (equal (type (car left)) 'SYM) (equal (car left) (car right)))
        (EL:StoreDifference (cdr left) (cdr right) (append path (list (car left)))))
      ((and left right (listp left) (listp right))
        (setq index 0 a left b right)
        (while (and a b (listp a) (listp b) (not found))
          (setq found (EL:StoreDifference (car a) (car b) (append path (list index)))
            a (cdr a) b (cdr b) index (1+ index)))
        (if found found (EL:StoreDifference a b (append path '(tail)))))
      (T
        (setq offset (if (and (equal (type left) 'STR) (equal (type right) 'STR))
          (vl-string-mismatch left right)))
        (list (cons 'path path) (cons 'expected-type (type left)) (cons 'actual-type (type right))
        (cons 'expected (cond ((equal (type left) 'STR) (substr left (max 1 (- (cond (offset) (T 0)) 39)) 80))
          ((and left (listp left)) "<list>") (T left)))
        (cons 'actual (cond ((equal (type right) 'STR) (substr right (max 1 (- (cond (offset) (T 0)) 39)) 80))
          ((and right (listp right)) "<list>") (T right)))
        (cons 'string-offset offset)
        (cons 'expected-length (if (equal (type left) 'STR) (strlen left)))
        (cons 'actual-length (if (equal (type right) 'STR) (strlen right)))
        (cons 'number-difference (if (and (numberp left) (numberp right)) (- left right))))))))
(defun EL:StoreCheck (expected actual stage)
  (if (not (equal expected actual))
    (progn
      (EL:LogEvent "STORE_MISMATCH" (cons (cons 'stage stage) (EL:StoreDifference expected actual nil)))
      (princ "\n草稿记录回读不一致，已停止写入；请保留本次诊断日志。") (exit))) T)
(defun EL:StoreAuditPayload (expected entry source / actual left right index)
  ;; Date: 2026-10-09. Compare before decoding, so malformed native data
  ;; cannot hide its first changed/inserted/missing DXF field behind EXIT.
  (setq actual (EL:StorePayload entry) left expected right actual index 1)
  ;; Date: 2026-10-13. Native full equality is linear without per-field Lisp calls.
  ;; Walk only a mismatch to retain its exact diagnostic field index.
  (if (equal expected actual)
    (setq left nil right nil)
    (while (and left right (equal (car left) (car right)))
      (setq left (cdr left) right (cdr right) index (1+ index))))
  (EL:LogEvent "STORE_DXF_READBACK" (list (cons 'source source)
    (cons 'handle (cdr (assoc 5 entry))) (cons 'object-type (cdr (assoc 0 entry)))
    (cons 'expected-fields (length expected)) (cons 'actual-fields (length actual))
    (cons 'equal (and (not left) (not right)))))
  (if (or left right)
    (EL:LogEvent "STORE_DXF_MISMATCH" (list (cons 'source source) (cons 'index index)
      (cons 'expected (EL:StoreTokenSummary (car left)))
      (cons 'actual (EL:StoreTokenSummary (car right)))
      (cons 'expected-next (EL:StoreTokenSummary (cadr left)))
      (cons 'actual-next (EL:StoreTokenSummary (cadr right))))))
  ;; Date: 2026-10-13. Return this audited payload for the following exact checks.
  actual)
(defun EL:StoreReadback (chunks entity expected / entry native value actual nativepayload)
  (setq entry (dictsearch (namedobjdict) "EL_FIXED_V1"))
  (setq actual (EL:StoreAuditPayload chunks entry 'dictsearch))
  (setq native (entget entity))
  (setq nativepayload (EL:StoreAuditPayload chunks native 'entget))
  ;; Date: 2026-10-12. Reuse the pre-write decoded value only after BOTH actual
  ;; DWG representations match every typed field. No hash or sampled check.
  (if (and *EL:StorePreverified*
      (equal (cdr (assoc -1 entry)) entity)
      (equal (cdr (assoc 0 entry)) "XRECORD") (equal (cdr (assoc 0 native)) "XRECORD")
      (equal chunks (car *EL:StorePreverified*))
      (equal chunks actual) (equal chunks nativepayload)
      (equal expected (cadr *EL:StorePreverified*)))
    (progn (setq value (cadr *EL:StorePreverified*)) (EL:PerfCount "store-readback-decode-reuses" 1))
    (setq value (EL:StoreReadEntry entry)))
  ;; Preserve business-field diagnostics before checking raw representation.
  (EL:StoreCheck expected value 'readback)
  (EL:StoreCheck chunks actual 'dictsearch-readback)
  (EL:StoreCheck chunks nativepayload 'entget-readback)
  (EL:StoreReadCacheRemember entry value))
(defun EL:StoreLegacyEntry (entry / marker value)
  ;; Date: 2026-10-11. A preserved backup must remain an independently valid
  ;; legacy record. Never use a V2/future/corrupt backup as a historical copy.
  (EL:Require (and entry (equal (cdr (assoc 0 entry)) "XRECORD")) "旧版记录备份对象无效，未覆盖。")
  (setq marker (cdr (assoc 300 entry)))
  (EL:Require (or (not marker) (equal marker "EL_TYPED_V1")) "旧版记录备份格式不符，未覆盖。")
  (setq value (EL:StoreReadEntry entry))
  (EL:CompactTemplates value) value)
(defun EL:StoreLegacyBackupVerify (chunks entity expected / entry native value)
  (setq entry (dictsearch (namedobjdict) "EL_FIXED_V1_LEGACY") native (entget entity))
  (EL:Require (and (equal entity (cdr (assoc -1 entry)))
    (equal (cdr (assoc 0 native)) "XRECORD")) "旧版记录备份关联回读失败。")
  (EL:StoreCheck chunks (EL:StorePayload entry) 'legacy-dictsearch-readback)
  (EL:StoreCheck chunks (EL:StorePayload native) 'legacy-entget-readback)
  (setq value (EL:StoreLegacyEntry entry))
  (if expected (EL:StoreCheck expected value 'legacy-backup-logical-readback)) value)
(defun EL:StoreCurrentEntry (entry proposed / entity native chunks value)
  ;; Date: 2026-10-11. Native callbacks may have replaced the record after an
  ;; earlier read. Validate actual current data before any backup/replacement.
  (setq entity (cdr (assoc -1 entry)))
  (EL:Require (and entity (equal (cdr (assoc 0 entry)) "XRECORD")
    (setq native (entget entity)) (equal (cdr (assoc -1 native)) entity)
    (equal (cdr (assoc 0 native)) "XRECORD")) "当前草稿对象或关联已变化，未覆盖。")
  (setq chunks (EL:StorePayload entry))
  (EL:StoreCheck chunks (EL:StorePayload native) 'current-native-before-write)
  (setq value (EL:StoreReadCached entry))
  (EL:CompactTemplates value)
  (EL:Require (equal (EL:Get 'drawing-uuid value) (EL:Get 'drawing-uuid proposed))
    "当前草稿属于其他图纸，未覆盖。") value)
(defun EL:StoreLegacyBackup (entry store old / marker native chunks backup entity value flags)
  ;; Only a write changing an old wire version creates/verifies the backup.
  ;; Subsequent V2 reads/writes do not repeatedly decode historical geometry.
  (setq marker (cdr (assoc 300 entry)))
  (if (and entry (not (member marker '("EL_COMPACT_TYPED_V2" "EL_COMPACT_TYPED_V3"))))
    (progn
      (EL:Require *EL:TransactionOpen* "旧草稿格式迁移必须在完整事务中执行，未写入。")
      (setq entity (cdr (assoc -1 entry))
        native (entget entity) chunks (EL:StorePayload entry))
      (EL:PerfSet "store-legacy-fields" (length chunks))
      (EL:Require (and (equal (cdr (assoc 0 native)) "XRECORD")
        (equal chunks (EL:StorePayload native))
        (equal (EL:Get 'drawing-uuid old) (EL:Get 'drawing-uuid store)))
        "旧记录归属或两路回读不一致，未迁移。")
      (if (setq backup (dictsearch (namedobjdict) "EL_FIXED_V1_LEGACY"))
        (progn
          (setq value (EL:StoreLegacyBackupVerify (EL:StorePayload backup)
            (cdr (assoc -1 backup)) nil))
          (EL:Require (equal (EL:Get 'drawing-uuid value) (EL:Get 'drawing-uuid old))
            "旧版记录备份属于其他图纸，未覆盖。"))
        (progn
          (setq flags (cdr (assoc 280 entry)))
          (if (not flags) (setq flags 1))
          (setq entity (EL:LogCall "STORE_BACKUP_CREATE" (list (cons 'fields (length chunks)))
            'EL:StoreCreatePayload (list chunks flags)))
          (EL:Require (and entity (dictadd (namedobjdict) "EL_FIXED_V1_LEGACY" entity))
            "无法建立旧版记录备份，未迁移。")
          (EL:StoreLegacyBackupVerify chunks entity old)
          (EL:PerfCount "legacy-backup-created" 1)
          (EL:LogEvent "STORE_LEGACY_BACKUP" (list (cons 'fields (length chunks))
            (cons 'format (cond (marker) (T 'legacy-text))))))))) T)
(defun EL:StoreReplacePayload (entity chunks / codes values pair)
  ;; Date: 2026-10-09. ENTMOD may retain omitted XRecord fields in AutoCAD.
  ;; SetXRecordData replaces the complete payload, including legacy strings.
  (setq codes (vlax-make-safearray 2 (cons 0 (1- (length chunks))))
    values (vlax-make-safearray 12 (cons 0 (1- (length chunks)))))
  (vlax-safearray-fill codes (mapcar 'car chunks))
  (vlax-safearray-fill values (mapcar '(lambda (pair)
    (vlax-make-variant (cdr pair) (cond ((= (car pair) 40) 5) ((= (car pair) 90) 3) (T 8)))) chunks))
  (vla-SetXRecordData (vlax-ename->vla-object entity) codes values) T)
(defun EL:StoreCreatePayload (chunks flags / header entity)
  ;; Date: 2026-10-13. Bound the initial ENTMAKEX argument, including its header.
  ;; Large records use the same typed replacement route as existing records;
  ;; never truncate data or weaken either native readback check.
  (setq header (list '(0 . "XRECORD") '(100 . "AcDbXrecord") (cons 280 flags)))
  (if (<= (length chunks) 1021)
    (entmakex (append header chunks))
    (progn
      (setq entity (EL:LogCall "STORE_CREATE_HEADER" (list (cons 'fields (length chunks)))
        'entmakex (list header)))
      (EL:Require entity "无法建立草稿记录头，未写入数据。")
      (EL:LogCall "STORE_REPLACE_PAYLOAD" (list (cons 'entity entity)
          (cons 'fields (length chunks)) '(mode . new-record))
        'EL:StoreReplacePayload (list entity chunks)) entity)))
(defun EL:StoreContextMonolithicValid (context / entry native entity payload)
  ;; Date: 2026-10-11. Check the same document, association and both complete
  ;; native payloads. Reuse avoids decoding, never the actual DWG checks.
  (if (and context (equal (EL:Get 'owner context) (namedobjdict))
      (setq entity (EL:Get 'entity context))
      (setq payload (EL:Get 'payload context))
      (EL:Get 'verified-store context)
      (setq entry (dictsearch (namedobjdict) "EL_FIXED_V1"))
      (equal entity (cdr (assoc -1 entry)))
      (equal (cdr (assoc 0 entry)) "XRECORD")
      (setq native (entget entity))
      (equal (cdr (assoc 0 native)) "XRECORD"))
    (and (equal payload (EL:StorePayload entry))
      (equal payload (EL:StorePayload native)))))
(defun EL:StoreContextCommit (/ valid)
  ;; EndUndoMark can notify other extensions. Only promote a candidate after
  ;; confirming that its exact audited representation still exists then.
  (if (and *EL:StoreContextActive* *EL:StoreContextCandidate*)
    (progn
      (EL:PerfCount "store-context-commit-verifies" 1)
      (setq valid (EL:MeasuredCatch '(lambda ()
        (and (= 0 (logand 8 (getvar "UNDOCTL")))
          (not *EL:TransactionOpen*)
          (EL:LogCall "STORE_CONTEXT_COMMIT" nil 'EL:StoreContextValid (list *EL:StoreContextCandidate*)))) nil))
      (if (and (not (vl-catch-all-error-p valid)) valid)
        (setq *EL:StoreContextCommitted* T)
        (progn
          (setq *EL:StoreContextCandidate* nil *EL:StoreContextCommitted* nil)
          (EL:LogEvent "STORE_CONTEXT_DISCARDED" '((reason . post-commit-native-change))))))))
(defun EL:TransactionVerifiedStore (function args / outcome *EL:StoreContextActive* *EL:StoreContextCandidate* *EL:StoreContextCommitted*)
  ;; Explicit one-operation output; the candidate has dynamic scope only.
  ;; Existing Transaction and StoreWrite return values remain unchanged.
  (setq *EL:StoreContextActive* T)
  (setq outcome (EL:Transaction function args))
  (append (list (cons 'outcome outcome) (cons 'committed
      (and outcome *EL:StoreContextCommitted*)))
    (if (and outcome *EL:StoreContextCommitted*) *EL:StoreContextCandidate*)))
(defun EL:TransactionVerifiedRead (context / valid)
  ;; A caller uses this immediately after the transaction. Still check raw
  ;; data here: unknown callbacks, document changes or later writes invalidate.
  (if (and (EL:Get 'outcome context) (EL:Get 'committed context))
    (setq valid (EL:MeasuredCatch 'EL:LogCall
      (list "STORE_CONTEXT_READ" nil 'EL:StoreContextValid (list context)))))
  (if (and (not (vl-catch-all-error-p valid)) valid)
    (progn (EL:PerfCount "store-context-reuses" 1) (EL:Get 'verified-store context))
    (EL:StoreRead)))
(defun EL:StoreWriteMonolithic (store / chunks entry entity value current decoded *EL:StorePhase* *EL:StorePreverified*)
  (EL:FreshBoundary)
  ;; Every write invalidates the prior candidate, including a failed second
  ;; write in one transaction. Only actual readback can seed the command cache.
  (if *EL:StoreContextActive*
    (setq *EL:StoreContextCandidate* nil *EL:StoreContextCommitted* nil))
  (EL:PerfCount "store-write-calls" 1)
  (setq *EL:StorePhase* 'pre-write)
  (if (not (EL:StoreSchemaValid store))
    (progn
      (EL:LogEvent "STORE_SCHEMA_ERROR" (list (cons 'value-type (type store)) '(phase . pre-write)))
      (princ "\n待保存草稿字段或版本无效，未写入。") (exit)))
  (EL:CompactTemplates store)
  (setq chunks (EL:LogCall "STORE_SERIALIZE" '((format . native-dxf))
    (if *EL:StoreLegacyWrite* 'EL:StoreEncodeLegacy 'EL:StoreEncode) (list store)))
  (EL:PerfSet "store-payload-fields" (length chunks))
  ;; Both checks remain exact: no numeric tolerance, truncation or dropped fields.
  (setq decoded (EL:LogCall "STORE_PARSE" (list '(format . native-dxf) (cons 'tokens (length chunks)))
    'EL:StoreDecode (list chunks)))
  (EL:LogCall "STORE_PREWRITE_COMPARE" (list (cons 'fields (length chunks)))
    'EL:StoreCheck (list store decoded 'pre-write))
  (EL:Require (EL:LogCall "STORE_PREWRITE_SCHEMA" nil 'EL:StoreSchemaValid (list decoded))
    "写入前解码记录无效，未写入。")
  (setq *EL:StorePreverified* (list chunks decoded))
  (setq entry (EL:LogCall "STORE_TARGET_LOOKUP" nil 'dictsearch (list (namedobjdict) "EL_FIXED_V1"))
    entity (cdr (assoc -1 entry)))
  (if entry (setq current (EL:LogCall "STORE_CURRENT_READ" nil 'EL:StoreCurrentEntry (list entry store))))
  (setq *EL:StoreReadCache* nil)
  (if (not *EL:StoreLegacyWrite*)
    (EL:LogCall "STORE_LEGACY_BACKUP" nil 'EL:StoreLegacyBackup (list entry store current)))
  (EL:PerfCount "master-write-attempts" 1)
  (if entity
    (EL:LogCall "STORE_REPLACE_PAYLOAD" (list (cons 'handle (cdr (assoc 5 entry))))
      'EL:StoreReplacePayload (list entity chunks))
    (progn
      (setq entity (EL:LogCall "STORE_CREATE_PAYLOAD" (list (cons 'fields (length chunks)))
        'EL:StoreCreatePayload (list chunks 1)))
      (EL:Require (and entity (EL:LogCall "STORE_DICT_ATTACH" nil 'dictadd
        (list (namedobjdict) "EL_FIXED_V1" entity))) "无法关联草稿记录，事务未完成。")))
  (setq value (EL:LogCall "STORE_READBACK" nil 'EL:StoreReadback (list chunks entity store)))
  (if *EL:StoreContextActive*
    (setq *EL:StoreContextCandidate* (list (cons 'owner (namedobjdict))
      (cons 'entity entity) (cons 'payload chunks) (cons 'verified-store value))))
  (EL:FreshBoundary) T)
(defun EL:StoreWriteLegacy (store / *EL:StoreLegacyWrite*)
  ;; Only the explicit downgrade transaction selects the legacy encoder.
  (EL:Require *EL:TransactionOpen* "旧格式转换必须在完整事务中执行。")
  (setq *EL:StoreLegacyWrite* T)
  (EL:StoreWriteMonolithic store)
  (if *EL:SplitStorageLoaded* (EL:SplitDeactivate)) T)
(defun EL:StoreDowngradeWrite (/ store)
  ;; Read after StartUndoMark: a native callback may have edited the record.
  (if (setq store (EL:StoreRead))
    (progn (setq *EL:StoreDowngradeExpected* store) (EL:StoreWriteLegacy store))))
(defun EL:StoreDowngrade (/ context value entry outcome *EL:StoreDowngradeExpected*)
  (if (or (dictsearch (namedobjdict) "EL_FIXED_V1")
      (dictsearch (namedobjdict) "EL_FIXED_SPLIT_V1"))
    (progn
      (setq context (EL:TransactionVerifiedStore 'EL:StoreDowngradeWrite nil)
        outcome (EL:Get 'outcome context))
      (if outcome
        (progn
          (setq value (EL:TransactionVerifiedRead context)
            entry (dictsearch (namedobjdict) "EL_FIXED_V1"))
          (EL:Require (EL:Get 'committed context) "转换提交后记录已变化，未确认旧版兼容。")
          (EL:StoreCheck *EL:StoreDowngradeExpected* value 'legacy-post-commit-logical)
          ;; Audit both native routes again, including their actual wire tag.
          (EL:StoreCheck *EL:StoreDowngradeExpected*
            (EL:StoreCurrentEntry entry *EL:StoreDowngradeExpected*) 'legacy-final-native)
          (EL:Require (equal (cdr (assoc 300 entry)) "EL_TYPED_V1") "当前记录不是旧格式，未确认旧版兼容。")
          (princ "\n当前完整草稿已转换为旧版兼容格式；请保存 DWG 后加载旧版插件。")))
      outcome)
    (progn (princ "\n当前图纸没有系统图草稿，无需转换。") nil)))
(defun c:ELSTORELEGACY (/ outcome)
  (setq outcome (vl-catch-all-apply 'EL:StoreDowngrade nil))
  (if (vl-catch-all-error-p outcome)
    (progn
      (EL:LogEvent "STORE_LEGACY_ERROR" (list (cons 'message (vl-catch-all-error-message outcome))))
      (princ (strcat "\n旧格式转换未完成：" (vl-catch-all-error-message outcome)))))
  (princ))
(defun EL:DiagramForPanel (panel store / found row)
  ;; Date: 2026-10-14. Legacy drawings may still contain several records until
  ;; their next verified save; use only the latest one for current inputs.
  (foreach row (EL:Get 'diagrams store)
    (if (equal panel (EL:Get 'source-panel-handle row)) (setq found row))) found)
;; Date: 2026-10-14. Only the current source draft supplies review data.
(defun EL:RecordForResult (result store)
  (EL:DiagramForPanel (EL:Get 'panel result) store))
(defun EL:DiagramSerial (id panel store / prefix suffix serial index digit valid)
  (if (and (equal (type panel) 'STR) (equal (type (EL:Get 'drawing-uuid store)) 'STR))
    (setq prefix (strcat (EL:Get 'drawing-uuid store) "/" panel "/")))
  (if (and prefix (equal (type id) 'STR) (> (strlen id) (strlen prefix))
      (equal (substr id 1 (strlen prefix)) prefix))
    (progn
      (setq suffix (substr id (1+ (strlen prefix))) index 1 valid T)
      (while (and valid (<= index (strlen suffix)))
        (setq digit (ascii (substr suffix index 1))
          valid (and (<= 48 digit) (<= digit 57)) index (1+ index)))
      (if valid (progn (setq serial (atoi suffix))
        (if (and (> serial 0) (equal suffix (itoa serial))) serial 0)) 0)) 0))
(defun EL:InputRecord (record)
  ;; Date: 2026-10-15. Current-input reopening uses rows, config and overrides.
  ;; Full source geometry belongs to the live result/freshness check only;
  ;; no history replay or old-diagram update consumes a persisted snapshot.
  (EL:Put 'input-record-version 2
    (vl-remove-if '(lambda (row) (member (car row) '(source-signature draft-source-signature))) record)))
(defun EL:StorePutDiagram (record store / rows row source seen kept latest serials serial)
  ;; Date: 2026-10-14. Keep one editable record per source panel. Earlier
  ;; generated entities stay in the DWG with their tags, but their history
  ;; payload is dropped on the next verified store write.
  (setq rows (EL:Get 'diagrams store) serials (EL:Get 'diagram-serials store))
  (foreach row (append rows (list record))
    (setq source (EL:Get 'source-panel-handle row)
      serial (EL:DiagramSerial (EL:Get 'diagram-id row) source store))
    (if (> serial (cond ((EL:Get source serials)) (T 0)))
      (setq serials (EL:Put source serial serials)))
    (setq latest (EL:Put source row latest)))
  (foreach row rows
    (setq source (EL:Get 'source-panel-handle row))
    (if (not (member source seen))
      (setq kept (cons (EL:Get source latest) kept) seen (cons source seen))))
  (setq kept (reverse kept))
  (if (not (member (EL:Get 'source-panel-handle record) seen))
    (setq kept (append kept (list record))))
  (setq store (EL:Put 'diagrams kept store))
  (if (or serials (assoc 'diagram-serials store))
    (EL:Put 'diagram-serials serials store) store))
(defun EL:TagEntity (object store record kind uid / e data tag)
  (regapp "EL_FIXED_V1")
  (setq e (vlax-vla-object->ename object) data (entget e)
    tag (list "EL_FIXED_V1" (cons 1000 (EL:Get 'drawing-uuid store))
      (cons 1000 (EL:Get 'diagram-id record)) (cons 1000 kind) (cons 1000 uid)
      (cons 1000 (cdr (assoc 5 data)))))
  (EL:Require (EL:LogCall "TAG_ENTITY" (list (cons 'kind kind) (cons 'uid uid)
      (cons 'handle (cdr (assoc 5 data)))) 'EL:PerfWrite (list 'entmod (list (append data (list (list -3 tag))))))
    (strcat "系统图关联写入失败：" kind " / " uid))
  (EL:Require (EL:OwnedEntity (cdr (assoc 5 data)) store record kind uid)
    (strcat "系统图关联回读失败：" kind " / " uid))
  (cdr (assoc 5 data)))
(defun EL:OwnedEntity (handle store record kind uid / e data tag)
  (if (and (equal (type handle) 'STR) (setq e (handent handle)))
    (progn
      (setq data (entget e) tag (EL:DiagramTag e))
      (if (and (equal (cdr (assoc 0 data)) (if (equal kind "text") "TEXT" "INSERT"))
          (equal tag (list (cons 1000 (EL:Get 'drawing-uuid store))
            (cons 1000 (EL:Get 'diagram-id record)) (cons 1000 kind) (cons 1000 uid) (cons 1000 handle)))) e))))
(defun EL:UniqueDiagram (store record / ref handle identity handles identities e data reason good)
  ;; Date: 2026-10-13. The saved handles identify the update targets. Copies
  ;; elsewhere keep their old tags but must neither block nor inherit this
  ;; record. Never search by tag to replace a missing original member.
  (setq good (and (equal (type (EL:Get 'drawing-uuid store)) 'STR)
    (/= (EL:Get 'drawing-uuid store) "")
    (equal (type (EL:Get 'diagram-id record)) 'STR) (/= (EL:Get 'diagram-id record) "")))
  (if (not good)
    (EL:LogEvent "DIAGRAM_ASSOCIATION_CONFLICT" (list '(reason . invalid-record-identity)
      (cons 'drawing-uuid (EL:Get 'drawing-uuid store)) (cons 'diagram-id (EL:Get 'diagram-id record)))))
  (foreach ref (EL:DiagramOutputRefs record)
    (if (setq handle (car ref))
      (progn
        (setq identity (cdr ref) e nil data nil)
        (EL:PerfCount "diagram-association-targets" 1)
        (setq reason (cond
          ((or (not (equal (type handle) 'STR)) (equal handle "")
              (not (equal (type (caddr ref)) 'STR)) (equal (caddr ref) "")) 'invalid-member-reference)
          ((member handle handles) 'duplicate-handle)
          ((member identity identities) 'duplicate-member-identity)
          ;; HANDENT can still resolve an erased entity; ENTGET decides whether
          ;; it exists. Existing rebuild/layout guards handle missing members.
          ((and (setq e (handent handle)) (setq data (entget e))
              (or (not (equal handle (cdr (assoc 5 data))))
                (not (EL:OwnedEntity handle store record (cadr ref) (caddr ref))))) 'ownership-mismatch)))
        (if reason
          (progn (setq good nil)
            (EL:LogEvent "DIAGRAM_ASSOCIATION_CONFLICT" (list (cons 'reason reason)
              (cons 'diagram-id (EL:Get 'diagram-id record)) (cons 'drawing-uuid (EL:Get 'drawing-uuid store))
              (cons 'handle handle) (cons 'kind (cadr ref)) (cons 'uid (caddr ref))
              (cons 'actual-handle (cdr (assoc 5 data))) (cons 'actual-tag (if data (EL:DiagramTag e)))))))
        (setq handles (cons handle handles) identities (cons identity identities))))) good)
(defun EL:DiagramTransform (entity / d sx sy sz normal)
  (setq d (entget entity) sx (cdr (assoc 41 d)) sy (cdr (assoc 42 d)) sz (cdr (assoc 43 d))
    normal (cdr (assoc 210 d)))
  (if (and (equal (cdr (assoc 410 d)) "Model") (numberp sx) (> sx 0.0)
      (equal sx sy 1.0e-8) (equal sx sz 1.0e-8)
      (or (not normal) (equal normal '(0.0 0.0 1.0) 1.0e-8)))
    (list (cons 'position (cdr (assoc 10 d))) (cons 'rotation (cdr (assoc 50 d))) (cons 'scale sx))))
(defun EL:Writable (entity / d layer flags)
  (if entity
    (progn (setq d (entget entity) layer (tblsearch "LAYER" (cdr (assoc 8 d))) flags (cdr (assoc 70 layer)))
      (and layer (equal (cdr (assoc 410 d)) "Model") (= 0 (logand flags 4))))))
(defun EL:RecordRows (result plan handles / out row c h)
  (foreach row (EL:Get 'rows plan)
    (setq c (EL:By 'circuit-uid (EL:Get 'circuit-uid row) (EL:Get 'circuits result))
      h (EL:By 'circuit-uid (EL:Get 'circuit-uid row) handles))
    (setq out (cons (append (list (cons 'circuit-uid (EL:Get 'circuit-uid row))
      (cons 'block-handle (EL:Get 'block-handle h)) (cons 'text-handle (EL:Get 'text-handle h))
      (cons 'position (EL:Get 'position row)) (cons 'text-position (EL:Get 'text-position row))
      (cons 'mode (EL:Get 'mode row)) (cons 'value (EL:Get 'value row)) (cons 'watts (EL:Get 'watts row)))
      (EL:NumberFormalFields c row)
      (mapcar '(lambda (key) (cons key (EL:Get key c)))
        '(seed-key id output-order is-ground ground-source ground-rule ground-evidence))) out))) (reverse out))
(defun EL:TransactionRollback (/ doc)
  (setq *EL:StoreReadCache* nil)
  (if *EL:TransactionOpen*
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (vla-EndUndoMark doc)
      ;; The single group contains INSERT/TEXT, deletes, dynamic state and XRecord.
      (if *EL:TransactionDirty* (command-s "_.UNDO" "1"))
      (EL:Require (not (dictsearch (namedobjdict) "EL_FIXED_TX")) "撤销后事务标记仍存在，未确认清理完成。")
      (setq *EL:TransactionOpen* nil *EL:Created* nil *EL:TransactionDirty* nil)))
  (setq *EL:StoreReadCache* nil)
  (redraw))
(defun EL:TransactionBody (function args / marker outcome)
  ;; An owned temporary record ensures even an early failed edit has an undo
  ;; entry. An empty failed group must never undo the user's preceding action.
  (setq marker (EL:LogCall "TX_MARKER_CREATE" nil 'entmakex (list '((0 . "XRECORD") (100 . "AcDbXrecord") (1 . "transaction")))))
  (if marker (setq *EL:TransactionDirty* T))
  (EL:Require (and marker (dictadd (namedobjdict) "EL_FIXED_TX" marker)) "无法建立事务记录。")
  (setq outcome (EL:LogCall "TX_WRITE" nil function args))
  ;; Date: 2026-10-10. NIL is failure too. Retain the marker until rollback.
  (if outcome
    (progn
      (EL:Require (dictremove (namedobjdict) "EL_FIXED_TX") "无法清理事务记录。")
      (EL:Require (entdel marker) "无法删除事务记录。"))) outcome)
(defun EL:TransactionStart (doc / state)
  ;; Date: 2026-10-09. Close an existing mark without undoing its edits.
  ;; PRINC returns its argument in native AutoLISP: failures MUST return nil.
  (setq state (getvar "UNDOCTL"))
  (EL:LogEvent "TRANSACTION_START" (list (cons 'undoctl state)
    (cons 'open *EL:TransactionOpen*) (cons 'dirty *EL:TransactionDirty*)
    (cons 'running *EL:TransactionRunning*)))
  (cond
    ((= 0 (logand 1 state))
      (princ "\nUNDO 已关闭，未写入。请执行 UNDO 的 Control/All 后重试。") nil)
    (*EL:TransactionOpen*
      (princ "\n已有插件事务正在执行，本次未写入。") nil)
    (T
      (if (/= 0 (logand 8 state)) (vla-EndUndoMark doc))
      (if (/= 0 (logand 8 (getvar "UNDOCTL")))
        (progn (princ "\n无法结束已有撤销组，本次未写入。") nil)
        (progn (EL:LogCall "UNDO_BEGIN" nil 'vla-StartUndoMark (list doc))
          (setq *EL:TransactionOpen* T *EL:Created* nil *EL:TransactionDirty* nil)
          (EL:PerfCount "transaction-starts" 1) T)))))
(defun EL:TransactionRun (doc function args / outcome)
  (if (EL:TransactionStart doc)
    (progn
      (setq outcome (EL:TransactionBody function args))
      (if outcome
        (progn
          (EL:LogCall "UNDO_END" nil 'vla-EndUndoMark (list doc))
          (setq *EL:TransactionOpen* nil *EL:TransactionDirty* nil *EL:Created* nil)
          (EL:StoreContextCommit)))
      outcome)))
(defun EL:ArchiveInterruptedTransaction (/ entry entity name index)
  ;; Date: 2026-10-09. Preserve the record and every existing drawing object.
  (if (setq entry (dictsearch (namedobjdict) "EL_FIXED_TX"))
    (progn
      (setq entity (cdr (assoc -1 entry)) index 1 name "EL_FIXED_TX_INTERRUPTED_1")
      (EL:Require (and entity (equal (cdr (assoc 0 entry)) "XRECORD")
        (equal (cdr (assoc 1 entry)) "transaction")) "事务标记格式不符，未改动，请保留图纸排查。")
      (while (dictsearch (namedobjdict) name)
        (setq index (1+ index) name (strcat "EL_FIXED_TX_INTERRUPTED_" (itoa index))))
      (EL:Require (dictrename (namedobjdict) "EL_FIXED_TX" name) "无法归档事务标记，未解除拦截。")
      (EL:Require (and (not (dictsearch (namedobjdict) "EL_FIXED_TX"))
        (equal entity (cdr (assoc -1 (dictsearch (namedobjdict) name))))) "事务标记归档回读失败，请停止生成。")
      (setq *EL:TransactionOpen* nil *EL:TransactionDirty* nil *EL:Created* nil)
      (EL:LogEvent "TRANSACTION_RECOVERED" (list (cons 'archive name)))
      T)))
(defun EL:RecoverInterruptedTransaction (/ doc *EL:TransactionRunning*)
  ;; Date: 2026-10-10. Preserve drawing edits; never UNDO a stale group.
  ;; Keep all blockers if ending the mark fails. Also covers marker-free residue.
  (setq *EL:TransactionRunning* T)
  (if (/= 0 (logand 8 (getvar "UNDOCTL")))
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (EL:LogCall "RECOVERY_UNDO_END" nil 'vla-EndUndoMark (list doc))
      (EL:Require (= 0 (logand 8 (getvar "UNDOCTL"))) "无法结束中断的撤销组，未解除事务拦截。")))
  (if (dictsearch (namedobjdict) "EL_FIXED_TX")
    (EL:ArchiveInterruptedTransaction)
    (progn
      (setq *EL:TransactionOpen* nil *EL:TransactionDirty* nil *EL:Created* nil)
      (EL:LogEvent "TRANSACTION_MEMORY_RECOVERED" nil) T)))
(defun EL:EnsureTransactionReady (/ outcome marker)
  ;; Date: 2026-10-10. Live ownership is scoped to execution, not leftover flags.
  (setq marker (dictsearch (namedobjdict) "EL_FIXED_TX"))
  (EL:LogEvent "TRANSACTION_CHECK" (list (cons 'running *EL:TransactionRunning*)
    (cons 'open *EL:TransactionOpen*) (cons 'dirty *EL:TransactionDirty*)
    (cons 'marker (if marker T nil)) (cons 'undoctl (getvar "UNDOCTL"))))
  (cond
    (*EL:TransactionRunning*
      (princ "\n已有事务正在执行，不能恢复或嵌套写入。") nil)
    ((and (not marker) (not *EL:TransactionOpen*) (not *EL:TransactionDirty*)) T)
    ((and (not marker) (not *EL:TransactionDirty*))
      ;; No transaction write occurred. Start will safely close any old mark.
      (setq *EL:TransactionOpen* nil *EL:Created* nil)
      (EL:LogEvent "TRANSACTION_MEMORY_RECOVERED" (list (cons 'empty T))) T)
    (T
      (EL:LogEvent "TRANSACTION_RECOVERY_REQUIRED" nil)
      ;; Date: 2026-10-10. Generate is the user's intent to continue. Preserve
      ;; old edits and archive our marker automatically; never ask Yes/No.
      (setq outcome (vl-catch-all-apply 'EL:RecoverInterruptedTransaction nil))
      (if (vl-catch-all-error-p outcome)
        (progn
          (EL:LogEvent "TRANSACTION_RECOVERY_FAILED" (list (cons 'message (vl-catch-all-error-message outcome))))
          (princ (strcat "\n恢复未完成：" (vl-catch-all-error-message outcome))) nil)
        (if outcome (progn (princ "\n已保留现有内容并自动清理中断状态。") T))))))
(defun c:ELRECOVER ()
  (if (EL:EnsureTransactionReady)
    (princ "\n事务检查完成，可运行 ELSTAT。"))
  (princ))
(defun EL:TransactionGuarded (function args / doc outcome rollback stack checkpoint *EL:TransactionRunning*)
  ;; Date: 2026-10-10. Hold the live guard through commit AND rollback.
  (setq *EL:TransactionRunning* T
    doc (vla-get-ActiveDocument (vlax-get-acad-object)) stack *EL:LogStack* checkpoint *EL:PerfPending*)
  (setq outcome (vl-catch-all-apply 'EL:TransactionRun (list doc function args)))
  (if (or (vl-catch-all-error-p outcome) (and (not outcome) *EL:TransactionOpen*))
    (progn
      (if *EL:StoreContextActive*
        (setq *EL:StoreContextCandidate* nil *EL:StoreContextCommitted* nil))
      ;; Date: 2026-10-13. Record the original failing stage before cleanup.
      (EL:LogEvent "TRANSACTION_ERROR" (list (cons 'message
          (if (vl-catch-all-error-p outcome) (vl-catch-all-error-message outcome) "事务写入返回空值，未完成。"))
        (cons 'stack *EL:LogStack*)))
      (EL:PerfUnwind checkpoint) (EL:PerfCount "transaction-failures" 1)
      (princ (strcat "\n系统图事务失败："
        (if (vl-catch-all-error-p outcome) (vl-catch-all-error-message outcome) "事务写入返回空值，未完成。")))
      (setq rollback (vl-catch-all-apply 'EL:TransactionRollback nil))
      (if (or (vl-catch-all-error-p rollback) *EL:TransactionOpen*)
        (progn
          (EL:LogEvent "ROLLBACK_ERROR" (list (cons 'message
            (if (vl-catch-all-error-p rollback) (vl-catch-all-error-message rollback) "撤销返回后事务仍未关闭。"))))
          (princ "\n自动撤销未完成，请停止继续生成，使用 UNDO 或恢复图纸。"))
        (princ "\n本次事务已停止；已撤销本次已记录的修改。"))
      (setq *EL:LogStack* stack) nil)
    outcome))
(defun EL:Transaction (function args)
  ;; Check the caller's guard before creating a new dynamically scoped guard.
  (EL:FreshBoundary)
  (if (EL:EnsureTransactionReady) (EL:TransactionGuarded function args)))
;; Date: 2026-10-09. CCKK captions share the managed diagram transaction.
(defun EL:CCKKLabelPlan (kind uid parent origin plan / spec)
  (setq spec (EL:CCKKCaptionDef kind))
  (list (cons 'uid uid) (cons 'kind kind) (cons 'parent-uid parent) (cons 'text (if (equal kind 'panel) (EL:PanelNumber plan) (car spec)))
    (cons 'text-position (EL:LocalPoint (list (cadr spec) (caddr spec) 0.0) origin
      (EL:Get 'rotation plan) (EL:Get 'scale plan)))))
(defun EL:CCKKLabels (plan / labels row index label)
  ;; Captions are mandatory for this box, including old plans without the marker.
  (if (and (equal (EL:Get 'panel-name plan) "ZYF_Tool_应急照明配电箱图块") (EL:Get 'rows plan))
    (progn
      (setq labels (list (EL:CCKKLabelPlan 'panel "panel-label" nil (EL:Get 'position plan) plan)))
      (setq index 0)
      (foreach row (EL:Get 'rows plan)
        (setq index (1+ index) label (EL:CCKKLabelPlan 'number
          (strcat "number/" (EL:Get 'circuit-uid row)) (EL:Get 'circuit-uid row)
          (EL:Get 'position row) plan)
          labels (append labels (list (EL:Put 'text (EL:CircuitNumberText row index) label))))
        (if (not (equal (EL:Get 'mode row) 'reserve))
          (setq labels (append labels (list (EL:CCKKLabelPlan 'purpose
            (strcat "label/" (EL:Get 'circuit-uid row)) (EL:Get 'circuit-uid row)
            (EL:Get 'position row) plan)))))))) labels)
(defun EL:CCKKLabelMatches (entity label plan / data spec)
  (setq data (entget entity) spec (EL:CCKKCaptionDef (EL:Get 'kind label)))
  (and (equal (cdr (assoc 0 data)) "TEXT") (equal (cdr (assoc 1 data)) (EL:Get 'text label))
    (equal (cdr (assoc 8 data)) (nth 3 spec)) (equal (cdr (assoc 7 data)) (nth 4 spec))
    (equal (cond ((cdr (assoc 62 data))) (T 256)) (nth 5 spec))
    (equal (cdr (assoc 40 data)) (* 350.0 (EL:Get 'scale plan)) 1.0e-6)
    (equal (cdr (assoc 41 data)) 0.7 1.0e-8) (equal (cdr (assoc 72 data)) 1)
    (equal (cond ((cdr (assoc 73 data))) (T 0)) 0)
    (equal (cond ((cdr (assoc 60 data))) (T 0)) 0)
    (equal (cond ((cdr (assoc 440 data))) (T 0)) 0)))
(defun EL:CCKKCreateLabel (label plan record store / parent row entity object data spec point)
  (setq spec (EL:CCKKCaptionDef (EL:Get 'kind label)))
  (if (equal (EL:Get 'kind label) 'panel)
    (setq parent (EL:OwnedEntity (EL:Get 'panel-output-handle record) store record "panel" "panel"))
    (progn
      (setq row (EL:By 'circuit-uid (EL:Get 'parent-uid label) (EL:Get 'rows record)))
      (setq parent (EL:OwnedEntity (EL:Get 'block-handle row) store record "circuit" (EL:Get 'parent-uid label)))))
  (EL:Require parent "箱号或用途文字缺少对应图块，停止生成。")
  (EL:Require (and (tblsearch "STYLE" (nth 4 spec)) (EL:CCKKLayer (nth 3 spec))) "箱号或用途文字的样式/图层不可用。")
  (EL:PerfCount "text-create-attempts" 1)
  (setq entity (EL:PerfWrite 'EL:CCKKText (cons parent (cons (EL:Get 'text label) (cdr spec)))))
  (EL:Require entity "CCKK 箱号或用途文字创建失败。")
  (setq object (vlax-ename->vla-object entity) *EL:Created* (cons object *EL:Created*))
  (if (not (equal (EL:Get 'scale plan) 1.0 1.0e-8))
    (progn (setq data (entget entity))
      (EL:Require (EL:PerfWrite 'entmod (list (subst (cons 40 (* 350.0 (EL:Get 'scale plan))) (assoc 40 data) data))) "文字缩放失败。")))
  (setq point (EL:CCKKPoint parent (cadr spec) (caddr spec)))
  (EL:Require (and (EL:CCKKLabelMatches entity label plan)
    (equal (EL:TextPoint entity) point 1.0e-6)) "CCKK 箱号或用途文字回读不符，停止生成。")
  (EL:LogEvent "CCKK_LABEL_CREATED" (list (cons 'uid (EL:Get 'uid label))
    (cons 'text (EL:Get 'text label)) (cons 'handle (cdr (assoc 5 (entget entity)))) (cons 'point point))) object)
;; Date: 2026-10-14. Captions are created only for the new output.
(defun EL:CreateCCKKLabels (plan record store / result label object)
  (foreach label (EL:CCKKLabels plan)
    (setq object (EL:CCKKCreateLabel label plan record store)
      label (EL:Put 'handle (EL:TagEntity object store record "text" (EL:Get 'uid label)) label)
      result (cons (EL:Put 'cckk-text-version 1 label) result)))
  (EL:Put 'cckk-labels (reverse result) record))
(defun EL:CCKK2ManagedBlock (name point definition value / entity object)
  (EL:PerfCount "block-create-attempts" 1)
  (setq entity (EL:LogCall "CCKK2_INSERT_BLOCK" (list (cons 'name name) (cons 'point point) (cons 'value value))
      'EL:PerfCall (list (if point "NATIVE_INSERT" "PLACEMENT_INPUT")
        'EL:PerfWrite (list 'EL:CCKK2Insert (list name (if point (trans point 0 1))))))
    object (vlax-ename->vla-object entity)
    *EL:Created* (cons object *EL:Created*))
  (EL:DynamicUpdate entity (EL:Get 'property definition) value) object)
(defun EL:CCKK2CreateBody (result template capacity plan record store / *EL:CCKK2Panel* transform)
  (princ "\nCCKK2：移动鼠标预览配电箱，左键放置后按实际功率生成回路，Esc 取消。")
  (setq *EL:CCKK2Panel* (EL:CCKK2ManagedBlock (EL:Get 'panel-name plan) nil
    (EL:Get 'panel template) (EL:Get 'panel-value plan))
    transform (EL:DiagramTransform (vlax-vla-object->ename *EL:CCKK2Panel*)))
  (EL:Require transform "当前坐标系不支持受管系统图，请切换到世界坐标系后重试。")
  (setq plan (EL:FixedPlan result template capacity (EL:Get 'position transform)
    (EL:Get 'rotation transform) (EL:Get 'scale transform)))
  (EL:Require plan "CCKK2 实际回路计划无效。")
  (EL:CreateDiagram result template capacity plan record store))
(defun EL:CCKK2CreateDiagram (result template capacity plan record store / saved item outcome *EL:CCKK2Created*)
  ;; Restore command settings on success, native Esc, and all build failures.
  ;; The enclosing managed transaction rolls back objects and the DWG record.
  (foreach item '("CMDECHO" "ATTREQ" "DRAGMODE" "CLAYER")
    (setq saved (cons (cons item (getvar item)) saved)))
  (setq outcome (EL:MeasuredCatch 'EL:LogCall
    (list "CCKK2_CREATE" nil 'EL:CCKK2CreateConfigured
      (list result template capacity plan record store))))
  (foreach item saved (setvar (car item) (cdr item)))
  (if (vl-catch-all-error-p outcome)
    (progn
      (EL:LogEvent "CCKK2_INSERT_ERROR" (list (cons 'message (vl-catch-all-error-message outcome))))
      (princ (strcat "\nCCKK2 插入停止：" (vl-catch-all-error-message outcome))) (exit)))
  (EL:Require (and (listp outcome) (EL:Get 'panel-output-handle outcome))
    "GENERATION_EMPTY_RESULT：生成未返回完整记录，已停止并回滚；请查看 CCKK2_CREATE 阶段。") outcome)
(defun EL:CCKK2CreateConfigured (result template capacity plan record store)
  (EL:Require (EL:CCKKLayer (EL:Get 'layer template)) "CCKK2 输出图层不可用。")
  (setvar "CMDECHO" 0) (setvar "ATTREQ" 0) (setvar "DRAGMODE" 2)
  (setvar "CLAYER" (EL:Get 'layer template))
  (EL:CCKK2CreateBody result template capacity plan record store))
(defun EL:CreatePowerAnnotation (space row plan layer block / entity object data)
  ;; Date: 2026-10-10. Fixed CCKK power uses the same native TEXT constructor
  ;; as the original plugin, without the separate ActiveX formatting chain.
  (if (not (EL:Get 'cckk-layout plan))
    (EL:CreateAnnotation space row plan layer)
    (progn
      (EL:Require (and block (EL:Get 'text row) (tblsearch "STYLE" "_TEL_DIM")
        (EL:CCKKLayer "TEL_TEXT")) "功率文字缺少回路图块、样式或可用图层。")
      (EL:PerfCount "text-create-attempts" 1)
      (setq entity (EL:LogCall "CCKK_POWER_TEXT" (list (cons 'uid (EL:Get 'circuit-uid row))
          (cons 'text (EL:Get 'text row)) (cons 'block (cdr (assoc 5 (entget block)))))
        'EL:PerfWrite (list 'EL:CCKKText (list block (EL:Get 'text row) 10983.0 -450.0 "TEL_TEXT" "_TEL_DIM" 256))))
      (EL:Require entity "CCKK 功率文字创建失败。")
      (setq object (vlax-ename->vla-object entity) *EL:Created* (cons object *EL:Created*))
      (if (not (equal (EL:Get 'scale plan) 1.0 1.0e-8))
        (progn (setq data (entget entity))
          (EL:Require (EL:PerfWrite 'entmod (list (subst (cons 40 (* 350.0 (EL:Get 'scale plan))) (assoc 40 data) data)))
            "功率文字缩放失败。")))
      (setq data (entget entity))
      (EL:Require (and (equal (cdr (assoc 0 data)) "TEXT")
        (equal (cdr (assoc 1 data)) (EL:Get 'text row))
        (equal (cdr (assoc 8 data)) "TEL_TEXT") (equal (cdr (assoc 7 data)) "_TEL_DIM")
        (equal (cdr (assoc 40 data)) (* 350.0 (EL:Get 'scale plan)) 1.0e-6)
        (equal (cdr (assoc 41 data)) 0.7 1.0e-8) (equal (cdr (assoc 72 data)) 1)
        (equal (cdr (assoc 73 data)) 0) (equal (EL:TextPoint entity) (EL:CCKKPoint block 10983.0 -450.0) 1.0e-6))
        "CCKK 功率文字回读不符，停止生成。") object)))
(defun EL:CreateDiagram (result template capacity plan record store / doc space layer object handles row h)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)) space (vla-get-ModelSpace doc) layer (EL:Get 'layer template))
  (if (not (tblsearch "LAYER" layer)) (vla-Add (vla-get-Layers doc) layer))
  (setq object (if *EL:CCKK2Panel* *EL:CCKK2Panel*
    (EL:CreateBlock space (EL:Get 'panel-name plan) (EL:Get 'position plan)
      (EL:Get 'scale plan) (EL:Get 'rotation plan) (EL:Get 'property (EL:Get 'panel template)) (EL:Get 'panel-value plan) layer)))
  ;; Date: 2026-10-15. The output handle gives every placement an identity
  ;; without rewriting the saved input record or reusing a previous output id.
  (if *EL:PlacementOnly*
    (setq record (EL:Put 'diagram-id (strcat (EL:Get 'diagram-id record)
      "/output/" (cdr (assoc 5 (entget (vlax-vla-object->ename object))))) record)))
  (setq record (EL:Put 'panel-output-handle (EL:TagEntity object store record "panel" "panel") record))
  (if *EL:CCKK2Panel*
    (progn
      ;; Date: 2026-10-14. Native placement can run callbacks. Check the
      ;; template and number now; the full contact/source check runs before
      ;; the verified DWG write without forcing a whole-drawing regeneration.
      (EL:FreshBoundary)
      (EL:Require (EL:TemplateRuntimeValid template (EL:Get 'config record))
        "TEMPLATE_CHANGED：放置期间模板变化，已停止生成。")
      (EL:Require (EL:NumberInputsCurrent result)
        "SOURCE_NUMBER_CHANGED：放置期间平面编号变化，已停止生成。")
      (if *EL:PlacementOnly*
        (progn
          (EL:Require (EL:DLSubmissionCurrent result)
            "设备库在放置期间变化，请核对后重试。")
          (EL:Require (EL:FreshResult result (EL:Get 'config record))
            "SOURCE_CHANGED：放置期间源图变化，已停止生成。")))))
  (foreach row (EL:Get 'rows plan)
    (EL:LogEvent "CCKK_ROW_BEGIN" (list (cons 'uid (EL:Get 'circuit-uid row))
      (cons 'mode (EL:Get 'mode row)) (cons 'watts (EL:Get 'watts row)) (cons 'position (EL:Get 'position row))))
    (setq object (if *EL:CCKK2Panel*
      (EL:CCKK2ManagedBlock (EL:Get 'name (EL:Get 'circuit template)) (EL:Get 'position row)
        (EL:Get 'circuit template) (EL:Get 'value row))
      (EL:CreateBlock space (EL:Get 'name (EL:Get 'circuit template)) (EL:Get 'position row)
        (EL:Get 'scale plan) (EL:Get 'rotation plan) (EL:Get 'property (EL:Get 'circuit template)) (EL:Get 'value row) layer))
      h (list (cons 'circuit-uid (EL:Get 'circuit-uid row))
        (cons 'block-handle (EL:TagEntity object store record "circuit" (EL:Get 'circuit-uid row)))))
    (if (EL:Get 'text row)
      (setq h (EL:Put 'text-handle (EL:TagEntity (EL:CreatePowerAnnotation space row plan layer
          (vlax-vla-object->ename object))
        store record "text" (EL:Get 'circuit-uid row)) h)))
    (setq handles (cons h handles))
    (EL:LogEvent "CCKK_ROW_CREATED" h))
  (setq record (EL:Put 'rows (EL:RecordRows result plan handles) (EL:Put 'plan plan record)))
  (setq record (EL:CreateCCKKLabels plan record store))
  (EL:PerfMark "graphics-complete")
  (if (not *EL:PlacementOnly*)
    (progn
      ;; Legacy callers retain their persistent output record. The current
      ;; panel finishes after creation and the enclosing undo group closes.
      (if *EL:NativePreview*
        (EL:Require (EL:FreshResult result (EL:Get 'config record)) "SOURCE_CHANGED：预览后源图变化。"))
      (EL:Require (EL:NumberInputsCurrent result) "SOURCE_NUMBER_CHANGED：生成期间平面编号变化，已停止本次生成。")
      (EL:Require (equal T (EL:LogCall "SAVE_CREATED_DIAGRAM" nil 'EL:StoreWrite
        (list (EL:StorePutDiagram record store))))
        "系统图记录保存失败，已停止生成并回滚。"))) record)
