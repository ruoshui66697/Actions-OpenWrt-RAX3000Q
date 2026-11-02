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
# 6. 【终极解决 cpuinfo 冲突与频率读取】物理斩断两家的 cpuinfo
# ============================================================
# 6.1 找到 autocore 和 base-files 的 Makefile，物理删除所有带 cpuinfo 的安装行
find feeds -path "*/autocore/Makefile" -exec sed -i '/cpuinfo/d' {} + 2>/dev/null
find feeds package -path "*/base-files/Makefile" -exec sed -i '/cpuinfo/d' {} + 2>/dev/null

# 6.2 物理删除源码里自带的 cpuinfo（防止残留）
find feeds -path "*/autocore*" -name "cpuinfo" -type f -exec rm -f {} + 2>/dev/null
find feeds package -path "*base-files*" -name "cpuinfo" -type f -exec rm -f {} + 2>/dev/null

# 6.3 利用 OpenWrt 的 files/ 覆盖机制强行注入我们的脚本
mkdir -p files/sbin
cat << 'EOF' > files/sbin/cpuinfo
#!/bin/sh
ARCH=$(grep "Processor" /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^ *//')
CORES=$(grep -c "^processor" /proc/cpuinfo)
# 核心：读取 scaling_cur_freq，性能模式下能真正抓到 1200000
# =================带 sleep 1 防抖的真实频率动态读取=====================
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
echo "$ARCH x $CORES (${FREQ}MHz)"
EOF
chmod 755 files/sbin/cpuinfo
echo "✅ 已通过 files/ 机制注入自定义 cpuinfo 脚本"

# ============================================================
# 6.4 修复前端 ACL 权限
# ============================================================
ACL_FILE="feeds/luci/modules/luci-base/root/usr/share/rpcd/acl.d/luci-base.json"
if [ -f "$ACL_FILE" ]; then
    sed -i 's/"luci": \[ "getFeatures" \]/"luci": [ "getFeatures", "getCPUInfo" ]/' "$ACL_FILE"
fi

# ============================================================
# 7. 【终结报错】完全重写 CoreMark 的 Makefile（修正 -O3 覆盖问题）
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

# 关键修改：-O3 必须放在 $(TARGET_CFLAGS) 之后，才能覆盖掉系统的 -Os！
define Build/Compile
	sed -i 's/FLAGS_STR/\"OpenWrt O3\"/' $(PKG_BUILD_DIR)/posix/core_portme.h
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -O3 -funroll-loops -static \
		-I$(PKG_BUILD_DIR)/posix -I$(PKG_BUILD_DIR) \
		-DITERATIONS=40000 \
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
    echo "✅ 已重写 CoreMark Makefile（修正 -O3 覆盖问题）"
fi

# ============================================================
# 7.1 原生 CoreMark 跑分、生成日志并直接注入网页型号
# ============================================================
mkdir -p files/etc

# 7.2 写入纯跑分脚本（锁频 2 秒 + 提取数字 + 安全替换型号）
cat << 'EOF' > files/etc/coremark.sh
#!/bin/sh

# 1. 锁定性能模式
echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# 2. 等待 2 秒，确保硬件真正锁死在 1200MHz
sleep 2

# 3. 运行原生 -O3 满血 coremark
/bin/coremark > /tmp/coremark.log 2>/dev/null

# 4. 提取第 4 列数字（绝对不会有斜杠干扰）
SCORE=$(grep "CoreMark 1.0" /tmp/coremark.log | awk '{print $4}')
[ -z "$SCORE" ] && SCORE="0.000000"

# 5. 生成前端需要的日志
echo " (CpuMark : ${SCORE} Scores)" > /etc/bench.log

# 6. 安全替换系统型号（使用 | 作为分隔符，避免 sed 报错）
sed -i "s|DISTRIB_DESCRIPTION=.*|DISTRIB_DESCRIPTION='CMCC RAX3000Q (CpuMark : ${SCORE} Scores)'|" /etc/openwrt_release

# 7. 跑完切回按需模式
echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
EOF
chmod +x files/etc/coremark.sh

# 7.3 把跑分任务强行写进底层的 rc.local
sed -i '/exit 0/d' package/base-files/files/etc/rc.local 2>/dev/null || true
# 先等系统启动 20 秒，如果没有分数，就调用 coremark.sh
echo "if [ ! -f /etc/bench.log ]; then (sleep 20 && /etc/coremark.sh) & fi" >> package/base-files/files/etc/rc.local
echo "exit 0" >> package/base-files/files/etc/rc.local

echo "========================================="
echo "脚本执行完毕，开始编译。"
echo "========================================="
