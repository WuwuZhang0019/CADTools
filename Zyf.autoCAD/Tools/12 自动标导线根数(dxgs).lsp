;;; dxgs.lsp
;;; CAD wire count annotation command based on topology analysis.
;;; Command: DXGS
;;; Encoding: UTF-8

(vl-load-com)

;;; ------------------------------------------------------------------------
;;; Global configuration
;;; ------------------------------------------------------------------------

(if (not (boundp '*DXGS-CONFIG*))
  (setq *DXGS-CONFIG* nil)
)
(if (not (boundp '*DXGS-CONNECT-TOL*))
  (setq *DXGS-CONNECT-TOL* 5.0)
)
(if (not (boundp '*DXGS-MERGE-GAP*))
  (setq *DXGS-MERGE-GAP* 400.0)
)
(if (not (boundp '*DXGS-ANGLE-TOL*))
  (setq *DXGS-ANGLE-TOL* (/ pi 180.0))
)
(if (not (boundp '*DXGS-CLEAN-RADIUS*))
  (setq *DXGS-CLEAN-RADIUS* 200.0)
)
(if (not (boundp '*DXGS-LABEL-OFFSET*))
  (setq *DXGS-LABEL-OFFSET* 150.0)
)
(if (not (boundp '*DXGS-TEXT-HEIGHT*))
  (setq *DXGS-TEXT-HEIGHT* 250.0)
)
(if (not (boundp '*DXGS-USE-BDXS*))
  (setq *DXGS-USE-BDXS* T)
)
(if (not (boundp '*DXGS-BDXS-COMMAND*))
  (setq *DXGS-BDXS-COMMAND* "BDXS")
)

;;; ------------------------------------------------------------------------
;;; Small utilities
;;; ------------------------------------------------------------------------

(defun dxgs:get (alist key)
  (cdr (assoc key alist))
)

(defun dxgs:set (alist key value / old)
  (setq old (assoc key alist))
  (if old
    (subst (cons key value) old alist)
    (append alist (list (cons key value)))
  )
)

(defun dxgs:add-unique (lst item)
  (if (member item lst)
    lst
    (append lst (list item))
  )
)

(defun dxgs:member-ci (item lst / hit x)
  (setq hit nil)
  (if item
    (foreach x lst
      (if (and x (= (strcase item) (strcase x)))
        (setq hit T)
      )
    )
  )
  hit
)

(defun dxgs:add-unique-ci (lst item)
  (if (or (null item) (= item "") (dxgs:member-ci item lst))
    lst
    (append lst (list item))
  )
)

(defun dxgs:same-handle-p (a b)
  (and a b (= (strcase a) (strcase b)))
)

(defun dxgs:string-prefix-p (prefix s)
  (and s
       (<= (strlen prefix) (strlen s))
       (= (strcase prefix) (strcase (substr s 1 (strlen prefix)))))
)

(defun dxgs:trim (s)
  (vl-string-trim " \t\r\n" s)
)

(defun dxgs:split-comma (s / pos out token)
  (setq out nil)
  (while (setq pos (vl-string-search "," s))
    (setq token (substr s 1 pos))
    (setq out (append out (list (dxgs:trim token))))
    (setq s (substr s (+ pos 2)))
  )
  (if (> (strlen (dxgs:trim s)) 0)
    (setq out (append out (list (dxgs:trim s))))
  )
  out
)

(defun dxgs:layer-match-p (layer pattern-string / ok pat)
  (setq ok nil)
  (foreach pat (dxgs:split-comma pattern-string)
    (if (and (> (strlen pat) 0)
             (wcmatch (strcase layer) (strcase pat)))
      (setq ok T)
    )
  )
  ok
)

(defun dxgs:abort (msg)
  (princ (strcat "\n[DXGS] " msg))
  (quit)
)

(defun dxgs:ss->enames (ss / idx out)
  (setq idx 0
        out nil)
  (while (and ss (< idx (sslength ss)))
    (setq out (cons (ssname ss idx) out)
          idx (1+ idx))
  )
  (reverse out)
)

;;; ------------------------------------------------------------------------
;;; Drawing configuration
;;; ------------------------------------------------------------------------

(defun dxgs:entity-type (ename)
  (cdr (assoc 0 (entget ename)))
)

(defun dxgs:entity-layer (ename)
  (cdr (assoc 8 (entget ename)))
)

(defun dxgs:entity-handle (ename)
  (cdr (assoc 5 (entget ename)))
)

(defun dxgs:insert-block-name (ename / obj value)
  (setq obj (vlax-ename->vla-object ename))
  (if (vlax-property-available-p obj 'EffectiveName)
    (progn
      (setq value
        (vl-catch-all-apply
          '(lambda () (vla-get-EffectiveName obj))
          nil))
      (if (vl-catch-all-error-p value)
        (vla-get-Name obj)
        value
      )
    )
    (vla-get-Name obj)
  )
)

(defun dxgs:config-chunks (s size / out pos total)
  (setq out nil
        pos 1
        total (strlen s))
  (while (<= pos total)
    (setq out (append out (list (substr s pos size))))
    (setq pos (+ pos size))
  )
  out
)

(defun dxgs:config-pack-string (record / out pair)
  (setq out "")
  (foreach pair record
    (if (= (car pair) 1)
      (setq out (strcat out (cdr pair)))
    )
  )
  out
)

(defun dxgs:config-load (/ record raw parsed)
  (setq record (dictsearch (namedobjdict) "DXGS_CONFIG"))
  (if record
    (progn
      (setq raw (dxgs:config-pack-string record))
      (setq parsed (vl-catch-all-apply 'read (list raw)))
      (if (vl-catch-all-error-p parsed)
        nil
        (dxgs:normalize-config parsed)
      )
    )
    nil
  )
)

(defun dxgs:config-save (cfg / nod old xrec chunks data)
  (setq nod (namedobjdict)
        old (dictsearch nod "DXGS_CONFIG")
        chunks (dxgs:config-chunks (vl-prin1-to-string cfg) 240)
        data (append
               (list (cons 0 "XRECORD")
                     (cons 100 "AcDbXrecord"))
               (mapcar '(lambda (chunk) (cons 1 chunk)) chunks)))
  (if old
    (dictremove nod "DXGS_CONFIG")
  )
  (setq xrec (entmakex data))
  (if xrec
    (dictadd nod "DXGS_CONFIG" xrec)
  )
  cfg
)

(defun dxgs:config-label-layer ()
  (if (and *DXGS-CONFIG*
           (dxgs:get *DXGS-CONFIG* "label_layer")
           (> (strlen (dxgs:get *DXGS-CONFIG* "label_layer")) 0))
    (dxgs:get *DXGS-CONFIG* "label_layer")
    (getvar "CLAYER")
  )
)

(defun dxgs:config-valid-p (cfg)
  (and cfg
       (dxgs:get cfg "wire_layers")
       (dxgs:get cfg "lamp_blocks")
       (dxgs:get cfg "lamp_layers")
       (dxgs:get cfg "switch_types")
       (dxgs:get cfg "label_layer"))
)

(defun dxgs:collect-insert-signature (ss / blocks layers en)
  (setq blocks nil
        layers nil)
  (foreach en (dxgs:ss->enames ss)
    (if (= (dxgs:entity-type en) "INSERT")
      (progn
        (setq blocks (dxgs:add-unique-ci blocks (dxgs:insert-block-name en)))
        (setq layers (dxgs:add-unique-ci layers (dxgs:entity-layer en)))
      )
    )
  )
  (list (cons "blocks" blocks)
        (cons "layers" layers))
)

(defun dxgs:collect-wire-signature (ss / layers types en typ)
  (setq layers nil
        types nil)
  (foreach en (dxgs:ss->enames ss)
    (setq typ (dxgs:entity-type en))
    (if (member typ '("LINE" "LWPOLYLINE" "POLYLINE"))
      (progn
        (setq layers (dxgs:add-unique-ci layers (dxgs:entity-layer en)))
        (setq types (dxgs:add-unique-ci types typ))
      )
    )
  )
  (list (cons "layers" layers)
        (cons "types" types))
)

(defun dxgs:default-switch-catalog ()
  (list
    (list (cons "name" "单联单控")
          (cons "control_count" 1)
          (cons "control_wire_count" 1)
          (cons "kind" "SINGLE"))
    (list (cons "name" "双联单控")
          (cons "control_count" 2)
          (cons "control_wire_count" 2)
          (cons "kind" "SINGLE"))
    (list (cons "name" "三联单控")
          (cons "control_count" 3)
          (cons "control_wire_count" 3)
          (cons "kind" "SINGLE"))
    (list (cons "name" "四联单控")
          (cons "control_count" 4)
          (cons "control_wire_count" 4)
          (cons "kind" "SINGLE"))
    (list (cons "name" "单联双控")
          (cons "control_count" 1)
          (cons "control_wire_count" 2)
          (cons "kind" "DOUBLE"))
  )
)

(defun dxgs:switch-type-by-name (switches name / found st)
  (setq found nil)
  (foreach st switches
    (if (= (strcase (dxgs:get st "name")) (strcase name))
      (setq found st)
    )
  )
  found
)

(defun dxgs:switch-control-wire-count (st)
  (cond
    ((dxgs:get st "control_wire_count") (dxgs:get st "control_wire_count"))
    ((= (dxgs:get st "kind") "DOUBLE") 2)
    (t 1)
  )
)

(defun dxgs:normalize-switch-type (st / spec)
  (setq spec (dxgs:switch-type-by-name (dxgs:default-switch-catalog) (dxgs:get st "name")))
  (if spec
    (list (cons "name" (dxgs:get spec "name"))
          (cons "control_count" (dxgs:get spec "control_count"))
          (cons "control_wire_count" (dxgs:get spec "control_wire_count"))
          (cons "kind" (dxgs:get spec "kind"))
          (cons "blocks" (dxgs:get st "blocks"))
          (cons "layers" (dxgs:get st "layers")))
    nil
  )
)

(defun dxgs:normalize-switch-types (switches / out item)
  (setq out nil)
  (foreach item switches
    (setq item (dxgs:normalize-switch-type item))
    (if (and item (dxgs:get item "blocks") (dxgs:get item "layers"))
      (setq out (dxgs:replace-switch-type out item))
    )
  )
  out
)

(defun dxgs:normalize-config (cfg / switches)
  (if cfg
    (progn
      (setq switches (dxgs:normalize-switch-types (dxgs:get cfg "switch_types")))
      (dxgs:set cfg "switch_types" switches)
    )
    nil
  )
)

(defun dxgs:replace-switch-type (switches item / out st replaced name)
  (setq out nil
        replaced nil
        name (dxgs:get item "name"))
  (foreach st switches
    (if (= (strcase (dxgs:get st "name")) (strcase name))
      (progn
        (setq out (append out (list item)))
        (setq replaced T))
      (setq out (append out (list st)))
    )
  )
  (if replaced
    out
    (append out (list item))
  )
)

(defun dxgs:setup-one-switch-type (spec old / name count wire-count kind ss sig item)
  (setq name (dxgs:get spec "name")
        count (dxgs:get spec "control_count")
        wire-count (dxgs:get spec "control_wire_count")
        kind (dxgs:get spec "kind"))
  (if old
    (princ
      (strcat
        "\n[DXGS] 已配置 [" name "]，回车保留；重新选择将覆盖该类型。"
        "\n        当前块名: " (vl-princ-to-string (dxgs:get old "blocks"))
        "，图层: " (vl-princ-to-string (dxgs:get old "layers"))))
    (princ (strcat "\n[DXGS] 请选择 [" name "] 开关图例块；没有则直接回车跳过。"))
  )
  (setq ss (ssget '((0 . "INSERT"))))
  (if ss
    (progn
      (setq sig (dxgs:collect-insert-signature ss))
      (if (and (dxgs:get sig "blocks") (dxgs:get sig "layers"))
        (progn
          (setq item
            (list (cons "name" name)
                  (cons "control_count" count)
                  (cons "control_wire_count" wire-count)
                  (cons "kind" kind)
                  (cons "blocks" (dxgs:get sig "blocks"))
                  (cons "layers" (dxgs:get sig "layers"))))
          (princ (strcat "\n[DXGS] 已记录 [" name "]。"))
          item)
        (progn
          (princ (strcat "\n[DXGS] 未从 [" name "] 选择集中读取到有效开关图块。"))
          old)
      )
    )
    (progn
      (if old
        (princ (strcat "\n[DXGS] 保留 [" name "] 原配置。"))
        (princ (strcat "\n[DXGS] 跳过 [" name "]。"))
      )
      old)
  )
)

(defun dxgs:setup-switch-types (existing / catalog out spec old item)
  (setq catalog (dxgs:default-switch-catalog)
        out nil)
  (foreach spec catalog
    (setq old (dxgs:switch-type-by-name existing (dxgs:get spec "name")))
    (setq item (dxgs:setup-one-switch-type spec old))
    (if item
      (setq out (dxgs:replace-switch-type out item))
    )
  )
  (if out
    out
    (dxgs:abort "未配置任何开关图例，配置中止。")
  )
)

(defun dxgs:prompt-label-layer (existing / picked value fallback)
  (setq fallback
    (if (and existing (> (strlen existing) 0))
      existing
      (getvar "CLAYER")
    ))
  (setq picked
    (entsel
      (strcat
        "\n选择一个实体作为自动标注输出图层，或回车输入/保留 ["
        fallback "]: ")))
  (if picked
    (dxgs:entity-layer (car picked))
    (progn
      (setq value
        (dxgs:trim
          (getstring T
            (strcat "\n输入自动标注输出图层名，回车使用 [" fallback "]: "))))
      (if (= value "")
        fallback
        value
      )
    )
  )
)

(defun dxgs:config-summary (cfg / text st)
  (setq text
    (strcat
      "\n[DXGS] 当前配置:"
      "\n  导线图层: " (vl-princ-to-string (dxgs:get cfg "wire_layers"))
      "\n  灯具块名: " (vl-princ-to-string (dxgs:get cfg "lamp_blocks"))
      "\n  灯具图层: " (vl-princ-to-string (dxgs:get cfg "lamp_layers"))
      "\n  标注图层: " (dxgs:get cfg "label_layer")))
  (princ text)
  (foreach st (dxgs:get cfg "switch_types")
    (princ
      (strcat
        "\n  开关类型: " (dxgs:get st "name")
        " / 回路数 " (itoa (dxgs:get st "control_count"))
        " / 控制线 " (itoa (dxgs:switch-control-wire-count st))
        " / 块名 " (vl-princ-to-string (dxgs:get st "blocks"))
        " / 图层 " (vl-princ-to-string (dxgs:get st "layers"))))
  )
)

(defun dxgs:setup-config (/ existing lamp-ss lamp-sig wire-ss wire-sig switch-types label-layer cfg)
  (setq existing (dxgs:normalize-config (dxgs:config-load)))
  (if (dxgs:config-valid-p existing)
    (progn
      (setq *DXGS-CONFIG* existing)
      (princ "\n[DXGS] 开始修改本图纸的识别配置。回车可保留已有项。")
      (dxgs:config-summary existing))
    (princ "\n[DXGS] 开始建立本图纸的识别配置。")
  )

  (princ "\n请选择一个或多个灯具图例块；已有配置时回车保留。")
  (setq lamp-ss (ssget '((0 . "INSERT"))))
  (if lamp-ss
    (setq lamp-sig (dxgs:collect-insert-signature lamp-ss))
    (if (dxgs:config-valid-p existing)
      (setq lamp-sig
        (list (cons "blocks" (dxgs:get existing "lamp_blocks"))
              (cons "layers" (dxgs:get existing "lamp_layers"))))
      (dxgs:abort "未选择灯具图例，配置中止。")
    )
  )
  (if (or (null (dxgs:get lamp-sig "blocks"))
          (null (dxgs:get lamp-sig "layers")))
    (dxgs:abort "未能从灯具图例中读取块名和图层。")
  )

  (setq switch-types (dxgs:setup-switch-types (dxgs:get existing "switch_types")))

  (princ "\n请选择一条或多条导线样例（LINE/LWPOLYLINE/POLYLINE）；已有配置时回车保留。")
  (setq wire-ss (ssget '((0 . "LINE,LWPOLYLINE,POLYLINE"))))
  (if wire-ss
    (setq wire-sig (dxgs:collect-wire-signature wire-ss))
    (if (dxgs:config-valid-p existing)
      (setq wire-sig
        (list (cons "layers" (dxgs:get existing "wire_layers"))
              (cons "types" (dxgs:get existing "wire_types"))))
      (dxgs:abort "未选择导线样例，配置中止。")
    )
  )
  (if (null (dxgs:get wire-sig "layers"))
    (dxgs:abort "未能从导线样例中读取图层。")
  )

  (setq label-layer (dxgs:prompt-label-layer (dxgs:get existing "label_layer")))
  (setq cfg
    (list (cons "version" 1)
          (cons "wire_layers" (dxgs:get wire-sig "layers"))
          (cons "wire_types" (dxgs:get wire-sig "types"))
          (cons "lamp_blocks" (dxgs:get lamp-sig "blocks"))
          (cons "lamp_layers" (dxgs:get lamp-sig "layers"))
          (cons "switch_types" switch-types)
          (cons "label_layer" label-layer)))
  (setq *DXGS-CONFIG* (dxgs:config-save cfg))
  (dxgs:config-summary cfg)
  (princ "\n[DXGS] 配置已保存到当前 DWG。")
  cfg
)

(defun dxgs:ensure-config (/ cfg ans)
  (setq cfg (dxgs:config-load))
  (if (dxgs:config-valid-p cfg)
    (progn
      (setq *DXGS-CONFIG* cfg)
      cfg
    )
    (progn
      (princ "\n[DXGS] 当前图纸尚未配置灯具、开关和导线识别规则。")
      (dxgs:setup-config)
    )
  )
)

;;; ------------------------------------------------------------------------
;;; Geometry helpers
;;; ------------------------------------------------------------------------

(defun dxgs:pt3 (pt)
  (cond
    ((null pt) nil)
    ((= (length pt) 2) (list (car pt) (cadr pt) 0.0))
    (t (list (car pt) (cadr pt) (if (caddr pt) (caddr pt) 0.0)))
  )
)

(defun dxgs:v- (a b)
  (list (- (car a) (car b))
        (- (cadr a) (cadr b))
        (- (caddr (dxgs:pt3 a)) (caddr (dxgs:pt3 b))))
)

(defun dxgs:v+ (a b)
  (list (+ (car a) (car b))
        (+ (cadr a) (cadr b))
        (+ (caddr (dxgs:pt3 a)) (caddr (dxgs:pt3 b))))
)

(defun dxgs:v* (s v)
  (list (* s (car v)) (* s (cadr v)) (* s (caddr (dxgs:pt3 v))))
)

(defun dxgs:dot2 (a b)
  (+ (* (car a) (car b)) (* (cadr a) (cadr b)))
)

(defun dxgs:len2 (v)
  (sqrt (+ (* (car v) (car v)) (* (cadr v) (cadr v))))
)

(defun dxgs:dist2 (a b)
  (dxgs:len2 (dxgs:v- (dxgs:pt3 a) (dxgs:pt3 b)))
)

(defun dxgs:midpoint (a b)
  (list (/ (+ (car a) (car b)) 2.0)
        (/ (+ (cadr a) (cadr b)) 2.0)
        (/ (+ (caddr (dxgs:pt3 a)) (caddr (dxgs:pt3 b))) 2.0))
)

(defun dxgs:segment-param (pt a b / ab ap len2 param)
  (setq ab (dxgs:v- b a)
        ap (dxgs:v- pt a)
        len2 (dxgs:dot2 ab ab))
  (if (equal len2 0.0 1e-9)
    0.0
    (progn
      (setq param (/ (dxgs:dot2 ap ab) len2))
      (cond
        ((< param 0.0) 0.0)
        ((> param 1.0) 1.0)
        (t param)
      )
    )
  )
)

(defun dxgs:closest-point-on-segment (pt a b / ab len2 param)
  (setq param (dxgs:segment-param pt a b)
        ab (dxgs:v- b a))
  (dxgs:v+ a (dxgs:v* param ab))
)

(defun dxgs:near-point-list-p (pts pt tol / hit p)
  (setq hit nil)
  (foreach p pts
    (if (<= (dxgs:dist2 p pt) tol)
      (setq hit T)
    )
  )
  hit
)

(defun dxgs:add-point-unique (pts pt tol)
  (if (dxgs:near-point-list-p pts pt tol)
    pts
    (append pts (list (dxgs:pt3 pt)))
  )
)

(defun dxgs:collinear-vectors-p (v1 v2 tol-ang / len1 len2 cos-val)
  (setq len1 (dxgs:len2 v1)
        len2 (dxgs:len2 v2))
  (if (or (equal len1 0.0 1e-9)
          (equal len2 0.0 1e-9))
    nil
    (progn
      (setq cos-val (abs (/ (dxgs:dot2 v1 v2) (* len1 len2))))
      (>= cos-val (cos tol-ang))
    )
  )
)

(defun dxgs:point-in-box-p (pt minpt maxpt tol)
  (and (>= (car pt) (- (car minpt) tol))
       (<= (car pt) (+ (car maxpt) tol))
       (>= (cadr pt) (- (cadr minpt) tol))
       (<= (cadr pt) (+ (cadr maxpt) tol)))
)

(defun dxgs:orient2 (a b c)
  (- (* (- (car b) (car a)) (- (cadr c) (cadr a)))
     (* (- (cadr b) (cadr a)) (- (car c) (car a))))
)

(defun dxgs:on-segment-p (a b c tol)
  (and (<= (abs (dxgs:orient2 a b c)) tol)
       (<= (min (car a) (car b)) (+ (car c) tol))
       (>= (max (car a) (car b)) (- (car c) tol))
       (<= (min (cadr a) (cadr b)) (+ (cadr c) tol))
       (>= (max (cadr a) (cadr b)) (- (cadr c) tol)))
)

(defun dxgs:segments-intersect-p (p1 p2 q1 q2 / o1 o2 o3 o4 eps)
  (setq eps 1e-7
        o1 (dxgs:orient2 p1 p2 q1)
        o2 (dxgs:orient2 p1 p2 q2)
        o3 (dxgs:orient2 q1 q2 p1)
        o4 (dxgs:orient2 q1 q2 p2))
  (or (and (< (* o1 o2) 0.0) (< (* o3 o4) 0.0))
      (dxgs:on-segment-p p1 p2 q1 eps)
      (dxgs:on-segment-p p1 p2 q2 eps)
      (dxgs:on-segment-p q1 q2 p1 eps)
      (dxgs:on-segment-p q1 q2 p2 eps))
)

(defun dxgs:segment-intersects-box-p (p1 p2 minpt maxpt tol / minx maxx miny maxy a b c d)
  (setq minx (- (car minpt) tol)
        maxx (+ (car maxpt) tol)
        miny (- (cadr minpt) tol)
        maxy (+ (cadr maxpt) tol)
        a (list minx miny 0.0)
        b (list maxx miny 0.0)
        c (list maxx maxy 0.0)
        d (list minx maxy 0.0))
  (or (dxgs:point-in-box-p p1 minpt maxpt tol)
      (dxgs:point-in-box-p p2 minpt maxpt tol)
      (dxgs:segments-intersect-p p1 p2 a b)
      (dxgs:segments-intersect-p p1 p2 b c)
      (dxgs:segments-intersect-p p1 p2 c d)
      (dxgs:segments-intersect-p p1 p2 d a))
)

(defun dxgs:get-bbox (obj / minpt maxpt result)
  (setq result
    (vl-catch-all-apply
      '(lambda ()
         (vla-GetBoundingBox obj 'minpt 'maxpt))
      nil))
  (if (vl-catch-all-error-p result)
    nil
    (list (dxgs:pt3 (vlax-safearray->list minpt))
          (dxgs:pt3 (vlax-safearray->list maxpt)))
  )
)

;;; ------------------------------------------------------------------------
;;; Entity extraction
;;; ------------------------------------------------------------------------

(defun dxgs:lwpolyline-closed-p (entdata / flag)
  (setq flag (cdr (assoc 70 entdata)))
  (and flag (= 1 (logand flag 1)))
)

(defun dxgs:entity-vertices (ename / entdata typ verts next vdata)
  (setq entdata (entget ename)
        typ (cdr (assoc 0 entdata))
        verts nil)
  (cond
    ((= typ "LINE")
     (list (dxgs:pt3 (cdr (assoc 10 entdata)))
           (dxgs:pt3 (cdr (assoc 11 entdata)))))
    ((= typ "LWPOLYLINE")
     (foreach pair entdata
       (if (= (car pair) 10)
         (setq verts (append verts (list (dxgs:pt3 (cdr pair)))))
       )
     )
     (if (and (dxgs:lwpolyline-closed-p entdata) (> (length verts) 1))
       (setq verts (append verts (list (car verts))))
     )
     verts)
    ((= typ "POLYLINE")
     (setq next (entnext ename))
     (while next
       (setq vdata (entget next))
       (cond
         ((= (cdr (assoc 0 vdata)) "VERTEX")
          (setq verts (append verts (list (dxgs:pt3 (cdr (assoc 10 vdata)))))))
         ((= (cdr (assoc 0 vdata)) "SEQEND")
          (setq next nil))
       )
       (if next (setq next (entnext next)))
     )
     verts)
    (t nil)
  )
)

(defun dxgs:configured-wire-layer-p (layer / layers)
  (setq layers (dxgs:get *DXGS-CONFIG* "wire_layers"))
  (and layer layers (dxgs:member-ci layer layers))
)

(defun dxgs:make-segments-from-entity (ename / entdata layer handle verts idx a b segs)
  (setq entdata (entget ename)
        layer (cdr (assoc 8 entdata))
        handle (cdr (assoc 5 entdata))
        verts (dxgs:entity-vertices ename)
        idx 0
        segs nil)
  (if (and layer (dxgs:configured-wire-layer-p layer) (> (length verts) 1))
    (while (< idx (1- (length verts)))
      (setq a (nth idx verts)
            b (nth (1+ idx) verts))
      (if (> (dxgs:dist2 a b) 1e-6)
        (setq segs
          (cons
            (list (cons "id" (strcat handle ":" (itoa idx)))
                  (cons "source_id" (strcat handle ":" (itoa idx)))
                  (cons "handle" handle)
                  (cons "ename" ename)
                  (cons "layer" layer)
                  (cons "p1" a)
                  (cons "p2" b))
            segs))
      )
      (setq idx (1+ idx))
    )
  )
  (reverse segs)
)

(defun dxgs:collect-wire-segments (ss / en out segs kept skipped)
  (setq out nil
        kept 0
        skipped 0)
  (foreach en (dxgs:ss->enames ss)
    (setq segs (dxgs:make-segments-from-entity en))
    (if segs
      (progn
        (setq out (append out segs)
              kept (1+ kept)))
      (setq skipped (1+ skipped))
    )
  )
  (princ
    (strcat "\n[DXGS] 已提取管线实体 " (itoa kept)
            " 个，图层/类型不匹配跳过 " (itoa skipped) " 个。"))
  out
)

(defun dxgs:switch-config-for-entity (ename / block layer found st)
  (setq block (dxgs:insert-block-name ename)
        layer (dxgs:entity-layer ename)
        found nil)
  (foreach st (dxgs:get *DXGS-CONFIG* "switch_types")
    (if (and (dxgs:member-ci block (dxgs:get st "blocks"))
             (dxgs:member-ci layer (dxgs:get st "layers")))
      (setq found st)
    )
  )
  found
)

(defun dxgs:device-config-for-entity (ename type / block layer st)
  (if (/= (dxgs:entity-type ename) "INSERT")
    nil
    (progn
      (setq block (dxgs:insert-block-name ename)
            layer (dxgs:entity-layer ename))
      (cond
        ((= type "LAMP")
         (if (and (dxgs:member-ci block (dxgs:get *DXGS-CONFIG* "lamp_blocks"))
                  (dxgs:member-ci layer (dxgs:get *DXGS-CONFIG* "lamp_layers")))
           (list (cons "block" block)
                 (cons "layer" layer))
           nil))
        ((= type "SWITCH")
         (setq st (dxgs:switch-config-for-entity ename))
         (if st
           (list (cons "block" block)
                 (cons "layer" layer)
                 (cons "switch_name" (dxgs:get st "name"))
                 (cons "control_count" (dxgs:get st "control_count"))
                 (cons "control_wire_count" (dxgs:switch-control-wire-count st))
                 (cons "kind" (dxgs:get st "kind")))
           nil))
        (t nil)
      )
    )
  )
)

(defun dxgs:make-device (ename type meta / entdata obj bbox handle ins)
  (setq entdata (entget ename)
        obj (vlax-ename->vla-object ename)
        bbox (dxgs:get-bbox obj)
        handle (cdr (assoc 5 entdata))
        ins (dxgs:pt3 (cdr (assoc 10 entdata))))
  (if bbox
    (append
      (list (cons "handle" handle)
            (cons "node" (strcat "D:" handle))
            (cons "ename" ename)
            (cons "vla" obj)
            (cons "type" type)
            (cons "insert_pt" ins)
            (cons "box_min" (car bbox))
            (cons "box_max" (cadr bbox)))
      meta)
    nil
  )
)

(defun dxgs:collect-devices (ss type / en dev out meta)
  (setq out nil)
  (foreach en (dxgs:ss->enames ss)
    (setq meta (dxgs:device-config-for-entity en type))
    (if meta
      (progn
        (setq dev (dxgs:make-device en type meta))
        (if dev
          (setq out (cons dev out))
        )
      )
    )
  )
  (reverse out)
)

;;; ------------------------------------------------------------------------
;;; T-junction split
;;; ------------------------------------------------------------------------

(defun dxgs:segment-endpoints (seg)
  (list (dxgs:get seg "p1") (dxgs:get seg "p2"))
)

(defun dxgs:split-segment-by-points (seg pts / p1 p2 sorted idx a b out base-id)
  (setq p1 (dxgs:get seg "p1")
        p2 (dxgs:get seg "p2")
        base-id (dxgs:get seg "id")
        sorted
          (vl-sort pts
            '(lambda (a b)
               (< (dxgs:segment-param a p1 p2)
                  (dxgs:segment-param b p1 p2))))
        idx 0
        out nil)
  (while (< idx (1- (length sorted)))
    (setq a (nth idx sorted)
          b (nth (1+ idx) sorted))
    (if (> (dxgs:dist2 a b) *DXGS-CONNECT-TOL*)
      (setq out
        (cons
          (list (cons "id" (strcat base-id "." (itoa idx)))
                (cons "source_id" (dxgs:get seg "source_id"))
                (cons "handle" (dxgs:get seg "handle"))
                (cons "ename" (dxgs:get seg "ename"))
                (cons "layer" (dxgs:get seg "layer"))
                (cons "p1" a)
                (cons "p2" b))
          out))
    )
    (setq idx (1+ idx))
  )
  (reverse out)
)

(defun dxgs:split-t-junctions (segments / seg other endpoint proj pts out t-count)
  (setq out nil
        t-count 0)
  (foreach seg segments
    (setq pts (list (dxgs:get seg "p1") (dxgs:get seg "p2")))
    (foreach other segments
      (if (/= (dxgs:get seg "id") (dxgs:get other "id"))
        (foreach endpoint (dxgs:segment-endpoints other)
          (setq proj
            (dxgs:closest-point-on-segment
              endpoint
              (dxgs:get seg "p1")
              (dxgs:get seg "p2")))
          (if (and (<= (dxgs:dist2 endpoint proj) *DXGS-CONNECT-TOL*)
                   (> (dxgs:dist2 proj (dxgs:get seg "p1")) *DXGS-CONNECT-TOL*)
                   (> (dxgs:dist2 proj (dxgs:get seg "p2")) *DXGS-CONNECT-TOL*)
                   (not (dxgs:near-point-list-p pts proj *DXGS-CONNECT-TOL*)))
            (progn
              (setq pts (dxgs:add-point-unique pts proj *DXGS-CONNECT-TOL*))
              (setq t-count (1+ t-count)))
          )
        )
      )
    )
    (setq out (append out (dxgs:split-segment-by-points seg pts)))
  )
  (if (> t-count 0)
    (princ (strcat "\n[DXGS] 检测并虚拟切分 T 接点 " (itoa t-count) " 处。"))
  )
  out
)

;;; ------------------------------------------------------------------------
;;; Union-Find helpers
;;; ------------------------------------------------------------------------

(defun dxgs:uf-add (key parent)
  (if (assoc key parent)
    parent
    (cons (cons key key) parent)
  )
)

(defun dxgs:uf-find (key parent / val)
  (setq val (cdr (assoc key parent)))
  (cond
    ((null val) key)
    ((= val key) key)
    (t (dxgs:uf-find val parent))
  )
)

(defun dxgs:uf-union (a b parent / ra rb old)
  (setq parent (dxgs:uf-add a parent)
        parent (dxgs:uf-add b parent)
        ra (dxgs:uf-find a parent)
        rb (dxgs:uf-find b parent))
  (if (/= ra rb)
    (progn
      (setq old (assoc rb parent))
      (setq parent (subst (cons rb ra) old parent))
    )
  )
  parent
)

;;; ------------------------------------------------------------------------
;;; Node binding and clustering
;;; ------------------------------------------------------------------------

(defun dxgs:devices-at-point (pt devices / out dev)
  (setq out nil)
  (foreach dev devices
    (if (dxgs:point-in-box-p pt
                             (dxgs:get dev "box_min")
                             (dxgs:get dev "box_max")
                             *DXGS-CONNECT-TOL*)
      (setq out (cons dev out))
    )
  )
  out
)

(defun dxgs:endpoint-records (segments devices / out seg side pt key hits node)
  (setq out nil)
  (foreach seg segments
    (foreach side '("S" "E")
      (setq pt (if (= side "S") (dxgs:get seg "p1") (dxgs:get seg "p2"))
            key (strcat (dxgs:get seg "id") ":" side)
            hits (dxgs:devices-at-point pt devices))
      (cond
        ((> (length hits) 1)
         (dxgs:abort
           (strcat "检测到重叠设备冲突，请检查设备间距。管线端点: "
                   (rtos (car pt) 2 2) "," (rtos (cadr pt) 2 2))))
        ((= (length hits) 1)
         (setq node (dxgs:get (car hits) "node")))
        (t
         (setq node nil))
      )
      (setq out
        (cons
          (list (cons "key" key)
                (cons "edge_id" (dxgs:get seg "id"))
                (cons "side" side)
                (cons "pt" pt)
                (cons "node" node))
          out))
    )
  )
  (reverse out)
)

(defun dxgs:cluster-endpoints (records / parent unbound a b root-map counter key root node node-map)
  (setq parent nil
        unbound nil
        root-map nil
        node-map nil
        counter 0)
  (foreach a records
    (if (null (dxgs:get a "node"))
      (progn
        (setq key (dxgs:get a "key"))
        (setq parent (dxgs:uf-add key parent))
        (setq unbound (cons a unbound)))
    )
  )
  (foreach a unbound
    (foreach b unbound
      (if (and (/= (dxgs:get a "key") (dxgs:get b "key"))
               (<= (dxgs:dist2 (dxgs:get a "pt") (dxgs:get b "pt"))
                   *DXGS-CONNECT-TOL*))
        (setq parent (dxgs:uf-union (dxgs:get a "key") (dxgs:get b "key") parent))
      )
    )
  )
  (foreach a records
    (setq key (dxgs:get a "key"))
    (if (dxgs:get a "node")
      (setq node (dxgs:get a "node"))
      (progn
        (setq root (dxgs:uf-find key parent))
        (if (not (assoc root root-map))
          (progn
            (setq counter (1+ counter))
            (setq root-map (cons (cons root (strcat "N:" (itoa counter))) root-map))
          )
        )
        (setq node (cdr (assoc root root-map)))
      )
    )
    (setq node-map (cons (cons key node) node-map))
  )
  node-map
)

(defun dxgs:assign-nodes-to-segments (segments devices / records node-map out seg s-key e-key)
  (setq records (dxgs:endpoint-records segments devices)
        node-map (dxgs:cluster-endpoints records)
        out nil)
  (foreach seg segments
    (setq s-key (strcat (dxgs:get seg "id") ":S")
          e-key (strcat (dxgs:get seg "id") ":E"))
    (setq seg (dxgs:set seg "node1" (cdr (assoc s-key node-map))))
    (setq seg (dxgs:set seg "node2" (cdr (assoc e-key node-map))))
    (if (/= (dxgs:get seg "node1") (dxgs:get seg "node2"))
      (setq out (cons seg out))
    )
  )
  (reverse out)
)

;;; ------------------------------------------------------------------------
;;; Broken collinear segment merge
;;; ------------------------------------------------------------------------

(defun dxgs:nearest-endpoint-pair (a b / pts1 pts2 p q best dist)
  (setq pts1 (list (list (dxgs:get a "p1") (dxgs:get a "node1") "S")
                   (list (dxgs:get a "p2") (dxgs:get a "node2") "E"))
        pts2 (list (list (dxgs:get b "p1") (dxgs:get b "node1") "S")
                   (list (dxgs:get b "p2") (dxgs:get b "node2") "E"))
        best nil)
  (foreach p pts1
    (foreach q pts2
      (setq dist (dxgs:dist2 (car p) (car q)))
      (if (or (null best) (< dist (nth 4 best)))
        (setq best (list (car p) (cadr p) (car q) (cadr q) dist))
      )
    )
  )
  best
)

(defun dxgs:gap-intersects-device-p (p1 p2 devices / hit dev)
  (setq hit nil)
  (foreach dev devices
    (if (dxgs:segment-intersects-box-p p1 p2
                                       (dxgs:get dev "box_min")
                                       (dxgs:get dev "box_max")
                                       *DXGS-CONNECT-TOL*)
      (setq hit T)
    )
  )
  hit
)

(defun dxgs:can-merge-segments-p (a b devices / pair p1 p2 d)
  (setq pair (dxgs:nearest-endpoint-pair a b)
        p1 (nth 0 pair)
        p2 (nth 2 pair)
        d (nth 4 pair))
  (and (= (dxgs:get a "layer") (dxgs:get b "layer"))
       (> d *DXGS-CONNECT-TOL*)
       (<= d *DXGS-MERGE-GAP*)
       (not (dxgs:string-prefix-p "D:" (nth 1 pair)))
       (not (dxgs:string-prefix-p "D:" (nth 3 pair)))
       (dxgs:collinear-vectors-p
         (dxgs:v- (dxgs:get a "p2") (dxgs:get a "p1"))
         (dxgs:v- (dxgs:get b "p2") (dxgs:get b "p1"))
         *DXGS-ANGLE-TOL*)
       (dxgs:collinear-vectors-p
         (dxgs:v- (dxgs:get a "p2") (dxgs:get a "p1"))
         (dxgs:v- p2 p1)
         *DXGS-ANGLE-TOL*)
       (not (dxgs:gap-intersects-device-p p1 p2 devices)))
)

(defun dxgs:group-segments-by-merge (segments devices / parent a b root groups old rest rest2)
  (setq parent nil
        groups nil)
  (foreach a segments
    (setq parent (dxgs:uf-add (dxgs:get a "id") parent))
  )
  (setq rest segments)
  (while rest
    (setq a (car rest)
          rest2 (cdr rest))
    (while rest2
      (setq b (car rest2))
      (if (dxgs:can-merge-segments-p a b devices)
        (setq parent (dxgs:uf-union (dxgs:get a "id") (dxgs:get b "id") parent))
      )
      (setq rest2 (cdr rest2))
    )
    (setq rest (cdr rest))
  )
  (foreach a segments
    (setq root (dxgs:uf-find (dxgs:get a "id") parent)
          old (assoc root groups))
    (if old
      (setq groups (subst (cons root (append (cdr old) (list a))) old groups))
      (setq groups (cons (cons root (list a)) groups))
    )
  )
  groups
)

(defun dxgs:farthest-group-endpoints (group / endpoints seg a b best dist)
  (setq endpoints nil
        best nil)
  (foreach seg group
    (setq endpoints
      (append endpoints
        (list (list (dxgs:get seg "p1") (dxgs:get seg "node1"))
              (list (dxgs:get seg "p2") (dxgs:get seg "node2")))))
  )
  (foreach a endpoints
    (foreach b endpoints
      (setq dist (dxgs:dist2 (car a) (car b)))
      (if (or (null best) (> dist (nth 4 best)))
        (setq best (list (car a) (cadr a) (car b) (cadr b) dist))
      )
    )
  )
  best
)

(defun dxgs:longest-segment (group / best len seg)
  (setq best nil)
  (foreach seg group
    (setq len (dxgs:dist2 (dxgs:get seg "p1") (dxgs:get seg "p2")))
    (if (or (null best) (> len (dxgs:get best "length")))
      (setq best (dxgs:set seg "length" len))
    )
  )
  best
)

(defun dxgs:readable-angle (ang)
  (while (< ang 0.0)
    (setq ang (+ ang (* 2.0 pi)))
  )
  (while (>= ang (* 2.0 pi))
    (setq ang (- ang (* 2.0 pi)))
  )
  (if (and (> ang (/ pi 2.0))
           (< ang (* 1.5 pi)))
    (- ang pi)
    ang
  )
)

(defun dxgs:make-logical-edge (idx group / ends long mid ang label-pt physical-ids seg)
  (setq ends (dxgs:farthest-group-endpoints group)
        long (dxgs:longest-segment group)
        mid (dxgs:midpoint (dxgs:get long "p1") (dxgs:get long "p2"))
        ang (dxgs:readable-angle (angle (dxgs:get long "p1") (dxgs:get long "p2")))
        label-pt (polar mid (+ ang (/ pi 2.0)) *DXGS-LABEL-OFFSET*)
        physical-ids nil)
  (foreach seg group
    (setq physical-ids (dxgs:add-unique physical-ids (dxgs:get seg "source_id")))
  )
  (list (cons "id" (strcat "E" (itoa idx)))
        (cons "segments" group)
        (cons "physical_edges" physical-ids)
        (cons "node1" (nth 1 ends))
        (cons "node2" (nth 3 ends))
        (cons "start_pt" (nth 0 ends))
        (cons "end_pt" (nth 2 ends))
        (cons "label_pt" (dxgs:pt3 label-pt))
        (cons "label_angle" ang)
        (cons "wires" nil)
        (cons "wire_count" 0)
        (cons "need_label" nil))
)

(defun dxgs:build-logical-edges (segments devices / groups idx out group edge)
  (setq groups (dxgs:group-segments-by-merge segments devices)
        idx 1
        out nil)
  (foreach group groups
    (setq edge (dxgs:make-logical-edge idx (cdr group)))
    (if (/= (dxgs:get edge "node1") (dxgs:get edge "node2"))
      (progn
        (setq out (cons edge out))
        (setq idx (1+ idx)))
    )
  )
  (princ (strcat "\n[DXGS] 生成逻辑管线边 " (itoa (length out)) " 条。"))
  (reverse out)
)

;;; ------------------------------------------------------------------------
;;; Graph and BFS
;;; ------------------------------------------------------------------------

(defun dxgs:adj-add (adj node edge-id / old)
  (setq old (assoc node adj))
  (if old
    (subst (cons node (dxgs:add-unique (cdr old) edge-id)) old adj)
    (cons (cons node (list edge-id)) adj)
  )
)

(defun dxgs:build-adj (edges / adj edge)
  (setq adj nil)
  (foreach edge edges
    (setq adj (dxgs:adj-add adj (dxgs:get edge "node1") (dxgs:get edge "id")))
    (setq adj (dxgs:adj-add adj (dxgs:get edge "node2") (dxgs:get edge "id")))
  )
  adj
)

(defun dxgs:edge-by-id (edges id / found edge)
  (setq found nil)
  (foreach edge edges
    (if (= (dxgs:get edge "id") id)
      (setq found edge)
    )
  )
  found
)

(defun dxgs:other-node (edge node)
  (if (= node (dxgs:get edge "node1"))
    (dxgs:get edge "node2")
    (dxgs:get edge "node1")
  )
)

(defun dxgs:bfs-path (start end adj edges blocked / queue visited parent current eids eid edge next rec path found)
  (if (= start end)
    nil
    (progn
      (setq queue (list start)
            visited (list start)
            parent nil
            found nil)
      (while (and queue (not found))
        (setq current (car queue)
              queue (cdr queue)
              eids (cdr (assoc current adj)))
        (foreach eid eids
          (setq edge (dxgs:edge-by-id edges eid)
                next (dxgs:other-node edge current))
          (if (and (not (member next visited))
                   (or (= next end)
                       (= next start)
                       (not (member next blocked))))
            (progn
              (setq visited (cons next visited))
              (setq parent (cons (list next current eid) parent))
              (if (= next end)
                (setq found T)
                (setq queue (append queue (list next)))
              )
            )
          )
        )
      )
      (if (not (member end visited))
        nil
        (progn
          (setq path nil
                current end)
          (while (/= current start)
            (setq rec (assoc current parent))
            (if rec
              (progn
                (setq path (cons (caddr rec) path))
                (setq current (cadr rec)))
              (setq current start)
            )
          )
          path
        )
      )
    )
  )
)

(defun dxgs:reachable-nodes (root adj edges / queue visited current eids edge next)
  (setq queue (list root)
        visited (list root))
  (while queue
    (setq current (car queue)
          queue (cdr queue)
          eids (cdr (assoc current adj)))
    (foreach eid eids
      (setq edge (dxgs:edge-by-id edges eid)
            next (dxgs:other-node edge current))
      (if (not (member next visited))
        (setq visited (cons next visited)
              queue (append queue (list next)))
      )
    )
  )
  visited
)

(defun dxgs:component-cycle-p (root adj edges / nodes edge-count edge)
  (setq nodes (dxgs:reachable-nodes root adj edges)
        edge-count 0)
  (foreach edge edges
    (if (and (member (dxgs:get edge "node1") nodes)
             (member (dxgs:get edge "node2") nodes))
      (setq edge-count (1+ edge-count))
    )
  )
  (>= edge-count (length nodes))
)

;;; ------------------------------------------------------------------------
;;; Electrical calculation
;;; ------------------------------------------------------------------------

(defun dxgs:device-nodes-by-type (devices type / out dev)
  (setq out nil)
  (foreach dev devices
    (if (= (dxgs:get dev "type") type)
      (setq out (cons (dxgs:get dev "node") out))
    )
  )
  (reverse out)
)

(defun dxgs:devices-by-type (devices type / out dev)
  (setq out nil)
  (foreach dev devices
    (if (= (dxgs:get dev "type") type)
      (setq out (cons dev out))
    )
  )
  (reverse out)
)

(defun dxgs:switch-gang-wires (switch switch-idx gang-idx / count wire-count wires n)
  (setq count (dxgs:get switch "control_count"))
  (if (or (null count) (< count 1))
    (setq count 1)
  )
  (if (> count 1)
    (list (strcat "C" (itoa switch-idx) "." (itoa gang-idx)))
    (progn
      (setq wire-count (dxgs:get switch "control_wire_count"))
      (if (or (null wire-count) (< wire-count 1))
        (setq wire-count 1)
      )
      (setq wires nil
            n 1)
      (while (<= n wire-count)
        (setq wires
          (append wires
            (list
              (if (= wire-count 1)
                (strcat "C" (itoa switch-idx))
                (strcat "C" (itoa switch-idx) "." (itoa n))))))
        (setq n (1+ n))
      )
      wires
    )
  )
)

(defun dxgs:multi-single-switch-p (switch / count)
  (setq count (dxgs:get switch "control_count"))
  (if (or (null count) (< count 1))
    (setq count 1)
  )
  (and (> count 1) (= (dxgs:get switch "kind") "SINGLE"))
)

(defun dxgs:single-gang-single-control-p (switch / count wire-count)
  (setq count (dxgs:get switch "control_count"))
  (if (or (null count) (< count 1))
    (setq count 1)
  )
  (setq wire-count (dxgs:get switch "control_wire_count"))
  (if (or (null wire-count) (< wire-count 1))
    (setq wire-count 1)
  )
  (and (= count 1)
       (= wire-count 1)
       (= (dxgs:get switch "kind") "SINGLE"))
)

(defun dxgs:switch-by-handle (switches handle / found sw)
  (setq found nil)
  (foreach sw switches
    (if (dxgs:same-handle-p (dxgs:get sw "handle") handle)
      (setq found sw)
    )
  )
  found
)

(defun dxgs:switch-by-node (switches node / found sw)
  (setq found nil)
  (foreach sw switches
    (if (= (dxgs:get sw "node") node)
      (setq found sw)
    )
  )
  found
)

(defun dxgs:remove-switch-by-node (switches node / out sw)
  (setq out nil)
  (foreach sw switches
    (if (/= (dxgs:get sw "node") node)
      (setq out (append out (list sw)))
    )
  )
  out
)

(defun dxgs:prompt-switch-choice (switches idx total / pick sw)
  (setq sw nil)
  (while (null sw)
    (setq pick
      (entsel
        (strcat "\n请选择第 " (itoa idx) "/" (itoa total) " 个开关: ")))
    (if pick
      (progn
        (setq sw (dxgs:switch-by-handle switches (dxgs:entity-handle (car pick))))
        (if (null sw)
          (princ "\n[DXGS] 请选择本次分析范围内尚未分组的已识别开关。")
        )
      )
      (princ "\n[DXGS] 未选择开关，请点选一个开关。")
    )
  )
  sw
)

(defun dxgs:lamp-by-handle (lamps handle / found lamp)
  (setq found nil)
  (foreach lamp lamps
    (if (dxgs:same-handle-p (dxgs:get lamp "handle") handle)
      (setq found lamp)
    )
  )
  found
)

(defun dxgs:collect-selected-lamps (ss lamps / out en lamp)
  (setq out nil)
  (foreach en (dxgs:ss->enames ss)
    (setq lamp (dxgs:lamp-by-handle lamps (dxgs:entity-handle en)))
    (if lamp
      (setq out (dxgs:add-unique out (dxgs:get lamp "node")))
    )
  )
  out
)

(defun dxgs:group-assigned-lamp-nodes (gang-groups / out rec group lamp-node)
  (setq out nil)
  (foreach rec gang-groups
    (foreach group (cdr rec)
      (foreach lamp-node (cdr group)
        (setq out (dxgs:add-unique out lamp-node))
      )
    )
  )
  out
)

(defun dxgs:remaining-lamp-nodes (lamps gang-groups / assigned out lamp node)
  (setq assigned (dxgs:group-assigned-lamp-nodes gang-groups)
        out nil)
  (foreach lamp lamps
    (setq node (dxgs:get lamp "node"))
    (if (not (member node assigned))
      (setq out (append out (list node)))
    )
  )
  out
)

(defun dxgs:remaining-lamp-groups (lamps gang-groups / nodes)
  (setq nodes (dxgs:remaining-lamp-nodes lamps gang-groups))
  (if nodes
    (list (cons 1 nodes))
    nil
  )
)

(defun dxgs:order-switches-by-groups (switches gang-groups / out rec sw)
  (setq out nil)
  (foreach rec gang-groups
    (setq sw (dxgs:switch-by-node switches (car rec)))
    (if sw
      (setq out (append out (list sw)))
    )
  )
  (foreach sw switches
    (if (null (assoc (dxgs:get sw "node") gang-groups))
      (setq out (append out (list sw)))
    )
  )
  out
)

(defun dxgs:prompt-switch-gang-lamps (switch lamps prompt-all / count idx ss selected groups)
  (setq count (dxgs:get switch "control_count"))
  (if (or (null count) (< count 1))
    (setq count 1)
  )
  (if (and (not prompt-all) (not (dxgs:multi-single-switch-p switch)))
    nil
    (progn
      (if (> count 1)
        (princ (strcat "\n[DXGS] 开关 [" (dxgs:get switch "switch_name") "] 为 " (itoa count) " 联，请按每一联选择控制的灯具。"))
        (princ (strcat "\n[DXGS] 开关 [" (dxgs:get switch "switch_name") "] 为单联，请选择其控制的灯具。"))
      )
      (setq idx 1
            groups nil)
      (while (<= idx count)
        (if (> count 1)
          (princ (strcat "\n请选择第 " (itoa idx) " 联控制的灯具组，回车跳过该联: "))
          (princ "\n请选择该开关控制的灯具组，回车跳过: ")
        )
        (setq ss (ssget '((0 . "INSERT"))))
        (if ss
          (progn
            (setq selected (dxgs:collect-selected-lamps ss lamps))
            (if selected
              (progn
                (setq groups (cons (cons idx selected) groups))
                (princ
                  (strcat "\n[DXGS] 记录灯具 "
                          (itoa (length selected)) " 个。")))
              (princ
                "\n[DXGS] 未选到当前分析范围内的已识别灯具。")
            )
          )
          (princ "\n[DXGS] 跳过选择。")
        )
        (setq idx (1+ idx))
      )
      groups
    )
  )
)

(defun dxgs:prompt-switch-gang-groups (switches lamps / out sw groups prompt-all remaining idx total)
  (setq out nil)
  (setq total (length switches)
        prompt-all (>= total 2))
  (if prompt-all
    (progn
      (princ "\n[DXGS] 检测到多个开关，请按实际控制顺序依次点选开关并指定灯具分组。")
      (setq remaining switches
            idx 1)
      (while remaining
        (setq sw (dxgs:prompt-switch-choice remaining idx total))
        (setq remaining (dxgs:remove-switch-by-node remaining (dxgs:get sw "node")))
        (if (and (null remaining) (dxgs:single-gang-single-control-p sw))
          (progn
            (setq groups (dxgs:remaining-lamp-groups lamps out))
            (setq out (append out (list (cons (dxgs:get sw "node") groups))))
            (princ
              (strcat "\n[DXGS] 最后一个开关为单联单控，自动分配剩余灯具 "
                      (itoa (length (if groups (cdr (car groups)) nil))) " 个。"))
          )
          (progn
            (setq groups (dxgs:prompt-switch-gang-lamps sw lamps T))
            (setq out (append out (list (cons (dxgs:get sw "node") groups))))
          )
        )
        (setq idx (1+ idx))
      )
    )
    (foreach sw switches
      (setq groups (dxgs:prompt-switch-gang-lamps sw lamps nil))
      (if (or groups (dxgs:multi-single-switch-p sw))
        (setq out (append out (list (cons (dxgs:get sw "node") groups))))
      )
    )
  )
  out
)

(defun dxgs:group-lamps-for-switch (switch lamps groups / rec out lamp)
  (setq rec (assoc (dxgs:get switch "node") groups))
  (if rec
    (cdr rec)
    (progn
      (setq out nil)
      (foreach lamp lamps
        (setq out (cons (cons 1 (list (dxgs:get lamp "node"))) out))
      )
      out
    )
  )
)

(defun dxgs:add-wire-to-edge (edge wire)
  (dxgs:set edge "wires" (dxgs:add-unique (dxgs:get edge "wires") wire))
)

(defun dxgs:add-wires-to-path (edges path wires / out edge wire)
  (setq out nil)
  (foreach edge edges
    (if (member (dxgs:get edge "id") path)
      (foreach wire wires
        (setq edge (dxgs:add-wire-to-edge edge wire))
      )
    )
    (setq out (cons edge out))
  )
  (reverse out)
)

(defun dxgs:path-or-warn (start end adj edges blocked label / path)
  (setq path (dxgs:bfs-path start end adj edges blocked))
  (if (null path)
    (princ (strcat "\n[DXGS] 警告: 未找到路径，跳过 " label "。"))
  )
  path
)

(defun dxgs:assign-wires-model-a (edges root lamps switches adj gang-groups / sw sw-node lamp lamp-node path idx groups group gang-idx)
  (setq idx 1)
  (foreach sw switches
    (setq sw-node (dxgs:get sw "node"))
    (setq path (dxgs:path-or-warn root sw-node adj edges nil (strcat "Root->Switch " sw-node)))
    (if path
      (setq edges (dxgs:add-wires-to-path edges path (list "L")))
    )
  )
  (foreach lamp lamps
    (setq lamp-node (dxgs:get lamp "node"))
    (setq path (dxgs:path-or-warn root lamp-node adj edges nil (strcat "Root->Lamp " lamp-node)))
    (if path
      (setq edges (dxgs:add-wires-to-path edges path (list "N" "PE")))
    )
  )
  (foreach sw switches
    (setq sw-node (dxgs:get sw "node"))
    (setq groups (dxgs:group-lamps-for-switch sw lamps gang-groups))
    (foreach group groups
      (setq gang-idx (car group))
      (foreach lamp-node (cdr group)
        (setq path
          (dxgs:path-or-warn sw-node lamp-node adj edges nil
            (strcat "Switch->Lamp " sw-node " -> " lamp-node)))
        (if path
          (setq edges
            (dxgs:add-wires-to-path edges path (dxgs:switch-gang-wires sw idx gang-idx))))
      )
    )
    (setq idx (1+ idx))
  )
  edges
)

(defun dxgs:assign-wires-model-b (edges root lamps switches adj gang-groups / sw sw-node lamp lamp-node path idx groups group gang-idx)
  (setq idx 1)
  (foreach sw switches
    (setq sw-node (dxgs:get sw "node"))
    (setq path (dxgs:path-or-warn root sw-node adj edges nil (strcat "Root->Switch " sw-node)))
    (if path
      (setq edges (dxgs:add-wires-to-path edges path (list "L" "N" "PE")))
    )
  )
  (foreach sw switches
    (setq sw-node (dxgs:get sw "node"))
    (setq groups (dxgs:group-lamps-for-switch sw lamps gang-groups))
    (foreach group groups
      (setq gang-idx (car group))
      (foreach lamp-node (cdr group)
        (setq path
          (dxgs:path-or-warn sw-node lamp-node adj edges nil
            (strcat "Switch->Lamp " sw-node " -> " lamp-node)))
        (if path
          (setq edges
            (dxgs:add-wires-to-path edges path (append (dxgs:switch-gang-wires sw idx gang-idx) (list "N" "PE")))))
      )
    )
    (setq idx (1+ idx))
  )
  edges
)

(defun dxgs:finalize-label-flags (edges filter / out edge count)
  (setq out nil)
  (foreach edge edges
    (setq count (length (dxgs:get edge "wires")))
    (setq edge (dxgs:set edge "wire_count" count))
    (setq edge
      (dxgs:set edge "need_label"
        (and (> count 0)
             (not (and (= filter "SKIP2") (= count 2)))
             (not (and (= filter "SKIP3") (= count 3))))))
    (setq out (cons edge out))
  )
  (reverse out)
)

(defun dxgs:assign-wires (edges root devices model filter / adj lamps switches gang-groups)
  (setq adj (dxgs:build-adj edges))
  (setq lamps (dxgs:devices-by-type devices "LAMP")
        switches (dxgs:devices-by-type devices "SWITCH")
        gang-groups (dxgs:prompt-switch-gang-groups switches lamps))
  (setq switches (dxgs:order-switches-by-groups switches gang-groups))
  (if (= model "B")
    (setq edges (dxgs:assign-wires-model-b edges root lamps switches adj gang-groups))
    (setq edges (dxgs:assign-wires-model-a edges root lamps switches adj gang-groups))
  )
  (dxgs:finalize-label-flags edges filter)
)

;;; ------------------------------------------------------------------------
;;; Source edge and root node
;;; ------------------------------------------------------------------------

(defun dxgs:logical-edge-distance-to-pick (edge handle pick / best seg proj dist)
  (setq best nil)
  (foreach seg (dxgs:get edge "segments")
    (if (and handle
             (dxgs:get seg "handle")
             (= (strcase (dxgs:get seg "handle")) (strcase handle)))
      (progn
        (setq proj
          (dxgs:closest-point-on-segment pick (dxgs:get seg "p1") (dxgs:get seg "p2")))
        (setq dist (dxgs:dist2 pick proj))
        (if (or (null best) (< dist best))
          (setq best dist)
        )
      )
    )
  )
  best
)

(defun dxgs:logical-edge-nearest-distance-to-pick (edge pick / best seg proj dist)
  (setq best nil)
  (foreach seg (dxgs:get edge "segments")
    (setq proj
      (dxgs:closest-point-on-segment pick (dxgs:get seg "p1") (dxgs:get seg "p2")))
    (setq dist (dxgs:dist2 pick proj))
    (if (or (null best) (< dist best))
      (setq best dist)
    )
  )
  best
)

(defun dxgs:find-source-edge (edges handle pick / best fallback edge dist)
  (setq best nil)
  (foreach edge edges
    (setq dist (dxgs:logical-edge-distance-to-pick edge handle pick))
    (if (and dist (or (null best) (< dist (cdr best))))
      (setq best (cons edge dist))
    )
  )
  (if best
    (car best)
    (progn
      (setq fallback nil)
      (foreach edge edges
        (setq dist (dxgs:logical-edge-nearest-distance-to-pick edge pick))
        (if (and dist (or (null fallback) (< dist (cdr fallback))))
          (setq fallback (cons edge dist))
        )
      )
      (if (and fallback (<= (cdr fallback) (* *DXGS-CONNECT-TOL* *DXGS-CONNECT-TOL*)))
        (progn
          (princ "\n[DXGS] 未按实体 handle 匹配到电源线，已按拾取点距离匹配最近管线。")
          (car fallback))
        nil)
    )
  )
)

(defun dxgs:edge-handle-list (edge / out seg)
  (setq out nil)
  (foreach seg (dxgs:get edge "segments")
    (setq out (dxgs:add-unique-ci out (dxgs:get seg "handle")))
  )
  out
)

(defun dxgs:print-source-edge-debug (power-ename power-handle logical-edges / edge)
  (princ
    (strcat "\n[DXGS] 调试: 电源选择对象 类型 "
            (vl-princ-to-string (dxgs:entity-type power-ename))
            " / 图层 "
            (vl-princ-to-string (dxgs:entity-layer power-ename))
            " / handle "
            (vl-princ-to-string power-handle)))
  (foreach edge logical-edges
    (princ
      (strcat "\n[DXGS] 调试: 逻辑边 "
              (dxgs:get edge "id")
              " / handles "
              (vl-princ-to-string (dxgs:edge-handle-list edge)))))
)

(defun dxgs:infer-root-node (edge / n1 n2 p1 p2 ans)
  (setq n1 (dxgs:get edge "node1")
        n2 (dxgs:get edge "node2")
        p1 (dxgs:get edge "start_pt")
        p2 (dxgs:get edge "end_pt"))
  (cond
    ((and (dxgs:string-prefix-p "D:" n1)
          (not (dxgs:string-prefix-p "D:" n2)))
     n2)
    ((and (dxgs:string-prefix-p "D:" n2)
          (not (dxgs:string-prefix-p "D:" n1)))
     n1)
    (t
     (setq ans (getpoint "\n无法自动判断电源侧根节点，请点选该管线的电源侧端点: "))
     (if (<= (dxgs:dist2 ans p1) (dxgs:dist2 ans p2))
       n1
       n2)))
)

;;; ------------------------------------------------------------------------
;;; Label cleanup and output
;;; ------------------------------------------------------------------------

(defun dxgs:ensure-layer (name / doc layers layer result)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        layers (vla-get-Layers doc)
        result (vl-catch-all-apply 'vla-Item (list layers name)))
  (if (vl-catch-all-error-p result)
    (setq layer (vla-Add layers name))
    (setq layer result)
  )
  layer
)

(defun dxgs:digit-string-p (s / idx ok ch)
  (if (null s)
    nil
    (progn
      (setq s (vl-string-trim " \t\r\n" s)
            idx 1
            ok (> (strlen s) 0))
      (while (and ok (<= idx (strlen s)))
        (setq ch (substr s idx 1))
        (if (not (wcmatch ch "#"))
          (setq ok nil)
        )
        (setq idx (1+ idx))
      )
      ok
    )
  )
)

(defun dxgs:auto-label-entity-p (ename / entdata typ layer obj objname text)
  (setq entdata (entget ename)
        typ (cdr (assoc 0 entdata))
        layer (cdr (assoc 8 entdata))
        obj (vlax-ename->vla-object ename)
        objname (vla-get-ObjectName obj))
  (and (= (strcase layer) (strcase (dxgs:config-label-layer)))
       (or (wcmatch (strcase objname) "*TDB*,*TCH*")
           (and (member typ '("TEXT" "MTEXT"))
                (progn
                  (setq text
                    (vl-catch-all-apply
                      '(lambda () (vla-get-TextString obj))
                      nil))
                  (if (vl-catch-all-error-p text)
                    (setq text (cdr (assoc 1 entdata)))
                  )
                  (dxgs:digit-string-p text)))))
)

(defun dxgs:cleanup-old-labels-at (pt / r p1 p2 ss idx en)
  (setq r *DXGS-CLEAN-RADIUS*
        p1 (list (- (car pt) r) (- (cadr pt) r) 0.0)
        p2 (list (+ (car pt) r) (+ (cadr pt) r) 0.0)
        ss (ssget "_C" p1 p2 (list (cons 8 (dxgs:config-label-layer))))
        idx 0)
  (while (and ss (< idx (sslength ss)))
    (setq en (ssname ss idx))
    (if (dxgs:auto-label-entity-p en)
      (entdel en)
    )
    (setq idx (1+ idx))
  )
)

(defun dxgs:check-bdxs-available ()
  (and (boundp 'C:BDXS) C:BDXS)
)

(defun dxgs:bdxs-count-supported-p (count)
  (and (numberp count) (<= 1 count) (<= count 8))
)

(defun dxgs:edge-bdxs-pick (edge / seg)
  (setq seg (dxgs:longest-segment (dxgs:get edge "segments")))
  (if seg
    (dxgs:midpoint (dxgs:get seg "p1") (dxgs:get seg "p2"))
    (dxgs:get edge "label_pt")
  )
)

(defun dxgs:add-edge-to-count-group (groups count edge / rec)
  (setq rec (assoc count groups))
  (if rec
    (subst (cons count (append (cdr rec) (list edge))) rec groups)
    (append groups (list (cons count (list edge))))
  )
)

(defun dxgs:group-edges-by-wire-count (edges / groups edge)
  (setq groups nil)
  (foreach edge edges
    (setq groups
      (dxgs:add-edge-to-count-group
        groups
        (dxgs:get edge "wire_count")
        edge))
  )
  groups
)

(defun dxgs:call-bdxs-for-edges (edges / groups group count edge)
  (if edges
    (progn
      (setq groups (dxgs:group-edges-by-wire-count edges))
      (princ (strcat "\n[DXGS] 正在调用天正 BDXS 标注 " (itoa (length edges)) " 个导线根数。"))
      (command *DXGS-BDXS-COMMAND*)
      (foreach group groups
        (setq count (car group))
        (command (itoa count))
        (foreach edge (cdr group)
          (command (dxgs:edge-bdxs-pick edge))
        )
      )
      (command "")
    )
  )
  T
)

(defun dxgs:create-text-labels (edges / edge)
  (foreach edge edges
    (dxgs:create-text-label edge)
  )
)

(defun dxgs:emit-bdxs-labels (edges / supported unsupported edge result)
  (setq supported nil
        unsupported nil)
  (foreach edge edges
    (if (dxgs:bdxs-count-supported-p (dxgs:get edge "wire_count"))
      (setq supported (append supported (list edge)))
      (setq unsupported (append unsupported (list edge)))
    )
  )
  (if unsupported
    (progn
      (princ
        (strcat "\n[DXGS] BDXS 仅支持 1~8 根，"
                (itoa (length unsupported)) " 个标注已改用 TEXT。"))
      (dxgs:create-text-labels unsupported))
  )
  (if supported
    (progn
      (setq result
        (vl-catch-all-apply 'dxgs:call-bdxs-for-edges (list supported)))
      (if (vl-catch-all-error-p result)
        (progn
          (princ
            (strcat "\n[DXGS] BDXS 标注失败，已改用 TEXT。错误: "
                    (vl-catch-all-error-message result)))
          (dxgs:create-text-labels supported))
      )
    )
  )
)

(defun dxgs:create-text-label (edge / pt text ent)
  (setq pt (dxgs:get edge "label_pt")
        text (itoa (dxgs:get edge "wire_count")))
  (setq ent
    (entmakex
      (list (cons 0 "TEXT")
            (cons 100 "AcDbEntity")
            (cons 8 (dxgs:config-label-layer))
            (cons 100 "AcDbText")
            (cons 10 pt)
            (cons 11 pt)
            (cons 40 *DXGS-TEXT-HEIGHT*)
            (cons 1 text)
            (cons 50 (dxgs:get edge "label_angle"))
            (cons 7 (getvar "TEXTSTYLE"))
            (cons 72 1)
            (cons 73 2))))
  ent
)

(defun dxgs:cleanup-and-label (edges method / edge total skipped label-edges)
  (dxgs:ensure-layer (dxgs:config-label-layer))
  (setvar "CLAYER" (dxgs:config-label-layer))
  (setq total 0
        skipped 0
        label-edges nil)
  (foreach edge edges
    (if (> (dxgs:get edge "wire_count") 0)
      (dxgs:cleanup-old-labels-at (dxgs:get edge "label_pt"))
    )
    (if (dxgs:get edge "need_label")
      (progn
        (setq label-edges (append label-edges (list edge)))
        (setq total (1+ total)))
      (if (> (dxgs:get edge "wire_count") 0)
        (setq skipped (1+ skipped))
      )
    )
  )
  (if (= (strcase method) "BDXS")
    (dxgs:emit-bdxs-labels label-edges)
    (dxgs:create-text-labels label-edges)
  )
  (list total skipped)
)

;;; ------------------------------------------------------------------------
;;; Prompts
;;; ------------------------------------------------------------------------

(defun dxgs:prompt-model (/ value normalized model)
  (setq value
    (dxgs:trim
      (getstring "\n接线模型 [A电源进灯盒(1)/B电源进开关(2)] <A>: ")))
  (if (= value "") (setq value "A"))
  (setq normalized (strcase value))
  (cond
    ((or (= normalized "A")
         (= normalized "1")
         (= value "电源进灯盒")
         (= value "灯盒"))
     (setq model "A"))
    ((or (= normalized "B")
         (= normalized "2")
         (= value "电源进开关")
         (= value "开关"))
     (setq model "B"))
    (t
     (princ (strcat "\n[DXGS] 未识别接线模型 [" value "]，使用默认 [A]。"))
     (setq model "A"))
  )
  model
)

(defun dxgs:prompt-filter (/ value normalized filter)
  (setq value
    (dxgs:trim
      (getstring "\n标注过滤 [All全部(1)/Skip2不标2根(2)/Skip3不标3根(3)] <Skip3>: ")))
  (if (= value "") (setq value "Skip3"))
  (setq normalized (strcase value))
  (cond
    ((or (= normalized "ALL")
         (= normalized "A")
         (= normalized "1")
         (= value "全部"))
     (setq filter "ALL"))
    ((or (= normalized "SKIP2")
         (= normalized "S2")
         (= normalized "2")
         (= value "不标2根")
         (= value "不标2"))
     (setq filter "SKIP2"))
    ((or (= normalized "SKIP3")
         (= normalized "S3")
         (= normalized "3")
         (= value "不标3根")
         (= value "不标3"))
     (setq filter "SKIP3"))
    (t
     (princ (strcat "\n[DXGS] 未识别标注过滤 [" value "]，使用默认 [Skip3]。"))
     (setq filter "SKIP3"))
  )
  filter
)

(defun dxgs:prompt-label-method (/ value normalized method default)
  (setq default (if *DXGS-USE-BDXS* "BDXS" "Text"))
  (setq value
    (dxgs:trim
      (getstring
        (strcat "\n标注方式 [Text普通文字(1)/BDXS天正导线根数(2)] <" default ">: "))))
  (if (= value "")
    (setq value default)
  )
  (setq normalized (strcase value))
  (cond
    ((or (= normalized "BDXS")
         (= normalized "B")
         (= normalized "2")
         (= value "天正")
         (= value "天正导线根数"))
     (setq method "BDXS"))
    ((or (= normalized "TEXT")
         (= normalized "T")
         (= normalized "1")
         (= value "普通文字")
         (= value "文字"))
     (setq method "TEXT"))
    (t
     (princ (strcat "\n[DXGS] 未识别标注方式 [" value "]，使用默认 [" default "]。"))
     (setq method (strcase default)))
  )
  (setq *DXGS-USE-BDXS* (= method "BDXS"))
  method
)

(defun C:DXGSSETUP (/ *error* doc old-cmd old-osm old-lay)
  (vl-load-com)

  (defun *error* (msg)
    (if doc (vla-EndUndoMark doc))
    (if old-cmd (setvar "CMDECHO" old-cmd))
    (if old-osm (setvar "OSMODE" old-osm))
    (if old-lay (setvar "CLAYER" old-lay))
    (if (and msg
             (not (member msg '("Function cancelled" "quit / exit abort" "console break"))))
      (princ (strcat "\n[DXGS] 配置错误: " msg))
    )
    (princ)
  )

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vla-StartUndoMark doc)
  (setq old-cmd (getvar "CMDECHO")
        old-osm (getvar "OSMODE")
        old-lay (getvar "CLAYER"))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)

  (dxgs:setup-config)

  (vla-EndUndoMark doc)
  (setvar "CMDECHO" old-cmd)
  (setvar "OSMODE" old-osm)
  (setvar "CLAYER" old-lay)
  (princ)
)

(defun C:DXGSCFG (/ cfg)
  (setq cfg (dxgs:config-load))
  (if (dxgs:config-valid-p cfg)
    (dxgs:config-summary cfg)
    (princ "\n[DXGS] 当前 DWG 尚未保存配置。运行 DXGSSETUP 建立配置。")
  )
  (princ)
)

;;; ------------------------------------------------------------------------
;;; Main command
;;; ------------------------------------------------------------------------

(defun C:DXGS (/ *error* doc old-cmd old-osm old-lay model filter label-method analysis-ss
                 power-pick power-ename power-handle power-point base-segments split-segments node-segments
                 devices lamps switches logical-edges adj source-edge root-node result label-count skip-count)
  (vl-load-com)

  (defun *error* (msg)
    (if doc (vla-EndUndoMark doc))
    (if old-cmd (setvar "CMDECHO" old-cmd))
    (if old-osm (setvar "OSMODE" old-osm))
    (if old-lay (setvar "CLAYER" old-lay))
    (if (and msg
             (not (member msg '("Function cancelled" "quit / exit abort" "console break"))))
      (princ (strcat "\n[DXGS] 错误: " msg))
    )
    (princ)
  )

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vla-StartUndoMark doc)
  (setq old-cmd (getvar "CMDECHO")
        old-osm (getvar "OSMODE")
        old-lay (getvar "CLAYER"))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)

  (dxgs:ensure-config)
  (setq model (dxgs:prompt-model))
  (setq filter (dxgs:prompt-filter))
  (setq label-method "BDXS")
  (setq *DXGS-USE-BDXS* T)

  (princ "\n请选择本次分析范围（包含导线、灯具、开关）。")
  (setq analysis-ss (ssget))
  (if (null analysis-ss)
    (dxgs:abort "未选择分析范围，命令结束。")
  )

  (setq power-pick (entsel "\n请选择电源来源管线: "))
  (if (null power-pick)
    (dxgs:abort "未选择电源来源管线，命令结束。")
  )
  (setq power-ename (car power-pick)
        power-handle (dxgs:entity-handle power-ename)
        power-point (dxgs:pt3 (cadr power-pick)))

  (setq lamps (dxgs:collect-devices analysis-ss "LAMP")
        switches (dxgs:collect-devices analysis-ss "SWITCH")
        devices (append lamps switches))
  (if (or (null lamps) (null switches))
    (dxgs:abort "在分析范围内未识别到已配置的灯具或开关，请运行 DXGSSETUP 检查配置。")
  )
  (princ
    (strcat "\n[DXGS] 已读取灯具 " (itoa (length lamps))
            " 个，开关 " (itoa (length switches)) " 个。"))

  (setq base-segments (dxgs:collect-wire-segments analysis-ss))
  (if (null base-segments)
    (dxgs:abort "分析范围内没有符合当前配置导线图层的管线。")
  )
  (setq split-segments (dxgs:split-t-junctions base-segments))
  (setq node-segments (dxgs:assign-nodes-to-segments split-segments devices))
  (if (null node-segments)
    (dxgs:abort "没有可用于拓扑分析的管线段。")
  )

  (setq logical-edges (dxgs:build-logical-edges node-segments devices))
  (setq adj (dxgs:build-adj logical-edges))
  (setq source-edge (dxgs:find-source-edge logical-edges power-handle power-point))
  (if (null source-edge)
    (progn
      (dxgs:print-source-edge-debug power-ename power-handle logical-edges)
      (dxgs:abort "电源来源管线不在已分析的管线集合中，或被图层过滤排除。")
    )
  )
  (setq root-node (dxgs:infer-root-node source-edge))
  (princ (strcat "\n[DXGS] 根节点: " root-node))

  (if (dxgs:component-cycle-p root-node adj logical-edges)
    (dxgs:abort "检测到封闭环路，请修正图纸后重新运行。")
  )

  (setq logical-edges (dxgs:assign-wires logical-edges root-node devices model filter))
  (setq result (dxgs:cleanup-and-label logical-edges label-method)
        label-count (car result)
        skip-count (cadr result))

  (vla-EndUndoMark doc)
  (setvar "CMDECHO" old-cmd)
  (setvar "OSMODE" old-osm)
  (setvar "CLAYER" old-lay)

  (princ
    (strcat "\n[DXGS] 导线根数标注计算已完成。输出标注 "
            (itoa label-count) " 个，按过滤规则跳过 "
            (itoa skip-count) " 个。"))
  (princ)
)

(princ "\nDXGS 已加载 multi-gang-select 2026-06-09。首次使用或修改配置运行 DXGSSETUP，查看配置运行 DXGSCFG，标注运行 DXGS。")
(princ)
