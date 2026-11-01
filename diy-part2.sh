#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#

# ============================================================
# 0. 启用 autocore-arm
# ============================================================
sed -i '/CONFIG_PACKAGE_autocore-arm/d' .config
echo "CONFIG_PACKAGE_autocore-arm=y" >> .config

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
sed -i '/CONFIG_PACKAGE_luci-app-frpc/d' .config
sed -i '/CONFIG_PACKAGE_frpc/d' .config
sed -i '/CONFIG_PACKAGE_luci-i18n-frpc/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-xlnetacc/d' .config
sed -i '/CONFIG_PACKAGE_luci-i18n-xlnetacc/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-natmap/d' .config
sed -i '/CONFIG_PACKAGE_natmap/d' .config
sed -i '/CONFIG_PACKAGE_luci-i18n-natmap/d' .config

echo "CONFIG_PACKAGE_smartdns=y" >> .config
echo "CONFIG_PACKAGE_luci-app-smartdns=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-smartdns-zh-cn=y" >> .config

# ============================================================
# 5. 添加 CPU 频率调节
# ============================================================
if [ ! -d "feeds/luci/applications/luci-app-cpufreq" ]; then
    git clone --depth=1 https://github.com/immortalwrt/luci.git /tmp/luci-cpufreq
    cp -r /tmp/luci-cpufreq/applications/luci-app-cpufreq feeds/luci/applications/
    rm -rf /tmp/luci-cpufreq
fi
sed -i '/CONFIG_PACKAGE_luci-app-cpufreq/d' .config
sed -i '/CONFIG_PACKAGE_luci-i18n-cpufreq/d' .config
echo "CONFIG_PACKAGE_luci-app-cpufreq=y" >> .config
[ -d "files/etc/hotplug.d/button" ] && chmod +x files/etc/hotplug.d/button/*
echo "CONFIG_PACKAGE_luci-i18n-cpufreq-zh-cn=y" >> .config

# ============================================================
# 6. 【彻底终结 cpuinfo 冲突】拆掉 base-files，全权交给 autocore 安装
# ============================================================
# 6.1 把我们想要的脚本内容定义好
CPUINFO_SCRIPT='#!/bin/sh
ARCH=$(grep "Processor" /proc/cpuinfo | head -n1 | cut -d: -f2 | sed "s/^ *//")
CORES=$(grep -c "^processor" /proc/cpuinfo)
FREQ_PATH="/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
F1=$(cat "$FREQ_PATH" 2>/dev/null)
if [ -n "$F1" ] && [ "$F1" -gt 0 ] 2>/dev/null; then
    if [ "$F1" -gt 800000 ]; then
        sleep 1
        F2=$(cat "$FREQ_PATH" 2>/dev/null)
        if [ -n "$F2" ] && [ "$F2" -lt "$F1" ]; then
            FREQ=$((F2 / 1000))
        else
            FREQ=$((F1 / 1000))
        fi
    else
        FREQ=$((F1 / 1000))
    fi
else
    FREQ="unknown"
fi
echo "$ARCH x $CORES (${FREQ}MHz)"'

# 6.2 重写 autocore 源码里的 cpuinfo
AUTOCORE_DIR=$(find feeds package -type d -name "autocore" | grep -v build_dir | head -n 1)
if [ -n "$AUTOCORE_DIR" ]; then
    mkdir -p "$AUTOCORE_DIR/files/sbin"
    printf '%s\n' "$CPUINFO_SCRIPT" > "$AUTOCORE_DIR/files/sbin/cpuinfo"
    chmod 755 "$AUTOCORE_DIR/files/sbin/cpuinfo"
    echo "✅ 已用自定义脚本覆盖 autocore 源文件"
fi

# 6.3 消灭 base-files 里的罪魁祸首
BASE_DIR=$(find feeds package -type d -name "base-files" | grep -v build_dir | head -n 1)
if [ -n "$BASE_DIR" ]; then
    # 删除源码自带的 cpuinfo，并注释掉 Makefile 里的安装行
    rm -f "$BASE_DIR/files/sbin/cpuinfo" "$BASE_DIR/files/usr/bin/cpuinfo" 2>/dev/null
    sed -i '/cpuinfo/s/^/# /g' "$BASE_DIR/Makefile" 2>/dev/null
    echo "✅ 已彻底阉割 base-files 里的 cpuinfo 提供能力"
fi

# ============================================================
# 7. 修复前端 ACL 权限
# ============================================================
ACL_FILE="feeds/luci/modules/luci-base/root/usr/share/rpcd/acl.d/luci-base.json"
if [ -f "$ACL_FILE" ]; then
    sed -i 's/"luci": \[ "getFeatures" \]/"luci": [ "getFeatures", "getCPUInfo" ]/' "$ACL_FILE"
fi

# ============================================================
# 8. 【终结报错】完全重写 CoreMark 的 Makefile
# ============================================================
COREMARK_MAKEFILE="feeds/packages/utils/coremark/Makefile"
if [ -f "$COREMARK_MAKEFILE" ]; then
    cat << 'EOF' > "$COREMARK_MAKEFILE"
include $(TOPDIR)/rules.mk

PKG_NAME:=coremark
PKG_RELEASE:=1
PKG_SOURCE:=$(PKG_NAME)-2022-07-27.tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/eembc/coremark/tar.gz/eefc986ebd3452d6adde22eafaff3e5c859f29e4?
PKG_HASH:=a5964bf215786d65d08941b6f9a9a4f4e50524f5391fa3826db2994c47d5e7f3
PKG_BUILD_DIR:=$(BUILD_DIR)/coremark-eefc986ebd3452d6adde22eafaff3e5c859f29e4

include $(INCLUDE_DIR)/package.mk

define Package/coremark
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=CoreMark benchmark
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	tar -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
endef

# 用 sed 直接把源码里的 FLAGS_STR 替换成 "OpenWrt"，避开宏定义转义地狱
define Build/Compile
	sed -i 's/FLAGS_STR/\"OpenWrt\"/' $(PKG_BUILD_DIR)/posix/core_portme.h
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -static \
		-I$(PKG_BUILD_DIR)/posix -I$(PKG_BUILD_DIR) \
		-DITERATIONS=10000 \
		$(PKG_BUILD_DIR)/core_list_join.c \
		$(PKG_BUILD_DIR)/core_main.c \
		$(PKG_BUILD_DIR)/core_matrix.c \
		$(PKG_BUILD_DIR)/core_state.c \
		$(PKG_BUILD_DIR)/core_util.c \
		$(PKG_BUILD_DIR)/posix/core_portme.c \
		-o $(PKG_BUILD_DIR)/coremark
endef

define Package/coremark/install
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/coremark $(1)/bin/
endef

$(eval $(call BuildPackage,coremark))
EOF
    echo "✅ 已重写 CoreMark Makefile"
fi

echo "========================================="
echo "脚本执行完毕，开始编译。"
echo "========================================="
