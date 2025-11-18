(setq Stage 1)
(vl-load-com)
(setq Block_Layer_list '("FAS_消防设备_E" "LITE_照明设备_E")
      Line_Layer_list '("FAS_报警布线_E" "FAS_联动+DC24V线_E" "FAS_联动控制布线_E" "LITE_应急照明布线_E")
      Block_Layer_Temp_list Block_Layer_list
      Line_Layer_Temp_list Line_Layer_list
      BlockIdentify_Rules (append  
                            (list 
                              '(-4 . "<and")
                                '(0 . "INSERT")
                                '(-4 . "<or")
                            )
                            (mapcar
                              (function
                                (lambda
                                        (x)
                                  (cons 8 x)
                                )
                              )
                              Block_Layer_list
                            )
                            (list
                                '(-4 . "or>")
                              '(-4 . "and>")
                            )
                          )
      LineIdentify_Rules  (append
                            (list 
                              '(-4 . "<and")
                                '(-4 . "<or")
                                  '(0 . "LWPOLYLINE")
                                  '(0 . "LINE")
                                '(-4 . "or>")
                                '(-4 . "<or")
                            )
                            (mapcar
                              (function
                                (lambda
                                        (x)
                                  (cons 8 x)
                                )
                              )
                              Line_Layer_list
                            )
                            (list
                                '(-4 . "or>")
                              '(-4 . "and>")
                            )
                          )
      Identify_Rules  (append 
                        '((-4 . "<or"))
                        BlockIdentify_Rules
                        LineIdentify_Rules
                        '((-4 . "or>"))
                      )
      BlockIdentified_InfoList nil
      BreakLine_Tolerance 3000
      Line_Tolerance 5
      Block_Tolerance 36
      LineAngle_Tolerance 0.035  ;弧度制，角度换算为该值除以π乘以180
)

;|
  主函数
  @Returns No Return
|;
(defun c:FASG()
  (setq Model_Scale (getvar "hpscale"))
;  (if (and Stage 
;           (> Stage 1)
;      )
;    (progn
;      (alert "检测到上次未完成生成系统图，是否继续？")
;      (if ()
;        (setq Stage 1)
;      )
;    )
;  )
  (if (= Stage 0)
    (setq Stage 1)
  )
  (while (null (= Stage 0))
    (cond ((= Stage 1) (Pick_Stage))
          ((= Stage 2) (Draw_Stage))
    )
  )
  (setvar "osmode" 16319)
  (setq CircuitSS (EntNameList_To_SS Circuit_Ent_Namelist))
  (sssetfirst nil CircuitSS)
  ;; 执行自定义命令XFTJ
  (if CircuitSS
    (progn
      (princ "\n正在执行XFTJ命令...")
      (command "XFTJ" CircuitSS)  ; 调用XFTJ命令并传递选择集
    )
    (princ "\n未找到有效的选择集，跳过XFTJ命令")
  )
  (princ "\nDone")
  (princ)
)

;|
  拾取实体阶段
  @Returns No Return
|;
(defun Pick_Stage()
  (princ "\n进入Stage1")
  (setq Start_Ent_Name (car (entsel "\n选择一条回路出线或者设备"))
        Process_Number 0
  )
  (while (or (null Start_Ent_Name)
             (not 
               (and
                (vl-position (cdr (assoc 0 (entget Start_Ent_Name))) '("LWPOLYLINE" "LINE" "INSERT"))
                (vl-position (cdr (assoc 8 (entget Start_Ent_Name))) (append Block_Layer_list Line_Layer_list))
              )
             )
         )
    (setq Start_Ent_Name (car (entsel "\n选择无效，请重新选择")))
  )
  (setq Circuit_Ent_Namelist nil
        WaitForCheck_EntName_List (list Start_Ent_Name)
        OSmode_Value (getvar "osmode")
        time1 (getvar "millisecs")
  )
  (setvar "osmode" 0)
  (setvar "selectionoffscreen" 2)
  (FAS_Circuit_Check)
  (setvar "osmode" OSmode_Value)
  (setvar "selectionoffscreen" 1)
  (setq Stage 0)
  (princ (strcat "\n已识别" (rtos (length Circuit_Ent_Namelist) 2 0) "个实体"))
  (princ (strcat "\n用时" (rtos (- (getvar "millisecs") time1) 2 0) "毫秒"))
  (princ)
)

;|
  回路设备检测，以开始实体为起点，返回回路中的设备与导线实体名列表
  @Returns No return
|;
(defun FAS_Circuit_Check()
  (while (setq CheckEntName (car WaitForCheck_EntName_List))
    (if (null (vl-position CheckEntName Circuit_Ent_Namelist))
      (setq WaitForCheck_EntName_List (vl-remove 
                                        CheckEntName 
                                        (Append_ListX 
                                          (Element_Circuit_Check)
                                          (cdr WaitForCheck_EntName_List) 
                                        )
                                      )
            Circuit_Ent_Namelist (cons CheckEntName Circuit_Ent_Namelist)
      )
      (setq WaitForCheck_EntName_List (cdr WaitForCheck_EntName_List))
    )
  )
)


;|
  检查元素类型，确定进入子函数类型，返回连接的实体名列表
  @Param Ent_Name Entity_Name
  @Returns 实体名列表
|;
(defun Element_Circuit_Check()
  (setq CheckEntList (entget CheckEntName)
        CheckEntType (cdr (assoc 0 CheckEntList))
        CheckEntLayer (cdr (assoc 8 CheckEntList))
        CheckLine_PList (Point_Get CheckEntName)
  )
  (cond ((or (= CheckEntType "LWPOLYLINE") (= CheckEntType "LINE"))
          (Line_LinkEnt_Select)  
        )
        ( (= CheckEntType "INSERT") 
          (Block_Circuit_Check)
        )
  )
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
  按输入阈值以点表的首尾两点为框选中心选择实体，返回实体名列表
  @Param P_list 点表
  @Returns 实体名列表
|;
(defun Line_LinkEnt_Select()
  (setq Point_A (car CheckLine_PList)
        Point_Pre_A (cadr CheckLine_PList)
        Point_B (last CheckLine_PList)
        Point_Pre_B (cadr (reverse CheckLine_PList))
  )
  (if (and 
        Point_A 
        Point_B 
        Point_Pre_A 
        Point_Pre_B
      )
    (Append_ListX (Line_LinkCheck Point_A Point_Pre_A) (Line_LinkCheck Point_B Point_Pre_B))
    nil
  )
)

(defun Line_LinkCheck(Inputpoint1 Inputpoint2 / PX PY P1 P2 PE Angle_PTP Result)
  ;正常情况
  (setq PX (car Inputpoint1)
        PY (cadr Inputpoint1)
        Angle_PTP (rem (angle Inputpoint2 Inputpoint1) (* 2.0 pi))
        Angle_Temp (rem (angle Inputpoint2 Inputpoint1) pi)
        P1 (list (+ PX Line_Tolerance) (+ PY Line_Tolerance) 0.0)
        P2 (list (- PX Line_Tolerance) (- PY Line_Tolerance) 0.0)
  )
  (setq Result  (LineSelect_EntCheck
                  (SS_To_EntNameList 
                    (if (setq EntSS (ssget "C" P1 P2 Identify_Rules))
                      (setq EntSS (ssdel CheckEntName EntSS))
                      nil
                    )
                  )
                )
  )
  ;断线情况
  (if (null Result)
    (progn
      (setq PE (list
                  (+ PX (* BreakLine_Tolerance (cos Angle_PTP)))
                  (+ PY (* BreakLine_Tolerance (sin Angle_PTP)))
                  0.0
                )
      )
      (setq Result  (LineSelect_EntCheck 
                       (SS_To_EntNameList 
                          (ssget "F" (list Inputpoint1 PE) LineIdentify_Rules)
                       )
                    )
      )   
    )
  )
  Result
)

;|
  输入实体名表，筛选合适的导线或图块实体
  @Param Input_List 输入的实体名表
  @Returns 返回实体名表
|;
(defun LineSelect_EntCheck(Input_List)
  (vl-remove-if-not
    (function
      (lambda (x / elist_x plist_x)
        (setq elist_x (entget x)
              plist_x (Point_Get x)
        )
        (or
          ;线情况
          (and 
              (= (cdr (assoc 0 elist_x)) CheckEntType)
              (= (cdr (assoc 8 elist_x)) CheckEntLayer) ;同图层
              (or
                  (< (distance (car plist_x) (car CheckLine_PList)) Line_Tolerance) ;首首检测
                  (< (distance (last plist_x) (car CheckLine_PList)) Line_Tolerance) ;尾首检测
                  (< (distance (last plist_x) (last CheckLine_PList)) Line_Tolerance) ;尾尾检测
                  (< (distance (car plist_x) (last CheckLine_PList)) Line_Tolerance) ;首尾检测
                  (< (abs (- 
                            (rem (angle (car plist_x) (cadr plist_x)) pi) 
                            Angle_Temp
                          )
                     )
                     LineAngle_Tolerance
                  )
                  (< (abs (- 
                            (rem (angle (last plist_x) (cadr (reverse plist_x))) pi) 
                            Angle_Temp
                          )
                     )
                     LineAngle_Tolerance
                  )
              )
          )
          ;块情况
          (and
            (= (cdr (assoc 0 (setq elist_x (entget x)))) "INSERT")
            (= (cdr (assoc 8 elist_x)) "FAS_消防设备_E")
          )
        )
      )
    )
    Input_List
  )
)


;|
  图块回路检查，返回连接的导线与图块实体名列表
  @Param Ent_List Entity_List
  @Returns 实体名列表
|;
(defun Block_Circuit_Check()
  (setq BlockName_NIC (cdr (assoc 2 CheckEntList))
        Insert_X_Scale (cdr (assoc 41 CheckEntList))
        Insert_Y_Scale (cdr (assoc 42 CheckEntList))
        Insert_Rotation (cdr (assoc 50 CheckEntList))
        Insert_BasePoint (cdr (assoc 10 CheckEntList))
  )
  (SS_To_EntNameList  (ssget 
                        "CP" 
                        (Pointlist_With_Tolerance 
                          (mapcar
                            (function
                              (lambda
                                (x / R Ro)
                                (setq R (sqrt 
                                          (+ 
                                            (expt (* Insert_X_Scale (car x)) 2) 
                                            (expt (* Insert_Y_Scale (cadr x)) 2)
                                          )
                                        )
                                      Ro (angle '(0.0 0.0 0.0) x)
                                )
                                (list (+ 
                                        (car Insert_BasePoint)
                                        (* R (cos (+ Ro Insert_Rotation)))
                                      )
                                      (+ 
                                        (cadr Insert_BasePoint)
                                        (* R (sin (+ Ro Insert_Rotation)))
                                      )
                                      0.0
                                )
                              )
                            )
                            (if (null (member BlockName_NIC BlockIdentified_InfoList))
                              (progn 
                                (setq BlockPlist_NIC (Get_Pointlist_Inside_Block CheckEntName))
                                (PutBlockInfo_to_List BlockName_NIC BlockPlist_NIC)
                                BlockPlist_NIC
                              )
                              (cdr (assoc BlockName_NIC BlockIdentified_InfoList))
                            )
                          )
                        )    
                        Identify_Rules
                      )
  )
)


;|
  将输入的块名与块轮廓点集保存至表内
  @Param BlockName 块的字典图元名
  @Param P_list 经过处理后的块轮廓点集
  @Returns None
|;
(defun PutBlockInfo_to_List(BlockName P_list)
  (if (null (assoc BlockName BlockIdentified_InfoList))
    (setq BlockIdentified_InfoList (cons (append (list BlockName) P_list) BlockIdentified_InfoList))
    (setq BlockIdentified_InfoList (subst (append (list BlockName) P_list) (assoc BlockName BlockIdentified_InfoList) BlockIdentified_InfoList)
    )
  )
)

;|
  获取块内图元外轮廓坐标
  @Param BlockInsert_Name 块插入图元名
  @Returns 坐标表
|;
(defun Get_Pointlist_Inside_Block(BlockInsert_Name)
  (setq BlockInsert_list (entget BlockInsert_Name)
        BlockDic_Name (cdr (assoc 2 BlockInsert_list))
        BlockEnt_name (cdr (assoc -2 (tblsearch "block" BlockDic_Name)))
        BlockEnt_NameList nil
  )
  (while BlockEnt_name
    (setq BlockEnt_NameList (cons BlockEnt_name BlockEnt_NameList)
          BlockEnt_name (entnext BlockEnt_name)
    )
  )
  (setq BlockEnt_PointCheckList
    (mapcar
      (function
        (lambda
          (x)
          (if (or (= (cdr (assoc 0 (entget x))) "LINE")
                  (= (cdr (assoc 0 (entget x))) "LWPOLYLINE")
                  (= (cdr (assoc 0 (entget x))) "POINT")
              )
            (Point_Get x)
          )
        )
      )
      BlockEnt_NameList
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
  块内图元点集转框选点集
  @Param P_list 点表
  @Returns 外轮廓框选点表
|;
(defun SelectPoint_Convert(P_list / P0 P1 P2 P3 PR_list T_list R_list)
  (setq P0 (car 
             (vl-sort P_list
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
        PR_list (vl-sort P_list 
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
  按给定阈值扩大多边形选择边界
  @Param P_list 输入多边形点集
  @Returns 返回扩大后点集
|;
(defun Pointlist_With_Tolerance(P_list / PA PB PC V1 V2 V3 D1 D2 D3 PX RP_list)
  (setq P_list (append (list (last P_list)) P_list (list (car P_list)))
        RP_list nil
  )
  (while (caddr P_list)
    (setq PA (car P_list)
          PB (cadr P_list)
          PC (caddr P_list)
          D1 (distance PA PB)
          D2 (distance PB PC)
          V1 (mapcar '(lambda (A B) (/ (- B A) D1)) PA PB)
          V2 (mapcar '(lambda (A B) (/ (- B A) D2)) PC PB)
          V3 (mapcar '+ V1 V2)
          D3 (sqrt (vl-catch-all-apply '+ (mapcar '(lambda (x) (expt x 2)) V3)))
          V3 (mapcar '(lambda (x) (/ x D3)) V3)
          PX (mapcar '+ (mapcar '(lambda (x) (* x Block_Tolerance)) V3) PB)
          RP_list (cons PX RP_list)
    )
    (setq P_list (cdr P_list))
  )
  RP_list
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
  图元名表转选择集
  @Param Input_List EntName_List
  @Returns Selection_Set
|;
(defun EntNameList_To_SS(Input_List / Result_SS Ent_Name)
  (setq Result_SS (ssadd))
  (while (setq Ent_Name (car Input_List))
    (setq Input_List (cdr Input_List)
          Result_SS (ssadd Ent_Name Result_SS)
    )
  )
  Result_SS
)

;|
  合并两个表，并去除重复元素
  @Param Input_List1 表1
  @Param Input_List2 表2
  @Returns 表
|;
(defun Append_ListX(Input_List1 Input_List2 / Result_List1 Result_List2)
  (if (setq Result_List1 (append Input_List1 Input_List2))
    (progn
      (while (setq Result_List2 (cons (car Result_List1) Result_List2)
                   Result_List1 (vl-remove (car Result_List1) (cdr Result_List1))
            )
      )
      (reverse Result_List2)
    )
    nil
  )
)