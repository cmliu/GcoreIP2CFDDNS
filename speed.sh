#!/bin/bash
# $ ./speed.sh gcore xxxx.com xxxx@gmail.com xxxxxxxxxxxxxxx
export LANG=zh_CN.UTF-8
auth_email="xxxx@gmail.com"    #你的CloudFlare注册账户邮箱 *必填
auth_key="xxxxxxxxxxxxxxx"   #你的CloudFlare账户key,位置在域名概述页面点击右下角获取api key。*必填
zone_name="xxxx.com"     #你的主域名 *必填

area_GEC="gcore"    #自动更新的二级域名前缀,必须取hk sg kr jp us等常用国家代码
port=443 #自定义测速端口 不能为空!!!

speedtestMB=90 #测速文件大小 单位MB，文件过大会拖延测试时长，过小会无法测出准确速度
speedlower=10  #自定义下载速度下限,单位为mb/s
lossmax=0.75  #自定义丢包几率上限；只输出低于/等于指定丢包率的 IP，范围 0.00~1.00，0 过滤掉任何丢包的 IP
speedqueue_max=1 #自定义测速IP冗余量

telegramBotUserId="" # telegram UserId
telegramBotToken="6599852032:AAHhetLKhXfAIjeXgCHpish1DK_NHo3BCrk" #telegram BotToken https://t.me/ACFST_DDNS_bot
telegramBotAPI="api.telegram.ssrc.cf" #telegram 推送API,留空将启用官方API接口:api.telegram.org
###############################################################以下脚本内容，勿动#######################################################################
speedurl="https://speed.cloudflare.com/__down?bytes=$((speedtestMB * 1000000))" #官方测速链接
proxygithub="https://github.ssrc.cf/" #反代github加速地址，如果不需要可以将引号内容删除，如需修改请确保/结尾 例如"https://ghproxy.com/"

#带有地区参数，将赋值第1参数为地区
if [ -n "$1" ]; then 
    record_name="$1"
fi

#带有CloudFlare账户邮箱参数，将赋值第4参数
if [ -n "$3" ]; then
    auth_email="$3"
fi

#带有CloudFlare账户key参数，将赋值第5参数
if [ -n "$4" ]; then
    auth_key="$4"
fi

# 选择客户端 CPU 架构
archAffix(){
    case "$(uname -m)" in
        i386 | i686 ) echo '386' ;;
        x86_64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

update_gengxinzhi=0
apt_update() {
    if [ "$update_gengxinzhi" -eq 0 ]; then
        sudo apt update
        update_gengxinzhi=$((update_gengxinzhi + 1))
    fi
}

apt_install() {
    if ! command -v "$1" &> /dev/null; then
        log "$1 Not installed, start installation..."
        apt_update
        
	if grep -qi "alpine" /etc/os-release; then
		apk add $1
	elif grep -qi "openwrt" /etc/os-release; then
		opkg install $1
	elif grep -qi "ubuntu\|debian" /etc/os-release; then
		sudo apt-get install $1 -y
	elif grep -qi "centos\|red hat\|fedora" /etc/os-release; then
		sudo yum install $1 -y
	else
		log "未能检测出你的系统：$(uname)，请自行安装$1。"
		exit 1
	fi
 
        log "$1 The installation is complete!"
    fi
}

# 检测并安装 Git、Curl、unzip 和 awk
apt_install git
apt_install curl
apt_install unzip
apt_install awk
apt_install jq

TGmessage(){
if [ -z "$telegramBotAPI" ]; then
    telegramBotAPI="api.telegram.org"
fi
#解析模式，可选HTML或Markdown
MODE='HTML'
#api接口
URL="https://${telegramBotAPI}/bot${telegramBotToken}/sendMessage"
if [[ -z ${telegramBotToken} ]]; then
   echo "Telegram 推送通知未配置。"
else
   res=$(timeout 20s curl -s -X POST $URL -d chat_id=${telegramBotUserId}  -d parse_mode=${MODE} -d text="$1")
    if [ $? == 124 ];then
      echo "Telegram API请求超时，请检查网络是否能够访问Telegram或者更换telegramBotAPI。"          
    else
      resSuccess=$(echo "$res" | jq -r ".ok")
      if [[ $resSuccess = "true" ]]; then
        echo "Telegram 消息推送成功！"
      else
        echo "Telegram 消息推送失败，请检查Telegram机器人的telegramBotToken和telegramBotUserId！"
      fi
    fi
fi
}

download_CloudflareST() {
    # 发送 API 请求获取仓库信息（替换 <username> 和 <repo>）
    latest_version=$(curl -s https://api.github.com/repos/XIU2/CloudflareSpeedTest/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$latest_version" ]; then
    	latest_version="v2.2.4"
    	echo "下载版本号: $latest_version"
    else
    	echo "最新版本号: $latest_version"
    fi
    # 下载文件到当前目录
    curl -L -o CloudflareST.tar.gz "${proxygithub}https://github.com/XIU2/CloudflareSpeedTest/releases/download/$latest_version/CloudflareST_linux_$(archAffix).tar.gz"
    # 解压CloudflareST文件到当前目录
    sudo tar -xvf CloudflareST.tar.gz CloudflareST -C /
	rm CloudflareST.tar.gz

}

# 尝试次数
max_attempts=5
current_attempt=1

while [ $current_attempt -le $max_attempts ]; do
    # 检查是否存在CloudflareST文件
    if [ -f "CloudflareST" ]; then
        echo "CloudflareST 准备就绪。"
        break
    else
        echo "CloudflareST 未准备就绪。"
        echo "第 $current_attempt 次下载 CloudflareST ..."
        download_CloudflareST
    fi

    ((current_attempt++))
done

if [ $current_attempt -gt $max_attempts ]; then
    echo "连续 $max_attempts 次下载失败。请检查网络环境时候可以访问github后重试。"
    exit 1
fi

upip(){
    curl -k -o ip.txt https://gcoreip.ssrc.cf
    # 检查下载是否成功
    if [ $? -eq 0 ]; then
      echo "IP库更新成功！"
    else
      echo "IP库更新失败！检查网络或IP库地址错误。"
      exit 1  # 如果下载失败，则退出脚本
    fi
}

# 检查ip.txt文件是否存在
if [ -e "ip.txt" ]; then
    # 获取ip.txt文件的最后编辑时间戳
    file_timestamp=$(stat -c %Y ip.txt)

    # 获取当前时间戳
    current_timestamp=$(date +%s)

    # 计算时间差（以秒为单位）
    time_diff=$((current_timestamp - file_timestamp))

    # 将6小时转换为秒
    eight_hours_in_seconds=$((6 * 3600))

    # 如果时间差小于6小时
    if [ "$time_diff" -lt "$eight_hours_in_seconds" ]; then
        # 继续执行后续脚本逻辑
        echo "ip.txt文件已是最新版本，无需更新"
    else
        echo "ip.txt文件已过期，开始更新IP库"
	upip
    fi
else
    echo "ip.txt文件不存在，开始更新IP库"
    upip
fi

#带有域名参数，将赋值第3参数为地区
if [ -n "$2" ]; then 
    zone_name="$2"
    echo "域名 $2"
fi

#带有自定义测速地址参数，将赋值第6参数为自定义测速地址
if [ -n "$6" ]; then
    speedurl="$6"
    echo "自定义测速地址 $6"
else
    echo "使用默认测速地址 $speedurl"
fi

ip_txt="ip.txt"
result_csv="result.csv"

local_IP=$(curl -s 4.ipw.cn)
#全球IP地理位置API请求和响应示例
local_IP_geo=$(curl -s http://ip-api.com/json/${local_IP}?lang=zh-CN)
# 使用jq解析JSON响应并提取所需的信息
status=$(echo "$local_IP_geo" | jq -r '.status')

if [ "$status" = "success" ]; then
    countryCode=$(echo "$local_IP_geo" | jq -r '.countryCode')
    country=$(echo "$local_IP_geo" | jq -r '.country')
    regionName=$(echo "$local_IP_geo" | jq -r '.regionName')
    city=$(echo "$local_IP_geo" | jq -r '.city')
    # 如果status等于success，则显示地址信息
    # echo "您的地址是 ${country}${regionName}${city}"
    # 判断countryCode是否等于CN
    if [ "$countryCode" != "CN" ]; then
        echo "你的IP地址是 $local_IP ${country}${regionName}${city} 经确认本机网络使用了代理，请关闭代理后重试。"
        exit 1  # 在不是中国的情况下强行退出脚本
    else
        echo "你的IP地址是 $local_IP ${country}${regionName}${city} 经确认本机网络未使用代理..."
    fi
else
    echo "你的IP地址是 $local_IP 地址判断请求失败，请自行确认为本机网络未使用代理..."
fi

echo "待处理域名 ${record_name}.${zone_name} （如您使用的是443端口的话，准备域名无需标注端口号。）"

record_type="A"     
#获取zone_id、record_id
zone_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
# echo $zone_identifier
readarray -t record_identifiers < <(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name.$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*')

record_count=0
for identifier in "${record_identifiers[@]}"; do
	# echo "${record_identifiers[$record_count]}"
	((record_count++))
done
speedqueue=$((record_count + speedqueue_max)) #自定义测速队列，多测2条做冗余

#./CloudflareST -tp 443 -url "https://cs.cmliussss.link" -f "ip/HK.txt" -dn 128 -tl 260 -p 0 -o "log/HK.csv"
./CloudflareST -tp $port -url $speedurl -f $ip_txt -dn $speedqueue -tl 280 -tlr $lossmax -p 0 -sl $speedlower -o $result_csv -dd

TGtext0=""
sed -n '2,20p' $result_csv | while read line
do
    #echo $record_name$record_count'.'$zone_name
    #record_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name"'.'"$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
	
    # 初始化尝试次数
    attempt=0
    
    # 更新DNS记录
    while [[ $attempt -lt 3 ]]
    do
      update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/${record_identifiers[$record_count - 1]}" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" --data "{\"type\":\"$record_type\",\"name\":\"$record_name.$zone_name\",\"content\":\"${line%%,*}\",\"ttl\":60,\"proxied\":false}")
    
      # 反馈更新情况
      if [[ "$update" != "${update%success*}" ]] && [[ "$(echo $update | grep "\"success\":true")" != "" ]]; then
        TGtext=$record_name'.'$zone_name' 更新成功: '${line%%,*}
        echo $TGtext
        break
      elif [[ "$update" != "${update%success*}" ]] && [[ "$(echo $update | grep "\"code\":81058")" != "" ]]; then
        TGtext=$record_name'.'$zone_name' 维护成功: '${line%%,*}
        echo $TGtext
        break
      else
        TGtext=$record_name'.'$zone_name' 更新失败: '${update}
        echo $TGtext
        attempt=$(( $attempt + 1 ))
        echo "尝试次数: $attempt, 1分钟后将再次尝试更新..."
        sleep 60
      fi
    done
    
    TGtext0="$TGtext0%0A$TGtext"
    record_count=$(($record_count-1))    #二级域名序号递减
    #echo $record_count
    if [ $record_count -eq 0 ]; then
        TGmessage "ACFST_DDNS更新完成！%0A地区:$record_name 	端口:$port $TGtext0"
        break
    fi

done
