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

# 修复Rust本地编译LLVM
RUST_FILE="feeds/packages/lang/rust/Makefile"

if [ -f "$RUST_FILE" ]; then
  sed -i 's/download-ci-llvm=true/download-ci-llvm=false/g' "$RUST_FILE"
  echo "✅ Rust 已设置为本地编译 LLVM"
else
  RUST_FILE=$(find feeds/ -type f -name "Makefile" -path "*/lang/rust/*" | head -1)
  if [ -n "$RUST_FILE" ]; then
    sed -i 's/download-ci-llvm=true/download-ci-llvm=false/g' "$RUST_FILE"
    echo "✅ Rust 已设置为本地编译 LLVM (路径: $RUST_FILE)"
  else
    echo "⚠️ 未找到 Rust Makefile，跳过"
  fi
fi

# =========================================================
# 4. 内核配置追加（OpenWrt 25.x / kernel 6.12+）
# =========================================================
for conf in target/linux/mediatek/filogic/config-*; do
cat >> $conf << 'EOF'

# =========================================================
# Cgroup BPF（daed 必需，SOCK_CGROUP_DATA 已被自动选中）
# =========================================================
CONFIG_CGROUP_BPF=y

# =========================================================
# eBPF 增强（BPF/BPF_SYSCALL/BPF_JIT 已是 25.x 默认值）
# =========================================================
CONFIG_BPF_JIT_ALWAYS_ON=y

# =========================================================
# eBPF 网络调度（NET_SCHED 已是默认值）
# =========================================================
CONFIG_NET_CLS_ACT=y
CONFIG_NET_ACT_BPF=m
CONFIG_NET_CLS_BPF=m

# =========================================================
# XDP / 高速数据路径
# =========================================================
CONFIG_XDP_SOCKETS=y
CONFIG_BPF_STREAM_PARSER=y

# =========================================================
# 诊断接口（INET_DIAG 已是默认值）
# =========================================================
CONFIG_INET_TCP_DIAG=y

# =========================================================
# Conntrack 增强（EVENTS/CT_NETLINK 已是默认值）
# =========================================================
CONFIG_NF_CONNTRACK_TIMESTAMP=y
CONFIG_NF_CONNTRACK_LABELS=y

EOF
done

echo "✅ 内核配置已追加（25.x 精简版）"

# =========================================================
# 5. 网络参数优化（sysctl）
# =========================================================
mkdir -p files/etc/sysctl.d/

cat > files/etc/sysctl.d/99-proxy-optimize.conf << 'SYSCTL'
# ---------------------------------------------------------
# Conntrack（daed/代理高并发必需）
# ---------------------------------------------------------
net.netfilter.nf_conntrack_max=32768
net.netfilter.nf_conntrack_tcp_timeout_established=3600
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=120

# ---------------------------------------------------------
# TCP 优化
# ---------------------------------------------------------
net.core.netdev_max_backlog=2048
net.core.somaxconn=2048
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_max_tw_buckets=8192

# ---------------------------------------------------------
# 缓冲区（适配 256MB 路由器）
# ---------------------------------------------------------
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.ipv4.tcp_rmem=4096 131072 4194304
net.ipv4.tcp_wmem=4096 65536 4194304
net.ipv4.udp_mem=8192 12288 16384

# ---------------------------------------------------------
# 本地端口范围
# ---------------------------------------------------------
net.ipv4.ip_local_port_range=1024 65535
SYSCTL

echo "✅ 网络优化参数已写入"

# 修改默认 IP (192.168.30.1)
sed -i 's/192.168.6.1/192.168.30.1/g' package/base-files/files/bin/config_generate

echo "✅ SSH2 配置完成。"
