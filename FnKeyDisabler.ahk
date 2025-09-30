; 需要 AutoHotkey v2
#Requires Autohotkey v2

; 功能：禁用 Fn 组合键（常见的亮度、音量快捷键），可通过UI开关
global fnDisabled := false

; --- UI 部分 ---
ShowUI() {
    global fnDisabled

    myGui := Gui("AlwaysOnTop +Resize", "Fn 键禁用开关 - x.j")
    myGui.Add("Text", , "选择是否禁用 Fn 键功能：")
    toggleBtn := myGui.Add("Button", "w120 h30", fnDisabled ? "启用 Fn" : "禁用 Fn")
    toggleBtn.OnEvent("Click", (*) => ToggleFn(toggleBtn))
    myGui.Show("w200 h100")
}

ToggleFn(btn) {
    global fnDisabled
    fnDisabled := !fnDisabled
    btn.Text := fnDisabled ? "启用 Fn" : "禁用 Fn"
    TrayTip("Fn 键状态", fnDisabled ? "已禁用" : "已启用", 1)
}

; --- 拦截 Fn 功能键 ---
; 不同笔记本可能略有差异，可以根据需要添加或修改
#HotIf fnDisabled
; 常见 Fn 组合（根据品牌可能不同）
Volume_Up::Return
Volume_Down::Return
Volume_Mute::Return
Media_Play_Pause::Return
Media_Next::Return
Media_Prev::Return
Launch_Mail::Return
Launch_Media::Return
Launch_App1::Return
Launch_App2::Return
; 屏蔽亮度调节（某些电脑可能是 SC163/SC164）
SC163::Return
SC164::Return
#HotIf

; 启动时显示界面
ShowUI()
