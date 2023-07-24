using Autodesk.AutoCAD.Runtime;
using Tuna.autoCAD.Commands;

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

[assembly: CommandClass(typeof(MyCommand6))]
namespace Tuna.autoCAD.Commands;

public class MyCommand6
{
    [CommandMethod(nameof(Command), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
    public void Command()
    {
        System.Windows.MessageBox.Show("        张裕锋");
    }
}

