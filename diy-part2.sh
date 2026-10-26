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
# 添加 mwan3 多拨/负载均衡
sed -i '/CONFIG_PACKAGE_luci-app-mwan3/d' .config
sed -i '/CONFIG_PACKAGE_mwan3/d' .config
sed -i '/CONFIG_PACKAGE_iptables-mod-conntrack-extra/d' .config
sed -i '/CONFIG_PACKAGE_iptables-mod-ipopt/d' .config
sed -i '/CONFIG_PACKAGE_kmod-ipt-conntrack-extra/d' .config
sed -i '/CONFIG_PACKAGE_kmod-ipt-ipopt/d' .config

echo "CONFIG_PACKAGE_luci-app-mwan3=y" >> .config
echo "CONFIG_PACKAGE_mwan3=y" >> .config
echo "CONFIG_PACKAGE_iptables-mod-conntrack-extra=y" >> .config
echo "CONFIG_PACKAGE_iptables-mod-ipopt=y" >> .config
echo "CONFIG_PACKAGE_kmod-ipt-conntrack-extra=y" >> .config
echo "CONFIG_PACKAGE_kmod-ipt-ipopt=y" >> .config

# ============================================================
# 补全底层工具（ssdk_sh, mount.ubi）及其依赖
# ============================================================

# 1. 高通交换机配置工具 ssdk_sh
# 包名来自 nss-packages feed，IPQ50xx 已支持
echo "CONFIG_PACKAGE_qca-ssdk-shell=y" >> .config

# 2. UBI 管理工具，提供 mount.ubi 及 ubiattach/ubidetach 等命令
echo "CONFIG_PACKAGE_ubi-utils=y" >> .config

# 3. block-mount 及其运行依赖，确保 block 命令和挂载逻辑完整
# block-mount 依赖 ubox（提供 ubusd/ubus）、libuci、fstools
echo "CONFIG_PACKAGE_block-mount=y" >> .config
echo "CONFIG_PACKAGE_ubox=y" >> .config
echo "CONFIG_PACKAGE_ubus=y" >> .config
echo "CONFIG_PACKAGE_ubusd=y" >> .config
echo "CONFIG_PACKAGE_libuci=y" >> .config
echo "CONFIG_PACKAGE_fstools=y" >> .config

# 4. 显式启用内核 UBI 块设备支持（mount.ubi 运行的前提）
echo "CONFIG_PACKAGE_kmod-ubiblock=y" >> .config
echo "CONFIG_PACKAGE_kmod-ubi=y" >> .config
