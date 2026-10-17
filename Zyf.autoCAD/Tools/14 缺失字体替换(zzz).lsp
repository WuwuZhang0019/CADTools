; CAD 字体批量替换与缺失字体修复，命令：ZZZ
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
  (if (= (car target) "SHX")
    (and (ZZZ:SameFile main (cadr target) dirs) (ZZZ:SameFile big (nth 2 target) dirs))
    (progn
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

(defun ZZZ:WriteStyle (style target font dirs / result actual)
  (if (= (car target) "TTF")
    (progn
      ; 必须先清大字体，再写文件，最后设置字体名，避免后续写文件清掉字体描述符。
      (setq result (ZZZ:ClearBigFont style))
      (if (eq result T)
        (progn
          (vla-put-FontFile style (nth 2 target))
          (vla-SetFont style (cadr target) (nth 1 font) (nth 2 font) (nth 3 target) (logior 4 (nth 4 font))))))
    (progn
      (if (= (nth 2 target) "") (setq result (ZZZ:ClearBigFont style)) (setq result T))
      (if (eq result T)
        (progn
          (vla-put-FontFile style (cadr target))
          (if (ZZZ:TextP (nth 2 target)) (vla-put-BigFontFile style (nth 2 target)))))))
  (if (eq result T)
    (if (not (ZZZ:Matches style target dirs))
      (setq result "字体设置后读回不一致")
      (if (= (car target) "TTF")
        (progn
          (setq actual (ZZZ:GetFont style))
          (if (or (not (equal (nth 1 font) (nth 1 actual))) (not (equal (nth 2 font) (nth 2 actual))))
            (setq result "字体替换后粗体或斜体读回不一致"))))))
  result)

(defun ZZZ:RestoreStyle (style before font / after)
  ; 直接恢复原记录及 XData，也能恢复指向缺失字体的原始引用。
  (and (entmod before)
       (setq after (entget (vlax-vla-object->ename style) '("*")))
       (equal (assoc 3 before) (assoc 3 after)) (equal (assoc 4 before) (assoc 4 after))
       (equal (assoc -3 before) (assoc -3 after)) (equal font (ZZZ:GetFont style))))

(defun ZZZ:CancelledP (message)
  (wcmatch (strcase message) "*CANCEL*,*QUIT*,*BREAK*,*取消*"))

(defun ZZZ:ProcessStyle (style request dirs / name before flags font target result restored message)
  (setq name (vla-get-Name style) before (entget (vlax-vla-object->ename style) '("*"))
        flags (cdr (assoc 70 before)))
  (cond
    ((or (wcmatch name "*|*") (/= 0 (logand (if flags flags 0) 17))) 'SKIP)
    (T
      (setq font (ZZZ:GetFont style))
      (setq target (cond ((= (car request) "MISSING") (ZZZ:MissingTarget before font dirs))
                         ((= (car request) "MIXED") (ZZZ:MixedTarget name dirs)) (T request)))
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
              message)))))))

(defun ZZZ:FillList (key items / item)
  (start_list key)
  (foreach item items (add_list item))
  (end_list)
  (mode_tile key (if items 0 1))
  (if items (set_tile key "0")))

(defun ZZZ:ToggleFonts (/ lists)
  ; zzz-* 变量由 ZZZ:Dialog 局部绑定，仅在该对话框回调期间使用。
  (set_tile "error" "")
  (if (= (get_tile "sydzt") "1")
    (progn
      (if (not zzz-scanned)
        (progn
          (setq lists (ZZZ:SHXLists zzz-dirs) zzz-unis (car lists) zzz-bigs (cadr lists) zzz-scanned T)))
      (set_tile "pop1-t" "SHX 字体:") (set_tile "pop2-t" "大字体:")
      (ZZZ:FillList "pop1" zzz-unis) (ZZZ:FillList "pop2" zzz-bigs)
      (mode_tile "ok" (if (and zzz-unis zzz-bigs) 0 1))
      (if (not (and zzz-unis zzz-bigs)) (set_tile "error" "未找到可用的 SHX 字体组合，请检查支持文件搜索路径。")))
    (progn
      (set_tile "pop1-t" "Windows 字体:") (set_tile "pop2-t" "字体样式:")
      (ZZZ:FillList "pop1" zzz-ttfs) (ZZZ:FillList "pop2" nil)
      (mode_tile "ok" (if zzz-ttfs 0 1))
      (if (not zzz-ttfs) (set_tile "error" "未找到预设的 Windows 字体文件。")))))

(defun ZZZ:Selected (key values / index)
  (if (and values (ZZZ:TextP (get_tile key)))
    (progn (setq index (atoi (get_tile key))) (if (>= index 0) (nth index values)))))

(defun ZZZ:AcceptCustom (/ first second)
  (if (= (get_tile "sydzt") "1")
    (progn
      (setq first (ZZZ:Selected "pop1" zzz-unis) second (ZZZ:Selected "pop2" zzz-bigs))
      (if (and first second) (setq zzz-choice (list "SHX" first second))))
    (if (setq first (ZZZ:Selected "pop1" zzz-ttfs)) (setq zzz-choice (list "TTF" first))))
  (if zzz-choice (done_dialog 1) (set_tile "error" "请先选择有效的字体。")))

(defun ZZZ:WriteDialog (stream / line)
  ; 日期：2026-10-17。六个功能按钮统一尺寸，说明列统一宽度和起点。
  (foreach line
    '("zzz_action_button : button { width = 22; height = 1.6; fixed_width = true; fixed_height = true; }"
      "zzz_action_note : text { width = 44; fixed_width = true; fixed_height = true; }"
      "fonts:dialog { label = \"CAD 字体批量替换\"; initial_focus = \"11\";"
      "  :column { children_alignment = left; children_fixed_width = true;"
      "    :row { children_alignment = centered; :zzz_action_button { key = \"11\"; label = \"1.修复缺失(&K)\"; } :zzz_action_note { label = \"保留可用字体，只修复缺失的字体引用\"; } }"
      "    :row { children_alignment = centered; :zzz_action_button { key = \"12\"; label = \"2.混合字型(&F)\"; } :zzz_action_note { label = \"按样式名称选择宋体、黑体等，其余用 SHX\"; } }"
      "    :row { children_alignment = centered; :zzz_action_button { key = \"13\"; label = \"3.方正字型(&Z)\"; } :zzz_action_note { label = \"全部文字样式使用 tssdeng + tssdchn\"; } }"
      "    :row { children_alignment = centered; :zzz_action_button { key = \"14\"; label = \"4.国标字型(&G)\"; } :zzz_action_note { label = \"全部文字样式使用 gbenor + gbcbig\"; } }"
      "    :row { children_alignment = centered; :zzz_action_button { key = \"15\"; label = \"5.仿宋字型(&S)\"; } :zzz_action_note { label = \"全部文字样式使用仿宋\"; } }"
      "    :row { children_alignment = centered; :zzz_action_button { key = \"16\"; label = \"6.刷新显示(&R)\"; } :zzz_action_note { label = \"重新生成所有视口，更新字体显示\"; } }"
      "  }"
      "  spacer; :boxed_column { label = \"7.自定义字型\";"
      "    :row { :column {"
      "      :row { :text { key = \"pop1-t\"; label = \"Windows 字体:\"; width = 16; } :popup_list { key = \"pop1\"; width = 24; } }"
      "      :row { :text { key = \"pop2-t\"; label = \"字体样式:\"; width = 16; } :popup_list { key = \"pop2\"; width = 24; } }"
      "    } :column { :toggle { key = \"sydzt\"; label = \"使用大字体\"; value = \"0\"; }"
      "      :button { key = \"ok\"; label = \"修改\"; } } } }"
      "  :text { key = \"error\"; label = \"\"; width = 64; }"
      "  :text { label = \"作用于文字样式；跳过外部参照和形样式。\"; }"
      "  :button { key = \"cancel\"; label = \"关闭\"; is_cancel = true; fixed_width = true; alignment = centered; }"
      "}")
    (write-line line stream)))

(defun ZZZ:Dialog (zzz-dirs / zzz-choice zzz-unis zzz-bigs zzz-ttfs zzz-scanned face result)
  (foreach face '("微软雅黑" "仿宋" "Malgun Gothic" "黑体" "楷体" "宋体" "新宋体")
    (if (listp (ZZZ:TTFTarget face zzz-dirs)) (setq zzz-ttfs (append zzz-ttfs (list face)))))
  (action_tile "11" "(done_dialog 11)") (action_tile "12" "(done_dialog 12)")
  (action_tile "13" "(done_dialog 13)") (action_tile "14" "(done_dialog 14)")
  (action_tile "15" "(done_dialog 15)") (action_tile "16" "(done_dialog 16)")
  (action_tile "cancel" "(done_dialog 0)")
  (action_tile "sydzt" "(ZZZ:ToggleFonts)") (action_tile "ok" "(ZZZ:AcceptCustom)")
  (ZZZ:ToggleFonts)
  (setq result (start_dialog))
  (cond ((= result 1) zzz-choice)
        ((= result 11) '("MISSING")) ((= result 12) '("MIXED"))
        ((= result 13) '("SHX" "tssdeng.shx" "tssdchn.shx"))
        ((= result 14) '("SHX" "gbenor.shx" "gbcbig.shx"))
        ((= result 15) '("TTF" "仿宋")) ((= result 16) '("REGEN"))))

(defun ZZZ:Cleanup (doc undo dclid active file stream echo)
  (if active (vl-catch-all-apply 'done_dialog '(0)))
  (if (and dclid (> dclid 0)) (vl-catch-all-apply 'unload_dialog (list dclid)))
  (if stream (vl-catch-all-apply 'close (list stream)))
  (if file (vl-catch-all-apply 'vl-file-delete (list file)))
  (if undo (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
  (if echo (vl-catch-all-apply 'setvar (list "CMDECHO" echo))))

(defun ZZZ:Run (request / *error* doc echo dirs fname stream dclid active undo target style result changed unchanged skipped failed)
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
            (progn (setq active T request (ZZZ:Dialog dirs) active nil))
            (alert "ZZZ：字体窗口加载失败，请检查临时目录及 DCL 文件。")))
        (alert "ZZZ：无法创建临时 DCL 文件，请检查临时目录写入权限。"))))
  ; 对话框关闭、卸载后才允许修改图纸或重生成。
  (if (and dclid (> dclid 0)) (progn (unload_dialog dclid) (setq dclid nil)))
  (cond
    ((null request) nil)
    ((= (car request) "REGEN") (vla-Regen doc 1) (princ "\n[ZZZ] 已重新生成所有视口。"))
    (T
      (setq target (cond ((= (car request) "TTF") (ZZZ:TTFTarget (cadr request) dirs))
                         ((= (car request) "SHX") (ZZZ:SHXTarget (cadr request) (nth 2 request) dirs)) (T request)))
      (if (= (type target) 'STR) (alert (strcat "ZZZ：" target "\n请安装字体或将字体目录加入支持文件搜索路径。"))
        (progn
          (setq changed 0 unchanged 0 skipped 0 failed 0)
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
                  (T (setq failed (1+ failed)) (princ (strcat "\n[ZZZ] 样式 " (vla-get-Name style) "：" result)))))
          (if (> changed 0)
            (progn
              (setq result (vl-catch-all-apply 'vla-Regen (list doc 1)))
              (if (vl-catch-all-error-p result) (princ (strcat "\n[ZZZ] 字体已修改，显示刷新失败：" (vl-catch-all-error-message result))))))
          (princ (strcat "\n[ZZZ] 已修改 " (itoa changed) "，无需修改 " (itoa unchanged)
                         "，跳过 " (itoa skipped) "，失败 " (itoa failed) " 个文字样式。"))))))
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
