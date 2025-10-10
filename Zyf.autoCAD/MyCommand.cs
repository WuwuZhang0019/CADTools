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
    
    // 添加支持文件搜索路径
    [CommandMethod("AddZYFSupportPath", CommandFlags.Modal)]
    public void AddZYFSupportPath()
    {
        Document document = Application.DocumentManager.MdiActiveDocument;
        Editor ed = document.Editor;
        
        try
        {
            // 要添加的支持文件路径
            string supportPath = "C:\\ProgramData\\Autodesk\\ApplicationPlugins\\ZYF.bundle";
            
            // 获取当前的支持文件搜索路径
            string currentPaths = Application.GetSystemVariable("ACAD").ToString();
            
            // 检查路径是否已经存在
            if (currentPaths.Contains(supportPath))
            {
                ed.WriteMessage($"\n路径 {supportPath} 已经在支持文件搜索路径中。");
                return;
            }
            
            // 添加新路径（使用分号分隔）
            string newPaths = currentPaths + ";" + supportPath;
            
            // 设置新的支持文件搜索路径
            Application.SetSystemVariable("ACAD", newPaths);
            
            ed.WriteMessage($"\n成功将路径 {supportPath} 添加到支持文件搜索路径中。");
            ed.WriteMessage("\n请重启AutoCAD以确保设置生效。");
        }
        catch (System.Exception ex)
        {
            ed.WriteMessage($"\n添加支持文件路径时出错: {ex.Message}");
        }
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
    //08 0层置为当前层
    [CommandMethod(nameof(P0), CommandFlags.Modal)]
    public void P0()
    {
        Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;

        string lispPath = "C:/Users/Administrator/Desktop/CADTOOL/ZyfTools/Zyf.autoCAD/Tools/08 0层置为当前图层(p0).lsp";

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
        
        Editor ed = Application.DocumentManager.MdiActiveDocument.Editor;
        
        // 检查程序是否已经在运行
        if (IsProcessRunning(processName))
        {
            ed.WriteMessage("\n字体自动选择程序已经在运行中。");
            return;
        }
        
        // 启动程序
        try
        {
            // 验证文件是否存在
            if (!System.IO.File.Exists(exePath))
            {
                ed.WriteMessage($"\n找不到程序文件: {exePath}");
                return;
            }
            
            // 检查文件是否为有效的Windows PE文件
            if (!IsValidWindowsPEFile(exePath))
            {
                ed.WriteMessage("\n错误：字体自动选择程序文件格式无效或已损坏。");
                ed.WriteMessage("\n请检查程序文件是否完整，或重新获取有效的可执行文件。");
                return;
            }
            
            Process.Start(exePath);
            ed.WriteMessage("\n字体自动选择程序已启动。");
        }
        catch (System.Exception ex)
        {
            ed.WriteMessage($"\n启动字体自动选择程序失败: {ex.Message}");
            ed.WriteMessage($"\n程序路径: {exePath}");
            
            // 针对平台兼容性错误提供更详细的建议
            if (ex.Message.Contains("不是此操作系统平台的有效应用程序"))
            {
                ed.WriteMessage("\n提示：此程序可能与您当前的Windows版本不兼容。");
                ed.WriteMessage("\n建议：请尝试以兼容模式运行程序，或联系开发者获取兼容版本。");
            }
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
    
    // 检查文件是否为有效的Windows PE文件
    private bool IsValidWindowsPEFile(string filePath)
    {
        try
        {
            // 读取文件的前4个字节作为魔术数字
            using (System.IO.FileStream fs = new System.IO.FileStream(filePath, System.IO.FileMode.Open, System.IO.FileAccess.Read))
            {
                byte[] header = new byte[4];
                int bytesRead = fs.Read(header, 0, 4);
                
                // 有效的Windows PE文件魔术数字应该是 MZ.. (4D-5A-90-00)
                return bytesRead == 4 && header[0] == 0x4D && header[1] == 0x5A && header[2] == 0x90 && header[3] == 0x00;
            }
        }
        catch
        {
            // 如果读取文件失败，也视为无效文件
            return false;
        }
    }
}
