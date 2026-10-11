' Tarjeta de póster. El contenido es un MediaNode (HDPosterUrl, title, progress).

sub init()
    m.ring = m.top.findNode("ring")
    m.bg = m.top.findNode("bg")
    m.poster = m.top.findNode("poster")
    m.fallback = m.top.findNode("fallback")
    m.barBg = m.top.findNode("barBg")
    m.bar = m.top.findNode("bar")
    m.poster.observeField("loadStatus", "onLoadStatus")
end sub

sub onLayout()
    w = m.top.width
    h = m.top.height
    if w <= 0 or h <= 0 then return
    m.ring.translation = [-5, -5]
    m.ring.width = w + 10
    m.ring.height = h + 10
    m.bg.width = w
    m.bg.height = h
    m.poster.width = w
    m.poster.height = h
    m.poster.loadWidth = w
    m.poster.loadHeight = h
    m.fallback.translation = [8, 8]
    m.fallback.width = w - 16
    m.fallback.height = h - 16
    m.barBg.translation = [0, h - 8]
    m.barBg.width = w
    m.barBg.height = 8
    m.bar.translation = [0, h - 8]
    m.bar.height = 8
    onContent()
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.poster.uri = c.HDPosterUrl
    m.fallback.text = c.title
    m.fallback.visible = (c.HDPosterUrl = "")
    p = 0.0
    if c.hasField("progress") then p = c.progress
    showBar = p > 0
    m.barBg.visible = showBar
    m.bar.visible = showBar
    m.bar.width = m.top.width * p
end sub

sub onLoadStatus()
    if m.poster.loadStatus = "failed" then m.fallback.visible = true
end sub

sub onFocus()
    m.ring.visible = m.top.itemHasFocus
end sub
