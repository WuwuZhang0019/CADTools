; 底图处理函数 - 用于CAD中对图层进行灰化、冻结和打印状态处理
  ; 加载COM接口
  (vl-load-com)
  
  ; 定义灰化处理的列表（后缀名 长度）
  (setq gray-suffix-list
    '(("JSK" 3)
      ("货车" 4) ("家具" 4) ("坑位" 4) ("空调" 4) ("屏幕" 4) 
      ("填充" 4) ("银幕" 4) ("座椅" 4) ("COLU" 4) ("砼墙" 4) 
      ("洁具" 4) ("器材" 4) ("厨卫" 4) ("窗帘" 4) ("活动" 4) 
      ("疏散" 4) ("Cols" 4) ("Patt" 4) ("JSK2" 4) ("地沟" 4) 
      ("线脚" 4)
      ("HATCH" 5) ("SCEEN" 5) ("STAIR" 5) ("LVTRY" 5)
      ("COLUMN" 6) ("CHEWEI" 6) ("21-CAR" 6) ("21洁具" 6) 
      ("P-FURN" 6) ("微型车" 6) ("排污管" 6) ("构造柱" 6) 
      ("面积线" 6) ("P-PFIX" 6) ("装饰面" 6) ("EL-DIM" 6)
      ("00-洁具" 7) ("LATRINE" 7) ("P_HATCH" 7) ("FF-FURN" 7) 
      ("02平-地" 7) ("02平-顶" 7) ("EL-NORM" 7) ("1_填充_S" 7)
      ("Y-运动场" 7) ("地面标志" 7) ("防火卷帘" 7) ("疏散指示" 7)
      ("屏幕座位" 7) ("P-完成面" 7) ("洞口实线" 7) ("洞口虚线" 7)
      ("FF-FURNA" 7) ("IDS-FIXT" 7) ("D-detail" 7)
      ("0$0当前层" 9) ("colu_填充" 9) ("F防火卷帘" 9) ("F-家具-E3" 9)
      ("Plan-洁具" 9) ("名称-JSK2" 9) ("PUB_HATCH" 9) ("PROJ-LINE" 9)
      ("-战时拆除" 9)
      ("Audi seats" 10) ("AUDI_SEATS" 10) ("COLU_HATCH" 10) ("D-电梯编号" 10)
      ("疏散梯类型" 10) ("自动扶梯-2" 10) ("P-活动家具" 10) ("P-平面窗帘" 10)
      ("P-平面洁具" 10) ("W-区域文字" 10) ("Plan-new门" 10) ("顶面造型线" 10)
      ("A-车位线-电" 11) ("COLU_柱墙_A" 11) ("MTRL_铝板_A" 11) ("MTRL_石材_A" 11)
      ("P5-活动家具" 11) ("PUB_HATCH_A" 11) ("SYMB_排水_A" 11) ("WS_厨房设备" 11)
      ("装饰-完成面" 11) ("I-ELEV-OTL2" 11) ("I-ELEV-MBND" 11)
      ("1_平面洞口_S" 12) ("EQU_空调机_A" 12) ("P-平面楼梯线" 12)
      ("固定(不到顶)" 12) ("太阳能集热板" 12)
      ("0$KTs系统设备" 13) ("A-通用-投影线" 13) ("BEAM_梁实线_S" 13)
      ("BEAM_梁虚线_S" 13) ("BRIK_构造柱_S" 13) ("COLU_柱填充_A" 13)
      ("COMP_建筑沟_A" 13) ("COMP_结构沟_A" 13) ("LINE_投影线_A" 13)
      ("HS-A-防火卷帘" 13) ("HS-A-填充图案" 13) ("Plan-完成面墙" 13)
      ("Plan-固定道具" 13) ("LINE_中粗线_A" 13)
      ("J-平面固定家具" 14) ("J-平面活动家具" 14) ("STAIR_楼电梯_A" 14)
      ("EQU_厨卫设备_A" 14) ("EQU_固定家具_A" 14) ("EQU_活动家具_A" 14)
      ("P-平面活动家具" 14) ("暖通井文件TEXT" 14)
      ("A-通用-图案填充" 15) ("HOLE_平面洞口_A" 15) ("Plan-toilet洁具" 15)
      ("S_STAIR_楼电梯_" 15) ("TRI-B2$0$A-DRAN" 15) ("WALL_柱墙填充_S" 15)
      ("DS-HIGH CABINET" 15)
      ("HATCH_通用填充_A" 16)
      ("F-FLR3 (PLATFORM)" 17) ("HATCH_立面填充1_A" 17) ("HATCH_立面填充2_A" 17)
      ("COLU_上层柱轮廓_S" 17) ("COLU_下层柱轮廓_S" 17) ("ICDA方案_活动家具" 17)
      ("P9-平面家具灰度层" 17) ("WALL_上层墙轮廓_S" 17) ("WALL_下层墙轮廓_S" 17)
      ("辅助-安全出口指示" 17)
      ("P-固定家具（悬空）" 18)
      ("HS-A-停车位（标准）" 19)
      ("FF--FURN_SF(固定家俱)" 21) ("WALL_地下室外墙填充_S" 21)
      ("FF--FIXT（洁具、厨具）" 22) ("P-平面洁具（地格显示）" 22)
      ("HS-A-停车位（标准）5.1" 22) ("HS-A-停车位（标准）5.3" 22)
      ("P-固定家具（落地、到顶）" 24)
      ("P-洁具及配件（地坪图显示）" 26) ("P-固定家具（落地、不到顶）" 26)
      ("P-洁具及配件（地坪图不显示）" 28)
    )
  )
  
  ; 定义冻结处理的列表（后缀名 长度）
  (setq freeze-suffix-list
    '(("DOTE" 4) ("AXIS" 4) ("车道" 4) ("距离" 4)
      ("p排水" 5)
      ("辅助线" 6) ("车行线" 6) ("雨水管" 6) ("保温线" 6)
      ("PUB_DIM" 7) ("S索引框" 7) ("Pa-turn" 7)
      ("DIM_LEAD" 8) ("消防车道" 8) ("疏散距离" 8) ("车行流线" 8) ("降板范围" 8) ("疏散指示" 8) ("战时内容" 8) ("道路中线" 8) ("内部轴号" 8) ("降板填充" 8)
      ("F疏散距离" 9) ("WS_地漏_W" 9)
      ("s-设备基础" 10) ("DIM_标注_A" 10) ("楼电梯编号" 10) ("人防门编号" 10) ("道路中心线" 10)
      ("DOTE_轴线_A" 11) ("WINDOW_TEXT" 11) ("SYMB_排水_A" 11) ("SYMB_索引_A" 11) ("SYMB_引注_A" 11) ("B楼电梯编号" 11) ("平面洞口_A" 11) ("A-Road-Cntr" 11)
      ("0$FZ消防留洞" 12) ("地下室范围线" 12) ("厨卫空调洞口" 12) ("DIM_留洞标注" 12) ("电梯楼梯编号" 12) ("L-楼电梯编号" 12) ("人防门窗编号" 12)
      ("DOTE_次轴线_A" 13) ("PS_排水立管_W" 13) ("HS-A-门窗编号" 13) ("DOOR_FIRE_TEXT" 13)
      ("DOOR_FIRE_TEXT" 14) ("DIM_集水坑引注" 14) ("AXIS_轴号_内圈" 14) ("$0$DOTE_轴线_A" 14) ("人防门开启范围" 14) ("内部专用名称_A" 14)
      ("TEXT_门窗编号_A" 15) ("Pyle-kit-给排水" 15) ("HS-风管砖墙留洞" 15)
      ("LINE_辅助轮廓线_A" 17) ("STRUC-CONCRETE-cc" 17)
      ("Dim_变电所门洞更改" 18)
      ("HOLE_厨卫空调洞口_A" 19) ("PS_排水管线及标注_W" 19)
      ("AXIS_轴号_A_内部轴网" 20)
    )
  )
  
  ; 定义打印状态处理的列表（后缀名 长度）
  (setq plot-suffix-list
    '(("防护区" 6)
      ("防火分区" 8) ("活动家具" 8) ("DIM_MODI" 8)
      ("防火分区线" 10) ("活动家具_A" 10)
      ("内部专用名称_A" 14)
    )
  )
  
  ; 遍历所有图层
  (vlax-for x (vla-get-layers (vla-get-activedocument (vlax-get-acad-object)))
    (setq a (vla-get-name x))

    ; 统一处理灰化
    (foreach item gray-suffix-list
      (setq suffix (car item))
      (setq len (cadr item))
      (if (and (>= (strlen a) len)  
               (= (substr a (- (strlen a) len) len) suffix))
        (vla-put-Color x 252)
      )
    )
    
    ; 统一处理冻结
    (foreach item freeze-suffix-list
      (setq suffix (car item))
      (setq len (cadr item))
      (if (and (>= (strlen a) len)  
               (= (substr a (- (strlen a) len) len) suffix))
        (if (= suffix "距离")
          (vla-put-Freeze x :vlax-false)  ; 特殊处理：距离需要解冻
          (vla-put-Freeze x :vlax-true)   ; 其他都冻结
        )          
      )
    )
    
    ; 统一处理打印状态
    (foreach item plot-suffix-list
      (setq suffix (car item))
      (setq len (cadr item))
      (if (and (>= (strlen a) len)                 
               (= (substr a (- (strlen a) len) len) suffix))  
        (if (or (= suffix "防护区") (= suffix "防火分区") (= suffix "防火分区线") (= suffix "内部专用名称_A"))
          (vla-put-Plottable x :vlax-false)  ; 这些设置为不可打印
          (vla-put-Plottable x :vlax-true)   ; 其他设置为可打印
        )
      )
    )
  )
  
  (command "regen")
  (princ "\n底图处理完成！")
  (princ " 2020.08.31 有问题请联系张裕锋-V3.0.0/此版本优化了代码结构，减少了重复代码")
  (prin1)

