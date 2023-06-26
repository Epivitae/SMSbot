PROJECT = "smsdemo"
VERSION = "1.0.2"

log.info("main", PROJECT, VERSION)
sys = require("sys")
require "sysplus"

if wdt then --添加硬狗
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end
log.info("main", "Air780E sms forwarder")

socket.setDNS(nil, 1, "119.29.29.29")
socket.setDNS(nil, 2, "223.5.5.5")

mobile.setAuto(1000 * 10)

mobile.ipv6(true)

local buff = {} --缓存消息
bark_url = "https://api.day.app"
bark_key = "GGExpoGmpZm26DvoETdzGE"

-- 辅助发送http Post 请求, 因为http库需要在task里运行
function http_post(url, data, headers)
    sys.taskInit(function()
        for i=1,10 do
            local code, headers, body = http.request("POST", url, headers, data).wait()
            log.info("HTTP response code:", code)
            log.info("HTTP response body:", body)
            if code == 200 then
                break
            end
            sys.wait(5000)
        end
    end)
end

-- 短信转发
function forward_to_bark(num, txt)
    local body = "转发8600：".. num .. "/" .. txt .. "?icon=https://img1.imgtp.com/2023/06/27/jbjkQHjX.jpg"
    log.info("url", body)
    http_post(bark_url .. "/" .. bark_key .. "/" .. body)
end

function forward_to_wechat(num, txt)
    local url = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=a6bfc61f-c31c-4dc0-afdf-1bdf1efd272f"
    local headers = {
        ["Content-Type"] = "application/json"
    }
    local data = {
        msgtype = "text",
        text = {
            content = "转发8600：".. num .. "/" .. txt
        }
    }
    http_post(url, json.encode(data), headers)
end

function forward_to_feishu(num, txt)
    local webhook = 'https://open.feishu.cn/open-apis/bot/v2/hook/279bf7bf-d93a-466c-b97c-50add9199e7c'
    local headers = {
        ["Content-Type"] = "application/json"
    }
    local data = {
        msg_type = "text",
        content = {
            text = "转发8600：".. num .. "/" .. txt
        }
    }
    http_post(webhook, json.encode(data), headers)
end

-- 短信转发
function sms_handler(num, txt)
    -- num 手机号码
    -- txt 文本内容
    log.info("sms", num, txt, txt:toHex())

    -- 转发到 bark
    forward_to_bark(num, txt)

    -- 转发到企业微信群机器人
    forward_to_wechat(num, txt)

    -- 转发到飞书机器人
    forward_to_feishu(num, txt)
end


sys.subscribe("SMS_INC",function(phone,data)
    log.info("notify","got sms",phone,data)
    table.insert(buff,{phone,data})
    sys.publish("SMS_ADD")--推个事件
end)

sys.taskInit(function()
    while true do
        print("ww",collectgarbage("count"))
        while #buff > 0 do--把消息读完
            collectgarbage("collect")--防止内存不足
            local sms = table.remove(buff,1)
            sms_handler(sms[1], sms[2])
        end
        log.info("notify","wait for a new sms~")
        print("zzz",collectgarbage("count"))
        sys.waitUntil("SMS_ADD")
    end
end)

sys.run()
