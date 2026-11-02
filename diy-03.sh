#!/bin/bash
# ============================================================
# 3. 动态查找并替换自定义 DTS 文件 (1.3GHz 专用版)
# ============================================================

echo "========== 🔍 开始寻找并替换 DTS (1.3GHz 版本) =========="
# 在 openwrt 源码目录中搜索目标 dts 文件
TARGET_DTS=$(find $GITHUB_WORKSPACE/openwrt -name "ipq5000-rax3000q.dts" | head -n 1)

# 修正：源文件必须加上 .dts 后缀
SOURCE_DTS="$GITHUB_WORKSPACE/custom_dts/ipq5000-rax3000q-13.dts"

if [ -n "$TARGET_DTS" ]; then
    echo "✅ 找到原 DTS 文件，路径为：$TARGET_DTS"
    cp -f "$SOURCE_DTS" "$TARGET_DTS"
    echo "🚀 DTS 替换成功！(已替换为 1.3GHz 版本)"
else
    echo "⚠️ 源码中未找到现有 DTS，尝试强制放入默认路径..."
    mkdir -p $GITHUB_WORKSPACE/openwrt/target/linux/ipq50xx/dts
    cp -f "$SOURCE_DTS" $GITHUB_WORKSPACE/openwrt/target/linux/ipq50xx/dts/ipq5000-rax3000q.dts
    echo "🚀 DTS 已强制放入！(已替换为 1.3GHz 版本)"
fi

echo "========== 检查替换后的关键代码 ========="
# 检查一下替换进去的 DTS 里面有没有 1300000000 这个频率，确认没替换错
grep -A 2 "opp-1300000000" $GITHUB_WORKSPACE/openwrt/target/linux/ipq50xx/dts/ipq5000-rax3000q.dts 2>/dev/null || echo "未找到 1.3GHz 节点，请检查 custom_dts 下的源文件"
echo "========================================="
