#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# 1. 创建临时配置文件
cat <<EOF > /tmp/temp_feeds.conf
src-git packages $CUSTOM_PACKAGES_URL
src-git luci $CUSTOM_LUCI_URL
EOF

# 2. 通过环境变量指定配置路径
export FEEDS_CONF=/tmp/temp_feeds.conf

# 科学插件
# Passwall 
# echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git' >> feeds.conf.default
echo 'src-git passwall https://github.com/Openwrt-Passwall/openwrt-passwall.git' >> feeds.conf.default
echo 'src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git' >> feeds.conf.default
# OpenClash 
echo 'src-git openclash https://github.com/vernesong/OpenClash.git' >> feeds.conf.default
# Nikki / Momo
echo 'src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git' >> feeds.conf.default
echo 'src-git momo https://github.com/nikkinikki-org/OpenWrt-momo.git' >> feeds.conf.default
# Daed (指定 kix 分支)
echo 'src-git daed https://github.com/QiuSimons/luci-app-daed.git;kix' >> feeds.conf.default
# Helloworld (SSR+)
echo 'src-git helloworld https://github.com/fw876/helloworld.git' >> feeds.conf.default

# === 功能插件 Feeds ===
# Lucky (大吉大利，端口转发/反向代理神器)
echo 'src-git lucky https://github.com/gdy666/luci-app-lucky.git' >> feeds.conf.default
# Openlist2 (可能是指 OpenList 或相关列表工具)
echo 'src-git openlist2 https://github.com/sbwml/luci-app-openlist2.git' >> feeds.conf.default
# Sirpdboy 的插件 (看门狗 & 计划任务)
echo 'src-git watchdog https://github.com/sirpdboy/luci-app-watchdog.git' >> feeds.conf.default
echo 'src-git taskplan https://github.com/sirpdboy/luci-app-taskplan.git' >> feeds.conf.default
# Authshield (认证屏蔽/管理)
echo 'src-git authshield https://github.com/iv7777/luci-app-authshield.git' >> feeds.conf.default
# EasyTier (内网穿透组网)
echo 'src-git easytier https://github.com/EasyTier/luci-app-easytier.git' >> feeds.conf.default
# Tailscale Community (注意：改名为 tailscale_community 以防与官方 packages 里的 tailscale 混淆)
echo 'src-git tailscale_community https://github.com/Tokisaki-Galaxy/luci-app-tailscale-community.git' >> feeds.conf.default
# OWQ WOL (网络唤醒)
echo 'src-git owq_wol https://github.com/isalikai/luci-app-owq-wol.git' >> feeds.conf.default

# 主题
git clone --depth=1 -b openwrt-25.12 https://github.com/sbwml/luci-theme-argon package/argon
echo 'src-git aurora https://github.com/eamonxg/luci-theme-aurora.git' >> feeds.conf.default
echo 'src-git aurora_config https://github.com/eamonxg/luci-app-aurora-config.git' >> feeds.conf.default
echo 'src-git kucat https://github.com/sirpdboy/luci-theme-kucat.git' >> feeds.conf.default
echo 'src-git kucat_config https://github.com/sirpdboy/luci-app-kucat-config.git' >> feeds.conf.default
