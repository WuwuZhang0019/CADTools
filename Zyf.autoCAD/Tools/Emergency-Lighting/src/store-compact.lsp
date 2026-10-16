;; Date: 2026-10-11. Lossless V2 storage envelope; logical V1 records stay exact.
;; Native StoreEncode still owns REAL/INT and the 32-character DXF segments.
(defun EL:CompactRequire (condition reason)
  (if (not condition)
    (progn
      (EL:LogEvent "STORE_COMPACT_ERROR" (list (cons 'reason reason)))
      (EL:StoreParseRequire nil))) condition)
(defun EL:CompactProperList (value)
  ;; Date: 2026-10-14. Native traversal also distinguishes dotted tails.
  (and (listp value) (numberp (vl-list-length value))))
(defun EL:CompactIndex (value items / index found)
  (setq index 0)
  (while (and items (not found))
    (if (equal value (car items)) (setq found (list index)))
    (setq index (1+ index) items (cdr items)))
  (if found (car found)))
(defun EL:CompactTemplateAdd (value)
  (if value
    (progn
      (EL:CompactRequire (and (listp value) (EL:CompactProperList value)) 'template-shape)
      (if (not (member value *EL:CompactTemplates*))
        (setq *EL:CompactTemplates* (append *EL:CompactTemplates* (list value)))))))
(defun EL:CompactTemplates (store / *EL:CompactTemplates* record direct configured)
  ;; Historical global templates may differ. Copies belonging to one record
  ;; must agree; never resolve an ambiguity by overwriting a supplied copy.
  (EL:CompactTemplateAdd (EL:Get 'fixed-template store))
  (foreach record (EL:Get 'diagrams store)
    (setq direct (EL:Get 'template record)
      configured (EL:Get 'template (EL:Get 'config record)))
    (EL:CompactRequire (or (not direct) (not configured) (equal direct configured)) 'template-copy-conflict)
    (EL:CompactTemplateAdd direct) (EL:CompactTemplateAdd configured))
  *EL:CompactTemplates*)
(defun EL:CompactAtom (value / kind key bucket candidates found index)
  ;; Bucket keys accelerate lookup only. Full EQUAL decides every identity.
  (setq kind (type value)
    key (if (equal kind 'SYM) (list kind value)
      (list kind (strlen value) (substr value 1 1) (substr value (max 1 (strlen value)) 1)))
    bucket (assoc key *EL:CompactBuckets*) candidates (cdr bucket)
    found (assoc value candidates))
  (if found (cdr found)
    (progn
      (setq index *EL:CompactAtomCount* *EL:CompactAtomCount* (1+ index)
        *EL:CompactAtoms* (cons value *EL:CompactAtoms*)
        *EL:CompactBuckets* (EL:Put key (cons (cons value index) candidates) *EL:CompactBuckets*))
      index)))
(defun EL:CompactEmit (value)
  (setq *EL:CompactTokens* (cons value *EL:CompactTokens*)))
(defun EL:CompactEncode (value / kind index item count)
  (setq kind (type value))
  (cond
    ((not value) (EL:CompactEmit 0))
    ((equal value T) (EL:CompactEmit 1))
    ((equal kind 'INT) (EL:CompactEmit 2) (EL:CompactEmit value))
    ((equal kind 'REAL) (EL:CompactEmit value))
    ((member kind '(STR SYM)) (EL:CompactEmit (- -1 (EL:CompactAtom value))))
    ((and *EL:CompactTemplates* (listp value) (member (car value) '(template fixed-template))
        (setq index (EL:CompactIndex (cdr value) *EL:CompactTemplates*)))
      ;; An alist entry with a list value is a proper list in AutoLISP.
      ;; Encode its CDR as a template reference, rather than visiting every
      ;; element of the copy as if it were an independent payload list.
      (EL:CompactEmit 3) (EL:CompactEncode (car value))
      (EL:CompactEmit 4) (EL:CompactEmit index))
    ((listp value)
      (setq index (if *EL:CompactTemplates* (EL:CompactIndex value *EL:CompactTemplates*)))
      (cond
        (index (EL:CompactEmit 4) (EL:CompactEmit index))
        ((setq count (vl-list-length value))
          (EL:CompactEmit (+ 8 count))
          (foreach item value (EL:CompactEncode item)))
        (T (EL:CompactEmit 3) (EL:CompactEncode (car value)) (EL:CompactEncode (cdr value)))))
    (T (EL:CompactRequire nil 'unsupported-value))))
(defun EL:StoreCompact (store / *EL:CompactTemplates* *EL:CompactAtoms* *EL:CompactBuckets*
    *EL:CompactAtomCount* *EL:CompactTokens*)
  (setq *EL:CompactTemplates* (EL:CompactTemplates store) *EL:CompactAtomCount* 0)
  (EL:CompactEncode store)
  (list '(format-version . 2) '(codec . EL_COMPACT_V1)
    (cons 'templates *EL:CompactTemplates*) (cons 'atoms (reverse *EL:CompactAtoms*))
    (cons 'body (reverse *EL:CompactTokens*))))
(defun EL:CompactTake (/ value)
  (if (not *EL:CompactRemaining*) (EL:CompactRequire nil 'truncated-body))
  (setq value (car *EL:CompactRemaining*) *EL:CompactRemaining* (cdr *EL:CompactRemaining*)
    *EL:CompactRemainingCount* (1- *EL:CompactRemainingCount*)) value)
;; Date: 2026-10-13. Pack only integer tape tokens. REALs remain native DXF doubles.
(defun EL:CompactIntegerRun (text run)
  ;; Native strings cost two delimiters plus their 32-character DXF pieces.
  (if (> (length run) (+ 2 (fix (/ (+ (strlen text) 31) 32)))) (list text) (reverse run)))
(defun EL:CompactPackIntegers (body / chunks text token item run)
  (setq text "")
  (foreach item body
    (cond
      ((equal (type item) 'INT)
        (setq token (itoa item))
        (if (> (+ (strlen text) (strlen token) 1) 224)
          (progn (foreach token (EL:CompactIntegerRun text run) (setq chunks (cons token chunks)))
            (setq text "" run nil token (itoa item))))
        (setq text (strcat text token " ") run (cons item run)))
      ((equal (type item) 'REAL)
        (if run (progn (foreach token (EL:CompactIntegerRun text run) (setq chunks (cons token chunks)))
          (setq text "" run nil)))
        (setq chunks (cons item chunks)))
      (T (EL:CompactRequire nil 'invalid-tape-token))))
  (if run (foreach token (EL:CompactIntegerRun text run) (setq chunks (cons token chunks)))) (reverse chunks))
(defun EL:CompactReadIntegerChunk (chunk / size wrapped values)
  ;; Date: 2026-10-14. READ sees only a bounded integer alphabet, enclosed
  ;; in our own parentheses. Source strings and native REAL fields never
  ;; use this path; a malformed numeric token cannot be evaluated.
  ;; Full canonical text and INT/range checks reject partial/ambiguous input.
  (setq size (strlen chunk))
  (EL:CompactRequire (and (> size 1) (<= size 224)
    (equal (substr chunk size 1) " ")) 'integer-chunk-size)
  (EL:CompactRequire (equal (vl-string-trim " -0123456789" chunk) "") 'integer-chunk-characters)
  (setq wrapped (strcat "(" (substr chunk 1 (1- size)) ")")
    values (vl-catch-all-apply 'read (list wrapped)))
  (EL:CompactRequire (and (not (vl-catch-all-error-p values)) values
    (listp values) (EL:CompactProperList values)
    (vl-every '(lambda (item) (and (equal (type item) 'INT)
      (<= -2147483648 item) (<= item 2147483647))) values)
    (equal wrapped (vl-prin1-to-string values))) 'integer-chunk-value)
  values)
(defun EL:CompactUnpackIntegers (chunks / body chunk value)
  ;; Date: 2026-10-14. Native parsing replaces per-integer SEARCH/SUBSTR/
  ;; ATOI/ITOA. The native numeric payload and wire format stay unchanged.
  (foreach chunk chunks
    (cond
      ((member (type chunk) '(INT REAL)) (setq body (cons chunk body)))
      ((equal (type chunk) 'STR)
        (foreach value (EL:CompactReadIntegerChunk chunk) (setq body (cons value body))))
      (T (EL:CompactRequire nil 'integer-chunk-type)))) (reverse body))
(defun EL:CompactPoolPages (values / pages page count)
  ;; Date: 2026-10-11. Linear construction, then two bounded NTH traversals
  ;; replace walking a large atom/template pool from its head for every ref.
  ;; Pure lists preserve symbols, strings and whole template values exactly.
  (while values
    (setq page nil count 0)
    (while (and values (< count 32))
      (setq page (cons (car values) page) values (cdr values) count (1+ count)))
    (setq pages (cons (reverse page) pages))) (reverse pages))
(defun EL:CompactPoolAt (index pages)
  (nth (fix (rem index 32)) (nth (/ index 32) pages)))
(defun EL:CompactPoolLength (value / count)
  ;; Date: 2026-10-14. Validate and count in a single native traversal.
  (if (not (and (listp value) (setq count (vl-list-length value))))
    (EL:CompactRequire nil 'pool-shape)) count)
(defun EL:CompactDecode (/ token kind index count rows item tail)
  ;; Date: 2026-10-14. This hot path visits every logical value. Inline
  ;; token consumption; error diagnostics and bounds stay unchanged.
  (if (not *EL:CompactRemaining*) (EL:CompactRequire nil 'truncated-body))
  (setq token (car *EL:CompactRemaining*) *EL:CompactRemaining* (cdr *EL:CompactRemaining*)
    *EL:CompactRemainingCount* (1- *EL:CompactRemainingCount*) kind (type token))
  (cond
    ((equal kind 'REAL) token)
    ((not (equal kind 'INT)) (EL:CompactRequire nil 'invalid-token))
    ((< token 0)
      (setq index (- -1 token))
      (if (>= index *EL:CompactReadAtomCount*) (EL:CompactRequire nil 'atom-reference))
      (if *EL:CompactReadAtomPages*
        (nth (fix (rem index 32)) (nth (/ index 32) *EL:CompactReadAtomPages*))
        (nth index *EL:CompactReadAtoms*)))
    ((= token 0) nil)
    ((= token 1) T)
    ((= token 2)
      (setq item (EL:CompactTake))
      (if (not (equal (type item) 'INT)) (EL:CompactRequire nil 'integer-value)) item)
    ((= token 3)
      (setq item (EL:CompactDecode) tail (EL:CompactDecode))
      (if (not tail) (EL:CompactRequire nil 'dotted-tail))
      (cons item tail))
    ((= token 4)
      (setq index (EL:CompactTake))
      (if (not (and (equal (type index) 'INT) (>= index 0)
          (< index *EL:CompactReadTemplateCount*))) (EL:CompactRequire nil 'template-reference))
      (if *EL:CompactReadTemplatePages* (EL:CompactPoolAt index *EL:CompactReadTemplatePages*)
        (nth index *EL:CompactReadTemplates*)))
    ((> token 8)
      (setq count (- token 8))
      (if (> count *EL:CompactRemainingCount*) (EL:CompactRequire nil 'list-length))
      (repeat count
        ;; Coordinates are already native doubles, requiring no tag/ref
        ;; expansion. Keep the exact value, including tiny REALs and 0.0.
        (if (equal (type (car *EL:CompactRemaining*)) 'REAL)
          (setq rows (cons (car *EL:CompactRemaining*) rows)
            *EL:CompactRemaining* (cdr *EL:CompactRemaining*)
            *EL:CompactRemainingCount* (1- *EL:CompactRemainingCount*))
          (setq rows (cons (EL:CompactDecode) rows)))) (reverse rows))
    (T (EL:CompactRequire nil 'invalid-tag))))
(defun EL:StoreExpand (packed / *EL:CompactRemaining* *EL:CompactReadTemplates*
    *EL:CompactReadAtoms* *EL:CompactRemainingCount* *EL:CompactReadAtomCount*
    *EL:CompactReadTemplateCount* *EL:CompactReadAtomPages* *EL:CompactReadTemplatePages* row keys value)
  (EL:CompactRequire (and (listp packed) (EL:CompactProperList packed) (= (length packed) 5)) 'envelope-shape)
  (foreach row packed
    (EL:CompactRequire (and row (listp row)
      (member (car row) '(format-version codec templates atoms body))
      (not (member (car row) keys))) 'envelope-field)
    (setq keys (cons (car row) keys)))
  (EL:CompactRequire (and (equal (EL:Get 'format-version packed) 2)
    (member (EL:Get 'codec packed) '(EL_COMPACT_V1 EL_COMPACT_V2))) 'unsupported-format)
  (setq *EL:CompactRemaining* (if (equal (EL:Get 'codec packed) 'EL_COMPACT_V2)
      (EL:PerfCall "STORE_UNPACK_INTS" 'EL:CompactUnpackIntegers (list (EL:Get 'body packed)))
      (EL:Get 'body packed))
    *EL:CompactReadTemplates* (EL:Get 'templates packed)
    *EL:CompactReadAtoms* (EL:Get 'atoms packed))
  ;; Bound references and list lengths with constant-time counters. Calling
  ;; LENGTH on the remaining long tape for every row is quadratic in CAD.
  (setq *EL:CompactRemainingCount* (EL:CompactPoolLength *EL:CompactRemaining*)
    *EL:CompactReadAtomCount* (EL:CompactPoolLength *EL:CompactReadAtoms*)
    *EL:CompactReadTemplateCount* (EL:CompactPoolLength *EL:CompactReadTemplates*))
  (foreach value *EL:CompactReadAtoms*
    (if (not (member (type value) '(STR SYM))) (EL:CompactRequire nil 'atom-type)))
  (foreach value *EL:CompactReadTemplates*
    (EL:CompactRequire (and value (listp value) (EL:CompactProperList value)) 'template-shape))
  ;; Small pools already have bounded lookups; do not build an extra index.
  (if (> *EL:CompactReadAtomCount* 32)
    (setq *EL:CompactReadAtomPages* (EL:CompactPoolPages *EL:CompactReadAtoms*)))
  (if (> *EL:CompactReadTemplateCount* 32)
    (setq *EL:CompactReadTemplatePages* (EL:CompactPoolPages *EL:CompactReadTemplates*)))
  (setq value (EL:PerfCall "STORE_VALUE_DECODE" 'EL:CompactDecode nil))
  (EL:CompactRequire (not *EL:CompactRemaining*) 'trailing-body)
  (EL:CompactRequire (and (listp value) (EL:CompactProperList value)) 'logical-store-shape)
  ;; Recheck logical copy agreement after expanding references as well.
  (EL:CompactTemplates value) value)
