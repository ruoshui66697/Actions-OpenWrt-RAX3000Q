#!/usr/bin/env python3
# ============================================================
# 用途：注释掉 ath11k 源码中 DISABLE_KEY 分支的 WMI_CIPHER_NONE，
#      避免固件触发断言死锁，导致 GTK rekey 失败。
# 回退：直接删除本文件，并在 workflow 中删除对应的调用行。
# ============================================================
import re
import sys
import glob
import argparse

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", required=True, help="mac80211 源码目录")
    args = parser.parse_args()

    # 在传入的源码目录中寻找 mac.c
    mac_c_pattern = f"{args.source_dir}/drivers/net/wireless/ath/ath11k/mac.c"
    files = glob.glob(mac_c_pattern)
    
    if not files:
        print(f"[PATCH] 未找到 mac.c，路径可能不对: {mac_c_pattern}")
        sys.exit(0)

    path = files[0]
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()

    # 匹配 DISABLE_KEY 分支中的 arg.key_cipher = WMI_CIPHER_NONE;
    pattern = re.compile(
        r'(\bif\s*\(\s*cmd\s*==\s*DISABLE_KEY\s*\)\s*\{[^}]*?)'
        r'(\barg\.key_cipher\s*=\s*WMI_CIPHER_NONE\s*;)',
        re.S
    )

    def repl(m):
        # 在前面加上 // 注释掉
        return m.group(1) + "// " + m.group(2)

    new_src, count = pattern.subn(repl, src)

    if count == 0:
        print("[PATCH] 未匹配到 WMI_CIPHER_NONE 行，可能已经被改过或路径不对")
        sys.exit(0)

    # 备份原文件
    with open(path + ".bak_keycipher", "w") as f:
        f.write(src)

    with open(path, "w") as f:
        f.write(new_src)

    print(f"[PATCH] 成功注释 WMI_CIPHER_NONE，匹配 {count} 处：{path}")

if __name__ == "__main__":
    main()
