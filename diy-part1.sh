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
    # ============================================================
# 手动修补 ath11k rekey 问题（Python方案）
# ============================================================
# 先删掉原始 945 补丁（防止 patch 工具报错中断编译）
rm -f "$GITHUB_WORKSPACE/openwrt/package/kernel/mac80211/patches/all-ipq50xx/945-ath11k-fix_group_data_packet_drops_during_rekey.patch"

# 执行 Python 脚本直接修改源码
python3 "$GITHUB_WORKSPACEath11k_rekey_fix_5.4_qsdk.py" \
    --source-dir "$GITHUB_WORKSPACE/openwrt/package/kernel/mac80211/patches/backports-20210222-5.4-qsdk-11.5.0.5"
fi

