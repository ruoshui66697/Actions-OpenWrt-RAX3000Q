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
# 尝试用 git apply --3way 重新打 mac80211 补丁（比 patch 命令更智能）
# ============================================================
cd "$GITHUB_WORKSPACE/openwrt"
# 找到 mac80211 包目录
MAC80211_PATCH_DIR=$(find "$GITHUB_WORKSPACE/openwrt" -path "*/package/kernel/mac80211/patches/all-ipq50xx" -type d 2>/dev/null | head -n 1)
if [ -n "$MAC80211_PATCH_DIR" ]; then
    # 找到对应的 build 目录
    BUILD_DIR=$(find "$GITHUB_WORKSPACE/openwrt/build_dir" -path "*/linux-ipq50xx_arm/backports-20210222-5.4-qsdk-11.5.0.5" -type d 2>/dev/null | head -n 1)
    if [ -n "$BUILD_DIR" ]; then
        cd "$BUILD_DIR"
        # 对每个 patch 文件用 git apply --3way 重试
        for patch_file in "$MAC80211_PATCH_DIR"/*.patch; do
            patch_name=$(basename "$patch_file")
            echo "尝试用 git apply --3way 应用: $patch_name"
            if ! git apply --3way --reject "$patch_file" 2>&1; then
                echo "警告: $patch_name 用 git apply --3way 也失败了，保留 .rej 文件供分析"
            fi
        done
    fi
fi
fi
