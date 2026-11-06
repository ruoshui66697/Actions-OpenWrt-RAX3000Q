#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import sys
import argparse

def read_file(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as fh:
        return fh.read()

def write_file(path, content):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)
    # 【核心】：写入后立刻刷新这个文件的时间戳，防止被系统覆盖
    os.utime(path, None)

def assert_success(condition, msg):
    if not condition:
        print(f"\n❌ [FATAL ERROR] {msg}")
        sys.exit(1)
    else:
        print(f"[OK] {msg}")

def fix_core_h(sd):
    print("\n[1/2] 正在修补 ath11k/core.h...")
    path = os.path.join(sd, "drivers/net/wireless/ath/ath11k/core.h")
    assert_success(os.path.exists(path), f"找到 core.h 文件")
    
    c = read_file(path)
    if "u32 num_stations;" in c and "bool reinstall_group_keys;" in c:
        print("[OK] core.h: 字段已存在，跳过。")
        os.utime(path, None)
        return
        
    marker = "struct ath11k_vif {"
    assert_success(marker in c, "在 core.h 中找到结构体 ath11k_vif")
    c = c.replace(marker, marker + "\n\tu32 num_stations;\n\tbool reinstall_group_keys;", 1)
    write_file(path, c)
    print("[OK] core.h: 成功添加所需字段。")

def fix_mac_c(sd):
    print("\n[2/2] 正在修补 ath11k/mac.c...")
    path = os.path.join(sd, "drivers/net/wireless/ath/ath11k/mac.c")
    assert_success(os.path.exists(path), f"找到 mac.c 文件")
    c = read_file(path)

    # 1. 添加辅助函数
    if "ath11k_set_group_keys" not in c:
        func = (
            "static int ath11k_set_group_keys(struct ath11k_vif *arvif)\n"
            "{\n"
            "\tstruct ath11k *ar = arvif->ar;\n"
            "\tstruct ath11k_base *ab = ar->ab;\n"
            "\tconst u8 *addr = arvif->bssid;\n"
            "\tint i, ret, first_errno = 0;\n"
            "\tstruct ath11k_peer *peer;\n"
            "\n"
            "\tspin_lock_bh(&ab->base_lock);\n"
            "\tpeer = ath11k_peer_find(ab, arvif->vdev_id, addr);\n"
            "\tspin_unlock_bh(&ab->base_lock);\n"
            "\n"
            "\tif (!peer)\n"
            "\t\treturn -ENOENT;\n"
            "\n"
            "\tfor (i = 0; i < ARRAY_SIZE(peer->keys); i++) {\n"
            "\t\tstruct ieee80211_key_conf *key = peer->keys[i];\n"
            "\n"
            "\t\tif (!key || (key->flags & IEEE80211_KEY_FLAG_PAIRWISE))\n"
            "\t\t\tcontinue;\n"
            "\n"
            "\t\tret = ath11k_install_key(arvif, key, SET_KEY, addr, WMI_KEY_GROUP);\n"
            "\t\tif (ret < 0 && first_errno == 0)\n"
            "\t\t\tfirst_errno = ret;\n"
            "\n"
            "\t\tif (ret < 0)\n"
            "\t\t\tath11k_warn(ab, \"failed to set group key of idx %d for vdev %d: %d\\n\", i, arvif->vdev_id, ret);\n"
            "\t}\n"
            "\n"
            "\treturn first_errno;\n"
            "}\n\n"
        )
        marker = "static int ath11k_mac_op_set_key(struct ieee80211_hw *hw, enum set_key_cmd cmd,"
        assert_success(marker in c, "在 mac.c 中找到 ath11k_mac_op_set_key 函数签名")
        c = c.replace(marker, func + marker, 1)
        print("[OK] mac.c: 添加了 ath11k_set_group_keys 辅助函数。")

    # 2. 添加变量
    if "bool is_ap_with_no_sta;" not in c:
        marker = "struct ath11k_sta *arsta;"
        assert_success(marker in c, "在 mac.c 中找到 arsta 变量声明处")
        c = c.replace(marker, marker + "\n\tbool is_ap_with_no_sta;", 1)
        print("[OK] mac.c: 添加了 is_ap_with_no_sta 变量。")

    # 3. 核心重写
    if "is_ap_with_no_sta = (vif->type == NL80211_IFTYPE_AP" not in c:
        old = (
            "\tret = ath11k_install_key(arvif, key, cmd, peer_addr, flags);\n"
            "\tif (ret) {\n"
            "\t\tath11k_warn(ab, \"ath11k_install_key failed (%d)\\n\", ret);\n"
            "\t\tgoto exit;\n"
            "\t}\n"
            "\n"
            "\tret = ath11k_dp_peer_rx_pn_replay_config(arvif, peer_addr, cmd, key);\n"
            "\tif (ret) {\n"
            "\t\tath11k_warn(ab, \"failed to offload PN replay detection %d\\n\", ret);\n"
            "\t\tgoto exit;\n"
            "\t}"
        )
        new = (
            "\tath11k_dbg(ar->ab, ATH11K_DBG_MAC,\n"
            "\t\t   \"%s for peer %pM on vdev %d flags 0x%X, type = %d, num_sta %d\\n\",\n"
            "\t\t   cmd == SET_KEY ? \"SET_KEY\" : \"DEL_KEY\", peer_addr, arvif->vdev_id,\n"
            "\t\t   flags, arvif->vdev_type, arvif->num_stations);\n"
            "\n"
            "\t/* 仅允许在 AP 模式且没有站点关联时才清除群组密钥 */\n"
            "\tis_ap_with_no_sta = (vif->type == NL80211_IFTYPE_AP && !arvif->num_stations);\n"
            "\n"
            "\t/* 如果是组密钥、且是 SET_KEY，或者满足上述 AP 条件，才真正下发 WMI 命令 */\n"
            "\tif ((flags & WMI_KEY_PAIRWISE) || cmd == SET_KEY || is_ap_with_no_sta) {\n"
            "\t\tret = ath11k_install_key(arvif, key, cmd, peer_addr, flags);\n"
            "\t\tif (ret) {\n"
            "\t\t\tath11k_warn(ab, \"ath11k_install_key failed (%d)\\n\", ret);\n"
            "\t\t\tgoto exit;\n"
            "\t\t}\n"
            "\n"
            "\t\tret = ath11k_dp_peer_rx_pn_replay_config(arvif, peer_addr, cmd, key);\n"
            "\t\tif (ret) {\n"
            "\t\t\tath11k_warn(ab, \"failed to offload PN replay detection %d\\n\", ret);\n"
            "\t\t\tgoto exit;\n"
            "\t\t}\n"
            "\n"
            "\t\tif ((flags & WMI_KEY_GROUP) && cmd == SET_KEY && is_ap_with_no_sta)\n"
            "\t\t\tarvif->reinstall_group_keys = true;\n"
            "\t}"
        )
        
        assert_success(old in c, "在 mac.c 中精确匹配到了要替换的密钥安装代码块")
        c = c.replace(old, new)
        print("[OK] mac.c: 成功重写了 set_key 逻辑。")

    # 4. 计数器
    if "arvif->num_stations++;" not in c:
        marker = "ar->num_stations++;"
        assert_success(marker in c, "找到 num_stations++ 锚点")
        c = c.replace(marker, "ar->num_stations++;\n\tarvif->num_stations++;", 1)
        print("[OK] mac.c: 添加了 vif 级别的递增计数器。")
        
    if c.count("arvif->num_stations--;") < c.count("ar->num_stations--;"):
        marker = "ar->num_stations--;"
        assert_success(marker in c, "找到 num_stations-- 锚点")
        c = c.replace(marker, "ar->num_stations--;\n\tarvif->num_stations--;", 1)
        print("[OK] mac.c: 添加了 vif 级别的递减计数器。")

    # 5. 密钥重装
    if "reinstall_group_keys = false;" not in c:
        marker = "arsta->rx_stats = kzalloc"
        assert_success(marker in c, "在 station_add 中找到 rx_stats 分配锚点")
        idx = c.find(marker)
        line_start = c.rfind("\n", 0, idx) + 1
        code = (
            "\t/* 当第一个站点接入，且标记了需重装群组密钥时执行 */\n"
            "\tif (arvif->num_stations == 1 && arvif->reinstall_group_keys) {\n"
            "\t\tret = ath11k_set_group_keys(arvif);\n"
            "\t\tif (ret)\n"
            "\t\t\tgoto dec_num_station;\n"
            "\t\tarvif->reinstall_group_keys = false;\n"
            "\t}\n\n"
        )
        c = c[:line_start] + code + c[line_start:]
        print("[OK] mac.c: 添加了站点接入时的密钥重装逻辑。")

    write_file(path, c)

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source-dir", required=True)
    args = p.parse_args()
    sd = args.source_dir

    print(f"Source Directory: {sd}")
    print("=" * 60)
    
    if not os.path.exists(sd):
        print(f"❌ [FATAL] 找不到源码目录: {sd}")
        sys.exit(1)

    fix_core_h(sd)
    fix_mac_c(sd)

    print("=" * 60)
    print("[SUCCESS] 992 补丁完美应用！时间戳已安全刷新。")
    sys.exit(0)

if __name__ == "__main__":
    main()
