#Requires AutoHotkey v2.0

; 设置系统托盘图标
TraySetIcon("shell32.dll", 42)

; 获取脚本所在目录
scriptDir := A_ScriptDir
iniFile := scriptDir "\yt-dlp-gui-settings.ini"

PROCESS_QUERY_LIMITED_INFORMATION := 0x1000
PROCESS_QUERY_INFORMATION := 0x0400
SYNCHRONIZE := 0x00100000

myGui := Gui()
myGui.Title := "yt-dlp GUI - by x.j"

; ==================== 前置准备 ====================
myGui.Add("GroupBox", "x10 y10 w480 h220", "下载前准备")

; 第一行 - yt-dlp 路径
myGui.Add("Text", "x30 y40", "yt-dlp 路径:")
ytDlpPathEdit := myGui.Add("Edit", "x120 y35 w250 vYtDlpPath")
browseBtn := myGui.Add("Button", "x380 y35 w70", "浏览...")
browseBtn.OnEvent("Click", BrowseForYtDlp)

; 第二行 - FFmpeg 路径
myGui.Add("Text", "x30 y80", "FFmpeg 路径:")
ffmpegPathEdit := myGui.Add("Edit", "x120 y75 w250 vFfmpegPath")
ffmpegBrowseBtn := myGui.Add("Button", "x380 y75 w70", "浏览...")
ffmpegBrowseBtn.OnEvent("Click", BrowseForFfmpeg)

; 第三行 - 下载地址
myGui.Add("Text", "x30 y120", "工具下载:")
ytDlpDownloadBtn := myGui.Add("Button", "x120 y115 w160", "打开 yt-dlp 下载页面")
ytDlpDownloadBtn.OnEvent("Click", OpenYtDlpDownload)
ffmpegDownloadBtn := myGui.Add("Button", "x290 y115 w160", "打开 FFmpeg 下载页面")
ffmpegDownloadBtn.OnEvent("Click", OpenFfmpegDownload)

; 第四行 - 下载目录
myGui.Add("Text", "x30 y160", "下载目录:")
downloadDirEdit := myGui.Add("Edit", "x120 y155 w250 vDownloadDir")
dirBrowseBtn := myGui.Add("Button", "x380 y155 w70", "浏览...")
dirBrowseBtn.OnEvent("Click", BrowseForDownloadDir)

; 第五行 - 保存按钮
saveBtn := myGui.Add("Button", "x120 y195 w80", "保存")
saveBtn.OnEvent("Click", SaveSettings)

; ==================== 下载区域 ====================
myGui.Add("GroupBox", "x10 y240 w480 h200", "下载区域")

; 第一行 - 视频 URL
myGui.Add("Text", "x30 y260", "视频 URL:")
urlEdit := myGui.Add("Edit", "x120 y255 w330 vUrl")

; 第二行 - 格式选择
myGui.Add("Text", "x30 y300", "下载格式:")
videoBtn := myGui.Add("Radio", "x120 y295 w120 h26 Checked vFormat", "视频 (mp4)")
audioBtn := myGui.Add("Radio", "x250 y295 w120 h26", "音频 (mp3)")
mergeCheck := myGui.Add("CheckBox", "x120 y325 w280 h26 vMergeMedia Checked", "下载后合并音频（需要 FFmpeg）")
overwriteCheck := myGui.Add("CheckBox", "x120 y355 w280 h26 vOverwriteExisting Checked", "文件已存在时覆盖")
videoBtn.OnEvent("Click", UpdateFormatSelection)
audioBtn.OnEvent("Click", UpdateFormatSelection)
mergeCheck.OnEvent("Click", MergeCheckboxChanged)

; 第四行 - 下载按钮
downloadBtn := myGui.Add("Button", "x120 y400 w110 Default", "开始下载")
downloadBtn.OnEvent("Click", DownloadVideo)

; ==================== 工具说明 ====================
myGui.Add("GroupBox", "x10 y450 w480 h90", "工具说明")
myGui.Add("Text", "x30 y475 w450", "这是一个基于 yt-dlp 的简洁图形界面，可快速下载常见站点的视频或音频。")
myGui.Add("Text", "x30 y500 w450", "支持：YouTube、Bilibili、爱奇艺、腾讯视频、优酷、抖音/TikTok、微博、Facebook、Twitter(X)、Vimeo、Niconico 等。")

; 设置窗口关闭事件
myGui.OnEvent("Close", CloseGui)

ffmpegPathCache := ""
mergePrevChoice := 1

; 加载保存的设置
LoadSettings()
UpdateFormatSelection()

; 显示窗口
myGui.Show("w500 h550")

; 浏览选择 yt-dlp.exe 文件
BrowseForYtDlp(*) {
    selectedFile := FileSelect(3, , "选择 yt-dlp 可执行文件", "可执行文件 (*.exe)")
    if (selectedFile != "") {
        ytDlpPathEdit.Value := selectedFile
    }
}

; 浏览选择下载目录
BrowseForDownloadDir(*) {
    selectedDir := FileSelect("D", , "选择下载目录")
    if (selectedDir != "") {
        downloadDirEdit.Value := selectedDir
    }
}

; 浏览选择 FFmpeg
BrowseForFfmpeg(*) {
    global ffmpegPathEdit, ffmpegPathCache, scriptDir
    selectedFile := FileSelect(3, scriptDir, "选择 ffmpeg 可执行文件", "可执行文件 (*.exe)")
    if (selectedFile != "") {
        ffmpegPathEdit.Value := selectedFile
        ffmpegPathCache := selectedFile
    }
}

; 更新格式与合并选项的可见性
UpdateFormatSelection(*) {
    global videoBtn, mergeCheck, mergePrevChoice
    isVideo := (videoBtn.Value = 1)
    if (isVideo) {
        mergeCheck.Visible := true
        mergeCheck.Enabled := true
        mergeCheck.Value := mergePrevChoice
    } else {
        mergePrevChoice := mergeCheck.Value
        mergeCheck.Value := 0
        mergeCheck.Visible := false
        mergeCheck.Enabled := false
    }
}

MergeCheckboxChanged(*) {
    global mergeCheck, mergePrevChoice
    mergePrevChoice := mergeCheck.Value
}

; 打开 yt-dlp 下载页面
OpenYtDlpDownload(*) {
    try {
        Run "https://github.com/yt-dlp/yt-dlp/releases"
    } catch {
        MsgBox "无法打开 yt-dlp 下载页面。", "错误", "OK Iconx"
    }
}

; 打开 FFmpeg 下载页面
OpenFfmpegDownload(*) {
    try {
        Run "https://github.com/BtbN/FFmpeg-Builds/releases"
    } catch {
        MsgBox "无法打开 FFmpeg 下载页面。", "错误", "OK Iconx"
    }
}

; 下载函数
DownloadVideo(*) {
    global ffmpegPathEdit, videoBtn, audioBtn, mergeCheck, urlEdit, ytDlpPathEdit, downloadDirEdit, overwriteCheck
    myGui.Submit(false)
    url := Trim(urlEdit.Value)
    if (url = "") {
        MsgBox "请输入 URL。", "错误", "OK Iconx"
        return
    }

    ytDlpPath := Trim(ytDlpPathEdit.Value)
    if (ytDlpPath = "") {
        if FileExist(scriptDir "\yt-dlp.exe") {
            ytDlpPath := scriptDir "\yt-dlp.exe"
        } else {
            result := MsgBox("未找到 yt-dlp.exe。是否要从 GitHub 下载？", "未找到 yt-dlp", "YesNo Icon?")
            if (result = "Yes")
                DownloadYtDlp()
            return
        }
    } else if (!FileExist(ytDlpPath)) {
        MsgBox "指定的 yt-dlp 可执行文件不存在。", "错误", "OK Iconx"
        return
    }

    mergeEnabled := (videoBtn.Value = 1 && mergeCheck.Value = 1)
    manualFfmpeg := Trim(ffmpegPathEdit.Value)
    needFfmpeg := mergeEnabled || (audioBtn.Value = 1)
    ffmpegOpt := ""
    if (needFfmpeg) {
        ffmpegPath := FindFfmpeg()
        if (manualFfmpeg != "" && !FileExist(manualFfmpeg)) {
            MsgBox "FFmpeg 路径无效，请重新选择。", "提示", "OK Icon!"
            ffmpegPath := ""
        }
        if (ffmpegPath != "") {
            ffmpegOpt := "--ffmpeg-location " . Chr(34) . ffmpegPath . Chr(34) . " "
        } else if (mergeEnabled) {
            MsgBox "未检测到可用的 FFmpeg，无法自动合并音视频，将改为分别保存文件。", "提示", "OK Icon!"
            mergeEnabled := false
        } else if (audioBtn.Value = 1) {
            MsgBox "未检测到 FFmpeg，转换为 mp3 可能失败。", "提示", "OK Icon!"
        }
    }

    if (videoBtn.Value = 1) {
        formatOpt := "-f bestvideo+bestaudio"
        if (mergeEnabled)
            formatOpt .= " --merge-output-format mp4"
    } else {
        formatOpt := "-x --audio-format mp3"
    }

    downloadDir := Trim(downloadDirEdit.Value)
    outputOpt := ""
    if (downloadDir != "") {
        if (SubStr(downloadDir, -1) != "\")
            downloadDir := downloadDir "\"
        outputOpt := "--output " . Chr(34) . downloadDir . "%(title)s.%(ext)s" . Chr(34) . " "
    }

    overwriteOpt := (overwriteCheck.Value = 1) ? "--force-overwrites " : "--no-overwrites "
    progressOpt := "--newline "
    cmd := Chr(34) . ytDlpPath . Chr(34) . " " . progressOpt . overwriteOpt . outputOpt . ffmpegOpt . formatOpt . " " . Chr(34) . url . Chr(34)
    escapedCmd := StrReplace(cmd, Chr(34), Chr(34) Chr(34))
    consoleCmd := A_ComSpec . " /k " . Chr(34) . escapedCmd . Chr(34)

    try {
        Run(consoleCmd)
    } catch Error as err {
        detail := (err.HasProp("Message") && err.Message != "") ? ("（" err.Message "）") : ""
        MsgBox "运行 yt-dlp 失败。请检查路径或安装。" . detail, "yt-dlp 下载器", "OK Iconx"
    }
}

; 下载 yt-dlp.exe
DownloadYtDlp() {
    try {
        ; 下载 yt-dlp.exe 到脚本目录
        Download "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe", scriptDir "\yt-dlp.exe"
        MsgBox "yt-dlp.exe 已下载到您的脚本目录。", "yt-dlp 下载器", "OK Iconi"
        ; 自动设置路径
        ytDlpPathEdit.Value := scriptDir "\yt-dlp.exe"
    } catch {
        MsgBox "下载 yt-dlp.exe 失败。请手动从 https://github.com/yt-dlp/yt-dlp/releases 下载", "yt-dlp 下载器", "OK Iconx"
    }
}

; 保存设置到 ini 文件
SaveSettings(*) {
    global mergePrevChoice, overwriteCheck
    myGui.Submit(false)
    IniWrite ytDlpPathEdit.Value, iniFile, "Settings", "YtDlpPath"
    IniWrite videoBtn.Value, iniFile, "Settings", "VideoFormat"
    IniWrite audioBtn.Value, iniFile, "Settings", "AudioFormat"
    IniWrite mergePrevChoice, iniFile, "Settings", "MergeMedia"
    IniWrite downloadDirEdit.Value, iniFile, "Settings", "DownloadDir"
    IniWrite ffmpegPathEdit.Value, iniFile, "Settings", "FfmpegPath"
    IniWrite overwriteCheck.Value, iniFile, "Settings", "OverwriteExisting"
    ; 使用 MsgBox 显示成功消息
    MsgBox "设置已保存成功！", "yt-dlp 下载器", "OK Iconi"
    ; 或者如果需要使用 MsgBox，确保不会隐藏主窗口
    ; MsgBox "设置已保存成功！", "设置已保存", "OK"
    ; 不退出程序，继续运行
}

; 加载设置从 ini 文件
LoadSettings() {
    global mergePrevChoice, ffmpegPathCache, overwriteCheck
    if FileExist(iniFile) {
        ytDlpPath := IniRead(iniFile, "Settings", "YtDlpPath", "")
        videoFormat := IniRead(iniFile, "Settings", "VideoFormat", "1")
        audioFormat := IniRead(iniFile, "Settings", "AudioFormat", "0")
        mergeMedia := IniRead(iniFile, "Settings", "MergeMedia", "1")
        downloadDir := IniRead(iniFile, "Settings", "DownloadDir", "")
        ffmpegStored := IniRead(iniFile, "Settings", "FfmpegPath", "")
        overwriteStored := IniRead(iniFile, "Settings", "OverwriteExisting", "1")

        if (ytDlpPath != "ERROR") {
            ytDlpPathEdit.Value := ytDlpPath
        }
        if (videoFormat != "ERROR" && videoFormat = "1") {
            videoBtn.Value := 1
        }
        if (audioFormat != "ERROR" && audioFormat = "1") {
            audioBtn.Value := 1
        }
        if (mergeMedia != "ERROR") {
            mergePrevChoice := mergeMedia + 0
            mergeCheck.Value := mergePrevChoice
        } else {
            mergeCheck.Value := mergePrevChoice
        }
        if (downloadDir != "ERROR" && downloadDir != "") {
            downloadDirEdit.Value := downloadDir
        }
        if (ffmpegStored != "ERROR" && ffmpegStored != "") {
            ffmpegPathEdit.Value := ffmpegStored
            ffmpegPathCache := ffmpegStored
        }
        if (overwriteStored != "ERROR") {
            overwriteCheck.Value := overwriteStored + 0
        }
    }
}

; 关闭函数
CloseGui(GuiObj) {
    ; 隐藏窗口而不是退出程序
    GuiObj.Hide()
}

FindFfmpeg() {
    global scriptDir, ffmpegPathEdit, ffmpegPathCache
    manual := Trim(ffmpegPathEdit.Value)
    if (manual != "") {
        if FileExist(manual) {
            ffmpegPathCache := manual
            return manual
        } else {
            ffmpegPathCache := ""
            return ""
        }
    }

    if (ffmpegPathCache != "" && FileExist(ffmpegPathCache)) {
        return ffmpegPathCache
    }

    candidates := [
        scriptDir "\ffmpeg.exe",
        scriptDir "\bin\ffmpeg.exe"
    ]

    for , candidate in candidates {
        if FileExist(candidate) {
            ffmpegPathCache := candidate
            return candidate
        }
    }

    envPath := EnvGet("PATH")
    Loop Parse envPath, ";"
    {
        dir := Trim(A_LoopField)
        if (dir = "")
            continue
        candidate := dir "\ffmpeg.exe"
        if FileExist(candidate) {
            ffmpegPathCache := candidate
            return candidate
        }
    }

    ffmpegPathCache := ""
    return ""
}
