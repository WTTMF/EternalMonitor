Option Explicit

If WScript.Arguments.Count <> 2 Then
    WScript.Quit 2
End If

Dim toggleScript, action, shell, powershell, command, exitCode
toggleScript = WScript.Arguments(0)
action = LCase(WScript.Arguments(1))

If action <> "enable" And action <> "disable" Then
    WScript.Quit 2
End If

Set shell = CreateObject("WScript.Shell")
powershell = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")
command = Chr(34) & powershell & Chr(34) & _
    " -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " & _
    Chr(34) & toggleScript & Chr(34) & " -Action " & action
exitCode = shell.Run(command, 0, True)
WScript.Quit exitCode
