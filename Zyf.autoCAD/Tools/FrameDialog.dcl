dlg_1:dialog
{
    label="图框划线编号"; 
    : row 
    {
      : row 
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
    }

    : boxed_column
    {
      label = "识别结果";
      : row 
      {
        : text {label = "    序号";                                        key = "T0"; fixed_width = true;}//序号
        : text {label = "|      图号    ";                                 key = "T1"; fixed_width = true;}//图号
        : text {label = "|                      图名                    "; key = "T2"; fixed_width = true;}//图名
        : text {label = "|    日期  ";                                     key = "T3"; fixed_width = true;}//日期
        : text {label = "|                    项目名称                   "; key = "T4"; fixed_width = true;}//项目名称
        : text {label = "|  子项名称";                                     key = "T5"; fixed_width = true;}//子项名称
        : text {label = "|    设计编号  ";                                 key = "T6"; fixed_width = true;}//设计编号
        : text {label = "|           建设单位           ";                 key = "T7"; fixed_width = true;}//建设单位
        : text {label = "|  版本号";                                       key = "T8"; fixed_width = true;}//版本号
        : text {label = "|   图幅  ";                                      key = "T9"; fixed_width = true;}//图幅
      }
          : row //1
      {
        : toggle   {key = "A" ; }
        : spacer_1 {  }
        : text     {key = "A0"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "A1"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//图号
        : edit_box {key = "A2"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "A3"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "A4"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "A5"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "A6"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "A7"; fixed_width = true; width = 32;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "A8"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "A9"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //2
      {
        : toggle   {key = "B" ; }
        : spacer_1 {  }
        : text     {key = "B0"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "B1"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//图号
        : edit_box {key = "B2"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "B3"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "B4"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "B5"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "B6"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "B7"; fixed_width = true; width = 32;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "B8"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "B9"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //3
      {
        : toggle   {key = "C" ; }
        : spacer_1 {  }
        : text     {key = "C0"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "C1"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//图号
        : edit_box {key = "C2"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "C3"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "C4"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "C5"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "C6"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "C7"; fixed_width = true; width = 32;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "C8"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "C9"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //4
      {
        : toggle   {key = "D" ; }
        : spacer_1 {  }
        : text     {key = "D0"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "D1"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//图号
        : edit_box {key = "D2"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "D3"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "D4"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "D5"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "D6"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "D7"; fixed_width = true; width = 32;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "D8"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "D9"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //5
      {
        : toggle   {key = "E" ; }
        : spacer_1 {  }
        : text     {key = "E0"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "E1"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//图号
        : edit_box {key = "E2"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "E3"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "E4"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "E5"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "E6"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "E7"; fixed_width = true; width = 32;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "E8"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "E9"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //6
      {
        : toggle   {key = "F" ; }
        : spacer_1 {  }
        : text     {key = "F0"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "F1"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//图号
        : edit_box {key = "F2"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "F3"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "F4"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "F5"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "F6"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "F7"; fixed_width = true; width = 32;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "F8"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "F9"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //7
      {
        : toggle   {key = "G" ; }
        : spacer_1 {  }
        : text     {key = "G0"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "G1"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//图号
        : edit_box {key = "G2"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "G3"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "G4"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "G5"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "G6"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "G7"; fixed_width = true; width = 32;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "G8"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "G9"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //8
      {
        : toggle   {key = "H" ; }
        : spacer_1 {  }
        : text     {key = "H0"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "H1"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//图号
        : edit_box {key = "H2"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "H3"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "H4"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "H5"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "H6"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "H7"; fixed_width = true; width = 32;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "H8"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "H9"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //9
      {
        : toggle   {key = "I" ; }
        : spacer_1 {  }
        : text     {key = "I0"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "I1"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//图号
        : edit_box {key = "I2"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "I3"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "I4"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "I5"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "I6"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "I7"; fixed_width = true; width = 32;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "I8"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "I9"; fixed_width = true; width = 8;                                        }//图幅
      }
          : row //10
      {
        : toggle   {key = "J" ; }
        : spacer_1 {  }
        : text     {key = "J0"; fixed_width = true; width = 4;                                        }//序号
        : edit_box {key = "J1"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//图号
        : edit_box {key = "J2"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//图名
        : edit_box {key = "J3"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//日期
        : edit_box {key = "J4"; fixed_width = true; width = 48;action = "(EditBox_Change_Data $key)"; }//项目名称
        : edit_box {key = "J5"; fixed_width = true; width = 12;action = "(EditBox_Change_Data $key)"; }//子项名称
        : edit_box {key = "J6"; fixed_width = true; width = 16;action = "(EditBox_Change_Data $key)"; }//设计编号
        : edit_box {key = "J7"; fixed_width = true; width = 32;action = "(EditBox_Change_Data $key)"; }//建设单位
        : edit_box {key = "J8"; fixed_width = true; width = 8; action = "(EditBox_Change_Data $key)"; }//版本号
        : text     {key = "J9"; fixed_width = true; width = 8;                                        }//图幅
      }
    }
    : row
    {
      : spacer_1 {  }
      : button {label = "重新识别"; key = "Identify"; fixed_width = true; width = 20;}
      : button {label = "刷新"; key = "Refresh"; fixed_width = true; width = 20;}
      : button {label = "生成图号"; key = "GenFrameDrawingNumber"; fixed_width = true; width = 20;}
      : button {label = "尝试生成图名"; key = "GenFrameName"; fixed_width = true; width = 20;}
      : button {label = "写入图框"; key = "Execute"; fixed_width = true; width = 20;}
      : button {label = "生成目录"; key = "Gen_Index"; fixed_width = true; width = 20;}
      : spacer_1 {  }
      : spacer_1 {  }
      : button {label = "<< 上一页"; key = "PrePage" ; fixed_width = true; width = 20;}
      : button {label = "下一页 >>"; key = "NextPage"; fixed_width = true; width = 20;}
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
  : text { key = "Confirm_txt"; }
  ok_cancel;
}

dlg_GenFrameDrawingNumber:dialog
{
  label = "填写图号编写规则";
  : edit_box { label = "请填写开始的图号（如：电施-01）"; key = "Input_SN"; }
  ok_only;
}