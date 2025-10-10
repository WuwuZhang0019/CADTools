(defun c:a1()
    (setq new_d (strcat d "A"))
    (setq new_b "变")
    (setq new_txt (cons 1 (strcat a new_b c new_d)))
    (setq new_text (subst new_txt old_txt text_data)) 
    (entmod new_text)
)
(defun c:a2()
    (setq e (substr txt 6 2))
    (setq f (substr txt len 1))
    (setq new_f (chr (+ (ASCII f) 1)))
    (setq new_txt (cons 1 (strcat a b c e new_f)))
    (setq new_text (subst new_txt old_txt text_data)) 
    (entmod new_text)
)
(defun c:a3()
    (setq e (substr txt 6 3))
    (setq f (substr txt len 1))
    (setq new_f (chr (+ (ASCII f) 1)))
    (setq new_txt (cons 1 (strcat a b c e new_f)))
    (setq new_text (subst new_txt old_txt text_data)) 
    (entmod new_text)
)
(defun c:thdz()
(setq text_data (entget (car (entsel))))
;((-1 . <图元名: 249a3470050>) (0 . "TEXT") (330 . <图元名: 249c22cc020>) (5 . "F5") (100 . "AcDbEntity") (67 . 0) (410 . "Model") (8 . "图框") (100 . "AcDbText") (10 159502.0 855675.0 0.0) (40 . 400.0) (1 . "电施-01") (50 . 0.0) (41 . 0.7) (51 . 0.0) (7 . "hztxt") (71 . 0) (72 . 0) (11 0.0 0.0 0.0) (210 0.0 0.0 1.0) (100 . "AcDbText") (73 . 0))
(setq old_txt (assoc 1 text_data));(1 . "电施-01")
(setq txt (cdr old_txt));"电施-01"
(setq len (strlen txt));7
(setq a (substr txt 1 2));"电"
(setq b (substr txt 3 2));"施"
(setq c (substr txt 5 1));"-"
(setq d (substr txt 6 len));"01"
(if (= b "施") (c:a1))
(if (and (= b "变") (wcmatch d "##@")) (c:a2))
(if (and (= b "变") (wcmatch d "###@")) (c:a3))
(princ "\n2022.08.11-V2.0版 有问题请联系张裕锋")
)
(c:thdz)
(prin1)



  


  