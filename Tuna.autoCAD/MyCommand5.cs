using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;
using System;
using System.Text;
using Tuna.autoCAD;



[assembly: CommandClass(typeof(MyCommand5))]

namespace Tuna.autoCAD
{
    public class MyCommand5
    {
        [CommandMethod(nameof(Nod), CommandFlags.Modal | CommandFlags.NoUndoMarker | CommandFlags.NoUndoMarker)]
        //命名字典
        public void Nod()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database dataBase = document.Database;

            using (Transaction ts = document.TransactionManager.StartTransaction())
            {
                DBDictionary nod = (DBDictionary)dataBase.NamedObjectsDictionaryId.GetObject(OpenMode.ForWrite);

                foreach (var item in nod)
                {
                    editor.WriteMessage($"\n {item.Key}");
                }
                ts.Abort();
            }

        }

        [CommandMethod(nameof(GetAllLayouts), CommandFlags.Modal | CommandFlags.NoUndoMarker | CommandFlags.NoUndoMarker)]
        //拿到所有布局
        public void GetAllLayouts()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database dataBase = document.Database;

            using (Transaction ts = document.TransactionManager.StartTransaction())
            {
                DBDictionary layouts = (DBDictionary)dataBase.LayoutDictionaryId.GetObject(OpenMode.ForWrite);

                foreach (var item in layouts)
                {
                    Layout layout = (Layout)item.Value.GetObject(OpenMode.ForRead);
                    editor.WriteMessage($"\n {layout.LayoutName}");
                }
                ts.Abort();
            }

        }

        [CommandMethod(nameof(CreateLayout), CommandFlags.Modal | CommandFlags.NoUndoMarker | CommandFlags.NoUndoMarker)]
        //创建布局
        public void CreateLayout()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database dataBase = document.Database;

            string name = "布局2344432";
            using (Transaction ts = document.TransactionManager.StartTransaction())
            {
                /*#region 方式一
                DBDictionary layouts = (DBDictionary)dataBase.LayoutDictionaryId.GetObject(OpenMode.ForWrite);//拿到所有布局，并判断布局名称是否已存在
                if (!layouts.Contains(name))
                {
                    //若不存在则新建一个布局
                    BlockTable table = (BlockTable)dataBase.BlockTableId.GetObject(OpenMode.ForWrite);//拿到块表
                    BlockTableRecord record = new BlockTableRecord()//新建块记录
                    {
                        Name = $"*Paper_Spacce{layouts.Count - 1}",//块记录名称有固定格式“*Paper_Spacce”加编号
                    };

                    table.Add(record);//将记录加到块表
                    ts.AddNewlyCreatedDBObject(record, true);//通知事务 添加了一个块记录
                    using (Layout layout = new Layout())//创建布局
                    {
                        layout.LayoutName = name;//布局命名
                        layout.AddToLayoutDictionary(dataBase, record.Id);//加到布局字典中
                        ts.AddNewlyCreatedDBObject(layout, true);//通知事务 添加了一个布局
                    }
                    record.Dispose();//手动销毁记录
                }
                #endregion*/

                #region 方式二
                if (!LayoutManager.Current.LayoutExists(name))
                {
                    LayoutManager.Current.CreateLayout(name);//如果不存在就创建一个布局
                    LayoutManager.Current.CurrentLayout = name; //切换到当前布局
                }
                #endregion

                editor.Regen();
                ts.Commit();
            }
            editor.WriteMessage("\n 添加成功");

        }

        [CommandMethod(nameof(DeleteLayout), CommandFlags.Modal | CommandFlags.NoUndoMarker | CommandFlags.NoUndoMarker)]
        //删除布局
        public void DeleteLayout()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database dataBase = document.Database;

            PromptResult result = editor.GetString("输入要删除的布局");

            if (result.Status == PromptStatus.OK)
            {
                if (LayoutManager.Current.LayoutExists(result.StringResult))
                {
                    using (Transaction ts = document.TransactionManager.StartTransaction())
                    {
                        LayoutManager.Current.DeleteLayout(result.StringResult);
                        editor.Regen();
                        ts.Commit();
                    }
                }
            }
        }

        [CommandMethod(nameof(GetEntitiesByLayout), CommandFlags.Modal | CommandFlags.NoUndoMarker | CommandFlags.NoUndoMarker)]
        //拿到当前布局中所有实体
        public void GetEntitiesByLayout()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database dataBase = document.Database;

            PromptSelectionResult result = editor.SelectAll(new SelectionFilter(new TypedValue[]
            {
                new TypedValue((int)DxfCode.LayoutName,LayoutManager.Current.CurrentLayout)
            }));
            if (result.Status == PromptStatus.OK)
            {
                editor.WriteMessage($"\n {result.Value.Count}");
            }

        }

        [CommandMethod(nameof(AddDictionary), CommandFlags.Modal | CommandFlags.NoUndoMarker | CommandFlags.NoUndoMarker)]
        //创建自己的字典
        public void AddDictionary()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database dataBase = document.Database;

            var namedObjectsDiction = dataBase.NamedObjectsDictionaryId;
            using (Transaction ts = document.TransactionManager.StartTransaction())
            {
                DBDictionary nod = (DBDictionary)namedObjectsDiction.GetObject(OpenMode.ForWrite);
                DBDictionary newdic = new DBDictionary();
                nod.SetAt("Tuna_myDic", newdic);
                ts.AddNewlyCreatedDBObject(newdic, true);
                ts.Commit();
            }
            editor.WriteMessage("\n添加成功");
        }

        [CommandMethod(nameof(SetDictionary), CommandFlags.Modal | CommandFlags.NoUndoMarker | CommandFlags.NoUndoMarker)]
        //设置字典
        public void SetDictionary()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database dataBase = document.Database;

            var namedObjectsDiction = dataBase.NamedObjectsDictionaryId;
            using (Transaction ts = document.TransactionManager.StartTransaction())
            {
                DBDictionary nod = (DBDictionary)namedObjectsDiction.GetObject(OpenMode.ForRead);
                if (nod.Contains("Tuna_myDic"))
                {
                    DBDictionary myDic = (DBDictionary)nod.GetAt("Tuna_myDic").GetObject(OpenMode.ForWrite);
                    using(DBDictionary newdic= new DBDictionary())
                    {
                        myDic.SetAt("DBDictionary", newdic);
                        ts.AddNewlyCreatedDBObject(newdic,true);                         
                    }
                    editor.WriteMessage("\n添加成功");
                }
                ts.Commit();

            }
        }

        [CommandMethod(nameof(SetLayoutValue), CommandFlags.Modal | CommandFlags.NoUndoMarker | CommandFlags.NoUndoMarker)]
        //在字典中添加布局
        public void SetLayoutValue()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database dataBase = document.Database;

            var namedObjectsDiction = dataBase.NamedObjectsDictionaryId;
            using (Transaction ts = document.TransactionManager.StartTransaction())
            {
                DBDictionary nod = (DBDictionary)namedObjectsDiction.GetObject(OpenMode.ForRead);
                if (nod.Contains("Tuna_myDic"))
                {
                    DBDictionary myDic = (DBDictionary)nod.GetAt("Tuna_myDic").GetObject(OpenMode.ForWrite);

                    using (Layout layout = new Layout()) 
                    {
                        layout.LayoutName = "layout";
                        myDic.SetAt("layout", layout);
                        ts.AddNewlyCreatedDBObject(layout, true);
                    }
                    editor.WriteMessage("\n添加成功");
                }
                ts.Commit();

            }
        }


        [CommandMethod(nameof(SetDataTable), CommandFlags.Modal | CommandFlags.NoUndoMarker | CommandFlags.NoUndoMarker)]
        //在字典中添加数据表
        public void SetDataTable()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database dataBase = document.Database;

            ObjectId namedObjectsDiction = dataBase.NamedObjectsDictionaryId;
            using (Transaction ts = document.TransactionManager.StartTransaction())
            {
                DBDictionary dBDictionary = (DBDictionary)namedObjectsDiction.GetObject(OpenMode.ForRead);
                if (dBDictionary.Contains("Tuna_myDic"))
                {
                    DBDictionary myDic = (DBDictionary)dBDictionary.GetAt("Tuna_myDic").GetObject(OpenMode.ForWrite);

                    using (DataTable dataTable=new DataTable())
                    {
                        dataTable.TableName = "DataTable";
                        dataTable.AppendColumn(CellType.Integer, "Integer Column");//创建列

                        DataCellCollection cells = new DataCellCollection();
                        DataCell cell = new DataCell();
                        cell.SetInteger(100);
                        cells.Add(cell);
                        dataTable.AppendRow(cells, false);

                        myDic.SetAt("DataTable", dataTable);
                        ts.AddNewlyCreatedDBObject(dataTable, true);
                    }
                    editor.WriteMessage("\n添加成功");
                }
                ts.Commit();

            }
        }


    }
}
