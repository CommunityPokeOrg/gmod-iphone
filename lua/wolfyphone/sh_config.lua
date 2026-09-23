-- Shared configuration. Edit values here, or override the listed keys at
-- runtime with the wolfyphone_* server convars (see sv_core.lua).

WolfyPhone.Config = {

    -- Branding shown on the phone status bar.
    DeviceName = "WolfyPhone",
    CarrierName = "Wolfy",

    -- World model used by the SWEP. Uses a stock model so the addon has no
    -- content downloads; override with a custom phone model if you have one.
    PhoneWorldModel = "models/props/cs_office/phone.mdl",

    -- Messages
    MaxMessageLength = 280,          -- characters, enforced server-side
    MaxMessagesPerConvo = 100,       -- history cap kept per conversation
    MessageCooldown = 1.0,           -- seconds between sends per player
    DeliverOfflineMessages = true,   -- queue messages for offline players

    -- Persistence (server-side, garrysmod/data/wolfyphone/)
    SaveInterval = 120,              -- seconds between inbox flushes

    -- Calls
    CallRingTimeout = 30,            -- seconds before an unanswered call drops
    GlobalCallVoice = true,          -- players in a call hear each other anywhere
    CallCooldown = 5,                -- seconds between outgoing calls per player

    -- Commands / input
    ChatCommand = "!phone",          -- say this to receive the SWEP
    GiveOnCommand = true,            -- allow the chat command at all
    GiveToNewPlayers = false,        -- auto-give SWEP on first spawn

    -- UI
    PhoneWidth = 360,
    PhoneHeight = 680,
    OpenSound = "buttons/button9.wav",
    CloseSound = "buttons/button8.wav",
    NotifySound = "buttons/button15.wav",
    SendSound = "buttons/button14.wav",
    RingSound = "ambient/alarms/warningbell1.wav",
}

-- Palette used by the Derma UI.
WolfyPhone.Colors = {
    Bezel = Color(18, 18, 22),
    Screen = Color(12, 12, 16),
    Wallpaper = Color(24, 27, 38),
    StatusBar = Color(200, 200, 210),
    Text = Color(235, 235, 240),
    TextDim = Color(150, 152, 165),
    Accent = Color(0, 122, 255),      -- classic iOS blue; Settings app recolors it
    Green = Color(52, 199, 89),
    Red = Color(255, 59, 48),
    BubbleIn = Color(58, 58, 66),     -- incoming message bubble
    BubbleOut = Color(0, 122, 255),   -- outgoing message bubble
}
