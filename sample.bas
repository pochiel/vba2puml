Public Function testfuntion(param As String, param2 As Integer) As Integer
    Dim i As Integer
    For i = 0 To 100
        Debug.Print ("abcd")
        If i < 100 Then
            Debug.Print ("i<100")
        Else
            ' ���̃��[�g�ʂ�Ȃ��̂ł́H
            Debug.Print ("else route")
        End If
    Next
End Function
