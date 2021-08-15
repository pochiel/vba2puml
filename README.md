# vba2puml
tranpile VBA(Visual Basic for Applications) source code to plant uml flow chart.

VBAのソースコードからフローチャートを直接出力可能なソフトを目指します。 具体的には PlantUML 用のActivity図の .puml ファイルを出力します。

一応下記のようなVBAっぽいソースコードからフローチャートを作れます。
VBSとか VBとか その辺が使えるかどうかは知らん。

```
Public Function testfuntion(param As String, param2 As Integer) As Integer
    Dim i As Integer
    For i = 0 To 100
        Debug.Print ("abcd")
        If i < 100 Then
            Debug.Print ("i<100")
        Else
            ' このルート通らないのでは？
            Debug.Print ("else route")
        End If
    Next
End Function
```
![image](https://user-images.githubusercontent.com/2684586/129491739-cc4e87f0-22c2-4a19-b87b-9605d92a285d.png)
