# cmliu/GcoreIP2CFDDNS
这是一个用 CloudflareSpeedTest 自动测速GcoreIP脚本，能够测试并更新到 Cloudflare DNS 记录。

## 用法
在运行脚本之前，请确保你已经获取了CloudFlare账户邮箱(auth_email)和API密钥(auth_key)。

修改脚本中的配置参数，包括CloudFlare账户邮箱、API密钥、域名等信息。

### 下载脚本：
``` bash
wget -N -P GcoreIP2CFDDNS https://mirror.ghproxy.com/https://raw.githubusercontent.com/cmliu/GcoreIP2CFDDNS/main/speed.sh && cd GcoreIP2CFDDNS && chmod +x speed.sh 
```
### 运行脚本：
``` bash
./speed.sh [二级域名] [更新IP数量] [主域名] [CloudFlare邮箱] [CloudFlare API密钥]
```
### 例如：给gcore.xxxx.com更新4条IP
``` bash
./speed.sh gcore 4 xxxx.com xxxx@gmail.com xxxxxxxxxxxxxxx
```

### 参数说明
二级域名：例如 gcore、cdn、yx 等。

主域名：你的 Cloudflare 主域名。

[CloudFlare邮箱]（可选）：Cloudflare账户邮箱，如果不提供，则使用脚本中的默认邮箱。

[CloudFlare API密钥]（可选）：Cloudflare账户API密钥，如果不提供，则使用脚本中的默认API密钥。

## 推送通知

脚本支持Telegram推送通知，你可以配置 telegramBotUserId 和 telegramBotToken，并选择是否使用官方Telegram API或自定义API。

``` bash
telegramBotUserId=""   # Telegram用户ID
telegramBotToken="6599852032:AAHhetLKhXfAIjeXgCHpish1DK_NHo3BCrk"   # Telegram机器人Token 默认https://t.me/ACFST_DDNS_bot
telegramBotAPI="api.telegram.org"     # Telegram推送API，默认为官方API
```

# 感谢
 [xiaodao2026](https://github.com/xiaodao2026/speed)、[MaxMind](https://www.maxmind.com/)、[P3TERX](https://github.com/P3TERX/GeoLite.mmdb)、[XIU2](https://github.com/XIU2/CloudflareSpeedTest)






