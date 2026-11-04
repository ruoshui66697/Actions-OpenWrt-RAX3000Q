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
# 手动修补 ath11k rekey 问题（Python方案）
# 注意：这部分必须在 if 块外面，确保始终执行
# ============================================================

# 1. 删掉原始 945 补丁（防止 patch 工具因 hunk failed 中断编译）
PATCH_FILE="$GITHUB_WORKSPACE/openwrt/package/kernel/mac80211/patches/all-ipq50xx/945-ath11k-fix_group_data_packet_drops_during_rekey.patch"
if [ -f "$PATCH_FILE" ]; then
    rm -f "$PATCH_FILE"
    echo "[DIY] 已移除 945 原始补丁文件"
fi

# 2. 执行 Python 脚本直接修改源码
PYTHON_SCRIPT="$GITHUB_WORKSPACEath11k_rekey_fix_5.4_qsdk.py"
if [ -f "$PYTHON_SCRIPT" ]; then
    python3 "$PYTHON_SCRIPT" \
        --source-dir "$GITHUB_WORKSPACE/openwrt/package/kernel/mac80211/patches/backports-20210222-5.4-qsdk-11.5.0.5"
    if [ $? -eq 0 ]; then
        echo "[DIY] Python 脚本执行成功"
    else
        echo "[DIY] WARNING: Python 脚本执行返回码 $?，部分修改可能未生效"
    fi
else
    echo "[DIY] WARNING: 找不到 $PYTHON_SCRIPT，跳过手动修补"
fi
