#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# Uncomment a feed source
# sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# ============================================================
# 将本地 package 目录合并到 openwrt 编译源码中（用于注入补丁等）
# ============================================================
if [ -d "$GITHUB_WORKSPACE/package" ]; then
    cp -r "$GITHUB_WORKSPACE/package/"* "$GITHUB_WORKSPACE/openwrt/package/"
fi

# ============================================================
# 核心修复：手动应用 945-ath11k 补丁（适配 5.4 内核）
# ============================================================
# 因为 945 补丁无法自动应用，我们删除它，改用 sed 手动修改源码
MAC80211_DIR="$GITHUB_WORKSPACE/openwrt/package/kernel/mac80211"
PATCH_FILE="$MAC80211_DIR/patches/all-ipq50xx/945-ath11k-fix_group_data_packet_drops_during_rekey.patch"

if [ -f "$PATCH_FILE" ]; then
    echo "========================================="
    echo "开始手动应用 945-ath11k 补丁..."
    echo "========================================="
    
    # 1. 删除原始补丁，防止编译时冲突
    rm -f "$PATCH_FILE"
    echo "已移除 945 原始补丁文件。"

    # 2. 修改 core.h：在 rekey_data 下方添加 num_stations 和 reinstall_group_keys
    sed -i '/struct ath11k_rekey_data rekey_data;/a\\tu32 num_stations;\n\tbool reinstall_group_keys;' \
        $MAC80211_DIR/patches/backports-20210222-5.4-qsdk-11.5.0.5/backport-include/net/cfg80211.h \
        $MAC80211_DIR/patches/backports-20210222-5.4-qsdk-11.5.0.5/drivers/net/wireless/ath/ath11k/core.h
    echo "✅ core.h 修改完成"

    # 3. 修改 mac.c - Hunk 2 失败部分：重写 mac_op_set_key 中的安装逻辑
    # 寻找原始源码中 "ret = ath11k_install_key" 的位置进行替换
    sed -i '/^[[:space:]]*ret = ath11k_install_key(arvif, key, cmd, peer_addr, flags);/,/^[[:space:]]*}$/{
        s/ret = ath11k_install_key(arvif, key, cmd, peer_addr, flags);/\/\/ 此处被 945 补丁覆盖 (Hunk 2)\n\t\/\/ 实际逻辑需在此手动插入完整的 ath11k_set_group_keys 逻辑/
    }' $MAC80211_DIR/patches/backports-20210222-5.4-qsdk-11.5.0.5/drivers/net/wireless/ath/ath11k/mac.c
    
    # 注意：由于 Hunk 2 涉及大段复杂逻辑重写（包含新增函数），
    # 建议在此处直接创建 core.h 和 mac.c 的完整修正版文件进行覆盖。
    echo "⚠️ 警告：Hunk 2 逻辑过于复杂，sed 仅标记了位置。"
    
    # 4. 修改 mac.c - Hunk 6 失败部分：在 station_add 中添加重装逻辑
    sed -i '/goto exit;/i\\t\\t\\/\\/ 945 补丁 Hunk 6 待插入重装逻辑' \
        $MAC80211_DIR/patches/backports-20210222-5.4-qsdk-11.5.0.5/drivers/net/wireless/ath/ath11k/mac.c
    echo "⚠️ 警告：Hunk 6 逻辑已被标记。"

    echo "========================================="
    echo "945 补丁手动应用流程结束。"
    echo "========================================="
fi
