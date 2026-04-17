#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

echo "=========================================="
echo "执行自定义优化脚本 (diy-part2.sh)"
echo "=========================================="

# 升级替换 mosdns
# drop mosdns and v2ray-geodata packages that come with the source
find ./ | grep Makefile | grep v2ray-geodata | xargs rm -f
find ./ | grep Makefile | grep mosdns | xargs rm -f

git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

# requires golang 1.24.x or latest version
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang

# 升级替换 smartdns
WORKINGDIR="`pwd`/feeds/packages/net/smartdns"
mkdir $WORKINGDIR -p
rm $WORKINGDIR/* -fr
wget https://github.com/pymumu/openwrt-smartdns/archive/master.zip -O $WORKINGDIR/master.zip
unzip $WORKINGDIR/master.zip -d $WORKINGDIR
mv $WORKINGDIR/openwrt-smartdns-master/* $WORKINGDIR/
rmdir $WORKINGDIR/openwrt-smartdns-master
rm $WORKINGDIR/master.zip

LUCIBRANCH="master" #更换此变量
WORKINGDIR="`pwd`/feeds/luci/applications/luci-app-smartdns"
mkdir $WORKINGDIR -p
rm $WORKINGDIR/* -fr
wget https://github.com/pymumu/luci-app-smartdns/archive/${LUCIBRANCH}.zip -O $WORKINGDIR/${LUCIBRANCH}.zip
unzip $WORKINGDIR/${LUCIBRANCH}.zip -d $WORKINGDIR
mv $WORKINGDIR/luci-app-smartdns-${LUCIBRANCH}/* $WORKINGDIR/
rmdir $WORKINGDIR/luci-app-smartdns-${LUCIBRANCH}
rm $WORKINGDIR/${LUCIBRANCH}.zip

# ---------------------------------------------------------
# libxcrypt 专项救治 (极致精简版)
# ---------------------------------------------------------
XCRYPT_MK="feeds/packages/libs/libxcrypt/Makefile"
if [ -f "$XCRYPT_MK" ]; then
    echo ">>> 正在硬化 libxcrypt 编译参数..."
    
    # 1. 强制禁用 werror (兼容多种等号写法)
    # 作用：防止编译器因为一些琐碎的警告而罢工
    sed -i 's/CONFIGURE_ARGS[ \t]*+=[ \t]*/&--disable-werror /' "$XCRYPT_MK"

    # 2. 注入 -fcommon (核心修复)
    # 作用：解决 gen-des-tables.o 报错的真凶（允许多重定义变量）
    # 使用 TARGET_CFLAGS 注入，如果还报 host 错，我们会同时注入给 HOST_CFLAGS
    sed -i 's/TARGET_CFLAGS[ \t]*+=[ \t]*/&-fcommon /' "$XCRYPT_MK"
    
    # 3. 额外保险：针对宿主机编译工具的补丁
    # 因为 gen-des-tables 是在你的电脑上跑的，有时候需要这一行
    # sed -i 's/HOST_CFLAGS[ \t]*+=[ \t]*/&-fcommon /' "$XCRYPT_MK" 2>/dev/null || true

    echo "✅ libxcrypt 参数注入完成。"
fi

# 5.1 Tailscale -> VPN 
TS_DIR=$(find feeds package -type d -name "luci-app-tailscale-community" 2>/dev/null | head -n 1)

if [ -n "$TS_DIR" ]; then
    echo ">>> 发现 Tailscale 插件目录: $TS_DIR"
    # 1. 替换菜单路径定义
    find "$TS_DIR" -type f -name "*.json" -exec sed -i 's|admin/services/tailscale|admin/vpn/tailscale|g' {} +
    # 2. 替换父级分类定义
    find "$TS_DIR" -type f -name "*.json" -exec sed -i 's/"parent": "luci.services"/"parent": "luci.vpn"/g' {} +
    echo "✅ Tailscale 菜单已移动到 VPN"
else
    # 备用逻辑：如果 feed 名改了，全盘搜索 package/feeds 内部
    TS_FILES=$(grep -rl "admin/services/tailscale" package/feeds 2>/dev/null)
    if [ -n "$TS_FILES" ]; then
        echo "$TS_FILES" | xargs sed -i 's|admin/services/tailscale|admin/vpn/tailscale|g'
        echo "$TS_FILES" | xargs sed -i 's/"parent": "luci.services"/"parent": "luci.vpn"/g'
        echo "✅ Tailscale 菜单(全盘搜索模式)已移动"
    fi
fi

# 5.2 KSMBD -> NAS (只在 ksmbd 目录下改)
# 自动定位 ksmbd 插件的物理目录，通常在 feeds/luci 下
KSMBD_DIR=$(find feeds/luci -type d -name "luci-app-ksmbd" | head -n 1)
if [ -n "$KSMBD_DIR" ]; then
    find "$KSMBD_DIR" -type f -exec sed -i 's|admin/services/ksmbd|admin/nas/ksmbd|g' {} +
    find "$KSMBD_DIR" -type f -exec sed -i 's/"parent": "luci.services"/"parent": "luci.nas"/g' {} +
    echo "✅ KSMBD 菜单已移动"
fi

# 5.3 OpenList2 -> NAS (自动定位并精准修改)
OPENLIST2_DIR=$(find feeds package -type d -name "luci-app-openlist2" | head -n 1)
if [ -n "$OPENLIST2_DIR" ]; then
    # 修改菜单路径：从 services 变更为 nas
    find "$OPENLIST2_DIR" -type f -exec sed -i 's|admin/services/openlist2|admin/nas/openlist2|g' {} +
    # 修改 JSON 父级定义 (如果存在 parent 字段)
    find "$OPENLIST2_DIR" -type f -exec sed -i 's/"parent": "luci.services"/"parent": "luci.nas"/g' {} +
    echo "✅ OpenList2 菜单已移动到 NAS"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages -path "*/lang/rust/Makefile" | head -n 1)

if [ -n "$RUST_FILE" ] && [ -f "$RUST_FILE" ]; then
    sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"
    echo "Rust local LLVM build enabled!"
fi

# =========================================================
# 修复 eBPF 与 Daed 的内核依赖冲突 (终极版)
# =========================================================
echo ">>> [Kernel] 正在修复 eBPF/Daed 编译依赖..."

# 1. 解决 vmlinux-btf 依赖警告
# 因为该分支可能没有单独的 vmlinux-btf 包，我们从 daed 的 Makefile 中强行剔除它
# (只要内核开启了 BTF，不需要这个虚拟包也能正常运行)
find package feeds -name "Makefile" -path "*/daed/*" 2>/dev/null | xargs sed -i 's/+vmlinux-btf//g' 2>/dev/null || true
echo "✅ 移除了 Daed 中的 vmlinux-btf 虚拟依赖。"

# 2. 强行打通内核 BPF 与 TC (Traffic Control) 前置依赖
# 直接向 mediatek/filogic 的内核模板注入，防止被 make oldconfig 静默丢弃
for conf in target/linux/mediatek/filogic/config-*; do
    if[ -f "$conf" ]; then
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
        echo "CONFIG_DEBUG_INFO_BTF=y" >> "$conf"
        
        # --- 3. BPF 极致性能优化 (榨干路由器算力) ---
        echo "CONFIG_BPF_JIT=y" >> "$conf"
        echo "CONFIG_BPF_JIT_ALWAYS_ON=y" >> "$conf"
        # 代理软件 (Daed/Clash) 的神级加速特性 (Sockmap 绕过网络栈)
        echo "CONFIG_BPF_STREAM_PARSER=y" >> "$conf"
        echo "CONFIG_NET_SOCK_MSG=y" >> "$conf"
        # XDP 高速通道
        echo "CONFIG_XDP_SOCKETS=y" >> "$conf"
        
        echo "✅ eBPF 高性能与底层网络调度配置注入完成。"
    fi
done

# 修改默认 IP (192.168.30.1)
sed -i 's/192.168.6.1/192.168.30.1/g' package/base-files/files/bin/config_generate

echo "✅ SSH2 配置完成。"
