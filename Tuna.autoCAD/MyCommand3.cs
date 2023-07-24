using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;
using System;
using System.Text;
using Tuna.autoCAD;



[assembly: CommandClass(typeof(MyCommand3))]
namespace Tuna.autoCAD
{
    /// <summary>
    /// 获取图元
    /// </summary>
    public class MyCommand3    
    {
        [CommandMethod(nameof(GeyAllElements), CommandFlags.Modal | CommandFlags.NoBlockEditor)]     
        //获取所有图元
        public void GeyAllElements()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database database = document.Database;

            PromptSelectionResult result = editor.SelectAll();

            if (result.Status == PromptStatus.OK)
            {
                editor.WriteMessage(result.Value.Count.ToString());
                using (OpenCloseTransaction ts = database.TransactionManager.StartOpenCloseTransaction())
                {
                    foreach (SelectedObject item in result.Value)
                    {
                        var selectedObject = ts.GetObject(item.ObjectId, OpenMode.ForRead);
                        editor.WriteMessage("\n" + selectedObject.GetType().ToString());
                    }
                    editor.SetImpliedSelection(result.Value);    //亮显当前所选项
                    ts.Abort();
                }                
            }
            else
            {
                editor.WriteMessage(result.Status.ToString());

            }

        }

        [CommandMethod(nameof(GeyElements), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //获取过滤的图元
        public void GeyElements()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database database = document.Database;

            PromptSelectionResult result = editor.SelectAll(new SelectionFilter(new TypedValue[]
            {
                //new TypedValue((int)DxfCode.Start,"Line")
                new TypedValue(0,"Line")

            }));
            if (result.Status == PromptStatus.OK)
            {
                editor.WriteMessage(result.Value.Count.ToString());
                using (OpenCloseTransaction ts = database.TransactionManager.StartOpenCloseTransaction())
                {
                    foreach (SelectedObject item in result.Value)
                    {
                        var selectedObject = ts.GetObject(item.ObjectId, OpenMode.ForRead);
                        editor.WriteMessage("\n" + selectedObject.GetType().ToString());
                        editor.SetImpliedSelection(result.Value);    //亮显当前所选项                        

                    }
                    ts.Abort();
                }
            }
            else
            {
                editor.WriteMessage(result.Status.ToString());

            }
        }

        [CommandMethod(nameof(GeyLast), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //获取在当前视口最后创建的图元
        public void GeyLast()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database database = document.Database;

            PromptSelectionResult result = editor.SelectLast();

            if (result.Status == PromptStatus.OK)
            {
                editor.WriteMessage(result.Value.Count.ToString());
                using (OpenCloseTransaction ts = database.TransactionManager.StartOpenCloseTransaction())
                {
                    foreach (SelectedObject item in result.Value)
                    {
                        var selectedObject = ts.GetObject(item.ObjectId, OpenMode.ForRead);
                        editor.WriteMessage("\n" + selectedObject.GetType().ToString());
                    }
                    editor.SetImpliedSelection(result.Value);    //亮显当前所选项
                    ts.Abort();
                }
            }
            else
            {
                editor.WriteMessage(result.Status.ToString());

            }

        }

        [CommandMethod(nameof(GeyPrevious), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //获取上一次提示用户选择的图元
        public void GeyPrevious()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database database = document.Database;

            PromptSelectionResult result = editor.SelectPrevious();

            if (result.Status == PromptStatus.OK)
            {
                editor.WriteMessage(result.Value.Count.ToString());
                using (OpenCloseTransaction ts = database.TransactionManager.StartOpenCloseTransaction())
                {
                    foreach (SelectedObject item in result.Value)
                    {
                        var selectedObject = ts.GetObject(item.ObjectId, OpenMode.ForRead);
                        editor.WriteMessage("\n" + selectedObject.GetType().ToString());
                    }
                    editor.SetImpliedSelection(result.Value);    //亮显当前所选项
                    ts.Abort();
                }
            }
            else
            {
                editor.WriteMessage(result.Status.ToString());

            }

        }

        [CommandMethod(nameof(SelectElements), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //获取选择集
        public void SelectElements()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database database = document.Database;

            PromptSelectionResult result = editor.GetSelection();

            if (result.Status == PromptStatus.OK)
            {
                editor.WriteMessage(result.Value.Count.ToString());
                using (OpenCloseTransaction ts = database.TransactionManager.StartOpenCloseTransaction())
                {
                    foreach (SelectedObject item in result.Value)
                    {
                        var selectedObject = ts.GetObject(item.ObjectId, OpenMode.ForRead);
                        editor.WriteMessage("\n" + selectedObject.GetType().ToString());
                    }
                    editor.SetImpliedSelection(result.Value);    //亮显当前所选项
                    ts.Abort();
                }
            }
            else
            {
                editor.WriteMessage(result.Status.ToString());

            }

        }

    }
}
