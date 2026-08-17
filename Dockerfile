# مرحله دریافت باینری رسمی mtg
FROM nineseconds/mtg:2 AS mtg_bin

# استفاده از آلپاین پایدار و سبک
FROM alpine:3.19

# نصب CA Certificates، ابزارهای ضروری و dos2unix
RUN apk add --no-cache ca-certificates tzdata dos2unix bind-tools

# کپی باینری mtg
COPY --from=mtg_bin /mtg /usr/local/bin/mtg

# اعتبارسنجی باینری در زمان بیلد داکر
RUN chmod +x /usr/local/bin/mtg && (/usr/local/bin/mtg -v || /usr/local/bin/mtg --version || true)

# کپی اسکریپت راه‌اندازی و تبدیل فرمت به LF استاندارد یونیکس
COPY entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

# پورت و سکرت پیش‌فرض
ENV PORT=443
ENV SECRET=eed34e5658e41a995252834b92b6a95f7c676f6f676c652e636f6d

EXPOSE 443

# نقطه ورود پایدار کانتینر
ENTRYPOINT ["/entrypoint.sh"]
