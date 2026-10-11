' Ayudas comunes de las pruebas. Salida: una línea "PASS"/"FAIL" por comprobación y al final "RESULT: n fallos".

sub TestsInit()
    m.failures = 0
    m.checks = 0
end sub

sub TestsDone()
    print "RESULT: "; m.failures; " fallos de "; m.checks; " comprobaciones"
end sub

sub Eq(name as string, actual as dynamic, expected as dynamic)
    m.checks = m.checks + 1
    ok = false
    if type(actual) = "roArray" and type(expected) = "roArray" then
        ok = (FormatJson(actual) = FormatJson(expected))
    else
        ok = (actual = expected)
    end if
    if ok then
        print "PASS "; name
    else
        m.failures = m.failures + 1
        print "FAIL "; name; ": obtenido="; FormatJson(actual); " esperado="; FormatJson(expected)
    end if
end sub

function MakeStream(name as string, title as string, url as string) as object
    return { name: name, title: title, url: url }
end function

' Candidato ya analizado (ver Streams.brs) con lo mínimo para ordenar y describir.
function Cand(name as string, quality as string, priority as integer, langs as object, sizeGb as integer) as object
    return {
        name: name, title: name, quality: quality, priority: priority
        languages: langs, sizeBytes: sizeGb * 1073741824#, url: "https://x/" + name, tags: [], provider: ""
        availText: "", availColor: "0x9CA3AFFF", notice: false
    }
end function

function Names(list as object) as object
    out = []
    for each c in list
        out.Push(c.name)
    end for
    return out
end function

function Entry(id as string, season as integer, episode as integer, pos as integer, dur as integer, updated as integer) as object
    return { item: { id: id, tmdbId: 0, type: "movie", title: id }, season: season, episode: episode, positionMs: pos, durationMs: dur, updated: updated, source: invalid }
end function
