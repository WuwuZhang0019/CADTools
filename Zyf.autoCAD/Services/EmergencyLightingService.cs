using System;
using System.IO;
using Autodesk.AutoCAD.ApplicationServices;
using CadApplication = Autodesk.AutoCAD.ApplicationServices.Core.Application;

namespace ZYF.autoCAD.Services
{
    internal static class EmergencyLightingService
    {
        private static Document _pendingDocument;

        public static void QueueStart()
        {
            Document document = CadApplication.DocumentManager.MdiActiveDocument;
            if (document == null || _pendingDocument != null) return;

            UpdateService.CheckAndNotifyUpdateOnCommandRun();
            _pendingDocument = document;
            CadApplication.Idle += DispatchOnIdle;
        }

        private static void DispatchOnIdle(object sender, EventArgs e)
        {
            CadApplication.Idle -= DispatchOnIdle;
            Document document = _pendingDocument;
            _pendingDocument = null;
            if (document == null || CadApplication.DocumentManager.MdiActiveDocument != document)
                return;

            string moduleRoot = Path.Combine(
                Path.GetDirectoryName(typeof(EmergencyLightingService).Assembly.Location),
                "Tools", "Emergency-Lighting");
            foreach (string relative in new[] { "src/load.lsp", EmergencyLightingScript.Version + ".marker" })
            {
                string path = Path.Combine(moduleRoot, relative);
                if (!File.Exists(path))
                {
                    document.Editor.WriteMessage($"\n应急照明运行文件缺失：{path}。请恢复完整模块目录。");
                    return;
                }
            }

            document.SendStringToExecute(EmergencyLightingScript.Build(moduleRoot), false, false, false);
        }
    }

    internal static class EmergencyLightingScript
    {
        public const string Version = "lite-v0.1.61";

        public static string Build(string moduleRoot)
        {
            string root = moduleRoot.Replace('\\', '/').TrimEnd('/') + "/";
            string quotedRoot = "\"" + root.Replace("\"", "\\\"") + "\"";

            // 加载状态保存在当前图纸的 LISP 环境；不注册与业务命令重名的 .NET 包装。
            return $@"(progn
                (vl-load-com)
                ((lambda (zyfRoot zyfLoadResult)
                    (setq *EL:CADToolsRoot* zyfRoot)
                    (if (not (and *EL:MonitorLoadReady*
                                  (equal *EL:LiteVersion* ""{Version}"")
                                  (equal *EL:Root* zyfRoot) C:ELSTAT))
                        (progn
                            (setq *EL:MonitorLoadReady* nil)
                            (setq zyfLoadResult (vl-catch-all-apply 'load
                                (list (strcat zyfRoot ""src/load.lsp""))))))
                    (cond
                        ((vl-catch-all-error-p zyfLoadResult)
                            (princ (strcat ""\n应急照明加载失败：""
                                (vl-catch-all-error-message zyfLoadResult))))
                        ((and *EL:MonitorLoadReady*
                              (equal *EL:LiteVersion* ""{Version}"")
                              (equal *EL:Root* zyfRoot) C:ELSTAT)
                            (C:ELSTAT))
                        (T (princ (strcat ""\n应急照明未就绪：""
                            (if *EL:StartupError* *EL:StartupError*
                                ""请检查模块版本和运行文件。""))))))
                    {quotedRoot} nil)
                (princ))".Replace("\r", string.Empty).Replace("\n", " ") + "\n";
        }
    }
}
