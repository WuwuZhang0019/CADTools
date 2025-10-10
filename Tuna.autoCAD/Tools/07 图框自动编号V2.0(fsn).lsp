;(alert "命令：FSN")
(setq Point_List (List '("SN" 61.0 154.0 22.0 8.0) '("Name" 50.0 125.35 80.0 16.7))
      FrameModel_List (List '("A0" 1189.0 841.0)
                            '("A0+1-4" 1486.0 841.0)
                            '("A0+1-2" 1783.0 841.0)
                            '("A1" 841.0 594.0)
                            '("A1+1-4" 1051.0 594.0)
                            '("A1+1-2" 1261.0 594.0)
                            '("A2" 594.0 420.0)
                            '("A2+1-4" 742.0 420.0)
                            '("A2+1-2" 891.0 420.0)
                            '("A3" 420.0 297.0)
                            '("A3_BG" 420.0 297.0)
                      )
      Acad_ver (atof (substr (getvar "acadver") 1 4))
      OldVer_Enabled (< Acad_ver 24.0)
)
(defun c:fsn()
  (setq Stage 1)
  (while Stage
    (cond ((= Stage 1) (princ "\nConfirm_Stage") (Confirm_Stage))
          ((= Stage 2) (princ "\nDraw_Stage") (Draw_Stage))
          ((= Stage 3) (princ "\nPick_Stage") (Pick_Stage))
          ((= Stage 4) (princ "\nSelectFrame_Stage") (SelectFrame_Stage))
          ((= Stage 5) (princ "\nInput_Stage") (Input_Stage))
          ((= Stage 6) (princ "\nOutput_Stage") (Output_Stage))
          ((= Stage 0) (princ "\nExit") (exit))
    )
  )
)

(defun Confirm_Stage()
  (setq Pick_mode nil
        confirm_string (getstring "是否识别已有多段线?<Y>")
  )
  (while (null Pick_mode)
    (cond ((OR (= confirm_string "") (= confirm_string "Y") (= confirm_string "y")) (setq Pick_mode 1))
          ((OR (= confirm_string "N") (= confirm_string "n")) (setq Pick_mode 0))
          ((null (OR (= confirm_string "Y") (= confirm_string "y") (= confirm_string "N") (= confirm_string "n"))) (setq confirm_string (getstring "请输入Y或者N:<Y>")))
    )
  )
  (if (= Pick_mode 0)
    (setq Stage 2)
    (setq Stage 3)
  )
)

(defun Draw_Stage(/ P_Now P_Previous)
  (setq P_list nil
        P_Previous nil
  )
  (while (setq P_Now (getpoint))
    (setq P_list (cons P_Now P_list))
    (if P_Previous
      (command "line" P_Previous P_Now "")
    )
    (setq P_Previous P_Now)
  )
  (setq Stage 4
        P_list (reverse P_list)
  )
)

(defun Pick_Stage( / symbol i)
  (setq symbol nil)
  (while (null symbol)
    (setq Pick_result (car (entsel)))
    (if (= (cdr (assoc 0 (entget Pick_result))) "LWPOLYLINE")
      (setq symbol T)
      (alert "请选择一条多段线！")
    )
  )
  (setq PL_list (entget Pick_result)
        PLPt_list (member (assoc 10 PL_list) PL_list)
        i (1- (length PLPt_list))
        P_list nil
  )
  (while (> i 0)
    (if (= (rem i 5) 0)
      (setq P_list (cons (cdr (car PLPt_list)) P_list))
    )
    (setq i (1- i)
          PLPt_list (cdr PLPt_list)
    )
  )
  (setq Stage 4 
        P_list (reverse P_list)
  )
)

(defun SelectFrame_Stage( / loop EntName)
  (setq Frame_Set (ssget "F" P_list '((-4 . "<and")
                                      (0 . "insert")
                                      (8 . "图框")
                                      (-4 . "and>")
                                      )
                  )
        loop (1- (sslength Frame_set))
        Frame_namelist nil 
  )
  (while (>= loop 0)
    (setq EntName (ssname Frame_set loop)
          loop (1- loop)
    )
    (if (wcmatch (cdr (assoc 2 (entget EntName))) "ICDA_2019_7_A*")
      (setq Frame_namelist (cons EntName Frame_namelist))
    )
  )
  (if (null Frame_namelist) 
    (progn (alert "未检测到图框") (setq Stage 0))
  )
  (setq Stage 5)
  Frame_namelist
)

(defun Input_Stage(/ ASCII_String loop End_Symbol)
  (setq Input_String (getstring T "输入开始的编号")
        String_ASCIIlist (vl-string->list Input_String)
        SN_Start nil
        CN_Number 0.0
        loop 1
  )
  (while String_ASCIIlist
    (setq ASCII_String (car String_ASCIIlist)
          String_ASCIIlist (cdr String_ASCIIlist)
    )
    (cond (
            (and 
              (>= ASCII_String 48) 
              (<= ASCII_String 57)
              (null SN_Start)
            )
            (setq SN_Start loop)
          )
          (
            (and 
              SN_Start 
              (or (< ASCII_String 48) 
                  (> ASCII_String 57)
              )
            )
            (setq SN_End (1- loop)
                  String_ASCIIlist nil  
            )
          )
          (
            (and
              SN_Start
              (null String_ASCIIlist)
              (>= loop SN_Start)
            )
            (setq SN_End loop
                  String_ASCIIlist nil  
            )
          )
    )
    (setq loop (1+ loop))
  )
  (setq SN_Prefix (substr Input_String 1 (if (= SN_Start 1) () (1- SN_Start)))
        Current_SN (atoi (substr Input_String SN_Start (- (1+ SN_End) SN_Start)))
        SN_Suffix (substr Input_String (1+ SN_End))
        Stage 6
  )
)

(defun Output_Stage( / loop)
  (setq loop 0 
        Current_layer (getvar "clayer")
  )
  (setvar "clayer" "lz_属性字")
  (while (< loop (length Frame_namelist))
    (setq Frame_Name (nth loop Frame_namelist)
          Frame_list (entget Frame_Name)
          Frame_Model (Determine_Frame)
          Frame_Scale (cdr (assoc 41 Frame_list))
          Frame_Angle (cdr (assoc 50 Frame_list))
          Frame_Point (cdr (assoc 10 Frame_list))
          Base_Point (list 
                       (+ (car Frame_Point) (* (cos Frame_Angle) (cadr (assoc Frame_Model FrameModel_List)) Frame_Scale))
                       (+ (cadr Frame_Point) (* (sin Frame_Angle) (cadr (assoc Frame_Model FrameModel_List)) Frame_Scale))
                       0.0
                     )
          SN_Textpoint (list
                          (- 
                            (car Base_Point) 
                            (+
                              (* 
                                (cos Frame_Angle) 
                                (cadr (assoc "SN" Point_List))
                                Frame_Scale
                              )
                              (* 
                                (sin Frame_Angle) 
                                (caddr (assoc "SN" Point_List))
                                Frame_Scale
                              )
                            )
                          )
                          (+ 
                            (cadr Base_Point) 
                            (-
                              (* 
                                (cos Frame_Angle) 
                                (caddr (assoc "SN" Point_List))
                                Frame_Scale
                              )
                              (* 
                                (sin Frame_Angle) 
                                (cadr (assoc "SN" Point_List))
                                Frame_Scale
                              )
                            )
                          )
                          0.0
                       )
          SN_R (/
                  (expt
                    (+
                      (expt 
                        (nth 3 (assoc "SN" Point_List)) 
                        2
                      )
                      (expt 
                        (nth 4 (assoc "SN" Point_List)) 
                        2
                      )
                    )
                    0.5
                  )
                  2
                )
          SN_A_Angle (angle '(0.0 0.0) (cdddr (assoc "SN" Point_List)))
          SN_B_Angle (- pi SN_A_Angle)
          SN_C_Angle (+ pi SN_A_Angle)
          SN_D_Angle (- (* pi 2) SN_A_Angle)
          SN_A_point (PointAngle_Convert SN_A_Angle)
          SN_B_point (PointAngle_Convert SN_B_Angle)
          SN_C_point (PointAngle_Convert SN_C_Angle)
          SN_D_point (PointAngle_Convert SN_D_Angle)
          Output_String (strcat SN_Prefix (if (< Current_SN 10) "0" "") (rtos Current_SN 2 0) SN_Suffix)
          loop (1+ loop)
          Current_SN (1+ Current_SN)
    )
    (if (ssget "WP" (list SN_A_point SN_B_point SN_C_point SN_D_point)  '((-4 . "<or")
                                                                        (0 . "TEXT")
                                                                        (0 . "MTEXT")
                                                                        (-4 . "or>"))
        )
      (command "._erase" "P" "")
    )
    (Create_Txt Output_String SN_Textpoint)
  )
  (setvar "clayer" Current_layer)
  (exit)
)

(defun Determine_Frame()
  (setq Namestring_Trim1 (substr (cdr (assoc 2 Frame_list)) 13))
  (cond ((wcmatch Namestring_Trim1 "A?v*") (setq Namestring_Trim2 (substr Namestring_Trim1 1 2)))
        ((wcmatch Namestring_Trim1 "A?+1-?v*") (setq Namestring_Trim2 (substr Namestring_Trim1 1 6)))
        ((wcmatch Namestring_Trim1 "A3_BG*") (setq Namestring_Trim2 "A3_BG"))
        (T (alert "识别异常"))
  )
  Namestring_Trim2
)

(defun Create_Txt(TXT CP)                         ;生成文字
    (entmake (list '(0 . "text")                  ;图元类型
                   '(7 . "ICDA-STYLE1")           ;字体样式
                    (cons 10 CP)                  ;X坐标
                    (cons 11 CP)                  ;Y坐标
                    (cons 40 (* 3.5 Frame_Scale)) ;字体大小
                   '(41 . 0.7)                    ;字宽
                    ;(cons 62 COLOR)               字体颜色
                    (cons 1 TXT)                  ;文字内容
                   '(72 . 1)                      ;文字水平对正
                   '(73 . 2)                      ;文字垂直对正
                    (cons 50 Frame_Angle)         ;文字旋转
             )
    )
)

(defun PointAngle_Convert(Angle1)
  (list
    (+
      (car SN_Textpoint)
      (*
        SN_R
        (cos (+ Angle1 Frame_Angle))
        Frame_Scale
      )
    )
    (+
      (cadr SN_Textpoint)
      (*
        SN_R
        (sin (+ Angle1 Frame_Angle))
        Frame_Scale
      )
    )
    0.0
  )
)
(c:fsn)
(prin1)