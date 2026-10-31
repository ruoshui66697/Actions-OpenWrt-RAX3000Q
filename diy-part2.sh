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
# 0. 禁用 autocore-arm 防止与<6>自定义 cpuinfo 冲突
# ============================================================
sed -i '/CONFIG_PACKAGE_autocore-arm/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-autocore/d' .config

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


# =========================6. 定制底层 cpuinfo 脚本（解决 1.2GHz 动态显示）===================
# 确保目标目录存在
mkdir -p package/base-files/files/sbin

# 将我们定制好的 cpuinfo 脚本写入固件源码目录
cat << 'EOF' > package/base-files/files/sbin/cpuinfo
#!/bin/sh

cpu_arch="$(awk -F ': ' '/model name/ {print $2}' /proc/cpuinfo | head -n1)"
[ -n "${cpu_arch}" ] || cpu_arch="ARMv7 Processor rev 4 (v7l)"

cpu_cores="$(grep -c "processor" /proc/cpuinfo)"

hw_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq 2>/dev/null)
sc_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)

if [ "$sc_freq" = "1200000" ]; then
    cpu_freq="1200MHz"
elif [ -n "$hw_freq" ]; then
    cpu_freq="$((hw_freq / 1000))MHz"
else
    cpu_freq="?"
fi

echo -n "$cpu_arch x $cpu_cores ($cpu_freq)"
EOF

# 赋予可执行权限，防止刷机后权限不对导致无法运行
chmod +x package/base-files/files/sbin/cpuinfo

# =========================7. 修复前端无权获取 CPU 频率的问题 ===================
ACL_FILE="feeds/luci/modules/luci-base/root/usr/share/rpcd/acl.d/luci-base.json"
if [ -f "$ACL_FILE" ]; then
    # 把 getCPUInfo 塞进 ubus 的 luci 权限列表里
    sed -i 's/"luci": \[ "getFeatures" \]/"luci": [ "getFeatures", "getCPUInfo" ]/' "$ACL_FILE"
    echo "✅ 已修改 ACL，赋予前端读取 getCPUInfo 的权限"
fi
