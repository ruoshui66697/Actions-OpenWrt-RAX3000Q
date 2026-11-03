
#!/usr/bin/env python3
"""ath11k rekey fix for 5.4 QSDK - 直接修改源码"""

import os, sys, argparse

def read_file(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as fh:
        return fh.read()

def write_file(path, content):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)

def fix_core_h(sd):
    path = os.path.join(sd, "drivers/net/wireless/ath/ath11k/core.h")
    if not os.path.exists(path):
        print(f"[SKIP] core.h not found"); return False
    c = read_file(path)
    if "u32 num_stations;" in c and "bool reinstall_group_keys;" in c:
        print("[OK] core.h: fields already present"); return True
    if "struct ath11k_rekey_data rekey_data;" in c:
        c = c.replace(
            "struct ath11k_rekey_data rekey_data;",
            "struct ath11k_rekey_data rekey_data;\n\tu32 num_stations;\n\tbool reinstall_group_keys;"
        )
        write_file(path, c)
        print("[OK] core.h: added fields"); return True
    print("[WARN] core.h: marker not found"); return False

def fix_mac_c(sd):
    path = os.path.join(sd, "drivers/net/wireless/ath/ath11k/mac.c")
    if not os.path.exists(path):
        print(f"[SKIP] mac.c not found"); return False
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
        marker = '\\tarsta->rx_stats = kzalloc(sizeof(*arsta->rx_stats), GFP_KERNEL);'
        if marker in c:
            code = (
                "\t/* Driver allows the DEL KEY followed by SET KEY sequence for\n"
                "\t * group keys for only when there is no clients associated, if at\n"
                "\t * all firmware has entered the race during that window,\n"
                "\t * reinstalling the same key when the first sta connects will allow\n"
                "\t * firmware to recover from the race.\n"
                "\t */\n"
                "\tif (arvif->num_stations == 1 && arvif->reinstall_group_keys) {\n"
                "\t\tath11k_dbg(ab, ATH11K_DBG_MAC, \"set group keys on 1st station add for vdev %d\\n\",\n"
                "\t\t   arvif->vdev_id);\n"
                "\t\tret = ath11k_set_group_keys(arvif);\n"
                "\t\tif (ret)\n"
                "\t\t\tgoto dec_num_station;\n"
                "\t\tarvif->reinstall_group_keys = false;\n"
                "\t}\n"
                "\n"
            )
            c = c.replace(marker, code + marker)
            print("[OK] mac.c: added station_add reinstall logic")
            changes.append("reinstall")
        else:
            print("[WARN] mac.c: station_add marker not found")
    else:
        print("[OK] mac.c: station_add reinstall logic already present")

    write_file(path, c)
    print(f"\n[SUMMARY] mac.c: {len(changes)} changes: {changes}")
    return len(changes) > 0

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source-dir", required=True)
    args = p.parse_args()
    sd = args.source_dir
    print(f"Source: {sd}")
    print("=" * 60)
    if not os.path.exists(sd):
        print(f"[ERROR] Not found: {sd}"); sys.exit(1)
    r1 = fix_core_h(sd)
    print()
    r2 = fix_mac_c(sd)
    print("=" * 60)
    if r1 and r2:
        print("[SUCCESS] All changes applied"); sys.exit(0)
    elif r1 or r2:
        print("[WARNING] Partial"); sys.exit(1)
    else:
        print("[FAILURE] None applied"); sys.exit(2)

if __name__ == "__main__":
    main()
