;清理超大图纸
;(setvar "cmdecho" 0)
;(dictremove (namedobjdict) "ACAD_DGNLINESTYLECOMP")
;(command "_purge" "all" "" "n")
;(command "layer" "s" 0 "")
;(setvar "cmdecho" 1)

(defun ends-with (a s)
  (and (>= (strlen a) (strlen s))
       (= (substr a (- (strlen a) (strlen s) -1) (strlen s)) s)))

(defun tt ()
  (vl-load-com)

  (setq color-suffixes '(
    "JSK" "货车" "家具" "坑位" "空调" "屏幕" "填充" "银幕" "座椅"
    "COLU" "砼墙" "洁具" "器材" "厨卫" "窗帘" "活动" "疏散" "Cols" "Patt"
    "JSK2" "地沟" "线脚" "HATCH" "SCEEN" "STAIR" "LVTRY"
    "COLUMN" "CHEWEI" "21-CAR" "21洁具" "P-FURN" "微型车" "排污管"
    "构造柱" "面积线" "P-PFIX" "装饰面" "EL-DIM"
    "00-洁具" "LATRINE" "P_HATCH" "FF-FURN" "02平-地" "02平-顶"
    "EL-NORM" "1_填充_S" "Y-运动场" "地面标志" "防火卷帘"
    "疏散指示" "屏幕座位" "P-完成面" "洞口实线" "洞口虚线"
    "FF-FURNA" "IDS-FIXT" "D-detail"
    "0$0当前层" "colu_填充" "F防火卷帘" "F-家具-E3" "Plan-洁具"
    "名称-JSK2" "PUB_HATCH" "PROJ-LINE" "-战时拆除"
    "Audi seats" "AUDI_SEATS" "COLU_HATCH" "D-电梯编号" "疏散梯类型"
    "自动扶梯-2" "P-活动家具" "P-平面窗帘" "P-平面洁具" "W-区域文字"
    "Plan-new门" "顶面造型线"
    "A-车位线-电" "COLU_柱墙_A" "MTRL_铝板_A" "MTRL_石材_A"
    "P5-活动家具" "PUB_HATCH_A" "SYMB_排水_A" "WS_厨房设备"
    "装饰-完成面" "I-ELEV-OTL2" "I-ELEV-MBND"
    "1_平面洞口_S" "EQU_空调机_A" "P-平面楼梯线" "固定(不到顶)"
    "太阳能集热板"
    "0$KTs系统设备" "A-通用-投影线" "BEAM_梁实线_S" "BEAM_梁虚线_S"
    "BRIK_构造柱_S" "COLU_柱填充_A" "COMP_建筑沟_A" "COMP_结构沟_A"
    "LINE_投影线_A" "HS-A-防火卷帘" "HS-A-填充图案" "Plan-完成面墙"
    "Plan-固定道具" "LINE_中粗线_A"
    "J-平面固定家具" "J-平面活动家具" "STAIR_楼电梯_A" "EQU_厨卫设备_A"
    "EQU_固定家具_A" "EQU_活动家具_A" "P-平面活动家具" "暖通井文件TEXT"
    "A-通用-图案填充" "HOLE_平面洞口_A" "Plan-toilet洁具" "S_STAIR_楼电梯_"
    "TRI-B2$0$A-DRAN" "WALL_柱墙填充_S" "DS-HIGH CABINET"
    "HATCH_通用填充_A"
    "F-FLR3 (PLATFORM)" "HATCH_立面填充1_A" "HATCH_立面填充2_A"
    "COLU_上层柱轮廓_S" "COLU_下层柱轮廓_S" "ICDA方案_活动家具"
    "P9-平面家具灰度层" "WALL_上层墙轮廓_S" "WALL_下层墙轮廓_S"
    "辅助-安全出口指示"
    "P-固定家具（悬空）"
    "HS-A-停车位（标准）"
    "FF--FURN_SF(固定家俱)" "WALL_地下室外墙填充_S"
    "FF--FIXT（洁具、厨具）" "P-平面洁具（地格显示）"
    "HS-A-停车位（标准）5.1" "HS-A-停车位（标准）5.3"
    "P-固定家具（落地、到顶）"
    "P-洁具及配件（地坪图显示）" "P-固定家具（落地、不到顶）"
    "P-洁具及配件（地坪图不显示）"
  ))

  (setq freeze-suffixes '(
    "DOTE" "AXIS" "车道" "p排水" "辅助线" "车行线" "雨水管" "保温线"
    "PUB_DIM" "S索引框" "Pa-turn"
    "DIM_LEAD" "消防车道" "疏散距离" "车行流线" "降板范围"
    "疏散指示" "战时内容" "道路中线" "内部轴号" "降板填充"
    "F疏散距离" "WS_地漏_W"
    "s-设备基础" "DIM_标注_A" "楼电梯编号" "人防门编号" "道路中心线"
    "DOTE_轴线_A" "WINDOW_TEXT" "SYMB_排水_A" "SYMB_索引_A"
    "SYMB_引注_A" "B楼电梯编号" "平面洞口_A" "A-Road-Cntr"
    "0$FZ消防留洞" "地下室范围线" "厨卫空调洞口" "DIM_留洞标注"
    "电梯楼梯编号" "L-楼电梯编号" "人防门窗编号"
    "DOTE_次轴线_A" "PS_排水立管_W" "HS-A-门窗编号" "DOOR_FIRE_TEXT"
    "DIM_集水坑引注" "AXIS_轴号_内圈" "$0$DOTE_轴线_A"
    "人防门开启范围" "内部专用名称_A"
    "TEXT_门窗编号_A" "Pyle-kit-给排水" "HS-风管砖墙留洞"
    "LINE_辅助轮廓线_A" "STRUC-CONCRETE-cc"
    "Dim_变电所门洞更改"
    "HOLE_厨卫空调洞口_A" "PS_排水管线及标注_W"
    "AXIS_轴号_A_内部轴网"
  ))

  (setq unfreeze-suffixes '("距离"))

  (setq hide-suffixes '("防护区" "防火分区" "防火分区线" "内部专用名称_A"))
  (setq show-suffixes '("活动家具" "DIM_MODI" "活动家具_A"))

  (vlax-for x (vla-get-layers (vla-get-activedocument (vlax-get-acad-object)))
    (setq a (vla-get-name x))

    (foreach s color-suffixes
      (if (ends-with a s) (vla-put-Color x 252)))

    (foreach s freeze-suffixes
      (if (ends-with a s) (vla-put-Freeze x :vlax-true)))

    (foreach s unfreeze-suffixes
      (if (ends-with a s) (vla-put-Freeze x :vlax-false)))

    (foreach s hide-suffixes
      (if (ends-with a s) (vla-put-Plottable x :vlax-false)))

    (foreach s show-suffixes
      (if (ends-with a s) (vla-put-Plottable x :vlax-true)))
  )

  (command "regen")
  (princ)
)

(princ " 2020.08.31 有问题请联系张裕锋-V2.4.0/此版本增加了设置打印状态的代码")
