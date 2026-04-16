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

# 1. 备份原始 feeds
cp feeds.conf.default feeds.conf.default.bak

# 2. NAS feeds
echo >> feeds.conf.default
echo 'src-git nas https://github.com/linkease/nas-packages.git;master' >> feeds.conf.default
echo 'src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main' >> feeds.conf.default

./scripts/feeds update nas nas_luci
./scripts/feeds install -a -p nas
./scripts/feeds install -a -p nas_luci

# 3. iStore feeds
echo >> feeds.conf.default
echo 'src-git istore https://github.com/linkease/istore;main' >> feeds.conf.default

./scripts/feeds update istore
./scripts/feeds install -d y -p istore luci-app-store

mkdir -p package/custom

# 科学插件
# Passwall
# git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/custom/passwall-packages
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall package/custom/passwall
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall2 package/custom/passwall2

# OpenClash
git clone --depth=1 -b dev https://github.com/vernesong/OpenClash.git package/custom/openclash

# Nikki / Momo
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki.git package/custom/nikki
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-momo.git package/custom/momo

# Daed
git clone --depth=1 -b kix https://github.com/QiuSimons/luci-app-daed.git package/custom/daed

# SSR+
git clone --depth=1 https://github.com/fw876/helloworld.git package/custom/ssrp

# 功能插件
git clone --depth=1 https://github.com/sirpdboy/luci-app-poweroffdevice.git package/custom/poweroffdevice
git clone --depth=1 https://github.com/isalikai/luci-app-owq-wol.git package/custom/owq-wol
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/custom/lucky
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2.git package/custom/openlist2

git clone --depth=1 https://github.com/sirpdboy/luci-app-watchdog.git package/custom/watchdog
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/custom/taskplan
git clone --depth=1 https://github.com/iv7777/luci-app-authshield.git package/custom/authshield

# VPN
git clone --depth=1 https://github.com/EasyTier/luci-app-easytier.git package/custom/easytier
git clone --depth=1 https://github.com/Tokisaki-Galaxy/luci-app-tailscale-community.git package/custom/tailscale-community

# 主题
git clone --depth=1 -b openwrt-25.12 https://github.com/sbwml/luci-theme-argon.git package/custom/luci-theme-argon

git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora.git package/custom/luci-theme-aurora
git clone --depth=1 https://github.com/eamonxg/luci-app-aurora-config.git package/custom/luci-app-aurora-config

git clone --depth=1 https://github.com/sirpdboy/luci-theme-kucat.git package/custom/luci-theme-kucat
git clone --depth=1 https://github.com/sirpdboy/luci-app-kucat-config.git package/custom/luci-app-kucat-config
