#!/bin/sh
set -e

# ==============================================================================
# Telegram MTProto Proxy (mtg v2) - Production Entrypoint & Diagnostic Script
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${CYAN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

echo "======================================================================"
echo -e "${BLUE}  🚀 Starting Telegram MTProto Proxy Diagnostics & Service${NC}"
echo "======================================================================"

# 1. بررسی باینری MTG
log_info "[گام ۱/۵] بررسی فایل اجرایی mtg..."
if [ ! -x "/usr/local/bin/mtg" ]; then
    log_error "فایل باینری /usr/local/bin/mtg یافت نشد یا دسترسی اجرایی ندارد!"
    exit 1
fi
MTG_VERSION=$(/usr/local/bin/mtg -v 2>&1 || /usr/local/bin/mtg --version 2>&1 || echo "v2.x")
log_success "باینری mtg تایید شد. نسخه: ${MTG_VERSION}"

# 2. بررسی و اعتبارسنجی پورت
log_info "[گام ۲/۵] اعتبارسنجی پورت (PORT)..."
PORT="${PORT:-443}"
PORT="$(echo "$PORT" | tr -d '[:space:]')"

if ! echo "$PORT" | grep -qE '^[0-9]+$' || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    log_error "پورت نامعتبر است: '${PORT}'. پورت باید عددی بین ۱ تا ۶۵۵۳۵ باشد."
    exit 1
fi
log_success "پورت اتصال تایید شد: ${PORT}"

# 3. بررسی و اعتبارسنجی سکرت
log_info "[گام ۳/۵] بررسی و پالایش سکرت (SECRET)..."
RAW_SECRET="${SECRET:-eed34e5658e41a995252834b92b6a95f7c676f6f676c652e636f6d}"
SECRET="$(echo "$RAW_SECRET" | tr -d '[:space:]' | tr -d '\r' | tr -d '\n')"

if [ -z "$SECRET" ]; then
    log_warn "سکرت خالی بود! سکرت پیش‌فرض google.com جایگزین گردید."
    SECRET="eed34e5658e41a995252834b92b6a95f7c676f6f676c652e636f6d"
fi

SECRET_LEN=${#SECRET}
log_info "طول رشته سکرت: ${SECRET_LEN} کاراکتر"

case "$SECRET" in
  ee*)
    log_success "سکرت معتبر است: حالت ضد فیلتر Fake-TLS فعال است (پیشوند ee)."
    ;;
  dd*)
    log_warn "سکرت با پیشوند dd تشخیص داده شد (حالت استاندارد تلگرام - ممکن است فیلتر شود)."
    ;;
  *)
    log_warn "سکرت فاقد پیشوند ee است! برای جلوگیری از فیلترینگ توصیه می‌شود از سکرت Fake-TLS استفاده کنید."
    ;;
esac

# 4. بررسی وضعیت شبکه و دی‌ان‌اس (DNS)
log_info "[گام ۴/۵] تست اتصال شبکه و بررسی تفکیک نام (DNS)..."
if nslookup telegram.org >/dev/null 2>&1 || nslookup google.com >/dev/null 2>&1; then
    log_success "ارتباط شبکه و DNS کانتینر برقرار است."
else
    log_warn "پاسخ DNS با کمی تاخیر همراه بود اما فرآیند اجرا ادامه می‌یابد."
fi

# 5. ساخت پارامترهای نهایی اجرای MTG
log_info "[گام ۵/۵] آماده‌سازی پرچم‌ها و راه‌اندازی نهایی..."
PREFER_IP="${PREFER_IP:-prefer-ipv4}"
CONCURRENCY="${CONCURRENCY:-8192}"
DOH_IP="${DOH_IP:-1.1.1.1}"

EXTRA_FLAGS=""

if [ "$DEBUG" = "true" ] || [ "$DEBUG" = "1" ]; then
    log_info "حالت دیباگ پرینت جزئیات فعال شد (-d)."
    EXTRA_FLAGS="${EXTRA_FLAGS} -d"
fi

if [ -n "$PREFER_IP" ]; then
    log_info "اولویت مسیریابی آی‌پی تلگرام: ${PREFER_IP}"
    EXTRA_FLAGS="${EXTRA_FLAGS} -i ${PREFER_IP}"
fi

if [ -n "$CONCURRENCY" ]; then
    log_info "حداکثر اتصالات همزمان: ${CONCURRENCY}"
    EXTRA_FLAGS="${EXTRA_FLAGS} -c ${CONCURRENCY}"
fi

if [ -n "$DOH_IP" ]; then
    EXTRA_FLAGS="${EXTRA_FLAGS} -n ${DOH_IP}"
fi

echo "======================================================================"
log_success "پروکسی با موفقیت فعال شد و آماده دریافت اتصالات تلگرام است!"
log_info "آدرس شنود در کانتینر: 0.0.0.0:${PORT}"
log_info "سکرت فعال: ${SECRET}"
echo -e "${YELLOW}👉 در پنل Railway وارد بخش Settings > Networking شده و 'Add TCP Proxy' را فعال کنید.${NC}"
echo "======================================================================"

# نکته مهم ساختاری: پرچم‌ها باید قبل از آرگومان‌های مکانی (IP:PORT و SECRET) قرار گیرند
exec /usr/local/bin/mtg simple-run ${EXTRA_FLAGS} "0.0.0.0:${PORT}" "${SECRET}"
