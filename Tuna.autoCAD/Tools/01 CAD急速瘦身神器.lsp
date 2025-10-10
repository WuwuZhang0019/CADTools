;打开超大图纸，将此文件直接拖入cad即可。
(setvar "cmdecho" 0)
(dictremove (namedobjdict) "ACAD_DGNLINESTYLECOMP")
(command "_purge" "all" "" "n")
(setvar "cmdecho" 1)
(princ)

