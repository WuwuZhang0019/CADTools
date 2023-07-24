using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Colors;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.Runtime;
using System;
using System.Diagnostics;
using System.Text;
using Tuna.autoCAD;



[assembly: CommandClass(typeof(MyCommand4))]

namespace Tuna.autoCAD
{
    public class MyCommand4
    {
        [CommandMethod(nameof(LayerTable), CommandFlags.Modal | CommandFlags.NoUndoMarker | CommandFlags.NoBlockEditor)]
        //获取图层表
        public void LayerTable()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database database = document.Database;

            using (OpenCloseTransaction ts = database.TransactionManager.StartOpenCloseTransaction())
            {
                //拿到图层ID
                LayerTable layerTable = (LayerTable)ts.GetObject(database.LayerTableId, OpenMode.ForRead);

                //遍历图层ID表，拿到每个图层名
                foreach (ObjectId item in layerTable)
                {
                    LayerTableRecord record = (LayerTableRecord)ts.GetObject(item, OpenMode.ForRead);
                    editor.WriteMessage("\n" + record.Name);

                }
                ts.Abort();
                //ts.Commit();
            }
        }

        [CommandMethod(nameof(GetLayerTableRecord), CommandFlags.Modal | CommandFlags.NoUndoMarker | CommandFlags.NoBlockEditor)]
        //获取图层表记录
        public void GetLayerTableRecord()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database database = document.Database;

            using (OpenCloseTransaction ts = database.TransactionManager.StartOpenCloseTransaction())
            {
                //拿到图层ID
                LayerTable layerTable = (LayerTable)ts.GetObject(database.LayerTableId, OpenMode.ForRead);
                //拿到图层表中的单个图层
                if (layerTable.Has("0"))
                {
                    var objectId = layerTable["0"];
                    LayerTableRecord record = (LayerTableRecord)ts.GetObject(objectId, OpenMode.ForRead);
                    //editor.WriteMessage($"{objectId}");
                    editor.WriteMessage($"\n 文档中存在{record.Name}图层");

                }
                else
                {
                    editor.WriteMessage($"文档中不存在图层");
                }
                ts.Abort();

            }
        }

        [CommandMethod(nameof(AddLayer), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //添加图层
        public void AddLayer()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database database = document.Database;

            try
            {
                using (Transaction ts = database.TransactionManager.StartTransaction())
                {
                    //拿到图层ID
                    LayerTable layerTable = (LayerTable)ts.GetObject(database.LayerTableId, OpenMode.ForWrite);
                    if (!layerTable.Has("wall2"))
                    {
                        using (LayerTableRecord record = new LayerTableRecord())
                        {
                            record.Name = "wall2";
                            record.Color = Color.FromColorIndex(ColorMethod.ByAci, 2);      //索引颜色

                            record.IsOff = false;        //开关
                            record.IsLocked = false;     //锁定
                            record.IsFrozen = false;    //冻结

                            var recordId = layerTable.Add(record);
                            ts.AddNewlyCreatedDBObject(record, true);       //添加新创建的数据库对象
                            database.Clayer = recordId;     //设置为当前图层

                        }
                    }
                    ts.Commit();

                }
            }
            catch (System.Exception e)
            {
                editor.WriteMessage(e.Message);
            }
        }

        [CommandMethod(nameof(DeleteLayer), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //删除图层
        public void DeleteLayer()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            Database database = document.Database;

            try
            {
                using(Transaction ts = database.TransactionManager.StartTransaction())
                {
                    string layerName = "333";
                    LayerTable table = (LayerTable)ts.GetObject(database.LayerTableId, OpenMode.ForRead);
                    if (table.Has(layerName))
                    {
                        ObjectId objectId = table[layerName];
                        if (layerName == "0" || layerName == "Defpoints")
                        {
                            throw new System.Exception("图层是0层或Defpoints层，不可删除");
                        }
                        if (database.Clayer == objectId)
                        {
                            throw new System.Exception("图层是当前图层");
                        }

                        LayerTableRecord record = (LayerTableRecord)ts.GetObject(objectId, OpenMode.ForWrite);
                        table.GenerateUsageData();
                        if (record.IsUsed)
                        {
                            throw new System.Exception("图层已被使用");
                        }


                        record.Erase();
                        if(record.IsErased)
                        {
                            editor.WriteMessage("已删除");
                        }
                    }
                    ts.Commit();
                }
            }
            catch(System.Exception e)
            {
                editor.WriteMessage("\n" + e.Message);
            }
        }

        [CommandMethod(nameof(Crateline2), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //创建直线并改图层
        public void Crateline2()
        {                      
            Document documant = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = documant.Editor;
            Database database = documant.Database;

            PromptPointResult pt1result = editor.GetPoint("\n 请输入第一个点");
            if (pt1result.Status == PromptStatus.OK)
            {
                PromptPointResult pt2result = editor.GetPoint(new PromptPointOptions("\n 请输入第二个点")
                {
                    UseBasePoint = true,
                    BasePoint = pt1result.Value
                });
                if (pt2result.Status == PromptStatus.OK)
                {
                    using (Transaction transaction = database.TransactionManager.StartTransaction())
                    using (Line line = new Line(pt1result.Value, pt2result.Value))
                    {

                        LayerTable layerTable = (LayerTable)database.LayerTableId.GetObject(OpenMode.ForRead);
                        if (!layerTable.Has("line"))    //判断是否已有line图层，没有就新建图层
                        {
                            using (LayerTableRecord layer = new LayerTableRecord())
                            {
                                layer.Name = "line";
                                layer.Color = Color.FromColorIndex(ColorMethod.ByAci, 2);

                                layerTable.UpgradeOpen();   //升级表的权限为可写
                                layerTable.Add(layer);      //将图层添加到图层表中
                                transaction.AddNewlyCreatedDBObject(layer, true);
                                layerTable.DowngradeOpen(); //降权
                            }
                        }
                        line.LayerId = layerTable["line"];

                        BlockTable table = (BlockTable)database.BlockTableId.GetObject(OpenMode.ForRead);
                        BlockTableRecord record = (BlockTableRecord)table[BlockTableRecord.ModelSpace].GetObject(OpenMode.ForWrite);

                        record.AppendEntity(line);
                        transaction.AddNewlyCreatedDBObject(line, true);
                        transaction.Commit();

                    }
                    

                }
            }
        }

        [CommandMethod(nameof(CrateBlock), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //创建块
        public void CrateBlock()
        {
            Document documant = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = documant.Editor;
            Database database = documant.Database;

            PromptPointResult result = editor.GetPoint("\n 单点放置块");
            if (result.Status != PromptStatus.OK) 
            {
                return;
            }
            try
            {
                using (Transaction ts = documant.TransactionManager.StartTransaction())
                {
                    BlockTable blockTable = (BlockTable)database.BlockTableId.GetObject(OpenMode.ForWrite);
                    BlockTableRecord modelSpace = (BlockTableRecord)blockTable[BlockTableRecord.ModelSpace].GetObject(OpenMode.ForWrite);   //通过索引的方式拿到模型空间的ID，并强转为块记录
                    using (BlockReference blockReference = new BlockReference(result.Value, modelSpace.Id))     //创建块
                    {
                        blockReference.LayerId = GetLayer(documant, "myBr");
                        modelSpace.AppendEntity(blockReference);    //添加到模型空间的块记录中
                        ts.AddNewlyCreatedDBObject(blockReference, true);   //告诉事务 添加了图形
                    }
                    ts.Commit();    //提交事务
                }
                //editor.WriteMessage("RE \n");
                editor.Regen();

            }
            catch (System.Exception e)
            {
                editor.WriteMessage(e.Message);
            }
        }

        public ObjectId GetLayer(Document documant, string name)
        {
            LayerTable layerTable = (LayerTable)documant.Database.LayerTableId.GetObject(OpenMode.ForWrite);    //拿到图层表
            if(!layerTable.Has(name))   //判断图层表里有没有需要的图层，若没有需自己创建
            {
                using(LayerTableRecord record = new LayerTableRecord())
                {
                    record.Name = name;     //图层名称根据传入的参数来设置
                    record.Color = Color.FromColorIndex(ColorMethod.ByAci, 1);      //颜色索引
                    layerTable.Add(record);     //初始化完毕后将记录添加到图层表中
                    documant.TransactionManager.TopTransaction.AddNewlyCreatedDBObject(record, true);       //拿到顶级事务
                }
            }
            return layerTable[name];    //通过索引返回图层
        }

        [CommandMethod(nameof(CrateBlockTableRecord), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //创建块表记录
        public void CrateBlockTableRecord()
        {
            Document documant = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = documant.Editor;
            Database database = documant.Database;

            try
            {
                using (Transaction ts = documant.TransactionManager.StartTransaction())
                {
                    BlockTable blockTable = (BlockTable)database.BlockTableId.GetObject(OpenMode.ForWrite);
                    BlockTableRecord modelSpace = (BlockTableRecord)blockTable[BlockTableRecord.ModelSpace].GetObject(OpenMode.ForWrite);   //通过索引的方式拿到模型空间的ID，并强转为块记录
                    if (!blockTable.Has("myBlock"))
                    {
                        using (BlockTableRecord record = new BlockTableRecord())
                        {
                            record.Name = "myBlock";    //块名
                            CrateLines(record);         //拿到块记录去创建图形，此处为创建一系列线
                            var id = blockTable.Add(record);    //将块记录添加到块表
                            ts.AddNewlyCreatedDBObject(record, true);   //告诉事务 创建了一个块记录

                            using (BlockReference blockReference = new BlockReference(Point3d.Origin, id))      //用上面的块记录去创建一个块，实例化一个块，传入插入点和块记录的值
                            {
                                blockReference.LayerId = GetLayer(documant, "myBr");    //图层名
                                modelSpace.AppendEntity(blockReference);                //告诉模型空间加进来了一个实体
                                ts.AddNewlyCreatedDBObject(blockReference, true);       //告诉事务加进来了一个实体
                            }
                        }
                    }
                    ts.Commit();
                }
                

            }
            catch(System.Exception e)
            {
                editor.WriteMessage(e.Message);

            }
        }

        public void CrateLines(BlockTableRecord record)
        {
            Point3d upLeft = new Point3d(-500, 500, 0);
            Point3d upRight = new Point3d(500, 500, 0);
            Point3d downLeft = new Point3d(-500, -500, 0);
            Point3d downRight = new Point3d(500, -500, 0);

            CreateLine(record, upLeft, upRight);
            CreateLine(record, upRight, downRight);
            CreateLine(record, downRight, downLeft);
            CreateLine(record, downLeft, upLeft);
        }
        public void CreateLine(BlockTableRecord record, Point3d startPoint, Point3d endPoint)
        {
            record.AppendEntity(new Line(startPoint, endPoint));
        }


        [CommandMethod(nameof(GetRecordReference), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //拿到块表记录
        public void GetRecordReference()
        {
            Document documant = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = documant.Editor;
            Database database = documant.Database;

            try
            {
                using (Transaction ts = documant.TransactionManager.StartTransaction())
                {
                    BlockTable blockTable = (BlockTable)database.BlockTableId.GetObject(OpenMode.ForWrite);
                    if (blockTable.Has("myBlock"))
                    {
                        BlockTableRecord record = (BlockTableRecord)blockTable["myBlock"].GetObject(OpenMode.ForWrite);
                        var references = record.GetBlockReferenceIds(true, true);   //拿到块记录的所有引用(直接引用，间接引用)
                        foreach(ObjectId objectId in references)
                        {
                            var dbObject = objectId.GetObject(OpenMode.ForRead);
                            editor.WriteMessage($"\n{dbObject.Handle}");
                        }
                    }
                    ts.Commit();
                    
                }
            }
            catch (System.Exception e)
            {
                editor.WriteMessage(e.Message);
            }
        }

        [CommandMethod(nameof(ExplodeBlockReference), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //炸开嵌套快中的块
        public void ExplodeBlockReference()
        {
            Document documant = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = documant.Editor;
            Database database = documant.Database;

            try
            {
                using (Transaction ts = documant.TransactionManager.StartTransaction())
                {
                    BlockTable blockTable = (BlockTable)database.BlockTableId.GetObject(OpenMode.ForWrite);
                    if (blockTable.Has("myBlock"))
                    {
                        BlockTableRecord record = (BlockTableRecord)blockTable["myBlock"].GetObject(OpenMode.ForWrite);
                        var references = record.GetBlockReferenceIds(true, true);   //拿到块记录的所有引用(直接引用，间接引用)
                        foreach (ObjectId objectId in references)
                        {
                            var dbObject = objectId.GetObject(OpenMode.ForWrite);
                            if (dbObject is BlockReference reference)
                            {
                                reference.ExplodeToOwnerSpace();    //炸开块引用并保留在OwnerSpace
                                reference.Erase();                  //删除块
                                
                            }
                        }
                    }
                    
                    editor.Regen();
                    ts.Commit();
                }

            }
            catch (System.Exception e)
            {
                editor.WriteMessage(e.Message);
            }
        }



    }


}


/*BlockTable blockTable = (BlockTable)ts.GetObject(database.BlockTableId, OpenMode.ForRead);
LayerTable dimStyleTable = (DimStyleTable)ts.GetObject(database.DimStyleTableId, OpenMode.ForRead);
LayerTable lineTypeTable = (LinetypeTable)ts.GetObject(database.LinetypeTableId, OpenMode.ForRead);
LayerTable regAppTable = (LayerTable)ts.GetObject(database.RegAppTableId, OpenMode.ForRead);
LayerTable textStyleTable = (LayerTable)ts.GetObject(database.TextStyleTableId, OpenMode.ForRead);
LayerTable ucsTable = (LayerTable)ts.GetObject(database.UcsTableId, OpenMode.ForRead);
LayerTable viewportTable = (LayerTable)ts.GetObject(database.ViewportTableId, OpenMode.ForRead);*/