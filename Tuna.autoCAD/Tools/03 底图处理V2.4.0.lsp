;清理超大图纸
(setvar "cmdecho" 0)
(dictremove (namedobjdict) "ACAD_DGNLINESTYLECOMP")
(command "_purge" "all" "" "n")
(command "layer" "s" 0 "") ;将0层设为当前层
(setvar "cmdecho" 1)
;此版本解决了中文乱码的问题
defun tt()
(vl-load-com)
(setq acmCol (vla-getinterfaceobject 
           (vlax-get-acad-object)  (strcat "AutoCAD.AcCmColor." (substr (getvar "ACADVER") 1 2))))
(vlax-for x (vla-get-layers (vla-get-activedocument (vlax-get-acad-object)))
(setq a (vla-get-name x))
;灰化
(if (> (strlen a) 2)
  (cond  
       ((= (substr a (- (strlen a) 2) 3) "JSK") (vla-put-Color x 252))
))

(if (> (strlen a) 3)
  (cond  
       ((= (substr a (- (strlen a) 3) 4) "货车") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "家具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "坑位") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "空调") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "屏幕") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "填充") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "银幕") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "座椅") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "COLU") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "砼墙") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "洁具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "器材") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "厨卫") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "窗帘") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "活动") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "疏散") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "Cols") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "Patt") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "JSK2") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "地沟") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 3) 4) "线脚") (vla-put-Color x 252))
))
(if (> (strlen a) 4)
  (cond  
       ((= (substr a (- (strlen a) 4) 5) "HATCH") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 4) 5) "SCEEN") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 4) 5) "STAIR") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 4) 5) "LVTRY") (vla-put-Color x 252))
))
(if (> (strlen a) 5)
  (cond
       ((= (substr a (- (strlen a) 5) 6) "COLUMN") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 5) 6) "CHEWEI") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 5) 6) "21-CAR") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 5) 6) "21洁具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 5) 6) "P-FURN") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 5) 6) "微型车") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 5) 6) "排污管") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 5) 6) "构造柱") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 5) 6) "面积线") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 5) 6) "P-PFIX") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 5) 6) "装饰面") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 5) 6) "EL-DIM") (vla-put-Color x 252))




))
(if (> (strlen a) 6)
  (cond  
       ((= (substr a (- (strlen a) 6) 7) "00-洁具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 6) 7) "LATRINE") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 6) 7) "P_HATCH") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 6) 7) "FF-FURN") (vla-put-Color x 252))     
       ((= (substr a (- (strlen a) 6) 7) "02平-地") (vla-put-Color x 252)) 
       ((= (substr a (- (strlen a) 6) 7) "02平-顶") (vla-put-Color x 252)) 
       ((= (substr a (- (strlen a) 6) 7) "EL-NORM") (vla-put-Color x 252)) 

))
(if (> (strlen a) 7)
  (cond  
       ((= (substr a (- (strlen a) 7) 8) "1_填充_S") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 7) 8) "Y-运动场") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 7) 8) "地面标志") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 7) 8) "防火卷帘") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 7) 8) "疏散指示") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 7) 8) "屏幕座位") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 7) 8) "P-完成面") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 7) 8) "1_填充_S") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 7) 8) "洞口实线") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 7) 8) "洞口虚线") (vla-put-Color x 252))
      ((= (substr a (- (strlen a) 7) 8) "FF-FURNA")(vla-put-Color x 252))
      ((= (substr a (- (strlen a) 7) 8) "IDS-FIXT")(vla-put-Color x 252))
      ((= (substr a (- (strlen a) 7) 8) "D-detail")(vla-put-Color x 252))

))
(if (> (strlen a) 8)
  (cond  
       ((= (substr a (- (strlen a) 8) 9) "0$0当前层") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 8) 9) "colu_填充") (vla-put-Color x 252))  
       ((= (substr a (- (strlen a) 8) 9) "F防火卷帘") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 8) 9) "F-家具-E3") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 8) 9) "Plan-洁具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 8) 9) "名称-JSK2") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 8) 9) "PUB_HATCH") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 8) 9) "PROJ-LINE") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 8) 9) "-战时拆除") (vla-put-Color x 252))

))
(if (> (strlen a) 9)
  (cond  
       ((= (substr a (- (strlen a) 9) 10) "Audi seats") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 9) 10) "AUDI_SEATS") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 9) 10) "COLU_HATCH") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 9) 10) "D-电梯编号") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 9) 10) "疏散梯类型") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 9) 10) "自动扶梯-2") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 9) 10) "P-活动家具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 9) 10) "P-平面窗帘") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 9) 10) "P-平面洁具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 9) 10) "W-区域文字") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 9) 10) "Plan-new门") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 9) 10) "顶面造型线") (vla-put-Color x 252))


))
(if (> (strlen a) 10)
  (cond  
       ((= (substr a (- (strlen a) 10) 11) "A-车位线-电") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 10) 11) "COLU_柱墙_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 10) 11) "MTRL_铝板_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 10) 11) "MTRL_石材_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 10) 11) "P5-活动家具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 10) 11) "PUB_HATCH_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 10) 11) "SYMB_排水_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 10) 11) "WS_厨房设备") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 10) 11) "装饰-完成面") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 10) 11) "I-ELEV-OTL2") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 10) 11) "I-ELEV-MBND") (vla-put-Color x 252))

))
(if (> (strlen a) 11)
  (cond  
       ((= (substr a (- (strlen a) 11) 12) "1_平面洞口_S") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 11) 12) "EQU_空调机_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 11) 12) "P-平面楼梯线") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 11) 12) "固定(不到顶)") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 11) 12) "太阳能集热板") (vla-put-Color x 252))

))
(if (> (strlen a) 12)
  (cond  
       ((= (substr a (- (strlen a) 12) 13) "0$KTs系统设备") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "A-通用-投影线") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "BEAM_梁实线_S") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "BEAM_梁虚线_S") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "BRIK_构造柱_S") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "COLU_柱填充_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "COMP_建筑沟_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "COMP_结构沟_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "LINE_投影线_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "HS-A-防火卷帘") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "HS-A-填充图案") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "Plan-完成面墙") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "Plan-固定道具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 12) 13) "LINE_中粗线_A") (vla-put-Color x 252))
))
(if (> (strlen a) 13)
  (cond  
       ((= (substr a (- (strlen a) 13) 14) "J-平面固定家具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 13) 14) "J-平面活动家具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 13) 14) "STAIR_楼电梯_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 13) 14) "EQU_厨卫设备_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 13) 14) "EQU_固定家具_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 13) 14) "EQU_活动家具_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 13) 14) "P-平面活动家具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 13) 14) "暖通井文件TEXT") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 13) 14) "EQU_厨卫设备_A") (vla-put-Color x 252))
))
(if (> (strlen a) 14)
  (cond  
       ((= (substr a (- (strlen a) 14) 15) "A-通用-图案填充") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 14) 15) "HOLE_平面洞口_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 14) 15) "Plan-toilet洁具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 14) 15) "S_STAIR_楼电梯_") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 14) 15) "TRI-B2$0$A-DRAN") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 14) 15) "WALL_柱墙填充_S") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 14) 15) "Plan-toilet洁具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 14) 15) "DS-HIGH CABINET") (vla-put-Color x 252))
))
(if (> (strlen a) 15)
  (cond  
       ((= (substr a (- (strlen a) 15) 16) "HATCH_通用填充_A") (vla-put-Color x 252))

))
(if (> (strlen a) 16)
  (cond  
       ((= (substr a (- (strlen a) 16) 17) "F-FLR3 (PLATFORM)") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 16) 17) "HATCH_立面填充1_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 16) 17) "HATCH_立面填充2_A") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 16) 17) "COLU_上层柱轮廓_S") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 16) 17) "COLU_下层柱轮廓_S") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 16) 17) "ICDA方案_活动家具") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 16) 17) "P9-平面家具灰度层") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 16) 17) "WALL_上层墙轮廓_S") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 16) 17) "WALL_下层墙轮廓_S") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 16) 17) "辅助-安全出口指示") (vla-put-Color x 252))
))
(if (> (strlen a) 17)
  (cond  
       ((= (substr a (- (strlen a) 17) 18) "P-固定家具（悬空）") (vla-put-Color x 252))
))
(if (> (strlen a) 18)
  (cond  
       ((= (substr a (- (strlen a) 18) 19) "HS-A-停车位（标准）") (vla-put-Color x 252))
))
;(if (> (strlen a) 19)
;  (cond  
;))
(if (> (strlen a) 20)
  (cond  
       ((= (substr a (- (strlen a) 20) 21) "FF--FURN_SF(固定家俱)") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 20) 21) "WALL_地下室外墙填充_S") (vla-put-Color x 252))
))
(if (> (strlen a) 21)
  (cond  
       ((= (substr a (- (strlen a) 21) 22) "FF--FIXT（洁具、厨具）") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 21) 22) "P-平面洁具（地格显示）") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 21) 22) "HS-A-停车位（标准）5.1") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 21) 22) "HS-A-停车位（标准）5.3") (vla-put-Color x 252))
))
(if (> (strlen a) 23)
  (cond  
       ((= (substr a (- (strlen a) 23) 24) "P-固定家具（落地、到顶）") (vla-put-Color x 252))
))
(if (> (strlen a) 25)
  (cond  
       ((= (substr a (- (strlen a) 25) 26) "P-洁具及配件（地坪图显示）") (vla-put-Color x 252))
       ((= (substr a (- (strlen a) 25) 26) "P-固定家具（落地、不到顶）") (vla-put-Color x 252))
))
(if (> (strlen a) 27)
  (cond 
       ((= (substr a (- (strlen a) 27) 28) "P-洁具及配件（地坪图不显示）") (vla-put-Color x 252))
 ))


;冻结

(if (> (strlen a) 3)
  (cond 
       ((= (substr a (- (strlen a) 3) 4) "DOTE") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 3) 4) "AXIS") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 3) 4) "车道") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 3) 4) "距离") (vla-put-Freeze x :vlax-false))  

 ))
(if (> (strlen a) 4)
  (cond 
       ((= (substr a (- (strlen a) 4) 5) "p排水") (vla-put-Freeze x :vlax-true))
 ))
(if (> (strlen a) 5)
  (cond 
       ((= (substr a (- (strlen a) 5) 6) "辅助线") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 5) 6) "车行线") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 5) 6) "雨水管") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 5) 6) "保温线") (vla-put-Freeze x :vlax-true))  
 ))
(if (> (strlen a) 6)
  (cond 
       ((= (substr a (- (strlen a) 6) 7) "PUB_DIM") (vla-put-Freeze x :vlax-true)) 
       ((= (substr a (- (strlen a) 6) 7) "S索引框") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 6) 7) "Pa-turn") (vla-put-Freeze x :vlax-true))  
 ))
(if (> (strlen a) 7)
  (cond 
       ((= (substr a (- (strlen a) 7) 8) "DIM_LEAD") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 7) 8) "消防车道") (vla-put-Freeze x :vlax-true))   
       ((= (substr a (- (strlen a) 7) 8) "疏散距离") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 7) 8) "车行流线") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 7) 8) "降板范围") (vla-put-Freeze x :vlax-true))   
       ((= (substr a (- (strlen a) 7) 8) "疏散指示") (vla-put-Freeze x :vlax-true))   
       ((= (substr a (- (strlen a) 7) 8) "战时内容") (vla-put-Freeze x :vlax-true))   
       ((= (substr a (- (strlen a) 7) 8) "道路中线") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 7) 8) "内部轴号") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 7) 8) "降板填充") (vla-put-Freeze x :vlax-true))  
 ))
(if (> (strlen a) 8)
  (cond 
       ((= (substr a (- (strlen a) 8) 9) "F疏散距离") (vla-put-Freeze x :vlax-true)) 
       ((= (substr a (- (strlen a) 8) 9) "WS_地漏_W") (vla-put-Freeze x :vlax-true))  
 
 ))
(if (> (strlen a) 9)
  (cond 
       ((= (substr a (- (strlen a) 9) 10) "s-设备基础") (vla-put-Freeze x :vlax-true))   
       ((= (substr a (- (strlen a) 9) 10) "DIM_标注_A") (vla-put-Freeze x :vlax-true)) 
       ((= (substr a (- (strlen a) 9) 10) "楼电梯编号") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 9) 10) "人防门编号") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 9) 10) "道路中心线") (vla-put-Freeze x :vlax-true))  

 ))
(if (> (strlen a) 10)
  (cond 
       ((= (substr a (- (strlen a) 10) 11) "DOTE_轴线_A") (vla-put-Freeze x :vlax-true))  ;false
       ((= (substr a (- (strlen a) 10) 11) "WINDOW_TEXT") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 10) 11) "SYMB_排水_A") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 10) 11) "SYMB_索引_A") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 10) 11) "SYMB_引注_A") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 10) 11) "B楼电梯编号") (vla-put-Freeze x :vlax-true)) 
       ((= (substr a (- (strlen a) 10) 11) "平面洞口_A") (vla-put-Freeze x :vlax-true))
       ;((= (substr a (- (strlen a) 10) 11) "LINE_细线_A") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 10) 11) "A-Road-Cntr") (vla-put-Freeze x :vlax-true))

 ))
(if (> (strlen a) 11)
  (cond 
       ((= (substr a (- (strlen a) 11) 12) "0$FZ消防留洞") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 11) 12) "地下室范围线") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 11) 12) "厨卫空调洞口") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 11) 12) "DIM_留洞标注") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 11) 12) "电梯楼梯编号") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 11) 12) "L-楼电梯编号") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 11) 12) "人防门窗编号") (vla-put-Freeze x :vlax-true)) 

 ))
(if (> (strlen a) 12)
  (cond 
       ((= (substr a (- (strlen a) 12) 13) "DOTE_次轴线_A") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 12) 13) "PS_排水立管_W") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 12) 13) "HS-A-门窗编号") (vla-put-Freeze x :vlax-true)) 
       ((= (substr a (- (strlen a) 12) 13) "DOOR_FIRE_TEXT") (vla-put-Freeze x :vlax-true)) 

 ))
(if (> (strlen a) 13)
  (cond 
       ((= (substr a (- (strlen a) 13) 14) "DOOR_FIRE_TEXT") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 13) 14) "DIM_集水坑引注") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 13) 14) "AXIS_轴号_内圈") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 13) 14) "$0$DOTE_轴线_A") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 13) 14) "人防门开启范围") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 13) 14) "内部专用名称_A") (vla-put-Freeze x :vlax-true))   
 
 ))
(if (> (strlen a) 14)
  (cond 
       ((= (substr a (- (strlen a) 14) 15) "TEXT_门窗编号_A") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 14) 15) "Pyle-kit-给排水") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 14) 15) "HS-风管砖墙留洞") (vla-put-Freeze x :vlax-true))  
       
 ))
(if (> (strlen a) 16)
  (cond 
       ((= (substr a (- (strlen a) 16) 17) "LINE_辅助轮廓线_A") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 16) 17) "STRUC-CONCRETE-cc") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 16) 17) "LINE_辅助轮廓线_A") (vla-put-Freeze x :vlax-true)) 
 ))
(if (> (strlen a) 17)
  (cond 
       ((= (substr a (- (strlen a) 17) 18) "Dim_变电所门洞更改") (vla-put-Freeze x :vlax-true))  
 ))
(if (> (strlen a) 18)
  (cond 
       ((= (substr a (- (strlen a) 18) 19) "HOLE_厨卫空调洞口_A") (vla-put-Freeze x :vlax-true))  
      ; ((= (substr a (- (strlen a) 18) 19) "HOLE_厨卫空调洞口_A") (vla-put-Freeze x :vlax-true))  
       ((= (substr a (- (strlen a) 18) 19) "PS_排水管线及标注_W") (vla-put-Freeze x :vlax-true))  
 ))
(if (> (strlen a) 19)
  (cond 
       ((= (substr a (- (strlen a) 19) 20) "AXIS_轴号_A_内部轴网") (vla-put-Freeze x :vlax-true)) 
 ))

;打印状态

(if (> (strlen a) 5)
  (cond 
       ((= (substr a (- (strlen a) 5) 6) "防护区") (vla-put-Plottable x :vlax-false))  
      
 ))

(if (> (strlen a) 7)
  (cond 
       ((= (substr a (- (strlen a) 7) 8) "防火分区") (vla-put-Plottable x :vlax-false))   
       ((= (substr a (- (strlen a) 7) 8) "活动家具") (vla-put-Plottable x :vlax-true)) 
       ((= (substr a (- (strlen a) 7) 8) "DIM_MODI") (vla-put-Plottable x :vlax-true)) 
 ))
(if (> (strlen a) 9)
  (cond 
       ((= (substr a (- (strlen a) 9) 10) "防火分区线") (vla-put-Plottable x :vlax-false))   
       ((= (substr a (- (strlen a) 9) 10) "活动家具_A") (vla-put-Plottable x :vlax-true))
 ))
(if (> (strlen a) 13)
  (cond 
       ((= (substr a (- (strlen a) 13) 14) "内部专用名称_A") (vla-put-Plottable x :vlax-false))   
       
 ))


)
(command "regen" )

(princ)  " 2020.08.31 有问题请联系张裕锋-V2.4.0/此版本增加了设置打印状态的代码"

