' Fila de texto. El contenido es un RowNode (title, line2, right, rightColor).

sub init()
    m.bg = m.top.findNode("bg")
    m.title = m.top.findNode("title")
    m.line2 = m.top.findNode("line2")
    m.right = m.top.findNode("right")
end sub

sub onLayout()
    w = m.top.width
    h = m.top.height
    if w <= 0 or h <= 0 then return
    m.bg.width = w - 8
    m.bg.height = h - 8
    rightW = 420
    m.title.width = w - rightW - 60
    m.line2.width = w - rightW - 60
    m.line2.translation = [24, 46]
    m.line2.height = 34
    m.right.translation = [w - rightW - 32, 0]
    m.right.width = rightW
    m.right.height = h - 8
    onContent()
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.title.text = c.title
    m.line2.text = c.line2
    m.line2.visible = (c.line2 <> "")
    m.right.text = c.right
    h = m.top.height
    if c.line2 <> "" then
        m.title.vertAlign = "top"
        m.title.translation = [24, 6]
        m.title.height = 40
    else
        m.title.vertAlign = "center"
        m.title.translation = [24, 0]
        m.title.height = h - 8
    end if
    onFocus()
end sub

sub onFocus()
    if m.top.itemHasFocus then
        m.bg.color = "0xEC4899FF"
        m.title.color = "0xFFFFFFFF"
        m.line2.color = "0xFFE4F1FF"
        m.right.color = "0xFFFFFFFF"
    else
        m.bg.color = "0x1A1A2EFF"
        m.title.color = "0xF3F4F6FF"
        m.line2.color = "0xB4B4C8FF"
        c = m.top.itemContent
        if c <> invalid then m.right.color = c.rightColor
    end if
end sub
