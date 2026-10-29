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

            try
            {
                string moduleRoot = Path.Combine(
                    Path.GetDirectoryName(typeof(EmergencyLightingService).Assembly.Location),
                    "Tools", "Emergency-Lighting");
                string dataRoot = EmergencyLightingRuntime.Prepare(moduleRoot);
                string entry = Path.Combine(moduleRoot, EmergencyLightingRuntime.EntryName);
                document.SendStringToExecute(EmergencyLightingScript.Build(dataRoot, entry), false, false, false);
            }
            catch (Exception ex)
            {
                document.Editor.WriteMessage("\n应急照明准备失败：" + ex.Message);
            }
        }
    }

    internal static class EmergencyLightingScript
    {
        public const string Version = "full-v0.1.84";

        private static string QuotePath(string path)
        {
            return "\"" + path.Replace('\\', '/').Replace("\"", "\\\"") + "\"";
        }

        public static string Build(string dataRoot, string entryPath)
        {
            string root = dataRoot.Replace('\\', '/').TrimEnd('/') + "/";
            // State is held by the current drawing's LISP environment, not by the process.
            return $@"(progn
                (vl-load-com)
                ((lambda (zyfRoot zyfEntry zyfLoadResult)
                    (setq *EL:CADToolsRoot* zyfRoot)
                    (if (not (and *EL:MonitorLoadReady*
                                  (equal *EL:CADToolsVersion* ""{Version}"")
                                  (equal *EL:PackageMarker* ""{EmergencyLightingRuntime.PackageMarker}"")
                                  (equal *EL:Root* zyfRoot) C:ELSTAT))
                        (progn
                            (setq *EL:MonitorLoadReady* nil)
                            (setq zyfLoadResult (vl-catch-all-apply 'load (list zyfEntry)))))
                    (cond
                        ((vl-catch-all-error-p zyfLoadResult)
                            (princ (strcat ""\n应急照明加载失败：""
                                (vl-catch-all-error-message zyfLoadResult))))
                        ((and *EL:MonitorLoadReady*
                              (equal *EL:CADToolsVersion* ""{Version}"")
                              (equal *EL:PackageMarker* ""{EmergencyLightingRuntime.PackageMarker}"")
                              (equal *EL:Root* zyfRoot) C:ELSTAT)
                            (C:ELSTAT))
                        (C:ELFULL84 (C:ELFULL84))
                        (T (princ ""\n应急照明未就绪：请检查运行文件和可信路径。""))))
                    {QuotePath(root)} {QuotePath(entryPath)} nil)
                (princ))".Replace("\r", string.Empty).Replace("\n", " ") + "\n";
        }
    }
}
