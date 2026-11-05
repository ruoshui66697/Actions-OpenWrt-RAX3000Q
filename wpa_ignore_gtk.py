#!/usr/bin/env python3
# 用途：让 wpa_supplicant 收到组密钥更新请求时直接丢弃，不往底层驱动发指令
# 回退：删除本文件，并在 workflow 删除对应执行行
import os
import re
import glob

def main():
    # 查找 wpa_supplicant 的源码文件 wpa.c
    # 在 OpenWrt 编译目录中，通常位于 build_dir 下的 hostapd 源码里
    print("正在寻找 wpa.c 源码...")
    wpa_c_files = glob.glob("build_dir/**/src/rsn_supp/wpa.c", recursive=True)
    
    if not wpa_c_files:
        print("❌ 找不到 wpa.c 源码，跳过补丁。")
        return

    for file_path in wpa_c_files:
        print(f"✅ 找到源码: {file_path}")
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # 函数 1：处理 WPA2 (RSN) 的 Group Key 消息 1/2
        target_rsn = "static int wpa_supplicant_process_1_of_2_rsn(struct wpa_sm *sm,"
        if target_rsn in content:
            # 在函数体开头直接加入 return -1;
            content = re.sub(
                r'(static int wpa_supplicant_process_1_of_2_rsn\(struct wpa_sm \*sm,[^)]+\)\s*\{)',
                r'\1\n\treturn -1; // 注入：装死，忽略GTK',
                content
            )
            print("✅ 已注入 WPA2 忽略补丁")
        
        # 函数 2：处理 WPA1 的 Group Key 消息 1/2
        target_wpa = "static int wpa_supplicant_process_1_of_2_wpa(struct wpa_sm *sm,"
        if target_wpa in content:
            content = re.sub(
                r'(static int wpa_supplicant_process_1_of_2_wpa\(struct wpa_sm \*sm,[^)]+\)\s*\{)',
                r'\1\n\treturn -1; // 注入：装死，忽略GTK',
                content
            )
            print("✅ 已注入 WPA1 忽略补丁")

        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
            
if __name__ == "__main__":
    main()
