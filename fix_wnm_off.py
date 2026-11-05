#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fix_wnm_off.py
用途：在编译前关闭 wpa_supplicant 的 WNM 功能，避免 GTK rekey 时因 WNM 漫游引导导致的断线。
"""

import sys
import re
from pathlib import Path

def main():
    # 默认在 openwrt 目录下执行，可以通过参数传入路径
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    cfg_dir = root / "package/network/services/hostapd/files"
    
    print(f"[*] 正在检查目标目录: {cfg_dir}")
    
    if not cfg_dir.exists():
        print(f"[ERROR] 找不到目录: {cfg_dir}")
        print("[ERROR] 源码结构可能已更改，终止编译以防遗漏补丁！")
        sys.exit(1)
        
    target_files = sorted(cfg_dir.glob("*.config"))
    if not target_files:
        print(f"[ERROR] 在 {cfg_dir} 中找不到任何 .config 文件")
        sys.exit(1)
        
    patched_count = 0
    found_wnm_keyword = False
    
    for cfg in target_files:
        content = cfg.read_text()
        
        # 检查文件中是否包含 WNM 关键字
        if "CONFIG_WNM" in content:
            found_wnm_keyword = True
            
        # 使用正则匹配行首的 CONFIG_WNM=y，并允许行尾有空格或注释
        if re.search(r"^CONFIG_WNM=y", content, re.MULTILINE):
            new_content = re.sub(
                r"^CONFIG_WNM=y.*$", 
                "# CONFIG_WNM is not set  # PATCH: ignore BTM roam hints", 
                content, 
                flags=re.MULTILINE
            )
            cfg.write_text(new_content)
            print(f"[OK] {cfg.name}: 已将 CONFIG_WNM=y 修改为注释状态")
            patched_count += 1
        elif "# CONFIG_WNM is not set" in content:
            print(f"[SKIP] {cfg.name}: CONFIG_WNM 已经处于关闭状态")
        else:
            print(f"[WARN] {cfg.name}: 存在 CONFIG_WNM 但未找到 'CONFIG_WNM=y' 这一行")

    # 安全拦截：如果遍历了所有配置文件，连 CONFIG_WNM 这个字样都没找到，说明上游改了配置逻辑
    if not found_wnm_keyword:
        print("[ERROR] 所有配置文件中均未找到 CONFIG_WNM 关键字！")
        print("[ERROR] 上游源码可能已变更，请检查文件结构。终止编译！")
        sys.exit(1)
        
    print(f"[DONE] 补丁注入完成。共修改了 {patched_count} 个文件。")

if __name__ == "__main__":
    main()
