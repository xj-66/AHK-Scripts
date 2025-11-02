#Requires AutoHotkey v2.0
#SingleInstance Force

; ========= 配置 =========
iniFile := A_ScriptDir "\settings.ini"
progressFile := ""   ; 每次执行生成唯一文件名
; =======================

; ========= 读取保存的设置 =========
ffmpegPathSaved := IniRead(iniFile, "Paths", "ffmpeg", "")
sourcePathSaved := IniRead(iniFile, "Paths", "source", "")
outNameSaved    := IniRead(iniFile, "Paths", "outname", "output.mp3")
reencSaved      := IniRead(iniFile, "Encode", "reencode", "0")
brSaved         := IniRead(iniFile, "Encode", "bitrate", "320k")

; ========= GUI（可缩放布局） =========
myGui := Gui(, "MP3 合并工具 - x.j")
myGui.Opt("+Resize +MinSize800x560")  ; 允许缩放，并设置最小尺寸
myGui.Show("w1200 h740")

; 先创建控件（初始位置随便占位，稍后由布局函数统一摆放）
txtFfmpeg := myGui.AddText("", "FFmpeg 路径：")
editFfmpeg := myGui.AddEdit("", ffmpegPathSaved)
btnBrowseFfmpeg := myGui.AddButton("", "浏览")

txtSource := myGui.AddText("", "源文件夹：")
editSource := myGui.AddEdit("", sourcePathSaved)
btnBrowseSource := myGui.AddButton("", "浏览并加载")

txtOut := myGui.AddText("", "输出文件名：")
editOutName := myGui.AddEdit("", outNameSaved)

chkReenc := myGui.AddCheckBox("", "重新编码合并（更兼容）")
cmbBr    := myGui.AddComboBox("", ["128k","192k","256k","320k"])
chkReenc.Value := (reencSaved = "1") ? 1 : 0
cmbBr.Text := brSaved
cmbBr.Enabled := chkReenc.Value = 1
btnMerge := myGui.AddButton("", "执行合并")

txtList := myGui.AddText("", "文件顺序（可拖动更改）：")
lvFiles := myGui.AddListView("", ["文件名", "完整路径"])
lvFiles.ModifyCol(1, 500), lvFiles.ModifyCol(2, 0)

; 备用排序按钮
btnUp      := myGui.AddButton("", "上移")
btnDown    := myGui.AddButton("", "下移")
btnTop     := myGui.AddButton("", "置顶")
btnBottom  := myGui.AddButton("", "置底")

; 右侧进度与日志
grpRight := myGui.AddGroupBox("", "进度与日志")
txtPrg   := myGui.AddText("", "进度：")
prg      := myGui.AddProgress("", 0)
lblPct   := myGui.AddText("", "0%")
txtLog   := myGui.AddText("", "日志（带时间戳）：")
logBox   := myGui.AddEdit("+ReadOnly +Multi +VScroll +Wrap", "状态：等待操作...")

; 初始化日志
Log("程序启动，等待操作。")
if (sourcePathSaved != "" && DirExist(sourcePathSaved)) {
    Log("检测到上次的源目录存在，尝试自动加载：" sourcePathSaved)
    LoadMp3ToList(sourcePathSaved)
}

; —— 绑定窗口缩放事件
myGui.OnEvent("Size", Gui_OnSize)

; 先做一次初始布局
Gui_DoLayout()

; ========= 事件绑定 =========
btnBrowseFfmpeg.OnEvent("Click", BrowseFfmpeg)
btnBrowseSource.OnEvent("Click", BrowseSourceAndLoad)
btnMerge.OnEvent("Click", Merge)

; 新增：源路径失焦自动加载
editSource.OnEvent("LoseFocus", SourcePathChanged)

; 勾选重新编码时，启用/禁用比特率选择
chkReenc.OnEvent("Click", ToggleBr)

btnUp.OnEvent("Click", MoveUp)
btnDown.OnEvent("Click", MoveDown)
btnTop.OnEvent("Click", MoveTop)
btnBottom.OnEvent("Click", MoveBottom)

myGui.OnEvent("Close", OnClose)

; ========= 事件处理函数 =========
OnClose(*) {
    ExitApp()
}

ToggleBr(*) {
    global cmbBr, chkReenc
    cmbBr.Enabled := (chkReenc.Value = 1)
}

BrowseFfmpeg(*) {
    global editFfmpeg
    path := FileSelect(3, , "选择 ffmpeg.exe", "可执行文件 (*.exe)")
    if (path) {
        editFfmpeg.Value := path
        Log("已选择 FFmpeg：" path)
    } else {
        Log("取消选择 FFmpeg。")
    }
}

BrowseSourceAndLoad(*) {
    global editSource
    folder := DirSelect("选择源文件夹")
    if (folder) {
        editSource.Value := folder
        Log("已选择源文件夹：" folder)
        LoadMp3ToList(folder)
    } else {
        Log("取消选择源文件夹。")
    }
}

SourcePathChanged(*) {
    global editSource
    folder := Trim(editSource.Value)
    if (folder != "" && DirExist(folder)) {
        Log("源路径失焦触发加载：" folder)
        LoadMp3ToList(folder)
    }
}

; ======== 自然排序工具 ========
IsDigit(ch) {
    ; 返回布尔值，避免返回 Match 对象
    return RegExMatch(ch, "^\d$") != 0
}

; —— 自然排序比较器（按数值块比较，而非字典序）
NatLess(a, b) {
    i := 1, j := 1
    lenA := StrLen(a), lenB := StrLen(b)
    while (i <= lenA && j <= lenB) {
        ca := SubStr(a, i, 1)
        cb := SubStr(b, j, 1)

        if (IsDigit(ca) && IsDigit(cb)) {
            ; 提取连续数字块
            na := "", nb := ""
            while (i <= lenA && IsDigit(SubStr(a, i, 1))) {
                na .= SubStr(a, i, 1), i++
            }
            while (j <= lenB && IsDigit(SubStr(b, j, 1))) {
                nb .= SubStr(b, j, 1), j++
            }
            ; 去前导零后比较长度与数值
            na2 := RegExReplace(na, "^0+")
            nb2 := RegExReplace(nb, "^0+")
            if (na2 = "") na2 := "0"
            if (nb2 = "") nb2 := "0"

            if (StrLen(na2) != StrLen(nb2))
                return StrLen(na2) < StrLen(nb2)
            if (na2 != nb2)
                return na2 < nb2
        } else {
            la := StrLower(ca), lb := StrLower(cb)
            cmp := StrCompare(la, lb)    ; ← 字符串比较（修复点）
            if (cmp != 0)
                return cmp < 0
            i++, j++
        }
    }
    return StrLen(a) < StrLen(b)
}

LoadMp3ToList(folder) {
    global lvFiles
    lvFiles.Delete()
    Log("开始扫描目录中 mp3 文件：" folder)

    items := []  ; {name, full}
    Loop Files, folder "\*.mp3" {
        items.Push({name: A_LoopFileName, full: A_LoopFileFullPath})
    }

    if (items.Length = 0) {
        Log("未找到 mp3 文件。")
        SetStatus("等待操作...")
        return
    }

    ; === 手动排序（自然顺序） ===
    for i, _ in items {
        for j, _ in items {
            if (j < items.Length && NatLess(items[j+1].name, items[j].name)) {
                tmp := items[j]
                items[j] := items[j+1]
                items[j+1] := tmp
            }
        }
    }

    ; === 加载到 ListView ===
    for it in items
        lvFiles.Add(, it.name, it.full)

    Log("已加载文件数：" items.Length)
    SetStatus("已加载文件，等待合并。")
}

; ========= 关键改动：合并流程不再使用 cmd.exe =========
Merge(*) {
    global editFfmpeg, editSource, editOutName, chkReenc, cmbBr
    global logBox, prg, lblPct, iniFile, progressFile
    global mergePID, totalDurSec, btnMerge, lvFiles, debugTick

    Log("开始校验输入参数...")
    ffmpegPath := Trim(editFfmpeg.Value)
    sourcePath := Trim(editSource.Value)
    outName    := Trim(editOutName.Value)
    doReenc    := (chkReenc.Value = 1)
    bitrate    := Trim(cmbBr.Text)
    if (bitrate = "")
        bitrate := "320k"

    if (ffmpegPath = "" || sourcePath = "" || outName = "") {
        Log("参数缺失：FFmpeg/源文件夹/输出文件名。")
        MsgBox("请填写 FFmpeg 路径、源文件夹 和 输出文件名！", "错误", 48)
        return
    }
    if (InStr(outName, "\") || InStr(outName, "/")) {
        Log("输出文件名包含路径，已中止。")
        MsgBox("输出文件名只填文件名，不要包含路径（如：output.mp3）", "提示", 64)
        return
    }
    Log("参数验证通过。FFmpeg=" ffmpegPath ", 源=" sourcePath ", 输出名=" outName ", 重新编码=" (doReenc?"是":"否") ", 码率=" bitrate)

    ; 记住设置
    IniWrite(ffmpegPath, iniFile, "Paths", "ffmpeg")
    IniWrite(sourcePath, iniFile, "Paths", "source")
    IniWrite(outName,    iniFile, "Paths", "outname")
    IniWrite(doReenc ? "1" : "0", iniFile, "Encode", "reencode")
    IniWrite(bitrate,     iniFile, "Encode", "bitrate")
    Log("已写入设置到 ini。")

    ; 读取 ListView 当前顺序
    cnt := lvFiles.GetCount()
    if (cnt = 0) {
        Log("列表为空，尝试自动加载目录。")
        LoadMp3ToList(sourcePath)
        cnt := lvFiles.GetCount()
        if (cnt = 0) {
            Log("目录仍无 mp3 文件，终止。")
            MsgBox("该文件夹下没有 mp3 文件。", "提示", 64)
            return
        }
    }
    Log("当前合并文件数：" cnt)

    filesFull := []
    Loop cnt {
        full := lvFiles.GetText(A_Index, 2) ; 第2列：完整路径
        filesFull.Push(full)
    }

    ; ===== 生成 concat filelist.txt（UTF-8 无 BOM + 单引号转义 + CRLF）=====
    fileList := sourcePath "\filelist.txt"
    try FileDelete(fileList)

    ; ★ 关键：使用 UTF-8-RAW（无 BOM）
    f := FileOpen(fileList, "w", "UTF-8-RAW")
    if (!IsObject(f)) {
        Log("无法创建 filelist.txt：" fileList)
        MsgBox("无法创建 filelist.txt（权限/路径异常）。", "错误", 48)
        return
    }

    SanitizeForConcat(path) {
        ; 单引号转义：' -> '\''
        return StrReplace(path, "'", "'\''")
    }

    Log("开始生成 filelist.txt -> " fileList)
    for full in filesFull {
        ; FFmpeg 接受 LF 或 CRLF，这里显式 CRLF 更稳
        f.Write("file '" SanitizeForConcat(full) "'`r`n")
    }
    f.Close()
    Log("filelist 生成完成。")

    ; ===== 参数一致性体检（仅当直拷时必要）=====
    needParamCheck := (doReenc = 0)
    if (needParamCheck) {
        Log("开始参数一致性检查（针对直拷模式）...")
        ffprobePathChk := GuessFfprobe(ffmpegPath)
        if (!FileExist(ffprobePathChk)) {
            Log("未找到 ffprobe.exe，跳过一致性检查。")
        } else {
            plist := []
            for ffn in filesFull {
                p := ProbeAudioParams(ffprobePathChk, ffn)
                plist.Push({file:ffn, p:p})
                Log("参数 -> " ffn " | " ParamsString(p))
            }
            chk := DetectParamMismatches(plist)

            if (!chk.ok) {
                Log("检测到参数不一致（codec/sr/ch 不同），详细清单如下：")
                diffsByFile := Map()
                for d in chk.diffs {
                    flist := diffsByFile.Has(d.file) ? diffsByFile[d.file] : []
                    flist.Push(d)
                    diffsByFile[d.file] := flist
                }
                for file, flist in diffsByFile {
                    Log(" - " file)
                    for it in flist {
                        lbl := FieldLabel(it.field)
                        Log("    · " lbl ": " FmtVal(it.field, it.got) " ≠ 期望 " FmtVal(it.field, it.expect))
                    }
                }

                Log("为保证合并成功，将自动启用“重新编码合并”。")
                doReenc := 1
                try {
                    chkReenc.Value := 1    ; 同步 UI
                    cmbBr.Enabled := true
                }
            } else {
                Log("参数一致，直拷模式可行。基准参数：" ParamsString(chk.base))
            }
        }
    }

    ; 估算总时长（ffprobe）
    ffprobePath := GuessFfprobe(ffmpegPath)
    Log("准备探测时长，ffprobe=" ffprobePath)
    if (!FileExist(ffprobePath)) {
        Log("未找到 ffprobe.exe，终止。")
        MsgBox("未找到 ffprobe.exe（需与 ffmpeg 同目录）。请确保已安装完整 FFmpeg 套件。", "错误", 48)
        return
    }

    totalDurSec := 0.0
    idx := 0
    badFiles := []  ; 收集无法获取时长的文件
    for ffn in filesFull {
        idx++
        Log("探测(" idx "/" filesFull.Length ")：" ffn)
        d := ProbeDuration(ffprobePath, ffn)
        if (d > 0) {
            totalDurSec += d
            Log(" -> 时长=" Round(d, 3) " 秒")
        } else {
            Log(" -> 未能获取时长，可能是异常文件。")
            badFiles.Push(ffn)
        }
    }

    if (badFiles.Length > 0) {
        Log("以下文件未能获取时长（可能损坏或不完整，将影响进度百分比计算）：")
        for bf in badFiles
            Log("  - " bf)
    }

    if (totalDurSec <= 0) {
        Log("总时长为 0，无法计算进度。终止。")
        MsgBox("无法获取音频总时长，进度无法计算。", "错误", 48)
        return
    }
    Log("总时长=" Round(totalDurSec, 3) " 秒")

    ; ==== 直拷预检：如果 -c copy 不可行，自动切到重新编码 ====
    if (doReenc = 0) {
        Log("开始直拷预检（不写出文件，仅验证 concat 是否可行）...")
        pre := PreflightCopy(ffmpegPath, fileList)
        if (!pre.ok) {
            Log("直拷预检失败，将自动改为重新编码。具体原因：`n" pre.msg)
            doReenc := 1
            try {
                chkReenc.Value := 1
                cmbBr.Enabled := true
            }
        } else {
            Log("直拷预检通过。")
        }
    }

    ; 清空进度、生成唯一进度文件名
    progressFile := A_Temp "\ff_progress_" A_TickCount ".txt"
    try FileDelete(progressFile)
    prg.Value := 0
    lblPct.Value := "0%"
    SetStatus("准备中...")

    outputFile := sourcePath "\" outName

    ; 构造编码参数
    codecArgs := ""
    if (doReenc) {
        ; 重新编码，更兼容：libmp3lame + 采样率/声道统一
        codecArgs := "-c:a libmp3lame -b:a " bitrate " -ar 44100 -ac 2"
        Log("采用重新编码：" codecArgs)
    } else {
        codecArgs := "-c copy"
        Log("采用直拷码流（更快）：" codecArgs)
    }

    ; ========= 稳定版：进度在文件里，刷新更及时 =========
    ffCmd := '"' ffmpegPath '" -hide_banner -y -f concat -safe 0 -i "' fileList '" -nostats -progress "' progressFile '" ' codecArgs ' "' outputFile '" -loglevel warning'
    Log("执行命令（直连）：`n" ffCmd "`n进度文件：" progressFile)
    SetStatus("开始处理...")

    shell := ComObject("WScript.Shell")
    ; 使用 Run 方法并在后台静默运行，返回 PID
    mergePID := shell.Run(ffCmd, 0, true)  ; 0 = 隐藏窗口, false = 不等待完成
    Log("ffmpeg 进程 PID=" mergePID)

    btnMerge.Enabled := false

    SetTimer(ReadProgress, 150)
    debugTick := 0
    SetTimer(DebugProgressFile, 600)
}

ReadProgress() {
    global progressFile, prg, lblPct, logBox, mergePID, btnMerge, totalDurSec
    if (!ProcessExist(mergePID)) {
        UpdateProgressFromFile(true)  ; 尝试最终刷新并置 100%
        SetTimer(ReadProgress, 0)
        btnMerge.Enabled := true
        try FileDelete(progressFile)
        return
    }
    UpdateProgressFromFile(false)
}

; 调试：显示进度文件大小，确认 ffmpeg 是否在写
DebugProgressFile() {
    global progressFile, logBox, mergePID, debugTick
    if (progressFile = "")
        return
    if (!ProcessExist(mergePID)) {
        Log("检测到 ffmpeg 进程已退出，停止调试计时器。")
        SetTimer(DebugProgressFile, 0)
        return
    }
    sz := 0
    if FileExist(progressFile) {
        sz := FileGetSize(progressFile, "B")
    }
    debugTick++
    if (Mod(debugTick, 3) = 0) { ; 每 1.5s 追加一次
        Log("[调试] progress 文件存在=" (FileExist(progressFile)?"是":"否") ", 大小=" sz " bytes")
    }
}

UpdateProgressFromFile(final := false) {
    global progressFile, prg, lblPct, logBox, totalDurSec
    if (!FileExist(progressFile))
        return

    try content := FileRead(progressFile, "UTF-8")
    catch
        return

    outTimeMs := ""
    outTime   := ""
    lastProgress := ""

    Loop Parse, content, "`n", "`r" {
        line := Trim(A_LoopField)
        if (SubStr(line, 1, 12) = "out_time_ms=") {
            outTimeMs := SubStr(line, 13)
        } else if (SubStr(line, 1, 9) = "out_time=") {
            outTime := SubStr(line, 10)
        } else if (SubStr(line, 1, 9) = "progress=") {
            lastProgress := SubStr(line, 10) ; "continue" / "end"
        }
    }

    curSec := ""
    if (outTimeMs != "") {
        curSec := (outTimeMs + 0) / 1000000.0
    } else if (outTime != "") {
        curSec := HmsToSec(outTime)
    }

    if (curSec != "") {
        pct := Round(curSec / totalDurSec * 100)
        if (pct > 100) pct := 100
        if (pct < 0)   pct := 0
        prg.Value := pct
        lblPct.Value := pct "%"
        SetStatus("处理中...  " Round(curSec, 1) "s / " Round(totalDurSec, 1) "s  (" pct "%)")
    }

    if (lastProgress = "end" || final) {
        prg.Value := 100
        lblPct.Value := "100%"
        SetStatus("合并完成 ✅")
    }
}

; ========= 日志工具 =========
Log(msg) {
    global logBox
    stamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    cur := logBox.Value
    cur := CRLF(cur)
    line := "[" stamp "] " CRLF(msg)  ; 允许 msg 里自带多行
    if (cur != "")
        cur .= "`r`n"
    cur .= line
    logBox.Value := cur
    ; 自动滚动到底
    try {
        SendMessage(0x00B1, StrLen(cur), StrLen(cur), , logBox.Hwnd) ; EM_SETSEL
        SendMessage(0x00B7, 0, 0, , logBox.Hwnd)                    ; EM_SCROLLCARET
    }
}

SetStatus(msg) {
    global logBox
    txt := CRLF(logBox.Value)
    txt := RegExReplace(txt, "(?m)^状态：.*(?:\R)?", "")
    txt := RTrim(txt, "`r`n")
    if (txt != "")
        txt .= "`r`n"
    txt .= "状态：" msg
    logBox.Value := txt
    try {
        SendMessage(0x00B1, StrLen(txt), StrLen(txt), , logBox.Hwnd)
        SendMessage(0x00B7, 0, 0, , logBox.Hwnd)
    }
}

; —— 显示用字段映射与数值格式化（用于差异清单） ——
FieldLabel(field) {
    switch field {
        case "codec": return "编码器"
        case "sr":    return "采样率"
        case "ch":    return "声道数"
        case "br":    return "码率"
        default:      return field
    }
}
FmtVal(field, v) {
    if (v = "")
        return "(未知)"
    switch field {
        case "sr": return v + 0 " Hz"
        case "ch": return v + 0 " ch"
        case "br": return v + 0 " bps"
        default:   return v
    }
}

; ========= 工具 =========
GuessFfprobe(ffmpegPath) {
    SplitPath(ffmpegPath, , &dir)
    return dir "\ffprobe.exe"
}

HmsToSec(str) {
    parts := StrSplit(str, ":")
    if (parts.Length() < 3)
        return 0
    h := parts[1] + 0, m := parts[2] + 0
    s := parts[3] + 0
    return h*3600 + m*60 + s
}

__ParseNumber(str) {
    str := Trim(str)
    if (str = "")
        return 0
    pos := InStr(str, "`n")
    if (pos)
        str := SubStr(str, 1, pos-1)
    str := RegExReplace(str, "[^\d\.,\-Ee+]", "")
    str := StrReplace(str, ",", ".")
    try return str + 0
    catch
        return 0
}

; ========= 关键改动：直接 Exec，可抓取 stdout/stderr =========
__ExecDirect(exePath, args) {
    shell := ComObject("WScript.Shell")
    cmdLine := '"' exePath '" ' args
    exec := shell.Exec(cmdLine)
    out := "", err := ""
    while !exec.StdOut.AtEndOfStream
        out .= exec.StdOut.ReadLine() "`n"
    while !exec.StdErr.AtEndOfStream
        err .= exec.StdErr.ReadLine() "`n"
    return {Out:out, Err:err, ExitCode:exec.ExitCode}
}

; ========= 探测（已改为直连） =========
ProbeDuration(ffprobe, filePath) {
    ; 方案A：format.duration
    r := __ExecDirect(ffprobe, '-v error -show_entries format=duration -of csv=p=0 "' filePath '"')
    dur := __ParseNumber(r.Out)
    if (dur > 0)
        return dur

    ; 方案B：stream.duration
    r := __ExecDirect(ffprobe, '-v error -select_streams a:0 -show_entries stream=duration -of csv=p=0 "' filePath '"')
    dur := __ParseNumber(r.Out)
    if (dur > 0)
        return dur

    ; 方案C：ffmpeg 兜底（stderr 一并解析）
    SplitPath(ffprobe, , &dir)
    ffmpeg := dir "\ffmpeg.exe"
    if FileExist(ffmpeg) {
        r := __ExecDirect(ffmpeg, '-hide_banner -i "' filePath '" -f null -')
        text := r.Out "`n" r.Err
        if RegExMatch(text, "Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)", &m) {
            h := m[1] + 0, m2 := m[2] + 0, s := m[3] + 0
            dur := h*3600 + m2*60 + s
            if (dur > 0)
                return dur
        }
    }
    Log("ffprobe/ffmpeg 未能解析时长：`n  文件：" filePath "`n  说明（如有）：`n" r.Err)
    return 0
}

ProbeAudioParams(ffprobe, filePath) {
    r := __ExecDirect(ffprobe, '-v error -select_streams a:0 -show_entries stream=codec_name,sample_rate,channels,bit_rate -of default=nw=1 "' filePath '"')
    text := r.Out
    p := {codec:"", sr:"", ch:"", br:""}
    Loop Parse, text, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        if RegExMatch(line, "i)^codec_name\s*=\s*(.*)$", &m)
            p.codec := Trim(m[1])
        else if RegExMatch(line, "i)^sample_rate\s*=\s*(\d+)$", &m)
            p.sr := m[1] + 0
        else if RegExMatch(line, "i)^channels\s*=\s*(\d+)$", &m)
            p.ch := m[1] + 0
        else if RegExMatch(line, "i)^bit_rate\s*=\s*(\d+)$", &m)
            p.br := m[1] + 0
    }
    if (p.codec = "" && r.Err != "")
        Log("ffprobe 参数解析失败，可能无法打开文件：`n  文件：" filePath "`n  说明：`n" r.Err)
    return p
}

ParamsString(p) {
    return "codec=" p.codec ", sr=" p.sr ", ch=" p.ch ", br=" p.br
}

DetectParamMismatches(list) {
    if (list.Length = 0)
        return {ok:true, base:"", diffs:[]}
    keys := ["codec","sr","ch","br"]
    base := IsObject(list[1].p) ? list[1].p : {codec:"", sr:"", ch:"", br:""}
    for i, it in list {
        for _, k in keys {
            if (base.%k% = "" && it.p.%k% != "")
                base.%k% := it.p.%k%
        }
    }
    diffs := []  ; [{file, field, got, expect}]
    for i, it in list {
        for _, field in ["codec","sr","ch"] {
            got := it.p.%field%
            exp := base.%field%
            if (got != "" && exp != "" && got != exp) {
                diffs.Push({file: it.file, field: field, got: got, expect: exp})
            }
        }
    }
    return {ok: diffs.Length=0, base:base, diffs:diffs}
}

; ======== 排序按钮用函数 ========
LV_MoveRow(lv, from, to) {
    if (from = to)
        return
    name := lv.GetText(from, 1)
    full := lv.GetText(from, 2)
    lv.Delete(from)
    if (to < 1)
        to := 1
    if (to > lv.GetCount()+1)
        to := lv.GetCount()+1
    lv.Insert(to, , name, full)
}
MoveUp(*) {
    MoveRowRelative(-1)
}
MoveDown(*) {
    MoveRowRelative(1)
}
MoveTop(*) {
    MoveRowAbsolute(1)
}
MoveBottom(*) {
    global lvFiles
    MoveRowAbsolute(lvFiles.GetCount())
}

MoveRowRelative(offset) {
    global lvFiles
    row := lvFiles.GetNext(0, "F")
    if (row = 0) {
        return
    }
    target := row + offset
    if (target < 1) {
        target := 1
    }
    if (target > lvFiles.GetCount()) {
        target := lvFiles.GetCount()
    }
    LV_MoveRow(lvFiles, row, target)
    lvFiles.Modify(target, "Select Focus")
}

MoveRowAbsolute(pos) {
    global lvFiles
    row := lvFiles.GetNext(0, "F")
    if (row = 0) {
        return
    }
    if (pos < 1) {
        pos := 1
    }
    if (pos > lvFiles.GetCount()) {
        pos := lvFiles.GetCount()
    }
    LV_MoveRow(lvFiles, row, pos)
    lvFiles.Modify(pos, "Select Focus")
}

; ===== 自适应布局 =====
Gui_OnSize(thisGui, minMax, w, h) {
    if (minMax = 2)  ; 最小化不布局
        return
    Gui_DoLayout()
}

Gui_DoLayout() {
    global myGui
    global txtFfmpeg, editFfmpeg, btnBrowseFfmpeg
    global txtSource, editSource, btnBrowseSource
    global txtOut, editOutName, chkReenc, cmbBr, btnMerge
    global txtList, lvFiles, btnUp, btnDown, btnTop, btnBottom
    global grpRight, txtPrg, prg, lblPct, txtLog, logBox

    ; ★ 用客户区宽高，避免边框/标题栏带来的偏差
    myGui.GetClientPos(, , &CW, &CH)

    ; 简单的 DPI 缩放工具
    Dpi(n) {
        return Round(n * A_ScreenDPI / 96)
    }

    pad    := Dpi(16)
    gutter := Dpi(14)
    lineH  := Dpi(22)      ; ← 统一行高（更矮）
    txtW   := Dpi(100)
    btnW   := Dpi(120)

    ; 左右列宽
    leftW := Floor((CW - pad*3) * 0.46)
    if (leftW < Dpi(360))
        leftW := Dpi(360)
    rightX := pad*2 + leftW
    rightW := CW - rightX - pad
    if (rightW < Dpi(260))
        rightW := Dpi(260)

    y := pad

    ; ===== 左侧（Edit/Btn 高度统一用 lineH，不再 +4；去除 y-2 上移） =====
    txtFfmpeg.Move(pad, y, txtW, lineH)
    editFfmpeg.Move(pad + txtW + Dpi(10), y, leftW - txtW - Dpi(10) - btnW - Dpi(10), lineH)
    btnBrowseFfmpeg.Move(pad + leftW - btnW, y, btnW, lineH)
    y += Dpi(34)

    txtSource.Move(pad, y, txtW, lineH)
    editSource.Move(pad + txtW + Dpi(10), y, leftW - txtW - Dpi(10) - btnW - Dpi(10), lineH)
    btnBrowseSource.Move(pad + leftW - btnW, y, btnW, lineH)
    y += Dpi(34)

    txtOut.Move(pad, y, txtW, lineH)
    editOutName.Move(pad + txtW + Dpi(10), y, leftW - txtW - Dpi(10), lineH)
    y += Dpi(32)

    chkReenc.Move(pad, y, Dpi(200), lineH)
    cmbBr.Move(pad + Dpi(210), y, Dpi(120), lineH)
    btnMerge.Move(pad + leftW - Dpi(120), y, Dpi(120), lineH)
    y += Dpi(32)

    txtList.Move(pad, y, leftW, lineH)
    y += Dpi(20)

    ; —— 为底部按钮预留固定高度，防止溢出
    bottomBtnH := Dpi(26)
    bottomGap  := Dpi(6)
    safetyPad  := Dpi(6)

    safeH := CH - y - pad - (bottomBtnH + bottomGap) - safetyPad
    if (safeH < Dpi(120))
        safeH := Dpi(120)

    lvFiles.Move(pad, y, leftW, safeH)

    btnY := y + safeH + bottomGap
    btnUp.Move(pad,               btnY, Dpi(80), bottomBtnH)
    btnDown.Move(pad + Dpi(85),   btnY, Dpi(80), bottomBtnH)
    btnTop.Move(pad + Dpi(170),   btnY, Dpi(80), bottomBtnH)
    btnBottom.Move(pad + Dpi(255),btnY, Dpi(80), bottomBtnH)

    ; ===== 右侧 =====
    grpRight.Move(rightX, pad, rightW, CH - pad*2)

    ; GroupBox 内控件不是子控件，靠“视觉内边距”摆放
    innerX   := rightX + Dpi(12)
    innerW   := rightW - Dpi(24)
    titleOff := Dpi(24)  ; 组框标题的视觉高度偏移（略小）
    innerTop := pad + titleOff
    innerH   := CH - innerTop - pad
    if (innerH < Dpi(140))
        innerH := Dpi(140)

    txtPrg.Move(innerX, innerTop + Dpi(2), innerW, Dpi(18))
    prg.Move(innerX, innerTop + Dpi(22), innerW, Dpi(18))
    lblPct.Move(innerX, innerTop + Dpi(44), innerW, Dpi(18))

    txtLogY := innerTop + Dpi(72)
    txtLog.Move(innerX, txtLogY, innerW, Dpi(18))

    logY := txtLogY + Dpi(20)
    logH := innerH - (logY - innerTop) - Dpi(8)
    if (logH < Dpi(60))
        logH := Dpi(60)
    logBox.Move(innerX, logY, innerW, logH)
}

CRLF(s) {
    s := StrReplace(s, "`r`n", "`n")
    s := StrReplace(s, "`r", "`n")
    s := StrReplace(s, "`n", "`r`n")
    return s
}

; 预检直拷是否可行：尝试把 concat 输入推到空设备（null），不产生输出文件
; 返回 { ok:Bool, msg:String }
PreflightCopy(ffmpegPath, fileListPath) {
    SplitPath(ffmpegPath, , &dir)
    ffmpeg := ffmpegPath
    ; -v error 只打印错误；-nostdin 防止等待输入；-f null - 把输出丢到空设备
    args := '-hide_banner -nostdin -f concat -safe 0 -i "' fileListPath '" -v error -c copy -f null -'
    r := __ExecDirect(ffmpeg, args)
    if (r.ExitCode = 0) {
        return { ok: true, msg: "预检通过：直拷可行" }
    } else {
        msg := Trim(r.Out "`n" r.Err)
        if (msg = "")
            msg := "预检失败：未知错误（ExitCode=" r.ExitCode "）"
        return { ok: false, msg: msg }
    }
}
