;2021.06.08 张裕锋
;公区应急照明16m一个，疏散指示10m一个，地面3m
;应急灯图块名med，吊装疏散指示灯图块名mes,地面疏散f
;(defun c:med()
;(command "measure" PAUSE  "B" "med" "y" "16000" )
;(prin1)
;)
;(defun c:mes()
;(command "measure" PAUSE  "B" "mes" "y" "10000" )
;(prin1)
;)
(defun c:mee()
(command "measure" PAUSE  "B" "f" "y" "3000" )
)
(c:mee)
(prin1)
