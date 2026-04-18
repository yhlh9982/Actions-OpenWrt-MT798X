#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

echo "=========================================="
echo "执行自定义优化脚本 (diy-part2.sh)"
echo "=========================================="

# ---------------------------------------------------------
# 1. 环境路径识别与安全兜底
# ---------------------------------------------------------
TARGET_DIR="${1:-$(pwd)}"

check_openwrt_root() {
    [ -f "\$1/scripts/feeds" ] && [ -f "\$1/Makefile" ]
}

if [ -n "$TARGET_DIR" ] && check_openwrt_root "$TARGET_DIR"; then
    OPENWRT_ROOT="$TARGET_DIR"
    echo "✅ 自动识别 OpenWrt 根目录: $OPENWRT_ROOT"
else
    SUB_DIR=$(find . -maxdepth 2 -name "scripts" -type d | head -n 1 | xargs -r dirname 2>/dev/null)
    if [ -n "$SUB_DIR" ] && check_openwrt_root "$SUB_DIR"; then
        OPENWRT_ROOT="$(realpath "$SUB_DIR")"
        echo "✅ 在子目录找到 OpenWrt 根目录: $OPENWRT_ROOT"
    else
        OPENWRT_ROOT=$(pwd)
        echo "⚠️ 警告: 未能智能识别，强制设定根目录为当前目录: $OPENWRT_ROOT"
    fi
fi

# ---------------------------------------------------------
# 2. QuickStart 首页温度显示修复
# ---------------------------------------------------------
echo ">>> 执行 QuickStart 修复..."
REPO_ROOT=$(dirname "$(readlink -f "\$0")")/.. 
if [ -n "$GITHUB_WORKSPACE" ]; then
    REPO_ROOT="$GITHUB_WORKSPACE"
fi

CUSTOM_LUA="$REPO_ROOT/istore/istore_backend.lua"
TARGET_LUA=$(find feeds package -name "istore_backend.lua" -type f 2>/dev/null | head -n 1)

if [ -n "$TARGET_LUA" ]; then
    echo "定位到目标文件: $TARGET_LUA"
    if [ -f "$CUSTOM_LUA" ]; then
        echo "正在覆盖自定义文件..."
        cp -f "$CUSTOM_LUA" "$TARGET_LUA"
        if cmp -s "$CUSTOM_LUA" "$TARGET_LUA"; then
             echo "✅ QuickStart 修复成功"
        else
             echo "❌ 错误: 文件复制校验失败"
        fi
    else
        echo "⚠️ 警告: 仓库中未找到自定义文件 $CUSTOM_LUA"
    fi
else
    echo "⚠️ 警告: 未在源码中找到 istore_backend.lua，跳过修复"
fi

# ---------------------------------------------------------
# 3. 核心组件升级替换
# ---------------------------------------------------------
echo ">>> 升级核心组件..."
find feeds package -type d -name "mosdns" -exec rm -rf {} + 2>/dev/null
find feeds package -type d -name "v2ray-geodata" -exec rm -rf {} + 2>/dev/null

git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

# requires golang 1.24.x or latest version
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang

# 升级替换 smartdns
WORKINGDIR="$(pwd)/feeds/packages/net/smartdns"
mkdir -p "$WORKINGDIR"
rm -rf "$WORKINGDIR"/*
wget https://github.com/pymumu/openwrt-smartdns/archive/master.zip -O "$WORKINGDIR/master.zip"
unzip -q "$WORKINGDIR/master.zip" -d "$WORKINGDIR"
mv "$WORKINGDIR"/openwrt-smartdns-master/* "$WORKINGDIR/"
rmdir "$WORKINGDIR/openwrt-smartdns-master"
rm -f "$WORKINGDIR/master.zip"

LUCIBRANCH="master"
WORKINGDIR="$(pwd)/feeds/luci/applications/luci-app-smartdns"
mkdir -p "$WORKINGDIR"
rm -rf "$WORKINGDIR"/*
wget https://github.com/pymumu/luci-app-smartdns/archive/${LUCIBRANCH}.zip -O "$WORKINGDIR/${LUCIBRANCH}.zip"
unzip -q "$WORKINGDIR/${LUCIBRANCH}.zip" -d "$WORKINGDIR"
mv "$WORKINGDIR"/luci-app-smartdns-${LUCIBRANCH}/* "$WORKINGDIR/"
rmdir "$WORKINGDIR/luci-app-smartdns-${LUCIBRANCH}"
rm -f "$WORKINGDIR/${LUCIBRANCH}.zip"
echo "✅ 核心组件升级完成"

# ---------------------------------------------------------
# 4. 其他组件修复与硬化
# ---------------------------------------------------------
find feeds/luci -type f -path "*/luci-app-diskman/Makefile" -exec sed -i '/ntfs-3g-utils /d' {} +
echo "✅ DiskMan 依赖修复完成"

# libxcrypt 专项救治
XCRYPT_MK="feeds/packages/libs/libxcrypt/Makefile"
if [ -f "$XCRYPT_MK" ]; then
    echo ">>> 正在硬化 libxcrypt 编译参数..."
    sed -i 's/CONFIGURE_ARGS[ \t]*+=[ \t]*/&--disable-werror /' "$XCRYPT_MK"
    sed -i 's/TARGET_CFLAGS[ \t]*+=[ \t]*/&-fcommon /' "$XCRYPT_MK"
    echo "✅ libxcrypt 参数注入完成。"
fi

# ---------------------------------------------------------
# 5. 菜单位置调整
# ---------------------------------------------------------
echo ">>> 调整插件菜单位置..."

# 5.1 Tailscale -> VPN 
TS_DIR=$(find feeds package -type d -name "luci-app-tailscale-community" 2>/dev/null | head -n 1)

if [ -n "$TS_DIR" ]; then
    echo ">>> 发现 Tailscale 插件目录: $TS_DIR"
    find "$TS_DIR" -type f -name "*.json" -exec sed -i 's|admin/services/tailscale|admin/vpn/tailscale|g' {} +
    find "$TS_DIR" -type f -name "*.json" -exec sed -i 's/"parent": "luci.services"/"parent": "luci.vpn"/g' {} +
    echo "✅ Tailscale 菜单已移动到 VPN"
else
    grep -rl "admin/services/tailscale" package feeds 2>/dev/null | xargs -r sed -i 's|admin/services/tailscale|admin/vpn/tailscale|g'
    grep -rl '"parent": "luci.services"' package feeds 2>/dev/null | xargs -r sed -i 's/"parent": "luci.services"/"parent": "luci.vpn"/g'
    echo "✅ Tailscale 菜单(全盘搜索模式)已移动"
fi

# 5.2 KSMBD -> NAS
KSMBD_DIR=$(find feeds/luci -type d -name "luci-app-ksmbd" 2>/dev/null | head -n 1)
if [ -n "$KSMBD_DIR" ]; then
    find "$KSMBD_DIR" -type f -exec sed -i 's|admin/services/ksmbd|admin/nas/ksmbd|g' {} +
    find "$KSMBD_DIR" -type f -exec sed -i 's/"parent": "luci.services"/"parent": "luci.nas"/g' {} +
    echo "✅ KSMBD 菜单已移动"
fi

# 5.3 OpenList2 -> NAS
OPENLIST2_DIR=$(find feeds package -type d -name "luci-app-openlist2" 2>/dev/null | head -n 1)
if [ -n "$OPENLIST2_DIR" ]; then
    find "$OPENLIST2_DIR" -type f -exec sed -i 's|admin/services/openlist2|admin/nas/openlist2|g' {} +
    find "$OPENLIST2_DIR" -type f -exec sed -i 's/"parent": "luci.services"/"parent": "luci.nas"/g' {} +
    echo "✅ OpenList2 菜单已移动到 NAS"
fi

# ---------------------------------------------------------
# 6. 修复Rust编译失败
# ---------------------------------------------------------
RUST_FILE=$(find feeds/packages -path "*/lang/rust/Makefile" 2>/dev/null | head -n 1)

if [ -n "$RUST_FILE" ] && [ -f "$RUST_FILE" ]; then
    sed -i 's/download-ci-llvm:=.*/download-ci-llvm:="if-unchanged"/g' "$RUST_FILE"
    sed -i 's/download-ci-llvm=.*/download-ci-llvm="if-unchanged"/g' "$RUST_FILE"
    echo "✅ Rust CI-LLVM build enabled (Safe Mode)!"
fi

# =========================================================
# 修复 eBPF 与 Daed 的内核依赖冲突 (终极性能版)
# =========================================================
echo ">>> [Kernel] 正在修复 eBPF/Daed 编译依赖..."

# 强行打通内核 BPF 与 TC (Traffic Control) 前置依赖
for conf in target/linux/mediatek/filogic/config-*; do
    # 【关键修正】：if 和 [ 之间必须有空格！
    if [ -f "$conf" ]; then
        echo ">>> 正在为 $conf 注入 eBPF/TC 核心与极致性能配置..."
        
        # --- 1. 流量控制 (TC) 前置大门 (缺失会导致 act_bpf 丢失) ---
        echo "CONFIG_NET_SCHED=y" >> "$conf"
        echo "CONFIG_NET_CLS=y" >> "$conf"
        echo "CONFIG_NET_CLS_ACT=y" >> "$conf"
        echo "CONFIG_NET_INGRESS=y" >> "$conf"
        echo "CONFIG_NET_EGRESS=y" >> "$conf"
 
        # --- 2. BPF 核心与模块 ---
        echo "CONFIG_NET_CLS_BPF=m" >> "$conf"
        echo "CONFIG_NET_ACT_BPF=m" >> "$conf"
        echo "CONFIG_BPF=y" >> "$conf"
        echo "CONFIG_BPF_SYSCALL=y" >> "$conf"
        echo "CONFIG_CGROUP_BPF=y" >> "$conf"

        # --- 3. BPF 极致性能优化 (榨干路由器算力) ---
        echo "CONFIG_BPF_JIT=y" >> "$conf"
        echo "CONFIG_BPF_JIT_ALWAYS_ON=y" >> "$conf"
        echo "CONFIG_BPF_STREAM_PARSER=y" >> "$conf"
        echo "CONFIG_NET_SOCK_MSG=y" >> "$conf"
        echo "CONFIG_XDP_SOCKETS=y" >> "$conf"
        
        echo "✅ eBPF 高性能与底层网络调度配置注入完成。"
    fi
done

# ---------------------------------------------------------
# 8. 系统收尾工作
# ---------------------------------------------------------
sed -i 's/192.168.6.1/192.168.30.1/g' package/base-files/files/bin/config_generate

if [ -f feeds.conf.default.bak ]; then
    mv feeds.conf.default.bak feeds.conf.default
fi

rm -f feeds.conf

echo "✅ 执行自定义优化脚本 (diy-part2.sh) 收尾完成。"
