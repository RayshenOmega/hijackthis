Attribute VB_Name = "modWindow"
'[modWindow.bas]

'
' Window manipulation module by Alex Dragokas
'

Option Explicit

Private Declare Function FindWindow Lib "user32.dll" Alias "FindWindowW" (ByVal lpClassName As Long, ByVal lpWindowName As Long) As Long
Private Declare Function FindWindowEx Lib "user32" Alias "FindWindowExW" (ByVal hWndParent As Long, ByVal hWndChildAfter As Long, ByVal lpszClass As Long, ByVal lpszWindow As Long) As Long
Private Declare Function GetDlgCtrlID Lib "user32" (ByVal hWnd As Long) As Long
Private Declare Function GetWindowText Lib "user32" Alias "GetWindowTextW" (ByVal hWnd As Long, ByVal lpString As Long, ByVal cch As Long) As Long
Private Declare Function GetWindowTextLength Lib "user32" Alias "GetWindowTextLengthW" (ByVal hWnd As Long) As Long
Private Declare Function EnumWindows Lib "user32" (ByVal lpEnumFunc As Long, ByVal lParam As Long) As Long
Private Declare Function GetClassName Lib "user32" Alias "GetClassNameW" (ByVal hWnd As Long, ByVal lpClassName As Long, ByVal nMaxCount As Long) As Long
Private Declare Function GetWindowThreadProcessId Lib "user32" (ByVal hWnd As Long, lpdwProcessId As Long) As Long
Private Declare Function EnumChildWindows Lib "user32" (ByVal hWndParent As Long, ByVal lpEnumFunc As Long, ByVal lParam As Long) As Long
Private Declare Function EnumThreadWindows Lib "user32" (ByVal dwThreadID As Long, ByVal lpfn As Long, ByVal lParam As Long) As Long
Private Declare Function GetParent Lib "user32" (ByVal hWnd As Long) As Long
Private Declare Function GetWindowLong Lib "user32.dll" Alias "GetWindowLongW" (ByVal hWnd As Long, ByVal nIndex As Long) As Long
Private Declare Function ShowWindow Lib "user32.dll" (ByVal hWnd As Long, ByVal nCmdShow As Long) As Long
Private Declare Function EndDialog Lib "user32.dll" (ByVal hDlg As Long, ByVal nResult As Long) As Long

Private Const WS_VISIBLE         As Long = &H10000000
Private Const GWL_STYLE          As Long = -16
Private Const GWL_EXSTYLE        As Long = -20
Private Const WS_EX_TOOLWINDOW   As Long = &H80&
Private Const WS_EX_APPWINDOW    As Long = &H40000
Private Const SW_HIDE            As Long = 0
Private Const SW_MINIMIZE        As Long = 6
Private Const SW_SHOWNORMAL      As Long = 1
Private Const SW_SHOW            As Long = 5
Private Const WS_EX_TOPMOST      As Long = 8
Private Const WS_POPUP           As Long = &H80000000

Dim m_CountFound      As Long
Dim m_fndHwnd         As Long
Dim m_fndHwnds()      As Long
Dim m_WindowTitle     As String
Dim m_WindowTitlePart As String
Dim m_WindowPid       As Long
Dim m_WindowExStyle   As Long
Dim m_WindowStyle     As Long
Dim m_All             As Boolean

Private Sub SetDefaults()
    m_CountFound = 0
    m_fndHwnd = 0
    Erase m_fndHwnds
    m_WindowPid = 0
    m_WindowTitle = vbNullString
    m_WindowExStyle = 0
    m_WindowStyle = 0
    m_All = False
End Sub

'Returns window handle found by ProcessId
Public Function FindWindowByPID(pid As Long) As Long
    SetDefaults
    m_WindowPid = pid
    EnumWindows AddressOf Callback_EnumWindow, 0
    FindWindowByPID = m_fndHwnd
End Function

'Returns array of window handles found by ProcessId
Public Function FindWindowsByPID(out_hWindows() As Long, pid As Long) As Long
    SetDefaults
    m_WindowPid = pid
    m_All = True
    EnumWindows AddressOf Callback_EnumWindow, 0
    out_hWindows = m_fndHwnds
    FindWindowsByPID = m_CountFound
End Function

'Returns window handle found by window title
Public Function FindWindowByTitle(sExactTitle As String, Optional sPartialTitle As String) As Long
    SetDefaults
    m_WindowTitle = sExactTitle
    m_WindowTitlePart = sPartialTitle
    EnumWindows AddressOf Callback_EnumWindow, 0
    FindWindowByTitle = m_fndHwnd
End Function

'Returns array of window handles found by window title
Public Function FindWindowsByTitle(out_hWindows() As Long, sExactTitle As String, Optional sPartialTitle As String) As Long
    SetDefaults
    m_WindowTitle = sExactTitle
    m_WindowTitlePart = sPartialTitle
    m_All = True
    EnumWindows AddressOf Callback_EnumWindow, 0
    out_hWindows = m_fndHwnds
    FindWindowsByTitle = m_CountFound
End Function

'Returns window handle of own popup menu
Public Function FindPopupMenu() As Long
    SetDefaults
    m_WindowPid = GetCurrentProcessId()
    m_WindowExStyle = WS_EX_TOPMOST
    m_WindowStyle = WS_POPUP
    EnumWindows AddressOf Callback_EnumWindow, 0
    FindPopupMenu = m_fndHwnd
End Function

Private Function Callback_EnumWindow(ByVal hWnd As Long, ByVal lParam As Long) As Boolean
    Dim sTitle  As String
    Dim bFound  As Boolean
    If m_WindowPid <> 0 Then
        If GetPidByWindow(hWnd) = m_WindowPid Then
            bFound = True
        Else
            Callback_EnumWindow = True
            Exit Function
        End If
    End If
    If Len(m_WindowTitle) <> 0 Then
        bFound = (StrComp(GetWindowTitle(hWnd), m_WindowTitle, vbTextCompare) = 0)
    ElseIf Len(m_WindowTitlePart) <> 0 Then
        bFound = (InStr(1, GetWindowTitle(hWnd), m_WindowTitlePart, vbTextCompare) <> 0)
    End If
    If bFound Then
        If m_WindowStyle <> 0 Then
            If (GetWindowLong(hWnd, GWL_STYLE) And m_WindowStyle) <> m_WindowStyle Then bFound = False
        End If
    End If
    If bFound Then
        If m_WindowExStyle <> 0 Then
            If (GetWindowLong(hWnd, GWL_EXSTYLE) And m_WindowExStyle) <> m_WindowExStyle Then bFound = False
        End If
    End If
    If bFound Then
        If m_All Then
            ReDim Preserve m_fndHwnds(m_CountFound)
            m_fndHwnds(m_CountFound) = hWnd
            m_CountFound = m_CountFound + 1
            Callback_EnumWindow = True
        Else
            m_fndHwnd = hWnd
        End If
    Else
        Callback_EnumWindow = True
    End If
End Function

'Returns text of a window's control by its class
Public Function GetControlText(WindowTitle As String, sClass As String) As String
    Dim hWnd            As Long
    Dim hControl        As Long
    Dim hControlChild   As Long
    hWnd = FindWindow(0, StrPtr(WindowTitle))
    If hWnd <> 0 Then
        Do
            hControl = FindWindowEx(hWnd, hControlChild, StrPtr(sClass), 0)
            If hControl <> 0 Then
                GetControlText = GetWindowTitle(hControl)
                Exit Function
            End If
            hControlChild = hControl
        Loop While hControl
    End If
End Function

'Returns ProcessId of the window by handle
Public Function GetPidByWindow(hWnd As Long) As Long
    Dim hThread     As Long
    Dim pid         As Long
    hThread = GetWindowThreadProcessId(ByVal hWnd, pid)
    GetPidByWindow = pid
End Function

'Returns class name of the window by handle
Public Function GetClassNameByWindow(hWnd As Long) As String
    Dim nMaxCount As Long:
    Dim lpClassName As String:
    Dim lResult As Long:
    nMaxCount = 100
    lpClassName = String$(nMaxCount, 0)
    lResult = GetClassName(hWnd, StrPtr(lpClassName), nMaxCount)
    If lResult <> 0 Then
        GetClassNameByWindow = Left$(lpClassName, lResult)
    End If
End Function

'Returns title text of the window by handle
Public Function GetWindowTitle(hWnd As Long) As String
    Dim iLength As Long
    Dim sTitle As String
    iLength = GetWindowTextLength(hWnd)
    If iLength > 0 Then
        sTitle = String$(iLength, 0)
        GetWindowText hWnd, StrPtr(sTitle), iLength + 1
    End If
    GetWindowTitle = sTitle
End Function

Public Sub EnumWindowsChilds(hWnd As Long)
    EnumChildWindows hWnd, AddressOf EnumWindowProc, 0
End Sub

Function EnumWindowProc(ByVal lhWnd As Long, ByVal lParam As Long) As Long
    Debug.Print "Child: 0x" & Hex(lhWnd) & _
        ", class: " & GetClassNameByWindow(lhWnd) & _
        ", title: " & GetWindowTitle(lhWnd)
    EnumWindowProc = True
End Function

Public Sub SetWindowAlwaysOnTop(hWnd As Long, Enable As Boolean)
    SetWindowPos hWnd, IIf(Enable, HWND_TOPMOST, HWND_NOTOPMOST), 0, 0, 0, 0, SWP_NOMOVE Or SWP_NOSIZE
End Sub

Public Sub CloseWindow(hWindow As Long, bForce As Boolean)
    If bForce Then
        Dim iResult As Long
        EndDialog hWindow, VarPtr(iResult)
    Else
        PostMessage hWindow, WM_CLOSE, 0, 0
    End If
End Sub

Public Function ProcessCloseWindow( _
    ProcessID As Long, _
    bForce As Boolean, _
    Optional bWait As Boolean, _
    Optional TimeoutMs As Long) As Boolean
    
    Dim hWindows() As Long
    Dim i As Long, iExitCode As Long
    For i = 0 To FindWindowsByPID(hWindows, ProcessID) - 1
        CloseWindow hWindows(i), bForce
    Next
    
    If bWait Then
        iExitCode = Proc.WaitForTerminate(TimeoutMs:=TimeoutMs, ProcessID:=ProcessID)
        ProcessCloseWindow = (iExitCode = ERROR_SUCCESS)
    End If
End Function

Public Function ProcessCloseWindowByFile( _
    sPath As String, _
    bForce As Boolean, _
    Optional bWait As Boolean, _
    Optional TimeoutMs As Long) As Boolean
    
    Dim i&
    Dim lNumProcesses As Long
    Dim Process() As MY_PROC_ENTRY
    Dim bSuccess As Boolean: bSuccess = True
    
    If Len(sPath) = 0 Then Exit Function
    
    lNumProcesses = GetProcesses(Process)
    
    If lNumProcesses Then
        
        For i = 0 To UBound(Process)
        
            If StrComp(sPath, Process(i).Path, 1) = 0 Then 'No wait
            
                Call ProcessCloseWindow(Process(i).pid, bForce, False)
            End If
        Next
        
        lNumProcesses = GetProcesses(Process)
        For i = 0 To UBound(Process)
        
            If StrComp(sPath, Process(i).Path, 1) = 0 Then 'Wait
            
                bSuccess = bSuccess And ProcessCloseWindow(Process(i).pid, bForce, bWait, TimeoutMs)
                If Not bSuccess Then Exit For 'Exit on first timeout
            End If
        Next
        
    End If
    
    ProcessCloseWindowByFile = bSuccess
End Function

Public Function ProcessCloseWindowByFileOrPID( _
    sPath As String, _
    pid As Long, _
    bForce As Boolean, _
    Optional bWait As Boolean, _
    Optional TimeoutMs As Long) As Boolean
    
    If pid <> 0 Then
        ProcessCloseWindowByFileOrPID = ProcessCloseWindow(pid, bForce, bWait, TimeoutMs)
    Else
        ProcessCloseWindowByFileOrPID = ProcessCloseWindowByFile(sPath, bForce, bWait, TimeoutMs)
    End If
End Function
