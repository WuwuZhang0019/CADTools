using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;
using ZYF.autoCAD;


[assembly: CommandClass(typeof(AFS))]
namespace ZYF.autoCAD
{
    public class AFS
    {
        [CommandMethod("ReplaceFonts")]
        public void ReplaceFonts()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database database = document.Database;

            var host = HostApplicationServices.Current;//获取当前host
            using (OpenCloseTransaction ts = document.TransactionManager.StartOpenCloseTransaction())
            {
                TextStyleTable textStyleTable = (TextStyleTable)ts.GetObject(database.TextStyleTableId, OpenMode.ForRead);

                foreach (ObjectId item in textStyleTable)//遍历每一个文字样式
                {
                    TextStyleTableRecord record = (TextStyleTableRecord)ts.GetObject(item, OpenMode.ForRead);

                    if (record.Font.TypeFace == "")//判断文字样式没有使用windows字体
                    {
                        try
                        {
                            host.FindFile(record.BigFontFileName, database, FindFileHint.CompiledShapeFile);
                        }
                        catch (System.Exception)
                        {

                            editor.WriteMessage("\n文字样式<" + record.Name + ">未找到大字体—<" + record.BigFontFileName + ">", "Tssdchn.shx");
                            record = (TextStyleTableRecord)ts.GetObject(item, OpenMode.ForWrite);
                            record.BigFontFileName = "Tssdchn.shx";
                        }

                        try
                        {
                            host.FindFile(record.FileName, database, FindFileHint.CompiledShapeFile);
                        }
                        catch (System.Exception)
                        {

                            editor.WriteMessage("\n文字样式<" + record.Name + ">未找到小字体—<" + record.FileName + ">", "Tssdeng.shx");
                            record = (TextStyleTableRecord)ts.GetObject(item, OpenMode.ForWrite);
                            record.FileName = "Tssdeng.shx";
                        }                        
                    }
                }
                ts.Commit();
                editor.Regen();

            }
        }
    }
}
