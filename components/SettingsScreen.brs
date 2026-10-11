' Ajustes. Cada cambio se guarda al instante en el registro. Los valores con pocas opciones rotan con OK;
' las claves y las URL de addons se escriben en un diálogo de teclado (se puede pegar desde la app móvil de Roku).
' Los addons de la lista se quitan con * (options). Las filas del plugin (PluginSettingsItems) tienen id "plugin:<id>".

sub init()
    m.nav = m.top.findNode("nav")
    m.title = m.top.findNode("title")
    m.warning = m.top.findNode("warning")
    m.list = m.top.findNode("list")
    m.hint = m.top.findNode("hint")

    m.nav.items = [Tx("nav_home"), Tx("nav_search"), Tx("nav_mylist"), Tx("nav_settings")]
    m.nav.activeIndex = 3
    m.nav.index = 3
    m.nav.observeField("selected", "onNav")
    m.title.text = Tx("nav_settings")
    m.hint.text = Tx("set_hint")
    m.list.observeField("itemSelected", "onSelect")
    m.list.observeField("itemFocused", "onFocused")
    m.prevFocus = 0
    m.editing = ""
    m.dialog = invalid
    m.rowIds = []
    refresh()
end sub

' Texto de una clave guardada sin revelarla: "****abcd".
function maskKey(k as string) as string
    if k = "" then return Tx("set_notset")
    if Len(k) <= 4 then return "****"
    return "****" + Right(k, 4)
end function

function joinLangNames(codes as object) as string
    names = []
    for each c in codes
        names.Push(LangLabel(c))
    end for
    return ArrayJoin(names, ", ")
end function

function subNames(codes as object) as string
    if codes.Count() = 0 then return Tx("set_nosubs")
    names = []
    for each c in codes
        names.Push(SubLangName(c))
    end for
    return ArrayJoin(names, ", ")
end function

' Fila de la lista: { id, title, desc, value }.
function makeRow(id as string, title as string, desc as string, value as string) as object
    return { id: id, title: title, desc: desc, value: value }
end function

' Reconstruye las filas con los valores actuales (mantiene la fila enfocada).
sub refresh()
    s = SettingsLoad()
    focused = m.list.itemFocused
    if focused = invalid or focused < 0 then focused = 0

    uiName = "Espa" + Chr(241) + "ol"
    if s.uiLang = "en" then uiName = "English"
    catName = Tx("set_auto")
    if s.catalog = "tmdb" then catName = "TMDB"
    if s.catalog = "cinemeta" then catName = "Cinemeta"
    maxQ = s.maxQuality
    if maxQ = "" then maxQ = Tx("set_noquality")

    rows = []
    rows.Push(makeRow("uilang", Tx("set_uilang"), "", uiName))
    rows.Push(makeRow("catalog", Tx("set_catalog"), Tx("set_catalog_d"), catName))
    rows.Push(makeRow("tmdbKey", Tx("set_tmdbkey"), Tx("set_tmdbkey_d"), maskKey(s.tmdbKey)))
    for each r in PluginSettingsItems(s)
        rows.Push(makeRow("plugin:" + r.id, r.title, r.desc, r.value))
    end for
    rows.Push(makeRow("langs", Tx("set_langs"), Tx("set_langs_d"), joinLangNames(s.prefLangs)))
    rows.Push(makeRow("quality", Tx("set_quality"), Tx("set_quality_d"), maxQ))
    for i = 0 to s.streamAddons.Count() - 1
        rows.Push(makeRow("src:" + i.ToStr(), Tx("set_srcaddon"), Tx("set_srcaddon_d"), AddonLabel(s.streamAddons[i])))
    end for
    rows.Push(makeRow("addsrc", Tx("set_addsrc"), Tx("set_addsrc_d"), ""))
    rows.Push(makeRow("subs", Tx("set_subs"), Tx("set_subs_d"), subNames(s.subLangs)))
    for i = 0 to s.subAddons.Count() - 1
        rows.Push(makeRow("sub:" + i.ToStr(), Tx("set_subaddon"), Tx("set_srcaddon_d"), AddonLabel(s.subAddons[i])))
    end for
    rows.Push(makeRow("addsub", Tx("set_addsub"), Tx("set_addsrc_d"), ""))
    rows.Push(makeRow("clear", Tx("set_clear"), Tx("set_clear_d"), ""))
    rows.Push(makeRow("about", Tx("set_about"), Tx("set_about_d"), "v0.1"))

    root = CreateObject("roSGNode", "ContentNode")
    m.rowIds = []
    for each r in rows
        root.appendChild(MakeRowNode(r.title, r.desc, r.value))
        m.rowIds.Push(r.id)
    end for
    m.list.content = root
    m.list.jumpToItem = focused

    ' Advertencia: la del plugin, o la de "sin addons de fuentes".
    warning = PluginSettingsWarning(s)
    if IsStr(warning) then
        m.warning.text = warning
    else if AddonsEffective(s).Count() = 0 then
        m.warning.text = Tx("set_noaddons_warning")
    else
        m.warning.text = ""
    end if
end sub

' Índice del preset que coincide con la lista actual (o -1).
function presetIndex(presets as object, current as object) as integer
    cur = ArrayJoin(current, ",")
    for i = 0 to presets.Count() - 1
        if ArrayJoin(presets[i], ",") = cur then return i
    end for
    return -1
end function

' Id de la fila en la posición index ("" si no existe).
function rowIdAt(index as dynamic) as string
    if index = invalid then return ""
    if index < 0 or index >= m.rowIds.Count() then return ""
    return m.rowIds[index]
end function

' Posición numérica de un id con formato "src:2" / "sub:0".
function rowOrdinal(id as string) as integer
    return Int(Val(Mid(id, 5)))
end function

sub onSelect()
    id = rowIdAt(m.list.itemSelected)
    s = SettingsLoad()
    if id = "uilang" then
        if s.uiLang = "es" then s.uiLang = "en" else s.uiLang = "es"
        SettingsSave(s)
        m.global.lang = s.uiLang
        m.top.action = { type: "restart" }
        return
    else if id = "catalog" then
        if s.catalog = "auto" then
            s.catalog = "tmdb"
        else if s.catalog = "tmdb" then
            s.catalog = "cinemeta"
        else
            s.catalog = "auto"
        end if
    else if id = "tmdbKey" then
        openKey("tmdbKey", Tx("set_tmdbkey"), Tx("set_tmdbkey_msg"), s.tmdbKey)
        return
    else if Left(id, 7) = "plugin:" then
        r = PluginHandleSetting(s, Mid(id, 8))
        SettingsSave(r.settings)
        refresh()
        if r.ask <> invalid then openKey(id, r.ask.title, r.ask.message, r.ask.text)
        return
    else if id = "langs" then
        presets = LanguagePresets()
        s.prefLangs = presets[(presetIndex(presets, s.prefLangs) + 1) mod presets.Count()]
    else if id = "quality" then
        opts = QualityOptions()
        idx = -1
        for k = 0 to opts.Count() - 1
            if opts[k] = s.maxQuality then idx = k
        end for
        s.maxQuality = opts[(idx + 1) mod opts.Count()]
    else if id = "addsrc" then
        openKey(id, Tx("set_addsrc"), Tx("set_addon_msg"), "")
        return
    else if id = "addsub" then
        openKey(id, Tx("set_addsub"), Tx("set_addon_msg"), "")
        return
    else if Left(id, 4) = "src:" or Left(id, 4) = "sub:" then
        OpenMessageDialog(Tx("set_srcaddon"), [Tx("set_addon_info")], m.top)
        return
    else if id = "subs" then
        presets = SubtitlePresets()
        s.subLangs = presets[(presetIndex(presets, s.subLangs) + 1) mod presets.Count()]
    else if id = "clear" then
        WatchClear()
        OpenMessageDialog(Tx("set_clear"), [Tx("set_cleared")], m.top)
        return
    else if id = "about" then
        OpenMessageDialog(Tx("set_about"), [Tx("about_text"), " ", Tx("tmdb_attr"), " ", Tx("legal")], m.top)
        return
    else
        return
    end if
    SettingsSave(s)
    refresh()
end sub

' Quita de la lista el addon de la fila enfocada (tecla *); en otras filas no hace nada.
sub removeFocusedAddon()
    id = rowIdAt(m.list.itemFocused)
    s = SettingsLoad()
    if Left(id, 4) = "src:" then
        s.streamAddons = AddonListRemove(s.streamAddons, rowOrdinal(id))
    else if Left(id, 4) = "sub:" then
        s.subAddons = AddonListRemove(s.subAddons, rowOrdinal(id))
    else
        return
    end if
    SettingsSave(s)
    refresh()
end sub

' Abre el teclado para un valor: "tmdbKey", "addsrc", "addsub" o "plugin:<id>". En el teclado se puede pegar desde
' la app móvil de Roku.
sub openKey(field as string, title as string, message as string, current as string)
    m.editing = field
    m.dialog = OpenKeyboardDialog(title, message, current, m.top, "onKeyboard")
end sub

sub onKeyboard()
    dlg = m.dialog
    if dlg = invalid then return
    idx = dlg.buttonSelected
    text = dlg.text
    dlg.close = true
    m.dialog = invalid
    if idx <> 0 then return
    s = SettingsLoad()
    field = m.editing
    badUrl = false
    if field = "tmdbKey" then
        s.tmdbKey = StripSpaces(text)
    else if field = "addsrc" or field = "addsub" then
        url = AddonNormalizeUrl(text)
        if url = "" then
            badUrl = StripSpaces(text) <> ""
        else if field = "addsrc" then
            s.streamAddons = AddonListAdd(s.streamAddons, url)
        else
            s.subAddons = AddonListAdd(s.subAddons, url)
        end if
    else if Left(field, 7) = "plugin:" then
        s = PluginApplyKeyboard(s, Mid(field, 8), text)
    end if
    SettingsSave(s)
    refresh()
    if badUrl then OpenMessageDialog(Tx("set_addsrc"), [Tx("set_addon_bad")], m.top)
end sub

' La lista da la vuelta sola; se evita: arriba en la primera fila sube a la barra, abajo en la ultima se queda.
sub onFocused()
    cur = m.list.itemFocused
    n = 0
    if m.list.content <> invalid then n = m.list.content.getChildCount()
    prev = m.prevFocus
    if n > 2 and cur >= 0 then
        if prev = 0 and cur = n - 1 then
            m.list.jumpToItem = 0
            m.prevFocus = 0
            m.nav.setFocus(true)
            return
        else if prev = n - 1 and cur = 0 then
            m.list.jumpToItem = n - 1
            m.prevFocus = n - 1
            return
        end if
    end if
    m.prevFocus = cur
end sub

sub onNav()
    m.top.action = { type: "nav", index: m.nav.selected }
end sub

sub activate()
    m.nav.index = 3
    refresh()
    m.list.setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "options" and m.list.isInFocusChain() then
        removeFocusedAddon()
        return true
    else if key = "up" and m.list.isInFocusChain() then
        if m.list.itemFocused = 0 then
            m.nav.setFocus(true)
            return true
        end if
    else if key = "down" and m.nav.isInFocusChain() then
        m.list.setFocus(true)
        return true
    end if
    return false
end function
