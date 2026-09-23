-- Notes app: simple client-side notepad persisted to
-- garrysmod/data/wolfyphone_notes.json.

WolfyPhone.RegisterApp({
    id = "notes",
    name = "Notes",
    color = Color(255, 214, 10),
    glyph = "N",
    order = 50,
})

if SERVER then return end

local C = WolfyPhone.Colors
local STORE = "wolfyphone_notes.json"

local function loadNotes()
    if not file.Exists(STORE, "DATA") then return {} end
    local ok, data = pcall(util.JSONToTable, file.Read(STORE, "DATA") or "")
    return (ok and istable(data)) and data or {}
end

local function saveNotes(notes)
    file.Write(STORE, util.TableToJSON(notes))
end

local function buildEditor(body, notes, idx)
    body:Clear()
    local note = notes[idx]

    local entry = vgui.Create("DTextEntry", body)
    entry:Dock(FILL)
    entry:DockMargin(10, 10, 10, 6)
    entry:SetMultiline(true)
    entry:SetFont("WolfyPhone.Body")
    entry:SetTextColor(C.Text)
    entry:SetPlaceholderText("Write something...")
    entry:SetPlaceholderColor(C.TextDim)
    entry:SetText(note.text)
    entry:SetDrawLanguageID(false)
    entry.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(36, 38, 46))
        self:DrawTextEntryText(C.Text, C.Accent, C.Text)
    end

    local bar = vgui.Create("DPanel", body)
    bar:Dock(BOTTOM)
    bar:SetTall(40)
    bar.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 110))
    end

    local function close(save)
        if save then
            note.text = entry:GetText()
            note.ts = os.time()
            saveNotes(notes)
        end
        buildList(body, notes)
    end

    local save = vgui.Create("DButton", bar)
    save:Dock(RIGHT)
    save:SetWide(90)
    save:SetText("")
    save.Paint = function(_, w, h)
        draw.SimpleText("Save", "WolfyPhone.Body", w / 2, h / 2,
            C.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    save.DoClick = function() close(true) end

    local del = vgui.Create("DButton", bar)
    del:Dock(RIGHT)
    del:SetWide(90)
    del:SetText("")
    del.Paint = function(_, w, h)
        draw.SimpleText("Delete", "WolfyPhone.Body", w / 2, h / 2,
            C.Red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    del.DoClick = function()
        table.remove(notes, idx)
        saveNotes(notes)
        buildList(body, notes)
    end
end

function buildList(body, notes)
    body:Clear()

    local list = vgui.Create("DScrollPanel", body)
    list:Dock(FILL)
    local sbar = list:GetVBar()
    sbar:SetWide(4)
    sbar.Paint = nil
    sbar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 60))
    end

    for i, note in ipairs(notes) do
        local b = list:Add("DButton")
        b:Dock(TOP)
        b:DockMargin(8, 4, 8, 0)
        b:SetTall(46)
        b:SetText("")
        local preview = string.sub(string.gsub(note.text, "\n", " "), 1, 42)
        local ts = note.ts
        b.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h,
                self:IsHovered() and Color(50, 52, 62) or Color(36, 38, 46))
            draw.SimpleText(preview ~= "" and preview or "(empty note)",
                "WolfyPhone.Body", 12, 14, C.Text)
            draw.SimpleText(WolfyPhone.Util.FormatClock(ts),
                "WolfyPhone.Small", 12, 32, C.TextDim)
        end
        b.DoClick = function() buildEditor(body, notes, i) end
    end

    if #notes == 0 then
        local lbl = vgui.Create("DLabel", list)
        lbl:Dock(TOP)
        lbl:SetTall(60)
        lbl:SetContentAlignment(5)
        lbl:SetFont("WolfyPhone.Body")
        lbl:SetTextColor(C.TextDim)
        lbl:SetText("No notes yet")
    end

    local newBtn = vgui.Create("DButton", body)
    newBtn:Dock(BOTTOM)
    newBtn:SetTall(34)
    newBtn:SetText("")
    newBtn.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 110))
        draw.SimpleText("+ New Note", "WolfyPhone.Body", w / 2, h / 2,
            self:IsHovered() and C.Accent or C.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    newBtn.DoClick = function()
        table.insert(notes, { text = "", ts = os.time() })
        buildEditor(body, notes, #notes)
    end
end

WolfyPhone.Apps.notes.OnOpen = function(body)
    buildList(body, loadNotes())
end
