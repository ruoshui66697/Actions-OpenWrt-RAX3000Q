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

# ============================================================
# 4. 自动精简插件并添加 SmartDNS
# ============================================================

# 移除 Frp、迅雷快鸟(xlnetacc)、natmap 相关的所有配置
sed -i '/CONFIG_PACKAGE_luci-app-frpc/d' .config
sed -i '/CONFIG_PACKAGE_frpc/d' .config
sed -i '/CONFIG_PACKAGE_luci-i18n-frpc/d' .config

sed -i '/CONFIG_PACKAGE_luci-app-xlnetacc/d' .config
sed -i '/CONFIG_PACKAGE_luci-i18n-xlnetacc/d' .config

sed -i '/CONFIG_PACKAGE_luci-app-natmap/d' .config
sed -i '/CONFIG_PACKAGE_natmap/d' .config
sed -i '/CONFIG_PACKAGE_luci-i18n-natmap/d' .config

# 强制添加 SmartDNS 及其 UI、中文包
echo "CONFIG_PACKAGE_smartdns=y" >> .config
echo "CONFIG_PACKAGE_luci-app-smartdns=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-smartdns-zh-cn=y" >> .config
