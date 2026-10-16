using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;
using System;
using System.Diagnostics;
using System.Text;
using System.IO;
using ZYF.autoCAD;
using ZYF.autoCAD.Services;
using ZYF.autoCAD.UI;
    // 由于命名空间“ZYF.autoCAD”中不存在类型或命名空间名“Commands”，移除该引用
    // using ZYF.autoCAD.Commands;

///1、如何写注册清单
///  加载路径（1）C:\Program Files\Autodesk\ApplicationPlugins
///          （2）C:\Users\Zyf\AppData\Roaming\Autodesk\ApplicationPlugins
///          （3）C:\ProgramData\Autodesk\ApplicationPlugins 全局位置，所有用户可用
///  文件夹命名要求：以 .bundle 结尾的文件夹
///  Contents文件夹存放dll文件、Resources文件夹和PackageContents配置清单，Resources文件夹存放图标
///2、如何在应用程序启动时加载引用
///     1、CAD启动时的插件查询路径
///     2、插件的文件夹结构
///     3、插件的配置清单
///3、如何在加载应用时加载界面

[assembly: CommandClass(typeof(MyCommand))]
namespace ZYF.autoCAD;

public class MyCommand
{
    private const string DxgsFileName = "12 自动标导线根数(dxgs).lsp";
    private static Document pendingMenuYjstDocument;

    // 在菜单命令退出后投递真实的 YJST 命令，与命令行输入走同一入口。
    private static void DispatchMenuYjstOnIdle(object sender, EventArgs e)
    {
        Autodesk.AutoCAD.ApplicationServices.Core.Application.Idle -= DispatchMenuYjstOnIdle;
        Document document = pendingMenuYjstDocument;
        pendingMenuYjstDocument = null;
        if (document == null ||
            Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument != document)
            return;

        document.SendStringToExecute("YJST\n", false, false, false);
    }

    [CommandMethod("YJST_MENU", CommandFlags.Session | CommandFlags.NoUndoMarker)]
    public void YjstMenu()
    {
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
        if (document == null) return;
        if (pendingMenuYjstDocument != null) return;

        pendingMenuYjstDocument = document;
        Autodesk.AutoCAD.ApplicationServices.Core.Application.Idle += DispatchMenuYjstOnIdle;
    }
    private static void RunDxgsLispCommand(string commandName)
    {
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string filePath = System.Reflection.Assembly.GetAssembly(typeof(MyCommand)).Location;
        string assemblyPath = System.IO.Path.GetDirectoryName(filePath);
        string lispPath = Path.Combine(assemblyPath, "Tools", DxgsFileName).Replace(@"\", "/");

        string loadStr = $"(progn (load \"{lispPath}\") (C:{commandName}))\n";
        document.SendStringToExecute(loadStr, false, false, false);
    }

    //01CAD急速瘦身
    [CommandMethod(nameof(JSSS), CommandFlags.Modal)]
    public void JSSS()
    {
        UpdateService.CheckAndNotifyUpdateOnCommandRun();
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/01 CAD急速瘦身(jsss).lsp";

        string loadStr = String.Format("(load \"{0}\")\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //02布置地面疏散指示
    [CommandMethod(nameof(MEE), CommandFlags.Modal)]
    public void MEE()
    {
        UpdateService.CheckAndNotifyUpdateOnCommandRun();
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/02 布置地面疏散指示(mee).lsp";

        string loadStr = String.Format("(load \"{0}\") mee\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //03底图处理
    [CommandMethod(nameof(DTCL), CommandFlags.Modal)]
    public void DTCL()
    {
        UpdateService.CheckAndNotifyUpdateOnCommandRun();
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/03 底图处理(DTCL).lsp";

        string loadStr = String.Format("(load \"{0}\")\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //04图号文字递增
    [CommandMethod(nameof(THDZ), CommandFlags.Modal)]
    public void THDZ()
    {
        UpdateService.CheckAndNotifyUpdateOnCommandRun();
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/04 图号文字递增V2.0(thdz).lsp";

        string loadStr = String.Format("(load \"{0}\") thdz\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //05图片去黑框
    [CommandMethod(nameof(QHK), CommandFlags.Modal)]
    public void QHK()
    {
        UpdateService.CheckAndNotifyUpdateOnCommandRun();
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/05 图片去黑框(QHK).lsp";

        string loadStr = String.Format("(load \"{0}\")\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //06文字复制
    [CommandMethod(nameof(MAA), CommandFlags.Modal)]
    public void MAA()
    {
        UpdateService.CheckAndNotifyUpdateOnCommandRun();
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/06 文字复制(maa).lsp";

        string loadStr = String.Format("(load \"{0}\")\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //07图框自动编号
    [CommandMethod(nameof(FSN), CommandFlags.Modal)]
    public void FSN()
    {
        UpdateService.CheckAndNotifyUpdateOnCommandRun();
        RunFsnLispCommand(true);
    }

    [CommandMethod(nameof(FSN_LOAD), CommandFlags.Modal)]
    public void FSN_LOAD()
    {
        RunFsnLispCommand(false);
    }

    private static void RunFsnLispCommand(bool execute)
    {
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
        if (document == null) return;

        string assemblyPath = Path.GetDirectoryName(typeof(MyCommand).Assembly.Location);
        string path = Path.Combine(assemblyPath, "Tools", "07 图框自动编号(fsn).VLX").Replace(@"\", "/");
        if (!File.Exists(path))
        {
            document.Editor.WriteMessage($"\n未找到图框自动编号工具：{path}");
            return;
        }

        // 在当前图纸的 LISP 环境中检查命令，避免切换图纸或重复使用时重新加载。
        string invoke = execute ? " (C:FSN)" : "";
        string loadStr = $"(progn (if (not C:FSN) (load \"{path}\")){invoke} (princ))\n";
        document.SendStringToExecute(loadStr, false, false, false);
    }
    //08 0层置为当前层
    [CommandMethod(nameof(P0), CommandFlags.Modal)]
    public void P0()
    {
        UpdateService.CheckAndNotifyUpdateOnCommandRun();
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/08 0层置为当前图层(P0).lsp";

        string loadStr = String.Format("(load \"{0}\")\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }
    //09 启动字体自动选择程序
    [CommandMethod(nameof(StartFontApp), CommandFlags.Modal)]
    public void StartFontApp()
{
    try
    {
        string exeDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            @"Autodesk\ApplicationPlugins\ZYF.bundle\Contents\Tools");
            
        string exePath = Path.Combine(exeDir, "09 CAD开图自动选字体.exe");
        string processName = Path.GetFileNameWithoutExtension("09 CAD开图自动选字体.exe");
        
        // 检查程序是否已经在运行
        if (Process.GetProcessesByName(processName).Length > 0)
        {
            Application.DocumentManager.MdiActiveDocument.Editor.WriteMessage("\n字体自动选择程序已经在运行中，无需重复启动。");
            return;
        }
        
        Process.Start(new ProcessStartInfo {
            FileName = exePath,
            WorkingDirectory = exeDir
        });
    }
    catch(System.Exception ex)
    {
        Application.DocumentManager.MdiActiveDocument.Editor.WriteMessage(
            $"\n错误: {ex.Message}");
    }
}
    
    //重新设置字体
    [CommandMethod(nameof(ResetFontApp), CommandFlags.Modal)]
    public void ResetFontApp()
{
    try
    {
        string exeDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            @"Autodesk\ApplicationPlugins\ZYF.bundle\Contents\Tools");
            
        string exePath = Path.Combine(exeDir, "09 CAD开图自动选字体.exe");
        string txtPath = Path.Combine(exeDir, "cad开图自动选字体.txt");
        
        // 1. 删除txt文件
        if (File.Exists(txtPath))
        {
            File.Delete(txtPath);
        }
        
        // 2. 退出exe程序
        string processName = Path.GetFileNameWithoutExtension("09 CAD开图自动选字体.exe");
        Process[] processes = Process.GetProcessesByName(processName);
        foreach (Process process in processes)
        {
            process.Kill();
            process.WaitForExit(1000); // 等待进程退出，最多1秒
        }
        
        // 3. 重启exe程序
        Process.Start(new ProcessStartInfo {
            FileName = exePath,
            WorkingDirectory = exeDir
        });
        
        Application.DocumentManager.MdiActiveDocument.Editor.WriteMessage("\n字体设置已重置并重启程序。");
    }
    catch(System.Exception ex)
    {
        Application.DocumentManager.MdiActiveDocument.Editor.WriteMessage(
            $"\n错误: {ex.Message}");
    }
}
    // 软件卸载功能
    [CommandMethod(nameof(UninstallSoftware), CommandFlags.Modal)]
    public void UninstallSoftware()
    {
        try
        {
            // 1. 关闭后台运行的字体程序
            string processName = Path.GetFileNameWithoutExtension("09 CAD开图自动选字体.exe");
            Process[] processes = Process.GetProcessesByName(processName);
            foreach (Process process in processes)
            {
                process.Kill();
                process.WaitForExit(1000); // 等待进程退出，最多1秒
            }
            
            // 2. 启动卸载程序
            string uninstallPath = "C:\\ProgramData\\Autodesk\\ApplicationPlugins\\ZYF.bundle\\unins000.exe";
            
            if (File.Exists(uninstallPath))
            {
                Process.Start(uninstallPath);
                Application.DocumentManager.MdiActiveDocument.Editor.WriteMessage("\n软件卸载程序已启动，请按照提示完成卸载。");
            }
            else
            {
                Application.DocumentManager.MdiActiveDocument.Editor.WriteMessage("\n错误: 找不到卸载程序。");
            }
        }
        catch(System.Exception ex)
        {
            Application.DocumentManager.MdiActiveDocument.Editor.WriteMessage(
                $"\n错误: {ex.Message}");
        }
    }

    //10 消防回路统计
    [CommandMethod(nameof(FAS), CommandFlags.Modal)]
    public void FAS()
    {
        UpdateService.CheckAndNotifyUpdateOnCommandRun();
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/10 消防回路统计(FAS).lsp";

        string loadStr = String.Format("(load \"{0}\") FAS\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //11 PL线转桥架
    [CommandMethod(nameof(PTB), CommandFlags.Modal)]
    public void PTB()
    {
        UpdateService.CheckAndNotifyUpdateOnCommandRun();
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/11 PL线转桥架.lsp";

        string loadStr = String.Format("(load \"{0}\") PTB\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //12 自动标导线根数
    [CommandMethod(nameof(DXGS), CommandFlags.Modal)]
    public void DXGS()
    {
        UpdateService.CheckAndNotifyUpdateOnCommandRun();
        RunDxgsLispCommand(nameof(DXGS));
    }

    [CommandMethod(nameof(DXGSSETUP), CommandFlags.Modal)]
    public void DXGSSETUP()
    {
        RunDxgsLispCommand(nameof(DXGSSETUP));
    }

    [CommandMethod(nameof(DXGSCFG), CommandFlags.Modal)]
    public void DXGSCFG()
    {
        RunDxgsLispCommand(nameof(DXGSCFG));
    }

    //13 一键统一宋体
    [CommandMethod(nameof(YJST), CommandFlags.Modal)]
    public void YJST()
    {
        UpdateService.CheckAndNotifyUpdateOnCommandRun();
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
        if (document == null) return;

        string assemblyPath = Path.GetDirectoryName(typeof(MyCommand).Assembly.Location);
        string lispPath = Path.Combine(assemblyPath, "Tools", "13 一键统一宋体(yjst).lsp").Replace(@"\", "/");
        if (!File.Exists(lispPath))
        {
            document.Editor.WriteMessage($"\n未找到一键统一宋体工具：{lispPath}");
            return;
        }

        document.SendStringToExecute($"(progn (load \"{lispPath}\") (C:YJST))\n", false, false, false);
    }

    // 在菜单命令及其撤销分组结束后，向原目标图纸投递 LISP 入口。
    [CommandMethod("EmergencyLighting", CommandFlags.Session | CommandFlags.NoUndoMarker)]
    public void EmergencyLightingMenu()
    {
        EmergencyLightingService.QueueStart();
    }

    [CommandMethod(nameof(CheckUpdate), CommandFlags.Modal)]
    public void CheckUpdate()
    {
        UpdateCheckResult result = UpdateService.CheckForUpdatesAsync(isManual: true).GetAwaiter().GetResult();
        UpdateService.ShowManualResult(result);
    }

    [CommandMethod(nameof(AboutZYFTools), CommandFlags.Modal)]
    public void AboutZYFTools()
    {
        using (var form = new AboutForm())
        {
            form.ShowDialog();
        }
    }
}
