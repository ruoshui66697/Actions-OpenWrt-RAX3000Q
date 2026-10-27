#!/bin/bash
# 将自定义的 DTS 文件替换到源码目录中
cp -f $GITHUB_WORKSPACE/custom_dts/ipq5000-rax3000q.dts openwrt/target/linux/ipq50xx/dts/ipq5000-rax3000q.dts
