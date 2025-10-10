using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.Customization;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.EditorInput;
using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using ZYF.autoCAD;
using System.Drawing.Text;

[assembly:ExtensionApplication(typeof(App))]
namespace ZYF.autoCAD
{
    public class App : IExtensionApplication
    {
        private string _menuGroup = "ZYFTools";
        private string _path;
        private string _root; 
        private CustomizationSection _main;

        public App()
        {
            //在主文件下加载局部文件
            var mainPath = $"{Autodesk.AutoCAD.ApplicationServices.Core.Application.GetSystemVariable("Menuname")}.cuix";   //通过CAD系统变量拿到当前自定义主文件的路径
            _main = new CustomizationSection(mainPath);     //初始化自定义节点，即根节点

            string location=this.GetType().Assembly.Location;       //拿到当前安装路径
            _root=Directory.GetParent(location).FullName;           //拿到上一级路径

            _path = $"{_root}\\{_menuGroup}.cuix";      //拼装路径

        }

        private void Reset()
        {
            //查询当前主文件下局部自定义文件是否包含当前文件路径，如果不包含就结束
            if (!_main.PartialCuiFiles.Contains(_path))
            {
                return;
            }
            //如果包含就移除
            if (!_main.RemovePartialMenu(_path,_menuGroup))
            {
                return;
            }
            //保存
            if (!_main.Save())
            {
                return;
            }
            //删除当前文件
            if(!File.Exists(_path))
            {
                return;
            }
            File.Delete(_path);
        }

        void CrateMenu(CustomizationSection tunaSection)
        {
            StringCollection strings = new StringCollection 
            {
                "ZYFTools"
            };      //传入自定义节点，创建父节点
            PopMenu menu = new PopMenu("张裕锋工具集", strings, "ZYFTools", tunaSection.MenuGroup);  //根节点菜单
            new PopMenuItem(JSSS, "CAD急速瘦身", menu, 0);
            new PopMenuItem(MEE, "布置地面疏散指示", menu, 1);
            new PopMenuItem(DTCL, "底图处理", menu, 2);
            new PopMenuItem(THDZ, "图号文字递增", menu, 3);
            new PopMenuItem(QHK, "图片去黑框", menu, 4);
            new PopMenuItem(MAA, "文字复制", menu, 5);
            new PopMenuItem(FSN, "图框自动编号", menu, 6);
            new PopMenuItem(P01, "0层置为当前层", menu, 7);
            new PopMenuItem(StartFontApp, "启动字体自动选择", menu, 8);
            new PopMenuItem(StopFontApp, "关闭字体自动选择", menu, 9);
        }

        void CrateRibbon(CustomizationSection tunaSection)      //传入子节点
        {
            // Ribbon菜单栏已禁用
            // 所有Ribbon相关功能都被移除，仅保留函数接口
        }

        private MenuMacro _JSSS;
        public MenuMacro JSSS
        {
            get
            {
                if(_JSSS == null)
                {
                    _JSSS = new MenuMacro(Parent, "CAD急速瘦身", "JSSS", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _JSSS.macro.LargeImage = $@"{_root}\resource\icon\home.png";    //添加大图标
                }
                return _JSSS;
            }
        }

        private MenuMacro _MEE;
        public MenuMacro MEE
        {
            get
            {
                if (_MEE == null)
                {
                    _MEE = new MenuMacro(Parent, "布置地面疏散指示", "MEE", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _MEE.macro.LargeImage = $@"{_root}\resource\icon\home.png";    //添加大图标
                }
                return _MEE;
            }
        }

        private MenuMacro _DTCL;
        public MenuMacro DTCL
        {
            get
            {
                if (_DTCL == null)
                {
                    _DTCL = new MenuMacro(Parent, "底图处理", "DTCL", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _DTCL.macro.LargeImage = $@"{_root}\resource\icon\home.png";    //添加大图标
                }
                return _DTCL;
            }
        }

        private MenuMacro _THDZ;
        public MenuMacro THDZ
        {
            get
            {
                if (_THDZ == null)
                {
                    _THDZ = new MenuMacro(Parent, "图号文字递增", "THDZ", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _THDZ.macro.LargeImage = $@"{_root}\resource\icon\home.png";    //添加大图标
                }
                return _THDZ;
            }
        }

        private MenuMacro _QHK;
        public MenuMacro QHK
        {
            get
            {
                if (_QHK == null)
                {
                    _QHK = new MenuMacro(Parent, "图片去黑框", "QHK", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _QHK.macro.LargeImage = $@"{_root}\resource\icon\home.png";    //添加大图标
                }
                return _QHK;
            }
        }

        private MenuMacro _MAA;
        public MenuMacro MAA
        {
            get
            {
                if (_MAA == null)
                {
                    _MAA = new MenuMacro(Parent, "文字复制", "MAA", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _MAA.macro.LargeImage = $@"{_root}\resource\icon\home.png";    //添加大图标
                }
                return _MAA;
            }
        }

        private MenuMacro _FSN;
        public MenuMacro FSN
        {
            get
            {
                if (_FSN == null)
                {
                    _FSN = new MenuMacro(Parent, "图框自动编号", "FSN", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _FSN.macro.LargeImage = $@"{_root}\resource\icon\home.png";    //添加大图标
                }
                return _FSN;
            }
        }
        //080层置为当前层
        private MenuMacro _P01;
        public MenuMacro P01
        {
            get
            {
                if (_P01 == null)
                {
                    _P01 = new MenuMacro(Parent, "0层置为当前层", "P0", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _P01.macro.LargeImage = $@"{_root}\resource\icon\home.png";    //添加大图标
                }
                return _P01;
            }
        }
       
        public MacroGroup Parent{ get; set; }

        public void Initialize()
        {
            Autodesk.AutoCAD.ApplicationServices.Core.Application.BeginQuit += Application_BeginQuit;//订阅当前应用程序在关闭时的事件
            Reset();        

            // 在CAD打开之前自动启动字体选择程序（如果尚未运行）
            StartFontAppIfNotRunning();

            //开始自定义文件
            CustomizationSection tunaSection = new CustomizationSection()       //实例化一个自定义节点
            {
                MenuGroupName = _menuGroup      //属性赋值
            };

            Parent = new MacroGroup("ZYF", tunaSection.MenuGroup);     //创建宏组，存储对应命令

            // CrateRibbon(tunaSection);       //初始化ribbon界面 - 已注释掉禁用Ribbon菜单栏
            CrateMenu(tunaSection);         //设置菜单界面

            if(tunaSection.SaveAs(_path))   //另存文件
            {
                _main.AddPartialMenu(tunaSection.CUIFileName);      //将局部文件加载到当前主文件下
                _main.Save();       //保存
                Application.LoadPartialMenu(tunaSection.CUIFileName);   //加载局部菜单
            }

        }

// 添加MenuMacro属性
private MenuMacro _StartFontApp;
private MenuMacro _StopFontApp;

public MenuMacro StartFontApp
{
    get
    {
        if(_StartFontApp == null)
        {
            _StartFontApp = new MenuMacro(Parent, "启动字体自动选择", "StartFontApp", "zyf_tag");
            _StartFontApp.macro.LargeImage = $@"{_root}\resource\icon\home.png";
        }
        return _StartFontApp;
    }
}

public MenuMacro StopFontApp
{
    get
    {
        if(_StopFontApp == null)
        {
            _StopFontApp = new MenuMacro(Parent, "关闭字体自动选择", "StopFontApp", "zyf_tag");
            _StopFontApp.macro.LargeImage = $@"{_root}\resource\icon\home.png";
        }
        return _StopFontApp;
    }
}


        //订阅应用程序关闭前的动作
        private void Application_BeginQuit(object sender, BeginQuitEventArgs e)
        {
            Reset();    //重置文件夹文件，卸载界面菜单
            Autodesk.AutoCAD.ApplicationServices.Core.Application.BeginQuit -= Application_BeginQuit;   //取消订阅

        }

        //自动终结应用程序
        
        public void Terminate()
        {
            throw new NotImplementedException();
        }

        // 检查并启动字体自动选择程序
private void StartFontAppIfNotRunning()
{
    string processName = "09 CAD开图自动选字体-V1.1-20250221";
    
    // 检查程序是否已经在运行
    foreach (Process process in Process.GetProcesses())
    {
        if (process.ProcessName.Contains(processName))
        {
            return; // 程序已经在运行，不需要重复启动
        }
    }
    
    // 程序未运行，启动它
    try
    {
        string exePath = $"{_root}\\Tools\\{processName}.exe";
        if (File.Exists(exePath))
        {
            Process.Start(exePath);
        }
    }
    catch { }
}

    }

}
