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
