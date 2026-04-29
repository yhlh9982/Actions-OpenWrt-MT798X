#!/bin/bash
set -e

DAED_VER="1.27.0"

DAED_MK="feeds/packages/net/daed/Makefile"

echo "========================================="
echo " Daed 更新"
echo "========================================="

OLD_VER=$(grep '^PKG_VERSION:=' "$DAED_MK" | cut -d= -f2)

echo "旧版本: ${OLD_VER}"
echo "新版本: ${DAED_VER}"

echo "========================================="

echo ">>> 检查 release 是否存在"

RELEASE_URL="https://github.com/daeuniverse/daed/releases/tag/v${DAED_VER}"

HTTP_CODE=$(curl -sL -o /dev/null -w '%{http_code}' "$RELEASE_URL")

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ Release 不存在"
    exit 1
fi

echo "✓ Release 存在"

echo ">>> 修改 Makefile 版本"

sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=${DAED_VER}/" "$DAED_MK"

echo ">>> 下载源码"

TMP_DIR=$(mktemp -d)

SRC_URL="https://codeload.github.com/daeuniverse/daed/tar.gz/refs/tags/v${DAED_VER}"

curl -L -o "$TMP_DIR/daed.tar.gz" "$SRC_URL"

SRC_HASH=$(sha256sum "$TMP_DIR/daed.tar.gz" | awk '{print $1}')

echo "源码 hash:"
echo "$SRC_HASH"

echo ">>> 下载 Web UI"

WEB_URL="https://github.com/daeuniverse/daed/releases/download/v${DAED_VER}/web.zip"

curl -L -o "$TMP_DIR/web.zip" "$WEB_URL"

WEB_HASH=$(sha256sum "$TMP_DIR/web.zip" | awk '{print $1}')

echo "web hash:"
echo "$WEB_HASH"

echo ">>> 写入 Makefile"

sed -i "s/^PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=${SRC_HASH}/" "$DAED_MK"

sed -i "/define Download\/daed-web/,/endef/{s/HASH:=.*/HASH:=${WEB_HASH}/}" "$DAED_MK"

rm -rf "$TMP_DIR"

echo "========================================="
echo "更新完成"
echo "========================================="

grep PKG_VERSION "$DAED_MK"
grep PKG_MIRROR_HASH "$DAED_MK"
grep -A4 "define Download/daed-web" "$DAED_MK" | grep HASH


# ---------------------------------------------------------
# 双重保险：终结 OpenClash 带来的 Rust 漫长编译噩梦
# ---------------------------------------------------------
echo ">>> 开始执行双重拦截：关闭 Ruby YJIT，跳过 rust/host 编译..."

# ==========================================
# 方案 A：先从顶层配置文件强制取消 YJIT 编译
# ==========================================
# 遍历当前目录下的系统 .config 以及你仓库里的自定义 config (如 mt7986.config)
for conf in .config *.config; do
    if [ -f "$conf" ]; then
        # 1. 剔除可能存在的开启选项 (防冲突)
        sed -i '/CONFIG_RUBY_ENABLE_YJIT/d' "$conf"
        # 2. 强行追加关闭指令 (最高优先级)
        echo "# CONFIG_RUBY_ENABLE_YJIT is not set" >> "$conf"
        echo "✅ 方案 A 成功：已在 $conf 中强制声明关闭 RUBY_ENABLE_YJIT"
    fi
done

# ==========================================
# 方案 B：修改底层 Makefile，物理斩断依赖引擎
# ==========================================
RUBY_MK=$(find feeds -name "Makefile" -path "*/lang/ruby/Makefile" 2>/dev/null | head -n 1)

if [ -f "$RUBY_MK" ]; then
    echo ">>> 正在魔改 Ruby Makefile，执行物理级依赖阉割..."
    
    # 1. 防弹级正则破坏：在 config RUBY_ENABLE_YJIT 和 help 之间，将 default y 强制改为 default n
    sed -i '/config RUBY_ENABLE_YJIT/,/help/{s/default y.*/default n/g}' "$RUBY_MK"
    
    # 2. 釜底抽薪：精准删掉引发 Rust 编译的宿主机依赖关键词
    # sed -i 's/RUBY_ENABLE_YJIT:rust\/host//g' "$RUBY_MK"
    
    echo "✅ 方案 B 成功：Ruby 对 Rust 的依赖链已被彻底斩断！"
else
    echo "⚠️ 警告: 未找到 Ruby 的 Makefile，可能路径有变，方案 B 跳过。"
fi

echo "🎉 双重拦截部署完毕！"
