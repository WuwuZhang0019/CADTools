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

[assembly: ExtensionApplication(typeof(App))]
namespace ZYF.autoCAD
{
    public class App : IExtensionApplication
    {
        private readonly string _menuGroup = "ZYFTools";
        private readonly string _path;
        private readonly string _root;
        private readonly CustomizationSection _main;

        public App()
        {
            //在主文件下加载局部文件
            var mainPath = $"{Autodesk.AutoCAD.ApplicationServices.Core.Application.GetSystemVariable("Menuname")}.cuix";   //通过CAD系统变量拿到当前自定义主文件的路径
            _main = new CustomizationSection(mainPath);     //初始化自定义节点，即根节点

            string location = this.GetType().Assembly.Location;       //拿到当前安装路径
            _root = Directory.GetParent(location).FullName;           //拿到上一级路径

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
            if (!_main.RemovePartialMenu(_path, _menuGroup))
            {
                return;
            }
            //保存
            if (!_main.Save())
            {
                return;
            }
            //删除当前文件
            if (!File.Exists(_path))
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
            new PopMenuItem(JSSS, "01 CAD急速瘦身(jsss)", menu, 0);
            new PopMenuItem(MEE, "02 布置地面疏散指示(MEE)", menu, 1);
            new PopMenuItem(DTCL, "03 底图处理(DTCL)", menu, 2);
            new PopMenuItem(THDZ, "04 图号文字递增(THDZ)", menu, 3);
            new PopMenuItem(QHK, "05 图片去黑框(QHK)", menu, 4);
            new PopMenuItem(MAA, "06 文字复制(MAA)", menu, 5);
            new PopMenuItem(FSN, "07 图框自动编号(FSN)", menu, 6);
            new PopMenuItem(P0, "08 0层置为当前图层(P0)", menu, 7);
            // 暂时改为两个独立的菜单项
            // 移除"09-1 启动字体自动选择程序"菜单项，但保留实际功能
            new PopMenuItem(ResetFontApp, "09 重新设置字体", menu, 8);
            new PopMenuItem(FAS, "10 消防回路统计(FAS)", menu, 9);
            new PopMenuItem(PTB, "11 PL线转桥架(PTB)", menu, 10);
            new PopMenuItem(UninstallSoftware, "12 软件卸载", menu, 11);
        }

        private MenuMacro _JSSS;
        public MenuMacro JSSS
        {
            get
            {
                if (_JSSS == null)
                {
                    _JSSS = new MenuMacro(Parent, "01 CAD急速瘦身(jsss)", "JSSS", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _JSSS.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
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
                    _MEE = new MenuMacro(Parent, "02 布置地面疏散指示(mee)", "MEE", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _MEE.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
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
                    _DTCL = new MenuMacro(Parent, "03 底图处理(DTCL)", "DTCL", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _DTCL.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
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
                    _THDZ = new MenuMacro(Parent, "04 图号文字递增(THDZ)", "THDZ", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _THDZ.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
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
                    _QHK = new MenuMacro(Parent, "05 图片去黑框(QHK)", "QHK", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _QHK.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
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
                    _MAA = new MenuMacro(Parent, "06 文字复制(MAA)", "MAA", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _MAA.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
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
                    _FSN = new MenuMacro(Parent, "07 图框自动编号(FSN)", "FSN", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _FSN.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
                }
                return _FSN;
            }
        }

        private MenuMacro _P0;
        public MenuMacro P0
        {
            get
            {
                if (_P0 == null)
                {
                    _P0 = new MenuMacro(Parent, "08 0层置为当前图层(P0)", "P0", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _P0.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
                }
                return _P0;
            }
        }


        // 添加MenuMacro属性

        private MenuMacro _StartFontApp;
        public MenuMacro StartFontApp
        {
            get
            {
                if (_StartFontApp == null)
                {
                    _StartFontApp = new MenuMacro(Parent, "启动字体自动选择程序", "StartFontApp", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _StartFontApp.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
                }
                return _StartFontApp;
            }
        }

        private MenuMacro _ResetFontApp;
        public MenuMacro ResetFontApp
        {
            get
            {
                if (_ResetFontApp == null)
                {
                    _ResetFontApp = new MenuMacro(Parent, "重新设置字体", "ResetFontApp", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _ResetFontApp.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
                }
                return _ResetFontApp;
            }
        }
        
        private MenuMacro _UninstallSoftware;
        public MenuMacro UninstallSoftware
        {
            get
            {
                if (_UninstallSoftware == null)
                {
                    _UninstallSoftware = new MenuMacro(Parent, "软件卸载", "UninstallSoftware", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _UninstallSoftware.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
                }
                return _UninstallSoftware;
            }
        }
        
        private MenuMacro _FAS;
        public MenuMacro FAS
        {
            get
            {
                if (_FAS == null)
                {
                    _FAS = new MenuMacro(Parent, "10 消防回路统计(FAS)", "FAS", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _FAS.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
                }
                return _FAS;
            }
        }

        private MenuMacro _PTB;
        public MenuMacro PTB
        {
            get
            {
                if (_PTB == null)
                {
                    _PTB = new MenuMacro(Parent, "11 PL线转桥架(PTB)", "PTB", "zyf_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _PTB.macro.SmallImage = $@"{_root}\resource\icon\home.ico";    //添加小图标
                }
                return _PTB;
            }
        }
        
        public MacroGroup Parent { get; set; }

        public void Initialize()
        {
            Autodesk.AutoCAD.ApplicationServices.Core.Application.BeginQuit += Application_BeginQuit;//订阅当前应用程序在关闭时的事件
            Reset();

            // 订阅文档创建和激活事件，确保在打开图纸时字体自动选择程序也能运行
            Application.DocumentManager.DocumentCreated += DocumentManager_DocumentCreated;
            Application.DocumentManager.DocumentActivated += DocumentManager_DocumentActivated;

            // 在CAD打开之前自动启动字体选择程序（如果尚未运行）
            StartFontAppIfNotRunning();

            //开始自定义文件
            CustomizationSection tunaSection = new CustomizationSection()       //实例化一个自定义节点
            {
                MenuGroupName = _menuGroup      //属性赋值
            };

            Parent = new MacroGroup("ZYF", tunaSection.MenuGroup);     //创建宏组，存储对应命令


            CrateMenu(tunaSection);         //设置菜单界面

            if (tunaSection.SaveAs(_path))   //另存文件
            {
                _main.AddPartialMenu(tunaSection.CUIFileName);      //将局部文件加载到当前主文件下
                _main.Save();       //保存
                Application.LoadPartialMenu(tunaSection.CUIFileName);   //加载局部菜单
            }
            Application.Idle += OnApplicationIdle;
        }
        private void OnApplicationIdle(object sender, EventArgs e)
        {            
            // 仅执行一次
            Application.Idle -= OnApplicationIdle;
            StartFontAppIfNotRunning();
        }

        // 文档创建事件处理程序
        private void DocumentManager_DocumentCreated(object sender, DocumentCollectionEventArgs e)
        {
            // 当新文档创建时，检查并启动字体自动选择程序
            StartFontAppIfNotRunning();
        }

        // 文档激活事件处理程序
        private void DocumentManager_DocumentActivated(object sender, DocumentCollectionEventArgs e)
        {
            // 当文档被激活时，检查并启动字体自动选择程序
            StartFontAppIfNotRunning();
        }


        //订阅应用程序关闭前的动作
        private void Application_BeginQuit(object sender, BeginQuitEventArgs e)
        {
            Reset();    //重置文件夹文件，卸载界面菜单
            Autodesk.AutoCAD.ApplicationServices.Core.Application.BeginQuit -= Application_BeginQuit;   //取消订阅
            // 取消订阅文档相关事件
            Application.DocumentManager.DocumentCreated -= DocumentManager_DocumentCreated;
            Application.DocumentManager.DocumentActivated -= DocumentManager_DocumentActivated;
        }

        //自动终结应用程序

        public void Terminate()
        {
            throw new NotImplementedException();
        }


        private void StartFontAppIfNotRunning()
        {
            try
            {
                string processName = Path.GetFileNameWithoutExtension("09 CAD开图自动选字体.exe");
                string exePath = Path.Combine(_root, "Tools", "09 CAD开图自动选字体.exe");

                if (Process.GetProcessesByName(processName).Length == 0 && File.Exists(exePath))
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = exePath,
                        WorkingDirectory = Path.GetDirectoryName(exePath)
                    });
                }
                
                // 程序加载完成后自动执行FSN命令
                Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument.SendStringToExecute("FSN_LOAD ", false, false, true);
            }
            catch { /* 静默处理 */ }
        }
    }
}