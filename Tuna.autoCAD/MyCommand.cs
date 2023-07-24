using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.Runtime;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Tuna.autoCAD;

[assembly:CommandClass(typeof(MyCommand))]
namespace Tuna.autoCAD
{
    public class MyCommand
    {
        [CommandMethod("TestCommand",CommandFlags.Modal|CommandFlags.NoBlockEditor)]
        public void Crateline()
        {
            Debug.WriteLine("1");
            //System.Windows.MessageBox.Show("Hello 222");
            Document documant = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = documant.Editor;
            Database database = documant.Database;


            PromptPointResult pt1result = editor.GetPoint("请输入第一个点");
            if(pt1result.Status == PromptStatus.OK)
            {
                PromptPointResult pt2result = editor.GetPoint(new PromptPointOptions("请输入第二个点")
                {
                    UseBasePoint = true,
                    BasePoint = pt1result.Value
                }) ;
                if(pt2result.Status == PromptStatus.OK)
                {
                    //Transaction transaction = database.TransactionManager.StartTransaction();
                    //using (OpenCloseTransaction transaction = database.TransactionManager.StartOpenCloseTransaction())
                    var transaction = database.TransactionManager.StartOpenCloseTransaction();
                    using (Line line=new Line(pt1result.Value, pt2result.Value))
                    {


                        BlockTable table = (BlockTable)transaction.GetObject(database.BlockTableId, OpenMode.ForRead);
                        BlockTableRecord record =(BlockTableRecord)table[BlockTableRecord.ModelSpace].GetObject(OpenMode.ForWrite);

                        record.AppendEntity(line);

                        transaction.AddNewlyCreatedDBObject(line, true);
                        transaction.Commit();
                        
                    }
                    transaction.Dispose();//不用using就需要手动地调用对象的Dispose方法来释放对象中的非托管资源。

                }
            }
        }
        [CommandMethod(nameof(InputPoint),CommandFlags.Modal)]
        public void InputPoint()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            PromptPointOptions options = new PromptPointOptions("\n 在绘制窗口选择点[创建(A)/回退(B)]：","Crate Back");
            /*options.Keywords.Add("Crate", "C", "创建(C)");
            options.Keywords.Add("Back", "B", "回退(B)");
            options.AppendKeywordsToMessage = true;*/
            options.AllowNone = false;

            PromptPointResult result = editor.GetPoint(options);
            if(result.Status == PromptStatus.OK)
            {
                editor.WriteMessage(result.Value.ToString());
            }

            if(result.Status == PromptStatus.Keyword)
            {
                switch (result.StringResult)
                {
                    case "Crate":
                        //todo
                        editor.WriteMessage("创建的关键字");
                        break;
                    case "Back":
                        //todo
                        editor.WriteMessage("回退的关键字");
                        break;
                    default: 
                        break;

                }

            }
        }

        [CommandMethod(nameof(InputAngle), CommandFlags.Modal)]
        public void InputAngle()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            PromptAngleOptions options = new PromptAngleOptions("\n 请输入角度");
            PromptDoubleResult result = editor.GetAngle(options);
            if( result.Status == PromptStatus.OK)
            {
                editor.WriteMessage(result.Value.ToString() );
            }
        }

        [CommandMethod(nameof(InputCorner), CommandFlags.Modal)]
        public void InputCorner()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;
            PromptCornerOptions options = new PromptCornerOptions("\n 选择对角", Autodesk.AutoCAD.Geometry.Point3d.Origin)
            {
                UseDashedLine = true,
            };
            PromptPointResult result = editor.GetCorner(options); 
            if(result.Status == PromptStatus.OK)
            {
                editor.WriteMessage(result.Value.ToString());

            }
        }

        [CommandMethod(nameof(InputString), CommandFlags.Modal)]
        public void InputString()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;

            PromptResult result = editor.GetString(new PromptStringOptions("\n 请输入"));
            if(result.Status == PromptStatus.OK)
            {
                editor.WriteMessage(result.StringResult);
            }            
        }

        [CommandMethod(nameof(InputInteger), CommandFlags.Modal)]
        public void InputInteger()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;

            PromptIntegerOptions options = new PromptIntegerOptions("\n 请输入RGB");
            options.UpperLimit = 255;
            options.LowerLimit = 0;

            var result = editor.GetInteger(options);
            if( result.Status == PromptStatus.OK)
            {
                editor.WriteMessage(result.Value.ToString() );
            }
        }

        [CommandMethod(nameof(InputDouble), CommandFlags.Modal)]
        public void InputDouble()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;

            PromptDoubleOptions options = new PromptDoubleOptions("\n 请输入");
            options.AllowNegative = false;

            PromptDoubleResult result = editor.GetDouble(options);
            if(result.Status == PromptStatus.OK)
            {
                editor.WriteMessage($"\n 输入值为{result.Value}");
            }

        }

        [CommandMethod(nameof(InputDistance), CommandFlags.Modal)]
        public void InputDistance()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;

            PromptDistanceOptions options = new PromptDistanceOptions("\n 请测量");
            options.Only2d = true;
            PromptDoubleResult result = editor.GetDistance(options);
            if(result.Status == PromptStatus.OK)
            {
                editor.WriteMessage($"\n 总长度为{result.Value}");

            }

        }

        [CommandMethod(nameof(InputKeywords), CommandFlags.Modal)]
        public void InputKeywords()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;

            PromptKeywordOptions options = new PromptKeywordOptions("\n 请选择:");
            options.AllowNone = false;
            options.AppendKeywordsToMessage = true;
            options.Keywords.Add("Red","R","红色(R)");
            options.Keywords.Add("Yellow", "Y", "黄色(Y)");
            options.Keywords.Add("Green", "G", "绿色(G)");
            options.Keywords.Default = "Red";

            PromptResult result = editor.GetKeywords(options);
            if( result.Status == PromptStatus.OK)
            {
                editor.WriteMessage(result.StringResult);

            }
        }

        [CommandMethod(nameof(PickObject), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //选择实体
        public void PickObject()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;

            PromptEntityResult result = editor.GetEntity(new PromptEntityOptions("\n 选择实体")
            {
                AllowObjectOnLockedLayer = true,    //允许本方法选择到被锁定图层的对象
            });
            if (result.Status == PromptStatus.OK)
            {
                ObjectId SelectObjectId = result.ObjectId;
                using(OpenCloseTransaction ts =document.TransactionManager.StartOpenCloseTransaction() )
                {
                    var dbObject = ts.GetObject(SelectObjectId, OpenMode.ForRead);
                    editor.WriteMessage(ObjToString(dbObject));
                    ts.Commit();

                }
            }         

        }

        [CommandMethod(nameof(PickNestedObject), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //选择嵌套实体
        public void PickNestedObject()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;

            PromptNestedEntityResult result = editor.GetNestedEntity(new PromptNestedEntityOptions("\n 选择实体")
            {
                UseNonInteractivePickPoint = true,  //非交互式选择点
                NonInteractivePickPoint=Point3d.Origin,
            });
            if(result.Status == PromptStatus.Error)
            {
                editor.WriteMessage("Error");
            }
            if (result.Status == PromptStatus.OK)
            {
                ObjectId SelectObjectId = result.ObjectId;
                using (OpenCloseTransaction ts = document.TransactionManager.StartOpenCloseTransaction())
                {
                    DBObject dbObject = ts.GetObject(SelectObjectId, OpenMode.ForRead);
                    editor.WriteMessage(ObjToString(dbObject));
                    ts.Commit();

                }
            }

        }

        [CommandMethod(nameof(PickObjects), CommandFlags.Modal | CommandFlags.NoBlockEditor)]
        //多选
        public void PickObjects()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;

            PromptSelectionResult result = editor.GetSelection(new PromptSelectionOptions()
            {
                
                //SingleOnly = true,
                //SinglePickInSpace = true,//单次选择，选择后无需用户多按回车

                //AllowDuplicates = true,//允许重复选择，数量叠加

                AllowSubSelections = true,//允许选择到子图元
                ForceSubSelections = true,
                //MessageForAdding 设置提示词
                RejectObjectsOnLockedLayers = true,//允许选择锁定图层的图元
                

            });
            if (result.Status == PromptStatus.OK)
            {
                SelectionSet selectedObjects = result.Value;

                //对选择集进行递归,允许选择到子图元
                foreach (SelectedObject item in selectedObjects)
                {
                    if (item.SelectionMethod == SelectionMethod.SubEntity) 
                    {
                        editor.WriteMessage(item.GetSubentities().Length.ToString());
                    }
                    using (OpenCloseTransaction ts = document.TransactionManager.StartOpenCloseTransaction())
                    {
                        DBObject dbObject = ts.GetObject(item.ObjectId, OpenMode.ForRead);
                        editor.WriteMessage(ObjToString(dbObject));
                        ts.Commit();

                    }
                }
                editor.WriteMessage(selectedObjects.Count.ToString());
            }

        }

        public string ObjToString(DBObject dbObject)
        {
            StringBuilder builder = new StringBuilder();
            var type = dbObject.GetType();
            builder.AppendLine($"Start--------------------{DateTime.Now}-----------------------");
            builder.AppendLine($"Type: {type}");
            foreach (var item in type.GetProperties(System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public))
            {
                try
                {
                    var result = item.GetValue(dbObject);
                    builder.AppendLine($" {item.Name}:{result}");
                }
                catch (System.Exception e)
                {
                    builder.AppendLine($"error:{item.Name}{e.Message}");
                }
                
            }
            builder.AppendLine($"End-------------------{DateTime.Now}-----------------------");
            return builder.ToString();
        }
    }
}
