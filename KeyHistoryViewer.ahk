#Requires AutoHotkey v2.0

; 强制安装钩子，保证能捕获所有键鼠事件
InstallKeybdHook
InstallMouseHook

KeyHistory 100

; 创建主窗口
myGui := Gui("+AlwaysOnTop", "键盘记录 - x.j")
myGui.SetFont("s12", "Segoe UI")

; 添加一个按钮：点击后显示 KeyHistory
myGui.Add("Button", "w200 h40", "显示 KeyHistory").OnEvent("Click", ShowKeyHistory)

; 再加一个退出按钮
myGui.Add("Button", "w200 h40", "退出程序").OnEvent("Click", (*) => ExitApp())

; 居中并显示 GUI
myGui.Show("w240 h120 Center")

; 定义按钮事件：调用 KeyHistory
ShowKeyHistory(*) {
    KeyHistory ; 键盘鼠标历史
}
