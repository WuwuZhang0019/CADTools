using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;
using System;
using System.Text;
using Tuna.autoCAD;



[assembly: CommandClass(typeof(MyCommand2))]

namespace Tuna.autoCAD
{
    public class MyCommand2    
    {
        [CommandMethod(nameof(PickObjects1), CommandFlags.Modal | CommandFlags.NoUndoMarker)]
        //过滤选择
        public void PickObjects1()
        {
            Document document = Autodesk.AutoCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
            Editor editor = document.Editor;

            SelectionFilter filter = new SelectionFilter(new TypedValue[]
            {
                //普通过滤
                //new TypedValue(0,"Circle,*Text"),
                //new TypedValue((int)DxfCode.Start,"*Line"),
                //new TypedValue(8,"图层1"),//图层
                //new TypedValue(62,1),//颜色

                //算术运算符 过滤半径大于等于300的圆
                //new TypedValue(0,"Circle"),
                //new TypedValue(-4,">="),
                //new TypedValue(40,300),

                //逻辑运算符 过滤
                //new TypedValue(-4,"<OR"),
                //new TypedValue(0,"Circle"),
                //new TypedValue(0,"Line"),
                //new TypedValue(0,"Arc"),
                //new TypedValue(-4,"OR>"),

                //多类型过滤
                //new TypedValue(0,"Circle,Line,Arc,Text"),


                new TypedValue(1,"*单*"),



            });

            PromptSelectionResult result = editor.GetSelection(new PromptSelectionOptions()
            {
                SingleOnly = true,
                SinglePickInSpace = true,
            }, filter);

            if (result.Status == PromptStatus.OK)
            {
                SelectionSet selectedObjects = result.Value;    //获取用户选择的选择集
                editor.SetImpliedSelection(selectedObjects);    //亮显当前所选项                        
                editor.WriteMessage(selectedObjects.Count.ToString());  //选择到的图元数量打印到命令行
            }
            else
            {
                editor.WriteMessage(result.Status.ToString());

            }

        }
 
    }
}
