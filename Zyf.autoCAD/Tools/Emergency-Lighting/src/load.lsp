;; Date: 2026-10-16. UTF-8 source template; build emits strict GB2312.
;; CADTools sets *EL:CADToolsRoot* to this module's installation directory.
(setq *EL:BootstrapTick* (getvar "MILLISECS"))
(vl-load-com)
(setq *EL:LiteVersion* "lite-v0.1.61" *EL:LiteMarker* "lite-v0.1.61.marker"
  *EL:LiteFiles* '("assets/default-device-library/assets/ELDEV1/1/block.dwg"
    "assets/default-device-library/assets/ELDEV1/1/legend.sld"
    "assets/default-device-library/assets/ELDEV10/1/block.dwg"
    "assets/default-device-library/assets/ELDEV10/1/legend.sld"
    "assets/default-device-library/assets/ELDEV11/1/block.dwg"
    "assets/default-device-library/assets/ELDEV11/1/legend.sld"
    "assets/default-device-library/assets/ELDEV12/1/block.dwg"
    "assets/default-device-library/assets/ELDEV12/1/legend.sld"
    "assets/default-device-library/assets/ELDEV13/1/block.dwg"
    "assets/default-device-library/assets/ELDEV13/1/legend.sld"
    "assets/default-device-library/assets/ELDEV14/1/block.dwg"
    "assets/default-device-library/assets/ELDEV14/1/legend.sld"
    "assets/default-device-library/assets/ELDEV15/1/block.dwg"
    "assets/default-device-library/assets/ELDEV15/1/legend.sld"
    "assets/default-device-library/assets/ELDEV16/1/block.dwg"
    "assets/default-device-library/assets/ELDEV16/1/legend.sld"
    "assets/default-device-library/assets/ELDEV17/1/block.dwg"
    "assets/default-device-library/assets/ELDEV17/1/legend.sld"
    "assets/default-device-library/assets/ELDEV18/1/block.dwg"
    "assets/default-device-library/assets/ELDEV18/1/legend.sld"
    "assets/default-device-library/assets/ELDEV19/1/block.dwg"
    "assets/default-device-library/assets/ELDEV19/1/legend.sld"
    "assets/default-device-library/assets/ELDEV2/1/block.dwg"
    "assets/default-device-library/assets/ELDEV2/1/legend.sld"
    "assets/default-device-library/assets/ELDEV20/1/block.dwg"
    "assets/default-device-library/assets/ELDEV20/1/legend.sld"
    "assets/default-device-library/assets/ELDEV21/1/block.dwg"
    "assets/default-device-library/assets/ELDEV21/1/legend.sld"
    "assets/default-device-library/assets/ELDEV22/1/block.dwg"
    "assets/default-device-library/assets/ELDEV22/1/legend.sld"
    "assets/default-device-library/assets/ELDEV23/1/block.dwg"
    "assets/default-device-library/assets/ELDEV23/1/legend.sld"
    "assets/default-device-library/assets/ELDEV24/1/block.dwg"
    "assets/default-device-library/assets/ELDEV24/1/legend.sld"
    "assets/default-device-library/assets/ELDEV25/1/block.dwg"
    "assets/default-device-library/assets/ELDEV25/1/legend.sld"
    "assets/default-device-library/assets/ELDEV26/1/block.dwg"
    "assets/default-device-library/assets/ELDEV26/1/legend.sld"
    "assets/default-device-library/assets/ELDEV27/1/block.dwg"
    "assets/default-device-library/assets/ELDEV27/1/legend.sld"
    "assets/default-device-library/assets/ELDEV28/1/block.dwg"
    "assets/default-device-library/assets/ELDEV28/1/legend.sld"
    "assets/default-device-library/assets/ELDEV29/1/block.dwg"
    "assets/default-device-library/assets/ELDEV29/1/legend.sld"
    "assets/default-device-library/assets/ELDEV3/1/block.dwg"
    "assets/default-device-library/assets/ELDEV3/1/legend.sld"
    "assets/default-device-library/assets/ELDEV30/1/block.dwg"
    "assets/default-device-library/assets/ELDEV30/1/legend.sld"
    "assets/default-device-library/assets/ELDEV31/1/block.dwg"
    "assets/default-device-library/assets/ELDEV31/1/legend.sld"
    "assets/default-device-library/assets/ELDEV32/1/block.dwg"
    "assets/default-device-library/assets/ELDEV32/1/legend.sld"
    "assets/default-device-library/assets/ELDEV33/1/block.dwg"
    "assets/default-device-library/assets/ELDEV33/1/legend.sld"
    "assets/default-device-library/assets/ELDEV34/1/block.dwg"
    "assets/default-device-library/assets/ELDEV34/1/legend.sld"
    "assets/default-device-library/assets/ELDEV35/1/block.dwg"
    "assets/default-device-library/assets/ELDEV35/1/legend.sld"
    "assets/default-device-library/assets/ELDEV36/1/block.dwg"
    "assets/default-device-library/assets/ELDEV36/1/legend.sld"
    "assets/default-device-library/assets/ELDEV37/1/block.dwg"
    "assets/default-device-library/assets/ELDEV37/1/legend.sld"
    "assets/default-device-library/assets/ELDEV38/1/block.dwg"
    "assets/default-device-library/assets/ELDEV38/1/legend.sld"
    "assets/default-device-library/assets/ELDEV39/1/block.dwg"
    "assets/default-device-library/assets/ELDEV39/1/legend.sld"
    "assets/default-device-library/assets/ELDEV4/1/block.dwg"
    "assets/default-device-library/assets/ELDEV4/1/legend.sld"
    "assets/default-device-library/assets/ELDEV40/1/block.dwg"
    "assets/default-device-library/assets/ELDEV40/1/legend.sld"
    "assets/default-device-library/assets/ELDEV41/1/block.dwg"
    "assets/default-device-library/assets/ELDEV41/1/legend.sld"
    "assets/default-device-library/assets/ELDEV42/1/block.dwg"
    "assets/default-device-library/assets/ELDEV42/1/legend.sld"
    "assets/default-device-library/assets/ELDEV43/1/block.dwg"
    "assets/default-device-library/assets/ELDEV43/1/legend.sld"
    "assets/default-device-library/assets/ELDEV44/1/block.dwg"
    "assets/default-device-library/assets/ELDEV44/1/legend.sld"
    "assets/default-device-library/assets/ELDEV45/1/block.dwg"
    "assets/default-device-library/assets/ELDEV45/1/legend.sld"
    "assets/default-device-library/assets/ELDEV46/1/block.dwg"
    "assets/default-device-library/assets/ELDEV46/1/legend.sld"
    "assets/default-device-library/assets/ELDEV47/1/block.dwg"
    "assets/default-device-library/assets/ELDEV47/1/legend.sld"
    "assets/default-device-library/assets/ELDEV48/1/block.dwg"
    "assets/default-device-library/assets/ELDEV48/1/legend.sld"
    "assets/default-device-library/assets/ELDEV49/1/block.dwg"
    "assets/default-device-library/assets/ELDEV49/1/legend.sld"
    "assets/default-device-library/assets/ELDEV5/1/block.dwg"
    "assets/default-device-library/assets/ELDEV5/1/legend.sld"
    "assets/default-device-library/assets/ELDEV6/1/block.dwg"
    "assets/default-device-library/assets/ELDEV6/1/legend.sld"
    "assets/default-device-library/assets/ELDEV7/1/block.dwg"
    "assets/default-device-library/assets/ELDEV7/1/legend.sld"
    "assets/default-device-library/assets/ELDEV8/1/block.dwg"
    "assets/default-device-library/assets/ELDEV8/1/legend.sld"
    "assets/default-device-library/assets/ELDEV9/1/block.dwg"
    "assets/default-device-library/assets/ELDEV9/1/legend.sld"
    "assets/default-device-library/catalog.eld"
    "assets/default-device-library/legacy-defaults.eld"
    "assets/default-device-library/published-power-source.eld"
    "lite-v0.1.61.marker"
    "src/batch-number.lsp"
    "src/circuit-number.lsp"
    "src/common.lsp"
    "src/config.lsp"
    "src/device-assets.lsp"
    "src/device-defaults.lsp"
    "src/device-inputs.lsp"
    "src/device-library.lsp"
    "src/device-migration.lsp"
    "src/device-recognition.lsp"
    "src/device-ui.lsp"
    "src/diagram-commands.lsp"
    "src/diagram-store.lsp"
    "src/diagram-update.lsp"
    "src/fixed.lsp"
    "src/generation.lsp"
    "src/geometry.lsp"
    "src/insert-circuit.lsp"
    "src/load.lsp"
    "src/main.lsp"
    "src/panel.lsp"
    "src/simple.lsp"
    "src/startup.lsp"
    "src/statistics.lsp"
    "src/store-compact.lsp"
    "src/store-split.lsp"
    "src/topology.lsp"
    "templates/系统图块库.dwg"
    "ui/box-ui-011.marker"
    "ui/device-library.dcl"
    "ui/diagram-ui-025.marker"
    "ui/diagram-ui-028.marker"
    "ui/diagram-ui-029.marker"
    "ui/diagram-ui-031.marker"
    "ui/diagram-ui-044.marker"
    "ui/power.dcl"))
(defun EL:LiteNormalize (root)
  (if (and (equal (type root) 'STR) (/= root ""))
    (strcat (vl-string-right-trim "/\\" root) "/")))
(defun EL:LiteRootValid (root / ok relative)
  (if (setq root (EL:LiteNormalize root))
    (progn (setq ok T)
      (foreach relative *EL:LiteFiles*
        (if (not (findfile (strcat root relative))) (setq ok nil))) ok)))
(defun EL:LiteCandidate (path / root)
  (if (and (equal (type path) 'STR) (/= path ""))
    (progn
      (if (and (findfile path) (not (vl-file-directory-p path)))
        (setq path (vl-filename-directory path)))
      (setq root (EL:LiteNormalize path))
      (cond ((EL:LiteRootValid root) root)
        ((and root (EL:LiteRootValid (strcat root "../"))) (strcat root "../"))))))
(defun EL:LiteFindRoot (/ root path)
  ;; An explicit but broken install must fail, never silently load another copy.
  (if *EL:CADToolsRoot*
    (EL:LiteCandidate *EL:CADToolsRoot*)
    (progn
      (setq path (vl-registry-read
        (strcat "HKEY_CURRENT_USER\\" (vlax-product-key)
          "\\Profiles\\" (getvar "CPROFILE") "\\Dialogs\\Appload") "MainDialog")
        root (EL:LiteCandidate path))
      (if (not root) (setq root (EL:LiteCandidate (findfile *EL:LiteMarker*))))
      (if (not root) (setq root (EL:LiteCandidate
        (getenv (strcat "EL_CADTOOLS_" *EL:LiteVersion*))))) root)))
(defun EL:LiteInitData (/ base folder ok)
  (setq *EL:LiteDataRoot* nil)
  (if (setq base (EL:LiteNormalize (getenv "LOCALAPPDATA")))
    (progn
      (setq ok T)
      (foreach folder '("Emergency-Lighting/" "Emergency-Lighting/CADTools/"
                        "Emergency-Lighting/CADTools/config/" "Emergency-Lighting/CADTools/output/")
        (if (not (or (vl-file-directory-p (strcat base folder))
                     (vl-mkdir (strcat base folder)))) (setq ok nil)))
      (if ok (setq *EL:LiteDataRoot* (strcat base "Emergency-Lighting/CADTools/"))))))
(defun EL:LiteRelocate (/ path root)
  (if (setq path (getfiled "选择精简版 src/load.lsp" "" "lsp" 0))
    (if (setq root (EL:LiteCandidate path))
      (progn (setq *EL:CADToolsRoot* root) (EL:LiteLoad))
      (princ "\n所选目录不是当前精简版的完整运行目录，原目录保持不变。"))))
(defun EL:LiteLoadWork (/ root module token)
  (setq root (EL:LiteFindRoot))
  (cond
    ((not root) (setq *EL:StartupError* "精简版运行文件不完整或目录未指定，请检查 CADTools 安装目录。") nil)
    ((not (EL:LiteInitData)) (setq *EL:StartupError* "无法建立当前用户数据目录，请检查 LOCALAPPDATA。") nil)
    (T
      (setq *EL:Root* root)
      (foreach module '("common" "config" "geometry" "topology" "statistics" "device-library" "device-assets" "device-defaults" "device-ui" "device-recognition" "device-inputs" "device-migration" "generation" "main" "simple" "circuit-number" "fixed" "panel" "store-compact" "diagram-store" "store-split" "diagram-update" "diagram-commands" "insert-circuit" "startup" "batch-number")
        (if (equal module "common")
          (progn (load (strcat root "src/common.lsp"))
            (EL:MonitorLoadBegin *EL:BootstrapTick*))
          (progn
            (setq *EL:MonitorLabel* (strcat module ".lsp") token (EL:PerfBegin "LOAD_MODULE"))
            (load (strcat root "src/" module ".lsp"))
            (EL:PerfEnd token 'returned) (setq *EL:MonitorLabel* nil))))
      (defun c:ELROOT () (EL:LiteRelocate) (princ))
      (EL:ClearPickHighlights)
      (setq *EL:Result* nil *EL:DeviceResult* nil)
      (EL:PerfCall "LOAD_LIBRARY" 'EL:DLDefaultStartup nil)
      (setenv (strcat "EL_CADTOOLS_" *EL:LiteVersion*) root)
      T)))
(defun EL:LiteLoad (/ result)
  (setq *EL:BootstrapTick* (getvar "MILLISECS")
    *EL:Root* nil *EL:LiteDataRoot* nil *EL:MonitorLoadReady* nil
    *EL:StartupAttempted* T *EL:StartupError* nil *EL:PackageMarker* *EL:LiteMarker*)
  (setq result (vl-catch-all-apply 'EL:LiteLoadWork nil))
  (if (vl-catch-all-error-p result)
    (setq *EL:StartupError* (vl-catch-all-error-message result) result nil))
  (setq *EL:MonitorLoadReady* result)
  (if result
    (progn
      (EL:MonitorLoadEnd 'load-finished)
      (princ (strcat "\n已加载（CAD2020 " *EL:LiteVersion* "）。数据目录：" *EL:LiteDataRoot*))
      (EL:StartupCommandHint T))
    (progn
      (vl-catch-all-apply 'EL:MonitorLoadEnd (list 'load-failed))
      (setq *EL:Root* nil)
      (princ (strcat "\n精简版启动未完成：" *EL:StartupError*)))) result)
(EL:LiteLoad)
(princ)
