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
        // 获取DLL所在目录，这对于AutoCAD插件更为可靠
        string dllPath = System.Reflection.Assembly.GetExecutingAssembly().Location;
        string dllDirectory = System.IO.Path.GetDirectoryName(dllPath);
        string exePath = System.IO.Path.Combine(dllDirectory, "Tools", "09 CAD开图自动选字体.exe");
        
        // 简化进程名（去掉版本号等信息，只保留关键部分）
        string processName = "CAD开图自动选字体";
        
        // 检查程序是否已经在运行
        if (IsProcessRunning(processName))
        {
            Editor ed = Application.DocumentManager.MdiActiveDocument.Editor;
            ed.WriteMessage("\n字体自动选择程序已经在运行中。");
            return;
        }
        
        // 启动程序
        try
        {
            // 验证文件是否存在
            if (!System.IO.File.Exists(exePath))
            {
                Editor ed = Application.DocumentManager.MdiActiveDocument.Editor;
                ed.WriteMessage($"\n找不到程序文件: {exePath}");
                return;
            }
            
            Process.Start(exePath);
            Editor ed = Application.DocumentManager.MdiActiveDocument.Editor;
            ed.WriteMessage("\n字体自动选择程序已启动。");
        }
        catch (System.Exception ex)
        {
            Editor ed = Application.DocumentManager.MdiActiveDocument.Editor;
            ed.WriteMessage($"\n启动字体自动选择程序失败: {ex.Message}");
            ed.WriteMessage($"\n程序路径: {exePath}"); // 添加路径信息以便调试
        }
    }
      
    // 检查进程是否在运行（优化后的检测逻辑，更适合后台运行的进程）
    private bool IsProcessRunning(string processName)
    {
        try
        {
            // 首先尝试获取精确的进程名进行匹配（去掉.exe扩展名）
            string exactProcessName = "09 CAD开图自动选字体";
            Process[] exactProcesses = Process.GetProcessesByName(exactProcessName);
            if (exactProcesses.Length > 0)
            {
                return true;
            }
            
            // 如果精确匹配失败，使用更宽松的匹配方式遍历所有进程
            foreach (Process process in Process.GetProcesses())
            {
                try
                {
                    // 检查进程名称（不依赖MainModule）
                    if (!string.IsNullOrEmpty(process.ProcessName) && 
                        process.ProcessName.Contains(processName))
                    {
                        return true;
                    }
                    
                    // 如果可以访问MainModule，则进行更精确的检查
                    if (process.MainModule != null && 
                        process.MainModule.FileName != null)
                    {
                        string fileName = process.MainModule.FileName;
                        // 检查文件名是否包含目标进程名或完整文件名
                        if (fileName.Contains(processName) || 
                            fileName.Contains("09 CAD开图自动选字体.exe"))
                        {
                            return true;
                        }
                    }
                }
                catch (System.Exception)
                {
                    // 访问某些进程可能会抛出异常（尤其是系统进程或权限受限的进程）
                    // 忽略这些异常，继续检查下一个进程
                    continue;
                }
            }
        }
        catch (System.Exception)
        {
            // 如果获取进程列表失败，记录错误但不影响程序运行
            // 这里返回false表示没有检测到进程运行
        }
        return false;
    }
}
