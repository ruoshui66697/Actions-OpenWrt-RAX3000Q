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
# 0. 启用 autocore-arm 以恢复原生温度显示，并解决冲突
# ============================================================
sed -i '/CONFIG_PACKAGE_autocore-arm/d' .config
echo "CONFIG_PACKAGE_autocore-arm=y" >> .config

# ============================================================
# 0.1 【新增】删除 base-files 中的 cpuinfo，避免与 autocore 的文件冲突
# ============================================================
# base-files 可能在不同路径提供 sbin/cpuinfo，全部清理，
rm -f package/base-files/files/sbin/cpuinfo
rm -f package/base-files/files/usr/bin/cpuinfo
rm -f feeds/base/base-files/files/sbin/cpuinfo 2>/dev/null || true
rm -f feeds/base/base-files/files/usr/bin/cpuinfo 2>/dev/null || true
echo "✅ 已清理 base-files 中的 cpuinfo，避免文件冲突"

# 核心魔法：直接修改 autocore 的 Makefile，阻止它安装自带的 cpuinfo
# 这样它就不敢跟我们自定义的 cpuinfo 抢位置了，冲突直接消除！
# sed -i '/sbin\/cpuinfo/d' feeds/packages/utils/autocore/Makefile

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
# 2. 修改默认 LAN 口 IP 地址
# ============================================================
# 将源码中的默认 IP 192.168.1.1 替换为你想要的 IP（例如 192.168.6.1）
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

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

# ============================================================
# 5. 添加 CPU 频率调节 (cpufreq) LuCI 界面及中文语言包
# ============================================================
# 检查 feed 里是否存在 luci-app-cpufreq，不存在则手动拉取
if [ ! -d "feeds/luci/applications/luci-app-cpufreq" ]; then
    echo "luci-app-cpufreq not found in feeds, fetching from immortalwrt/luci..."
    git clone --depth=1 https://github.com/immortalwrt/luci.git /tmp/luci-cpufreq
    cp -r /tmp/luci-cpufreq/applications/luci-app-cpufreq feeds/luci/applications/
    rm -rf /tmp/luci-cpufreq
fi
# 清除可能存在的旧配置行
sed -i '/CONFIG_PACKAGE_luci-app-cpufreq/d' .config
sed -i '/CONFIG_PACKAGE_luci-i18n-cpufreq/d' .config

# 启用 cpufreq 插件
echo "CONFIG_PACKAGE_luci-app-cpufreq=y" >> .config
# ============================================================
#  确保 hotplug 脚本可执行
# ============================================================
[ -d "files/etc/hotplug.d/button" ] && chmod +x files/etc/hotplug.d/button/*
# 中文语言包（21.02 分支使用 zh-cn 命名，与你现有 base/firewall 等一致）
echo "CONFIG_PACKAGE_luci-i18n-cpufreq-zh-cn=y" >> .config

# =========================6. 定制底层 cpuinfo 脚本（替换 autocore 源码中所有 cpuinfo，base-files 不提供）===================
AUTOCORE_DIR=""
for d in \
    "feeds/packages/utils/autocore" \
    "feeds/base/utils/autocore" \
    "package/utils/autocore"
do
    if [ -d "$d" ]; then
        AUTOCORE_DIR="$d"
        break
    fi
done
if [ -z "$AUTOCORE_DIR" ]; then
    AUTOCORE_DIR=$(find feeds package -maxdepth 6 -type d -name autocore 2>/dev/null | head -n1)
fi

echo "===== autocore 目录: $AUTOCORE_DIR ====="
if [ -n "$AUTOCORE_DIR" ]; then
    echo "----- autocore 下所有 cpuinfo 文件 -----"
    find "$AUTOCORE_DIR" -type f -name cpuinfo -print 2>/dev/null || true
    echo "----- Makefile 中 cpuinfo 相关行 -----"
    grep -n "cpuinfo" "$AUTOCORE_DIR/Makefile" 2>/dev/null || echo "（无）"
    echo "---------------------------------------"
fi

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

if [ -n "$AUTOCORE_DIR" ] && [ -d "$AUTOCORE_DIR/files" ]; then
    FOUND=0
    while IFS= read -r f; do
        printf '%s\n' "$CPUINFO_SCRIPT" > "$f"
        chmod 755 "$f"
        echo "✅ 已替换: $f"
        FOUND=1
    done < <(find "$AUTOCORE_DIR/files" -type f -name cpuinfo 2>/dev/null)

    if [ "$FOUND" -eq 0 ]; then
        mkdir -p "$AUTOCORE_DIR/files/sbin"
        printf '%s\n' "$CPUINFO_SCRIPT" > "$AUTOCORE_DIR/files/sbin/cpuinfo"
        chmod 755 "$AUTOCORE_DIR/files/sbin/cpuinfo"
        echo "✅ 未找到已有 cpuinfo，已创建: $AUTOCORE_DIR/files/sbin/cpuinfo"
    fi
else
    echo "⚠️ 未找到 autocore/files 目录"
fi

# =========================7. 修复前端无权获取 CPU 频率的问题 ===================
ACL_FILE="feeds/luci/modules/luci-base/root/usr/share/rpcd/acl.d/luci-base.json"
if [ -f "$ACL_FILE" ]; then
    # 把 getCPUInfo 塞进 ubus 的 luci 权限列表里，否则网页会报错拿不到数据
    sed -i 's/"luci": \[ "getFeatures" \]/"luci": [ "getFeatures", "getCPUInfo" ]/' "$ACL_FILE"
    echo "✅ 已修改 ACL，赋予前端读取 getCPUInfo 的权限"
else
    echo "⚠️ 未找到 luci-base.json，跳过修改"
fi

# =========================8. 【新增】强制 CoreMark 静态编译 ===================
# 目的：让 /bin/coremark 不再依赖动态 musl 库，彻底解决段错误/卡死
COREMARK_MAKEFILE=""
for candidate in \
    "feeds/packages/utils/coremark/Makefile" \
    "package/utils/coremark/Makefile" \
    "feeds/packages/utils/coremark/Makefile"
do
    if [ -f "$candidate" ]; then
        COREMARK_MAKEFILE="$candidate"
        break
    fi
done

if [ -n "$COREMARK_MAKEFILE" ]; then
    echo "找到 CoreMark Makefile: $COREMARK_MAKEFILE"
    # 注入静态链接标志（避免重复注入）
    if ! grep -q "TARGET_LDFLAGS += -static" "$COREMARK_MAKEFILE"; then
        sed -i '/define Build\/Compile/i TARGET_LDFLAGS += -static\n' "$COREMARK_MAKEFILE"
        echo "✅ 已注入 TARGET_LDFLAGS += -static"
    else
        echo "ℹ️ TARGET_LDFLAGS += -static 已存在，跳过"
    fi

    if ! grep -q "TARGET_CFLAGS += -static" "$COREMARK_MAKEFILE"; then
        sed -i '/define Build\/Compile/i TARGET_CFLAGS += -static\n' "$COREMARK_MAKEFILE"
        echo "✅ 已注入 TARGET_CFLAGS += -static"
    else
        echo "ℹ️ TARGET_CFLAGS += -static 已存在，跳过"
    fi
else
    echo "⚠️ 未找到 CoreMark Makefile，请检查 feed 路径。"
    echo "   如果 CoreMark 包不在 feeds/packages/utils/coremark，请手动确认路径后调整脚本。"
fi

# =========================9. 将 CoreMark 改为单线程标准跑分 ===================
COREMARK_MK=""
for candidate in \
    "feeds/packages/utils/coremark/Makefile" \
    "package/utils/coremark/Makefile"
do
    if [ -f "$candidate" ]; then
        COREMARK_MK="$candidate"
        break
    fi
done

if [ -n "$COREMARK_MK" ]; then
    # 1. 删除 MULTITHREAD 变量定义（匹配 =、:=、?= 等所有形式）
    sed -i '/^[[:space:]]*MULTITHREAD[[:space:]]*[:?]*=/d' "$COREMARK_MK"

    # 2. 删除 -DMULTITHREAD=xxx（数字和 $(VAR) 形式都删）
    sed -i 's/-DMULTITHREAD=[^ ]*//g' "$COREMARK_MK"

    # 3. 删除 -DUSE_PTHREAD
    sed -i 's/-DUSE_PTHREAD//g' "$COREMARK_MK"

    # 4. 清理多余空格
    sed -i 's/  */ /g' "$COREMARK_MK"

    echo "✅ 已将 CoreMark 改为单线程编译"
    echo "   修改后仍含 MULTITHREAD/USE_PTHREAD 的行："
    grep -n "MULTITHREAD\|USE_PTHREAD" "$COREMARK_MK" || echo "   （已无残留，单线程化完成）"
else
    echo "⚠️ 未找到 CoreMark Makefile，跳过单线程修改"
fi

# =========================9.1 命令行覆盖 MULTITHREAD，确保 core_portme.mak 里的定义失效 ===================
if [ -n "$COREMARK_MK" ]; then
    if grep -q '\$(MAKE) -C \$(PKG_BUILD_DIR)' "$COREMARK_MK"; then
        sed -i 's/\$(MAKE) -C \$(PKG_BUILD_DIR)/$(MAKE) -C $(PKG_BUILD_DIR) MULTITHREAD=/' "$COREMARK_MK"
        echo "✅ 已在 \$(MAKE) 调用中传递 MULTITHREAD= 空值，覆盖 core_portme.mak 里的定义"
    else
        echo "⚠️ 未找到 \$(MAKE) -C \$(PKG_BUILD_DIR) 调用，跳过命令行覆盖"
    fi
fi

# =========================10. 修复 CoreMark mkdir 目录已存在导致的编译失败 ===================
# 根因：上游 Makefile 使用 mkdir 而非 mkdir -p，重复编译或目录残留时会报 File exists
COREMARK_MK_FIX=""
for candidate in \
    "feeds/packages/utils/coremark/Makefile" \
    "package/utils/coremark/Makefile"
do
    if [ -f "$candidate" ]; then
        COREMARK_MK_FIX="$candidate"
        break
    fi
done

if [ -n "$COREMARK_MK_FIX" ]; then
    # 将 mkdir $(PKG_BUILD_DIR)/$(ARCH) 替换为 mkdir -p $(PKG_BUILD_DIR)/$(ARCH)
    if grep -qE '^\s*mkdir \$\(PKG_BUILD_DIR\)/\$\(ARCH\)' "$COREMARK_MK_FIX"; then
        sed -i 's/^\s*mkdir \$(PKG_BUILD_DIR)\/\$(ARCH)/\tmkdir -p $(PKG_BUILD_DIR)\/$(ARCH)/' "$COREMARK_MK_FIX"
        echo "✅ 已将 CoreMark Makefile 中的 mkdir 修复为 mkdir -p"
    else
        echo "ℹ️ 未找到需要修复的 mkdir 行，可能已是 mkdir -p 或路径格式不同"
    fi
else
    echo "⚠️ 未找到 CoreMark Makefile，跳过 mkdir 修复"
fi
echo "========================================="
echo "diy-part2.sh 执行完毕，可以开始云编译。"
echo "========================================="
