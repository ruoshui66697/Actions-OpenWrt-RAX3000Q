#!/bin/bash
# ============================================================
# 3. 动态查找并替换自定义 DTS 文件
# ============================================================

echo "========== 🔍 开始寻找并替换 DTS =========="
# 在 openwrt 源码目录中搜索目标 dts 文件
TARGET_DTS=$(find $GITHUB_WORKSPACE/openwrt -name "ipq5000-rax3000q.dts" | head -n 1)

if [ -n "$TARGET_DTS" ]; then
    echo "✅ 找到原 DTS 文件，路径为: $TARGET_DTS"
    cp -f $GITHUB_WORKSPACE/custom_dts/ipq5000-rax3000q.dts "$TARGET_DTS"
    echo "🚀 DTS 替换成功！"
else
    echo "⚠️ 源码中未找到现有 DTS，尝试强制放入默认路径..."
    mkdir -p $GITHUB_WORKSPACE/openwrt/target/linux/ipq50xx/dts
    cp -f $GITHUB_WORKSPACE/custom_dts/ipq5000-rax3000q.dts $GITHUB_WORKSPACE/openwrt/target/linux/ipq50xx/dts/ipq5000-rax3000q.dts
    echo "🚀 DTS 已强制放入！"
fi

echo "========== 检查替换后的关键代码 =========="
grep -A 2 "reset-gpios" $GITHUB_WORKSPACE/openwrt/target/linux/ipq50xx/dts/ipq5000-rax3000q.dts 2>/dev/null || echo "未找到 reset-gpios 属性，请检查！"
echo "=========================================="
