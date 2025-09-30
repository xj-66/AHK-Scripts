/*
    AutoHotkey v2 脚本：自动切换 Windows 电源计划
    功能：
      - 检测系统锁屏/解锁状态
      - 检测用户空闲时长
      - 锁屏或空闲时切换到节能，解锁时切换到高性能
      - UI 可设置 GUID、检测间隔、空闲切换秒数
      - 通知支持本地和xxtui推送
    作者：x.j
    日期：2025-09-28
*/
#Requires AutoHotkey v2.0

global lastState := ""  ; "locked", "unlocked", "idle"
global uiWin := 0
global timeText := 0
global stateText := 0
global guidSaverEdit := 0
global guidHighEdit := 0
global intervalEdit := 0
global idleEdit := 0
global descText := 0
global cbLocalNotify := 0
global cbXXTuiNotify := 0
global xxtuiKeyEdit := 0

global ConfigFileName := "PowerSchemeSwitcher.ini"  ; 配置文件名

; 包含通知功能
#Include Notify.ahk
#Include ConfigUtils.ahk

; 加载配置
LoadConfig()

SetTimer(CheckLockScreen, TimerInterval)

A_TrayMenu.Delete()
A_TrayMenu.Add("显示状态", ShowStatusUI)
A_TrayMenu.Add("重载脚本", (*) => Reload())
A_TrayMenu.Add("退出", (*) => ExitApp())
TraySetIcon("shell32.dll", 167)
; 设置鼠标悬停在托盘图标上时显示的信息
A_IconTip := "自动切换电源计划 - x.j"

OnMessage(0x404, TrayClick)

; 安全取控件值，避免 "The control is destroyed"
SafeGet(ctrl, def := "") {
    try {
        return ctrl.Value
    } catch {
        return def
    }
}

; 设置配置结构
declareConfigStructure() {
    static configStructure := {}
    configStructure.PowerScheme := {}
    configStructure.PowerScheme.PowerSaverGUID := "f0f87f1d-03f0-434d-abb5-b58449761cb3"
    configStructure.PowerScheme.HighPerformanceGUID := "4cf5110b-e621-4a75-a90d-793a640aa02a"
    configStructure.PowerScheme.TimerInterval := "1000"
    configStructure.PowerScheme.IdleSeconds := "300"
    
    configStructure.Notification := {}
    configStructure.Notification.UseLocalNotify := "0"
    configStructure.Notification.UseXXTuiNotify := "1"
    configStructure.Notification.ApiKey := ""
    
    return configStructure
}

; 加载配置函数
LoadConfig() {
    global PowerSaverGUID, HighPerformanceGUID, TimerInterval, IdleSeconds
    global UseLocalNotify, UseXXTuiNotify, ApiKey
    global ConfigFileName
    
    configPath := A_ScriptDir "\" ConfigFileName
    
    ; 如果配置文件不存在，则创建默认配置
    if (!FileExist(configPath)) {
        ConfigUtils.CreateDefault(configPath, declareConfigStructure())
    }
    
    ; 从配置文件读取设置
    configObj := ConfigUtils.Load(configPath, declareConfigStructure())
    
    PowerSaverGUID := configObj.PowerScheme.PowerSaverGUID
    HighPerformanceGUID := configObj.PowerScheme.HighPerformanceGUID
    TimerInterval := configObj.PowerScheme.TimerInterval
    IdleSeconds := configObj.PowerScheme.IdleSeconds
    
    UseLocalNotify := configObj.Notification.UseLocalNotify
    UseXXTuiNotify := configObj.Notification.UseXXTuiNotify
    ApiKey := configObj.Notification.ApiKey
}

; 创建默认配置文件
CreateDefaultConfig(configPath) {
    global ConfigFileName
    ConfigUtils.CreateDefault(configPath, declareConfigStructure())
}

; 保存配置函数
SaveConfig() {
    global PowerSaverGUID, HighPerformanceGUID, TimerInterval, IdleSeconds
    global UseLocalNotify, UseXXTuiNotify, ApiKey
    global ConfigFileName
    
    configPath := A_ScriptDir "\" ConfigFileName
    
    configData := {}
    configData.PowerScheme := {}
    configData.PowerScheme.PowerSaverGUID := PowerSaverGUID
    configData.PowerScheme.HighPerformanceGUID := HighPerformanceGUID
    configData.PowerScheme.TimerInterval := TimerInterval
    configData.PowerScheme.IdleSeconds := IdleSeconds
    
    configData.Notification := {}
    configData.Notification.UseLocalNotify := UseLocalNotify
    configData.Notification.UseXXTuiNotify := UseXXTuiNotify
    configData.Notification.ApiKey := ApiKey
    
    ConfigUtils.Save(configPath, configData)
}

CheckLockScreen() {
    global lastState, PowerSaverGUID, HighPerformanceGUID, uiWin, IdleSeconds
    global UseLocalNotify, UseXXTuiNotify, ApiKey

    locked  := IsScreenLocked()
    idleMs  := A_TimeIdle
    idleSec := idleMs // 1000
    nowTime := FormatTime(, "yyyy-MM-dd HH:mm:ss")

    ; 获取通知设置（安全访问）
    ; 用安全函数取值，避免控件被销毁时报错
    useLocal := UseLocalNotify
    useXXTui := UseXXTuiNotify

    if (locked) {
        if (lastState != "locked") {
            Run("powercfg /setactive " PowerSaverGUID, , "Hide")
            Notify(nowTime " - 已切换到节能（锁屏）", "电源切换", "info", useLocal, useXXTui, ApiKey)
            lastState := "locked"
        }
    } else if (idleSec >= IdleSeconds) {
        if (lastState != "idle") {
            Run("powercfg /setactive " PowerSaverGUID, , "Hide")
            Notify(nowTime " - 已切换到节能（空闲" idleSec "秒）", "电源切换", "info", useLocal, useXXTui, ApiKey)
            lastState := "idle"
        }
    } else {
        if (lastState != "unlocked") {
            Run("powercfg /setactive " HighPerformanceGUID, , "Hide")
            Notify(nowTime " - 已切换到高性能", "电源切换", "info", useLocal, useXXTui, ApiKey)
            lastState := "unlocked"
        }
    }

    if uiWin && WinExist("ahk_id " uiWin.Hwnd)
        UpdateUIStatus()
}

IsScreenLocked() {
    return ProcessExist("LogonUI.exe")
}

ShowStatusUI(*) {
    global uiWin, timeText, stateText
    global guidSaverEdit, guidHighEdit, intervalEdit, idleEdit, descText
    global PowerSaverGUID, HighPerformanceGUID, TimerInterval, IdleSeconds
    global cbLocalNotify, cbXXTuiNotify, xxtuiKeyEdit
    global UseLocalNotify, UseXXTuiNotify, ApiKey

    defaultWidth := "w300"

    if uiWin && WinExist("ahk_id " uiWin.Hwnd) {
        uiWin.Show()
        return
    }
    uiWin := Gui(, "自动切换电源计划 - x.j")
    uiWin.OnEvent("Close", (*) => uiWin := 0)
    uiWin.OnEvent("Escape", (*) => uiWin := 0)

    uiWin.AddText(defaultWidth, "AutoHotkey 电源计划自动切换脚本")
    uiWin.AddText(defaultWidth, "检测锁屏/解锁/空闲自动切换电源计划")
    uiWin.AddText(defaultWidth, "获取电源计划GUID：powercfg /list")

    ; 添加GitHub链接
    githubLink := uiWin.AddLink("w300", "欢迎Star: <a href=`"https://github.com/xj-66/AHK-Scripts`">https://github.com/xj-66/AHK-Scripts</a>")
    githubLink.OnEvent("Click", (*) => Run("https://github.com/xj-66/AHK-Scripts"))
    uiWin.AddText(defaultWidth, "-----------------------------------")

    uiWin.AddText("w110", "节能GUID：")
    guidSaverEdit := uiWin.AddEdit("w300", PowerSaverGUID)

    uiWin.AddText("w110", "高性能GUID：")
    guidHighEdit := uiWin.AddEdit("w300", HighPerformanceGUID)

    uiWin.AddText("w110", "检测间隔(毫秒)：")
    intervalEdit := uiWin.AddEdit("w210", TimerInterval)

    uiWin.AddText("w110", "空闲切换秒数：")
    idleEdit := uiWin.AddEdit("w210", IdleSeconds)

    ; 新增通知设置
    cbLocalNotify := uiWin.AddCheckBox("w150 h20", "本地托盘通知")
    cbXXTuiNotify := uiWin.AddCheckBox("w150 h20", "xxtui推送通知")
    uiWin.AddText("w110", "API_KEY：")
    xxtuiKeyEdit := uiWin.AddEdit("w300", ApiKey)
    
    ; 根据配置设置复选框状态
    if (UseLocalNotify = 1)
        cbLocalNotify.Value := 1
    if (UseXXTuiNotify = 1)
        cbXXTuiNotify.Value := 1

    ; 添加测试按钮和获取API_KEY按钮在同一行
    testBtn := uiWin.AddButton("w120", "测试推送通知")
    testBtn.OnEvent("Click", TestXXTuiNotification)
    
    ; 添加获取API_KEY按钮
    getApiKeyBtn := uiWin.AddButton("w120 xp+130 yp", "获取API_KEY")
    getApiKeyBtn.OnEvent("Click", GetApiKeyInstructions)
    
    ; 重置x坐标，避免影响后续控件
    uiWin.AddText("xm", "") ; 通过添加一个文本控件重置x坐标
    
    saveBtn := uiWin.AddButton("w70", "保存设置")
    saveBtn.OnEvent("Click", SaveSettings)

    uiWin.AddText(defaultWidth, "-----------------------------------")

    timeText := uiWin.AddText(defaultWidth " h30", "")
    stateText := uiWin.AddText(defaultWidth " h30", "")

    ; 置顶
    ; uiWin.Opt("+AlwaysOnTop")
    uiWin.Show()
    UpdateUIStatus()
}

SaveSettings(*) {
    global guidSaverEdit, guidHighEdit, intervalEdit, idleEdit
    global PowerSaverGUID, HighPerformanceGUID, TimerInterval, IdleSeconds
    global cbLocalNotify, cbXXTuiNotify, xxtuiKeyEdit
    global UseLocalNotify, UseXXTuiNotify, ApiKey

    PowerSaverGUID := guidSaverEdit.Value
    HighPerformanceGUID := guidHighEdit.Value
    newInterval := intervalEdit.Value
    newIdle := idleEdit.Value

    if !RegExMatch(newInterval, "^\d+$") || newInterval < 1000 {
        MsgBox("检测间隔必须为大于1000的数字！", "错误", 48)
        intervalEdit.Value := TimerInterval
        return
    }
    if !RegExMatch(newIdle, "^\d+$") || newIdle < 10 {
        MsgBox("空闲切换秒数必须为大于10的数字！", "错误", 48)
        idleEdit.Value := IdleSeconds
        return
    }
    TimerInterval := newInterval
    IdleSeconds := newIdle

    SetTimer(CheckLockScreen, TimerInterval)

    ; 更新通知设置
    UseLocalNotify := cbLocalNotify.Value
    UseXXTuiNotify := cbXXTuiNotify.Value
    ApiKey := xxtuiKeyEdit.Value
    
    ; 保存配置到文件
    SaveConfig()
    
    Notify("参数已保存！", "设置", "info", true, false, ApiKey)
    UpdateUIStatus()
}

UpdateUIStatus(*) {
    global timeText, stateText, lastState

    idleMs := A_TimeIdle
    idleSec := idleMs // 1000

    nowTime := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    scheme := lastState = "locked" ? "节能（锁屏）"
            : lastState = "idle" ? "节能（空闲）"
            : "高性能"
    timeText.Value := "检测时间：" nowTime
    stateText.Value := "电源计划：" scheme " | 空闲时间（秒）：" idleSec
}

TrayClick(wParam, lParam, msg, hwnd) {
    if (lParam = 0x201) {
        ShowStatusUI()
    }
}

TestXXTuiNotification(*) {
    global cbXXTuiNotify, xxtuiKeyEdit

    apiKey := xxtuiKeyEdit.Value

    ; 优化后的测试逻辑：允许强制测试，无需考虑cbXXTuiNotify状态
    if (StrLen(apiKey) < 10) {  ; 简单验证API Key长度
        MsgBox("请输入有效的xxtui推送Key", "提示", 48)
        return
    }
    
    try {
        ; 强制发送测试通知，不受cbXXTuiNotify状态影响
        result := SendXXTuiNotification("PowerSchemeSwitcher", "PowerSchemeSwitcher测试通知", "这是一条来自PowerSchemeSwitcher的测试消息", apiKey)
        if (InStr(result, "error") || result == "") {
            MsgBox("测试通知发送完成，但可能存在问题`n返回结果: " result, "提示", 48)
        } else {
            MsgBox("xxtui推送测试已完成，请检查是否收到通知`n返回结果: " result, "提示", 64)
        }
    } catch as e {
        MsgBox("发送测试通知时出错: " e.Message, "错误", 16)
    }
}

GetApiKeyInstructions(*) {
    instructions := "
(
1. 即将访问网站：https://www.xxtui.com/
2. 注册或登录您的账户
4. 复制API_KEY并粘贴到上面的输入框中
5. 点击"保存设置"以应用更改

注意：请妥善保管您的API_KEY，不要泄露给他人。
)"
    result := MsgBox(instructions, "获取API_KEY说明", 64+1) ; 64=图标信息, 1=确定/取消按钮
    
    ; 只有当用户点击了确定按钮时才打开xxtui官网
    ; 同时检查字符串值'OK'和数值码1来准确识别用户点击了确认按钮
    if (result = "OK" || result = 1) {
        Run("https://www.xxtui.com/")
    }
}
