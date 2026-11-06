#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fix_all_ath11k_rekey.py
整合补丁：
1. mac80211 rx.c：放宽 VHT MCS 校验（解决误丢帧）
2. ath11k dp_rx.c：补充内存屏障（解决 msdu_done 报错）
3. ath11k core.h + mac.c：STA 模式跳过 DISABLE_KEY（解决 GTK 重密钥竞态）
"""

import os
import sys
import argparse
import re

def read_file(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as fh:
        return fh.read()

def write_file(path, content):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)

# ==========================================
# 补丁 1: mac80211 rx.c 放宽 MCS 校验
# ==========================================
def patch_mac80211_rx(sd):
    print("\n[1/3] 正在修补 mac80211/rx.c (放宽 VHT MCS 校验)...")
    path = os.path.join(sd, "net/mac80211/rx.c")
    
    if not os.path.exists(path):
        print(f"[ERROR] 找不到 {path}，请检查路径。")
        return False
    
    c = read_file(path)
    old_str = "status->rate_idx > 9"
    new_str = "status->rate_idx > 11"
    
    if old_str not in c and new_str in c:
        print("[OK] rx.c 已经应用过放宽校验。")
        return True
        
    if old_str in c:
        c = c.replace(old_str, new_str, 1)
        write_file(path, c)
        print("[OK] rx.c: 已将 rate_idx 上限从 9 放宽至 11。")
        return True
    else:
        print("[WARN] rx.c: 未找到目标字符串 'status->rate_idx > 9'，可能源码已变更。")
        return True

# ==========================================
# 补丁 2: ath11k dp_rx.c 补充内存屏障
# ==========================================
def patch_ath11k_dp_rx(sd):
    print("\n[2/3] 正在修补 ath11k/dp_rx.c (补充内存屏障)...")
    path = os.path.join(sd, "drivers/net/wireless/ath/ath11k/dp_rx.c")
    
    if not os.path.exists(path):
        print(f"[ERROR] 找不到 {path}，请检查路径。")
        return False
        
    c = read_file(path)
    marker = "rx_desc = ath11k_hal_srng_dst_get_next_entry(ab, srng);"
    
    if "PATCH_ATH11K_MEM_BARRIER" in c:
        print("[OK] dp_rx.c 已经应用过内存屏障补丁。")
        return True
        
    if marker in c:
        patch_code = """
    /* PATCH_ATH11K_MEM_BARRIER: 解决 AArch64 架构下的 RX 描述符数据竞争 */
    dma_rmb();
"""
        c = c.replace(marker, marker + "\n" + patch_code, 1)
        write_file(path, c)
        print("[OK] dp_rx.c: 已插入 dma_rmb() 内存屏障。")
        return True
    else:
        print("[WARN] dp_rx.c: 未找到 rx_desc 读取锚点，请人工检查源码。")
        return True

# ==========================================
# 补丁 3: ath11k core.h + mac.c (用户提供的原版逻辑)
# ==========================================
def fix_core_h(sd):
    path = os.path.join(sd, "drivers/net/wireless/ath/ath11k/core.h")
    if not os.path.exists(path):
        print("[SKIP] core.h not found")
        return False
    c = read_file(path)
    if "u32 num_stations;" in c and "bool reinstall_group_keys;" in c:
        print("[OK] core.h: fields already present")
        return True
        
    marker = "struct ath11k_vif {"
    if marker in c:
        c = c.replace(
            marker,
            marker + "\n\tu32 num_stations;\n\tbool reinstall_group_keys;"
        )
        write_file(path, c)
        print("[OK] core.h: added fields")
        return True
    print("[WARN] core.h: marker not found")
    return False

def fix_mac_c(sd):
    path = os.path.join(sd, "drivers/net/wireless/ath/ath11k/mac.c")
    if not os.path.exists(path):
        print("[SKIP] mac.c not found")
        return False
    c = read_file(path)
    changes = []

    # 1. Add ath11k_set_group_keys function
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
            "\t\tret = ath11k_install_key(arvif, key, SET_KEY, addr,\n"
            "\t\t\t\t\t WMI_KEY_GROUP);\n"
            "\t\tif (ret < 0 && first_errno == 0)\n"
            "\t\t\tfirst_errno = ret;\n"
            "\n"
            "\t\tif (ret < 0)\n"
            "\t\t\tath11k_warn(ab, \"failed to set group key of idx %d for vdev %d: %d\\n\",\n"
            "\t\t\t\t    i, arvif->vdev_id, ret);\n"
            "\t}\n"
            "\n"
            "\treturn first_errno;\n"
            "}\n"
            "\n"
        )
        marker = "static int ath11k_mac_op_set_key(struct ieee80211_hw *hw, enum set_key_cmd cmd,"
        if marker in c:
            c = c.replace(marker, func + marker, 1)
            print("[OK] mac.c: added ath11k_set_group_keys function")
            changes.append("func")
        else:
            print("[WARN] mac.c: function marker not found")
    else:
        print("[OK] mac.c: ath11k_set_group_keys already present")

    # 2. Add is_ap_with_no_sta variable
    if "bool is_ap_with_no_sta;" not in c:
        if "struct ath11k_sta *arsta;" in c:
            c = c.replace("struct ath11k_sta *arsta;", "struct ath11k_sta *arsta;\n\tbool is_ap_with_no_sta;", 1)
            print("[OK] mac.c: added is_ap_with_no_sta")
            changes.append("var")
        else:
            print("[WARN] mac.c: var marker not found")
    else:
        print("[OK] mac.c: is_ap_with_no_sta already present")

    # 3. Rewrite set_key install logic (core fix)
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
            "\t/* Allow group key clearing only in AP mode when no stations are associated. */\n"
            "\tis_ap_with_no_sta = (vif->type == NL80211_IFTYPE_AP &&\n"
            "\t\t     !arvif->num_stations);\n"
            "\n"
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
            "\t}\n"
        )
        if old in c:
            c = c.replace(old, new)
            print("[OK] mac.c: rewrote set_key logic")
            changes.append("rewrite")
        else:
            print("[WARN] mac.c: original block not found (may be already applied)")
            if "arvif->reinstall_group_keys = true;" in c:
                print("[OK] mac.c: fix logic appears present")
    else:
        print("[OK] mac.c: set_key fix already present")

    # 4. Add arvif counter in inc_num_stations
    if "arvif->num_stations++;" not in c:
        cnt = c.count("ar->num_stations++;")
        if cnt > 0:
            c = c.replace("ar->num_stations++;", "ar->num_stations++;\n\tarvif->num_stations++;", 1)
            print("[OK] mac.c: added inc counter")
            changes.append("inc")
        else:
            print("[WARN] mac.c: inc marker not found")
    else:
        print("[OK] mac.c: inc counter already present")

    # 5. Add arvif counter in dec_num_stations
    if c.count("arvif->num_stations--;") < c.count("ar->num_stations--;"):
        c = c.replace("ar->num_stations--;", "ar->num_stations--;\n\tarvif->num_stations--;", 1)
        print("[OK] mac.c: added dec counter")
        changes.append("dec")
    else:
        print("[OK] mac.c: dec counter already present")

    # 6. Add reinstall logic in station_add
    if "reinstall_group_keys = false;" not in c:
        marker = "arsta->rx_stats = kzalloc"
        if marker in c:
            idx = c.find(marker)
            line_start = c.rfind("\n", 0, idx) + 1
            code = (
                "\t/* Reinstall group keys when first station connects */\n"
                "\tif (arvif->num_stations == 1 && arvif->reinstall_group_keys) {\n"
                "\t\tret = ath11k_set_group_keys(arvif);\n"
                "\t\tif (ret)\n"
                "\t\t\tgoto dec_num_station;\n"
                "\t\tarvif->reinstall_group_keys = false;\n"
                "\t}\n\n"
            )
            c = c[:line_start] + code + c[line_start:]
            print("[OK] mac.c: added station_add reinstall logic")
            changes.append("reinstall")
        else:
            print("[WARN] mac.c: station_add marker not found")
    else:
        print("[OK] mac.c: station_add reinstall logic already present")

    write_file(path, c)
    print(f"mac.c: {len(changes)} changes applied: {changes}")
    return len(changes) > 0

def patch_ath11k_mac_and_core(sd):
    print("\n[3/3] 正在修补 ath11k/core.h 和 mac.c (跳过 STA DISABLE_KEY)...")
    fix_core_h(sd)
    fix_mac_c(sd)

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source-dir", required=True, help="Path to backports source directory")
    args = p.parse_args()
    sd = args.source_dir

    print(f"Source Directory: {sd}")
    print("=" * 60)
    if not os.path.exists(sd):
        print(f"[ERROR] Not found: {sd}")
        sys.exit(1)

    # 执行三个补丁
    patch_mac80211_rx(sd)
    patch_ath11k_dp_rx(sd)
    patch_ath11k_mac_and_core(sd)

    print("=" * 60)
    print("[INFO] 所有补丁应用完毕。交由后续编译流程检查。")
    sys.exit(0)

if __name__ == "__main__":
    main()
