#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# ============================================================
# 1. 添加 mwan3 多拨/负载均衡 及其依赖 (暂时注释，以后需要再取消)
# ============================================================
# sed -i '/CONFIG_PACKAGE_luci-app-mwan3/d' .config
# sed -i '/CONFIG_PACKAGE_mwan3/d' .config
# sed -i '/CONFIG_PACKAGE_iptables-mod-conntrack-extra/d' .config
# sed -i '/CONFIG_PACKAGE_iptables-mod-ipopt/d' .config
# sed -i '/CONFIG_PACKAGE_kmod-ipt-conntrack-extra/d' .config
# sed -i '/CONFIG_PACKAGE_kmod-ipt-ipopt/d' .config

# echo "CONFIG_PACKAGE_luci-app-mwan3=y" >> .config
# echo "CONFIG_PACKAGE_mwan3=y" >> .config
# echo "CONFIG_PACKAGE_iptables-mod-conntrack-extra=y" >> .config
# echo "CONFIG_PACKAGE_iptables-mod-ipopt=y" >> .config
# echo "CONFIG_PACKAGE_kmod-ipt-conntrack-extra=y" >> .config
# echo "CONFIG_PACKAGE_kmod-ipt-ipopt=y" >> .config


# ============================================================
# 2. 修复 ssdk_sh 缺失，补全底层工具
# ============================================================

# 强制开启高通 SSDK 包（提供 ssdk_sh 等命令，此源码没有单独的 shell 包）
sed -i '/CONFIG_PACKAGE_qca-ssdk/d' .config
sed -i '/CONFIG_PACKAGE_qca-ssdk-nohnat/d' .config
echo "CONFIG_PACKAGE_qca-ssdk=y" >> .config

# 补全 UBI 工具和内核模块（解决 mount.ubi 相关的潜在依赖）
sed -i '/CONFIG_PACKAGE_ubi-utils/d' .config
sed -i '/CONFIG_PACKAGE_kmod-ubi/d' .config
sed -i '/CONFIG_PACKAGE_kmod-ubiblock/d' .config
echo "CONFIG_PACKAGE_ubi-utils=y" >> .config
echo "CONFIG_PACKAGE_kmod-ubi=y" >> .config
echo "CONFIG_PACKAGE_kmod-ubiblock=y" >> .config


# ============================================================
# 3. 强制确认基础系统包（防止被 make defconfig 裁剪）
# ============================================================

# 基础系统组件
sed -i '/CONFIG_PACKAGE_base-files/d' .config
sed -i '/CONFIG_PACKAGE_busybox/d' .config
sed -i '/CONFIG_PACKAGE_netifd/d' .config
sed -i '/CONFIG_PACKAGE_procd/d' .config
sed -i '/CONFIG_PACKAGE_uci/d' .config
sed -i '/CONFIG_PACKAGE_block-mount/d' .config
sed -i '/CONFIG_PACKAGE_fstools/d' .config

echo "CONFIG_PACKAGE_base-files=y" >> .config
echo "CONFIG_PACKAGE_busybox=y" >> .config
echo "CONFIG_PACKAGE_netifd=y" >> .config
echo "CONFIG_PACKAGE_procd=y" >> .config
echo "CONFIG_PACKAGE_uci=y" >> .config
echo "CONFIG_PACKAGE_block-mount=y" >> .config
echo "CONFIG_PACKAGE_fstools=y" >> .config

# 图形界面基础（确保 LuCI 核心完整）
sed -i '/CONFIG_PACKAGE_luci-base/d' .config
sed -i '/CONFIG_PACKAGE_luci-mod-status/d' .config
sed -i '/CONFIG_PACKAGE_luci-mod-system/d' .config

echo "CONFIG_PACKAGE_luci-base=y" >> .config
echo "CONFIG_PACKAGE_luci-mod-status=y" >> .config
echo "CONFIG_PACKAGE_luci-mod-system=y" >> .config
