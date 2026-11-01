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
# 6. 【安全解决 cpuinfo 冲突】改写 base-files 源文件，注释 autocore 安装指令
# ============================================================
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

# 6.1 找到 base-files 里的 cpuinfo 并直接覆盖内容，保证源文件存在不报错
BASE_CPUINFO=$(find feeds/base/base-files package/base-files -type f -name "cpuinfo" 2>/dev/null | head -n 1)
if [ -n "$BASE_CPUINFO" ]; then
    printf '%s\n' "$CPUINFO_SCRIPT" > "$BASE_CPUINFO"
    echo "✅ 已用自定义脚本覆盖 base-files 的: $BASE_CPUINFO"
else
    mkdir -p package/base-files/files/sbin
    printf '%s\n' "$CPUINFO_SCRIPT" > package/base-files/files/sbin/cpuinfo
    echo "✅ 已创建 base-files 的 cpuinfo"
fi

# 6.2 阻止 autocore 再安装 cpuinfo（把 Makefile 里的相关行注释掉，不留隐患）
AUTOCORE_MAKEFILE="feeds/packages/utils/autocore/Makefile"
if [ -f "$AUTOCORE_MAKEFILE" ]; then
    sed -i '/cpuinfo/s/^/# /g' "$AUTOCORE_MAKEFILE"
    echo "✅ 已注释 autocore Makefile 中的 cpuinfo 安装行"
fi

# ============================================================
# 7. 修复前端 ACL 权限
# ============================================================
ACL_FILE="feeds/luci/modules/luci-base/root/usr/share/rpcd/acl.d/luci-base.json"
if [ -f "$ACL_FILE" ]; then
    sed -i 's/"luci": \[ "getFeatures" \]/"luci": [ "getFeatures", "getCPUInfo" ]/' "$ACL_FILE"
fi

# ============================================================
# 8. 【终结报错】完全重写 CoreMark 的 Makefile（去除导致引号转义报错的宏）
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

# 去除了 -DFLAGS_STR 宏，彻底避开嵌套双引号解析地狱！
define Build/Compile
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
