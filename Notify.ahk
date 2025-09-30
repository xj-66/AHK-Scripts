; notify.ahk - 提供本地和xxtui推送通知功能

Notify(msg, title := "通知", type := "info", useLocal := true, useXXTui := false, apiKey := "") {
    if (useLocal) {
        TrayTip(title, msg)
    }
    if (useXXTui && apiKey != "") {
        try {
            SendXXTuiNotification("PowerScript", title, msg, apiKey)
        }
    }
}

SendXXTuiNotification(from, title, content, apiKey) {
    url := "https://www.xxtui.com/xxtui/" . apiKey
    jsonData := "{"
        . '"from":"'    . from    . '",'
        . '"title":"'   . title   . '",'
        . '"content":"' . content . '"'
        . "}"

    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.Open("POST", url, false)
    http.SetRequestHeader("Content-Type", "application/json")
    http.Send(jsonData)

    return http.ResponseText
}
