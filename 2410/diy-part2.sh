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
git clone https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

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
# 4. 内核配置追加
# =========================================================
for conf in target/linux/mediatek/filogic/config-*; do
cat >> $conf << 'EOF'

# =========================================================
# CPU 调度优化
# =========================================================

CONFIG_PREEMPT_VOLUNTARY=y
CONFIG_HZ_250=y
CONFIG_SCHED_AUTOGROUP=y

# =========================================================
# Cgroup v2 完整支持
# =========================================================

CONFIG_CGROUPS=y
CONFIG_CGROUP_BPF=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_SCHED=y

CONFIG_MEMCG=y

CONFIG_SOCK_CGROUP_DATA=y

# =========================================================
# eBPF / Daed 核心
# =========================================================

CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_BPF_UNPRIV_DEFAULT_OFF=y

# =========================================================
# eBPF 网络调度
# =========================================================

CONFIG_NET_SCHED=y
CONFIG_NET_CLS=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_ACT_BPF=m
CONFIG_NET_CLS_BPF=m

# =========================================================
# XDP / 高速数据路径
# =========================================================

CONFIG_XDP_SOCKETS=y
CONFIG_BPF_STREAM_PARSER=y
CONFIG_NET_SOCK_MSG=y

# =========================================================
# 网络命名空间
# =========================================================

CONFIG_NET_NS=y

# =========================================================
# 诊断接口
# =========================================================

CONFIG_INET_DIAG=y
CONFIG_INET_TCP_DIAG=y
CONFIG_PACKET_DIAG=y

# =========================================================
# 网络性能增强
# =========================================================

CONFIG_NET_RX_BUSY_POLL=y
CONFIG_BQL=y
CONFIG_NET_FLOW_LIMIT=y
CONFIG_TCP_FASTOPEN=y

# =========================================================
# MT7986 多核优化
# =========================================================

CONFIG_RPS=y
CONFIG_RFS_ACCEL=y
CONFIG_XPS=y

# =========================================================
# TCP 优化
# =========================================================

CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_TCP_CONG_WESTWOOD=y
CONFIG_TCP_CONG_HTCP=y
CONFIG_TCP_MD5SIG=y
CONFIG_SYN_COOKIES=y

# =========================================================
# Conntrack 优化
# =========================================================

CONFIG_NF_CONNTRACK_EVENTS=y
CONFIG_NF_CONNTRACK_TIMESTAMP=y
CONFIG_NF_CONNTRACK_LABELS=y
CONFIG_NF_CT_NETLINK=y
CONFIG_NF_CT_NETLINK_HELPER=y

# =========================================================
# 硬件加密加速（MT7986）
# =========================================================

CONFIG_CRYPTO_DEV_SAFEXCEL=y
CONFIG_CRYPTO_HW=y
CONFIG_CRYPTO_AES=y
CONFIG_CRYPTO_GCM=y
CONFIG_CRYPTO_CHACHA20POLY1305=y

# =========================================================
# 高速包处理
# =========================================================

CONFIG_GRO_CELLS=y

EOF
done

# =========================================================
# Conntrack 表大小优化（写入 99-custom-network）
# =========================================================
mkdir -p files/etc/sysctl.d/

cat > files/etc/sysctl.d/99-proxy-optimize.conf << 'SYSCTL'
# 连接跟踪表扩大（代理高并发必需）
net.netfilter.nf_conntrack_max=65536
net.netfilter.nf_conntrack_tcp_timeout_established=7200
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=180

# TCP 优化
net.core.somaxconn=4096
net.core.netdev_max_backlog=4096
net.ipv4.tcp_max_syn_backlog=4096
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=1200
net.ipv4.tcp_max_tw_buckets=8192

# UDP 优化
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.udp_mem=8192 131072 16777216

# DNS 缓存优化
net.ipv4.ip_local_port_range=1024 65535

# 开启转发（代理必需）
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
SYSCTL

echo "✅ 代理网络优化参数已写入"

# 修改默认 IP (192.168.30.1)
sed -i 's/192.168.6.1/192.168.30.1/g' package/base-files/files/bin/config_generate

echo "✅ SSH2 配置完成。"
