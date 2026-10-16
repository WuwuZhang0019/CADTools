// EL_BOX_UI_011
el_exits : dialog {
  label = "整箱出口集中核对";
  : text { label = "点选后返回图面查看出线，按 Enter 返回；进线及非出线不选。"; }
  : list_box { key = "exits"; width = 88; height = 14; multiple_select = true; }
  : text { key = "scope_info"; width = 88; }
  : toggle { key = "scope_exclude"; label = "已核对：明确排除上述未纳入图层的箱边导线"; }
  : toggle { key = "role_recheck"; label = "重新核对已知设备角色（需要修正分类时勾选）"; }
  : button { key = "exit_preview"; label = "查看选中出线（返回图面）"; }
  : button { key = "exit_all"; label = "全选出线（请取消进线）"; }
  : button { key = "add_wire"; label = "补充导线图层"; }
  ok_cancel;
}
el_power : dialog {
  label = "应急照明设备功率表（整数瓦）";
  : list_box { key = "circuit_rows"; label = "回路 / 出口 / 数量 / 功率 / 识别状态"; width = 110; height = 6; }
  : toggle { key = "save_library"; label = "将本次明确确认的功率同时保存到设备库"; }
  : list_box { key = "rows"; label = "图块 / 本箱数量 / 各回路数量"; width = 88; height = 12; }
  : text { key = "source"; width = 80; }
  : popup_list { key = "category"; label = "确认类别"; }
  : edit_box { key = "display"; label = "显示名称"; edit_width = 40; }
  : edit_box { key = "watts"; label = "单个功率 W（整数）"; edit_width = 12; }
  : toggle { key = "zero"; label = "明确确认本行 0W 用途"; }
  : text { key = "error"; width = 80; }
  : row {
    : button { key = "save_row"; label = "保存此行"; }
    : button { key = "locate"; label = "定位图块"; }
  }
  : text { label = "先保存每个修改行；数量来自识别，不能直接手改。未知类别请明确选择。"; }
  ok_cancel;
}

el_roles : dialog {
  label = "连接图块按身份集中分类";
  : toggle { key = "role_library"; label = "将已确认角色同时保存到设备库"; }
  : list_box { key = "role_rows"; width = 88; height = 12; }
  : popup_list { key = "role_choice"; label = "角色"; }
  : text { key = "role_status"; width = 80; }
  : row {
    : button { key = "role_apply"; label = "确认本类角色"; }
    : button { key = "role_locate"; label = "定位全部实例"; }
  }
  : text { label = "未确认的类型保留为未知，不参与导通或负载计算。"; }
  ok_cancel;
}

// Date: 2026-10-08. Header and data share font, tabs and list-box insets.
el_device_columns : list_box {
  width = 85;
  fixed_width_font = true;
  tabs = "54 64";
  tab_truncate = true;
}

// Date: 2026-10-08. Simple device table: two picks, no role/exit review.
el_devices : dialog {
  label = "设备数量与功率";
  : text { label = "点选设备可在图面查看，按 Enter 返回；功率按图块名自动记住。"; }
  : el_device_columns { key = "s_header"; height = 1.5; fixed_height = true; is_enabled = false; is_tab_stop = false; }
  : el_device_columns { key = "s_names"; height = 13; }
  : text { key = "s_selected"; width = 85; }
  : edit_box { key = "s_edit"; label = "单个功率（W）"; edit_width = 12; }
  : text { key = "s_status"; width = 85; }
  : button { key = "s_locate"; label = "在图上查看该设备"; }
  : row {
    : button { key = "accept"; label = "保存并关闭"; is_default = true; }
    : button { key = "cancel"; label = "取消"; is_cancel = true; }
  }
}

// Date: 2026-10-16. Circuit rows share compact swatches and thin dividers.
el_panel_circuit_swatch : image {
  width = 2.5; height = 0.8; fixed_width = true; fixed_height = true;
  alignment = center; color = dialog_background;
}
el_panel_circuit_separator : image { height = 0.06; fixed_height = true; color = 8; }

// Date: 2026-10-16. Shared subassemblies keep compact and expanded panels identical.
el_panel_review : column { fixed_width = true; fixed_height = true; alignment = top;
    // Date: 2026-10-15. Four visible steps retain the existing pick controls.
    : row { fixed_width = true; fixed_height = true; alignment = left;
      : image { key = "p_step1"; width = 8; height = 1.3; fixed_width = true; fixed_height = true; color = dialog_background; help_string = "第一步：拾取配电箱和回路起始端导线"; }
      : text { label = "拾取配电箱和回路起始端导线"; width = 36; fixed_width = true; }
    }
    : row { fixed_width = true; alignment = left;
      : image_button { key = "p_pick"; width = 14; height = 1.8; fixed_width = true; fixed_height = true; color = 3; is_tab_stop = true; }
      : image_button { key = "p_trunk"; width = 28; height = 1.8; fixed_width = true; fixed_height = true; color = 3; is_tab_stop = true; }
    }
    : text { key = "p_number"; label = "配电箱编号：暂无编号"; width = 46; fixed_width = true; }
    : row { fixed_width = true; fixed_height = true; alignment = left;
      : image { key = "p_step2"; width = 8; height = 1.3; fixed_width = true; fixed_height = true; color = dialog_background; help_string = "第二步：选择配电箱容量"; }
      : text { label = "选择配电箱容量"; fixed_width = true; }
    }
    : radio_row { key = "p_capacity"; fixed_width = true; alignment = left;
      : radio_button { key = "p_300"; width = 10; fixed_width = true; label = "0.3kW"; value = "1"; }
      : radio_button { key = "p_600"; width = 10; fixed_width = true; label = "0.6kW"; }
      : radio_button { key = "p_1000"; width = 10; fixed_width = true; label = "1kW"; }
    }
    : boxed_column { label = "识别结果：回路编号 / 功率"; fixed_height = true; alignment = top;
      : row { fixed_height = true; alignment = left; : text { label = "ZE1"; width = 4; fixed_width = true; } : el_panel_circuit_swatch { key = "p_color0"; } : text { key = "p_row0"; width = 22; } }
      el_panel_circuit_separator;
      : row { fixed_height = true; alignment = left; : text { label = "ZE2"; width = 4; fixed_width = true; } : el_panel_circuit_swatch { key = "p_color1"; } : text { key = "p_row1"; width = 22; } }
      el_panel_circuit_separator;
      : row { fixed_height = true; alignment = left; : text { label = "ZE3"; width = 4; fixed_width = true; } : el_panel_circuit_swatch { key = "p_color2"; } : text { key = "p_row2"; width = 22; } }
      el_panel_circuit_separator;
      : row { fixed_height = true; alignment = left; : text { label = "ZE4"; width = 4; fixed_width = true; } : el_panel_circuit_swatch { key = "p_color3"; } : text { key = "p_row3"; width = 22; } }
      el_panel_circuit_separator;
      : row { fixed_height = true; alignment = left; : text { label = "ZE5"; width = 4; fixed_width = true; } : el_panel_circuit_swatch { key = "p_color4"; } : text { key = "p_row4"; width = 22; } }
      el_panel_circuit_separator;
      : row { fixed_height = true; alignment = left; : text { label = "ZE6"; width = 4; fixed_width = true; } : el_panel_circuit_swatch { key = "p_color5"; } : text { key = "p_row5"; width = 22; } }
      el_panel_circuit_separator;
      : row { fixed_height = true; alignment = left; : text { label = "ZE7"; width = 4; fixed_width = true; } : el_panel_circuit_swatch { key = "p_color6"; } : text { key = "p_row6"; width = 22; } }
      el_panel_circuit_separator;
      : row { fixed_height = true; alignment = left; : text { label = "ZE8"; width = 4; fixed_width = true; } : el_panel_circuit_swatch { key = "p_color7"; } : text { key = "p_row7"; width = 22; } }
      el_panel_circuit_separator;
      // Date: 2026-10-16. One power summary between the circuit rows and step three.
      : text { key = "p_power_total"; label = "总功率：未统计"; width = 40; fixed_width = true; fixed_height = true; }
      : row { fixed_width = true; fixed_height = true; alignment = left;
        : image { key = "p_step3"; width = 8; height = 1.3; fixed_width = true; fixed_height = true; color = dialog_background; help_string = "第三步：在图面查看全部回路"; }
        : button { key = "f_preview"; label = "在图面查看全部回路"; width = 28; fixed_width = true; }
      }
      : row { fixed_width = true; fixed_height = true; alignment = left;
        : image { key = "p_step4"; width = 8; height = 1.3; fixed_width = true; fixed_height = true; color = dialog_background; help_string = "第四步：生成新系统图"; }
        : button { key = "p_generate"; label = "生成新系统图"; width = 28; fixed_width = true; is_default = true; }
      }
    }

    : button { key = "p_library_toggle"; label = "展开设备库 >>"; width = 46; fixed_width = true; help_string = "展开或收起右侧设备库，保留当前回路与编辑资料"; }
}

el_panel_editor : boxed_column { label = "设备库"; fixed_height = true; alignment = top;
    // Date: 2026-10-16. Device editor above library paths; keep each section together.
    : column { fixed_height = true; alignment = top;
      : row { children_alignment = top;
        : column {
          : edit_box { key = "dl_query"; label = "搜索图块名 / 设备名"; edit_width = 20; }
          : toggle { key = "dl_deleted"; label = "显示已删除"; }
          : list_box { key = "dl_rows"; label = "图块名 / 设备名 / 状态"; width = 34; height = 17; }
          : button { key = "dl_pick"; label = "拾取设备入库"; }
          : row {
            : button { key = "dl_new"; label = "新增"; }
            : button { key = "dl_delete"; label = "删除"; }
            : button { key = "dl_restore"; label = "恢复"; }
          }
          : row {
            : button { key = "dl_refresh"; label = "刷新"; }
            : button { key = "dl_reload"; label = "重载选中项"; }
          }
          : button { key = "dl_directory"; label = "更改库目录"; }
          : button { key = "dl_import"; label = "导入设备库"; help_string = "导入完整设备库的独立副本并切换使用，原库保留"; }
        }
        : column {
          : image { key = "dl_image"; width = 34; height = 7; fixed_width = true; fixed_height = true; color = 0; }
          : text { key = "dl_asset"; width = 38; }
          : edit_box { key = "dl_block"; label = "图块名"; edit_width = 24; }
          : edit_box { key = "dl_aliases"; label = "别名（分号分隔）"; edit_width = 24; }
          : toggle { key = "dl_keep_old"; label = "改名时保留旧名"; value = "1"; }
          : edit_box { key = "dl_display"; label = "设备名"; edit_width = 24; }
          : edit_box { key = "dl_watts"; label = "单个功率（整数 W）"; edit_width = 12; }
          : toggle { key = "dl_zero"; label = "确认此设备为 0W"; }
          : popup_list { key = "dl_ground"; label = "是否地面"; }
          : toggle { key = "dl_active"; label = "启用名称匹配"; value = "1"; }
          : button { key = "dl_export"; label = "导出设备库"; help_string = "导出包含功率、图形和图例的设备库文件夹"; }
          : button { key = "dl_save"; label = "保存设备"; }
        }
      }
      : text { key = "dl_status"; width = 76; fixed_height = true; }
    }
  }

// Date: 2026-10-16. A text receiver keeps the cancel action without a native button frame.
// AutoCAD still renders a minimum frame for a button with a tiny requested size.
el_panel_escape : text {
  key = "cancel"; label = ""; is_cancel = true; is_tab_stop = false;
  width = 0.01; height = 0.01; fixed_width = true; fixed_height = true;
}
el_panel_diagnostics : row { fixed_width = true; fixed_height = true; alignment = top;
    : button { key = "p_diagnostic"; label = "导出诊断日志并打开文件夹"; width = 46; fixed_width = true; }
    el_panel_escape;
  }

el_panel_paths : column {
    : column { fixed_height = true; alignment = top;
      : text { key = "dl_root"; width = 76; fixed_height = true; }
      : row { alignment = left; fixed_height = true;
        : text { label = "功率参数：catalog.eld"; width = 44; fixed_width = true; }
        : button { key = "dl_open"; label = "打开所在文件夹"; width = 24; fixed_width = true; }
      }
      : row { alignment = left; fixed_height = true;
        : text { label = "图块图纸：系统图块库.dwg"; width = 44; fixed_width = true; }
        : button { key = "p_block_library_open"; label = "打开所在文件夹"; width = 24; fixed_width = true; }
      }
      : text { label = "默认功率反馈：点击保存设备并核对成功后，发送 catalog.eld。"; fixed_height = true; }
    }
    : text { label = "点击保存设备后核对上方结果；离开输入框时也会自动保存。"; fixed_height = true; }
  }

el_panel : dialog {
  label = "应急照明：回路核对与设备库";
  : row { children_alignment = top; el_panel_review; el_panel_editor; }
  : image { height = 0.12; fixed_height = true; color = 8; }
  : row { children_alignment = top; el_panel_diagnostics; el_panel_paths; }
}

el_panel_compact : dialog {
  label = "应急照明：回路核对";
  el_panel_review;
  : image { height = 0.12; fixed_height = true; color = 8; }
  el_panel_diagnostics;
}
