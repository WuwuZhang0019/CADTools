dlg_Main:dialog
{
    label="图框划线编号"; 
    : row
    {
      : boxed_row 
      {
        label = "图框选择方式";
        fixed_width = true;
        fixed_height = true;
        width = 30;
        height = 5;
        : column
        {
          : radio_button 
          {  
            label = "手动划线";
            key = "Draw";
            value = 1;
          }
          : radio_button 
          {  
            label = "选取多段线";
            key = "Pick";
          }
        }
        : button 
        {  
          label = "选择图框";
          key = "Start_Pick";
          fixed_width = true;
          fixed_height = true;
          width = 6;
          height = 4;
        }
      }
      : boxed_row 
      {
        label = "按上一次识别顺序";
        : button 
        {  
          label = "重新识别";
          key = "Identify";
          fixed_width = true;
          fixed_height = true;
          width = 6;
          height = 4;
        }
      }
      : boxed_row 
      {
        label = "刷新当前界面";
        : button 
        {  
          label = "刷新";
          key = "Refresh";
          fixed_width = true;
          fixed_height = true;
          width = 6;
          height = 4;
        }
      }
      : boxed_row 
      {
        label = "填写起始的图号";
        : button 
        {  
          label = "编写图号";
          key = "GenFrameDrawingNumber";
          fixed_width = true;
          fixed_height = true;
          width = 6;
          height = 4;
        }
      }
      : boxed_row 
      {
        label = "填写起始的次图号";
        : button 
        {  
          label = "编写次图号";
          key = "GenFrameSubNumber";
          fixed_width = true;
          fixed_height = true;
          width = 6;
          height = 4;
        }
      }
      : boxed_row 
      {
        label = "按图框内的天正图名";
        : button 
        {  
          label = "生成图名";
          key = "GenFrameName";
          fixed_width = true;
          fixed_height = true;
          width = 6;
          height = 4;
        }
      }
      : boxed_row 
      {
        label = "将图框信息写入图形";
        : button 
        {  
          label = "改写图框信息";
          key = "Execute";
          fixed_width = true;
          fixed_height = true;
          width = 6;
          height = 4;
        }
      }
      : boxed_row 
      {
        label = "按当前图框信息";
        : button 
        {  
          label = "生成目录";
          key = "Gen_Index";
          fixed_width = true;
          fixed_height = true;
          width = 6;
          height = 4;
        }
      }
      : boxed_row 
      {
        label = "管理当前图框库";
        : button 
        {  
          label = "图框管理";
          key = "Manger_Frame";
          fixed_width = true;
          fixed_height = true;
          width = 6;
          height = 4;
        }
      }
    }



    : boxed_column
    {
      label = "识别结果";
      : row 
      {
        : text {label = "    序号";                                        key = "T0"; fixed_width = true;}//序号
        : text {label = "|   图号   |";                                       key = "T1"; fixed_width = true;}//图号
        : toggle   {key = "Enable_SubName" ; }
        : text {label = "次图号";                                       key = "T1A"; fixed_width = true;}//次图号
        : text {label = "|                    图名                   ";  key = "T2"; fixed_width = true;}//图名
        : text {label = "|    日期  ";                                      key = "T3"; fixed_width = true;}//日期
        : text {label = "|                    项目名称                  ";  key = "T4"; fixed_width = true;}//项目名称
        : text {label = "| 子项名称";                                      key = "T5"; fixed_width = true;}//子项名称
        : text {label = "|   设计编号 ";                                    key = "T6"; fixed_width = true;}//设计编号
        : text {label = "|          建设单位         ";                     key = "T7"; fixed_width = true;}//建设单位
        : text {label = "|  版本号";                                       key = "T8"; fixed_width = true;}//版本号
        : text {label = "|   图幅  ";                                      key = "T9"; fixed_width = true;}//图幅
      }
          : row //1
      {
        : toggle   {key = "A" ;action = "(EditBox_Change_Data $key)"; }
        : spacer_1 {  }
        : text     {key = "A00"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "A01"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//图号
        : spacer_1 {  }
        : edit_box {key = "A02"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//次图号
        : spacer_1 {  }
        : edit_box {key = "A03"; fixed_width = true; width = 46;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "A04"; fixed_width = true; width = 11;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "A05"; fixed_width = true; width = 47;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "A06"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "A07"; fixed_width = true; width = 14;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "A08"; fixed_width = true; width = 28;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "A09"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "A10"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //2
      {
        : toggle   {key = "B" ;action = "(EditBox_Change_Data $key)"; }
        : spacer_1 {  }
        : text     {key = "B00"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "B01"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//图号
        : spacer_1 {  }
        : edit_box {key = "B02"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//次图号
        : spacer_1 {  }
        : edit_box {key = "B03"; fixed_width = true; width = 46;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "B04"; fixed_width = true; width = 11;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "B05"; fixed_width = true; width = 47;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "B06"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "B07"; fixed_width = true; width = 14;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "B08"; fixed_width = true; width = 28;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "B09"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "B10"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //3
      {
        : toggle   {key = "C" ;action = "(EditBox_Change_Data $key)"; }
        : spacer_1 {  }
        : text     {key = "C00"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "C01"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//图号
        : spacer_1 {  }
        : edit_box {key = "C02"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//次图号
        : spacer_1 {  }
        : edit_box {key = "C03"; fixed_width = true; width = 46;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "C04"; fixed_width = true; width = 11;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "C05"; fixed_width = true; width = 47;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "C06"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "C07"; fixed_width = true; width = 14;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "C08"; fixed_width = true; width = 28;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "C09"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "C10"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //4
      {
        : toggle   {key = "D" ;action = "(EditBox_Change_Data $key)"; }
        : spacer_1 {  }
        : text     {key = "D00"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "D01"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//图号
        : spacer_1 {  }
        : edit_box {key = "D02"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//次图号
        : spacer_1 {  }
        : edit_box {key = "D03"; fixed_width = true; width = 46;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "D04"; fixed_width = true; width = 11;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "D05"; fixed_width = true; width = 47;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "D06"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "D07"; fixed_width = true; width = 14;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "D08"; fixed_width = true; width = 28;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "D09"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "D10"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //5
      {
        : toggle   {key = "E" ;action = "(EditBox_Change_Data $key)"; }
        : spacer_1 {  }
        : text     {key = "E00"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "E01"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//图号
        : spacer_1 {  }
        : edit_box {key = "E02"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//次图号
        : spacer_1 {  }
        : edit_box {key = "E03"; fixed_width = true; width = 46;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "E04"; fixed_width = true; width = 11;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "E05"; fixed_width = true; width = 47;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "E06"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "E07"; fixed_width = true; width = 14;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "E08"; fixed_width = true; width = 28;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "E09"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "E10"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //6
      {
        : toggle   {key = "F" ;action = "(EditBox_Change_Data $key)"; }
        : spacer_1 {  }
        : text     {key = "F00"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "F01"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//图号
        : spacer_1 {  }
        : edit_box {key = "F02"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//次图号
        : spacer_1 {  }
        : edit_box {key = "F03"; fixed_width = true; width = 46;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "F04"; fixed_width = true; width = 11;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "F05"; fixed_width = true; width = 47;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "F06"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "F07"; fixed_width = true; width = 14;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "F08"; fixed_width = true; width = 28;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "F09"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "F10"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //7
      {
        : toggle   {key = "G" ;action = "(EditBox_Change_Data $key)"; }
        : spacer_1 {  }
        : text     {key = "G00"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "G01"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//图号
        : spacer_1 {  }
        : edit_box {key = "G02"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//次图号
        : spacer_1 {  }
        : edit_box {key = "G03"; fixed_width = true; width = 46;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "G04"; fixed_width = true; width = 11;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "G05"; fixed_width = true; width = 47;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "G06"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "G07"; fixed_width = true; width = 14;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "G08"; fixed_width = true; width = 28;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "G09"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "G10"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //8
      {
        : toggle   {key = "H" ;action = "(EditBox_Change_Data $key)"; }
        : spacer_1 {  }
        : text     {key = "H00"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "H01"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//图号
        : spacer_1 {  }
        : edit_box {key = "H02"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//次图号
        : spacer_1 {  }
        : edit_box {key = "H03"; fixed_width = true; width = 46;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "H04"; fixed_width = true; width = 11;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "H05"; fixed_width = true; width = 47;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "H06"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "H07"; fixed_width = true; width = 14;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "H08"; fixed_width = true; width = 28;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "H09"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "H10"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //9
      {
        : toggle   {key = "I" ;action = "(EditBox_Change_Data $key)"; }
        : spacer_1 {  }
        : text     {key = "I00"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "I01"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//图号
        : spacer_1 {  }
        : edit_box {key = "I02"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//次图号
        : spacer_1 {  }
        : edit_box {key = "I03"; fixed_width = true; width = 46;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "I04"; fixed_width = true; width = 11;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "I05"; fixed_width = true; width = 47;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "I06"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "I07"; fixed_width = true; width = 14;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "I08"; fixed_width = true; width = 28;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "I09"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "I10"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //10
      {
        : toggle   {key = "J" ;action = "(EditBox_Change_Data $key)"; }
        : spacer_1 {  }
        : text     {key = "J00"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "J01"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//图号
        : spacer_1 {  }
        : edit_box {key = "J02"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//次图号
        : spacer_1 {  }
        : edit_box {key = "J03"; fixed_width = true; width = 46;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "J04"; fixed_width = true; width = 11;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "J05"; fixed_width = true; width = 47;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "J06"; fixed_width = true; width = 10;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "J07"; fixed_width = true; width = 14;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "J08"; fixed_width = true; width = 28;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "J09"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "J10"; fixed_width = true; width = 8;                                        }//图幅
      }
    }
    : row
    {
      : button {label = "全选"; key = "SelectAll" ; fixed_width = true; width = 8; action = "(Temp_SelectAll)";}
      : button {label = "全不选"; key = "SelectNone" ; fixed_width = true; width = 8; action = "(Temp_SelectNone)";}
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : button {label = "<< 上一页"; key = "PrePage" ; fixed_width = true; width = 25;}
      : spacer_1 {  }
      : spacer_1 {  }
      : button {label = "下一页 >>"; key = "NextPage"; fixed_width = true; width = 25;}
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      : spacer_1 {  }
      ok_only;
    }
}


dlg_2:dialog
{
  label = "Test";
  : button { key = "B1"; label = "Get"; action = "(Get_txt)"; }
  : button { key = "B2"; label = "Set"; action = "(Set_txt)"; }
  : button { key = "Testkey"; label = "Getname"; }
  : text { key = "T1_txt"; }
  : text { key = "T2_txt"; }
  : edit_box {key = "Test_edit1";}
  : edit_box {key = "Test_edit2";}
  ok_cancel;
}

dlg_ChangeAllContfirm:dialog
{
  label = "注意";
  : text { key = "Confirm_txt"; fixed_width = true; width = 35; }
  ok_cancel;
}

dlg_GenFrameDrawingNumber:dialog
{
  label = "填写图号编写规则";
  : edit_box { label = "请填写开始的图号（如：电施-01）"; key = "Input_SN"; }
  ok_only;
}

dlg_FrameManger:dialog
{
  label = "图框管理";
  : row 
  {
    : boxed_column 
    {
      label = "图框库";
      : list_box { key = "FrameList" ; fixed_width = true ; width = 30; fixed_height = true ; height = 30 ; }
    }
    : column 
    {
      : text     { key = "FM_A1" ; fixed_width = true; width = 12; }
      : text     { key = "FM_B1" ; fixed_width = true; width = 12; }
      : text     { key = "FM_C1" ; fixed_width = true; width = 12; }
      : text     { key = "FM_D1" ; fixed_width = true; width = 12; }
      : text     { key = "FM_E1" ; fixed_width = true; width = 12; }
      : text     { key = "FM_F1" ; fixed_width = true; width = 12; }
      : text     { key = "FM_G1" ; fixed_width = true; width = 12; }
      : text     { key = "FM_H1" ; fixed_width = true; width = 12; }
      : text     { key = "FM_I1" ; fixed_width = true; width = 12; }
      : text     { key = "FM_J1" ; fixed_width = true; width = 12; }
      : text     { key = "FM_K1" ; fixed_width = true; width = 12; }
    }
    : column 
    {
      : text     { key = "FM_A2" ; fixed_width = true; width = 60; }
      : text     { key = "FM_B2" ; fixed_width = true; width = 60; }
      : text     { key = "FM_C2" ; fixed_width = true; width = 60; }
      : text     { key = "FM_D2" ; fixed_width = true; width = 60; }
      : text     { key = "FM_E2" ; fixed_width = true; width = 60; }
      : text     { key = "FM_F2" ; fixed_width = true; width = 60; }
      : text     { key = "FM_G2" ; fixed_width = true; width = 60; }
      : text     { key = "FM_H2" ; fixed_width = true; width = 60; }
      : text     { key = "FM_I2" ; fixed_width = true; width = 60; }
      : text     { key = "FM_J2" ; fixed_width = true; width = 60; }
      : text     { key = "FM_K2" ; fixed_width = true; width = 60; }
    }
  }
  : row 
  {
    : button { key = "Add_Frame"; label = "添加图框";fixed_width = true; width = 10; }
    : button { key = "Del_Frame"; label = "删除图框";fixed_width = true; width = 10; }
    : spacer_1 {  }
    : spacer_1 {  }
    : spacer_1 {  }
    ok_only;
  }
}