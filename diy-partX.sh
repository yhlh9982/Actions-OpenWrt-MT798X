#!/bin/bash

# Daed 预编译二进制注入 - 整体覆盖方案
#

set -e

echo ">>> Daed 预编译二进制注入"

# =========================================================
# 1. 定位 daed 目录
# =========================================================
DAED_DIR=$(find . -path "*/daed/daed" -type d 2>/dev/null | head -n 1)

if [ -z "$DAED_DIR" ]; then
    echo "❌ 未找到 daed 目录"
    exit 1
fi

echo ">>> daed 目录: $DAED_DIR"

# =========================================================
# 2. 验证 files 目录（init 脚本 + uci 配置）
# =========================================================
if [ ! -f "$DAED_DIR/files/daed.init" ] || [ ! -f "$DAED_DIR/files/daed.config" ]; then
    echo "❌ 缺少 files/daed.init 或 files/daed.config"
    ls -la "$DAED_DIR/files/" 2>/dev/null || echo "files 目录不存在"
    exit 1
fi

echo "✅ init 脚本和 uci 配置存在"

# =========================================================
# 3. 下载预编译二进制
# =========================================================
echo ">>> 下载 Daed arm64..."

curl -fL --connect-timeout 30 --max-time 300 --retry 3 \
    -o /tmp/daed.zip \
    https://github.com/daeuniverse/daed/releases/latest/download/daed-linux-arm64.zip

unzip -o /tmp/daed.zip -d /tmp/tmp_daed

# ✅ 修正：用 find 定位，兼容 zip 内有无子目录
DAED_BIN=$(find /tmp/tmp_daed -name "daed-linux-arm64" -type f | head -n 1)

if [ -z "$DAED_BIN" ]; then
    echo "❌ 未找到 daed-linux-arm64，zip 内容："
    find /tmp/tmp_daed -type f
    exit 1
fi

if file "$DAED_BIN" | grep -q "aarch64"; then
    echo "✅ 架构验证: ARM64"
else
    echo "⚠️  架构: $(file "$DAED_BIN")"
fi

mkdir -p "$DAED_DIR/prebuilt"
cp "$DAED_BIN" "$DAED_DIR/prebuilt/daed"
chmod +x "$DAED_DIR/prebuilt/daed"

rm -rf /tmp/daed.zip /tmp/tmp_daed

echo "✅ 二进制已就位: $DAED_DIR/prebuilt/daed"

# =========================================================
# 4. 覆盖 Makefile
# =========================================================
echo ">>> 覆盖 Makefile"

cat > "$DAED_DIR/Makefile" << 'MKEOF'
# SPDX-License-Identifier: GPL-2.0-only
#
# Daed prebuilt binary package
#

include $(TOPDIR)/rules.mk

PKG_NAME:=daed
PKG_VERSION:=prebuilt
PKG_RELEASE:=1

PKG_LICENSE:=AGPL-3.0-only MIT
PKG_MAINTAINER:=Tianling Shen <cnsztl@immortalwrt.org>

include $(INCLUDE_DIR)/package.mk

define Package/daed
@@TAB@@SECTION:=net
@@TAB@@CATEGORY:=Network
@@TAB@@SUBMENU:=Web Servers/Proxies
@@TAB@@TITLE:=A Modern Dashboard For dae (prebuilt)
@@TAB@@URL:=https://github.com/daeuniverse/daed
@@TAB@@DEPENDS:= \
@@TAB@@@@TAB@@+ca-bundle \
@@TAB@@@@TAB@@+kmod-sched-core \
@@TAB@@@@TAB@@+kmod-sched-bpf \
@@TAB@@@@TAB@@+kmod-xdp-sockets-diag \
@@TAB@@@@TAB@@+kmod-veth \
@@TAB@@@@TAB@@+v2ray-geoip \
@@TAB@@@@TAB@@+v2ray-geosite
endef

define Package/daed/description
@@TAB@@daed is a backend of dae, provides a method to bundle arbitrary
@@TAB@@frontend, dae and geodata into one binary. (prebuilt binary)
endef

define Package/daed/conffiles
/etc/daed/wing.db
/etc/config/daed
endef

define Build/Prepare
@@TAB@@mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
@@TAB@@@true
endef

define Package/daed/install
@@TAB@@$(INSTALL_DIR) $(1)/usr/bin
@@TAB@@$(INSTALL_BIN) $(CURDIR)/prebuilt/daed $(1)/usr/bin/daed

@@TAB@@$(INSTALL_DIR) $(1)/etc/config
@@TAB@@$(INSTALL_CONF) $(CURDIR)/files/daed.config $(1)/etc/config/daed

@@TAB@@$(INSTALL_DIR) $(1)/etc/init.d
@@TAB@@$(INSTALL_BIN) $(CURDIR)/files/daed.init $(1)/etc/init.d/daed

@@TAB@@$(INSTALL_DIR) $(1)/etc/daed

@@TAB@@$(INSTALL_DIR) $(1)/usr/share/daed
@@TAB@@$(LN) ../v2ray/geoip.dat $(1)/usr/share/daed/geoip.dat
@@TAB@@$(LN) ../v2ray/geosite.dat $(1)/usr/share/daed/geosite.dat
endef

$(eval $(call BuildPackage,daed))
MKEOF

sed -i 's/@@TAB@@/\t/g' "$DAED_DIR/Makefile"

# =========================================================
# 5. 验证
# =========================================================
# ✅ 修正：直接用 grep 退出码
if grep -qP '^\t' "$DAED_DIR/Makefile"; then
    echo "✅ TAB 缩进验证通过"
else
    echo "❌ TAB 缩进异常"
    exit 1
fi

echo ""
echo "✅ 完成"
echo ""
echo "   跳过："
echo "   ├── git clone 源码仓库"
echo "   ├── golang 工具链编译"
echo "   ├── Node.js / pnpm 前端构建"
echo "   ├── Go + BPF 编译"
echo "   └── 预计节省 30~50 分钟"
echo ""
echo "   保留："
echo "   ├── /usr/bin/daed                      (预编译二进制)"
echo "   ├── /etc/init.d/daed                   (原始 init 脚本)"
echo "   ├── /etc/config/daed                   (原始 uci 配置)"
echo "   ├── /etc/daed/                         (数据目录)"
echo "   ├── /usr/share/daed/geoip.dat → v2ray  (符号链接)"
echo "   ├── /usr/share/daed/geosite.dat → v2ray(符号链接)"
echo "   └── 运行时依赖自动安装"
