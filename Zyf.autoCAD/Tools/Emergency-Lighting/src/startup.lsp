;; Date: 2026-10-14. Resolve the current package without changing CAD security.
(defun EL:StartupCandidate (directory marker / root)
  ;; MainDialog may contain the selected filename, not only its directory.
  (if (and (equal (type directory) 'STR) (findfile directory)
           (not (vl-file-directory-p directory)))
    (setq directory (vl-filename-directory directory)))
  (if (setq root (EL:NormalizeRoot directory))
    (cond
      ((and (findfile (strcat root marker)) (EL:RootValid root)) root)
      ((and (findfile (strcat root "../" marker)) (EL:RootValid (strcat root "../")))
        (EL:NormalizeRoot (strcat root "../"))))))
(defun EL:StartupRegistryDirectory ()
  (vl-registry-read
    (strcat "HKEY_CURRENT_USER\\" (vlax-product-key)
      "\\Profiles\\" (getvar "CPROFILE") "\\Dialogs\\Appload") "MainDialog"))
(defun EL:StartupEmbeddedRoot () nil)
(defun EL:StartupUnwrap (value)
  (while (equal (type value) 'VARIANT) (setq value (vlax-variant-value value))) value)
(defun EL:StartupBinaryWork (path chunks / bytes expected)
  (if (EL:DLMkdir (vl-filename-directory path))
    (progn
      ;; Date: 2026-10-12. Native decode avoids millions of interpreted byte operations.
      (setq *EL:StartupStage* "BASE64_DECODE"
        *EL:StartupXML* (vlax-create-object "MSXML2.DOMDocument.6.0")
        *EL:StartupNode* (EL:StartupUnwrap (vlax-invoke-method *EL:StartupXML* 'createElement "binary")))
      (vlax-put-property *EL:StartupNode* 'dataType "bin.base64")
      (vlax-put-property *EL:StartupNode* 'text (EL:StoreJoinStrings chunks))
      (setq bytes (vlax-get-property *EL:StartupNode* 'nodeTypedValue))
      ;; Date: 2026-10-14. Canonical Base64 is an exact byte comparison, including
      ;; MSXML's line wrapping. Keep SAFEARRAYs native instead of making two
      ;; multi-million-element LISP lists for the bundled DWGs and slides.
      (vlax-put-property *EL:StartupNode* 'nodeTypedValue bytes)
      (setq expected (vlax-get-property *EL:StartupNode* 'text)
        *EL:StartupStream* (vlax-create-object "ADODB.Stream"))
      (vlax-put-property *EL:StartupStream* 'Type 1)
      ;; Date: 2026-10-12. Visual LISP needs all five ADO optional slots.
      (setq *EL:StartupStage* "STREAM_OPEN")
      (vlax-invoke-method *EL:StartupStream* 'Open nil 0 -1 "" "")
      (setq *EL:StartupStage* "BINARY_WRITE")
      (vlax-invoke-method *EL:StartupStream* 'Write bytes)
      ;; Only the versioned runtime seed is replaced, never the user's library.
      (setq *EL:StartupStage* "SAVE_TO_FILE")
      (vlax-invoke-method *EL:StartupStream* 'SaveToFile path 2)
      (setq *EL:StartupStage* "BINARY_READBACK")
      (vlax-invoke-method *EL:StartupStream* 'LoadFromFile path)
      (vlax-put-property *EL:StartupNode* 'nodeTypedValue
        (vlax-invoke-method *EL:StartupStream* 'Read -1))
      (equal expected (vlax-get-property *EL:StartupNode* 'text)))))
(defun EL:StartupWriteBase64 (path chunks / result object *EL:StartupStream* *EL:StartupStage* *EL:StartupXML* *EL:StartupNode*)
  (setq *EL:StartupStage* "STREAM_CREATE")
  (setq result (vl-catch-all-apply 'EL:StartupBinaryWork (list path chunks)))
  (if *EL:StartupStream* (vl-catch-all-apply 'vlax-invoke-method (list *EL:StartupStream* 'Close)))
  (foreach object (list *EL:StartupStream* *EL:StartupNode* *EL:StartupXML*)
    (if object (vl-catch-all-apply 'vlax-release-object (list object))))
  (if (vl-catch-all-error-p result)
    (setq *EL:StartupError* (strcat path " [" *EL:StartupStage* "] : " (vl-catch-all-error-message result)))
    (if (not result)
      (setq *EL:StartupError* (strcat path " [" *EL:StartupStage* "] : 文件写入或完整回读校验失败"))))
  (and (not (vl-catch-all-error-p result)) result))
(defun EL:StartupResource (writer path data / result)
  (setq result (vl-catch-all-apply writer (list path data)))
  (if (or (vl-catch-all-error-p result) (not result))
    (progn
      (if (not *EL:StartupError*)
        (setq *EL:StartupError* (strcat path " : "
          (if (vl-catch-all-error-p result) (vl-catch-all-error-message result) "文件写入或回读校验失败"))))
      nil)
    T))
(defun EL:StartupSelectRoot (marker / path)
  ;; Date: 2026-10-10. A confirmed package path keeps diagnostics beside the ZIP.
  (princ "\n请选择解压包内的 START-CAD2020.lsp；日志将保存在该包的 output 文件夹。")
  (if (setq path (getfiled "确认应急照明交付目录" "START-CAD2020.lsp" "lsp" 0))
    (EL:StartupCandidate path marker)))
(defun EL:StartupRememberRoot (root marker)
  (if root (vl-catch-all-apply 'setenv (list (strcat "EL_PACKAGE_ROOT_" marker) root)))
  root)
(defun c:ELROOT (/ root)
  (if (and *EL:PackageMarker* (setq root (EL:StartupSelectRoot *EL:PackageMarker*)))
    (progn
      (setq *EL:Root* (EL:StartupRememberRoot root *EL:PackageMarker*))
      (princ (strcat "\n插件数据目录已设置：" root "；后续日志保存在 output 文件夹。")))
    (princ "\n未选择当前版本的完整交付目录，原目录保持不变。"))
  (princ))
(defun EL:StartupWriteLines (path lines / stream result line)
  (if (setq stream (open path "w"))
    (progn
      (setq result (vl-catch-all-apply
        '(lambda () (foreach line lines (write-line line stream))) nil))
      (close stream)
      (if (not (vl-catch-all-error-p result))
        (progn
          (setq stream (open path "r") result T)
          (if stream
            (progn
              (foreach line lines
                (if (not (equal line (read-line stream))) (setq result nil)))
              (if (read-line stream) (setq result nil))
              (close stream) result)))))))
(defun EL:StartupFindRoot (marker / directory root path filename)
  ;; APPLOAD's last folder is only a candidate: require this version's marker
  ;; and the complete package before using it. No stale-root fallback.
  (setq directory (vl-catch-all-apply 'EL:StartupRegistryDirectory nil))
  (if (not (vl-catch-all-error-p directory))
    (setq root (EL:StartupCandidate directory marker)))
  (if (and (not root) (setq path (findfile marker)))
    (setq root (EL:StartupCandidate (vl-filename-directory path) marker)))
  ;; A support path can point at src, where the package marker is not visible.
  (foreach filename '("START-CAD2020.lsp" "load.lsp")
    (if (and (not root) (setq path (findfile filename)))
      (setq root (EL:StartupCandidate path marker))))
  (if (not root)
    (setq root (EL:StartupCandidate (getenv (strcat "EL_PACKAGE_ROOT_" marker)) marker)))
  root)
(defun EL:StartupRoot (marker / root)
  (setq *EL:StartupAttempted* T *EL:StartupError* nil
    root (EL:PerfCall "LOAD_ROOT_SEARCH" 'EL:StartupFindRoot (list marker)))
  ;; Never prompt during startup. Manual relocation belongs to c:ELROOT only.
  (if (not root)
    (progn
      (setq root (vl-catch-all-apply 'EL:PerfCall
        (list "LOAD_RUNTIME" 'EL:StartupEmbeddedRoot nil)))
      (if (vl-catch-all-error-p root)
        (setq *EL:StartupError* (vl-catch-all-error-message root) root nil))
      (if root (princ "\n未确认交付目录，暂用本地运行目录；输入 ELROOT 可改回交付包目录。"))))
  (setq *EL:Root* root *EL:PackageMarker* marker)
  (if root (EL:StartupRememberRoot root marker))
  (if root (princ (strcat "\n插件数据目录：" root))
    (princ (strcat "\n自动初始化失败："
      (cond (*EL:StartupError*) (T "无法建立完整本地运行目录，请检查 LOCALAPPDATA 路径。")))))
  root)
(defun EL:StartupCommandHint (ready)
  ;; Date: 2026-10-15. Print after the loading logs and timing report.
  (princ (if ready "\n启动命令：输入 ELSTAT 开始统计；ELDEVLIB 打开设备库。"
    "\n启动未完成：请修复上方初始化错误后重新加载；需要切换目录时运行 ELROOT。")))
