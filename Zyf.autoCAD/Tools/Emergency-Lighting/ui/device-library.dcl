// Date: 2026-10-16. Status: explicit save with verification plus automatic persistence.
el_device_library_locked : dialog {
  label = "独立设备库 - 占用恢复";
  : text { key = "dl_lock_root"; width = 104; }
  : text { label = "设备库存在占用文件。先结束其他 CAD 中的设备库保存，再检查并恢复。"; }
  : text { label = "恢复会保留占用文件备份，不删除设备资料。当前回路和输入保留。"; }
  : toggle { key = "dl_lock_confirm"; label = "我已确认其他 CAD 不再写入这个设备库"; }
  : text { key = "dl_lock_status"; width = 104; }
  : row {
    : button { key = "dl_lock_recover"; label = "检查并恢复占用"; }
    : button { key = "dl_lock_retry"; label = "重新检查"; }
    : button { key = "dl_lock_cancel"; label = "返回（保留输入）"; is_cancel = true; }
  }
}
el_device_library : dialog {
  label = "独立设备库";
  : column { fixed_height = true; alignment = top;
    : text { key = "dl_root"; width = 104; fixed_height = true; }
    : row { fixed_height = true;
      : text { label = "功率参数：catalog.eld；点击保存设备并核对成功后发送此文件。"; }
      : button { key = "dl_open"; label = "打开所在文件夹"; }
    }
  }
  : row {
    : column {
      : edit_box { key = "dl_query"; label = "搜索图块名 / 设备名"; edit_width = 28; }
      : toggle { key = "dl_deleted"; label = "同时显示已删除设备"; }
      : list_box { key = "dl_rows"; label = "图块名 / 设备名 / 状态"; width = 48; height = 19; }
      : button { key = "dl_pick"; label = "拾取设备入库（可多选）"; }
      : row {
        : button { key = "dl_new"; label = "新增"; }
        : button { key = "dl_delete"; label = "删除"; }
        : button { key = "dl_restore"; label = "恢复"; }
      }
      : row {
        : button { key = "dl_refresh"; label = "刷新列表"; }
        : button { key = "dl_reload"; label = "重载选中项"; }
        : button { key = "dl_directory"; label = "更改库目录"; }
      }
      : button { key = "dl_import"; label = "导入设备库"; help_string = "导入完整设备库的独立副本并切换使用，原库保留"; }
    }
    : boxed_column {
      label = "设备资料";
      : image { key = "dl_image"; width = 44; height = 8; fixed_width = true; fixed_height = true; color = 0; }
      : text { key = "dl_asset"; width = 50; }
      : edit_box { key = "dl_block"; label = "图块名"; edit_width = 30; }
      : edit_box { key = "dl_aliases"; label = "别名（用分号分隔）"; edit_width = 30; }
      : toggle { key = "dl_keep_old"; label = "改名时保留原图块名为别名"; value = "1"; }
      : edit_box { key = "dl_display"; label = "设备名"; edit_width = 30; }
      : edit_box { key = "dl_watts"; label = "单个功率（整数 W）"; edit_width = 12; }
      : toggle { key = "dl_zero"; label = "明确确认此设备为 0W"; }
      : popup_list { key = "dl_ground"; label = "是否地面"; }
      : toggle { key = "dl_active"; label = "启用名称匹配"; value = "1"; }
      : button { key = "dl_export"; label = "导出设备库"; help_string = "导出包含功率、图形和图例的设备库文件夹"; }
      : button { key = "dl_save"; label = "保存设备"; }
      : text { label = "点击保存设备后核对下方结果；离开输入框时也会自动保存。"; }
    }
  }
  : text { key = "dl_status"; width = 104; }
  : text { label = "重新统计时刷新库默认值，保留手填值；新图仅在点击生成后创建。"; }
  : row {
    : button { key = "dl_close"; label = "关闭"; is_cancel = true; }
  }
}
el_device_import : dialog {
  label = "导入旧资料";
  : text { label = "选择要导入的资料；同名不同参数必须只选一种。"; }
  : list_box { key = "di_rows"; width = 104; height = 16; multiple_select = true; }
  : text { key = "di_backup"; width = 104; }
  : text { key = "di_status"; width = 104; }
  : text { label = "仅创建待补资料的编辑草稿；原文件保留，不推断地面属性。"; }
  : row {
    : button { key = "di_accept"; label = "导入选中项"; is_default = true; }
    : button { key = "di_cancel"; label = "取消"; is_cancel = true; }
  }
}
