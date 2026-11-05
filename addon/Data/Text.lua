-- Text: GearPath's own words in the client's language. DRAFTS MADE BY
-- MACHINE, not by native speakers: corrections are welcome. The window,
-- its lists and Settings are covered; item tooltips and chat lines are
-- still English. "English text" in Settings turns the translations off.
--
-- Each line: t(English, German, French, Spanish, Portuguese, Russian,
-- Korean, Chinese (Simplified), Chinese (Traditional)). Mexican Spanish
-- uses the Spanish. Format codes (%s, %d...) keep the English order.

local _, GP = ...

local Text = { T = {} }
GP.Text = Text

Text.LANGS = { "deDE", "frFR", "esES", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
Text.SAME = { esMX = "esES" }

local T = Text.T
local function t(en, de, fr, es, pt, ru, ko, cn, tw)
    T[en] = { deDE = de, frFR = fr, esES = es, ptBR = pt, ruRU = ru, koKR = ko, zhCN = cn, zhTW = tw }
end

function Text.Lang(code)
    code = Text.SAME[code] or code
    for _, l in ipairs(Text.LANGS) do
        if l == code then return l end
    end
end

-- Fills GP.L for a client language (nil: back to English). Returns
-- whether anything was translated.
function Text.Apply(code)
    local L = GP.L
    for k in pairs(L) do rawset(L, k, nil) end
    local lang = code and Text.Lang(code)
    if not lang then return false end
    local n = 0
    for en, tr in pairs(T) do
        local v = tr[lang]
        if type(v) == "string" and v ~= "" then
            rawset(L, en, v)
            n = n + 1
        end
    end
    return n > 0
end

local function translateValues(tbl)
    if type(tbl) ~= "table" then return end
    for k, v in pairs(tbl) do
        if type(v) == "string" then tbl[k] = GP.L[v] end
    end
end

Text.NOTICE = "GearPath's window is in your game's language, translated by machine (a draft). Settings > Extras > English text switches it to English."

-- At load (before any window is built): the client's language, unless
-- "English text" is on.
GP.On("Loaded", function()
    local code = GetLocale and GP.Plain(GetLocale())
    Text.code = code
    Text.available = Text.Lang(code) ~= nil
    if not Text.available or GP.Setting("englishText") == true then return end
    Text.active = Text.Apply(code)
    if not Text.active then return end
    local UI = GP.UI or {}
    translateValues(UI.TIER_TEXT)
    translateValues(UI.CONTENT_LABELS)
    translateValues(UI.SORT_LABELS)
    translateValues(UI.Stats and UI.Stats.LABELS)
    translateValues(GP.Classes and GP.Classes.STAT_LABELS)
    for _, s in ipairs(GP.Slots and GP.Slots.LIST or {}) do s.label = GP.L[s.label] end
    BINDING_NAME_GEARPATH_TOGGLE = GP.L["Open or close GearPath"]
end)

GP.On("Login", function()
    if Text.active and GP.db and not GP.db.toldText then
        GP.db.toldText = true
        GP.Print(GP.L[Text.NOTICE])
    end
end)

-- ---------------------------------------------------------------------
-- The window: tabs, titles, sections, buttons
-- ---------------------------------------------------------------------

t("Character", "Charakter", "Personnage", "Personaje", "Personagem", "Персонаж", "캐릭터", "角色", "角色")
t("Route", "Route", "Itinéraire", "Ruta", "Rota", "Маршрут", "경로", "路线", "路線")
t("Browse", "Durchsuchen", "Parcourir", "Explorar", "Explorar", "Обзор", "찾아보기", "浏览", "瀏覽")
t("Settings", "Einstellungen", "Options", "Opciones", "Opções", "Настройки", "설정", "设置", "設定")
t("Open or close GearPath", "GearPath öffnen oder schließen", "Ouvrir ou fermer GearPath", "Abrir o cerrar GearPath",
    "Abrir ou fechar GearPath", "Открыть или закрыть GearPath", "GearPath 열기/닫기", "打开或关闭 GearPath", "開啟或關閉 GearPath")

t("Best now", "Jetzt holbar", "À prendre maintenant", "Mejor ahora", "Melhor agora", "Доступно сейчас", "지금 획득", "现在可得", "現在可得")
t("Worth chasing", "Lohnt die Jagd", "Vaut le détour", "Vale la pena buscar", "Vale a pena buscar", "Стоит добыть", "노려볼 만함", "值得追求", "值得追求")
t("Needs something first", "Braucht erst etwas", "Nécessite un prérequis", "Necesita algo antes", "Precisa de algo antes",
    "Нужны условия", "먼저 조건 필요", "需要先满足条件", "需要先滿足條件")
t("Nothing that needs a PvP rank, a reputation or a profession.", "Nichts, das einen PvP-Rang, Ruf oder Beruf braucht.",
    "Rien qui nécessite un rang JcJ, une réputation ou un métier.", "Nada que necesite un rango JcJ, reputación o profesión.",
    "Nada que precise de patente JxJ, reputação ou profissão.", "Нет ничего, что требует PvP-звания, репутации или профессии.",
    "PvP 계급, 평판, 전문 기술이 필요한 것이 없습니다.", "没有需要 PvP 军衔、声望或专业技能的物品。", "沒有需要 PvP 軍階、聲望或專業技能的物品。")
t("Near you", "In deiner Nähe", "Près de vous", "Cerca de ti", "Perto de você", "Рядом с вами", "주변", "附近", "附近")
t("Your gear route", "Deine Ausrüstungsroute", "Votre itinéraire d'équipement", "Tu ruta de equipo", "Sua rota de equipamento",
    "Ваш маршрут снаряжения", "장비 경로", "你的装备路线", "你的裝備路線")
t("Upgrades for every slot", "Verbesserungen für jeden Platz", "Améliorations pour chaque emplacement", "Mejoras para cada ranura",
    "Melhorias para cada espaço", "Улучшения для каждой ячейки", "모든 슬롯의 업그레이드", "所有栏位的提升", "所有欄位的提升")
t("Best now: easy to get at your level.  Worth chasing: dungeons, rares, long chains, a few levels away.",
    "Jetzt holbar: auf deiner Stufe leicht zu bekommen.  Lohnt die Jagd: Dungeons, seltene Gegner, lange Questreihen, ein paar Stufen entfernt.",
    "À prendre maintenant : facile à obtenir à votre niveau.  Vaut le détour : donjons, rares, longues chaînes, quelques niveaux plus loin.",
    "Mejor ahora: fácil de conseguir a tu nivel.  Vale la pena buscar: mazmorras, raros, cadenas largas, a unos niveles.",
    "Melhor agora: fácil de obter no seu nível.  Vale a pena buscar: masmorras, raros, cadeias longas, alguns níveis à frente.",
    "Доступно сейчас: легко получить на вашем уровне.  Стоит добыть: подземелья, редкие, длинные цепочки, через пару уровней.",
    "지금 획득: 현재 레벨에서 쉽게 얻음.  노려볼 만함: 던전, 희귀 몹, 긴 퀘스트 연계, 몇 레벨 뒤.",
    "现在可得：你的等级容易获得。  值得追求：地下城、稀有怪、长任务链、几级之后。",
    "現在可得：你的等級容易取得。  值得追求：地城、稀有怪、長任務鏈、幾級之後。")
t("All slots", "Alle Plätze", "Tous", "Todas", "Todos", "Все ячейки", "모든 슬롯", "所有栏位", "所有欄位")
t("Sort:", "Sortieren:", "Tri :", "Ordenar:", "Ordenar:", "Порядок:", "정렬:", "排序：", "排序：")
t("Show:", "Zeigen:", "Afficher :", "Mostrar:", "Mostrar:", "Показать:", "표시:", "显示：", "顯示：")
t("Search gear", "Ausrüstung suchen", "Chercher", "Buscar equipo", "Buscar equipamento", "Поиск снаряжения", "장비 검색", "搜索装备", "搜尋裝備")
t("Upgrades only", "Nur Verbesserungen", "Améliorations seules", "Solo mejoras", "Só melhorias", "Только улучшения", "업그레이드만", "仅提升", "僅提升")
t("Take it off", "Ausziehen", "Retirer", "Quitar", "Tirar", "Снять", "벗기", "脱下", "脫下")
t("Put it on", "Anlegen", "Équiper", "Equipar", "Equipar", "Надеть", "착용", "穿上", "穿上")
t("Put them on", "Alle anlegen", "Tout équiper", "Equipar todo", "Equipar tudo", "Надеть всё", "모두 착용", "全部穿上", "全部穿上")
t("binds", "wird gebunden", "se lie", "se liga", "vincula", "станет персональным", "귀속됨", "会绑定", "會綁定")
t("Close", "Schließen", "Fermer", "Cerrar", "Fechar", "Закрыть", "닫기", "关闭", "關閉")
t("Apply", "Übernehmen", "Appliquer", "Aplicar", "Aplicar", "Применить", "적용", "应用", "套用")
t("All", "Alle", "Tout", "Todo", "Tudo", "Все", "전체", "全部", "全部")
t("None", "Keine", "Aucun", "Nada", "Nenhum", "Ничего", "없음", "无", "無")
t("Everything", "Alles", "Tout", "Todo", "Tudo", "Всё", "전체", "全部", "全部")
t("Nothing", "Nichts", "Rien", "Nada", "Nada", "Ничего", "없음", "无", "無")
t("All but %s", "Alles außer %s", "Tout sauf %s", "Todo menos %s", "Tudo menos %s", "Всё, кроме: %s", "%s 제외 전체", "除%s外全部", "除%s外全部")
t("%d of %d kinds", "%d von %d Arten", "%d types sur %d", "%d de %d tipos", "%d de %d tipos", "%d из %d видов", "%d/%d 종류", "%d/%d 类", "%d/%d 類")
t("Empty", "Leer", "Vide", "Vacío", "Vazio", "Пусто", "비어 있음", "空", "空")
t("Nothing equipped", "Nichts angelegt", "Rien d'équipé", "Nada equipado", "Nada equipado", "Ничего не надето", "착용한 것 없음", "未装备", "未裝備")
t("Wearing %s", "Angelegt: %s", "Porté : %s", "Llevas: %s", "Usando: %s", "Надето: %s", "착용 중: %s", "已装备：%s", "已裝備：%s")
t("and", "und", "et", "y", "e", "и", "그리고", "和", "和")
t("Your stats", "Deine Werte", "Vos caractéristiques", "Tus atributos", "Seus atributos", "Ваши характеристики", "능력치", "你的属性", "你的屬性")
t("Share of your score", "Anteil an deiner Wertung", "Part de votre score", "Parte de tu puntuación", "Parte da sua pontuação",
    "Доля в оценке", "점수 비중", "占评分比例", "佔評分比例")
t("With %s", "Mit %s", "Avec %s", "Con %s", "Com %s", "С предметом %s", "%s 착용 시", "穿上%s", "穿上%s")
t("With the %d items you're trying on", "Mit den %d anprobierten Gegenständen", "Avec les %d objets essayés", "Con los %d objetos que pruebas",
    "Com os %d itens que você experimenta", "С примеряемыми предметами: %d", "착용해 보는 아이템 %d개", "试穿 %d 件物品", "試穿 %d 件物品")
t("Item level", "Gegenstandsstufe", "Niveau d'objet", "Nivel de objeto", "Nível de item", "Уровень предметов", "아이템 레벨", "物品等级", "物品等級")
t("GearPath score", "GearPath-Wertung", "Score GearPath", "Puntuación GearPath", "Pontuação GearPath", "Оценка GearPath", "GearPath 점수", "GearPath 评分", "GearPath 評分")
t("Click a slot for its upgrades. Click an item to try it on and see what it changes. Drag the model to turn it.",
    "Klicke auf einen Platz für seine Verbesserungen. Klicke auf einen Gegenstand, um ihn anzuprobieren. Ziehe das Modell, um es zu drehen.",
    "Cliquez sur un emplacement pour ses améliorations. Cliquez sur un objet pour l'essayer. Faites glisser le modèle pour le tourner.",
    "Haz clic en una ranura para ver sus mejoras. Haz clic en un objeto para probarlo. Arrastra el modelo para girarlo.",
    "Clique num espaço para ver as melhorias. Clique num item para experimentá-lo. Arraste o modelo para girá-lo.",
    "Нажмите на ячейку, чтобы увидеть улучшения. Нажмите на предмет, чтобы примерить его. Перетащите модель, чтобы повернуть.",
    "슬롯을 클릭하면 업그레이드가 보입니다. 아이템을 클릭하면 착용해 봅니다. 모델을 끌어 돌리세요.",
    "点击栏位查看提升。点击物品试穿并查看变化。拖动模型旋转。",
    "點擊欄位查看提升。點擊物品試穿並查看變化。拖曳模型旋轉。")
t("Click to see the upgrades for this slot.", "Klicken, um die Verbesserungen für diesen Platz zu sehen.",
    "Cliquez pour voir les améliorations de cet emplacement.", "Haz clic para ver las mejoras de esta ranura.",
    "Clique para ver as melhorias deste espaço.", "Нажмите, чтобы увидеть улучшения для этой ячейки.",
    "클릭하면 이 슬롯의 업그레이드가 보입니다.", "点击查看此栏位的提升。", "點擊查看此欄位的提升。")
t("Nothing to show yet.", "Noch nichts anzuzeigen.", "Rien à afficher pour l'instant.", "Nada que mostrar todavía.",
    "Nada para mostrar ainda.", "Пока нечего показать.", "아직 표시할 것이 없습니다.", "暂无内容。", "暫無內容。")
t("No gear matches.", "Keine passende Ausrüstung.", "Aucun équipement ne correspond.", "Ningún equipo coincide.",
    "Nenhum equipamento corresponde.", "Ничего не найдено.", "일치하는 장비가 없습니다.", "没有匹配的装备。", "沒有符合的裝備。")
t("Copy my weights", "Gewichte kopieren", "Copier mes poids", "Copiar mis pesos", "Copiar meus pesos", "Копировать веса",
    "가중치 복사", "复制我的权重", "複製我的權重")
t("Paste weights", "Gewichte einfügen", "Coller des poids", "Pegar pesos", "Colar pesos", "Вставить веса", "가중치 붙여넣기", "粘贴权重", "貼上權重")
t("Rescan database", "Datenbank neu lesen", "Relire la base", "Releer la base de datos", "Reler o banco de dados",
    "Перечитать базу", "데이터베이스 재검색", "重新扫描数据库", "重新掃描資料庫")
t("Reset stat weights", "Gewichte zurücksetzen", "Réinitialiser les poids", "Restablecer pesos", "Redefinir pesos",
    "Сбросить веса", "가중치 초기화", "重置属性权重", "重設屬性權重")
t("Forget learned gear", "Gelerntes vergessen", "Oublier l'appris", "Olvidar lo aprendido", "Esquecer o aprendido",
    "Забыть изученное", "학습한 장비 잊기", "忘记已学装备", "忘記已學裝備")
t("Check everything now", "Jetzt alles prüfen", "Tout vérifier", "Comprobar todo ahora", "Verificar tudo agora",
    "Проверить всё сейчас", "지금 모두 확인", "立即检查全部", "立即檢查全部")
t("Use these", "Übernehmen", "Utiliser", "Usar estos", "Usar estes", "Использовать", "이것으로 사용", "使用这些", "使用這些")

-- ---------------------------------------------------------------------
-- Counts (one form for any number: "Upgrades: 3")
-- ---------------------------------------------------------------------

t("%d upgrades", "Verbesserungen: %d", "Améliorations : %d", "Mejoras: %d", "Melhorias: %d", "Улучшений: %d", "업그레이드 %d개", "%d 项提升", "%d 項提升")
t("%d places", "Orte: %d", "Lieux : %d", "Lugares: %d", "Lugares: %d", "Мест: %d", "장소 %d곳", "%d 个地点", "%d 個地點")
t("%d upgrades in %d places", "Verbesserungen: %d, Orte: %d", "Améliorations : %d, lieux : %d", "Mejoras: %d, lugares: %d",
    "Melhorias: %d, lugares: %d", "Улучшений: %d, мест: %d", "업그레이드 %d개, 장소 %d곳", "%d 项提升，%d 个地点", "%d 項提升，%d 個地點")
t("%d items", "Gegenstände: %d", "Objets : %d", "Objetos: %d", "Itens: %d", "Предметов: %d", "아이템 %d개", "%d 件物品", "%d 件物品")
t("%d levels", "Stufen: %d", "Niveaux : %d", "Niveles: %d", "Níveis: %d", "Уровней: %d", "%d레벨", "%d 级", "%d 級")
t("%d empty slots", "Leere Plätze: %d", "Emplacements vides : %d", "Ranuras vacías: %d", "Espaços vazios: %d", "Пустых ячеек: %d",
    "빈 슬롯 %d개", "%d 个空栏位", "%d 個空欄位")
t("%d kinds", "Arten: %d", "types : %d", "tipos: %d", "tipos: %d", "видов: %d", "%d종류", "%d 种", "%d 種")
t("%d pts", "%d Pkt.", "%d pts", "%d pts", "%d pts", "%d очк.", "%d점", "%d 分", "%d 分")
t("%+.0f pts", "%+.0f Pkt.", "%+.0f pts", "%+.0f pts", "%+.0f pts", "%+.0f очк.", "%+.0f점", "%+.0f 分", "%+.0f 分")
t("%d min", "%d Min.", "%d min", "%d min", "%d min", "%d мин", "%d분", "%d 分钟", "%d 分鐘")
t("%d min ago", "vor %d Min.", "il y a %d min", "hace %d min", "há %d min", "%d мин назад", "%d분 전", "%d 分钟前", "%d 分鐘前")
t("%d h ago", "vor %d Std.", "il y a %d h", "hace %d h", "há %d h", "%d ч назад", "%d시간 전", "%d 小时前", "%d 小時前")
t("just now", "gerade eben", "à l'instant", "ahora mismo", "agora mesmo", "только что", "방금", "刚刚", "剛剛")
t("level %d", "Stufe %d", "niveau %d", "nivel %d", "nível %d", "уровень %d", "레벨 %d", "%d 级", "%d 級")
t("levels %d-%d", "Stufen %d-%d", "niveaux %d-%d", "niveles %d-%d", "níveis %d-%d", "уровни %d-%d", "레벨 %d-%d", "%d-%d 级", "%d-%d 級")
t("Off", "Aus", "Désactivé", "Desactivado", "Desligado", "Выкл.", "끔", "关闭", "關閉")
t("none", "keine", "aucune", "ninguna", "nenhuma", "нет", "없음", "无", "無")
t("new", "neu", "nouveau", "nuevo", "novo", "новое", "새 장비", "新", "新")
t("same", "gleich", "identique", "igual", "igual", "так же", "동일", "相同", "相同")

-- ---------------------------------------------------------------------
-- The status line, notes in the lists
-- ---------------------------------------------------------------------

t("Reading the gear database...", "Lese die Ausrüstungsdatenbank...", "Lecture de la base d'équipement...", "Leyendo la base de datos de equipo...",
    "Lendo o banco de dados de equipamentos...", "Чтение базы снаряжения...", "장비 데이터베이스 읽는 중...", "正在读取装备数据库……", "正在讀取裝備資料庫……")
t("Loading item details (%d left)...", "Lade Gegenstandsdetails (noch %d)...", "Chargement des objets (%d restants)...",
    "Cargando objetos (quedan %d)...", "Carregando itens (faltam %d)...", "Загрузка предметов (осталось %d)...",
    "아이템 정보 불러오는 중 (%d개 남음)...", "正在加载物品信息（剩余 %d）……", "正在載入物品資訊（剩餘 %d）……")
t("Getting ready...", "Wird vorbereitet...", "Préparation...", "Preparando...", "Preparando...", "Подготовка...", "준비 중...", "准备中……", "準備中……")
t("%d to get now, %d worth chasing", "%d jetzt holbar, %d lohnen die Jagd", "%d à prendre, %d valent le détour",
    "%d ahora, %d vale la pena buscar", "%d agora, %d vale a pena buscar", "сейчас: %d, стоит добыть: %d",
    "지금 %d개, 노려볼 만함 %d개", "现在可得 %d，值得追求 %d", "現在可得 %d，值得追求 %d")
t("QuestieDB not found", "QuestieDB nicht gefunden", "QuestieDB introuvable", "QuestieDB no encontrado", "QuestieDB não encontrado",
    "QuestieDB не найден", "QuestieDB 없음", "未找到 QuestieDB", "找不到 QuestieDB")
t("checked %s", "geprüft %s", "vérifié %s", "comprobado %s", "verificado %s", "проверено: %s", "확인: %s", "已检查：%s", "已檢查：%s")
t("%s, level %d %s", "%s, Stufe %d %s", "%s, niveau %d %s", "%s, nivel %d %s", "%s, nível %d %s", "%s, уровень %d, %s",
    "%s, 레벨 %d %s", "%s，%d 级%s", "%s，%d 級%s")
t("Still reading the gear database; the route fills in as items load.",
    "Die Datenbank wird noch gelesen; die Route füllt sich, während Gegenstände laden.",
    "Lecture de la base en cours ; l'itinéraire se remplit à mesure que les objets se chargent.",
    "Aún leyendo la base de datos; la ruta se completa a medida que cargan los objetos.",
    "Ainda lendo o banco de dados; a rota se preenche conforme os itens carregam.",
    "База ещё читается; маршрут заполнится по мере загрузки предметов.",
    "아직 데이터베이스를 읽는 중입니다. 아이템이 불러와지면 경로가 채워집니다.",
    "仍在读取数据库；物品加载后路线会逐步填充。", "仍在讀取資料庫；物品載入後路線會逐步填入。")
t("Still reading the gear database; the lists fill in as items load.",
    "Die Datenbank wird noch gelesen; die Listen füllen sich, während Gegenstände laden.",
    "Lecture de la base en cours ; les listes se remplissent à mesure que les objets se chargent.",
    "Aún leyendo la base de datos; las listas se completan a medida que cargan los objetos.",
    "Ainda lendo o banco de dados; as listas se preenchem conforme os itens carregam.",
    "База ещё читается; списки заполнятся по мере загрузки предметов.",
    "아직 데이터베이스를 읽는 중입니다. 아이템이 불러와지면 목록이 채워집니다.",
    "仍在读取数据库；物品加载后列表会逐步填充。", "仍在讀取資料庫；物品載入後清單會逐步填入。")
t("Still reading the gear database; more gear appears as items load.",
    "Die Datenbank wird noch gelesen; weitere Ausrüstung erscheint, während Gegenstände laden.",
    "Lecture de la base en cours ; d'autres objets apparaissent à mesure qu'ils se chargent.",
    "Aún leyendo la base de datos; aparecerá más equipo a medida que carguen los objetos.",
    "Ainda lendo o banco de dados; mais equipamentos aparecem conforme os itens carregam.",
    "База ещё читается; больше снаряжения появится по мере загрузки.",
    "아직 데이터베이스를 읽는 중입니다. 아이템이 불러와지면 장비가 더 나타납니다.",
    "仍在读取数据库；物品加载后会出现更多装备。", "仍在讀取資料庫；物品載入後會出現更多裝備。")
t("QuestieDB isn't installed, so only your bags and gear you've seen in game are listed. Install QuestieDB for every quest, drop and vendor.",
    "QuestieDB ist nicht installiert, daher stehen nur deine Taschen und im Spiel gesehene Ausrüstung hier. Installiere QuestieDB für alle Quests, Beute und Händler.",
    "QuestieDB n'est pas installé : seuls vos sacs et l'équipement vu en jeu sont listés. Installez QuestieDB pour toutes les quêtes, butins et marchands.",
    "QuestieDB no está instalado, así que solo se listan tus bolsas y el equipo visto en el juego. Instala QuestieDB para todas las misiones, botines y vendedores.",
    "O QuestieDB não está instalado, então só suas bolsas e o equipamento visto no jogo aparecem. Instale o QuestieDB para todas as missões, saques e vendedores.",
    "QuestieDB не установлен, поэтому показаны только сумки и снаряжение, увиденное в игре. Установите QuestieDB для всех заданий, добычи и торговцев.",
    "QuestieDB가 설치되지 않아 가방과 게임에서 본 장비만 표시됩니다. 모든 퀘스트, 전리품, 상인을 보려면 QuestieDB를 설치하세요.",
    "未安装 QuestieDB，只列出背包和游戏中见过的装备。安装 QuestieDB 即可显示所有任务、掉落和商人。",
    "未安裝 QuestieDB，只列出背包和遊戲中見過的裝備。安裝 QuestieDB 即可顯示所有任務、掉落和商人。")
t("Nothing here from what's ticked under Show.", "Nichts hier bei dem, was unter Zeigen angehakt ist.",
    "Rien ici parmi ce qui est coché dans Afficher.", "Nada aquí con lo marcado en Mostrar.", "Nada aqui com o que está marcado em Mostrar.",
    "Ничего среди отмеченного в «Показать».", "표시에서 선택한 항목 중 여기에 해당하는 것이 없습니다.", "“显示”中勾选的内容里，这里没有。", "「顯示」中勾選的內容裡，這裡沒有。")
t("Nothing for you here from what's ticked under Show.", "Hier nichts für dich bei dem, was unter Zeigen angehakt ist.",
    "Rien pour vous ici parmi ce qui est coché dans Afficher.", "Nada para ti aquí con lo marcado en Mostrar.",
    "Nada para você aqui com o que está marcado em Mostrar.", "Здесь для вас ничего среди отмеченного в «Показать».",
    "표시에서 선택한 항목 중 여기에서 얻을 것이 없습니다.", "“显示”中勾选的内容里，这里没有适合你的。", "「顯示」中勾選的內容裡，這裡沒有適合你的。")
t("Nothing to get at your level right now from what's ticked under Show.",
    "Bei dem, was unter Zeigen angehakt ist, gibt es auf deiner Stufe gerade nichts.",
    "Rien à obtenir à votre niveau parmi ce qui est coché dans Afficher.", "Nada que conseguir a tu nivel con lo marcado en Mostrar.",
    "Nada para obter no seu nível com o que está marcado em Mostrar.", "Сейчас на вашем уровне ничего среди отмеченного в «Показать».",
    "표시에서 선택한 항목 중 지금 레벨에서 얻을 것이 없습니다.", "“显示”中勾选的内容里，你目前的等级没有可得的。", "「顯示」中勾選的內容裡，你目前的等級沒有可得的。")
t("No upgrades to get at your level right now. Check Worth chasing below, or come back after a level or two.",
    "Gerade keine Verbesserungen auf deiner Stufe. Schau unten bei Lohnt die Jagd oder komm in ein, zwei Stufen wieder.",
    "Aucune amélioration à votre niveau pour l'instant. Regardez Vaut le détour plus bas, ou revenez dans un niveau ou deux.",
    "No hay mejoras a tu nivel ahora mismo. Mira Vale la pena buscar abajo, o vuelve en un nivel o dos.",
    "Sem melhorias no seu nível agora. Veja Vale a pena buscar abaixo, ou volte daqui a um ou dois níveis.",
    "Сейчас нет улучшений для вашего уровня. Загляните в «Стоит добыть» ниже или вернитесь через уровень-другой.",
    "지금 레벨에서 얻을 업그레이드가 없습니다. 아래 노려볼 만함을 보거나 한두 레벨 뒤에 다시 오세요.",
    "你目前的等级没有可得的提升。看看下方的“值得追求”，或升一两级后再来。",
    "你目前的等級沒有可得的提升。看看下方的「值得追求」，或升一兩級後再來。")
t("No upgrades to get here. The Route tab shows where to go.", "Hier gibt es keine Verbesserungen. Der Reiter Route zeigt, wohin.",
    "Aucune amélioration ici. L'onglet Itinéraire montre où aller.", "No hay mejoras aquí. La pestaña Ruta muestra adónde ir.",
    "Sem melhorias aqui. A aba Rota mostra aonde ir.", "Здесь улучшений нет. Вкладка «Маршрут» покажет, куда идти.",
    "여기에는 업그레이드가 없습니다. 경로 탭에서 갈 곳을 확인하세요.", "这里没有提升。“路线”标签页会告诉你去哪里。", "這裡沒有提升。「路線」分頁會告訴你去哪裡。")
t("and %d more here, farther away", "und %d weitere hier, weiter weg", "et %d de plus ici, plus loin", "y %d más aquí, más lejos",
    "e mais %d aqui, mais longe", "и ещё %d здесь, подальше", "그리고 여기 조금 먼 곳에 %d개 더", "此处更远还有 %d 个", "此處更遠還有 %d 個")
t("Nothing better you can get at your level yet.", "Noch nichts Besseres auf deiner Stufe.", "Rien de mieux à votre niveau pour l'instant.",
    "Aún nada mejor a tu nivel.", "Ainda nada melhor no seu nível.", "Пока ничего лучше на вашем уровне.",
    "아직 지금 레벨에서 더 좋은 것이 없습니다.", "你目前的等级还没有更好的。", "你目前的等級還沒有更好的。")
t("Nothing worth chasing within %d levels.", "Nichts, das die Jagd lohnt, innerhalb von %d Stufen.",
    "Rien qui vaille le détour d'ici %d niveaux.", "Nada que valga la pena buscar en %d niveles.",
    "Nada que valha a pena buscar em %d níveis.", "Ничего стоящего в пределах %d ур.", "%d레벨 안에 노려볼 만한 것이 없습니다.",
    "%d 级内没有值得追求的。", "%d 級內沒有值得追求的。")
t("Nothing worth chasing found yet.", "Noch nichts gefunden, das die Jagd lohnt.", "Rien qui vaille le détour pour l'instant.",
    "Aún no hay nada que valga la pena buscar.", "Ainda nada que valha a pena buscar.", "Пока ничего стоящего не найдено.",
    "아직 노려볼 만한 것이 없습니다.", "尚未找到值得追求的。", "尚未找到值得追求的。")
t("%s in %s%s. Click a place or an item for its map pin.", "%s, %s%s. Klicke auf einen Ort oder Gegenstand für die Kartenmarkierung.",
    "%s, %s%s. Cliquez sur un lieu ou un objet pour son repère sur la carte.", "%s, %s%s. Haz clic en un lugar u objeto para su marcador del mapa.",
    "%s, %s%s. Clique num lugar ou item para o marcador no mapa.", "%s, %s%s. Нажмите на место или предмет, чтобы поставить метку на карте.",
    "%s, %s%s. 장소나 아이템을 클릭하면 지도 핀을 꽂습니다.", "%s，%s%s。点击地点或物品放置地图标记。", "%s，%s%s。點擊地點或物品放置地圖標記。")
t("about +%d%% to your GearPath score", "etwa +%d%% auf deine GearPath-Wertung", "environ +%d%% à votre score GearPath",
    "unos +%d%% a tu puntuación GearPath", "cerca de +%d%% na sua pontuação GearPath", "примерно +%d%% к оценке GearPath",
    "GearPath 점수 약 +%d%%", "GearPath 评分约 +%d%%", "GearPath 評分約 +%d%%")
t("About +%d%% to your GearPath score", "Etwa +%d%% auf deine GearPath-Wertung", "Environ +%d%% à votre score GearPath",
    "Unos +%d%% a tu puntuación GearPath", "Cerca de +%d%% na sua pontuação GearPath", "Примерно +%d%% к оценке GearPath",
    "GearPath 점수 약 +%d%%", "GearPath 评分约 +%d%%", "GearPath 評分約 +%d%%")
t("A little more to your GearPath score", "Etwas mehr GearPath-Wertung", "Un peu plus de score GearPath", "Un poco más de puntuación GearPath",
    "Um pouco mais de pontuação GearPath", "Немного больше оценки GearPath", "GearPath 점수 조금 상승", "GearPath 评分略有提高", "GearPath 評分略有提高")
t("The best upgrade for each slot you can get now, grouped by where you go.",
    "Die beste Verbesserung je Platz, die du jetzt bekommen kannst, nach Ort gruppiert.",
    "La meilleure amélioration obtenable maintenant pour chaque emplacement, regroupée par lieu.",
    "La mejor mejora de cada ranura que puedes conseguir ahora, agrupada por lugar.",
    "A melhor melhoria de cada espaço que você pode obter agora, agrupada por lugar.",
    "Лучшее доступное сейчас улучшение для каждой ячейки, по местам.",
    "지금 얻을 수 있는 슬롯별 최고의 업그레이드를 장소별로 묶었습니다.", "每个栏位现在可得的最佳提升，按地点分组。", "每個欄位現在可得的最佳提升，按地點分組。")

-- ---------------------------------------------------------------------
-- Where an item comes from (each row's second line)
-- ---------------------------------------------------------------------

t("Where to get it isn't known yet", "Woher es kommt, ist noch unbekannt", "Provenance encore inconnue", "Aún no se sabe dónde conseguirlo",
    "Ainda não se sabe onde obter", "Пока неизвестно, где добыть", "아직 획득처를 모릅니다", "尚不知道在哪里获得", "尚不知道在哪裡取得")
t("In your bags: put it on", "In deinen Taschen: anlegen", "Dans vos sacs : à équiper", "En tus bolsas: equípalo", "Nas suas bolsas: equipe",
    "В сумках: наденьте", "가방에 있음: 착용하세요", "在背包中：穿上它", "在背包中：穿上它")
t("In your bags", "In deinen Taschen", "Dans vos sacs", "En tus bolsas", "Nas suas bolsas", "В сумках", "가방", "背包中", "背包中")
t("%s entrance, %s", "Eingang %s, %s", "Entrée de %s, %s", "Entrada de %s, %s", "Entrada de %s, %s", "Вход: %s, %s", "%s 입구, %s", "%s入口，%s", "%s入口，%s")
t("Quest: %s", "Quest: %s", "Quête : %s", "Misión: %s", "Missão: %s", "Задание: %s", "퀘스트: %s", "任务：%s", "任務：%s")
t("chain of %d, starts with %s", "Reihe aus %d, beginnt mit %s", "chaîne de %d, commence par %s", "cadena de %d, empieza con %s",
    "cadeia de %d, começa com %s", "цепочка из %d, начало: %s", "%d단계 연계, 시작: %s", "%d 环任务链，起始：%s", "%d 環任務鏈，起始：%s")
t("from %s", "bei %s", "auprès de %s", "de %s", "com %s", "у %s", "%s에게서", "从%s处", "從%s處")
t("in your quest log", "im Questlog", "dans votre journal", "en tu registro", "no seu registro", "в журнале заданий", "퀘스트 목록에 있음", "在任务日志中", "在任務日誌中")
t("starts inside the dungeon", "beginnt im Dungeon", "commence dans le donjon", "empieza dentro de la mazmorra", "começa dentro da masmorra",
    "начинается в подземелье", "던전 안에서 시작", "在地下城内开始", "在地城內開始")
t("Vendor: %s", "Händler: %s", "Marchand : %s", "Vendedor: %s", "Vendedor: %s", "Торговец: %s", "상인: %s", "商人：%s", "商人：%s")
t("Drop: %s", "Beute: %s", "Butin : %s", "Botín: %s", "Saque: %s", "Добыча: %s", "전리품: %s", "掉落：%s", "掉落：%s")
t("Found in: %s", "Zu finden in: %s", "Trouvé dans : %s", "Se encuentra en: %s", "Encontrado em: %s", "Находится в: %s", "발견 장소: %s", "位于：%s", "位於：%s")
t("World drop: random mobs", "Weltbeute: zufällige Gegner", "Butin mondial : monstres au hasard", "Botín del mundo: enemigos al azar",
    "Saque mundial: inimigos aleatórios", "Мировая добыча: случайные противники", "월드 드롭: 무작위 몹", "世界掉落：随机怪物", "世界掉落：隨機怪物")
t("Random chest loot (%d kinds of chest, like %s)", "Zufällige Truhenbeute (%d Truhenarten, z. B. %s)", "Butin de coffres au hasard (%d types, comme %s)",
    "Botín de cofres al azar (%d tipos, como %s)", "Saque de baús aleatórios (%d tipos, como %s)", "Добыча из случайных сундуков (%d видов, напр. %s)",
    "무작위 상자 전리품 (상자 %d종류, 예: %s)", "随机宝箱掉落（%d 种宝箱，如%s）", "隨機寶箱掉落（%d 種寶箱，如%s）")
t("Random chests: %s (spawns all over)", "Zufällige Truhen: %s (überall)", "Coffres au hasard : %s (un peu partout)", "Cofres al azar: %s (por todas partes)",
    "Baús aleatórios: %s (em todo lugar)", "Случайные сундуки: %s (повсюду)", "무작위 상자: %s (곳곳에 생성)", "随机宝箱：%s（到处刷新）", "隨機寶箱：%s（到處重生）")
t("Random chest loot", "Zufällige Truhenbeute", "Butin de coffres", "Botín de cofres", "Saque de baús", "Добыча из сундуков", "무작위 상자 전리품", "随机宝箱", "隨機寶箱")
t("Random world drops", "Zufällige Weltbeute", "Butin mondial", "Botín del mundo", "Saque mundial", "Мировая добыча", "무작위 월드 드롭", "随机世界掉落", "隨機世界掉落")
t("Somewhere unknown", "Unbekannter Ort", "Lieu inconnu", "Lugar desconocido", "Lugar desconhecido", "Неизвестно где", "알 수 없는 장소", "未知地点", "未知地點")
t("reported by other players", "von anderen Spielern gemeldet", "signalé par d'autres joueurs", "informado por otros jugadores",
    "relatado por outros jogadores", "по сообщениям игроков", "다른 플레이어 제보", "其他玩家报告", "其他玩家回報")
t("where isn't in the database yet", "Ort noch nicht in der Datenbank", "lieu absent de la base", "lugar aún no está en la base de datos",
    "local ainda não está no banco de dados", "места ещё нет в базе", "위치가 아직 데이터베이스에 없음", "数据库中尚无位置", "資料庫中尚無位置")
t("location unknown", "Ort unbekannt", "lieu inconnu", "lugar desconocido", "local desconhecido", "место неизвестно", "위치 모름", "位置未知", "位置未知")
t("Who starts it isn't in the database yet", "Wer sie vergibt, steht noch nicht in der Datenbank", "Qui la donne n'est pas encore dans la base",
    "Quién la da aún no está en la base de datos", "Quem a entrega ainda não está no banco de dados", "Кто выдаёт задание, в базе пока нет",
    "누가 주는지 아직 데이터베이스에 없음", "数据库中尚无任务发布者", "資料庫中尚無任務發布者")
t("Entrance: %s (%.1f, %.1f)", "Eingang: %s (%.1f, %.1f)", "Entrée : %s (%.1f, %.1f)", "Entrada: %s (%.1f, %.1f)", "Entrada: %s (%.1f, %.1f)",
    "Вход: %s (%.1f, %.1f)", "입구: %s (%.1f, %.1f)", "入口：%s（%.1f, %.1f）", "入口：%s（%.1f, %.1f）")
t("Elite", "Elite", "Élite", "Élite", "Elite", "Элита", "정예", "精英", "精英")
t("Rare Elite", "Seltene Elite", "Élite rare", "Élite raro", "Elite raro", "Редкая элита", "희귀 정예", "稀有精英", "稀有精英")
t("Boss", "Boss", "Boss", "Jefe", "Chefe", "Босс", "우두머리", "首领", "首領")
t("Rare", "Selten", "Rare", "Raro", "Raro", "Редкий", "희귀", "稀有", "稀有")
t("fills your empty %s slot", "füllt deinen leeren Platz %s", "remplit votre emplacement vide %s", "llena tu ranura vacía de %s",
    "preenche seu espaço vazio de %s", "займёт пустую ячейку: %s", "빈 %s 슬롯을 채움", "填补空着的%s栏位", "填補空著的%s欄位")
t("fills the empty slot", "füllt den leeren Platz", "remplit l'emplacement vide", "llena la ranura vacía", "preenche o espaço vazio",
    "займёт пустую ячейку", "빈 슬롯을 채움", "填补空栏位", "填補空欄位")
t("%s (empty now)", "%s (jetzt leer)", "%s (vide)", "%s (vacía)", "%s (vazio)", "%s (сейчас пусто)", "%s (비어 있음)", "%s（目前为空）", "%s（目前為空）")
t("right here", "genau hier", "juste ici", "aquí mismo", "bem aqui", "прямо здесь", "바로 여기", "就在这里", "就在這裡")

-- ---------------------------------------------------------------------
-- Clicks, tooltips, the stats panel
-- ---------------------------------------------------------------------

t("Click: try it on.  Right-click: map pin.  Ctrl-click: dressing room.  Shift-click: link.",
    "Klick: anprobieren.  Rechtsklick: Kartenmarkierung.  Strg-Klick: Anprobe.  Umschalt-Klick: verlinken.",
    "Clic : essayer.  Clic droit : repère sur la carte.  Ctrl-clic : cabine d'essayage.  Maj-clic : lien.",
    "Clic: probar.  Clic derecho: marcador del mapa.  Ctrl-clic: probador.  Mayús-clic: enlace.",
    "Clique: experimentar.  Clique direito: marcador no mapa.  Ctrl-clique: provador.  Shift-clique: link.",
    "Клик: примерить.  ПКМ: метка на карте.  Ctrl-клик: примерочная.  Shift-клик: ссылка.",
    "클릭: 착용해 보기.  우클릭: 지도 핀.  Ctrl-클릭: 미리보기.  Shift-클릭: 링크.",
    "点击：试穿。  右键：地图标记。  Ctrl-点击：试衣间。  Shift-点击：链接。",
    "點擊：試穿。  右鍵：地圖標記。  Ctrl-點擊：試衣間。  Shift-點擊：連結。")
t("Click: try it on.  Ctrl-click: dressing room.  Shift-click: link.",
    "Klick: anprobieren.  Strg-Klick: Anprobe.  Umschalt-Klick: verlinken.",
    "Clic : essayer.  Ctrl-clic : cabine d'essayage.  Maj-clic : lien.",
    "Clic: probar.  Ctrl-clic: probador.  Mayús-clic: enlace.",
    "Clique: experimentar.  Ctrl-clique: provador.  Shift-clique: link.",
    "Клик: примерить.  Ctrl-клик: примерочная.  Shift-клик: ссылка.",
    "클릭: 착용해 보기.  Ctrl-클릭: 미리보기.  Shift-클릭: 링크.",
    "点击：试穿。  Ctrl-点击：试衣间。  Shift-点击：链接。",
    "點擊：試穿。  Ctrl-點擊：試衣間。  Shift-點擊：連結。")
t("Click: map pin.  Ctrl-click: dressing room.  Shift-click: link.",
    "Klick: Kartenmarkierung.  Strg-Klick: Anprobe.  Umschalt-Klick: verlinken.",
    "Clic : repère sur la carte.  Ctrl-clic : cabine d'essayage.  Maj-clic : lien.",
    "Clic: marcador del mapa.  Ctrl-clic: probador.  Mayús-clic: enlace.",
    "Clique: marcador no mapa.  Ctrl-clique: provador.  Shift-clique: link.",
    "Клик: метка на карте.  Ctrl-клик: примерочная.  Shift-клик: ссылка.",
    "클릭: 지도 핀.  Ctrl-클릭: 미리보기.  Shift-클릭: 링크.",
    "点击：地图标记。  Ctrl-点击：试衣间。  Shift-点击：链接。",
    "點擊：地圖標記。  Ctrl-點擊：試衣間。  Shift-點擊：連結。")
t("No map pin: where it is isn't in the database yet.  Ctrl-click: dressing room.  Shift-click: link.",
    "Keine Kartenmarkierung: der Ort fehlt noch in der Datenbank.  Strg-Klick: Anprobe.  Umschalt-Klick: verlinken.",
    "Pas de repère : le lieu n'est pas encore dans la base.  Ctrl-clic : cabine d'essayage.  Maj-clic : lien.",
    "Sin marcador: el lugar aún no está en la base de datos.  Ctrl-clic: probador.  Mayús-clic: enlace.",
    "Sem marcador: o local ainda não está no banco de dados.  Ctrl-clique: provador.  Shift-clique: link.",
    "Метки нет: места ещё нет в базе.  Ctrl-клик: примерочная.  Shift-клик: ссылка.",
    "지도 핀 없음: 위치가 아직 데이터베이스에 없습니다.  Ctrl-클릭: 미리보기.  Shift-클릭: 링크.",
    "无地图标记：数据库中尚无位置。  Ctrl-点击：试衣间。  Shift-点击：链接。",
    "無地圖標記：資料庫中尚無位置。  Ctrl-點擊：試衣間。  Shift-點擊：連結。")
t("No map pin: where it is isn't in the database yet.", "Keine Kartenmarkierung: der Ort fehlt noch in der Datenbank.",
    "Pas de repère : le lieu n'est pas encore dans la base.", "Sin marcador: el lugar aún no está en la base de datos.",
    "Sem marcador: o local ainda não está no banco de dados.", "Метки нет: места ещё нет в базе.",
    "지도 핀 없음: 위치가 아직 데이터베이스에 없습니다.", "无地图标记：数据库中尚无位置。", "無地圖標記：資料庫中尚無位置。")
t("A: try it on.  X: map pin.", "A: anprobieren.  X: Kartenmarkierung.", "A : essayer.  X : repère sur la carte.", "A: probar.  X: marcador del mapa.",
    "A: experimentar.  X: marcador no mapa.", "A: примерить.  X: метка на карте.", "A: 착용해 보기.  X: 지도 핀.", "A：试穿。  X：地图标记。", "A：試穿。  X：地圖標記。")
t("A: try it on.", "A: anprobieren.", "A : essayer.", "A: probar.", "A: experimentar.", "A: примерить.", "A: 착용해 보기.", "A：试穿。", "A：試穿。")
t("A: map pin.", "A: Kartenmarkierung.", "A : repère sur la carte.", "A: marcador del mapa.", "A: marcador no mapa.", "A: метка на карте.", "A: 지도 핀.", "A：地图标记。", "A：地圖標記。")
t("Click to open GearPath.", "Klicken, um GearPath zu öffnen.", "Cliquez pour ouvrir GearPath.", "Haz clic para abrir GearPath.",
    "Clique para abrir o GearPath.", "Нажмите, чтобы открыть GearPath.", "클릭하면 GearPath가 열립니다.", "点击打开 GearPath。", "點擊開啟 GearPath。")
t("Click: open GearPath.  Right-click: Settings.", "Klick: GearPath öffnen.  Rechtsklick: Einstellungen.", "Clic : ouvrir GearPath.  Clic droit : options.",
    "Clic: abrir GearPath.  Clic derecho: opciones.", "Clique: abrir o GearPath.  Clique direito: opções.", "Клик: открыть GearPath.  ПКМ: настройки.",
    "클릭: GearPath 열기.  우클릭: 설정.", "点击：打开 GearPath。  右键：设置。", "點擊：開啟 GearPath。  右鍵：設定。")
t("Drag to move it round the minimap.", "Ziehen, um ihn am Minikartenrand zu verschieben.", "Faites glisser pour le déplacer autour de la minicarte.",
    "Arrastra para moverlo alrededor del minimapa.", "Arraste para movê-lo ao redor do minimapa.", "Перетащите, чтобы сдвинуть по краю миникарты.",
    "끌어서 미니맵 가장자리로 옮기세요.", "拖动以沿小地图边缘移动。", "拖曳以沿小地圖邊緣移動。")
t("%s to get now (best %s)", "%s jetzt holbar (beste: %s)", "%s à prendre (meilleure : %s)", "%s ahora (mejor: %s)", "%s agora (melhor: %s)",
    "%s сейчас (лучшее: %s)", "%s 지금 획득 가능 (최고: %s)", "%s 现在可得（最佳：%s）", "%s 現在可得（最佳：%s）")
t("%d more worth chasing", "%d weitere lohnen die Jagd", "%d autres valent le détour", "%d más vale la pena buscar", "mais %d vale a pena buscar",
    "ещё стоит добыть: %d", "노려볼 만한 것 %d개 더", "另有 %d 个值得追求", "另有 %d 個值得追求")
t("nothing better within reach yet", "noch nichts Besseres in Reichweite", "rien de mieux à portée pour l'instant", "aún nada mejor a tu alcance",
    "ainda nada melhor ao alcance", "пока ничего лучше в досягаемости", "아직 손닿는 곳에 더 좋은 것이 없음", "暂时没有更好的", "暫時沒有更好的")
t("Your gear's %s gives %d%% of your GearPath score.", "%s deiner Ausrüstung macht %d%% deiner GearPath-Wertung aus.",
    "%s de votre équipement fait %d%% de votre score GearPath.", "%s de tu equipo da el %d%% de tu puntuación GearPath.",
    "%s do seu equipamento dá %d%% da sua pontuação GearPath.", "%s снаряжения даёт %d%% оценки GearPath.",
    "장비의 %s이(가) GearPath 점수의 %d%%를 차지합니다.", "装备的%s占 GearPath 评分的 %d%%。", "裝備的%s佔 GearPath 評分的 %d%%。")
t("The game doesn't say this one; it's what your gear adds.", "Das Spiel nennt diesen Wert nicht; es ist, was deine Ausrüstung bringt.",
    "Le jeu ne donne pas cette valeur ; c'est ce qu'apporte votre équipement.", "El juego no da este valor; es lo que aporta tu equipo.",
    "O jogo não informa este valor; é o que seu equipamento soma.", "Игра не показывает это значение; это вклад снаряжения.",
    "게임이 알려주지 않는 값이라 장비가 더하는 수치입니다.", "游戏未提供此值；这是装备提供的数值。", "遊戲未提供此值；這是裝備提供的數值。")
t("With what you're trying on: %s", "Mit dem Anprobierten: %s", "Avec ce que vous essayez : %s", "Con lo que pruebas: %s", "Com o que você experimenta: %s",
    "С примеряемым: %s", "착용해 보는 장비로: %s", "试穿后：%s", "試穿後：%s")
t("Weight: %s points %s", "Gewichtung: %s Punkte %s", "Poids : %s points %s", "Peso: %s puntos %s", "Peso: %s pontos %s", "Вес: %s очк. %s",
    "가중치: %s점 %s", "权重：%s 分 %s", "權重：%s 分 %s")
t("per 1%", "pro 1%", "par 1%", "por 1%", "por 1%", "за 1%", "1%당", "每 1%", "每 1%")
t("each", "je Punkt", "par point", "por punto", "por ponto", "за единицу", "1당", "每点", "每點")

-- ---------------------------------------------------------------------
-- Putting gear on, the toast, the quest reward card, the text boxes
-- ---------------------------------------------------------------------

t("%s binds to you when you put it on: you can't trade it or sell it at the Auction House after. The game asks you to confirm first.",
    "%s wird beim Anlegen an dich gebunden: danach kannst du es nicht handeln oder im Auktionshaus verkaufen. Das Spiel fragt vorher nach.",
    "%s se lie à vous quand vous l'équipez : vous ne pourrez plus l'échanger ni le vendre à l'hôtel des ventes. Le jeu demande confirmation avant.",
    "%s se liga a ti al equiparlo: después no podrás comerciarlo ni venderlo en la casa de subastas. El juego te pide confirmación antes.",
    "%s fica vinculado a você ao equipar: depois não dá para negociar nem vender na casa de leilões. O jogo pede confirmação antes.",
    "%s станет персональным, когда вы его наденете: потом его нельзя будет обменять или продать на аукционе. Игра спросит подтверждение.",
    "%s은(는) 착용하면 귀속되어 거래하거나 경매장에 팔 수 없습니다. 게임이 먼저 확인을 요청합니다.",
    "%s 穿上后会绑定，之后无法交易或在拍卖行出售。游戏会先请你确认。",
    "%s 穿上後會綁定，之後無法交易或在拍賣場出售。遊戲會先請你確認。")
t("Not in combat: gear can't be changed in a fight.", "Nicht im Kampf: im Kampf lässt sich die Ausrüstung nicht wechseln.",
    "Pas en combat : l'équipement ne peut pas changer pendant un combat.", "Fuera de combate: el equipo no se puede cambiar en combate.",
    "Fora de combate: o equipamento não pode ser trocado em combate.", "Не в бою: в бою снаряжение менять нельзя.",
    "전투 중에는 장비를 바꿀 수 없습니다.", "非战斗中：战斗中无法更换装备。", "非戰鬥中：戰鬥中無法更換裝備。")
t("Upgrade: %s", "Verbesserung: %s", "Amélioration : %s", "Mejora: %s", "Melhoria: %s", "Улучшение: %s", "업그레이드: %s", "提升：%s", "提升：%s")
t("GearPath pick", "GearPath-Wahl", "Choix GearPath", "Elección GearPath", "Escolha GearPath", "Выбор GearPath", "GearPath 추천", "GearPath 推荐", "GearPath 推薦")
t("None are upgrades: sells for the most, %s", "Keine Verbesserung: bringt beim Händler am meisten, %s", "Aucune amélioration : se vend le plus cher, %s",
    "Ninguna es mejora: se vende por más, %s", "Nenhuma é melhoria: vende pelo maior valor, %s", "Улучшений нет: дороже всего продаётся, %s",
    "업그레이드 없음: 가장 비싸게 팔림, %s", "都不是提升：售价最高，%s", "都不是提升：售價最高，%s")
t("GearPath report", "GearPath-Bericht", "Rapport GearPath", "Informe de GearPath", "Relatório do GearPath", "Отчёт GearPath", "GearPath 보고서", "GearPath 报告", "GearPath 報告")
t("Press Ctrl+C to copy it, then paste it into your bug report.", "Mit Strg+C kopieren und dann in deinen Fehlerbericht einfügen.",
    "Ctrl+C pour copier, puis collez-le dans votre rapport de bug.", "Pulsa Ctrl+C para copiarlo y pégalo en tu informe de error.",
    "Pressione Ctrl+C para copiar e cole no seu relatório de erro.", "Нажмите Ctrl+C, чтобы скопировать, и вставьте в отчёт об ошибке.",
    "Ctrl+C로 복사해 버그 보고서에 붙여넣으세요.", "按 Ctrl+C 复制，然后粘贴到错误报告中。", "按 Ctrl+C 複製，然後貼到錯誤回報中。")
t("Your stat weights", "Deine Wertgewichte", "Vos poids de caractéristiques", "Tus pesos de atributos", "Seus pesos de atributos",
    "Ваши веса характеристик", "능력치 가중치", "你的属性权重", "你的屬性權重")
t("Press Ctrl+C to copy, then give it to another %s: Settings > Paste weights, or /gp weights followed by the string.",
    "Mit Strg+C kopieren und einem anderen %s geben: Einstellungen > Gewichte einfügen, oder /gp weights mit dem Text.",
    "Ctrl+C pour copier, puis donnez-le à un autre %s : Options > Coller des poids, ou /gp weights suivi du texte.",
    "Pulsa Ctrl+C para copiar y dáselo a otro %s: Opciones > Pegar pesos, o /gp weights seguido del texto.",
    "Pressione Ctrl+C para copiar e entregue a outro %s: Opções > Colar pesos, ou /gp weights seguido do texto.",
    "Нажмите Ctrl+C и передайте другому игроку (%s): Настройки > Вставить веса, или /gp weights и строка.",
    "Ctrl+C로 복사해 다른 %s에게 주세요: 설정 > 가중치 붙여넣기, 또는 /gp weights 뒤에 문자열.",
    "按 Ctrl+C 复制，然后交给另一位%s：设置 > 粘贴权重，或输入 /gp weights 加上该文本。",
    "按 Ctrl+C 複製，然後交給另一位%s：設定 > 貼上權重，或輸入 /gp weights 加上該文字。")
t("Paste stat weights", "Wertgewichte einfügen", "Coller des poids", "Pegar pesos", "Colar pesos", "Вставить веса", "가중치 붙여넣기", "粘贴属性权重", "貼上屬性權重")
t("Paste weights another GearPath user copied (Ctrl+V). They replace yours; Reset stat weights brings the defaults back.",
    "Füge Gewichte ein, die ein anderer GearPath-Nutzer kopiert hat (Strg+V). Sie ersetzen deine; Gewichte zurücksetzen stellt die Standardwerte wieder her.",
    "Collez les poids copiés par un autre joueur GearPath (Ctrl+V). Ils remplacent les vôtres ; Réinitialiser les poids rétablit les valeurs par défaut.",
    "Pega los pesos que copió otro usuario de GearPath (Ctrl+V). Sustituyen a los tuyos; Restablecer pesos recupera los predeterminados.",
    "Cole os pesos copiados por outro usuário do GearPath (Ctrl+V). Eles substituem os seus; Redefinir pesos volta ao padrão.",
    "Вставьте веса, скопированные другим игроком с GearPath (Ctrl+V). Они заменят ваши; «Сбросить веса» вернёт стандартные.",
    "다른 GearPath 사용자가 복사한 가중치를 붙여넣으세요 (Ctrl+V). 기존 값을 대체하며, 가중치 초기화로 기본값을 되돌립니다.",
    "粘贴其他 GearPath 用户复制的权重（Ctrl+V）。它们会替换你的权重；“重置属性权重”可恢复默认。",
    "貼上其他 GearPath 使用者複製的權重（Ctrl+V）。它們會取代你的權重；「重設屬性權重」可恢復預設。")
t("%s Checked %s: %d of %d need a second look. Hover them to see why.",
    "%s Geprüft %s: %d von %d brauchen einen zweiten Blick. Zeig darauf, um den Grund zu sehen.",
    "%s Vérifié %s : %d sur %d méritent un second regard. Survolez-les pour savoir pourquoi.",
    "%s Comprobado %s: %d de %d necesitan otra mirada. Pasa el ratón para ver por qué.",
    "%s Verificado %s: %d de %d precisam de outra olhada. Passe o mouse para ver o motivo.",
    "%s Проверено %s: %d из %d стоит перепроверить. Наведите курсор, чтобы узнать почему.",
    "%s 확인 %s: %d/%d개를 다시 볼 필요가 있습니다. 마우스를 올려 이유를 확인하세요.",
    "%s 已检查 %s：%d/%d 需要再看看。悬停查看原因。", "%s 已檢查 %s：%d/%d 需要再看看。懸停查看原因。")
t("%s Checked %s: the game and the database agree on all %d.",
    "%s Geprüft %s: Spiel und Datenbank stimmen bei allen %d überein.",
    "%s Vérifié %s : le jeu et la base concordent pour les %d.",
    "%s Comprobado %s: el juego y la base de datos coinciden en los %d.",
    "%s Verificado %s: o jogo e o banco de dados concordam em todos os %d.",
    "%s Проверено %s: игра и база совпадают по всем %d.",
    "%s 확인 %s: %d개 모두 게임과 데이터베이스가 일치합니다.",
    "%s 已检查 %s：全部 %d 个游戏与数据库一致。", "%s 已檢查 %s：全部 %d 個遊戲與資料庫一致。")

-- ---------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------

t("Look", "Aussehen", "Apparence", "Aspecto", "Aparência", "Вид", "모양", "外观", "外觀")
t("Window look", "Fensterstil", "Style de fenêtre", "Estilo de ventana", "Estilo da janela", "Стиль окна", "창 모양", "窗口外观", "視窗外觀")
t("Automatic", "Automatisch", "Automatique", "Automático", "Automático", "Автоматически", "자동", "自动", "自動")
t("Automatic uses DaylightUI's look when DaylightUI is on, the game's own look when it isn't.",
    "Automatisch nutzt den Stil von DaylightUI, wenn es an ist, sonst den des Spiels.",
    "Automatique utilise le style de DaylightUI s'il est actif, sinon celui du jeu.",
    "Automático usa el estilo de DaylightUI si está activo y, si no, el del juego.",
    "Automático usa o estilo do DaylightUI quando ativo e, se não, o do jogo.",
    "«Автоматически» — стиль DaylightUI, если он включён, иначе стиль игры.",
    "자동은 DaylightUI가 켜져 있으면 그 모양을, 아니면 게임 기본 모양을 씁니다.",
    "“自动”在启用 DaylightUI 时使用其外观，否则使用游戏原生外观。",
    "「自動」在啟用 DaylightUI 時使用其外觀，否則使用遊戲原生外觀。")
t("Showing: %s.", "Aktuell: %s.", "Actuel : %s.", "Mostrando: %s.", "Mostrando: %s.", "Сейчас: %s.", "현재: %s.", "当前：%s。", "目前：%s。")
t("Showing %s now; %s after a reload (type /reload).", "Jetzt %s; nach dem Neuladen %s (/reload eingeben).",
    "%s maintenant ; %s après rechargement (tapez /reload).", "Ahora %s; %s tras recargar (escribe /reload).",
    "Agora %s; %s depois de recarregar (digite /reload).", "Сейчас %s; после перезагрузки — %s (введите /reload).",
    "지금은 %s, 다시 불러오면 %s (/reload 입력).", "当前为%s；重载后为%s（输入 /reload）。", "目前為%s；重新載入後為%s（輸入 /reload）。")
t("Window scale", "Fenstergröße", "Échelle de la fenêtre", "Escala de la ventana", "Escala da janela", "Масштаб окна", "창 크기", "窗口缩放", "視窗縮放")
t("Makes everything in the window bigger or smaller. Drag the window's corner for more room.",
    "Macht alles im Fenster größer oder kleiner. Zieh an der Fensterecke für mehr Platz.",
    "Agrandit ou réduit tout le contenu. Tirez le coin de la fenêtre pour plus d'espace.",
    "Hace todo más grande o más pequeño. Arrastra la esquina de la ventana para más espacio.",
    "Deixa tudo maior ou menor. Arraste o canto da janela para mais espaço.",
    "Увеличивает или уменьшает всё в окне. Потяните угол окна, чтобы сделать его больше.",
    "창 안의 모든 것을 키우거나 줄입니다. 창 모서리를 끌면 더 넓어집니다.",
    "放大或缩小窗口内的一切。拖动窗口角落获得更多空间。", "放大或縮小視窗內的一切。拖曳視窗角落取得更多空間。")
t("What to look for", "Wonach suchen", "Quoi chercher", "Qué buscar", "O que procurar", "Что искать", "찾을 대상", "查找内容", "查找內容")
t("Look ahead", "Vorausschauen", "Anticiper", "Mirar adelante", "Olhar adiante", "Заглядывать вперёд", "미리 보기", "向前查看", "向前查看")
t("Show gear you can't wear yet, up to this many levels above you (under Worth chasing).",
    "Zeigt Ausrüstung, die du noch nicht tragen kannst, bis so viele Stufen über dir (unter Lohnt die Jagd).",
    "Montre l'équipement pas encore portable, jusqu'à ce nombre de niveaux au-dessus (dans Vaut le détour).",
    "Muestra equipo que aún no puedes llevar, hasta tantos niveles por encima (en Vale la pena buscar).",
    "Mostra equipamento que você ainda não pode usar, até tantos níveis acima (em Vale a pena buscar).",
    "Показывает снаряжение, которое пока нельзя надеть, до стольких уровней выше (в «Стоит добыть»).",
    "아직 착용할 수 없는 장비를 이만큼 높은 레벨까지 보여줍니다 (노려볼 만함 아래).",
    "显示暂时无法穿戴、最多高出你这么多级的装备（在“值得追求”下）。", "顯示暫時無法穿戴、最多高出你這麼多級的裝備（在「值得追求」下）。")
t("Best now range", "Bereich für Jetzt holbar", "Portée de À prendre maintenant", "Rango de Mejor ahora", "Alcance de Melhor agora",
    "Диапазон «Доступно сейчас»", "지금 획득 범위", "“现在可得”范围", "「現在可得」範圍")
t("Gear this many levels above you still counts as Best now, if it's easy to get (a quest or vendor out in the world).",
    "Ausrüstung bis so viele Stufen über dir zählt noch als Jetzt holbar, wenn sie leicht zu bekommen ist (Quest oder Händler draußen).",
    "L'équipement jusqu'à ce nombre de niveaux au-dessus compte encore comme À prendre maintenant s'il est facile à obtenir (quête ou marchand).",
    "El equipo hasta tantos niveles por encima sigue contando como Mejor ahora si es fácil de conseguir (misión o vendedor).",
    "Equipamento até tantos níveis acima ainda conta como Melhor agora se for fácil de obter (missão ou vendedor).",
    "Снаряжение до стольких уровней выше всё ещё считается «Доступно сейчас», если его легко получить (задание или торговец).",
    "이만큼 높은 레벨의 장비도 쉽게 얻을 수 있다면 (필드 퀘스트나 상인) 지금 획득으로 칩니다.",
    "高出你这么多级的装备，若容易获得（野外任务或商人），仍算“现在可得”。", "高出你這麼多級的裝備，若容易取得（野外任務或商人），仍算「現在可得」。")
t("Dungeon gear", "Dungeon-Ausrüstung", "Équipement de donjon", "Equipo de mazmorra", "Equipamento de masmorra", "Снаряжение из подземелий",
    "던전 장비", "地下城装备", "地城裝備")
t("List dungeon quests and drops under Worth chasing.", "Dungeon-Quests und -Beute unter Lohnt die Jagd aufführen.",
    "Lister les quêtes et butins de donjon dans Vaut le détour.", "Listar misiones y botín de mazmorras en Vale la pena buscar.",
    "Listar missões e saques de masmorra em Vale a pena buscar.", "Показывать задания и добычу подземелий в «Стоит добыть».",
    "던전 퀘스트와 전리품을 노려볼 만함에 표시합니다.", "将地下城任务和掉落列入“值得追求”。", "將地城任務和掉落列入「值得追求」。")
t("Also list gear that drops at random from many kinds of mobs (rarely worth farming).",
    "Auch Ausrüstung aufführen, die zufällig von vielen Gegnerarten fällt (lohnt selten das Farmen).",
    "Lister aussi l'équipement lâché au hasard par de nombreux monstres (rarement rentable).",
    "Listar también equipo que sueltan al azar muchos enemigos (rara vez vale la pena farmear).",
    "Listar também equipamento que cai aleatoriamente de muitos inimigos (raramente vale farmar).",
    "Показывать и снаряжение, случайно выпадающее со многих противников (фармить редко стоит).",
    "여러 몹에게서 무작위로 떨어지는 장비도 표시합니다 (파밍할 가치는 드묾).",
    "也列出许多怪物随机掉落的装备（很少值得刷）。", "也列出許多怪物隨機掉落的裝備（很少值得刷）。")
t("Healer gear", "Heilerausrüstung", "Équipement de soigneur", "Equipo de sanador", "Equipamento de curador", "Снаряжение лекаря", "치유 장비", "治疗装备", "治療裝備")
t("Gear made for healers (Healing is its main stat) is left out, and its loot roll tooltip says to let your healer roll. Turn this on to list it anyway.",
    "Ausrüstung für Heiler (Heilung als Hauptwert) wird weggelassen, und ihr Beute-Tooltip rät, den Heiler würfeln zu lassen. Einschalten, um sie trotzdem aufzuführen.",
    "L'équipement de soigneur (Soins en principale caractéristique) est exclu, et son infobulle de butin conseille de laisser le soigneur jeter les dés. Activez pour le lister quand même.",
    "El equipo de sanador (Sanación como atributo principal) se omite, y su descripción de botín sugiere dejar tirar al sanador. Actívalo para listarlo igualmente.",
    "Equipamento de curador (Cura como atributo principal) fica de fora, e a dica de saque sugere deixar o curador rolar. Ative para listar mesmo assim.",
    "Снаряжение для лекарей (исцеление — главный параметр) скрыто, а подсказка при добыче советует уступить лекарю. Включите, чтобы показывать его.",
    "치유가 주 능력치인 장비는 제외되고, 전리품 툴팁은 치유사에게 주사위를 양보하라고 알려줍니다. 켜면 그래도 표시합니다.",
    "治疗装备（以治疗为主属性）会被排除，其拾取提示会建议让治疗者掷骰。开启后仍会列出。",
    "治療裝備（以治療為主屬性）會被排除，其拾取提示會建議讓治療者擲骰。開啟後仍會列出。")
t("Extras", "Extras", "Extras", "Extras", "Extras", "Дополнительно", "추가 기능", "附加功能", "附加功能")
t("Tooltips", "Tooltips", "Infobulles", "Descripciones emergentes", "Dicas", "Подсказки", "툴팁", "鼠标提示", "滑鼠提示")
t("Adds GearPath's lines to tooltips: on gear, how much better it is and where to get it; on NPCs and mobs, the upgrades they drop, sell or give for a quest.",
    "Ergänzt Tooltips um GearPath-Zeilen: bei Ausrüstung, wie viel besser sie ist und woher sie kommt; bei NPCs und Gegnern, welche Verbesserungen sie fallen lassen, verkaufen oder für eine Quest geben.",
    "Ajoute les lignes GearPath aux infobulles : sur l'équipement, le gain et la provenance ; sur les PNJ et monstres, les améliorations qu'ils lâchent, vendent ou donnent en quête.",
    "Añade líneas de GearPath a las descripciones: en el equipo, cuánto mejora y dónde conseguirlo; en PNJ y enemigos, las mejoras que sueltan, venden o dan por misión.",
    "Adiciona linhas do GearPath às dicas: no equipamento, quanto melhora e onde obter; em PNJs e inimigos, as melhorias que derrubam, vendem ou dão em missões.",
    "Добавляет строки GearPath в подсказки: у снаряжения — насколько оно лучше и где его взять; у NPC и противников — какие улучшения они роняют, продают или дают за задания.",
    "툴팁에 GearPath 줄을 더합니다: 장비에는 얼마나 좋은지와 획득처, NPC와 몹에는 떨어뜨리거나 팔거나 퀘스트로 주는 업그레이드.",
    "在鼠标提示中加入 GearPath 信息：装备显示提升多少及来源；NPC 和怪物显示其掉落、出售或任务给予的提升。",
    "在滑鼠提示中加入 GearPath 資訊：裝備顯示提升多少及來源；NPC 和怪物顯示其掉落、出售或任務給予的提升。")
t("Minimap button", "Minikartenknopf", "Bouton de la minicarte", "Botón del minimapa", "Botão do minimapa", "Кнопка у миникарты", "미니맵 버튼", "小地图按钮", "小地圖按鈕")
t("A GearPath button on the minimap: click to open the window, right-click for Settings, drag to move it. GearPath also has a key binding (Key Bindings > AddOns).",
    "Ein GearPath-Knopf an der Minikarte: Klick öffnet das Fenster, Rechtsklick die Einstellungen, Ziehen verschiebt ihn. GearPath hat auch eine Tastenbelegung (Tastaturbelegung > AddOns).",
    "Un bouton GearPath sur la minicarte : clic pour ouvrir, clic droit pour les options, glisser pour le déplacer. GearPath a aussi un raccourci (Raccourcis > AddOns).",
    "Un botón de GearPath en el minimapa: clic para abrir, clic derecho para opciones, arrastrar para moverlo. GearPath también tiene un atajo (Asignación de teclas > Accesorios).",
    "Um botão do GearPath no minimapa: clique para abrir, clique direito para opções, arraste para mover. O GearPath também tem um atalho (Atalhos > AddOns).",
    "Кнопка GearPath у миникарты: клик открывает окно, ПКМ — настройки, перетаскивание двигает её. Есть и назначение клавиши (Назначение клавиш > Модификации).",
    "미니맵의 GearPath 버튼: 클릭하면 창, 우클릭하면 설정, 끌면 이동합니다. 단축키도 있습니다 (단축키 > 애드온).",
    "小地图上的 GearPath 按钮：点击打开窗口，右键打开设置，拖动可移动。GearPath 也有按键绑定（按键设置 > 插件）。",
    "小地圖上的 GearPath 按鈕：點擊開啟視窗，右鍵開啟設定，拖曳可移動。GearPath 也有按鍵設定（按鍵設定 > 插件）。")
t("Item levels", "Gegenstandsstufen", "Niveaux d'objet", "Niveles de objeto", "Níveis de item", "Уровни предметов", "아이템 레벨", "物品等级", "物品等級")
t("Shows each item's level on its slot in the game's own Character window, in the item's quality colour.",
    "Zeigt die Stufe jedes Gegenstands auf seinem Platz im Charakterfenster des Spiels, in der Qualitätsfarbe.",
    "Affiche le niveau de chaque objet sur son emplacement dans la fenêtre Personnage du jeu, dans la couleur de sa qualité.",
    "Muestra el nivel de cada objeto en su ranura de la ventana de personaje del juego, en el color de su calidad.",
    "Mostra o nível de cada item no seu espaço na janela de personagem do jogo, na cor da qualidade.",
    "Показывает уровень каждого предмета в его ячейке окна персонажа, цветом качества.",
    "게임 캐릭터 창의 각 슬롯에 아이템 레벨을 품질 색상으로 표시합니다.",
    "在游戏自带的角色窗口栏位上以品质颜色显示物品等级。", "在遊戲內建的角色視窗欄位上以品質顏色顯示物品等級。")
t("Upgrade notes", "Hinweise zu Verbesserungen", "Notes d'amélioration", "Avisos de mejoras", "Avisos de melhorias", "Заметки об улучшениях",
    "업그레이드 알림", "提升提示", "提升提示")
t("A toast when you put on an upgrade, and a line in chat when a vendor sells one or a level-up lets you wear one from your bags.",
    "Eine Einblendung, wenn du eine Verbesserung anlegst, und eine Chatzeile, wenn ein Händler eine verkauft oder ein Stufenaufstieg dir eine aus den Taschen erlaubt.",
    "Une notification quand vous équipez une amélioration, et une ligne de discussion quand un marchand en vend une ou qu'un niveau vous permet d'en porter une de vos sacs.",
    "Un aviso al equiparte una mejora, y una línea en el chat cuando un vendedor vende una o al subir de nivel puedes llevar una de tus bolsas.",
    "Um aviso ao equipar uma melhoria, e uma linha no chat quando um vendedor vende uma ou um novo nível libera uma das suas bolsas.",
    "Всплывающее окно, когда вы надеваете улучшение, и строка в чате, если торговец продаёт улучшение или новый уровень позволяет надеть вещь из сумок.",
    "업그레이드를 착용하면 알림이 뜨고, 상인이 팔거나 레벨업으로 가방 속 장비를 입을 수 있으면 채팅에 알려줍니다.",
    "穿上提升时弹出提示；商人出售提升或升级后可穿背包中的装备时在聊天中提示。",
    "穿上提升時彈出提示；商人出售提升或升級後可穿背包中的裝備時在聊天中提示。")
t("Learn as you play", "Beim Spielen lernen", "Apprendre en jouant", "Aprender jugando", "Aprender jogando", "Учиться по ходу игры", "플레이하며 학습", "边玩边学", "邊玩邊學")
t("Remember quest rewards, loot and vendor gear you see, so new items the database doesn't know yet still get a source.",
    "Merkt sich gesehene Questbelohnungen, Beute und Händlerwaren, damit neue Gegenstände, die die Datenbank noch nicht kennt, trotzdem eine Quelle haben.",
    "Retient les récompenses de quête, butins et objets de marchand vus, pour que les nouveaux objets inconnus de la base aient quand même une provenance.",
    "Recuerda recompensas de misión, botín y equipo de vendedor que ves, para que los objetos nuevos que la base de datos no conoce tengan origen.",
    "Lembra recompensas de missão, saques e itens de vendedor que você vê, para que itens novos que o banco de dados não conhece tenham origem.",
    "Запоминает увиденные награды, добычу и товары торговцев, чтобы у новых предметов, которых нет в базе, тоже был источник.",
    "본 퀘스트 보상, 전리품, 상인 장비를 기억해 데이터베이스가 모르는 새 아이템에도 획득처를 붙입니다.",
    "记住见过的任务奖励、掉落和商人装备，让数据库尚未收录的新物品也有来源。",
    "記住見過的任務獎勵、掉落和商人裝備，讓資料庫尚未收錄的新物品也有來源。")
t("Quest reward pick", "Questbelohnung wählen", "Choix de récompense", "Elección de recompensa", "Escolha de recompensa", "Выбор награды", "퀘스트 보상 추천", "任务奖励推荐", "任務獎勵推薦")
t("When a quest offers a choice, shows the best upgrade for you (or the best seller) beside the quest window, and in chat as you turn it in.",
    "Bietet eine Quest eine Wahl, zeigt sie neben dem Questfenster die beste Verbesserung für dich (oder was am meisten bringt) und nennt sie beim Abgeben im Chat.",
    "Quand une quête propose un choix, montre la meilleure amélioration (ou ce qui se vend le mieux) à côté de la fenêtre de quête, et dans la discussion à la remise.",
    "Cuando una misión ofrece elegir, muestra la mejor mejora para ti (o la que más vale) junto a la ventana de misión, y en el chat al entregarla.",
    "Quando uma missão oferece escolha, mostra a melhor melhoria para você (ou a que vende mais) ao lado da janela de missão, e no chat ao entregar.",
    "Когда задание предлагает выбор, показывает лучшее улучшение (или самую дорогую вещь) рядом с окном задания и в чате при сдаче.",
    "퀘스트 보상을 고를 때 퀘스트 창 옆에 최고의 업그레이드(또는 가장 비싼 것)를 보여주고, 완료할 때 채팅에도 알려줍니다.",
    "任务提供选择时，在任务窗口旁显示对你最好的提升（或售价最高的），交任务时在聊天中提示。",
    "任務提供選擇時，在任務視窗旁顯示對你最好的提升（或售價最高的），交任務時在聊天中提示。")
t("Rare watch", "Seltene im Blick", "Guet des rares", "Vigía de raros", "Vigia de raros", "Слежка за редкими", "희귀 몹 감시", "稀有怪监视", "稀有怪監視")
t("In a dungeon, an icon for each rare that drops an upgrade for you, lit with a sound when it's near. Hidden in combat; /gp rare brings it back.",
    "Im Dungeon ein Symbol für jeden seltenen Gegner mit einer Verbesserung für dich, das mit einem Ton aufleuchtet, wenn er nah ist. Im Kampf versteckt; /gp rare holt es zurück.",
    "En donjon, une icône par rare qui lâche une amélioration pour vous, allumée avec un son quand il est proche. Masquée en combat ; /gp rare la rétablit.",
    "En una mazmorra, un icono por cada raro que suelta una mejora para ti, que se ilumina con un sonido cuando está cerca. Oculto en combate; /gp rare lo recupera.",
    "Na masmorra, um ícone para cada raro que derruba uma melhoria para você, aceso com um som quando está perto. Oculto em combate; /gp rare o traz de volta.",
    "В подземелье — значок для каждого редкого противника с улучшением для вас; загорается со звуком, когда он рядом. Скрыт в бою; /gp rare возвращает его.",
    "던전에서 업그레이드를 떨어뜨리는 희귀 몹마다 아이콘을 띄우고, 가까이 오면 소리와 함께 켭니다. 전투 중 숨김, /gp rare로 다시 표시.",
    "在地下城中，为每个掉落你所需提升的稀有怪显示图标，靠近时亮起并发出声音。战斗中隐藏；/gp rare 可恢复。",
    "在地城中，為每個掉落你所需提升的稀有怪顯示圖示，靠近時亮起並發出聲音。戰鬥中隱藏；/gp rare 可恢復。")
t("Rare watch in the open world", "Seltene im Blick in der offenen Welt", "Guet des rares en monde ouvert", "Vigía de raros en el mundo abierto",
    "Vigia de raros no mundo aberto", "Слежка за редкими в открытом мире", "필드 희귀 몹 감시", "野外稀有怪监视", "野外稀有怪監視")
t("Out in the world, an icon, a sound and a chat line when a rare of your zone that drops an upgrade for you comes into view (its nameplate, a target, a minimap marker).",
    "In der offenen Welt ein Symbol, ein Ton und eine Chatzeile, wenn ein seltener Gegner deiner Zone mit einer Verbesserung für dich in Sicht kommt (Namensplakette, Ziel, Minikartenmarker).",
    "En monde ouvert, une icône, un son et une ligne de discussion quand un rare de votre zone qui lâche une amélioration apparaît (barre de nom, cible, marqueur de minicarte).",
    "En el mundo, un icono, un sonido y una línea de chat cuando aparece un raro de tu zona que suelta una mejora para ti (placa de nombre, objetivo, marcador del minimapa).",
    "No mundo, um ícone, um som e uma linha no chat quando um raro da sua zona que derruba uma melhoria aparece (placa de nome, alvo, marcador do minimapa).",
    "В открытом мире — значок, звук и строка в чате, когда редкий противник вашей зоны с улучшением для вас попадает в поле зрения (полоса имени, цель, метка на миникарте).",
    "필드에서 업그레이드를 떨어뜨리는 지역 희귀 몹이 보이면 (이름표, 대상, 미니맵 표시) 아이콘, 소리, 채팅으로 알려줍니다.",
    "在野外，当本区域掉落你所需提升的稀有怪出现在视野中（姓名板、目标、小地图标记）时，显示图标、发出声音并在聊天中提示。",
    "在野外，當本區域掉落你所需提升的稀有怪出現在視野中（名條、目標、小地圖標記）時，顯示圖示、發出聲音並在聊天中提示。")
t("English text", "Englischer Text", "Texte en anglais", "Texto en inglés", "Texto em inglês", "Текст на английском", "영어 텍스트", "英文文本", "英文文字")
t("GearPath's window is translated by machine (a draft). Turn this on to see it in English. Takes effect after a reload (type /reload).",
    "Das GearPath-Fenster ist maschinell übersetzt (ein Entwurf). Einschalten zeigt es auf Englisch. Wirkt nach dem Neuladen (/reload eingeben).",
    "La fenêtre de GearPath est traduite automatiquement (un brouillon). Activez pour l'afficher en anglais. Prend effet après rechargement (tapez /reload).",
    "La ventana de GearPath está traducida por máquina (un borrador). Actívalo para verla en inglés. Se aplica tras recargar (escribe /reload).",
    "A janela do GearPath foi traduzida por máquina (um rascunho). Ative para vê-la em inglês. Vale depois de recarregar (digite /reload).",
    "Окно GearPath переведено машинно (черновик). Включите, чтобы видеть его на английском. Сработает после перезагрузки (введите /reload).",
    "GearPath 창은 기계 번역(초안)입니다. 켜면 영어로 표시됩니다. 다시 불러온 뒤 적용됩니다 (/reload 입력).",
    "GearPath 窗口为机器翻译（草稿）。开启后显示英文。重载后生效（输入 /reload）。",
    "GearPath 視窗為機器翻譯（草稿）。開啟後顯示英文。重新載入後生效（輸入 /reload）。")
t("GearPath's window is in your game's language, translated by machine (a draft). Settings > Extras > English text switches it to English.",
    "Das GearPath-Fenster ist in der Sprache deines Spiels, maschinell übersetzt (ein Entwurf). Einstellungen > Extras > Englischer Text schaltet auf Englisch.",
    "La fenêtre de GearPath est dans la langue de votre jeu, traduite automatiquement (un brouillon). Options > Extras > Texte en anglais repasse en anglais.",
    "La ventana de GearPath está en el idioma de tu juego, traducida por máquina (un borrador). Opciones > Extras > Texto en inglés la pasa al inglés.",
    "A janela do GearPath está no idioma do seu jogo, traduzida por máquina (um rascunho). Opções > Extras > Texto em inglês muda para inglês.",
    "Окно GearPath на языке вашей игры, переведено машинно (черновик). Настройки > Дополнительно > Текст на английском переключит на английский.",
    "GearPath 창이 게임 언어로 기계 번역(초안)되어 있습니다. 설정 > 추가 기능 > 영어 텍스트로 영어로 바꿀 수 있습니다.",
    "GearPath 窗口已使用游戏语言显示（机器翻译草稿）。设置 > 附加功能 > 英文文本 可切换为英文。",
    "GearPath 視窗已使用遊戲語言顯示（機器翻譯草稿）。設定 > 附加功能 > 英文文字 可切換為英文。")
t("Checking and sharing", "Prüfen und Teilen", "Vérification et partage", "Comprobación y compartir", "Verificação e compartilhamento",
    "Проверка и обмен", "확인 및 공유", "检查与共享", "檢查與共享")
t("GearPath double-checks where items come from, and can trade what players see in game with other GearPath users.",
    "GearPath prüft nach, woher Gegenstände kommen, und kann Gesehenes mit anderen GearPath-Nutzern austauschen.",
    "GearPath revérifie la provenance des objets et peut échanger ce que les joueurs voient en jeu avec d'autres utilisateurs de GearPath.",
    "GearPath comprueba de dónde vienen los objetos y puede intercambiar lo que se ve en el juego con otros usuarios de GearPath.",
    "O GearPath confere de onde vêm os itens e pode trocar o que os jogadores veem no jogo com outros usuários do GearPath.",
    "GearPath перепроверяет, откуда берутся предметы, и может обмениваться увиденным в игре с другими пользователями GearPath.",
    "GearPath는 아이템 획득처를 다시 확인하고, 게임에서 본 것을 다른 GearPath 사용자와 주고받을 수 있습니다.",
    "GearPath 会复查物品来源，并可与其他 GearPath 用户交换游戏中看到的信息。", "GearPath 會複查物品來源，並可與其他 GearPath 使用者交換遊戲中看到的資訊。")
t("Check a slot when you click it", "Platz beim Anklicken prüfen", "Vérifier un emplacement au clic", "Comprobar una ranura al hacer clic",
    "Verificar um espaço ao clicar", "Проверять ячейку по клику", "슬롯 클릭 시 확인", "点击栏位时检查", "點擊欄位時檢查")
t("Asks the database again about that slot's items (finished quests, quests you picked up) and compares them with the game.",
    "Fragt die Datenbank erneut nach den Gegenständen dieses Platzes (abgeschlossene, angenommene Quests) und vergleicht sie mit dem Spiel.",
    "Réinterroge la base sur les objets de cet emplacement (quêtes finies, quêtes acceptées) et les compare au jeu.",
    "Vuelve a consultar la base de datos sobre los objetos de esa ranura (misiones terminadas o aceptadas) y los compara con el juego.",
    "Consulta de novo o banco de dados sobre os itens desse espaço (missões concluídas ou aceitas) e compara com o jogo.",
    "Заново спрашивает базу о предметах этой ячейки (выполненные и взятые задания) и сверяет с игрой.",
    "그 슬롯의 아이템을 데이터베이스에 다시 묻고 (완료한 퀘스트, 받은 퀘스트) 게임과 비교합니다.",
    "重新向数据库查询该栏位的物品（已完成、已接受的任务）并与游戏比对。", "重新向資料庫查詢該欄位的物品（已完成、已接受的任務）並與遊戲比對。")
t("Check everything every", "Alles prüfen alle", "Tout vérifier toutes les", "Comprobar todo cada", "Verificar tudo a cada", "Проверять всё каждые",
    "전체 확인 주기", "全部检查间隔", "全部檢查間隔")
t("Also checks every item in the background this often, out of combat.", "Prüft außerdem in diesem Abstand alle Gegenstände im Hintergrund, außerhalb des Kampfes.",
    "Vérifie aussi tous les objets en arrière-plan à cette fréquence, hors combat.", "También comprueba todos los objetos en segundo plano con esta frecuencia, fuera de combate.",
    "Também verifica todos os itens em segundo plano com essa frequência, fora de combate.", "Также проверяет все предметы в фоне с такой частотой, вне боя.",
    "전투 중이 아닐 때 이 주기로 모든 아이템을 백그라운드에서 확인합니다.", "非战斗时以此间隔在后台检查所有物品。", "非戰鬥時以此間隔在背景檢查所有物品。")
t("Share what you see", "Gesehenes teilen", "Partager ce que vous voyez", "Compartir lo que ves", "Compartilhar o que você vê", "Делиться увиденным",
    "본 것 공유", "共享所见", "共享所見")
t("Trades the quest rewards, loot and vendor gear you see with other GearPath users. Only item, quest, NPC and map numbers are sent.",
    "Tauscht gesehene Questbelohnungen, Beute und Händlerwaren mit anderen GearPath-Nutzern. Gesendet werden nur Gegenstands-, Quest-, NPC- und Kartennummern.",
    "Échange les récompenses, butins et objets de marchand vus avec les autres utilisateurs de GearPath. Seuls des numéros d'objet, de quête, de PNJ et de carte sont envoyés.",
    "Intercambia recompensas, botín y equipo de vendedor que ves con otros usuarios de GearPath. Solo se envían números de objeto, misión, PNJ y mapa.",
    "Troca recompensas, saques e itens de vendedor que você vê com outros usuários do GearPath. Só números de item, missão, PNJ e mapa são enviados.",
    "Обменивается увиденными наградами, добычей и товарами с другими пользователями GearPath. Отправляются только номера предметов, заданий, NPC и карт.",
    "본 퀘스트 보상, 전리품, 상인 장비를 다른 GearPath 사용자와 주고받습니다. 아이템·퀘스트·NPC·지도 번호만 보냅니다.",
    "与其他 GearPath 用户交换你看到的任务奖励、掉落和商人装备。只发送物品、任务、NPC 和地图编号。",
    "與其他 GearPath 使用者交換你看到的任務獎勵、掉落和商人裝備。只傳送物品、任務、NPC 和地圖編號。")
t("Use the GearPath channel", "GearPath-Kanal nutzen", "Utiliser le canal GearPath", "Usar el canal de GearPath", "Usar o canal do GearPath",
    "Использовать канал GearPath", "GearPath 채널 사용", "使用 GearPath 频道", "使用 GearPath 頻道")
t("Also trades with every other GearPath user online, through a hidden chat channel. Turn it off to share with only your guild and group.",
    "Tauscht auch mit allen anderen GearPath-Nutzern, die online sind, über einen versteckten Chatkanal. Ausschalten, um nur mit Gilde und Gruppe zu teilen.",
    "Échange aussi avec tous les autres utilisateurs de GearPath en ligne, via un canal de discussion caché. Désactivez-le pour ne partager qu'avec votre guilde et votre groupe.",
    "También intercambia con todos los demás usuarios de GearPath conectados, por un canal de chat oculto. Desactívalo para compartir solo con tu hermandad y grupo.",
    "Também troca com todos os outros usuários do GearPath online, por um canal de chat oculto. Desligue para compartilhar só com sua guilda e grupo.",
    "Также обменивается со всеми остальными пользователями GearPath в сети через скрытый канал чата. Выключите, чтобы делиться только с гильдией и группой.",
    "숨겨진 채팅 채널로 접속 중인 다른 모든 GearPath 사용자와도 주고받습니다. 길드와 파티하고만 공유하려면 끄세요.",
    "也会通过隐藏聊天频道与所有在线的其他 GearPath 用户交换。关闭后只与公会和队伍共享。",
    "也會透過隱藏聊天頻道與所有線上的其他 GearPath 使用者交換。關閉後只與公會和隊伍共享。")
t("GearPath shares where gear comes from with every GearPath player through a hidden chat channel (only item, quest, NPC and map numbers). To share with only your guild and group, turn off \"Use the GearPath channel\" in Settings.",
    "GearPath teilt mit allen GearPath-Spielern über einen versteckten Chatkanal, woher Ausrüstung stammt (nur Gegenstands-, Quest-, NPC- und Kartennummern). Um nur mit Gilde und Gruppe zu teilen, schalte in den Einstellungen \"GearPath-Kanal nutzen\" aus.",
    "GearPath partage l'origine de l'équipement avec tous les joueurs de GearPath via un canal de discussion caché (uniquement des numéros d'objet, de quête, de PNJ et de carte). Pour ne partager qu'avec votre guilde et votre groupe, désactivez \"Utiliser le canal GearPath\" dans les paramètres.",
    "GearPath comparte de dónde sale el equipo con todos los jugadores de GearPath por un canal de chat oculto (solo números de objeto, misión, PNJ y mapa). Para compartir solo con tu hermandad y grupo, desactiva \"Usar el canal de GearPath\" en la configuración.",
    "O GearPath compartilha de onde vem o equipamento com todos os jogadores do GearPath por um canal de chat oculto (só números de item, missão, PNJ e mapa). Para compartilhar só com sua guilda e grupo, desligue \"Usar o canal do GearPath\" nas configurações.",
    "GearPath сообщает всем игрокам с GearPath, откуда берётся снаряжение, через скрытый канал чата (только номера предметов, заданий, NPC и карт). Чтобы делиться только с гильдией и группой, выключите \"Использовать канал GearPath\" в настройках.",
    "GearPath는 숨겨진 채팅 채널로 모든 GearPath 플레이어와 장비 획득처를 공유합니다(아이템·퀘스트·NPC·지도 번호만). 길드와 파티하고만 공유하려면 설정에서 \"GearPath 채널 사용\"을 끄세요.",
    "GearPath 通过隐藏聊天频道与所有 GearPath 玩家共享装备来源（只有物品、任务、NPC 和地图编号）。如只想与公会和队伍共享，请在设置中关闭“使用 GearPath 频道”。",
    "GearPath 透過隱藏聊天頻道與所有 GearPath 玩家共享裝備來源（只有物品、任務、NPC 和地圖編號）。如只想與公會和隊伍共享，請在設定中關閉「使用 GearPath 頻道」。")
t("Stat weights", "Wertgewichte", "Poids des caractéristiques", "Pesos de atributos", "Pesos de atributos", "Веса характеристик", "능력치 가중치", "属性权重", "屬性權重")
t("How many points 1 of each stat is worth to you (hit, crit and haste: per 1%). Type a number; it's used as soon as you click away.",
    "Wie viele Punkte 1 jedes Werts für dich wert ist (Treffer, Krit und Tempo: pro 1%). Zahl eingeben; sie gilt, sobald du wegklickst.",
    "Combien de points vaut 1 de chaque caractéristique (toucher, critique et hâte : par 1%). Tapez un nombre ; il s'applique dès que vous cliquez ailleurs.",
    "Cuántos puntos vale para ti 1 de cada atributo (golpe, crítico y celeridad: por 1%). Escribe un número; se usa al hacer clic fuera.",
    "Quantos pontos vale 1 de cada atributo (acerto, crítico e aceleração: por 1%). Digite um número; vale assim que você clicar fora.",
    "Сколько очков стоит 1 единица каждой характеристики (меткость, крит и скорость: за 1%). Введите число; оно применится, когда вы щёлкнете в другом месте.",
    "각 능력치 1이 몇 점인지 정합니다 (적중, 치명타, 가속: 1%당). 숫자를 입력하고 다른 곳을 클릭하면 적용됩니다.",
    "每点属性值多少分（命中、暴击、急速：每 1%）。输入数字，点击别处即生效。",
    "每點屬性值多少分（命中、致命一擊、加速：每 1%）。輸入數字，點擊別處即生效。")

-- ---------------------------------------------------------------------
-- Labels: the Show: filter, sorting, stats, schools, slots
-- ---------------------------------------------------------------------

t("Quests", "Quests", "Quêtes", "Misiones", "Missões", "Задания", "퀘스트", "任务", "任務")
t("Dungeons", "Dungeons", "Donjons", "Mazmorras", "Masmorras", "Подземелья", "던전", "地下城", "地城")
t("Vendors", "Händler", "Marchands", "Vendedores", "Vendedores", "Торговцы", "상인", "商人", "商人")
t("Mob drops & rares", "Gegnerbeute & Seltene", "Butins & rares", "Botín de enemigos y raros", "Saques e raros", "Добыча и редкие", "몹 전리품 및 희귀 몹", "怪物掉落和稀有", "怪物掉落和稀有")
t("World drops & chests", "Weltbeute & Truhen", "Butin mondial & coffres", "Botín del mundo y cofres", "Saque mundial e baús", "Мировая добыча и сундуки", "월드 드롭 및 상자", "世界掉落和宝箱", "世界掉落和寶箱")
t("PvP rank", "PvP-Rang", "Rang JcJ", "Rango JcJ", "Patente JxJ", "PvP-звание", "PvP 계급", "PvP 军衔", "PvP 軍階")
t("Reputation", "Ruf", "Réputation", "Reputación", "Reputação", "Репутация", "평판", "声望", "聲望")
t("Professions", "Berufe", "Métiers", "Profesiones", "Profissões", "Профессии", "전문 기술", "专业技能", "專業技能")
t("item level", "Gegenstandsstufe", "niveau d'objet", "nivel de objeto", "nível de item", "уровень предмета", "아이템 레벨", "物品等级", "物品等級")
t("biggest gain", "größter Gewinn", "plus gros gain", "mayor mejora", "maior ganho", "наибольший прирост", "최대 향상", "提升最大", "提升最大")
t("required level", "benötigte Stufe", "niveau requis", "nivel requerido", "nível exigido", "требуемый уровень", "요구 레벨", "需要等级", "需要等級")
t("name", "Name", "nom", "nombre", "nome", "название", "이름", "名称", "名稱")

t("Holy", "Heilig", "Sacré", "Sagrado", "Sagrado", "Свет", "신성", "神圣", "神聖")
t("Fire", "Feuer", "Feu", "Fuego", "Fogo", "Огонь", "화염", "火焰", "火焰")
t("Nature", "Natur", "Nature", "Naturaleza", "Natureza", "Природа", "자연", "自然", "自然")
t("Frost", "Frost", "Givre", "Escarcha", "Gelo", "Лёд", "냉기", "冰霜", "冰霜")
t("Shadow", "Schatten", "Ombre", "Sombras", "Sombra", "Тьма", "암흑", "暗影", "暗影")
t("Arcane", "Arkan", "Arcane", "Arcano", "Arcano", "Тайная магия", "비전", "奥术", "秘法")

t("Spell Power", "Zaubermacht", "Puissance des sorts", "Poder con hechizos", "Poder mágico", "Сила заклинаний", "주문력", "法术强度", "法術能量")
t("Hit", "Treffer", "Toucher", "Golpe", "Acerto", "Меткость", "적중", "命中", "命中")
t("Crit", "Krit", "Critique", "Crítico", "Crítico", "Крит", "치명타", "暴击", "致命一擊")
t("Haste", "Tempo", "Hâte", "Celeridad", "Aceleração", "Скорость", "가속", "急速", "加速")
t("Intellect", "Intelligenz", "Intelligence", "Intelecto", "Intelecto", "Интеллект", "지능", "智力", "智力")
t("Spirit", "Willenskraft", "Esprit", "Espíritu", "Espírito", "Дух", "정신력", "精神", "精神")
t("Stamina", "Ausdauer", "Endurance", "Aguante", "Vigor", "Выносливость", "체력", "耐力", "耐力")
t("Strength", "Stärke", "Force", "Fuerza", "Força", "Сила", "힘", "力量", "力量")
t("Agility", "Beweglichkeit", "Agilité", "Agilidad", "Agilidade", "Ловкость", "민첩성", "敏捷", "敏捷")
t("Attack Power", "Angriffskraft", "Puissance d'attaque", "Poder de ataque", "Poder de ataque", "Сила атаки", "전투력", "攻击强度", "攻擊強度")
t("Ranged Attack Power", "Distanzangriffskraft", "Puissance d'attaque à distance", "Poder de ataque a distancia", "Poder de ataque à distância",
    "Сила атаки дальнего боя", "원거리 전투력", "远程攻击强度", "遠程攻擊強度")
t("Armor", "Rüstung", "Armure", "Armadura", "Armadura", "Броня", "방어도", "护甲", "護甲")
t("Mana per 5", "Mana alle 5", "Mana toutes les 5", "Maná cada 5", "Mana a cada 5", "Мана за 5", "5초당 마나", "每5秒法力", "每5秒法力")
t("Mana per 5 sec", "Mana alle 5 Sek.", "Mana toutes les 5 s", "Maná cada 5 s", "Mana a cada 5 s", "Мана за 5 сек.", "5초당 마나", "每5秒法力回复", "每5秒法力恢復")
t("Expertise", "Waffenkunde", "Expertise", "Pericia", "Aptidão", "Мастерство", "숙련", "精准", "熟練")
t("Defense", "Verteidigung", "Défense", "Defensa", "Defesa", "Защита", "방어", "防御", "防禦")
t("Block", "Blocken", "Blocage", "Bloqueo", "Bloqueio", "Блок", "방패 막기", "格挡", "格擋")
t("Dodge", "Ausweichen", "Esquive", "Esquivar", "Esquiva", "Уклонение", "회피", "躲闪", "閃躲")
t("Parry", "Parieren", "Parade", "Parada", "Aparo", "Парирование", "무기 막기", "招架", "招架")
t("Shadow Damage", "Schattenschaden", "Dégâts d'ombre", "Daño de Sombras", "Dano de Sombra", "Урон от темной магии", "암흑 피해", "暗影伤害", "暗影傷害")
t("Fire Damage", "Feuerschaden", "Dégâts de feu", "Daño de Fuego", "Dano de Fogo", "Урон от огня", "화염 피해", "火焰伤害", "火焰傷害")
t("Frost Damage", "Frostschaden", "Dégâts de givre", "Daño de Escarcha", "Dano de Gelo", "Урон от магии льда", "냉기 피해", "冰霜伤害", "冰霜傷害")
t("Arcane Damage", "Arkanschaden", "Dégâts des arcanes", "Daño Arcano", "Dano Arcano", "Урон от тайной магии", "비전 피해", "奥术伤害", "秘法傷害")
t("Nature Damage", "Naturschaden", "Dégâts de nature", "Daño de Naturaleza", "Dano de Natureza", "Урон от сил природы", "자연 피해", "自然伤害", "自然傷害")
t("Holy Damage", "Heiligschaden", "Dégâts sacrés", "Daño Sagrado", "Dano Sagrado", "Урон от светлой магии", "신성 피해", "神圣伤害", "神聖傷害")
t("Healing", "Heilung", "Soins", "Sanación", "Cura", "Исцеление", "치유량", "治疗", "治療")
t("Hit %", "Treffer %", "Toucher %", "Golpe %", "Acerto %", "Меткость %", "적중 %", "命中 %", "命中 %")
t("Crit %", "Krit %", "Critique %", "Crítico %", "Crítico %", "Крит %", "치명타 %", "暴击 %", "致命一擊 %")
t("Haste %", "Tempo %", "Hâte %", "Celeridad %", "Aceleração %", "Скорость %", "가속 %", "急速 %", "加速 %")
t("Dodge %", "Ausweichen %", "Esquive %", "Esquivar %", "Esquiva %", "Уклонение %", "회피 %", "躲闪 %", "閃躲 %")
t("Parry %", "Parieren %", "Parade %", "Parada %", "Aparo %", "Парирование %", "무기 막기 %", "招架 %", "招架 %")
t("Block Value", "Blockwert", "Valeur de blocage", "Valor de bloqueo", "Valor de bloqueio", "Показатель блока", "방패 막기 피해 감소량", "格挡值", "格擋值")
t("Weapon DPS", "Waffen-DPS", "DPS de l'arme", "DPS del arma", "DPS da arma", "УВС оружия", "무기 초당 공격력", "武器每秒伤害", "武器每秒傷害")
t("Off-hand DPS", "Schildhand-DPS", "DPS main gauche", "DPS de mano izquierda", "DPS da mão secundária", "УВС левой руки", "보조 장비 초당 공격력", "副手每秒伤害", "副手每秒傷害")
t("Ranged DPS", "Distanz-DPS", "DPS à distance", "DPS a distancia", "DPS à distância", "УВС дальнего боя", "원거리 초당 공격력", "远程每秒伤害", "遠程每秒傷害")
t("Wand DPS", "Zauberstab-DPS", "DPS de baguette", "DPS de varita", "DPS de varinha", "УВС жезла", "마법봉 초당 공격력", "魔杖每秒伤害", "魔杖每秒傷害")

t("Head", "Kopf", "Tête", "Cabeza", "Cabeça", "Голова", "머리", "头部", "頭部")
t("Neck", "Hals", "Cou", "Cuello", "Pescoço", "Шея", "목", "颈部", "頸部")
t("Shoulders", "Schultern", "Épaules", "Hombros", "Ombros", "Плечи", "어깨", "肩部", "肩部")
t("Shirt", "Hemd", "Chemise", "Camisa", "Camisa", "Рубашка", "속옷", "衬衣", "襯衣")
t("Chest", "Brust", "Torse", "Pecho", "Torso", "Грудь", "가슴", "胸部", "胸部")
t("Waist", "Taille", "Taille", "Cintura", "Cintura", "Пояс", "허리", "腰部", "腰部")
t("Legs", "Beine", "Jambes", "Piernas", "Pernas", "Ноги", "다리", "腿部", "腿部")
t("Feet", "Füße", "Pieds", "Pies", "Pés", "Ступни", "발", "脚", "腳")
t("Wrists", "Handgelenke", "Poignets", "Muñecas", "Pulsos", "Запястья", "손목", "手腕", "手腕")
t("Hands", "Hände", "Mains", "Manos", "Mãos", "Кисти рук", "손", "手", "手")
t("Ring 1", "Ring 1", "Anneau 1", "Anillo 1", "Anel 1", "Кольцо 1", "반지 1", "戒指 1", "戒指 1")
t("Ring 2", "Ring 2", "Anneau 2", "Anillo 2", "Anel 2", "Кольцо 2", "반지 2", "戒指 2", "戒指 2")
t("Trinket 1", "Schmuck 1", "Bijou 1", "Abalorio 1", "Berloque 1", "Аксессуар 1", "장신구 1", "饰品 1", "飾品 1")
t("Trinket 2", "Schmuck 2", "Bijou 2", "Abalorio 2", "Berloque 2", "Аксессуар 2", "장신구 2", "饰品 2", "飾品 2")
t("Back", "Rücken", "Dos", "Espalda", "Costas", "Спина", "등", "背部", "背部")
t("Main Hand", "Waffenhand", "Main droite", "Mano derecha", "Mão principal", "Правая рука", "주장비", "主手", "主手")
t("Off Hand", "Schildhand", "Main gauche", "Mano izquierda", "Mão secundária", "Левая рука", "보조장비", "副手", "副手")
t("Ranged", "Distanz", "À distance", "A distancia", "À distância", "Дальний бой", "원거리", "远程", "遠程")
t("Tabard", "Wappenrock", "Tabard", "Tabardo", "Tabardo", "Гербовая накидка", "휘장", "战袍", "外袍")

-- ---------------------------------------------------------------------
-- Training (weapon skills, armor, Dual Wield)
-- ---------------------------------------------------------------------

t("Learn %s first", "Erst %s lernen", "Apprendre %s d'abord", "Aprende %s primero", "Aprenda %s primeiro", "Сначала изучите: %s",
    "먼저 %s 배우기", "先学习%s", "先學習%s")
t("Learn %s first: your class trainer", "Erst %s lernen: bei deinem Klassenlehrer", "Apprendre %s d'abord : auprès de votre maître de classe",
    "Aprende %s primero: con tu instructor de clase", "Aprenda %s primeiro: com seu instrutor de classe",
    "Сначала изучите: %s, у наставника вашего класса", "먼저 %s 배우기: 직업 전문가", "先学习%s：找你的职业训练师", "先學習%s：找你的職業訓練師")
t("Learn %s first: %s, %s (%s)", "Erst %s lernen: %s, %s (%s)", "Apprendre %s d'abord : %s, %s (%s)", "Aprende %s primero: %s, %s (%s)",
    "Aprenda %s primeiro: %s, %s (%s)", "Сначала изучите: %s — %s, %s (%s)", "먼저 %s 배우기: %s, %s (%s)", "先学习%s：%s，%s（%s）", "先學習%s：%s，%s（%s）")
t("from level %d", "ab Stufe %d", "dès le niveau %d", "desde el nivel %d", "a partir do nível %d", "с %d-го уровня", "%d레벨부터", "%d 级起", "%d 級起")
t("Learn %s: %s, %s (%s)", "%s lernen: %s, %s (%s)", "Apprendre %s : %s, %s (%s)", "Aprender %s: %s, %s (%s)", "Aprender %s: %s, %s (%s)",
    "Изучить: %s — %s, %s (%s)", "%s 배우기: %s, %s (%s)", "学习%s：%s，%s（%s）", "學習%s：%s，%s（%s）")
t("Learn %s at your class trainer", "%s bei deinem Klassenlehrer lernen", "Apprendre %s auprès de votre maître de classe",
    "Aprender %s con tu instructor de clase", "Aprender %s com seu instrutor de classe", "Изучить у наставника класса: %s",
    "직업 전문가에게서 %s 배우기", "找职业训练师学习%s", "找職業訓練師學習%s")
t("for %d upgrades", "für Verbesserungen: %d", "pour améliorations : %d", "para mejoras: %d", "para melhorias: %d", "для улучшений: %d",
    "업그레이드 %d개용", "用于 %d 项提升", "用於 %d 項提升")

-- ---------------------------------------------------------------------
-- Specs
-- ---------------------------------------------------------------------

t("Spec", "Spezialisierung", "Spécialisation", "Especialización", "Especialização", "Специализация", "전문화", "专精", "專精")
t("Which stats count, and for melee and hunters which weapon speed. Healing specs list healer gear. Your own changes to the weights are kept for each spec.",
    "Welche Werte zählen, für Nahkämpfer und Jäger auch das Waffentempo. Heilerspezialisierungen führen Heilerausrüstung auf. Deine eigenen Gewichte bleiben je Spezialisierung erhalten.",
    "Quelles caractéristiques comptent, et pour la mêlée et les chasseurs la vitesse d'arme. Les spécialisations de soin listent l'équipement de soigneur. Vos propres poids sont gardés pour chaque spécialisation.",
    "Qué atributos cuentan y, para cuerpo a cuerpo y cazadores, la velocidad del arma. Las especializaciones de sanación listan equipo de sanador. Tus propios pesos se guardan para cada especialización.",
    "Quais atributos contam e, para corpo a corpo e caçadores, a velocidade da arma. Especializações de cura listam equipamento de curador. Seus próprios pesos ficam guardados para cada especialização.",
    "Какие характеристики важны, а для ближнего боя и охотников — скорость оружия. Лечащие специализации показывают снаряжение лекаря. Ваши собственные веса сохраняются для каждой специализации.",
    "어떤 능력치가 중요한지, 근접과 사냥꾼은 무기 속도도 정합니다. 치유 전문화는 치유 장비를 표시합니다. 직접 바꾼 가중치는 전문화마다 따로 저장됩니다.",
    "决定哪些属性重要，近战和猎人还包括武器速度。治疗专精会列出治疗装备。你自己调整的权重会按专精分别保存。",
    "決定哪些屬性重要，近戰和獵人還包括武器速度。治療專精會列出治療裝備。你自己調整的權重會按專精分別保存。")
t("Fury", "Furor", "Fureur", "Furia", "Fúria", "Неистовство", "분노", "狂怒", "狂怒")
t("Arms", "Waffen", "Armes", "Armas", "Armas", "Оружие", "무기", "武器", "武器")
t("Protection", "Schutz", "Protection", "Protección", "Proteção", "Защита", "방어", "防护", "防護")
t("Retribution", "Vergeltung", "Vindicte", "Reprensión", "Retribuição", "Воздаяние", "징벌", "惩戒", "懲戒")
t("Marksmanship", "Treffsicherheit", "Précision", "Puntería", "Precisão", "Стрельба", "사격", "射击", "射擊")
t("Survival", "Überleben", "Survie", "Supervivencia", "Sobrevivência", "Выживание", "생존", "生存", "生存")
t("Beast Mastery", "Tierherrschaft", "Maîtrise des bêtes", "Dominio de bestias", "Domínio das Feras", "Повелитель зверей", "야수", "野兽控制", "野獸控制")
t("Subtlety", "Täuschung", "Finesse", "Sutileza", "Subterfúgio", "Скрытность", "잠행", "敏锐", "敏銳")
t("Combat", "Kampf", "Combat", "Combate", "Combate", "Бой", "전투", "战斗", "戰鬥")
t("Assassination", "Meucheln", "Assassinat", "Asesinato", "Assassinato", "Ликвидация", "암살", "刺杀", "刺殺")
t("Holy/Discipline", "Heilig/Disziplin", "Sacré/Discipline", "Sagrado/Disciplina", "Sagrado/Disciplina", "Свет/Послушание", "신성/수양", "神圣/戒律", "神聖/戒律")
t("Enhancement", "Verstärkung", "Amélioration", "Mejora", "Aperfeiçoamento", "Совершенствование", "고양", "增强", "增強")
t("Elemental", "Elementar", "Élémentaire", "Elemental", "Elemental", "Стихии", "정기", "元素", "元素")
t("Restoration", "Wiederherstellung", "Restauration", "Restauración", "Restauração", "Исцеление", "복원", "恢复", "恢復")
t("Fire/Frost", "Feuer/Frost", "Feu/Givre", "Fuego/Escarcha", "Fogo/Gelo", "Огонь/Лёд", "화염/냉기", "火焰/冰霜", "火焰/冰霜")
t("Affliction", "Gebrechen", "Affliction", "Aflicción", "Suplício", "Колдовство", "고통", "痛苦", "痛苦")
t("Destruction", "Zerstörung", "Destruction", "Destrucción", "Destruição", "Разрушение", "파괴", "毁灭", "毀滅")
t("Demonology", "Dämonologie", "Démonologie", "Demonología", "Demonologia", "Демонология", "악마", "恶魔学识", "惡魔學識")
t("Feral", "Wilder Kampf", "Combat farouche", "Combate feral", "Combate Feral", "Сила зверя", "야성", "野性战斗", "野性戰鬥")
t("Feral (bear tank)", "Wilder Kampf (Bär, Tank)", "Combat farouche (ours, tank)", "Combate feral (oso, tanque)", "Combate Feral (urso, tanque)",
    "Сила зверя (медведь, танк)", "야성 (곰, 방어 전담)", "野性战斗（熊坦）", "野性戰鬥（熊坦）")
t("Balance", "Gleichgewicht", "Équilibre", "Equilibrio", "Equilíbrio", "Баланс", "조화", "平衡", "平衡")
t("Relic", "Relikt", "Relique", "Reliquia", "Relíquia", "Реликвия", "유물", "圣物", "聖物")
