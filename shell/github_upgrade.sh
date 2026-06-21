#!/bin/sh

# =====================================================
# ImmortalWrt / OpenWrt 固件在线升级脚本
# 仓库: gooyjq/ImmortalWrt-Builder | 标签: Autobuild-x86-64
# =====================================================
#
# 用法:
#   github_upgrade.sh             检查固件是否有更新
#   github_upgrade.sh --check     同上
#   github_upgrade.sh --upgrade   备份 + 下载 + 保留配置升级
#   github_upgrade.sh --backup    仅创建配置备份
#   github_upgrade.sh --reset     重置检测记录

REPO="gooyjq/ImmortalWrt-Builder"
TAG="Autobuild-x86-64"
PROXY="https://ghfast.top/"

API_URL="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
TMP_JSON="/tmp/release.json"
TMP_FIRMWARE="/tmp/firmware.img.gz"

TS=$(date +%Y%m%d-%H%M%S)
BACKUP_TMP="/tmp/pre-upgrade-backup-${TS}.tar.gz"
BACKUP_ROOT="/root/pre-upgrade-backup-${TS}.tar.gz"
STATE_FILE="/root/.firmware_latest_ts"

MODE="${1:-check}"

echo "========================================"
echo "  ImmortalWrt 固件在线升级"
echo "  仓库: ${REPO}  |  标签: ${TAG}"
echo "========================================"

# ===== 工具函数 =====
utc_to_local() {
    local utc_str="$1"
    local clean=$(echo "$utc_str" | sed 's/T/ /' | sed 's/Z//')
    local epoch_as_local=$(date -d "$clean" +%s 2>/dev/null)
    [ -z "$epoch_as_local" ] || [ "$epoch_as_local" = "0" ] && { echo "$utc_str"; return; }
    local epoch_utc=$((epoch_as_local + 8 * 3600))
    date -d "@${epoch_utc}" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$utc_str"
}

# 修复 SmartDNS（缺 smartdns-ui 包导致 ui=1 时无法启动）
smartdns_fix() {
    echo ""
    echo "[预检] SmartDNS 未运行，尝试修复..."
    UI_ENABLED=0
    [ "$(uci get smartdns.@smartdns[0].ui 2>/dev/null)" = "1" ] && UI_ENABLED=1

    if [ "${UI_ENABLED}" = "1" ] && ! [ -f /usr/lib/smartdns_ui.so ]; then
        # 先临时禁用 UI 让 SmartDNS 启动（恢复 DNS 解析）
        uci set smartdns.@smartdns[0].ui="0"
        uci commit smartdns
        /etc/init.d/smartdns restart 2>/dev/null
        sleep 2
        if /etc/init.d/smartdns status | grep -q "running"; then
            # DNS 通了，装包
            apk add smartdns-ui 2>/dev/null
            uci set smartdns.@smartdns[0].ui="1"
            uci commit smartdns
            /etc/init.d/smartdns restart 2>/dev/null
            sleep 2
        fi
    else
        /etc/init.d/smartdns restart 2>/dev/null
        sleep 2
    fi
    /etc/init.d/smartdns status | grep -q "running" && echo "  SmartDNS 已恢复运行 ✓"
}

# ===== 重置检测记录 =====
if [ "${MODE}" = "--reset" ]; then
    rm -f "${STATE_FILE}"
    echo "检测记录已重置。"
    exit 0
fi

# ===== 仅备份模式 =====
if [ "${MODE}" = "--backup" ]; then
    echo ""
    echo "正在创建配置备份..."
    sysupgrade -b "${BACKUP_TMP}"
    if [ $? -eq 0 ] && [ -s "${BACKUP_TMP}" ]; then
        cp "${BACKUP_TMP}" "${BACKUP_ROOT}"
        echo "备份成功: ${BACKUP_TMP} ($(du -h "${BACKUP_TMP}" | cut -f1))"
        echo "存档: ${BACKUP_ROOT}"
    else
        echo "错误：备份失败！"
        exit 1
    fi
    exit 0
fi

# ===== 预检 SmartDNS =====
if command -v smartdns >/dev/null 2>&1; then
    /etc/init.d/smartdns status 2>&1 | grep -q "running" || smartdns_fix
fi

# ===== 获取 Release 信息 =====
echo ""
echo "[1/3] 正在获取 Release 信息..."
HTTP_CODE=$(curl -sL -o "${TMP_JSON}" -w "%{http_code}" "${API_URL}")
if [ "${HTTP_CODE}" != "200" ]; then
    echo "错误：GitHub API 返回 HTTP ${HTTP_CODE}"
    case "${HTTP_CODE}" in
        404) echo "提示：仓库或标签不存在" ;;
        403) echo "提示：API 速率限制" ;;
        *)   echo "提示：网络异常" ;;
    esac
    rm -f "${TMP_JSON}"
    exit 1
fi

# ===== 查找固件文件 =====
echo ""
echo "[2/3] 正在查找最新固件..."
FILE_NAMES=$(cat "${TMP_JSON}" | jsonfilter -e "@.assets[*].name")
FILE_NAME=$(echo "${FILE_NAMES}" | grep -E "combined-efi.*\.img\.gz$" | head -1)
[ -z "${FILE_NAME}" ] && FILE_NAME=$(echo "${FILE_NAMES}" | grep -E "combined.*\.img\.gz$" | head -1)
if [ -z "${FILE_NAME}" ]; then
    echo "错误：未找到 .img.gz 固件"
    rm -f "${TMP_JSON}"
    exit 1
fi

FIRMWARE_VER=$(echo "${FILE_NAME}" | sed -n "s/immortalwrt-\([0-9.]*\)-.*/\1/p")
[ -z "${FIRMWARE_VER}" ] && FIRMWARE_VER="未知（${TAG}）"
ASSET_UPDATED=$(cat "${TMP_JSON}" | jsonfilter -e "@.assets[@.name=\"${FILE_NAME}\"].updated_at")
ASSET_UPDATED_LOCAL=$(utc_to_local "${ASSET_UPDATED}")
ASSET_SIZE=$(cat "${TMP_JSON}" | jsonfilter -e "@.assets[@.name=\"${FILE_NAME}\"].size")
DOWNLOAD_URL=$(cat "${TMP_JSON}" | jsonfilter -e "@.assets[@.name=\"${FILE_NAME}\"].browser_download_url")
rm -f "${TMP_JSON}"

# ===== 判断是否有新固件 =====
NEW_FIRMWARE=0
LAST_TS=""
[ -f "${STATE_FILE}" ] && LAST_TS=$(head -1 "${STATE_FILE}")
if [ -z "${LAST_TS}" ]; then
    NEW_FIRMWARE=1
    UPDATE_REASON="首次检测"
elif [ "${LAST_TS}" != "${ASSET_UPDATED}" ]; then
    NEW_FIRMWARE=1
    UPDATE_REASON="固件已重新编译（${ASSET_UPDATED_LOCAL}）"
else
    UPDATE_REASON="固件无变化（${ASSET_UPDATED_LOCAL}）"
fi
echo "${ASSET_UPDATED}" > "${STATE_FILE}"

# ===== 显示信息 =====
echo ""
echo "============================================"
echo "  固件状态"
echo "============================================"
CURRENT_ID=$(grep "DISTRIB_ID" /etc/openwrt_release 2>/dev/null | cut -d"'" -f2)
CURRENT_REL=$(grep "DISTRIB_RELEASE" /etc/openwrt_release 2>/dev/null | cut -d"'" -f2)
CURRENT_REV=$(grep "DISTRIB_REVISION" /etc/openwrt_release 2>/dev/null | cut -d"'" -f2 | sed "s/r//")
CURRENT_DESC=$(grep "DISTRIB_DESCRIPTION" /etc/openwrt_release 2>/dev/null | cut -d"'" -f2)
echo "  当前固件: ${CURRENT_ID} ${CURRENT_REL} (r${CURRENT_REV})"
echo "  描述:     ${CURRENT_DESC}"
echo ""
echo "  最新固件: ${FILE_NAME}"
echo "  版本号:   ${FIRMWARE_VER}"
echo "  文件大小: $(printf "%.0f MB" $((${ASSET_SIZE:-0} / 1024 / 1024)) 2>/dev/null)"
echo "  编译时间: ${ASSET_UPDATED_LOCAL}"
echo "  检测依据: ${UPDATE_REASON}"
echo "============================================"
[ "${NEW_FIRMWARE}" = "1" ] && echo "" && echo "  >>> 发现新固件！建议执行升级 <<<"

# ===== 检查模式 =====
if [ "${MODE}" != "--upgrade" ]; then
    echo ""
    echo "  升级: sh /bin/github_upgrade.sh --upgrade"
    echo "  备份: sh /bin/github_upgrade.sh --backup"
    exit 0
fi

# ====================================================================
#  升级模式
# ====================================================================
echo ""
echo "============================================"
echo "  [升级模式]"
echo "============================================"

# ---- Step A: 创建配置备份 ----
echo ""
echo "Step A: 创建配置备份..."
sysupgrade -b "${BACKUP_TMP}"
if [ $? -ne 0 ] || [ ! -s "${BACKUP_TMP}" ]; then
    echo "错误：配置备份失败！"
    exit 1
fi
cp "${BACKUP_TMP}" "${BACKUP_ROOT}"
BACKUP_SIZE=$(du -h "${BACKUP_TMP}" | cut -f1)
echo "  备份: ${BACKUP_TMP} (${BACKUP_SIZE})"
echo "  存档: ${BACKUP_ROOT}"

# ---- Step B: 下载固件 ----
FULL_URL="${PROXY}${DOWNLOAD_URL}"
echo ""
echo "Step B: 下载固件..."
curl -sL -o "${TMP_FIRMWARE}" "${FULL_URL}" --progress-bar 2>&1
if [ $? -ne 0 ] || [ ! -s "${TMP_FIRMWARE}" ]; then
    echo "错误：下载失败！"
    rm -f "${TMP_FIRMWARE}"
    exit 1
fi
echo "  下载成功 ($(du -h "${TMP_FIRMWARE}" | cut -f1))"

# ---- Step C: 写入备份到 /boot/ ----
echo ""
echo "Step C: 写入精简备份到 boot 分区..."

# 创建完整备份，然后用 tar 过滤掉 OpenClash 大文件
sysupgrade -b /tmp/bu_full.tar.gz 2>/dev/null
tar xzf /tmp/bu_full.tar.gz -C /tmp 2>/dev/null

# 删除 OpenClash 数据文件（保留配置文件）
rm -rf /tmp/etc/openclash/GeoIP.dat \
       /tmp/etc/openclash/GeoSite.dat \
       /tmp/etc/openclash/ASN.mmdb \
       /tmp/etc/openclash/Country.mmdb \
       /tmp/etc/openclash/cache.db \
       /tmp/etc/openclash/core \
       /tmp/etc/openclash/rule_provider

# 重新打包到 /boot/（用标准路径，不带 ./ 前缀）
cd /tmp
tar czf /boot/sysupgrade.tgz etc usr lib bin root www 2>/dev/null
cd /
sync
rm -f /tmp/bu_full.tar.gz
echo "  备份已写入 /boot/sysupgrade.tgz ($(ls -lh /boot/sysupgrade.tgz | awk '{print $5}'))"

# ---- sysupgrade ----
echo ""
echo "============================================"
echo "  执行 sysupgrade..."
echo "============================================"
echo ""
echo "  路由器即将重启，请勿断电！"
echo ""

/sbin/sysupgrade "${TMP_FIRMWARE}"
