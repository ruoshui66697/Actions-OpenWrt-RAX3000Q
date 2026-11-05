#!/usr/bin/env python3
"""
ath11k GTK Rekey 回退补丁 (5.4 QSDK 适配版)
撤销提交 436a4e886598，恢复 DISABLE_KEY 时 key_len=0 的行为，规避固件 TX 队列死锁。
"""

import os
import sys
import argparse
import re

def read_file(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as fh:
        return fh.read()

def write_file(path, content):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)

def revert_mac_c(source_dir):
    """回退 mac.c 中 ath11k_install_key 的 DISABLE_KEY 分支"""
    path = os.path.join(source_dir, "drivers/net/wireless/ath/ath11k/mac.c")
    if not os.path.exists(path):
        print(f"[ERROR] 找不到文件: {path}")
        return False

    content = read_file(path)
    
    # 检查是否已打过回退补丁
    if "/* arg.key_cipher = WMI_CIPHER_NONE; */" in content:
        print("[OK] mac.c: 回退补丁已存在，跳过。")
        return True

    # 匹配目标代码块 (允许一些空白符变化)
    # 原始有问题的代码:
    # if (cmd == DISABLE_KEY) {
    #     arg.key_cipher = WMI_CIPHER_NONE;
    #     arg.key_data = NULL;
    #     goto install;
    # }
    pattern = re.compile(
        r"(if\s*\(\s*cmd\s*==\s*DISABLE_KEY\s*\)\s*\{\s*\n)"
        r"(\s*)arg\.key_cipher\s*=\s*WMI_CIPHER_NONE\s*;(\s*\n)"
        r"(\s*)arg\.key_data\s*=\s*NULL\s*;(\s*\n)",
        re.MULTILINE
    )

    match = pattern.search(content)
    if not match:
        print("[WARN] mac.c: 未找到目标代码块，源码可能已适配或结构不同。")
        return False

    # 构建回退后的代码块
    indent = match.group(2)  # 保持缩进
    replacement = (
        f"{match.group(1)}"  # if 行
        f"{indent}/* TODO: Check if FW expects value other than NONE for del */\n"
        f"{indent}/* arg.key_cipher = WMI_CIPHER_NONE; */\n"
        f"{indent}arg.key_len = 0;\n"
        f"{match.group(4)}arg.key_data = NULL;{match.group(5)}"
    )

    new_content = content[:match.start()] + replacement + content[match.end():]
    write_file(path, new_content)
    print("[OK] mac.c: 已应用 DISABLE_KEY 回退补丁 (key_cipher=NONE -> key_len=0)。")
    return True


def revert_wmi_c(source_dir):
    """回退 wmi.c 中 ath11k_wmi_vdev_install_key 的 memcpy 保护"""
    path = os.path.join(source_dir, "drivers/net/wireless/ath/ath11k/wmi.c")
    if not os.path.exists(path):
        print(f"[WARN] 找不到文件: {path}，跳过 wmi.c 修改。")
        return True  # 非致命，继续

    content = read_file(path)
    
    # 检查是否已打过补丁 (存在保护性 if 语句)
    if "if (arg->key_data)" in content:
        print("[OK] wmi.c: 回退补丁已存在，跳过。")
        return True

    # 匹配原始的 memcpy 调用 (没有 if 保护)
    pattern = re.compile(
        r"(memcpy\s*\(\s*tlv->value\s*,\s*\(\s*u8\s*\*\s*\)\s*arg->key_data\s*,\s*key_len_aligned\s*\)\s*;)",
        re.MULTILINE
    )

    match = pattern.search(content)
    if not match:
        print("[WARN] wmi.c: 未找到目标 memcpy 调用，跳过。")
        return True

    # 添加 if 保护
    replacement = f"if (arg->key_data)\n\t\t{match.group(1)}"

    new_content = content[:match.start()] + replacement + content[match.end():]
    write_file(path, new_content)
    print("[OK] wmi.c: 已为 memcpy 添加 key_data 空指针保护。")
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", required=True, help="ath11k 驱动源码目录")
    args = parser.parse_args()
    sd = args.source_dir

    print(f"目标源码目录: {sd}")
    print("=" * 60)

    if not os.path.isdir(sd):
        print(f"[FATAL] 目录不存在: {sd}")
        sys.exit(1)

    # 执行回退
    ok_mac = revert_mac_c(sd)
    ok_wmi = revert_wmi_c(sd)

    print("=" * 60)
    if ok_mac and ok_wmi:
        print("[SUCCESS] 回退补丁脚本执行完毕。")
        sys.exit(0)
    else:
        print("[FAILURE] 部分或全部修改失败，请检查日志。")
        sys.exit(1)


if __name__ == "__main__":
    main()
