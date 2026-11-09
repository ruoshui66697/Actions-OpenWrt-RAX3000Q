#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#



# ============================================================
# 1. mwan3 (保持注释)
# ============================================================

# ============================================================
# 2. 修改默认 LAN 口 IP
# ============================================================
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# ============================================================
# 3. 强制确认基础系统包
# ============================================================
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

sed -i '/CONFIG_PACKAGE_luci-base/d' .config
sed -i '/CONFIG_PACKAGE_luci-mod-status/d' .config
sed -i '/CONFIG_PACKAGE_luci-mod-system/d' .config

echo "CONFIG_PACKAGE_luci-base=y" >> .config
echo "CONFIG_PACKAGE_luci-mod-status=y" >> .config
echo "CONFIG_PACKAGE_luci-mod-system=y" >> .config

# ============================================================
# 4. 自动精简插件并添加 SmartDNS
# ============================================================
# 强制排除 frpc
sed -i '/CONFIG_PACKAGE_luci-app-frpc/d' .config
sed -i '/CONFIG_PACKAGE_frpc/d' .config
sed -i '/CONFIG_PACKAGE_luci-i18n-frpc/d' .config
echo "# CONFIG_PACKAGE_luci-app-frpc is not set" >> .config
echo "# CONFIG_PACKAGE_frpc is not set" >> .config
echo "# CONFIG_PACKAGE_luci-i18n-frpc is not set" >> .config

# 强制排除 xlnetacc
sed -i '/CONFIG_PACKAGE_luci-app-xlnetacc/d' .config
sed -i '/CONFIG_PACKAGE_luci-i18n-xlnetacc/d' .config
echo "# CONFIG_PACKAGE_luci-app-xlnetacc is not set" >> .config
echo "# CONFIG_PACKAGE_luci-i18n-xlnetacc is not set" >> .config

# 强制排除 natmap
sed -i '/CONFIG_PACKAGE_luci-app-natmap/d' .config
sed -i '/CONFIG_PACKAGE_natmap/d' .config
sed -i '/CONFIG_PACKAGE_luci-i18n-natmap/d' .config
echo "# CONFIG_PACKAGE_luci-app-natmap is not set" >> .config
echo "# CONFIG_PACKAGE_natmap is not set" >> .config
echo "# CONFIG_PACKAGE_luci-i18n-natmap is not set" >> .config

# 强制排除 ddns-go (之前脚本里漏掉的)
sed -i '/CONFIG_PACKAGE_luci-app-ddns-go/d' .config
sed -i '/CONFIG_PACKAGE_ddns-go/d' .config
sed -i '/CONFIG_PACKAGE_luci-i18n-ddns-go/d' .config
echo "# CONFIG_PACKAGE_luci-app-ddns-go is not set" >> .config
echo "# CONFIG_PACKAGE_ddns-go is not set" >> .config
echo "# CONFIG_PACKAGE_luci-i18n-ddns-go is not set" >> .config

# 添加 SmartDNS
echo "CONFIG_PACKAGE_smartdns=y" >> .config
echo "CONFIG_PACKAGE_luci-app-smartdns=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-smartdns-zh-cn=y" >> .config

# ============================================================
# 开启 ath11k 的 debugfs 和 tracing 支持，方便后续排查
# 回退：删除这三行即可
# ============================================================

echo "========================================="
echo "脚本执行完毕，开始编译。"
echo "========================================="
