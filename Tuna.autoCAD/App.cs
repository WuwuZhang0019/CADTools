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
using Tuna.autoCAD;
using System.Drawing.Text;

[assembly:ExtensionApplication(typeof(App))]
namespace Tuna.autoCAD
{
    public class App : IExtensionApplication
    {
        private string _menuGroup = "tuna";
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
                "Tuna"
            };      //传入自定义节点，创建父节点
            PopMenu menu = new PopMenu("张裕锋1", strings, "Tuna", tunaSection.MenuGroup);  //根节点菜单
            new PopMenuItem(Home, "建筑", menu, 0);
            new PopMenuItem(Home, "结构", menu, 1);
            new PopMenuItem(Home, "机电", menu, 2);

            PopMenu subMenu = new PopMenu("其他", new StringCollection(), "Other", tunaSection.MenuGroup);    //创建子节点菜单
            new PopMenuRef(subMenu, menu, 3);       //创建子菜单索引占位
            new PopMenuItem(Home, "景观", subMenu, 0);
            new PopMenuItem(Home, "亮化", subMenu, 1);
            new PopMenuItem(Home, "规划", subMenu, 2);
        }

        void CrateRibbon(CustomizationSection tunaSection)      //传入子节点
        {
            RibbonRoot ribbonRoot = tunaSection.MenuGroup.RibbonRoot;   //拿到功能区根节点

            //创建自定义选项卡
            RibbonTabSource source = new RibbonTabSource(ribbonRoot)
            {
                Name = "Tuna",
                Text = "张裕锋"
            };
            ribbonRoot.RibbonTabSources.Add(source);    //拿到选项卡资源集，创建选项卡

            //创建面板 Panel
            RibbonPanelSource ribbonPanelSource = new RibbonPanelSource(ribbonRoot) 
            { 
                Name = "userpanel", 
                Text = "用户" 
            };
            ribbonRoot.RibbonPanelSources.Add(ribbonPanelSource);   //根节点加入面板资源PanelSources

            RibbonRow ribbonRow = new RibbonRow(ribbonPanelSource); //加一行菜单行
            ribbonPanelSource.Items.Add(ribbonRow);                 //把行加载到Source里去

            //实例化面板资源引用，传入父节点source
            RibbonPanelSourceReference ribbonPanelSourceReference = new RibbonPanelSourceReference(source)
            {
                PanelId = ribbonPanelSource.ElementID
            };
            source.Items.Add(ribbonPanelSourceReference);   //将引用加载到选项卡里

            //创建命令按钮
            ribbonRow.Items.Add(new RibbonCommandButton(ribbonRow)
            {
                ButtonStyle = RibbonButtonStyle.LargeWithText,      //按钮样式
                Text = "首页",                                      //按钮名称
                MacroID = Home.ElementID,                           //宏ID绑定到homeID
            });

            //创建分割线
            ribbonRow.Items.Add(new RibbonSeparator(ribbonRow));

            //创建堆叠式按钮
            RibbonRowPanel ribbonRowPanel = new RibbonRowPanel(ribbonRow);      //初始化子面板
            ribbonRow.Items.Add(ribbonRowPanel);        //将子面板加载到行里去

            RibbonRow firstRibbonRow = new RibbonRow(ribbonRowPanel);     //创建第一行  
            ribbonRowPanel.Items.Add(firstRibbonRow);       //添加到子面板中
            firstRibbonRow.Items.Add(new RibbonCommandButton(firstRibbonRow)     //创建第一行按钮
            {
                ButtonStyle = RibbonButtonStyle.SmallWithText,     //按钮样式
                Text = "剪切",                                     //按钮名称
                MacroID = Home.ElementID,                          //宏ID绑定到homeID
            });

            RibbonRow secondRibbonRow = new RibbonRow(ribbonRowPanel);      //创建第二行
            ribbonRowPanel.Items.Add(secondRibbonRow);       //添加到子面板中
            secondRibbonRow.Items.Add(new RibbonCommandButton(secondRibbonRow)
            {
                ButtonStyle = RibbonButtonStyle.SmallWithText,
                Text = "连接",
                MacroID = Home.ElementID,
            });

            //创建下拉式按钮
            RibbonSplitButton ribbonSplitButton = new RibbonSplitButton(ribbonRow)
            {
                Text = "建筑",
                ButtonStyle = RibbonButtonStyle.LargeWithText
            };
            ribbonRow.Items.Add(ribbonSplitButton);

            ribbonSplitButton.Items.Add(new RibbonCommandButton(ribbonSplitButton)
            {
                ButtonStyle = RibbonButtonStyle.LargeWithText,
                Text = "柱子",
                MacroID = Home.ElementID,

            });

            ribbonSplitButton.Items.Add(new RibbonCommandButton(ribbonSplitButton)
            {
                ButtonStyle = RibbonButtonStyle.LargeWithText,
                Text = "墙",
                MacroID = Home.ElementID,

            });
        }

        private MenuMacro _home;
        public MenuMacro Home
        {
            get
            {
                if(_home == null)
                {
                    _home = new MenuMacro(Parent, "home", "Command", "tuna_tag");   //实例化宏菜单对象，传入父集，宏名称，绑定的方法命令，标记
                    _home.macro.LargeImage = $@"{_root}\resource\icon\home.png";    //添加大图标
                    _home.macro.SmallImage = $@"{_root}\resource\icon\home.png";    //添加小图标
                }
                return _home;
            }
        }

        public MacroGroup Parent{ get; set; }

        public void Initialize()
        {
            Autodesk.AutoCAD.ApplicationServices.Core.Application.BeginQuit += Application_BeginQuit;//订阅当前应用程序在关闭时的事件
            Reset();        

            //开始自定义文件
            CustomizationSection tunaSection = new CustomizationSection()       //实例化一个自定义节点
            {
                MenuGroupName = _menuGroup      //属性赋值
            };

            Parent = new MacroGroup("Tuna", tunaSection.MenuGroup);     //创建宏组，存储对应命令

            CrateRibbon(tunaSection);       //初始化ribbon界面
            CrateMenu(tunaSection);         //设置菜单界面

            if(tunaSection.SaveAs(_path))   //另存文件
            {
                _main.AddPartialMenu(tunaSection.CUIFileName);      //将局部文件加载到当前主文件下
                _main.Save();       //保存
                Application.LoadPartialMenu(tunaSection.CUIFileName);   //加载局部菜单
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


    }

}
