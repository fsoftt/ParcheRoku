' Fila de episodio. El contenido es un RowNode (title, line2 = sinopsis, image = miniatura, right = estado).

sub init()
    m.bg = m.top.findNode("bg")
    m.thumb = m.top.findNode("thumb")
    m.title = m.top.findNode("title")
    m.overview = m.top.findNode("overview")
    m.right = m.top.findNode("right")
end sub

sub onLayout()
    w = m.top.width
    h = m.top.height
    if w <= 0 or h <= 0 then return
    m.bg.width = w - 8
    m.bg.height = h - 8
    thumbH = h - 24
    thumbW = Int(thumbH * 16 / 9)
    m.thumb.translation = [12, 12]
    m.thumb.width = thumbW
    m.thumb.height = thumbH
    textX = thumbW + 36
    m.title.translation = [textX, 10]
    m.title.width = w - textX - 220
    m.title.height = 40
    m.right.translation = [w - 232, 14]
    m.right.width = 200
    m.overview.translation = [textX, 54]
    m.overview.width = w - textX - 40
    m.overview.height = h - 74
    onContent()
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.title.text = c.title
    m.overview.text = c.line2
    m.right.text = c.right
    m.thumb.uri = c.image
    m.thumb.visible = (c.image <> "")
    onFocus()
end sub

sub onFocus()
    if m.top.itemHasFocus then
        m.bg.color = "0x8B5CF6FF"
        m.title.color = "0xFFFFFFFF"
        m.overview.color = "0xEDE9FEFF"
    else
        m.bg.color = "0x1A1A2EFF"
        m.title.color = "0xF3F4F6FF"
        m.overview.color = "0xB4B4C8FF"
    end if
end sub
