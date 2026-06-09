;;; PL线转桥架工具
;;; 将pline线转换为电气桥架

(defun C:PTB (/ ss i ent pts successCount failCount)
  "将选择的pline线转换为桥架"
  
  ;; 选择pline线
  (princ "\n请选择要转换为桥架的pline线: ")
  (setq ss (ssget '((0 . "LWPOLYLINE"))))
  
  (if ss
    (progn
      (princ (strcat "\n已选择 " (itoa (sslength ss)) " 条pline线"))
      
      ;; 初始化计数器
      (setq successCount 0)
      (setq failCount 0)
      
      ;; 处理每条pline线
      (setq i 0)
      (repeat (sslength ss)
        (setq ent (ssname ss i))
        (setq pts (GetPlineVertices ent))
        
        (if pts
          (progn
            (princ (strcat "\n正在处理第 " (itoa (1+ i)) " 条pline线..."))
            
            ;; 使用错误处理包装
            (if (vl-catch-all-error-p 
                  (vl-catch-all-apply 'ConvertPlineToBridge (list pts))
                )
              (progn
                (princ (strcat "\n第 " (itoa (1+ i)) " 条pline线创建失败"))
                (setq failCount (1+ failCount))
              )
              (progn
                (princ (strcat "\n第 " (itoa (1+ i)) " 条pline线创建成功"))
                (setq successCount (1+ successCount))
              )
            )
          )
          (progn
            (princ (strcat "\n第 " (itoa (1+ i)) " 条pline线顶点数据无效"))
            (setq failCount (1+ failCount))
          )
        )
        
        (setq i (1+ i))
      )
      
      ;; 显示结果统计
      (princ (strcat "\n转换完成! 成功: " (itoa successCount) " 条, 失败: " (itoa failCount) " 条"))
    )
    (princ "\n未选择任何pline线")
  )
  
  (princ)
)

(defun GetPlineVertices (ent / data pt closed pts)
  "获取pline线的所有顶点坐标"
  
  (setq data (entget ent))
  (setq pts '())
  (setq closed nil)
  
  ;; 检查是否闭合
  (foreach item data
    (if (= (car item) 70)
      (if (= (logand (cdr item) 1) 1)
        (setq closed T)
      )
    )
  )
  
  ;; 获取所有顶点
  (foreach item data
    (if (= (car item) 10)
      (progn
        (setq pt (cdr item))
        ;; 确保点是三维的
        (if (= (length pt) 2)
          (setq pt (append pt '(0.0)))
        )
        (setq pts (append pts (list pt)))
      )
    )
  )
  
  ;; 如果是闭合pline，添加起点作为终点
  (if (and closed pts (> (length pts) 1))
    (setq pts (append pts (list (car pts))))
  )
  
  pts
)

(defun ConvertPlineToBridge (pts / cmd)
  "将点列表转换为桥架"
  
  (if (and pts (>= (length pts) 2))
    (progn
      ;; 确保没有正在执行的命令
      (while (> (getvar "CMDACTIVE") 0)
        (command "")
      )
      
      ;; 开始telcableadd命令
      (command "telcableadd")
      
      ;; 依次选择每个点
      (foreach pt pts
        (command pt)
      )
      
      ;; 结束命令 - 使用空格而不是空字符串
      (command " ")
      
      ;; 等待命令完成
      (while (> (getvar "CMDACTIVE") 0)
        (command " ")
      )
    )
    (princ "\n点数量不足，无法创建桥架")
  )
)

;(princ "\nPL线转桥架工具已加载")
;(princ "\n输入 PTB 开始转换")
(c:PTB)
(prin1)
