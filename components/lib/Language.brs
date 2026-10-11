' Detección de idiomas en nombres de release y conversión de códigos de subtítulos.
' Port de LanguageCodes.cs de Parche. Funciones puras.

function LangMulti() as string
    return "multi"
end function

' Mapa de banderas (código de país ISO 3166) a idioma.
function LangFlagMap() as object
    return {
        "ES": "es"
        "MX": "es-419"
        "AR": "es-419"
        "CO": "es-419"
        "CL": "es-419"
        "PE": "es-419"
        "VE": "es-419"
        "UY": "es-419"
        "EC": "es-419"
        "BO": "es-419"
        "PY": "es-419"
        "CR": "es-419"
        "PA": "es-419"
        "DO": "es-419"
        "GT": "es-419"
        "CU": "es-419"
        "GB": "en"
        "US": "en"
        "AU": "en"
        "CA": "en"
        "BR": "pt"
        "PT": "pt"
        "FR": "fr"
        "IT": "it"
        "DE": "de"
        "RU": "ru"
        "JP": "ja"
        "KR": "ko"
        "CN": "zh"
        "IN": "hi"
    }
end function

' Añade un código al arreglo si todavía no está.
sub LangAdd(list as object, code as string)
    if not ArrayHas(list, code) then list.Push(code)
end sub

' Extrae los idiomas de un texto (nombre + título del addon). Sin información devuelve ["en"].
function LangDetect(text as dynamic) as object
    result = []
    s = NzStr(text)

    ' Banderas: pares de indicadores regionales (U+1F1E6..U+1F1FF).
    flags = LangFlagMap()
    n = Len(s)
    i = 1
    while i < n
        a = Asc(Mid(s, i, 1))
        if a >= 127462 and a <= 127487 then
            b = Asc(Mid(s, i + 1, 1))
            if b >= 127462 and b <= 127487 then
                code = Chr(65 + a - 127462) + Chr(65 + b - 127462)
                if flags.DoesExist(code) then LangAdd(result, flags[code])
                i = i + 1
            end if
        end if
        i = i + 1
    end while

    if RxTest("(?<![A-Za-z])(LATINO|LATIN|LAT|LATAM)(?![A-Za-z])", s) then LangAdd(result, "es-419")
    if RxTest("(?<![A-Za-z])(SPANISH|ESPA(N|" + Chr(209) + "|" + Chr(241) + ")OL|ESP|CASTELLANO)(?![A-Za-z])", s) then LangAdd(result, "es")
    if RxTest("(?<![A-Za-z])(ENGLISH|ENG)(?![A-Za-z])", s) then LangAdd(result, "en")
    if RxTest("(?<![A-Za-z])(PORTUGUESE|PORTUGU(E|" + Chr(202) + "|" + Chr(234) + ")S|DUBLADO|PT-BR|PTBR)(?![A-Za-z])", s) then LangAdd(result, "pt")
    if RxTest("(?<![A-Za-z])(DUAL|MULTI)(?![A-Za-z])", s) then LangAdd(result, LangMulti())

    if result.Count() = 0 then result.Push("en")
    return result
end function

' Prueba una expresión regular sin distinguir mayúsculas.
function RxTest(pattern as string, text as string) as boolean
    rx = CreateObject("roRegex", pattern, "i")
    return rx.IsMatch(text)
end function

' ¿El idioma candidato satisface la preferencia? "es" acepta también "es-419".
function LangMatches(preferred as string, candidate as string) as boolean
    p = LCase(preferred)
    c = LCase(candidate)
    if p = c then return true
    if Instr(1, p, "-") = 0 then
        if Left(c, Len(p) + 1) = p + "-" then return true
    end if
    return false
end function

' Nombre en lenguaje llano de un código de idioma de release.
function LangLabel(code as string) as string
    c = LCase(code)
    if c = "es" then return Tx("lang_es")
    if c = "es-419" then return Tx("lang_latino")
    if c = "en" then return Tx("lang_en")
    if c = "pt" then return Tx("lang_pt")
    if c = "fr" then return Tx("lang_fr")
    if c = "it" then return Tx("lang_it")
    if c = "de" then return Tx("lang_de")
    if c = LangMulti() then return Tx("lang_multi")
    return UCase(code)
end function

' Códigos de idioma de pista de audio de Roku (ISO 639-2 o 639-1) que satisfacen una preferencia ("es", "es-419", "en").
function AudioLangCodes(pref as string) as object
    p = LCase(pref)
    if p = "es-419" then return ["es-419", "spl", "spa", "es"]
    if p = "es" then return ["spa", "es"]
    if p = "en" then return ["eng", "en"]
    return [p]
end function

' Elige la primera pista de audio (availableAudioTracks de Roku: { Track, Language, Name }) que cumple las
' preferencias en orden. Devuelve su identificador (Track) o "" si ninguna coincide (se queda la pista por defecto).
function AudioPickTrack(tracks as dynamic, prefLangs as dynamic) as string
    if type(tracks) <> "roArray" or type(prefLangs) <> "roArray" then return ""
    for each pref in prefLangs
        for each code in AudioLangCodes(NzStr(pref))
            for each t in tracks
                if type(t) = "roAssociativeArray" then
                    l = LCase(NzStr(t.Language))
                    if l = code or Left(l, Len(code) + 1) = code + "-" then return NzStr(t.Track)
                end if
            end for
        end for
    end for
    return ""
end function

' Tabla de subtítulos: código ISO 639-2 de OpenSubtitles -> [ISO 639-1, nombre].
function SubLangTable() as object
    return {
        spa: ["es", "Espa" + Chr(241) + "ol"]
        spl: ["es-419", "Espa" + Chr(241) + "ol (Latino)"]
        eng: ["en", "English"]
        por: ["pt", "Portugu" + Chr(234) + "s"]
        pob: ["pt-BR", "Portugu" + Chr(234) + "s (Brasil)"]
        fre: ["fr", "Fran" + Chr(231) + "ais"]
        fra: ["fr", "Fran" + Chr(231) + "ais"]
        ger: ["de", "Deutsch"]
        deu: ["de", "Deutsch"]
        ita: ["it", "Italiano"]
        nld: ["nl", "Nederlands"]
        dut: ["nl", "Nederlands"]
        pol: ["pl", "Polski"]
        tur: ["tr", "T" + Chr(252) + "rk" + Chr(231) + "e"]
        swe: ["sv", "Svenska"]
        cat: ["ca", "Catal" + Chr(224)]
        rus: ["ru", "Russian"]
        jpn: ["ja", "Japanese"]
        kor: ["ko", "Korean"]
        ara: ["ar", "Arabic"]
        zho: ["zh", "Chinese"]
        chi: ["zh", "Chinese"]
    }
end function

' ISO 639-2 -> ISO 639-1 (si no se conoce devuelve el código en minúsculas).
function SubLangToIso1(code as string) as string
    k = LCase(code.Trim())
    t = SubLangTable()
    if t.DoesExist(k) then return t[k][0]
    return k
end function

' Nombre para mostrar de un código de subtítulo.
function SubLangName(code as string) as string
    k = LCase(code.Trim())
    t = SubLangTable()
    if t.DoesExist(k) then return t[k][1]
    return UCase(k)
end function

' ¿Mismo idioma (aceptando códigos de 2 o 3 letras)?
function SubLangSame(subCode as string, wanted as string) as boolean
    return SubLangToIso1(subCode) = SubLangToIso1(wanted)
end function
