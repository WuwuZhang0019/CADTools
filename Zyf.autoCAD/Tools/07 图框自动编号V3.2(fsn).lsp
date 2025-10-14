;【读取数据库文件】
(defun Read_DataBase(/ DataBaseContect Now_line_Strings Temp_List)
  (setq ff (open "C:\\FSNDataBase" "r"))
  (setq Frame_Unit_List nil)
  (setq DataBaseContect "")
  (while (setq Now_line_Strings (read-line ff))
    (setq DataBaseContect (strcat DataBaseContect Now_line_Strings))
    (if (= Now_line_Strings ")")
      (setq Temp_List (eval (read DataBaseContect))
            Frame_Unit_List (cons Temp_List Frame_Unit_List)
            DataBaseContect ""
      )
    )
  )
  (close ff)
)

;【写入数据库文件】
(defun Write_DataBase(/ Temp_Frame_list Temp_Info_list)
  (setq ff (open "C:\\FSNDataBase" "w"))
  (setq Temp_Frame_list Frame_Unit_List)
  (while Temp_Frame_list
    (setq Temp_Info_list (car Temp_Frame_list))
    (setq Temp_Frame_list (cdr Temp_Frame_list))
    (write-line (strcat "(list \"" (car Temp_Info_list) "\" ") ff)
    (setq Temp_Info_list (cdr Temp_Info_list))
    (while Temp_Info_list
      (write-line (strcat "  '" (vl-prin1-to-string (car Temp_Info_list))) ff)
      (setq Temp_Info_list (cdr Temp_Info_list))
    )
    (write-line ")\n" ff)
  )
  (close ff)
)

;【读取数据库】
(if (open "C:\\FSNDataBase" "r")
  (Read_DataBase)
  (alert "数据库为空，请先添加图框")
)


;【初始化】
(defun Initialize()
  ;设定图框尺寸
  (setq FrameModel_List (List '("A0" 1189.0 841.0)
                              '("A1" 841.0 594.0)
                              '("A2" 594.0 420.0)
                              '("A3" 420.0 297.0)
                        )
        Unit_List '("序号" "图号" "图名" "日期" "项目名称" "子项名称" "设计编号" "建设单位" "版本号")
  )
  ;设定图框筛选规则
  (setq Frame_Name_list (mapcar 
                        (function
                          (lambda
                            (x)
                            (car x)
                          )
                        )
                        Frame_Unit_List
                      )
      FrameIdentify_Rules (append  
                            (list 
                              '(-4 . "<and")
                                '(0 . "INSERT")
                                '(-4 . "<or")
                            )
                            (mapcar
                              (function
                                (lambda
                                  (x)
                                  (cons 2 x)
                                )
                              )
                              Frame_Name_list
                            )
                            (list
                                '(-4 . "or>")
                              '(-4 . "and>")
                            )
                          )
  )
  ;设定执行顺序
  (setq Execute_List '("图号"
                       "次图号"
                       "图名"
                       "日期"
                       "项目名称"
                       "子项名称"
                       "设计编号"
                       "建设单位"
                       "版本号" 
                      ) 
  )
)


;初始设定
(princ "已载入图块划线，快捷命令【FSN】,有问题请联系汤润泽,QQ495697659")
(setq Pick_mode nil
      Sub_Number_mode "0"
      Input_String "电施-01"
      Frame_Ename_List nil
)
(Initialize)


;主函数
(defun c:fsn()
  (setq Stage 1)
  (while Stage
    (cond ((= Stage 1) (princ "\nConfirm_Stage") (Confirm_Stage))
          ((= Stage 3) (princ "\nPick_Stage") (Pick_Stage))
          ((= Stage 4) (princ "\nSelectFrame_Stage") (SelectFrame_Stage))
          ((= Stage 5) (princ "\nRefresh_All_Frame_Data") (Refresh_All_Frame_Data))
          ((= Stage 6) (princ "\nOutput_Stage") (Output_Stage))
          ((= Stage 7) (princ "\nGen_Frame_Name_Stage") (Gen_Frame_Name_Stage))
          ((= Stage 8) (princ "\nGen_Index_Stage") (Gen_Index_Stage))
          ((= Stage 9) (princ "\nManger_Frame_Stage") (Manger_Frame_Stage))
          ((= Stage 10) (princ "\nGet_Frame_Zone_Stage") (Add_Frame_Stage))
          ((= Stage 0) (princ "\nExit") (exit))
    )
  )
)


;【Stage1】主界面
(defun Confirm_Stage()
  (setq Page_index 0)
  (setq Dlg_id (load_dialog "FrameDialog"))
  (if (< Dlg_id 0) (progn (alert "未找到DCL文件") (exit)))
  (if (not (new_dialog "dlg_Main" Dlg_id)) (progn (alert "初始化DCL对话框失败") (exit)))
  (Set_MainDia_Data)
  (action_tile "Draw" "(setq Pick_mode nil)")
  (action_tile "Pick" "(setq Pick_mode T)")
  (action_tile "Start_Pick" "(setq stage 3)(done_dialog)")
  (action_tile "NextPage" "(Next_Page_index)")
  (action_tile "PrePage" "(Pre_Page_index)")
  (action_tile "Identify" "(setq stage 5)(done_dialog)")
  (action_tile "Execute" "(setq stage 6)(done_dialog)")
  (action_tile "GenFrameName" "(setq stage 7)(done_dialog)")
  (action_tile "GenFrameDrawingNumber" "(Gen_Frame_Drawing_Number)")
  (action_tile "GenFrameSubNumber" "(Gen_Frame_Sub_Number)")
  (action_tile "Gen_Index" "(setq stage 8)(done_dialog)")
  (action_tile "Refresh" "(Set_MainDia_Data)")
  (action_tile "Manger_Frame" "(setq stage 9)(done_dialog)")
  (action_tile "accept" "(setq stage 0)(done_dialog)")
  (action_tile "Enable_SubName" "(setq Sub_Number_mode $value)(Set_MainDia_Data)")
  (start_dialog)
)


;|
  主界面翻下一页
|;
(defun Next_Page_index()
  (if (and Frame_Ename_List
           (> (- (length Frame_Ename_List) Page_index) 10)
      )
    (setq Page_index (+ Page_index 10))
  )
  (Set_MainDia_Data)
)


;|
  主界面翻上一页
|;
(defun Pre_Page_index()
  (if (and Frame_Ename_List
           (> Page_index 0)
      )
    (setq Page_index (- Page_index 10))
  )
  (Set_MainDia_Data)
)


;|
  复选框全选
|;
(defun Temp_SelectAll()
  (if Temp_Toggle_list
    (setq Temp_Toggle_list (mapcar
                             (function
                              (lambda
                                (ttl)
                                (cons (car ttl) "1")
                              )
                             )
                             Temp_Toggle_list
                           )
    )
  )
  (Set_MainDia_Data)
)


;|
  复选框全不选
|;
(defun Temp_SelectNone()
  (if Temp_Toggle_list
    (setq Temp_Toggle_list (mapcar
                             (function
                              (lambda
                                (ttl)
                                (cons (car ttl) "0")
                              )
                             )
                             Temp_Toggle_list
                           )
    )
  )
  (Set_MainDia_Data)
)


;|
  按顺序编写图号
  @Returns no return
|;
(defun Gen_Frame_Drawing_Number(/ loop Total_Frame_Number)
  (Input_Process)
  (if (not (new_dialog "dlg_GenFrameDrawingNumber" Dlg_id)) (progn (alert "初始化DCL对话框失败") (exit)))
  (if (and Input_String (not (= Input_String "")))
    (set_tile "Input_SN" Input_String)
  )
  (action_tile "Input_SN" "(setq Input_String $value)(if Input_String (Input_Process) (alert \"请输入起始的图号（例如：电施-01）\"))")
  (action_tile "accept" "(setq stage 1)(done_dialog)")
  (start_dialog)
  (setq loop 0
        Total_Frame_Number (length Frame_Ename_List)
  )
  (while (<= loop Total_Frame_Number)
    (setq Output_String (strcat 
                          SN_Prefix 
                          (T_rtos Current_SN (max SN_Bit (strlen (rtos Total_Frame_Number 2 0))))
                          SN_Suffix
                        )
          All_Frame_Data_List (subst (T_subst Output_String 1 (nth loop All_Frame_Data_List)) (nth loop All_Frame_Data_List) All_Frame_Data_List)
          loop (+ loop 1)
          Current_SN (1+ Current_SN)
    )
  )
  (Set_MainDia_Data)
)


;|
  编写次图号
  @Returns no return
|;
(defun Gen_Frame_Sub_Number()
  ()
  (if (not (new_dialog "dlg_GenFrameDrawingNumber" Dlg_id)) (progn (alert "初始化DCL对话框失败") (exit)))
  (if (and Input_String (not (= Input_String "")))
    (set_tile "Input_SN" Input_String)
  )
  (action_tile "Input_SN" "(setq Input_String $value)(if Input_String (Input_Process) (alert \"请输入起始的图号（例如：电施-01）\"))")
  (action_tile "accept" "(setq stage 1)(done_dialog)")
  (start_dialog)
  (setq loop 0
        Total_Frame_Number (length Frame_Ename_List)
  )
  (while (<= loop Total_Frame_Number)
    (setq Output_String (strcat 
                          SN_Prefix 
                          (T_rtos Current_SN (max (strlen (rtos Total_Frame_Number 2 0)) 2))
                          SN_Suffix
                        )
          All_Frame_Data_List (subst (T_subst Output_String 1 (nth loop All_Frame_Data_List)) (nth loop All_Frame_Data_List) All_Frame_Data_List)
          loop (+ loop 1)
          Current_SN (1+ Current_SN)
    )
  )
  (Set_MainDia_Data)
)


;【Stage3】读取PL路线
(defun Pick_Stage(/ Pick_result PL_entname)
  (if Pick_mode
    (progn
      (while (null (and (setq Pick_result (entsel))
                        (= (cdr (assoc 0 (entget (car Pick_result)))) "LWPOLYLINE")   
                   )
             )
        (print "请选择一条多段线！")
      )
      (setq PL_entname (car Pick_result))
    )
    (progn
      (vl-cmdf "_Pline" pause)
      (pauseing)
      (setq PL_entname (entlast))
    )
  )
  (setq P_list (Point_Get PL_entname)
        Stage 4
  )
  (if PL_entname
    (entdel PL_entname)
  )
)


;【Stage4】识别图框
(defun SelectFrame_Stage()
  (setq Frame_Set (ssget "F" P_list FrameIdentify_Rules)
        Frame_Ename_List (SS_To_EntNameList Frame_Set)
  )                     
  (if (null Frame_Ename_List) 
    (progn (alert "未检测到图框") (setq Stage 1))
    (setq Stage 5)
  )
)


;【Stage5】读取图签数据至Datalist
(defun Refresh_All_Frame_Data(/ Current_Selectmode Temp_Frame_Ename_List Operation_list Now_Frame_Data_List Now_Frame_Ename Now_Frame_Model)
  (setq Temp_Frame_Ename_List Frame_Ename_List
        All_Frame_Data_List nil
        Temp_Toggle_list nil
        Current_Selectmode (getvar "selectionoffscreen")
  )
  (setvar "selectionoffscreen" 2)
  (acet-ui-progress "正在识别图框信息" (length Temp_Frame_Ename_List))
  (while Temp_Frame_Ename_List
    (setq Now_Frame_Ename (car Temp_Frame_Ename_List)
          Now_Frame_Name (cdr (assoc 2 (entget Now_Frame_Ename)))
          Now_Frame_Model (Determine_Frame Now_Frame_Ename)
          Now_Frame_Unit_Zone_list (cdr (assoc Now_Frame_Name Frame_Unit_List))
          Now_Frame_Data_List nil
          Now_Serial_Number (1+ (vl-position Now_Frame_Ename Frame_Ename_List))
          Operation_list Execute_List
    )
    (setq Temp_Toggle_list (cons (cons Now_Frame_Ename "0") Temp_Toggle_list))
    (while Operation_list
      (setq Now_Frame_Data_List (cons (Get_Frame_Unit_Txt Now_Frame_Ename (car Operation_list)) Now_Frame_Data_List))
      (setq Operation_list (cdr Operation_list))
    )
    (setq Now_Frame_Data_List (cons Now_Frame_Ename (reverse (cons Now_Frame_Model Now_Frame_Data_List)))
          All_Frame_Data_List (cons Now_Frame_Data_List All_Frame_Data_List)
          Temp_Frame_Ename_List (cdr Temp_Frame_Ename_List)
    )
    (acet-ui-progress Now_Serial_Number)
  )
  (acet-ui-progress)
  (setvar "selectionoffscreen" Current_Selectmode)
  (setq Stage 1)
)


;【Stage6】写入图签数据
(defun Output_Stage(/ Temp_Frame_Data_list Current_layer Target_layer Current_Selectmode Now_Serial_Number
                    Now_Frame_Data_List Operation_list Now_Unit Now_Unit_Order Now_Data Original_Data 
                    Data_Zone_Abs_Point_List Txt_Mid_Point Txtss Now_Frame_Scale Now_Frame_Angle Now_Frame_Ename Now_Frame_Name)
  (defun Write_Data()
    (if 
      (and  (= Sub_Number_mode "1")
            (= Now_Unit "图号")
      ) 
      (setq Now_Unit "图号2")
    )
    (if (not  (and (= Sub_Number_mode "0")
                  (= Now_Unit "次图号")
              )
        )
      (progn
        (setq Data_Zone_Abs_Point_List (Create_Zone_Plist Now_Frame_Ename (cdr (assoc Now_Unit Now_Frame_Unit_Zone_list)))
              Txt_Mid_Point (Mid_Point (car Data_Zone_Abs_Point_List) (caddr Data_Zone_Abs_Point_List))
        )
        (if Data_Zone_Abs_Point_List
          (progn
            (if (ssget "CP" Data_Zone_Abs_Point_List  '( (-4 . "<or")
                                                            (0 . "TEXT")
                                                            (0 . "MTEXT")
                                                            (-4 . "or>")
                                                          )
                )
              (vl-cmdf "._erase" "P" "")
            )
            (if (not (= Now_Data ""))
              (Create_Txt Now_Data Txt_Mid_Point (* 3.5 Now_Frame_Scale) Now_Frame_Angle (distance (car Data_Zone_Abs_Point_List) (cadr Data_Zone_Abs_Point_List)) (distance (car Data_Zone_Abs_Point_List) (last Data_Zone_Abs_Point_List)))
            )
          )
        )
      )
    )
  )
  (setq Current_layer (getvar "clayer")
        Target_layer "lz_属性字"
        Current_Selectmode (getvar "selectionoffscreen")
        Temp_Frame_Data_list All_Frame_Data_List
        Now_Serial_Number 1
  )
  (setvar "selectionoffscreen" 2)
  (if (tblsearch "layer" Target_layer)
    (setvar "clayer" Target_layer)
    (progn  
      (MakeLayer Target_layer 7)
      (setvar "clayer" Target_layer)
    )
  )
  (acet-ui-progress "正在写入图框信息" (length Temp_Frame_Data_list))
  (while Temp_Frame_Data_list
    (setq Now_Frame_Data_List (car Temp_Frame_Data_list)
          Now_Frame_Ename (car Now_Frame_Data_List)
          Now_Frame_DXF (entget Now_Frame_Ename)
          Now_Frame_Scale (cdr (assoc 41 Now_Frame_DXF))
          Now_Frame_Angle (cdr (assoc 50 Now_Frame_DXF))
          Now_Frame_Name (cdr (assoc 2 Now_Frame_DXF))
          Now_Frame_Unit_Zone_list (cdr (assoc Now_Frame_Name Frame_Unit_List))
          Operation_list Execute_List
    )
    (while Operation_list
      (setq Now_Unit (car Operation_list)
            Now_Unit_Order (1+ (vl-position Now_Unit Execute_List))
            Now_Data (nth Now_Unit_Order Now_Frame_Data_List)
            Original_Data (Get_Frame_Unit_Txt Now_Frame_Ename Now_Unit)
      )
      (if (not (= Now_Data Original_Data))
        (Write_Data)
      ) 
      (setq Operation_list (cdr Operation_list))
    )
    (acet-ui-progress Now_Serial_Number)
    (setq Now_Serial_Number (1+ Now_Serial_Number)
          Temp_Frame_Data_list (cdr Temp_Frame_Data_list)
    )
  )
  (acet-ui-progress)
  (setvar "clayer" Current_layer)
  (setvar "selectionoffscreen" Current_Selectmode)
  (alert "图形写入完毕")
  (setq stage 0)
)


;【Stage7】生成图名
(defun Gen_Frame_Name_Stage(/ Temp_Frame_Data_list Current_Selectmode Now_Frame_Data Now_Frame_Ename Now_Frame_Length 
                            Now_Frame_Width Now_Frame_Zone FN_SS FN_String FN_namelist Execute_Data_List LOOP Now_Frame_Name Now_Frame_Model FramePlist Now_Frame_Scale True_Scale)
  (setq Current_Selectmode (getvar "selectionoffscreen")
        Temp_Frame_Data_list All_Frame_Data_List
        LOOP 0
  )
  (setvar "selectionoffscreen" 2)
  (acet-ui-progress "正在识别图名" (length Temp_Frame_Data_list))
  (while Temp_Frame_Data_list
    (setq Now_Frame_Data (car Temp_Frame_Data_list)
          Now_Frame_Ename (car Now_Frame_Data)
          Now_Frame_Scale (cdr (assoc 41 (entget Now_Frame_Ename)))
          FramePlist (Get_Pointlist_Inside_Block Now_Frame_Ename)
    )
    (setq Now_Frame_Width (distance (cadr FramePlist) (caddr FramePlist)))
    (setq Now_Frame_Length (distance (car FramePlist) (cadr FramePlist)))
    (if (> Now_Frame_Width 2000.0)
      (setq True_Scale (/ Now_Frame_Width (last (assoc (last Now_Frame_Data) FrameModel_List)))
            Now_Frame_Width (/ Now_Frame_Width True_Scale)
            Now_Frame_Length (/ Now_Frame_Length True_Scale)
      )
    )
    (setq Now_Frame_Zone (Create_Zone_Plist 
                           Now_Frame_Ename 
                           (list 
                             '(0.0 0.0 0.0) 
                             (list 0.0 Now_Frame_Width 0.0) 
                             (list Now_Frame_Length Now_Frame_Width 0.0) 
                             (list Now_Frame_Length 0.0 0.0) 
                           )
                         )
    )
    (if (setq FN_SS (ssget "WP" Now_Frame_Zone '((0 . "TCH_DRAWINGNAME"))))
      (progn  
        (setq FN_namelist (SS_To_EntNameList FN_SS)
              FN_String ""
        )
        (while FN_namelist
          (if (= FN_String "")
            (setq FN_String (cdr (assoc 1 (entget (car FN_namelist))))
                  FN_namelist (cdr FN_namelist)
            )
            (setq FN_String (strcat FN_String "、" (cdr (assoc 1 (entget (car FN_namelist)))))
                  FN_namelist (cdr FN_namelist)
            )
          )
        )
        (setq Execute_Data_List (T_subst FN_String 3 Now_Frame_Data)
              All_Frame_Data_List (subst Execute_Data_List (assoc (car Execute_Data_List) All_Frame_Data_List) All_Frame_Data_List)
        )
      )
    )
    (setq Temp_Frame_Data_list (cdr Temp_Frame_Data_list)
          LOOP (1+ LOOP)
    )
    (acet-ui-progress LOOP)
  )
  (acet-ui-progress)
  (setvar "selectionoffscreen" Current_Selectmode)
  (setq Stage 1)
)


;【Stage8】生成目录
(defun Gen_Index_Stage( / BP Index_W HeadRow_H Row_H Index_H C1 C2 C3 C4 osmode clayer R_C Temp_Frame_Data_List Now_Frame_Data_List NBP loop)
  (setq BP (getpoint "选择生成目录的基点")
        Row_Each_Page 45
        Index_W 17500.0
        HeadRow_H 1000.0
        Row_H 900.0
        Index_H (+ (* Row_Each_Page Row_H) HeadRow_H)
        C1 1000.0
        C2 10150.0
        C3 11950.0
        C4 13750.0
        C5 14950.0
        osmode (getvar "osmode")
        clayer (getvar "clayer")
        cecolor (getvar "cecolor")
        R_C 0.0
        loop 1
        Temp_Frame_Data_List All_Frame_Data_List
  )
  (setvar "clayer" "0")
  (setvar "osmode" 0)
  (command-s "-color" "BYLAYER")
  (command-s "PLINE" '(0.0 0.0 0.0) "w" 60.0 "" "")
  (while Temp_Frame_Data_List
    (command-s "PLINE" BP (Point_Offset BP 0.0 Index_H 0.0) (Point_Offset BP Index_W Index_H 0.0) (Point_Offset BP Index_W 0.0 0.0) BP "")
    (command-s "PLINE" (Point_Offset BP 0.0 (- Index_H HeadRow_H) 0.0) (Point_Offset BP Index_W (- Index_H HeadRow_H) 0.0) "")
    (command-s "LINE" (Point_Offset BP C1 0.0 0.0) (Point_Offset BP C1 Index_H 0.0) "")
    (command-s "LINE" (Point_Offset BP C2 0.0 0.0) (Point_Offset BP C2 Index_H 0.0) "")
    (command-s "LINE" (Point_Offset BP C3 0.0 0.0) (Point_Offset BP C3 Index_H 0.0) "")
    (command-s "LINE" (Point_Offset BP C4 0.0 0.0) (Point_Offset BP C4 Index_H 0.0) "")
    (command-s "LINE" (Point_Offset BP C5 0.0 0.0) (Point_Offset BP C5 Index_H 0.0) "")
    (Create_Txt "序号"           (Mid_Point (Point_Offset BP 0.0 (- Index_H HeadRow_H) 0.0) (Point_Offset BP C1 Index_H 0.0)) 500.0 0.0 C1 HeadRow_H)
    (Create_Txt "图  纸  名  称" (Mid_Point (Point_Offset BP C1 (- Index_H HeadRow_H) 0.0) (Point_Offset BP C2 Index_H 0.0)) 500.0 0.0 (- C2 C1) HeadRow_H)
    (Create_Txt "图号"           (Mid_Point (Point_Offset BP C2 (- Index_H HeadRow_H) 0.0) (Point_Offset BP C3 Index_H 0.0)) 500.0 0.0 (- C3 C2) HeadRow_H)
    (Create_Txt "更改版次"       (Mid_Point (Point_Offset BP C3 (- Index_H HeadRow_H) 0.0) (Point_Offset BP C4 Index_H 0.0)) 500.0 0.0 (- C4 C3) HeadRow_H)
    (Create_Txt "图幅"           (Mid_Point (Point_Offset BP C4 (- Index_H HeadRow_H) 0.0) (Point_Offset BP C5 Index_H 0.0)) 500.0 0.0 (- C5 C4) HeadRow_H)
    (Create_Txt "备  注"         (Mid_Point (Point_Offset BP C5 (- Index_H HeadRow_H) 0.0) (Point_Offset BP Index_W Index_H 0.0)) 500.0 0.0 (- Index_W C5) HeadRow_H)
    (while (< R_C (- Index_H HeadRow_H))
      (setq Now_Frame_Data_List (car Temp_Frame_Data_List)
            Temp_Frame_Data_List (cdr Temp_Frame_Data_List)
            R_C (+ R_C Row_H)
            NBP (Point_Offset BP 0.0 (- Index_H HeadRow_H R_C) 0.0)
      )
      (if (not Now_Frame_Data_List)
        (setq Now_Frame_Data_List '("" "" "" "" "" "" "" "" "" ""))
      )
      (command-s "LINE" NBP (Point_Offset NBP Index_W 0.0 0.0) "")
      (Create_Txt2 (if (<= loop (length All_Frame_Data_List)) (rtos loop 2 0) "") (Mid_Point NBP (Point_Offset NBP C1 Row_H 0.0)) 350.0 0.0 C1 Row_H)
      (Create_Txt2 (nth 3 Now_Frame_Data_List) (Mid_Point (Point_Offset NBP C1 0.0 0.0) (Point_Offset NBP C2 Row_H 0.0)) 350.0 0.0 (- C2 C1) Row_H)
      (Create_Txt2 (nth 1 Now_Frame_Data_List) (Mid_Point (Point_Offset NBP C2 0.0 0.0) (Point_Offset NBP C3 Row_H 0.0)) 350.0 0.0 (- C3 C2) Row_H)
      (Create_Txt2 (last Now_Frame_Data_List)  (Mid_Point (Point_Offset NBP C4 0.0 0.0) (Point_Offset NBP C5 Row_H 0.0)) 350.0 0.0 (- C5 C4) Row_H)
      (setq loop (1+ loop))
    )
    (setq BP (Point_Offset BP Index_W 0.0 0.0)
          R_C 0.0
    )
  )
  (setvar "osmode" osmode)
  (setvar "clayer" clayer)
  (setvar "cecolor" cecolor)
  (setq Stage 0)
)


;【Stage9】管理图框
(defun Manger_Frame_Stage()
  (setq List_value 0)
  (defun Set_MangerDia_Data(/ FrameInfo Cursor)
    (if Frame_Unit_List
      (progn
        (setq FrameInfo (cdr (nth List_value Frame_Unit_List))
          Cursor (ascii "A")
        )
        (while FrameInfo
          (setq Now_Info (car FrameInfo)
                P1 (nth 1 Now_Info)
                P2 (nth 3 Now_Info)
                P_Strs  (strcat 
                          "("
                          (rtos (car P1) 2 1) 
                          "," 
                          (rtos (last P1) 2 1) 
                          ") ("
                          (rtos (car P2) 2 1) 
                          "," 
                          (rtos (last P2) 2 1)
                          ")"
                        )
          )
          (set_tile (strcat "FM_" (chr Cursor) "1") (car Now_Info))
          (set_tile (strcat "FM_" (chr Cursor) "2") P_Strs)
          (setq Cursor (1+ Cursor)
                FrameInfo (cdr FrameInfo)
          )
        )
        (start_list "FrameList")
          (mapcar 'add_list (mapcar 
                              (function
                                (lambda
                                  (x)
                                  (car x)
                                )
                              )
                              Frame_Unit_List
                            )
          )
        (end_list)
        (set_tile "FrameList" (rtos List_value 2 0))
      )
    )
  )
  (if (not (new_dialog "dlg_FrameManger" Dlg_id)) (progn (alert "初始化DCL对话框失败") (exit)))
  (Set_MangerDia_Data)
  (action_tile "FrameList" "(setq List_value (atoi $value))(Set_MangerDia_Data)")
  (action_tile "Add_Frame" "(setq stage 10)(done_dialog)")
  (action_tile "Del_Frame" "(Del_Frame)(Set_MangerDia_Data)")
  (action_tile "accept" "(setq stage 1)(done_dialog)")
  (start_dialog)
)


;【Stage10】添加图框
(defun Add_Frame_Stage(/ Ref_Plist del_list EntName Pick_result osmode Frame_size loop zonename PA PB Xa Ya Xb
                       Yb P1 P2 P3 P4 L H Temp_Plist TP1 TP2 TP3 TP4 TL TH THL MP1 MP2 Temp_Plist1 Temp_Plist2
                       FrameName
                      )
  (command-s "PLINE" '(0.0 0.0 0.0) "w" 0.0 "" "")
  (setq Ref_Plist nil
        del_list nil
  )
  (while (null (and (setq Pick_result (entsel))
                    (= (dxf (car Pick_result) 0) "INSERT")   
               )
         )
        (print "请选择一个图块！")
  )
  (setq EntName (car Pick_result)
        FrameName (dxf EntName 2)
        osmode (getvar "osmode")
        Add_Symbol 1
  )
  (if (member FrameName (mapcar (function (lambda (x) (car x))) Frame_Unit_List))
    (progn
      (if (not (new_dialog "dlg_ChangeAllContfirm" Dlg_id)) (progn (alert "初始化DCL对话框失败") (exit)))
      (set_tile "Confirm_txt" "数据库内已存在同名图框，是否替换？")
      (action_tile "accept" "(done_dialog 1)")
      (action_tile "cancel" "(done_dialog 0)")
      (setq Add_Symbol (start_dialog))
    )
  )
  (if (= Add_Symbol 1)
    (progn
      (vl-cmdf "_.layout" "N" "FSN_Temp")
      (setq ctab (getvar "ctab"))
      (setvar "ctab" "FSN_Temp")
      (vl-cmdf "_.ERASE" "_all" "")
      (entmakex (LIST '(0 . "INSERT") 
                      (cons 2 FrameName)
                      '(10 0.0 0.0 0.0)
                )
      )
      (command-s "zoom" "o" (car (setq del_list (cons (entlast) del_list))) "")
      (setq Frame_size (Determine_Frame (entlast))
            loop 0
      )
      (while (setq zonename (nth loop Unit_List))
        (setq PA (getpoint (strcat "\n【" zonename "】拾取矩形范围的一点: ")))
        (setq PB (getpoint (strcat "\n【" zonename "】拾取另一点: ")))
        (setq Xa (car PA)
              Ya (cadr PA)
              Xb (car PB)
              Yb (cadr PB)
              P1 (list (min Xa Xb) (min Ya Yb))
              P2 (list (max Xa Xb) (min Ya Yb))
              P3 (list (max Xa Xb) (max Ya Yb))
              P4 (list (min Xa Xb) (max Ya Yb))
              L (distance P1 P2)
              H (distance P2 P3)
              Ref_Plist (cons (list zonename P1 P2 P3 P4) Ref_Plist)
              loop (1+ loop)
        )
        (setvar "osmode" 0)
        (command-s "PLINE" P1 P2 P3 P4 P1 P3 P2 P4 "")
        (setq del_list (cons (entlast) del_list))
        (Create_Txt zonename (Mid_Point P1 P3) (* H 0.75) 0.0 L H)
        (setq del_list (cons (entlast) del_list))
        (setvar "osmode" osmode)
      )
      (setq Ref_Plist (reverse Ref_Plist))
      (setq Temp_Plist (cdr (assoc "图号" Ref_Plist))
            TP1 (car Temp_Plist)
            TP2 (cadr Temp_Plist)
            TP3 (caddr Temp_Plist)
            TP4 (last Temp_Plist)
            TL (distance TP1 TP2)
            TH (distance TP2 TP3)
            THL (/ TL 2.0)
            MP1 (list (car (Mid_Point TP1 TP2)) (cadr (Mid_Point TP1 TP2)))
            MP2 (list (car (Mid_Point TP3 TP4)) (cadr (Mid_Point TP3 TP4)))
            Temp_Plist1 (list
                          "图号2"
                          TP1
                          MP1
                          MP2
                          TP4
                        )
            Temp_Plist2 (list
                          "次图号"
                          MP1
                          TP2
                          TP3
                          MP2
                        )
      )
      (setq Ref_Plist (append (list FrameName) Ref_Plist (list Temp_Plist1) (list Temp_Plist2)))
      (if (setq Oldlist (assoc FrameName Frame_Unit_List))
        (setq Frame_Unit_List (vl-remove Oldlist Frame_Unit_List))
      )
      (setq Frame_Unit_List (cons Ref_Plist Frame_Unit_List))
      (Write_DataBase)
      (Read_DataBase)
      (Initialize)
      (mapcar 'entdel del_list)
      (setvar "ctab" ctab)
      (vl-cmdf "_.layout" "D" "FSN_Temp")
      (setvar "osmode" osmode)
    )
  )
  (setq Stage 9)
)



;|
  删除图框库内当前图框
  @Returns ?
|;
(defun Del_Frame()
  (setq Frame_Unit_List (vl-remove (nth List_value Frame_Unit_List) Frame_Unit_List))
  (setq ff (open "C:\\FSNDataBase" "w"))
)


;|
  刷新主对话框数据
  @Returns no return
|;
(defun Set_MainDia_Data(/ Temp_Frame_Data_list Now_Row Now_Column Now_Frame_Data_List Box_Name)
  (if Frame_Ename_List 
    (progn 
      (mode_tile "Gen_Index" 0)
      (if (> Page_index 0)
        (mode_tile "PrePage" 0)
        (mode_tile "PrePage" 1)
      )
      (if (> (- (length Frame_Ename_List) Page_index) 10)
        (mode_tile "NextPage" 0)
        (mode_tile "NextPage" 1)
      )
      (setq Show_Frame_Data_list (ReadList_To_Sublist Page_index 10 All_Frame_Data_List))
      (setq Temp_Frame_Data_list Show_Frame_Data_list)
      (setq Now_Row 0
            Now_Column 0
      )
      (while (null (= (rem (length Temp_Frame_Data_list) 10) 0))
        (setq Temp_Frame_Data_list (append Temp_Frame_Data_list '(("" "" "" "" "" "" "" "" "" ""))))
      )
      (while Temp_Frame_Data_list
        (setq Now_Frame_Data_List (car Temp_Frame_Data_list))
        (if (not (= (car Now_Frame_Data_List) ""));【检查是否为空行】
          (progn
            ;【复选框】
            (mode_tile (chr (+ Now_Row 65)) 0)
            (set_tile 
              (chr (+ Now_Row 65)) 
              (cdr (assoc (car Now_Frame_Data_List) Temp_Toggle_list))
            )
            ;【序号】
            (mode_tile (strcat (chr (+ Now_Row 65)) "00") 0)
            (set_tile 
              (strcat (chr (+ Now_Row 65)) (T_rtos Now_Column 2)) 
              (rtos (1+ (vl-position Now_Frame_Data_List All_Frame_Data_List)) 2 0)
            )
            (setq Now_Column (1+ Now_Column))
            ;【图号，次图号，图名，日期，项目名称，子项名称，设计编号，建设单位，版本号，图幅】
            (setq Now_Frame_Data_List (cdr Now_Frame_Data_List))
            (while Now_Frame_Data_list
              (setq Box_Name (strcat (chr (+ Now_Row 65)) (T_rtos Now_Column 2)))
              
              (if (= Now_Column 2);【检查是否为次图号列】
                (if (= Sub_Number_mode "1");【检查是否启用次图号模式】
                  (progn 
                    (mode_tile Box_Name 0)
                    (set_tile Box_Name (Clear_String_Unused_Info (car Now_Frame_Data_List)))
                  )
                  (progn
                    (set_tile Box_Name "")                  
                    (mode_tile Box_Name 1)
                  )
                )
                (progn
                  (mode_tile Box_Name 0)
                  (set_tile 
                    Box_Name
                    (Clear_String_Unused_Info (car Now_Frame_Data_List))
                  )
                )
              )
              (setq Now_Frame_Data_List (cdr Now_Frame_Data_List)
                    Now_Column (1+ Now_Column)
              )
            )
          )
          (progn 
            (mode_tile (chr (+ Now_Row 65)) 1)
            (repeat 11
              (setq Box_Name (strcat (chr (+ Now_Row 65)) (T_rtos Now_Column 2)))
              (set_tile Box_Name "")
              (mode_tile Box_Name 1)
              (setq Now_Column (1+ Now_Column))
            )
          )
        )
        (setq Temp_Frame_Data_list (cdr Temp_Frame_Data_list)
              Now_Row (1+ Now_Row)
              Now_Column 0
        )
      )
    )
    (progn
      (mode_tile "PrePage" 1)
      (mode_tile "NextPage" 1)
      (mode_tile "Identify" 1)
      (mode_tile "Execute" 1)
      (mode_tile "GenFrameName" 1)
      (mode_tile "GenFrameDrawingNumber" 1)
      (mode_tile "GenFrameSubNumber" 1)
      (mode_tile "Refresh" 1)
      (mode_tile "Gen_Index" 1)
      (setq Now_Row 0
            Now_Column 0
      )
      (repeat 10 
        (mode_tile (chr (+ Now_Row 65)) 1)
        (repeat 8
          (mode_tile (strcat (chr (+ Now_Row 65)) (chr (+ Now_Column 49))) 1)
          (setq Now_Column (1+ Now_Column))
        )
        (setq Now_Row (1+ Now_Row)
              Now_Column 0
        )
      )
    )
  )
  ;更新选项
  ;拾取模式
  (if Pick_mode
    (set_tile "Pick" "1")
    (set_tile "Draw" "1")
  )
  ;次图号模式
  (if (= Sub_Number_mode "1")
    (progn    
      (set_tile "Enable_SubName" "1")
      (mode_tile "GenFrameSubNumber" 0)
    )
    (progn
      (set_tile "Enable_SubName" "0")
      (mode_tile "GenFrameSubNumber" 1)
    )
  )
)


;|
  去除多行文字中对于字宽的控制符
  @Param STR 输入字符串
  @Returns ?
|;
(defun Clear_String_Unused_Info(STR / Unused_Info_SP Unused_Info_KP Unused_Info_EP Applist1 Applist2 Applist3)
  (if STR
    (progn
      (setq Temp_STR_Ascii_List (vl-string->list STR))
      (while  (and 
                (member 123 Temp_STR_Ascii_List)
                (= (cadr (member 123 Temp_STR_Ascii_List)) 92)
                (member 125 Temp_STR_Ascii_List)
                (> (- (length (member 123 Temp_STR_Ascii_List)) (length (member 125 Temp_STR_Ascii_List))) 5)
              )
        (setq Unused_Info_SP (vl-position 123 Temp_STR_Ascii_List)
              Unused_Info_KP (vl-position 59 Temp_STR_Ascii_List)
              Unused_Info_EP (vl-position 125 Temp_STR_Ascii_List)
              Applist1 (ReadList_To_Sublist 0 Unused_Info_SP Temp_STR_Ascii_List)
              Applist2 (ReadList_To_Sublist (1+ Unused_Info_KP) (1- (- Unused_Info_EP Unused_Info_KP)) Temp_STR_Ascii_List)
              Applist3 (ReadList_To_Sublist (1+ Unused_Info_EP) (- (1- (length Temp_STR_Ascii_List)) Unused_Info_EP) Temp_STR_Ascii_List)
              Temp_STR_Ascii_List (append Applist1 Applist2 Applist3)
        )
      )
      (vl-list->string Temp_STR_Ascii_List)
    )
    ""
  )
)


;|
  应用更改输入框内容至Datalist
  @Param Box_Name 输入框key
  @Returns no return
|;
(defun EditBox_Change_Data(Box_Name / Now_Index Now_Column Now_Operating_Data Now_Edit Change_Symbol)
  (setq Box_Name_String (vl-string->list Box_Name)
        Now_Index (+ (- (car Box_Name_String) 65) Page_index)
  )
  (if (and (= (length Box_Name_String) 1);【判断是否在操作复选框】
           (>= (car Box_Name_String) 65)
           (<= (car Box_Name_String) 74)
      )
    (progn
      (setq Temp_Toggle_list (subst 
                               (cons 
                                 (car (nth Now_Index Temp_Toggle_list)) 
                                 (get_tile Box_Name)
                               ) 
                               (nth Now_Index Temp_Toggle_list)
                               Temp_Toggle_list
                             )
      )
    )
    (if (< Now_Index (length All_Frame_Data_List))
      (progn
        (setq Now_Column (atoi (vl-list->string (cdr Box_Name_String)))
              Now_Operating_Data (nth Now_Index All_Frame_Data_List)
        )
        (if (not (= (nth Now_Column Now_Operating_Data) (setq Now_Edit (get_tile Box_Name))))
          (progn
            (if (and (>= Now_Column 4) (<= Now_Column 9))
              (progn
                (if (vl-remove-if-not 
                      (function
                        (lambda
                          (ttl)
                          (= (cdr ttl) "1")
                        )
                      )
                      Temp_Toggle_list
                    )
                  (setq Change_Symbol 2)
                  (setq Change_Symbol 1)
                )
                (if (not (new_dialog "dlg_ChangeAllContfirm" Dlg_id)) (progn (alert "初始化DCL对话框失败") (exit)))
                (set_tile "Confirm_txt" (cond ((= Change_Symbol 1) (strcat "是否修改【全部】图框的" (car (nth (1- Now_Column) (cdr (car Frame_Unit_List)))) "？"))
                                              ((= Change_Symbol 2) (strcat "是否修改【已勾选】图框的" (car (nth (1- Now_Column) (cdr (car Frame_Unit_List)))) "？"))
                                        )
                )
                (action_tile "accept" "(done_dialog 1)")
                (action_tile "cancel" "(setq Change_Symbol 0)(done_dialog 0)")
                (start_dialog)
                (cond ((= Change_Symbol 2)
                        (setq All_Frame_Data_List (mapcar
                                                    (function
                                                      (lambda 
                                                        (Frame_Data)
                                                        (if (= (cdr (assoc (car Frame_Data) Temp_Toggle_list)) "1")
                                                          (T_subst
                                                            Now_Edit
                                                            Now_Column
                                                            Frame_Data
                                                          )
                                                          Frame_Data
                                                        )
                                                      )
                                                    )
                                                    All_Frame_Data_List
                                                  )
                        )
                      )
                      ((= Change_Symbol 1)
                        (setq All_Frame_Data_List (mapcar
                                                    (function
                                                      (lambda 
                                                        (Frame_Data)
                                                        (T_subst
                                                          Now_Edit
                                                          Now_Column
                                                          Frame_Data
                                                        )
                                                      )
                                                    )
                                                    All_Frame_Data_List
                                                  )
                        )
                      )
                      ((= Change_Symbol 0)
                        (setq All_Frame_Data_List (subst 
                                                    (T_subst
                                                      Now_Edit
                                                      Now_Column
                                                      Now_Operating_Data
                                                    )
                                                    Now_Operating_Data
                                                    All_Frame_Data_List
                                                  )
                        )
                      )
                )
              )
              (setq All_Frame_Data_List (subst 
                                          (T_subst
                                            Now_Edit
                                            Now_Column
                                            Now_Operating_Data
                                          )
                                          Now_Operating_Data
                                          All_Frame_Data_List
                                        )
              )
            )
          )
        )
      )
    )
  )
  (Set_MainDia_Data)
)


;|
  读取图面上对应图元名图框的文字内容
  @Param Frame_EntName 图框图元名
  @Param Unit_Name 文字信息名
  @Returns ?
|;
(defun Get_Frame_Unit_Txt(Frame_EntName Unit_Name / ss Plist Text_strings)
  (defun Catch_Txt()
    (setq Plist (Create_Zone_Plist Frame_EntName (cdr (assoc Unit_Name Now_Frame_Unit_Zone_list))))
    (if Plist
      (progn
        (setq ss  (ssget "CP" Plist  '((-4 . "<or")
                                      (0 . "TEXT")
                                      (0 . "MTEXT")
                                      (0 . "TCH_TEXT")
                                      (-4 . "or>"))
                  )
              Text_strings (apply 'strcat (mapcar (function (lambda (t_n) (cdr (assoc 1 (entget t_n))))) (SS_To_EntNameList ss)))
        )
      )
      (setq Text_strings "")
    )
  )
  (cond
    (
      (= Unit_Name "图号")
      (if (= Sub_Number_mode "1")
        (setq Unit_Name "图号2")
      )
      (Catch_Txt)
    )
    (
      (= Unit_Name "次图号")
      (if (= Sub_Number_mode "1")
        (Catch_Txt)
        (setq Text_strings "")
      )
    )
    (
      t
      (Catch_Txt)
    )
  )
  Text_strings
)


;|
  图名输入处理
  @Returns no return
|;
(defun Input_Process(/ String_ASCIIlist ASCII_Char Cursor End_Symbol SN_Start SN_End)
  (setq Current_SN nil)
  (if Input_String
    (progn
      (setq String_ASCIIlist (vl-string->list Input_String)
            SN_Start nil
            Cursor 1
      ) 
      (while String_ASCIIlist
        (setq ASCII_Char (car String_ASCIIlist)
              String_ASCIIlist (cdr String_ASCIIlist)
        )
        (cond (
                (and 
                  (>= ASCII_Char 48) 
                  (<= ASCII_Char 57)
                  (null SN_Start)
                )
                (setq SN_Start Cursor)
              )
              (
                (and 
                  SN_Start 
                  (or (< ASCII_Char 48) 
                      (> ASCII_Char 57)
                  )
                )
                (setq SN_End (1- Cursor)
                      String_ASCIIlist nil  
                )
              )
              (
                (and
                  SN_Start
                  (null String_ASCIIlist)
                  (>= Cursor SN_Start)
                )
                (setq SN_End Cursor
                      String_ASCIIlist nil  
                )
              )
        )
        (setq Cursor (1+ Cursor))
      )
      (setq SN_Prefix (substr Input_String 1 (if (= SN_Start 1) () (1- SN_Start)))
            Current_SN (atoi (substr Input_String SN_Start (- (1+ SN_End) SN_Start)))
            SN_Bit (strlen (substr Input_String SN_Start (- (1+ SN_End) SN_Start)))
            SN_Suffix (substr Input_String (1+ SN_End))
      )
    )
  )
)



;|
  根据图框实例以及相对坐标点列表，输出绝对坐标点列表
  @Param FrameEntname 图框的实体名
  @Param FrameZonePlist 相对区域坐标点列表
  @Returns 绝对坐标点列表
|;
(defun Create_Zone_Plist(FrameEntname FrameZonePlist / Frame_DXF Frame_Base_Point Frame_Scale Frame_Angle Abs_Zone_Plist Vector2D Abs_Vector2D)
  (if (and FrameZonePlist FrameEntname)
    (progn
      (setq Frame_DXF (entget FrameEntname)
            Frame_Base_Point (cdr (assoc 10 Frame_DXF))
            Frame_Scale (cdr (assoc 41 Frame_DXF))
            Frame_Angle (cdr (assoc 50 Frame_DXF))
      )
      (setq Abs_Zone_Plist (mapcar 
                             (function 
                               (lambda 
                                 (x) 
                                 (progn
                                   (setq Vector2D x
                                         Abs_Vector2D (Vector2D_Scale_Rotation Frame_Scale Frame_Angle Vector2D)
                                   )
                                   (list
                                    (+
                                      (car Abs_Vector2D)
                                      (car Frame_Base_Point)
                                    )
                                    (+
                                      (cadr Abs_Vector2D)
                                      (cadr Frame_Base_Point)
                                    )
                                   )
                                 )
                               )
                             )
                             FrameZonePlist
                           )
      )
      Abs_Zone_Plist
    )
    nil
  )
)


;|
  二维向量在平面内逆时针旋转
  @Param Frame_Scale 实际比例
  @Param Ro_Angle 旋转的角度（弧度制）
  @Param Vector2D 二维向量
  @Returns 经过放大旋转后的向量
|;
(defun Vector2D_Scale_Rotation(Frame_Scale Ro_Angle Vector2D /)
  (setq x (car Vector2D)
        y (cadr Vector2D)
        Frame_Angle_cos (cos Ro_Angle)
        Frame_Angle_sin (sin Ro_Angle)
        Result_Vector2D (list
                          (-
                            (* x Frame_Angle_cos Frame_Scale) 
                            (* y Frame_Angle_sin Frame_Scale)
                          )
                          (+ 
                            (* x Frame_Angle_sin Frame_Scale) 
                            (* y Frame_Angle_cos Frame_Scale)
                          )
                        )
  )
)


;|
  创建文字
  @Param Txt_Contect 文字内容
  @Param Txt_Point 文字中点
  @Param Txt_Scale 文字高度
  @Param Txt_Angle 文字旋转
  @Param TxtW 文字范围宽
  @Param TxtH 文字范围高
  @Returns ?
|;
(defun Create_Txt(Txt_Contect Txt_Point Txt_Scale Txt_Angle TxtW TxtH)    ;生成文字
  (setq W_Scale (/ Txt_Scale 350)
        Txt_length (strlen Txt_Contect)
        Single_Txt_Width (* 210 W_Scale)
  )
  (if (> (* Txt_length Single_Txt_Width) TxtW)
    (progn
      (setq MText_Width (*
                          (/ 
                            TxtW 
                            Txt_length
                            Single_Txt_Width
                          )
                          0.7
                        )
            Txt_Contect (strcat "{\\W" (rtos MText_Width 2 2) ";" Txt_Contect "}")
      )
    )
  )
  (entmake (list '(0 . "MTEXT")                                         ;图元类型
                 '(100 . "AcDbEntity")
                 '(100 . "AcDbMText")
                  (cons 10 Txt_Point)                                   ;X坐标
                 '(7 . "ICDA-STYLE1")                                   ;字体样式
                  (cons 40 Txt_Scale)                                   ;字体大小
                  (cons 41 TxtW)                                        ;段落宽
                  (cons 46 TxtH)                                        ;段落高
                 '(44 . 1.0)                                            ;行距比例
                  (cons 1 Txt_Contect)                                  ;文字内容
                 '(71 . 5)                                              ;文字对正
                  (cons 50 Txt_Angle)                                   ;文字旋转
           )
  )
)


;|
  选择集转图元名表
  @Param SS Selection_Set
  @Returns EntName_List
|;
(defun SS_To_EntNameList(SS / Ent_Name Result_List)
  (if SS
    (while (setq Ent_Name (ssname SS 0))
      (setq SS (ssdel Ent_Name SS)
            Result_List (cons Ent_Name Result_List)
      )
    )
    (setq Result_List nil)
  )
  Result_List
)


;|
  取两个点的中点
  @Param P1 ?
  @Param P2 ?
  @Returns 返回中点坐标
|;
(defun Mid_Point(P1 P2 / X Y Z)
  (if (and P1 P2)
    (progn
      (if (and 
            (= (length P1) 3)
            (= (length P2) 3)
          )
        (setq X (/ (+ (car P1) (car P2)) 2.0)
              Y (/ (+ (cadr P1) (cadr P2)) 2.0)
              Z (/ (+ (caddr P1) (caddr P2)) 2.0)
        )
        (setq X (/ (+ (car P1) (car P2)) 2.0)
              Y (/ (+ (cadr P1) (cadr P2)) 2.0)
              Z 0.0
        )
      )
      (list X Y Z)
    )
    nil
  )
) 


;|
  创建图层
  @Param name 图层名
  @Param color 颜色
|;
(defun MakeLayer(name color)
  (or (tblsearch "LAYER" name)                       ;判断是否有当前图层
    (entmake
      (list
        '(0 . "LAYER")
        '(100 . "AcDbSymbolTableRecord")
        '(100 . "AcDbLayerTableRecord")
        (cons 2 name)
        '(70 . 0)   ;可见
        '(290 . 1)  ;打印
        '(6 . "CONTINUOUS")
        (cons 62 color)
      )
    )
  )
)


;|
  输入列表转换为子列表
  @Param Start_index 开始的索引位置
  @Param Sub_Number 取出子列表数量
  @Param Process_list 要处理的列表
  @Returns 返回子列表
|;
(defun ReadList_To_Sublist(Start_index Sub_Number Process_list / Result_List)
  (setq Original_ListLength (length Process_list))
  (setq Process_list (member (setq Sub_Item (nth Start_index Process_list)) Process_list))
  (while (> (+ (length Process_list) Start_index) Original_ListLength)
    (setq Process_list (member Sub_Item (cdr Process_list)))
  )
  (setq Result_List nil)
  (while (and Process_list (> Sub_Number 0))
    (setq Result_List (cons (car Process_list) Result_List))
    (setq Process_list (cdr Process_list))
    (setq Sub_Number (1- Sub_Number))
  )
  (reverse Result_List)
)


;|
  替换表内指定位置的元素
  @Param New_item 替换的元素
  @Param Num_item 表内元素位置
  @Param Item_list 表
  @Returns 返回替换完成的表
|;
(defun T_subst(New_item Num_item Item_list / Result_List)
  (if (and Num_item Item_list (< Num_item (length Item_list)) (>= Num_item 0))
    (cond 
      ((= Num_item 0) 
        (setq Result_List (cons New_item (cdr Item_list)))
      )
      ((= Num_item (- (length Item_list) 1)) 
        (setq Result_List (reverse (cons New_item (cdr (reverse Item_list)))))
      )
      (t
        (setq Result_List (append 
                            (ReadList_To_Sublist 0 Num_item Item_list) 
                            (cons 
                              New_item 
                              (ReadList_To_Sublist (1+ Num_item) (- (length Item_list) (1+ Num_item)) Item_list)
                            )
                          )
        )
      )
    )
  )
)


;|
  用于根据提供的位数，整数转字符串，不足位补0
  @Param Integer 整数
  @Param Precision 位数
  @Returns 返回字符串
|;
(defun T_rtos(Integer Precision / Output_String)
  (setq Output_String (rtos Integer 2 0))
  (while (< (strlen Output_String) Precision)
    (setq Output_String (strcat "0" Output_String))
  )
  Output_String
)


;|
  DXF组码内获取10,11项的点坐标
  @Returns 返回三维点集，二维点自动补全Z坐标为0.0
|;
(defun Point_Get(Entname / result)
  (setq result (mapcar
                '(lambda (x) (cdr x))
                (vl-remove-if-not
                  (function
                    (lambda (x)
                      (member (car x) (list '10 '11))
                    )
                  )
                  (entget Entname)
                )
              )
  )
  (if (and (car result)
        (= (length (car result)) 2) 
      )
    (setq result (mapcar '(lambda (x) (append x '(0.0))) result))
    result
  )
  result
)


;|
  暂停等待上一个指令执行完成
  @Returns no return
|;
(defun pauseing()
  (while (= (logand (getvar 'CmdActive) 1) 1) (command pause))
)


;|
  取图元的DXF表内对应项
  @Param entname 图元名
  @Param index 项目
  @Returns 项目数据
|;
(defun dxf (entname index)
  (cdr (assoc index (entget entname)))
)


;|
  判断图框尺寸
  @Param entname 图框图元名
  @Returns 图框尺寸
|;
(defun Determine_Frame(entname / FramePlist Frame_Height Frame_Width Frame_size Temp_CheckModel_List Now_CheckModel Target_Height Frame_RefLength)
  (setq FramePlist (Get_Pointlist_Inside_Block entname)
        Frame_Width (distance (car FramePlist) (cadr FramePlist))
        Frame_Height (distance (cadr FramePlist) (caddr FramePlist))
        Frame_size nil
        Temp_CheckModel_List FrameModel_List
  )
  (while Temp_CheckModel_List
    (setq Now_CheckModel (car Temp_CheckModel_List)
          Target_Height (caddr Now_CheckModel)
          Temp_CheckModel_List (cdr Temp_CheckModel_List)
    )
    (if (null Frame_size)
      (progn
        (if
          (or (< (abs (- (rem Frame_Height Target_Height) Target_Height)) 1.0)
              (< (rem Frame_Height Target_Height) 1.0)
          )
          (progn
            (setq Frame_size (car Now_CheckModel))            
            (if (> 
                  (setq Frame_RefLength (/ 
                                          (/ Frame_Width (/ Frame_Height Target_Height)) 
                                          (cadr Now_CheckModel)
                                        )
                  )
                  1.01
                )
              (setq Frame_size (strcat Frame_size "+" (rtos (1- Frame_RefLength) 2 2)))
            )
          )
        )
      )
    )
  )
  Frame_size
)


;|
  获取块内图元外轮廓坐标
  @Param BlockInsert_Name 块插入图元名
  @Returns 坐标表
|;
(defun Get_Pointlist_Inside_Block(BlockInsert_Name / BlockInsert_list BlockDic_Name Block_SubEnt_Ename Block_SubEnt_Ename_List BlockEnt_PointCheckList BlockEnt_PointList CheckMember)
  (setq BlockInsert_list (entget BlockInsert_Name)
        BlockDic_Name (cdr (assoc 2 BlockInsert_list))
        Block_SubEnt_Ename (cdr (assoc -2 (tblsearch "block" BlockDic_Name)))
        Block_SubEnt_Ename_List nil
  )
  (while Block_SubEnt_Ename
    (setq Block_SubEnt_Ename_List (cons Block_SubEnt_Ename Block_SubEnt_Ename_List))
    (setq Block_SubEnt_Ename (entnext Block_SubEnt_Ename))
  )
  (setq Block_SubEnt_Ename_List (vl-remove-if-not
                                  (function
                                    (lambda
                                      (x)
                                      (progn
                                        (setq x_type (cdr (assoc 0 (entget x))))
                                        (or (= x_type "LINE")
                                            (= x_type "LWPOLYLINE")
                                            (= x_type "POINT")
                                        )
                                      )
                                    )
                                  )
                                  Block_SubEnt_Ename_List
                                )
  )
  (setq BlockEnt_PointCheckList
    (mapcar
      (function
        (lambda
          (x)
          (Point_Get x)
        )
      )
      Block_SubEnt_Ename_List
    )
    BlockEnt_PointList nil
  )
  (while BlockEnt_PointCheckList
    (setq CheckMember (car BlockEnt_PointCheckList)
          BlockEnt_PointCheckList (cdr BlockEnt_PointCheckList)
    )
    (while CheckMember
      (if (null (member (car CheckMember) BlockEnt_PointList))
        (setq BlockEnt_PointList (cons (car CheckMember) BlockEnt_PointList))
      )
      (setq CheckMember (cdr CheckMember))
    )
  )
  (SelectPoint_Convert BlockEnt_PointList)
)


;|
  块内图元点集转外轮廓框选点集
  @Param Plist 点表
  @Returns 外轮廓框选点表
|;
(defun SelectPoint_Convert(Plist / P0 P1 P2 P3 PR_list T_list R_list)
  (setq P0 (car 
             (vl-sort Plist
              (function
                (lambda (e1 e2) 
                  (if (= (cadr e1) (cadr e2))
                    (< (car e1) (car e2))
                    (< (cadr e1) (cadr e2))
                  )
                )
              )
            )
           )
        PR_list (vl-sort Plist 
                  (function
                    (lambda (e1 e2) 
                      (if (= (angle P0 e1) (angle P0 e2))
                        (< (distance P0 e1) (distance P0 e2))
                        (< (angle P0 e1) (angle P0 e2))
                      )
                    )
                  )
                )
        T_list PR_list
        R_list (list (cadr T_list) (car T_list))
  )
  (while (cddr T_list)
    (setq P3 (caddr T_list))
    (if (null (member P3 R_list))
      (setq R_list (cons P3 R_list))
    )
    (setq R_list (PointList_Check_Recursion R_list)
          T_list (cdr T_list)
    )
  )
  (reverse R_list)
)


;|
  判断是否形成凸包的递归函数
  @Param C_list 输入点集
  @Returns 返回点集
|;
(defun PointList_Check_Recursion(C_list)
  (if (null (Check_Vector (reverse C_list)))
    (progn
      (setq C_list (vl-remove (cadr C_list) C_list))
      (PointList_Check_Recursion C_list)
    )
    C_list
  )
)


;|
  检查点集形成的多边形是否为凸包，输入点集按极坐标排序
  @Param R_list 点集
  @Returns 返回 T 或nil
|;
(defun Check_Vector(R_list / check_symbol P1 P2 P3)
  (setq check_symbol T)
  (while (and (cddr R_list) check_symbol)
    (setq P1 (car R_list)
          P2 (cadr R_list)
          P3 (caddr R_list)
          R_list (cdr R_list)
    )
    (if (not (Cross_Product P1 P2 P3))
      (setq check_symbol nil)
    )
  )
  check_symbol
)


;|
  输入三个点坐标，返回向量V21,V32叉乘是否大于0结果，用于判断两向量方向
  @Param P1 点1
  @Param P2 点2
  @Param P3 点3
  @Returns 返回 T 或nil
|;
(defun Cross_Product(P1 P2 P3 / V1 V2)
  (setq V1 (mapcar '- P2 P1)
        V2 (mapcar '- P3 P2)
  )
  (>
    (* (car V1) (cadr V2))
    (* (cadr V1) (car V2))
  )
)


;|
  3D点坐标偏移
  @Param 3Dpoint 原3D点坐标点列表
  @Param Offset_x X坐标偏移量
  @Param Offset_y y坐标偏移量
  @Param Offset_z z坐标偏移量
  @Returns 偏移后的3D点坐标点列表
|;
(defun Point_Offset(3Dpoint Offset_x Offset_y Offset_z)
  (setq X (car 3Dpoint)
        Y (cadr 3Dpoint)
        Z (caddr 3Dpoint)
  )
  (list 
    (+ X Offset_x)
    (+ Y Offset_y)
    (+ Z Offset_z)
  )
)



;|
  创建文字（宋体）
  @Param Txt_Contect ?
  @Param Txt_Point ?
  @Returns ?
|;
(defun Create_Txt2(Txt_Contect Txt_Point Txt_Scale Txt_Angle TxtW TxtH / ename elist Single_Txt_Width Txt_length MText_Width Txtbox_size Txtbox_H Txtbox_L ratio)    ;生成文字
  ;; 输入参数验证
  (if (or (null Txt_Contect) (= Txt_Contect ""))
    (setq Txt_Contect " ")
  )
  (if (null Txt_Point)
    (setq Txt_Point '(0 0 0))
  )
  (if (or (null Txt_Scale) (<= Txt_Scale 0))
    (setq Txt_Scale 1.0)
  )
  (if (or (null TxtW) (<= TxtW 0))
    (setq TxtW 100.0)
  )
  (if (or (null TxtH) (<= TxtH 0))
    (setq TxtH 100.0)
  )
  
  ;; 创建MTEXT实体
  (setq ename (entmake (list '(0 . "MTEXT")                                         ;图元类型
                               '(100 . "AcDbEntity")
                               '(100 . "AcDbMText")
                                (cons 10 Txt_Point)                                   ;X坐标
                                (if (tblsearch "style" "宋体")                         ;字体样式
                                  '(7 . "宋体")
                                  '(7 . "standard")
                                )                                        
                                (cons 40 Txt_Scale)                                   ;字体大小
                                (cons 41 TxtW)                                        ;段落宽
                                (cons 46 TxtH)                                        ;段落高
                               '(44 . 1.0)                                            ;行距比例
                                (cons 1 Txt_Contect)                                  ;文字内容
                               '(71 . 5)                                              ;文字对正
                                (cons 50 Txt_Angle)                                   ;文字旋转
                         )
                   )
  )
  
  ;; 验证实体创建成功
  (if ename
    (progn
      (setq elist (entget ename))
      
      ;; 安全地获取文字边界框 - 使用完整的实体列表
      (setq Txtbox_size (textbox elist))
      
      (if (and Txtbox_size 
               (listp Txtbox_size) 
               (= (length Txtbox_size) 2)
               (listp (car Txtbox_size))
               (listp (cadr Txtbox_size)))
        (progn
          (setq Txtbox_H (abs (- (cadr (cadr Txtbox_size)) (cadr (car Txtbox_size))))
                Txtbox_L (abs (- (car (cadr Txtbox_size)) (car (car Txtbox_size))))
          )
          
          ;; 安全计算比例 - 防止除零错误
          (if (and (> Txtbox_H 0) (> Txt_Scale 0) (> TxtW 0))
            (progn
              (setq ratio (/ (/ Txtbox_L (/ Txtbox_H Txt_Scale)) TxtW))
              
              ;; 如果文字太宽，调整宽度比例
              (if (and (> ratio 0.9) (< ratio 10.0))  ;; 限制比例范围防止异常
                (progn 
                  (setq MText_Width (* (/ 1.0 ratio) 0.7 0.95))
                  
                  ;; 删除原实体并重新创建
                  (entdel ename)
                  (setq Txt_Contect (strcat "{\\W" (rtos MText_Width 2 2) ";" Txt_Contect "}"))
                  (entmake (list '(0 . "MTEXT")                                         ;图元类型
                                     '(100 . "AcDbEntity")
                                     '(100 . "AcDbMText")
                                      (cons 10 Txt_Point)                                   ;X坐标
                                      (if (tblsearch "style" "宋体")                         ;字体样式
                                        '(7 . "宋体")
                                        '(7 . "standard")
                                      )                                        
                                      (cons 40 Txt_Scale)                                   ;字体大小
                                      (cons 41 TxtW)                                        ;段落宽
                                      (cons 46 TxtH)                                        ;段落高
                                     '(44 . 1.0)                                            ;行距比例
                                      (cons 1 Txt_Contect)                                  ;文字内容
                                     '(71 . 5)                                              ;文字对正
                                      (cons 50 Txt_Angle)                                   ;文字旋转
                               )
                         )
                )
              )
            )
          )
        )
      )
    )
  )
  ename  ;; 返回创建的实体名
)