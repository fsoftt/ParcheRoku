' Reproductor.
'
' Flujo: 1) pide subtítulos (máx. 10 s) 2) reproduce la fuente elegida 3) si falla o no arranca en 45 s pasa a la
' siguiente fuente ya ordenada, retomando desde la última posición 4) guarda el avance cada 10 s para "Continuar
' viendo" y lo borra al terminar.

sub init()
    m.video = m.top.findNode("video")
    m.status = m.top.findNode("status")
    m.subsTimer = m.top.findNode("subsTimer")
    m.startTimer = m.top.findNode("startTimer")

    m.video.notificationInterval = 5
    m.video.observeField("state", "onState")
    m.video.observeField("position", "onPosition")
    m.video.observeField("availableAudioTracks", "onAudioTracks")
    m.subsTimer.observeField("fire", "onSubsTimeout")
    m.startTimer.observeField("fire", "onStartTimeout")

    m.req = invalid
    m.index = 0
    m.tracks = []
    m.started = false
    m.begun = false
    m.pendingId = -1
    m.lastPositionMs = 0
    m.durationMs = 0
    m.finishing = false
    m.lastSaveMs = 0
    m.prefLangs = DefaultLanguages()
    m.audioDone = false
end sub

sub onRequest()
    m.req = m.top.request
end sub

' Arranca al mostrarse la pantalla (ya dentro del árbol de nodos), una sola vez.
sub startFlow()
    if m.req = invalid or m.begun then return
    m.begun = true
    m.index = ToInt(m.req.index)
    m.lastPositionMs = ToInt(m.req.startMs)
    m.status.text = Tx("player_loading")
    m.status.visible = true

    item = m.req.item
    s = SettingsLoad()
    m.prefLangs = s.prefLangs
    if s.subLangs.Count() = 0 or s.subAddons.Count() = 0 or Left(NzStr(item.id), 2) <> "tt" then
        beginPlayback()
        return
    end if
    m.subsTimer.control = "start"
    m.pendingId = ApiRequest({
        kind: "subtitles"
        mediaType: NzStr(item.type, "movie")
        imdbId: item.id
        season: ToInt(m.req.season, -1)
        episode: ToInt(m.req.episode, -1)
        settings: s
    }, "onSubs")
end sub

sub onSubs(event as object)
    res = ApiTake(event)
    if res.reqId <> m.pendingId or m.started then return
    if res.ok then m.tracks = res.data.tracks
    beginPlayback()
end sub

sub onSubsTimeout()
    if not m.started then beginPlayback()
end sub

sub beginPlayback()
    if m.started then return
    m.started = true
    m.subsTimer.control = "stop"
    playSource(m.index)
end sub

' Texto que se muestra como título en el reproductor.
function displayTitle() as string
    t = NzStr(m.req.item.title)
    if ToInt(m.req.season, -1) >= 0 then t = t + "  " + Tx("home_s_e", m.req.season, m.req.episode)
    return t
end function

sub playSource(i as integer)
    src = m.req.sources[i]
    c = CreateObject("roSGNode", "ContentNode")
    c.url = src.url
    c.title = displayTitle()
    fmt = GuessStreamFormat(src.url)
    if fmt <> "" then c.streamFormat = fmt
    if m.lastPositionMs > 5000 then c.PlayStart = m.lastPositionMs / 1000

    if type(src.headers) = "roAssociativeArray" then
        hdrs = []
        for each k in src.headers
            hdrs.Push(k + ": " + NzStr(src.headers[k]))
        end for
        if hdrs.Count() > 0 then c.HttpHeaders = hdrs
    end if

    if m.tracks.Count() > 0 then
        st = []
        for each t in m.tracks
            st.Push({ Language: t.language, TrackName: t.url, Description: t.label })
        end for
        c.SubtitleTracks = st
        m.video.globalCaptionMode = "On"
    end if

    m.audioDone = false
    m.video.content = c
    m.video.control = "play"
    m.video.setFocus(true)
    m.startTimer.control = "stop"
    m.startTimer.control = "start"
end sub

sub onState()
    st = m.video.state
    if st = "playing" then
        m.startTimer.control = "stop"
        m.status.visible = false
        if m.tracks.Count() > 0 then m.video.subtitleTrack = m.tracks[0].url
    else if st = "paused" then
        saveProgress(true)
    else if st = "buffering" then
        m.status.visible = false
    else if st = "error" then
        m.startTimer.control = "stop"
        tryNext()
    else if st = "finished" then
        m.finishing = true
        finishWatching()
        m.top.action = { type: "back" }
    end if
end sub

' Pista de audio preferida: se aplica una sola vez por arranque, cuando Roku informa las pistas disponibles. Como no
' se vuelve a tocar después, un cambio manual del usuario no se pisa.
sub onAudioTracks()
    if m.audioDone then return
    tracks = m.video.availableAudioTracks
    if type(tracks) <> "roArray" or tracks.Count() = 0 then return
    m.audioDone = true
    if tracks.Count() < 2 then return
    id = AudioPickTrack(tracks, m.prefLangs)
    if id <> "" and id <> NzStr(m.video.audioTrack) then m.video.audioTrack = id
end sub

sub onStartTimeout()
    if m.video.state <> "playing" then
        m.video.control = "stop"
        tryNext()
    end if
end sub

' Pasa a la siguiente fuente; si no quedan, avisa a MainScene.
sub tryNext()
    if m.finishing then return
    saveProgress()
    if m.index + 1 < m.req.sources.Count() then
        m.index = m.index + 1
        m.status.text = Tx("player_trying")
        m.status.visible = true
        playSource(m.index)
    else
        m.finishing = true
        m.video.control = "stop"
        m.top.action = {
            type: "playFailed"
            item: m.req.item
            season: ToInt(m.req.season, -1)
            episode: ToInt(m.req.episode, -1)
            episodeTitle: NzStr(m.req.episodeTitle)
            fromPicker: m.req.sources.Count() > 1
        }
    end if
end sub

sub onPosition()
    curPos = m.video.position
    dur = m.video.duration
    if curPos = invalid or dur = invalid then return
    m.lastPositionMs = Int(curPos * 1000)
    if dur > 0 then m.durationMs = Int(dur * 1000)
    ' Guarda cada ~10 s.
    if m.lastPositionMs - m.lastSaveMs >= 10000 or m.lastPositionMs < m.lastSaveMs then saveProgress(true)
end sub

' Guarda el avance en "Continuar viendo" (CwReport ignora lo visto menos de un minuto). Con background = true
' (guardado periódico y pausa) la escritura va a un StoreTask para no bloquear el render; al salir o cambiar de fuente
' se escribe en el acto para que la pantalla anterior ya lea el dato nuevo.
sub saveProgress(background = false as boolean)
    if m.req = invalid or m.durationMs <= 0 then return
    src = m.req.sources[m.index]
    entry = ({
        item: CompactItem(m.req.item)
        season: ToInt(m.req.season, -1)
        episode: ToInt(m.req.episode, -1)
        episodeTitle: NzStr(m.req.episodeTitle)
        positionMs: m.lastPositionMs
        durationMs: m.durationMs
        updated: NowSeconds()
        source: { url: src.url, headers: src.headers, quality: src.quality }
    })
    if background then
        task = CreateObject("roSGNode", "StoreTask")
        task.entry = entry
        m.storeTask = task
        task.control = "RUN"
    else
        WatchReport(entry)
    end if
    m.lastSaveMs = m.lastPositionMs
end sub

' Al terminar la reproducción se quita de "Continuar viendo".
sub finishWatching()
    if m.req = invalid or m.durationMs <= 0 then return
    WatchReport({
        item: CompactItem(m.req.item)
        season: ToInt(m.req.season, -1)
        episode: ToInt(m.req.episode, -1)
        episodeTitle: ""
        positionMs: m.durationMs
        durationMs: m.durationMs
        updated: NowSeconds()
        source: invalid
    })
end sub

sub activate()
    startFlow()
    m.video.setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back" then
        m.finishing = true
        saveProgress()
        m.video.control = "stop"
        m.startTimer.control = "stop"
        m.top.action = { type: "back" }
        return true
    end if
    return false
end function
