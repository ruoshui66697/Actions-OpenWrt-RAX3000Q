#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fix_all_ath11k_rekey.py
整合补丁：
1. mac80211 rx.c：放宽 VHT MCS 校验（解决误丢帧）
2. ath11k dp_rx.c：补充内存屏障（解决 msdu_done 报错）
3. ath11k core.h + mac.c：STA 模式跳过 DISABLE_KEY（解决 GTK 重密钥竞态）

【防呆设计说明】
本脚本采用了强断言（assert）机制。如果上游源码发生变化导致找不到目标代码，
脚本会直接抛出异常并退出，中止整个编译流程。
这样可以绝对防止“静默失败”（即日志看着没报错，但补丁其实没打进去）。
"""

import os
import sys
import argparse
import re

def read_file(path):
    """读取文件内容，忽略编码错误，防止非 UTF-8 字符导致崩溃"""
    with open(path, "r", encoding="utf-8", errors="ignore") as fh:
        return fh.read()

def write_file(path, content):
    """将修改后的内容写回文件"""
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)

def assert_success(condition, msg):
    """
    强断言函数（Fail-Fast）。
    如果 condition 为假，则打印错误信息，并直接退出脚本（退出码 1），中断编译。
    """
    if not condition:
        print(f"\n❌ [FATAL ERROR] {msg}")
        print("❌ 编译已中止，防止产生未打补丁的坏固件！")
        sys.exit(1)
    else:
        print(f"[OK] {msg}")

# ==========================================
# 补丁 1: mac80211 rx.c 放宽 MCS 校验
# ==========================================
def patch_mac80211_rx(sd):
    print("\n[1/3] 正在修补 mac80211/rx.c (放宽 VHT MCS 校验)...")
    path = os.path.join(sd, "net/mac80211/rx.c")
    
    # 校验文件是否存在
    assert_success(os.path.exists(path), f"找到 rx.c 文件: {path}")
    
    c = read_file(path)
    
    # 目标：将原本限制最大 MCS 9 改为 11，允许接收更高阶的 VHT 帧
    old_str = "status->rate_idx > 9"
    new_str = "status->rate_idx > 11"
    
    # 检查是否已经修改过，防止重复打补丁
    if new_str in c:
        print("[OK] rx.c 已经应用过放宽校验，跳过。")
        return
        
    # 精确匹配原代码锚点
    assert_success(old_str in c, f"在 rx.c 中找到锚点 '{old_str}'")
    
    # 执行替换（只替换第一处匹配）
    c = c.replace(old_str, new_str, 1)
    write_file(path, c)
    print("[OK] rx.c: 已将 rate_idx 上限从 9 放宽至 11。")

# ==========================================
# 补丁 2: ath11k dp_rx.c 补充内存屏障
# ==========================================
def patch_ath11k_dp_rx(sd):
    print("\n[2/3] 正在修补 ath11k/dp_rx.c (补充内存屏障)...")
    path = os.path.join(sd, "drivers/net/wireless/ath/ath11k/dp_rx.c")
    
    assert_success(os.path.exists(path), f"找到 dp_rx.c 文件: {path}")
        
    c = read_file(path)
    
    # 检查是否已经包含补丁特征
    if "PATCH_ATH11K_MEM_BARRIER" in c:
        print("[OK] dp_rx.c 已经应用过内存屏障补丁，跳过。")
        return

    # 在获取接收描述符之后，必须加上内存屏障，防止 ARM 弱内存序导致读取到脏数据
    marker = "rx_desc = ath11k_hal_srng_dst_get_next_entry(ab, srng);"
    assert_success(marker in c, "在 dp_rx.c 中找到读取 rx_desc 的锚点")
    
    # 插入 dma_rmb()，并打上我们专属的注释标记
    patch_code = "\n\t/* PATCH_ATH11K_MEM_BARRIER: 解决 AArch64 架构下的 RX 描述符数据竞争 */\n\tdma_rmb();\n"
    c = c.replace(marker, marker + "\n" + patch_code, 1)
    write_file(path, c)
    print("[OK] dp_rx.c: 已插入 dma_rmb() 内存屏障。")

# ==========================================
# 补丁 3: ath11k core.h + mac.c (解决 GTK 重密钥死锁)
# ==========================================
def fix_core_h(sd):
    path = os.path.join(sd, "drivers/net/wireless/ath/ath11k/core.h")
    assert_success(os.path.exists(path), f"找到 core.h 文件: {path}")
    
    c = read_file(path)
    
    # 如果结构体已经包含了我们需要的字段，直接返回
    if "u32 num_stations;" in c and "bool reinstall_group_keys;" in c:
        print("[OK] core.h: 所需字段已存在，跳过。")
        return
        
    # 向 ath11k_vif 结构体中追加两个用于追踪站点的变量
    marker = "struct ath11k_vif {"
    assert_success(marker in c, "在 core.h 中找到结构体 ath11k_vif")
    
    c = c.replace(marker, marker + "\n\tu32 num_stations;\n\tbool reinstall_group_keys;", 1)
    write_file(path, c)
    print("[OK] core.h: 成功添加了 num_stations 和 reinstall_group_keys 字段。")

def fix_mac_c(sd):
    path = os.path.join(sd, "drivers/net/wireless/ath/ath11k/mac.c")
    assert_success(os.path.exists(path), f"找到 mac.c 文件: {path}")
    
    c = read_file(path)

    # --- 1. 添加辅助函数 ath11k_set_group_keys ---
    # 作用：用于在站点接入时，重新下发之前暂存的组密钥
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
    else:
        print("[OK] mac.c: ath11k_set_group_keys 已存在。")

    # --- 2. 添加局部变量 is_ap_with_no_sta ---
    if "bool is_ap_with_no_sta;" not in c:
        marker = "struct ath11k_sta *arsta;"
        assert_success(marker in c, "在 mac.c 中找到 arsta 变量声明处")
        c = c.replace(marker, marker + "\n\tbool is_ap_with_no_sta;", 1)
        print("[OK] mac.c: 添加了 is_ap_with_no_sta 变量。")
    else:
        print("[OK] mac.c: is_ap_with_no_sta 已存在。")

    # --- 3. 核心重写：拦截 STA 模式的 DISABLE_KEY ---
    if "is_ap_with_no_sta = (vif->type == NL80211_IFTYPE_AP" not in c:
        # 这是一段非常长且原汁原味的旧代码，必须一字节不差地匹配
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
        # 这是重写后的新逻辑，加入了条件判断，跳过了 STA 模式的 DISABLE_KEY
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
        print("[OK] mac.c: 成功重写了 set_key 逻辑，已跳过 STA 模式的 DISABLE_KEY。")
    else:
        print("[OK] mac.c: set_key 重写逻辑已存在。")

    # --- 4. 修复站点计数器 (递增) ---
    if "arvif->num_stations++;" not in c:
        marker = "ar->num_stations++;"
        assert_success(marker in c, "找到 num_stations++ 锚点")
        c = c.replace(marker, "ar->num_stations++;\n\tarvif->num_stations++;", 1)
        print("[OK] mac.c: 添加了 vif 级别的递增计数器。")
        
    # --- 5. 修复站点计数器 (递减) ---
    if c.count("arvif->num_stations--;") < c.count("ar->num_stations--;"):
        marker = "ar->num_stations--;"
        assert_success(marker in c, "找到 num_stations-- 锚点")
        c = c.replace(marker, "ar->num_stations--;\n\tarvif->num_stations--;", 1)
        print("[OK] mac.c: 添加了 vif 级别的递减计数器。")

    # --- 6. 在站点接入时恢复群组密钥 ---
    if "reinstall_group_keys = false;" not in c:
        marker = "arsta->rx_stats = kzalloc"
        assert_success(marker in c, "在 station_add 中找到 rx_stats 分配锚点")
        
        # 在该行之前插入重装逻辑
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

    # 最后统一写回文件
    write_file(path, c)


def main():
    # 解析命令行参数（由 YML 传入源码目录）
    p = argparse.ArgumentParser()
    p.add_argument("--source-dir", required=True, help="Path to backports source directory")
    args = p.parse_args()
    sd = args.source_dir

    print(f"Source Directory: {sd}")
    print("=" * 60)
    
    # 检查源码目录是否存在
    if not os.path.exists(sd):
        print(f"❌ [FATAL] 找不到源码目录: {sd}")
        sys.exit(1)

    # 依次执行三个补丁流程
    patch_mac80211_rx(sd)
    patch_ath11k_dp_rx(sd)
    
    print("\n[3/3] 正在修补 ath11k/core.h 和 mac.c...")
    fix_core_h(sd)
    fix_mac_c(sd)

    print("=" * 60)
    print("[SUCCESS] 所有补丁完美应用！交由后续编译流程检查。")
    
    # 正常退出，让 YML 继续往下走
    sys.exit(0)

if __name__ == "__main__":
    main()
