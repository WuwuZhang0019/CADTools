using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;
using System;
using System.Diagnostics;
using System.Text;
using ZYF.autoCAD;
using ZYF.autoCAD.Commands;

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
namespace ZYF.autoCAD.Commands;

public class MyCommand
{
    //01CAD急速瘦身
    [CommandMethod(nameof(JSSS), CommandFlags.Modal)]
    public void JSSS()
    {
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/01 CAD急速瘦身神器.lsp";
        
        string loadStr = String.Format("(load \"{0}\")\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //02布置地面疏散指示
    [CommandMethod(nameof(MEE), CommandFlags.Modal)]
    public void MEE()
    {
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/02 布置地面疏散指示(mee).lsp";

        string loadStr = String.Format("(load \"{0}\") mee\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //03底图处理
    [CommandMethod(nameof(DTCL), CommandFlags.Modal)]
    public void DTCL()
    {
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/03 底图处理V2.4.0.lsp";

        string loadStr = String.Format("(load \"{0}\")\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //04图号文字递增
    [CommandMethod(nameof(THDZ), CommandFlags.Modal)]
    public void THDZ()
    {
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/04 图号文字递增V2.0(thdz).lsp";
        
        string loadStr = String.Format("(load \"{0}\") thdz\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //05图片去黑框
    [CommandMethod(nameof(QHK), CommandFlags.Modal)]
    public void QHK()
    {
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/05 图片去黑框.lsp";

        string loadStr = String.Format("(load \"{0}\")\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //06文字复制
    [CommandMethod(nameof(MAA), CommandFlags.Modal)]
    public void MAA()
    {
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/06 文字复制(maa).lsp";

        string loadStr = String.Format("(load \"{0}\")\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }

    //07图框自动编号
    [CommandMethod(nameof(FSN), CommandFlags.Modal)]
    public void FSN()
    {
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/07 图框自动编号V2.0(fsn).lsp";

        string loadStr = String.Format("(load \"{0}\") fsn\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }
    //080层置为当前层
    [CommandMethod(nameof(P01), CommandFlags.Modal)]
    public void P01()
    {
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/ProgramData/Autodesk/ApplicationPlugins/ZYF.bundle/Contents/Tools/08 0层置为当前层(p01).lsp";

        string loadStr = String.Format("(load \"{0}\")\n", lispPath);

        document.SendStringToExecute(loadStr, false, false, false);
    }
    //09 启动字体自动选择程序
    [CommandMethod(nameof(StartFontApp), CommandFlags.Modal)]
    public void StartFontApp()
    {
        string exePath = $"{AppDomain.CurrentDomain.BaseDirectory}Tools\\09 CAD开图自动选字体-V1.1-20250221.exe";
        
        // 检查程序是否已经在运行
        if (IsProcessRunning("09 CAD开图自动选字体-V1.1-20250221"))
        {
            Editor ed = Application.DocumentManager.MdiActiveDocument.Editor;
            ed.WriteMessage("\n字体自动选择程序已经在运行中。");
            return;
        }
        
        // 启动程序
        try
        {
            Process.Start(exePath);
            Editor ed = Application.DocumentManager.MdiActiveDocument.Editor;
            ed.WriteMessage("\n字体自动选择程序已启动。");
        }
        catch (Exception ex)
        {
            Editor ed = Application.DocumentManager.MdiActiveDocument.Editor;
            ed.WriteMessage($"\n启动字体自动选择程序失败: {ex.Message}");
        }
    }
    
    //10 关闭字体自动选择程序
    [CommandMethod(nameof(StopFontApp), CommandFlags.Modal)]
    public void StopFontApp()
    {
        try
        {
            // 查找并关闭程序
            foreach (Process process in Process.GetProcessesByName("09 CAD开图自动选字体-V1.1-20250221"))
            {
                process.CloseMainWindow();
                process.WaitForExit(1000); // 等待1秒让程序关闭
                if (!process.HasExited)
                {
                    process.Kill();
                }
            }
            
            Editor ed = Application.DocumentManager.MdiActiveDocument.Editor;
            ed.WriteMessage("\n字体自动选择程序已关闭。");
        }
        catch (Exception ex)
        {
            Editor ed = Application.DocumentManager.MdiActiveDocument.Editor;
            ed.WriteMessage($"\n关闭字体自动选择程序失败: {ex.Message}");
        }
    }
    
    // 检查进程是否在运行
    private bool IsProcessRunning(string processName)
    {
        return Process.GetProcessesByName(processName).Length > 0;
    }
}
