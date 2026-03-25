;;;=============================================================================
;;; 底图处理 (DTCL) - AutoCAD图层批量处理工具
;;; 功能：清理DGN残留、清理未使用对象、批量设置图层颜色/冻结/打印状态
;;; 版本：V3.0.0 - 代码结构优化重构
;;; 原作者：张裕锋  |  优化日期：2026.03.25
;;;=============================================================================

;;; ---------- 第一部分：清理超大图纸 ----------
(setvar "cmdecho" 0)
(dictremove (namedobjdict) "ACAD_DGNLINESTYLECOMP")
(command "_purge" "all" "" "n")
(command "layer" "s" 0 "")  ; 将0层设为当前层
(setvar "cmdecho" 1)

;;; ---------- 第二部分：工具函数 ----------

;; 判断字符串 str 是否以 suffix 结尾（支持中文）
(defun DTCL:ends-with (str suffix / slen xlen)
  (setq slen (strlen str)
        xlen (strlen suffix)
  )
  (and (>= slen xlen)
       (= (substr str (1+ (- slen xlen)) xlen) suffix)
  )
)

;; 遍历列表，若图层名以列表中任一后缀结尾，则执行 action-fn
;; action-fn 接受两个参数：图层对象 和 匹配到的后缀（用于调试）
(defun DTCL:apply-by-suffix (layer-obj layer-name suffix-list action-fn / sfx)
  (foreach sfx suffix-list
    (if (DTCL:ends-with layer-name sfx)
      (progn
        (apply action-fn (list layer-obj sfx))
        ;; 注意：此处不 break，允许多条规则命中（与原始行为一致）
      )
    )
  )
)

;;; ---------- 第三部分：规则数据定义 ----------
;;; 只需在此处增删后缀即可，无需修改逻辑代码

;; ---- 灰化规则：将匹配图层颜色设为 252（浅灰） ----
(setq *DTCL-GRAY-SUFFIXES*
  (list
    ;; 3字符
    "JSK"
    ;; 4字符
    "货车" "家具" "坑位" "空调" "屏幕" "填充" "银幕" "座椅"
    "COLU" "砼墙" "洁具" "器材" "厨卫" "窗帘" "活动" "疏散"
    "Cols" "Patt" "JSK2" "地沟" "线脚"
    ;; 5字符
    "HATCH" "SCEEN" "STAIR" "LVTRY"
    ;; 6字符
    "COLUMN" "CHEWEI" "21-CAR" "21洁具" "P-FURN" "微型车"
    "排污管" "构造柱" "面积线" "P-PFIX" "装饰面" "EL-DIM"
    ;; 7字符
    "00-洁具" "LATRINE" "P_HATCH" "FF-FURN"
    "02平-地" "02平-顶" "EL-NORM"
    ;; 8字符
    "1_填充_S" "Y-运动场" "地面标志" "防火卷帘"
    "疏散指示" "屏幕座位" "P-完成面" "洞口实线"
    "洞口虚线" "FF-FURNA" "IDS-FIXT" "D-detail"
    ;; 9字符
    "0$0当前层" "colu_填充" "F防火卷帘" "F-家具-E3"
    "Plan-洁具" "名称-JSK2" "PUB_HATCH" "PROJ-LINE"
    "-战时拆除"
    ;; 10字符
    "Audi seats" "AUDI_SEATS" "COLU_HATCH" "D-电梯编号"
    "疏散梯类型" "自动扶梯-2" "P-活动家具" "P-平面窗帘"
    "P-平面洁具" "W-区域文字" "Plan-new门" "顶面造型线"
    ;; 11字符
    "A-车位线-电" "COLU_柱墙_A" "MTRL_铝板_A" "MTRL_石材_A"
    "P5-活动家具" "PUB_HATCH_A" "SYMB_排水_A" "WS_厨房设备"
    "装饰-完成面" "I-ELEV-OTL2" "I-ELEV-MBND"
    ;; 12字符
    "1_平面洞口_S" "EQU_空调机_A" "P-平面楼梯线"
    "固定(不到顶)" "太阳能集热板"
    ;; 13字符
    "0$KTs系统设备" "A-通用-投影线" "BEAM_梁实线_S" "BEAM_梁虚线_S"
    "BRIK_构造柱_S" "COLU_柱填充_A" "COMP_建筑沟_A" "COMP_结构沟_A"
    "LINE_投影线_A" "HS-A-防火卷帘" "HS-A-填充图案" "Plan-完成面墙"
    "Plan-固定道具" "LINE_中粗线_A"
    ;; 14字符
    "J-平面固定家具" "J-平面活动家具" "STAIR_楼电梯_A"
    "EQU_厨卫设备_A" "EQU_固定家具_A" "EQU_活动家具_A"
    "P-平面活动家具" "暖通井文件TEXT"
    ;; 15字符
    "A-通用-图案填充" "HOLE_平面洞口_A" "Plan-toilet洁具"
    "S_STAIR_楼电梯_" "TRI-B2$0$A-DRAN" "WALL_柱墙填充_S"
    "DS-HIGH CABINET"
    ;; 16字符
    "HATCH_通用填充_A"
    ;; 17字符
    "F-FLR3 (PLATFORM)" "HATCH_立面填充1_A" "HATCH_立面填充2_A"
    "COLU_上层柱轮廓_S" "COLU_下层柱轮廓_S" "ICDA方案_活动家具"
    "P9-平面家具灰度层" "WALL_上层墙轮廓_S" "WALL_下层墙轮廓_S"
    "辅助-安全出口指示"
    ;; 18字符
    "P-固定家具（悬空）"
    ;; 19字符
    "HS-A-停车位（标准）"
    ;; 21字符
    "FF--FURN_SF(固定家俱)" "WALL_地下室外墙填充_S"
    ;; 22字符
    "FF--FIXT（洁具、厨具）" "P-平面洁具（地格显示）"
    "HS-A-停车位（标准）5.1" "HS-A-停车位（标准）5.3"
    ;; 24字符
    "P-固定家具（落地、到顶）"
    ;; 26字符
    "P-洁具及配件（地坪图显示）" "P-固定家具（落地、不到顶）"
    ;; 28字符
    "P-洁具及配件（地坪图不显示）"
  )
)

;; ---- 冻结规则：将匹配图层冻结 ----
(setq *DTCL-FREEZE-SUFFIXES*
  (list
    ;; 4字符
    "DOTE" "AXIS" "车道"
    ;; 5字符
    "p排水"
    ;; 6字符
    "辅助线" "车行线" "雨水管" "保温线"
    ;; 7字符
    "PUB_DIM" "S索引框" "Pa-turn"
    ;; 8字符
    "DIM_LEAD" "消防车道" "疏散距离" "车行流线"
    "降板范围" "疏散指示" "战时内容" "道路中线"
    "内部轴号" "降板填充"
    ;; 9字符
    "F疏散距离" "WS_地漏_W"
    ;; 10字符
    "s-设备基础" "DIM_标注_A" "楼电梯编号" "人防门编号"
    "道路中心线"
    ;; 11字符
    "DOTE_轴线_A" "WINDOW_TEXT" "SYMB_排水_A"
    "SYMB_索引_A" "SYMB_引注_A" "B楼电梯编号"
    "平面洞口_A" "A-Road-Cntr"
    ;; 12字符
    "0$FZ消防留洞" "地下室范围线" "厨卫空调洞口"
    "DIM_留洞标注" "电梯楼梯编号" "L-楼电梯编号"
    "人防门窗编号"
    ;; 13字符
    "DOTE_次轴线_A" "PS_排水立管_W" "HS-A-门窗编号"
    "DOOR_FIRE_TEXT"
    ;; 14字符
    "DIM_集水坑引注" "AXIS_轴号_内圈"
    "$0$DOTE_轴线_A" "人防门开启范围" "内部专用名称_A"
    ;; 15字符
    "TEXT_门窗编号_A" "Pyle-kit-给排水" "HS-风管砖墙留洞"
    ;; 17字符
    "LINE_辅助轮廓线_A" "STRUC-CONCRETE-cc"
    ;; 18字符
    "Dim_变电所门洞更改"
    ;; 19字符
    "HOLE_厨卫空调洞口_A" "PS_排水管线及标注_W"
    ;; 20字符
    "AXIS_轴号_A_内部轴网"
  )
)

;; ---- 解冻规则：强制解冻的图层（特殊例外）----
(setq *DTCL-THAW-SUFFIXES*
  (list
    "距离"   ;; 4字符 - 原代码中设为 :vlax-false（解冻）
  )
)

;; ---- 不可打印规则 ----
(setq *DTCL-NOPLOT-SUFFIXES*
  (list
    "防护区"
    "防火分区"
    "防火分区线"
    "内部专用名称_A"
  )
)

;; ---- 可打印规则（强制设为可打印）----
(setq *DTCL-PLOT-SUFFIXES*
  (list
    "活动家具"
    "DIM_MODI"
    "活动家具_A"
  )
)

;;; ---------- 第四部分：执行处理 ----------

(defun C:DTCL (/ acDoc layers layer-name)
  (vl-load-com)
  (setq acDoc (vla-get-activedocument (vlax-get-acad-object)))

  ;; 遍历所有图层
  (vlax-for x (vla-get-layers acDoc)
    (setq layer-name (vla-get-name x))

    ;; 1) 灰化处理
    (DTCL:apply-by-suffix x layer-name *DTCL-GRAY-SUFFIXES*
      (function (lambda (obj sfx) (vla-put-Color obj 252)))
    )

    ;; 2) 冻结处理（跳过当前层，AutoCAD 不允许冻结当前层）
    (if (/= (strcase layer-name) (strcase (getvar "CLAYER")))
      (progn
        (DTCL:apply-by-suffix x layer-name *DTCL-FREEZE-SUFFIXES*
          (function (lambda (obj sfx) (vla-put-Freeze obj :vlax-true)))
        )
        (DTCL:apply-by-suffix x layer-name *DTCL-THAW-SUFFIXES*
          (function (lambda (obj sfx) (vla-put-Freeze obj :vlax-false)))
        )
      )
    )

    ;; 3) 打印状态
    (DTCL:apply-by-suffix x layer-name *DTCL-NOPLOT-SUFFIXES*
      (function (lambda (obj sfx) (vla-put-Plottable obj :vlax-false)))
    )
    (DTCL:apply-by-suffix x layer-name *DTCL-PLOT-SUFFIXES*
      (function (lambda (obj sfx) (vla-put-Plottable obj :vlax-true)))
    )
  )

  ;; 刷新显示
  (command "regen")

  (princ "\n[DTCL] 底图处理完成 - V3.0.0")
  (princ)
)

;; 自动执行
(C:DTCL)
