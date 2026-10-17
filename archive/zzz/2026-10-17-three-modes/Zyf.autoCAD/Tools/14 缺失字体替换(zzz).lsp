; CAD 字体工具：修复缺失字体、指定字体替换、全图统一字体，命令：ZZZ
; 日期：2026-10-17
; 编码：严格 GB2312，无 BOM
; 加载时只注册命令；所有修改由用户主动执行，使用当前活动图纸。

(vl-load-com)

(defun ZZZ:TextP (value)
  (and (= (type value) 'STR) (> (strlen value) 0)))

(defun ZZZ:FileName (path)
  (strcat (vl-filename-base path) (if (vl-filename-extension path) (vl-filename-extension path) "")))

(defun ZZZ:SplitPaths (text / pos paths)
  (while (and (ZZZ:TextP text) (setq pos (vl-string-search ";" text)))
    (if (> pos 0) (setq paths (cons (substr text 1 pos) paths)))
    (setq text (substr text (+ pos 2))))
  (if (ZZZ:TextP text) (setq paths (cons text paths)))
  (reverse paths))

(defun ZZZ:FontDirs (/ dirs dir known path result seen root)
  (setq dirs (ZZZ:SplitPaths (getvar "ACADPREFIX")))
  (setq dirs (cons (getvar "DWGPREFIX") dirs))
  (foreach known '("txt.shx" "simplex.shx" "gbcbig.shx" "tssdchn.shx")
    (if (setq path (findfile known)) (setq dirs (cons (vl-filename-directory path) dirs))))
  (if (setq path (findfile "acad.exe"))
    (setq dirs (cons (strcat (vl-filename-directory path) "\\Fonts") dirs)))
  (if (and (boundp '*fstl_dir*) (ZZZ:TextP *fstl_dir*))
    (setq dirs (cons (strcat *fstl_dir* "\\support") dirs)))
  (if (setq root (getenv "WINDIR")) (setq dirs (append dirs (list (strcat root "\\Fonts")))))
  (if (setq root (getenv "LOCALAPPDATA"))
    (setq dirs (append dirs (list (strcat root "\\Microsoft\\Windows\\Fonts")))))
  (foreach dir dirs
    (if (and (ZZZ:TextP dir) (vl-file-directory-p dir) (not (member (strcase dir) seen)))
      (setq result (cons dir result) seen (cons (strcase dir) seen))))
  (reverse result))

(defun ZZZ:FindFont (file dirs / base dir path)
  (if (ZZZ:TextP file)
    (progn
      (setq base (ZZZ:FileName file) path (findfile file))
      (if (not path) (setq path (findfile base)))
      (foreach dir dirs
        (if (not path) (setq path (findfile (strcat dir "\\" base)))))
      path)))

(defun ZZZ:SHXName (name)
  (if (and (ZZZ:TextP name) (not (vl-filename-extension name))) (strcat name ".shx") name))

(defun ZZZ:SHXKind (file / stream header byte count)
  ; SHX 文件只读取 ASCII 文件头，不按文本重写二进制文件。
  (if (and (ZZZ:TextP file) (setq stream (open file "r")))
    (progn
      (setq header "" count 0)
      (while (and (< count 40) (setq byte (read-char stream)) (> byte 0) (not (member byte '(10 13 26))))
        (setq header (strcat header (chr byte)) count (1+ count)))
      (close stream)
      (cond ((wcmatch (strcase header T) "*bigfont*") "BIG")
            ((wcmatch (strcase header T) "*unifont*,*shapes*") "SHX")))))

(defun ZZZ:SHXLists (dirs / dir files file path kind seen regular big)
  (foreach dir dirs
    (setq files (vl-catch-all-apply 'vl-directory-files (list dir "*.shx" 1)))
    (if (not (vl-catch-all-error-p files))
      (foreach file files
        (if (not (member (strcase file) seen))
          (progn
            ; 与实际替换使用同一搜索顺序，避免同名字体在不同目录中类型不一致。
            (setq path (ZZZ:FindFont file dirs)
                  kind (vl-catch-all-apply 'ZZZ:SHXKind (list path))
                  seen (cons (strcase file) seen))
            (cond ((equal kind "SHX") (setq regular (cons file regular)))
                  ((equal kind "BIG") (setq big (cons file big)))))))))
  (list (acad_strlsort regular) (acad_strlsort big)))

(defun ZZZ:FaceSpec (face / spec found)
  (foreach spec '(("微软雅黑" "Microsoft YaHei" "msyh.ttc" 134)
                 ("仿宋" "FangSong" "simfang.ttf" 134)
                 ("Malgun Gothic" "Malgun Gothic" "malgun.ttf" 129)
                 ("黑体" "SimHei" "simhei.ttf" 134)
                 ("楷体" "KaiTi" "simkai.ttf" 134)
                 ("宋体" "SimSun" "simsun.ttc" 134)
                 ("新宋体" "NSimSun" "simsun.ttc" 134))
    (if (and (ZZZ:TextP face)
             (or (= (strcase face) (strcase (car spec))) (= (strcase face) (strcase (cadr spec)))))
      (setq found spec)))
  found)

(defun ZZZ:TTFTarget (face dirs / spec path)
  (if (and (setq spec (ZZZ:FaceSpec face)) (setq path (ZZZ:FindFont (nth 2 spec) dirs)))
    (list "TTF" (cadr spec) path (nth 3 spec))
    (strcat "未找到字体文件：" (if spec (nth 2 spec) (if face face "未选择字体")))))

(defun ZZZ:SHXTarget (regular big dirs / mainpath bigpath)
  (setq regular (ZZZ:SHXName regular) big (ZZZ:SHXName big))
  (cond
    ((not (setq mainpath (ZZZ:FindFont regular dirs))) (strcat "未找到 SHX 字体：" (if regular regular "未选择字体")))
    ((not (equal (ZZZ:SHXKind mainpath) "SHX")) (strcat "不是常规 SHX 字体：" regular))
    ((and (ZZZ:TextP big) (not (setq bigpath (ZZZ:FindFont big dirs)))) (strcat "未找到大字体：" big))
    ((and bigpath (not (equal (ZZZ:SHXKind bigpath) "BIG"))) (strcat "不是 SHX 大字体：" big))
    (T (list "SHX" mainpath (if bigpath bigpath "")))))

(defun ZZZ:BigTarget (name dirs / path)
  (cond ((not (setq path (ZZZ:FindFont (ZZZ:SHXName name) dirs))) "未找到所选大字体文件。")
        ((not (equal (ZZZ:SHXKind path) "BIG")) "所选文件不是 SHX 大字体。")
        (T (list "BIG" path))))

(defun ZZZ:ResolveRequest (request dirs / target)
  (cond
    ((= (car request) "REPLACE")
      (cond
        ((not (cadr request)) "请先选择图中的源字体。")
        ((not (member (car (cadr request)) '("MAIN" "BIG"))) "源字体类型无效，请重新选择。")
        ((and (equal (car (cadr request)) "BIG") (not (equal (car (nth 2 request)) "BIG")))
          "替换大字体时，目标也必须为大字体。")
        ((and (equal (car (cadr request)) "MAIN") (equal (car (nth 2 request)) "BIG"))
          "替换主字体时，请选择 Windows 或 SHX 主字体。")
        (T
          (setq target (ZZZ:ResolveRequest (nth 2 request) dirs))
          (if (= (type target) 'STR) target (list "REPLACE" (cadr request) target)))))
    ((= (car request) "TTF") (ZZZ:TTFTarget (cadr request) dirs))
    ((= (car request) "BIG") (ZZZ:BigTarget (cadr request) dirs))
    ((= (car request) "SHX")
      (if (eq (nth 2 request) 'KEEP)
        (progn
          (setq target (ZZZ:SHXTarget (cadr request) "" dirs))
          (if (= (type target) 'STR) target (list "SHX" (cadr target) 'KEEP)))
        (ZZZ:SHXTarget (cadr request) (nth 2 request) dirs)))
    (T request)))

(defun ZZZ:GetFont (style / face bold italic charset pitch)
  (vla-GetFont style 'face 'bold 'italic 'charset 'pitch)
  (list face bold italic charset pitch))

(defun ZZZ:SameFace (first second / spec)
  (or (= (strcase first) (strcase second))
      (and (setq spec (ZZZ:FaceSpec first))
           (or (= (strcase second) (strcase (car spec))) (= (strcase second) (strcase (cadr spec)))))))

(defun ZZZ:SameFile (first second dirs / path)
  (or (equal (strcase first) (strcase second))
      (and (setq path (ZZZ:FindFont first dirs)) (= (strcase path) (strcase second)))))

(defun ZZZ:Matches (style target dirs / font main big)
  (setq main (vla-get-FontFile style) big (vla-get-BigFontFile style))
  (cond
    ((= (car target) "BIG") (ZZZ:SameFile big (cadr target) dirs))
    ((= (car target) "SHX")
      (and (ZZZ:SameFile main (cadr target) dirs)
           (or (eq (nth 2 target) 'KEEP) (ZZZ:SameFile big (nth 2 target) dirs))))
    (T
      (setq font (ZZZ:GetFont style))
      (and (ZZZ:SameFile main (nth 2 target) dirs) (= big "")
           (ZZZ:SameFace (car font) (cadr target)) (= (nth 3 font) (nth 3 target))
           (/= 0 (logand 4 (nth 4 font)))))))

(defun ZZZ:MissingTarget (data font dirs / main big path mainpath bigpath installed)
  (setq main (cdr (assoc 3 data)) big (cdr (assoc 4 data)))
  (if (not main) (setq main ""))
  (if (not big) (setq big ""))
  (setq path (ZZZ:FindFont (ZZZ:SHXName main) dirs))
  ; 先看文件类型，不用 GetFont 的字体名是否为空来猜测 SHX/TTF。
  (if (or (wcmatch (strcase main) "*.TTF,*.TTC,*.OTF")
          (and (= main "") (ZZZ:TextP (car font))))
    (if (not path)
      (progn
        (setq installed (ZZZ:TTFTarget (car font) dirs))
        (if (listp installed) installed (ZZZ:TTFTarget "仿宋" dirs))))
    (if (or (not path) (and (ZZZ:TextP big) (not (ZZZ:FindFont (ZZZ:SHXName big) dirs))))
      (progn
        (setq mainpath (if path path "tssdeng.shx"))
        ; 原样式没有大字体时保持为空，不能把单字体样式强行改成复合字体。
        (setq bigpath (if (ZZZ:TextP big) (ZZZ:FindFont (ZZZ:SHXName big) dirs) ""))
        (if (null bigpath) (setq bigpath "tssdchn.shx"))
        (ZZZ:SHXTarget mainpath bigpath dirs)))))

; 日期：2026-10-17。按实际字体引用归并源字体，不按文字样式名称猜测。
(defun ZZZ:EditableStyleP (name data / flags)
  (setq flags (cdr (assoc 70 data)))
  (and (not (wcmatch name "*|*")) (= 0 (logand (if flags flags 0) 17))))

(defun ZZZ:SourceKey (data font component / file face spec)
  (setq file (cdr (assoc (if (= component "BIG") 4 3) data)))
  (if (not file) (setq file ""))
  (if (= component "BIG")
    (list "BIG" (strcase (if (ZZZ:TextP file) (ZZZ:FileName (ZZZ:SHXName file)) "")))
    (progn
      (setq face (car font))
      (if (not (ZZZ:TextP face)) (setq face ""))
      (if (or (wcmatch (strcase file) "*.TTF,*.TTC,*.OTF") (and (= file "") (/= face "")))
        (progn
          (if (setq spec (ZZZ:FaceSpec face)) (setq face (cadr spec)))
          ; TTC 的不同字体族分别归并，例如宋体和新宋体不能混为一组。
          (list "MAIN" "TTF" (strcase (if (ZZZ:TextP file) (ZZZ:FileName file) "")) (strcase face)))
        (list "MAIN" "SHX" (strcase (if (ZZZ:TextP file) (ZZZ:FileName (ZZZ:SHXName file)) "")))))))

(defun ZZZ:SourceLabel (data font component / key file face spec)
  (setq key (ZZZ:SourceKey data font component))
  (setq file (cdr (assoc (if (= component "BIG") 4 3) data)))
  (if (not (ZZZ:TextP file)) (setq file "(未设置字体文件)"))
  (cond
    ((= component "BIG") (strcat "大字体: " (ZZZ:FileName file)))
    ((= (cadr key) "SHX") (strcat "主字体 / SHX: " (ZZZ:FileName file)))
    (T
      (setq face (car font))
      (if (not (ZZZ:TextP face)) (setq face "未记录字体名"))
      (if (setq spec (ZZZ:FaceSpec face)) (setq face (car spec)))
      (strcat "主字体 / Windows: " face " [" (ZZZ:FileName file) "]"))))

(defun ZZZ:StyleSources (style / name data font items big)
  (setq name (vla-get-Name style) data (entget (vlax-vla-object->ename style)))
  (if (not (ZZZ:EditableStyleP name data)) 'SKIP
    (progn
      (setq font (ZZZ:GetFont style))
      (setq items (list (list (ZZZ:SourceKey data font "MAIN") (ZZZ:SourceLabel data font "MAIN"))))
      (if (ZZZ:TextP (cdr (assoc 4 data)))
        (setq items (append items (list (list (ZZZ:SourceKey data font "BIG") (ZZZ:SourceLabel data font "BIG"))))))
      items)))

(defun ZZZ:AddSource (sources key label / entry result found)
  (foreach entry sources
    (if (equal (car entry) key)
      (setq entry (list key (cadr entry) (1+ (nth 2 entry))) found T))
    (setq result (cons entry result)))
  (if (not found) (setq result (cons (list key label 1) result)))
  (reverse result))

(defun ZZZ:SourceCatalog (doc / style items item sources eligible failed)
  (setq eligible 0 failed 0)
  (vlax-for style (vla-get-TextStyles doc)
    (setq items (vl-catch-all-apply 'ZZZ:StyleSources (list style)))
    (cond
      ((vl-catch-all-error-p items) (setq failed (1+ failed)))
      ((eq items 'SKIP) nil)
      (T
        (setq eligible (1+ eligible))
        (foreach item items (setq sources (ZZZ:AddSource sources (car item) (cadr item)))))))
  (list sources eligible failed))

(defun ZZZ:FindSource (key sources / entry found)
  (foreach entry sources (if (equal key (car entry)) (setq found entry)))
  found)

(defun ZZZ:SourceLabels (sources / entry result)
  (foreach entry sources
    (setq result (cons (strcat (cadr entry) " (" (itoa (nth 2 entry)) " 个样式)") result)))
  (reverse result))

(defun ZZZ:MixedTarget (name dirs)
  (cond ((wcmatch (strcase name) "*仿宋*,*FANGSONG*") (ZZZ:TTFTarget "仿宋" dirs))
        ((wcmatch (strcase name) "*宋体*,*SIMSUN*") (ZZZ:TTFTarget "宋体" dirs))
        ((wcmatch (strcase name) "*黑体*,*SIMHEI*") (ZZZ:TTFTarget "黑体" dirs))
        ((wcmatch (strcase name) "*楷体*,*KAITI*") (ZZZ:TTFTarget "楷体" dirs))
        (T (ZZZ:SHXTarget "tssdeng.shx" "tssdchn.shx" dirs))))

(defun ZZZ:ClearBigFont (style / result data)
  (if (/= (vla-get-BigFontFile style) "")
    (progn
      (setq result (vl-catch-all-apply 'vla-put-BigFontFile (list style "")))
      (if (vl-catch-all-error-p result)
        (progn
          (setq data (entget (vlax-vla-object->ename style)))
          (if (not (entmod (if (assoc 4 data) (subst '(4 . "") (assoc 4 data) data) (append data '((4 . ""))))))
            (setq result "无法清空原大字体")
            (setq result T)))
        (setq result T)))
    (setq result T))
  (if (and (eq result T) (/= (vla-get-BigFontFile style) "")) (setq result "大字体清空后读回不一致"))
  result)

(defun ZZZ:WriteStyle (style target font dirs / result actual original-main original-big)
  (setq original-main (vla-get-FontFile style) original-big (vla-get-BigFontFile style) result T)
  (cond
    ((= (car target) "BIG") (vla-put-BigFontFile style (cadr target)))
    ((= (car target) "TTF")
      ; 必须先清大字体，再写文件，最后设置字体名，保留原粗体及斜体。
      (setq result (ZZZ:ClearBigFont style))
      (if (eq result T)
        (progn
          (vla-put-FontFile style (nth 2 target))
          (vla-SetFont style (cadr target) (nth 1 font) (nth 2 font) (nth 3 target) (logior 4 (nth 4 font))))))
    (T
      (if (equal (nth 2 target) "") (setq result (ZZZ:ClearBigFont style)))
      (if (eq result T)
        (progn
          (vla-put-FontFile style (cadr target))
          (if (and (not (eq (nth 2 target) 'KEEP)) (ZZZ:TextP (nth 2 target)))
            (vla-put-BigFontFile style (nth 2 target)))))))
  (if (and (eq result T) (not (ZZZ:Matches style target dirs))) (setq result "字体设置后读回不一致"))
  (if (eq result T)
    (cond
      ((= (car target) "BIG")
        (if (or (/= original-main (vla-get-FontFile style)) (not (equal font (ZZZ:GetFont style))))
          (setq result "替换大字体后主字体发生变化，已拒绝本次写入")))
      ((and (= (car target) "SHX") (eq (nth 2 target) 'KEEP))
        (if (/= original-big (vla-get-BigFontFile style)) (setq result "原大字体未能保持，已拒绝本次写入")))
      ((= (car target) "TTF")
        (setq actual (ZZZ:GetFont style))
        (if (or (not (equal (nth 1 font) (nth 1 actual))) (not (equal (nth 2 font) (nth 2 actual))))
          (setq result "字体替换后粗体或斜体读回不一致")))))
  result)

(defun ZZZ:RestoreStyle (style before font / after)
  ; 直接恢复原记录及 XData，也能恢复指向缺失字体的原始引用。
  (and (entmod before)
       (setq after (entget (vlax-vla-object->ename style) '("*")))
       (equal (assoc 3 before) (assoc 3 after)) (equal (assoc 4 before) (assoc 4 after))
       (equal (assoc -3 before) (assoc -3 after)) (equal font (ZZZ:GetFont style))))

(defun ZZZ:CancelledP (message)
  (wcmatch (strcase message) "*CANCEL*,*QUIT*,*BREAK*,*取消*"))

(defun ZZZ:ProcessStyle (style request dirs / name before font target result restored message)
  (setq name (vla-get-Name style) before (entget (vlax-vla-object->ename style) '("*")))
  (cond
    ((not (ZZZ:EditableStyleP name before)) 'SKIP)
    (T
      (setq font (ZZZ:GetFont style))
      (if (and (= (car request) "REPLACE")
               (not (equal (cadr request) (ZZZ:SourceKey before font (car (cadr request))))))
        'NOTMATCHED
        (progn
          (setq target (cond ((= (car request) "MISSING") (ZZZ:MissingTarget before font dirs))
                             ((= (car request) "MIXED") (ZZZ:MixedTarget name dirs))
                             ((= (car request) "REPLACE") (nth 2 request)) (T request)))
          (cond
            ((null target) 'UNCHANGED)
            ((= (type target) 'STR) target)
            ((ZZZ:Matches style target dirs) 'UNCHANGED)
            (T
              (setq result (vl-catch-all-apply 'ZZZ:WriteStyle (list style target font dirs)))
              (if (eq result T) 'CHANGED
                (progn
                  (setq message (if (vl-catch-all-error-p result) (vl-catch-all-error-message result) result))
                  (setq restored (vl-catch-all-apply 'ZZZ:RestoreStyle (list style before font)))
                  (if (not (eq restored T)) (princ (strcat "\n[ZZZ] 样式 " name " 恢复失败，请用 U 撤销本次操作。")))
                  (if (ZZZ:CancelledP message) (quit))
                  message)))))))))

(defun ZZZ:FillList (key items / item)
  (start_list key)
  (foreach item items (add_list item))
  (end_list)
  (mode_tile key (if items 0 1))
  (if items (set_tile key "0")))

(defun ZZZ:Selected (key values / index)
  (if (and values (ZZZ:TextP (get_tile key)))
    (progn (setq index (atoi (get_tile key))) (if (>= index 0) (nth index values)))))

(defun ZZZ:FillOptions (key labels values selected / index)
  (ZZZ:FillList key labels)
  (if values
    (progn
      (setq index (vl-position selected values))
      (if (null index) (setq index 0))
      (set_tile key (itoa index))
      (nth index values))))

(defun ZZZ:EnsureSHX (/ lists)
  (if (not zzz-scanned)
    (progn
      (setq lists (ZZZ:SHXLists zzz-dirs) zzz-unis (car lists) zzz-bigs (cadr lists) zzz-scanned T))))

(defun ZZZ:CaptureUI (/ entry picked)
  ; 对话框状态局部绑定；切换模式和字体类型前保存已选内容。
  (if (= zzz-mode "REPLACE")
    (if (setq entry (ZZZ:Selected "source" zzz-sources)) (setq zzz-source-key (car entry))))
  (if (/= zzz-mode "MISSING")
    (progn
      (setq picked (ZZZ:Selected "pop1" zzz-target-values))
      (if picked
        (cond ((= zzz-effective-kind "TTF") (setq zzz-ttf picked))
              ((= zzz-effective-kind "SHX") (setq zzz-shx picked))
              ((= zzz-effective-kind "BIG") (setq zzz-big-target picked))))
      (if (= zzz-effective-kind "SHX")
        (if (setq picked (ZZZ:Selected "pop2" zzz-big-values))
          (if (= zzz-mode "REPLACE") (setq zzz-replace-big picked) (setq zzz-all-big picked)))))))

(defun ZZZ:UpdateScope (/ entry read-note)
  (setq entry (ZZZ:FindSource zzz-source-key zzz-sources))
  (setq read-note (if (> zzz-unread 0) (strcat "；另有 " (itoa zzz-unread) " 个样式无法读取") ""))
  (cond
    ((= zzz-mode "MISSING")
      (set_tile "scope1" "范围：只修复找不到字体文件的引用，已正常引用的字体保持不变。")
      (set_tile "scope2" "补缺：SHX 用 tssdeng.shx；大字体用 tssdchn.shx；Windows 用原字体或仿宋。")
      (set_tile "source_info" "自动查找缺失字体，无需选择源字体；此功能不保证解决所有乱码。"))
    ((= zzz-mode "REPLACE")
      (set_tile "scope1" (if entry (strcat "范围：仅替换使用所选源字体的 " (itoa (nth 2 entry)) " 个文字样式，其他样式不动。")
                                  "范围：仅替换使用所选源字体的文字样式，请先选择源字体。"))
      (set_tile "scope2" (if (= zzz-effective-kind "BIG") "只替换大字体，保留这些样式的主字体。"
                           "替换主字体；目标为 SHX 时，可保留或重新指定大字体。"))
      (set_tile "source_info" (strcat "按图中记录的主字体/大字体匹配，不按样式名称猜测" read-note "。")))
    (T
      (set_tile "scope1" (strcat "范围：当前图纸全部可修改的文字样式，包括未使用样式；已读取 " (itoa zzz-eligible) " 个。"))
      (set_tile "scope2" "所有这些样式统一为下方目标字体，会影响使用它们的文字。")
      (set_tile "source_info" (strcat "当前模式无需选择源字体" read-note "。")))))

(defun ZZZ:Render (/ source-entry big-only chosen labels ready)
  (set_tile "error" "")
  (set_tile "mode_missing" (if (= zzz-mode "MISSING") "1" "0"))
  (set_tile "mode_replace" (if (= zzz-mode "REPLACE") "1" "0"))
  (set_tile "mode_all" (if (= zzz-mode "ALL") "1" "0"))
  (setq source-entry (ZZZ:FindSource zzz-source-key zzz-sources))
  (if source-entry (setq chosen (vl-position source-entry zzz-sources)) (setq chosen 0))
  (ZZZ:FillList "source" (ZZZ:SourceLabels zzz-sources))
  (if zzz-sources (set_tile "source" (itoa chosen)))
  (mode_tile "source" (if (and (= zzz-mode "REPLACE") zzz-sources) 0 1))
  (setq big-only (and (= zzz-mode "REPLACE") (equal (car zzz-source-key) "BIG")))
  (setq zzz-effective-kind (if big-only "BIG" zzz-main-kind))
  (set_tile "pop1-t" (if big-only "目标大字体:" "目标字体:"))
  (set_tile "pop2-t" "配套大字体:")
  (setq ready T)
  (cond
    ((= zzz-mode "MISSING")
      (ZZZ:FillList "target_kind" '("自动补缺"))
      (ZZZ:FillList "pop1" '("按上方补缺规则自动修复"))
      (ZZZ:FillList "pop2" '("仅修复原来引用的大字体"))
      (setq zzz-target-values nil zzz-big-values nil)
      (mode_tile "target_kind" 1) (mode_tile "pop1" 1) (mode_tile "pop2" 1)
      (set_tile "target_hint" "修复模式无需设置目标；下方字体选择用于另外两种模式。")
      (set_tile "ok" "修复缺失字体"))
    (T
      (set_tile "ok" (if (= zzz-mode "REPLACE") "执行指定替换" "统一全图字体"))
      (if big-only
        (progn (ZZZ:FillList "target_kind" '("SHX 大字体")) (mode_tile "target_kind" 1))
        (ZZZ:FillOptions "target_kind" '("Windows 常用字体" "SHX 字体") '("TTF" "SHX") zzz-main-kind))
      (cond
        ((= zzz-effective-kind "TTF")
          (setq zzz-target-values zzz-ttfs zzz-big-values nil)
          (setq zzz-ttf (ZZZ:FillOptions "pop1" zzz-ttfs zzz-target-values zzz-ttf))
          (ZZZ:FillList "pop2" '("Windows 字体无需设置大字体")) (mode_tile "pop2" 1)
          (set_tile "target_hint" "保留原粗体、斜体；字体改变可能影响文字的实际显示宽度。"))
        ((= zzz-effective-kind "BIG")
          (ZZZ:EnsureSHX)
          (setq zzz-target-values zzz-bigs zzz-big-values nil)
          (setq zzz-big-target (ZZZ:FillOptions "pop1" zzz-bigs zzz-target-values zzz-big-target))
          (ZZZ:FillList "pop2" '("只替换上方大字体，主字体保留")) (mode_tile "pop2" 1)
          (set_tile "target_hint" "目标列表仅列出可用的大字体文件，不改变所选样式的主字体。"))
        (T
          (ZZZ:EnsureSHX)
          (setq zzz-target-values zzz-unis)
          (setq zzz-shx (ZZZ:FillOptions "pop1" zzz-unis zzz-target-values zzz-shx))
          (setq zzz-big-values (cons "" zzz-bigs) labels (cons "不使用大字体" zzz-bigs))
          (if (= zzz-mode "REPLACE")
            (setq zzz-big-values (cons 'KEEP zzz-big-values) labels (cons "保留各样式原大字体" labels)))
          (setq chosen (ZZZ:FillOptions "pop2" labels zzz-big-values (if (= zzz-mode "REPLACE") zzz-replace-big zzz-all-big)))
          (if (= zzz-mode "REPLACE") (setq zzz-replace-big chosen) (setq zzz-all-big chosen))
          (set_tile "target_hint" (if (= zzz-mode "REPLACE") "可只换主字体；选择保留大字体时，不会重写原大字体引用。"
                                       "主字体与大字体按上方设置统一；中文 SHX 通常需要配套的大字体。"))))
      (cond
        ((and (= zzz-mode "REPLACE") (not source-entry)) (setq ready nil) (set_tile "error" "当前图纸没有可选择的源字体。"))
        ((= zzz-eligible 0) (setq ready nil) (set_tile "error" "当前图纸没有可读取、可修改的文字样式。"))
        ((not zzz-target-values) (setq ready nil) (set_tile "error" "未找到该类型的可用目标字体，请更换字体类型或检查字体目录。")))))
  (mode_tile "ok" (if ready 0 1))
  (ZZZ:UpdateScope))

(defun ZZZ:ChangeMode (mode)
  (ZZZ:CaptureUI) (setq zzz-mode mode) (ZZZ:Render))

(defun ZZZ:SourceChanged ()
  (ZZZ:CaptureUI) (ZZZ:Render))

(defun ZZZ:KindChanged (/ selected)
  (ZZZ:CaptureUI)
  (if (setq selected (ZZZ:Selected "target_kind" '("TTF" "SHX"))) (setq zzz-main-kind selected))
  (ZZZ:Render))

(defun ZZZ:Accept (/ request target resolved)
  (ZZZ:CaptureUI)
  (if (= zzz-mode "MISSING")
    (setq request '("MISSING"))
    (progn
      (setq target (cond ((= zzz-effective-kind "BIG") (list "BIG" zzz-big-target))
                         ((= zzz-effective-kind "TTF") (list "TTF" zzz-ttf))
                         (T (list "SHX" zzz-shx (if (= zzz-mode "REPLACE") zzz-replace-big zzz-all-big)))))
      (setq request (if (= zzz-mode "REPLACE") (list "REPLACE" zzz-source-key target) target))))
  (setq resolved (ZZZ:ResolveRequest request zzz-dirs))
  (if (= (type resolved) 'STR) (set_tile "error" resolved)
    (progn (setq zzz-choice resolved) (done_dialog 1))))

(defun ZZZ:WriteDialog (stream / line)
  ; 日期：2026-10-17。三种模式分别解释范围；字段和底部按钮统一尺寸。
  (foreach line
    '("zzz_action_button : button { width = 22; height = 1.6; fixed_width = true; fixed_height = true; }"
      "zzz_font_label : text { width = 14; fixed_width = true; }"
      "zzz_font_popup : popup_list { width = 66; fixed_width = true; }"
      "fonts:dialog { label = \"字体修复与替换\"; initial_focus = \"mode_missing\";"
      "  :boxed_radio_column { label = \"选择处理模式\";"
      "    :radio_button { key = \"mode_missing\"; label = \"修复缺失字体：只修复找不到的字体，正常字体不动\"; value = \"1\"; }"
      "    :radio_button { key = \"mode_replace\"; label = \"指定字体替换：把图中的某一种字体换成目标字体\"; }"
      "    :radio_button { key = \"mode_all\"; label = \"全图统一字体：全部可修改的文字样式统一为目标字体\"; } }"
      "  :boxed_column { label = \"本次作用范围\";"
      "    :text { key = \"scope1\"; width = 88; } :text { key = \"scope2\"; width = 88; } }"
      "  :boxed_column { label = \"源字体（仅指定字体替换使用）\";"
      "    :row { children_alignment = centered; :zzz_font_label { label = \"源字体:\"; } :zzz_font_popup { key = \"source\"; } }"
      "    :text { key = \"source_info\"; width = 88; } }"
      "  :boxed_column { label = \"目标字体（指定字体替换 / 全图统一字体使用）\";"
      "    :row { children_alignment = centered; :zzz_font_label { label = \"字体类型:\"; } :zzz_font_popup { key = \"target_kind\"; } }"
      "    :row { children_alignment = centered; :zzz_font_label { key = \"pop1-t\"; label = \"目标字体:\"; } :zzz_font_popup { key = \"pop1\"; } }"
      "    :row { children_alignment = centered; :zzz_font_label { key = \"pop2-t\"; label = \"配套大字体:\"; } :zzz_font_popup { key = \"pop2\"; } }"
      "    :text { key = \"target_hint\"; width = 88; } }"
      "  :text { key = \"error\"; width = 88; }"
      "  :row { children_alignment = centered; :zzz_action_button { key = \"16\"; label = \"关闭并刷新\"; }"
      "    :zzz_action_button { key = \"ok\"; label = \"修复缺失字体\"; } :zzz_action_button { key = \"cancel\"; label = \"关闭\"; is_cancel = true; } }"
      "  :text { label = \"作用对象是当前图纸的文字样式；跳过外部参照和形样式。\"; }"
      "  :text { label = \"文字内容、字高、宽度因子和旋转不改；不清除多行文字内部单独设置的字体。\"; }"
      "}")
    (write-line line stream)))

(defun ZZZ:Dialog (doc zzz-dirs / zzz-choice zzz-sources zzz-eligible zzz-unread catalog zzz-mode zzz-source-key
                                   zzz-main-kind zzz-effective-kind zzz-ttfs zzz-unis zzz-bigs zzz-scanned
                                   zzz-ttf zzz-shx zzz-big-target zzz-replace-big zzz-all-big zzz-target-values zzz-big-values face result)
  (setq catalog (ZZZ:SourceCatalog doc) zzz-sources (car catalog) zzz-eligible (nth 1 catalog) zzz-unread (nth 2 catalog))
  (setq zzz-mode "MISSING" zzz-main-kind "TTF" zzz-effective-kind "TTF" zzz-replace-big 'KEEP zzz-all-big "")
  (if zzz-sources (setq zzz-source-key (car (car zzz-sources))))
  (foreach face '("宋体" "仿宋" "微软雅黑" "黑体" "楷体" "新宋体" "Malgun Gothic")
    (if (listp (ZZZ:TTFTarget face zzz-dirs)) (setq zzz-ttfs (append zzz-ttfs (list face)))))
  (setq zzz-ttf (car zzz-ttfs))
  (action_tile "mode_missing" "(ZZZ:ChangeMode \"MISSING\")")
  (action_tile "mode_replace" "(ZZZ:ChangeMode \"REPLACE\")")
  (action_tile "mode_all" "(ZZZ:ChangeMode \"ALL\")")
  (action_tile "source" "(ZZZ:SourceChanged)") (action_tile "target_kind" "(ZZZ:KindChanged)")
  (action_tile "pop1" "(ZZZ:CaptureUI)") (action_tile "pop2" "(ZZZ:CaptureUI)")
  (action_tile "ok" "(ZZZ:Accept)") (action_tile "16" "(done_dialog 16)")
  (action_tile "cancel" "(done_dialog 0)")
  (ZZZ:Render)
  (setq result (start_dialog))
  (cond ((= result 1) zzz-choice) ((= result 16) '("REGEN"))))

(defun ZZZ:RequestName (request)
  (cond ((= (car request) "MISSING") "修复缺失字体")
        ((= (car request) "REPLACE") "指定字体替换")
        ((= (car request) "MIXED") "按样式名称混合替换（兼容命令）")
        (T "全图统一字体")))

(defun ZZZ:Cleanup (doc undo dclid active file stream echo)
  (if active (vl-catch-all-apply 'done_dialog '(0)))
  (if (and dclid (> dclid 0)) (vl-catch-all-apply 'unload_dialog (list dclid)))
  (if stream (vl-catch-all-apply 'close (list stream)))
  (if file (vl-catch-all-apply 'vl-file-delete (list file)))
  (if undo (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
  (if echo (vl-catch-all-apply 'setvar (list "CMDECHO" echo))))

(defun ZZZ:Run (request / *error* doc echo dirs fname stream dclid active undo target style result changed unchanged skipped failed unmatched)
  (defun *error* (message)
    (ZZZ:Cleanup doc undo dclid active fname stream echo)
    (if (not (ZZZ:CancelledP message)) (princ (strcat "\n[ZZZ] " message)))
    (if (and changed (> changed 0))
      (progn
        (vl-catch-all-apply 'vla-Regen (list doc 1))
        (princ (strcat "\n[ZZZ] 本次已修改 " (itoa changed) " 个样式，可用 U 撤销。"))))
    (princ))
  (setq echo (getvar "CMDECHO") doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setvar "CMDECHO" 0)
  (setq dirs (ZZZ:FontDirs))
  (if (not request)
    (progn
      (setq fname (vl-filename-mktemp "zzz-" nil ".dcl") stream (open fname "w"))
      (if stream
        (progn
          (ZZZ:WriteDialog stream) (close stream) (setq stream nil)
          (setq dclid (load_dialog fname))
          (if (and dclid (> dclid 0) (new_dialog "fonts" dclid))
            (progn (setq active T request (ZZZ:Dialog doc dirs) active nil))
            (alert "ZZZ：字体窗口加载失败，请检查临时目录及 DCL 文件。")))
        (alert "ZZZ：无法创建临时 DCL 文件，请检查临时目录写入权限。"))))
  ; 对话框关闭、卸载后才允许修改图纸或重生成。
  (if (and dclid (> dclid 0)) (progn (unload_dialog dclid) (setq dclid nil)))
  (cond
    ((null request) nil)
    ((= (car request) "REGEN") (vla-Regen doc 1) (princ "\n[ZZZ] 已重新生成所有视口。"))
    (T
      (setq target (ZZZ:ResolveRequest request dirs))
      (if (= (type target) 'STR) (alert (strcat "ZZZ：" target "\n请安装字体或将字体目录加入支持文件搜索路径。"))
        (progn
          (setq changed 0 unchanged 0 skipped 0 failed 0 unmatched 0)
          (princ (strcat "\n[ZZZ] 模式：" (ZZZ:RequestName target)))
          ; 不关闭调用者已经打开的撤销分组。
          (if (and (/= 0 (logand 1 (getvar "UNDOCTL"))) (= 0 (logand 8 (getvar "UNDOCTL"))))
            (progn (vla-StartUndoMark doc) (setq undo T)))
          (vlax-for style (vla-get-TextStyles doc)
            (setq result (vl-catch-all-apply 'ZZZ:ProcessStyle (list style target dirs)))
            (if (vl-catch-all-error-p result)
              (progn
                (if (ZZZ:CancelledP (vl-catch-all-error-message result)) (quit))
                (setq result (vl-catch-all-error-message result))))
            (cond ((eq result 'CHANGED) (setq changed (1+ changed)))
                  ((eq result 'UNCHANGED) (setq unchanged (1+ unchanged)))
                  ((eq result 'SKIP) (setq skipped (1+ skipped)))
                  ((eq result 'NOTMATCHED) (setq unmatched (1+ unmatched)))
                  (T (setq failed (1+ failed)) (princ (strcat "\n[ZZZ] 样式 " (vla-get-Name style) "：" result)))))
          (if (> changed 0)
            (progn
              (setq result (vl-catch-all-apply 'vla-Regen (list doc 1)))
              (if (vl-catch-all-error-p result) (princ (strcat "\n[ZZZ] 字体已修改，显示刷新失败：" (vl-catch-all-error-message result))))))
          (princ (strcat "\n[ZZZ] 已修改 " (itoa changed) "，无需修改 " (itoa unchanged)
                         "，跳过 " (itoa skipped) "，失败 " (itoa failed) " 个文字样式。"
                         (if (= (car target) "REPLACE") (strcat " 未匹配源字体 " (itoa unmatched) " 个样式保持原样。") "")))))))
  (ZZZ:Cleanup doc undo dclid active fname stream echo)
  (princ))

(defun c:ZZZ () (ZZZ:Run nil))
; 保留原程序的快捷命令，统一使用相同的当前文档和错误清理流程。
(defun c:FONTSTOFH () (ZZZ:Run '("MIXED")))
(defun c:FONTSTOFZ () (ZZZ:Run '("SHX" "tssdeng.shx" "tssdchn.shx")))
(defun c:FONTSTOGB () (ZZZ:Run '("SHX" "gbenor.shx" "gbcbig.shx")))
(defun c:FONTSTOFS () (ZZZ:Run '("TTF" "仿宋")))
(defun c:REGENLOCAL () (ZZZ:Run '("REGEN")))
(defun c:R () (c:REGENLOCAL))

(princ "\n字体替换工具已加载，输入 ZZZ 打开窗口。")
(princ)
