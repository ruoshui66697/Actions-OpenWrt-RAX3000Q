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
