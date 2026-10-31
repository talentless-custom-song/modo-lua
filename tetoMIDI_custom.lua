--[[
    tetoMIDI custom song - Liquid Glass UI
    Intro + Floating Bubble + Custom Song (dán midi2lua tự chế, đặt tên, run) + Settings + tiếng click
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- ====================== CẤU HÌNH GITHUB ======================
local GITHUB_USER = "talentless-custom-song"
local GITHUB_REPO = "hu"

-- Link server Discord (bấm logo Discord sẽ copy link này)
local DISCORD_LINK = "https://discord.gg/peaqm6uqgB"

local IMAGE_DIR = "tetoMIDI/images"
local IMAGE_FILES = { "logo.png", "discord.png", "gear.png", "hub.png", "piano.png", "note.png", "reset.png" }
-- Ảnh không bắt buộc: thiếu thì UI vẫn chạy bình thường, không báo lỗi
local OPTIONAL_IMAGES = { ["reset.png"] = true, ["note.png"] = true, ["discord.png"] = true, ["hub.png"] = true, ["piano.png"] = true, ["gear.png"] = true }
local imageCache = {}

-- Nguồn tải ảnh (thử lần lượt, cái nào được thì dùng)
local function imageUrls(name)
    return {
        string.format("https://cdn.jsdelivr.net/gh/%s/%s@main/images/%s", GITHUB_USER, GITHUB_REPO, name),
        string.format("https://raw.githubusercontent.com/%s/%s/main/images/%s", GITHUB_USER, GITHUB_REPO, name),
    }
end

local function httpGetRaw(url)
    -- Cách 1: game:HttpGet
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and type(res) == "string" and #res > 0 then return res end
    -- Cách 2: request của executor
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        local ok2, r = pcall(req, { Url = url, Method = "GET" })
        if ok2 and type(r) == "table" and r.StatusCode == 200 and type(r.Body) == "string" and #r.Body > 0 then
            return r.Body
        end
    end
    return nil
end

-- File PNG hợp lệ phải bắt đầu bằng "\137PNG" (tránh lưu nhầm trang lỗi 404 HTML)
local function isPng(data)
    return type(data) == "string" and #data > 100 and data:sub(2, 4) == "PNG"
end

local function getAsset(path)
    local fn = getcustomasset or getsynasset
    if not fn then return "" end
    local ok, id = pcall(fn, path)
    if ok and id and id ~= "" then return id end
    return ""
end

-- Tải 1 ảnh về workspace rồi trả về asset id dùng được cho ImageLabel
local function loadImage(name)
    if imageCache[name] then return imageCache[name] end
    if not (writefile and isfile and readfile and (getcustomasset or getsynasset)) then
        warn("[tetoMIDI] Executor không hỗ trợ getcustomasset -> không hiện được ảnh")
        return ""
    end

    pcall(function()
        if isfolder and not isfolder("tetoMIDI") then makefolder("tetoMIDI") end
        if isfolder and not isfolder(IMAGE_DIR) then makefolder(IMAGE_DIR) end
    end)

    local path = IMAGE_DIR .. "/" .. name

    -- Dùng lại file đã tải nếu còn nguyên vẹn
    if isfile(path) then
        local okRead, data = pcall(readfile, path)
        if okRead and isPng(data) then
            local id = getAsset(path)
            if id ~= "" then imageCache[name] = id; return id end
        end
    end

    for _, url in ipairs(imageUrls(name)) do
        local data = httpGetRaw(url)
        if isPng(data) then
            local okW = pcall(writefile, path, data)
            if okW then
                local id = getAsset(path)
                if id ~= "" then imageCache[name] = id; return id end
            end
        end
    end

    if not OPTIONAL_IMAGES[name] then
        warn("[tetoMIDI] Không tải được ảnh: " .. name .. " (kiểm tra repo Public + file trong images/)")
    end
    return ""
end

-- Tải trước toàn bộ ảnh song song, chờ tối đa `timeout` giây
-- `onDone(name)` được gọi mỗi khi tải xong 1 ảnh (để intro cập nhật %)
local function preloadImages(timeout, onDone)
    local pending = #IMAGE_FILES
    for _, name in ipairs(IMAGE_FILES) do
        task.spawn(function()
            loadImage(name)
            pending = pending - 1
            if onDone then pcall(onDone, name) end
        end)
    end
    local t = 0
    while pending > 0 and t < (timeout or 10) do
        task.wait(0.1)
        t = t + 0.1
    end
end

-- Lấy ảnh đã cache (gọi sau preloadImages). Chưa có thì thử tải luôn.
local function getImage(name)
    return imageCache[name] or loadImage(name)
end

-- ====================== TIẾNG CLICK CHUỘT ======================
-- File nằm ở sounds/click.mp3 trong repo (tải về tetoMIDI/sounds/ như ảnh).
-- Tải không được thì dùng ID dự phòng của Roblox.
local SOUND_DIR = "tetoMIDI/sounds"
local CLICK_FILE = "click.mp3"
local CLICK_FALLBACK = "rbxassetid://421058925"
local CLICK_VOLUME = 0.75
local clickId = nil
local clickLoadStarted = false

local function soundUrls(name)
    return {
        string.format("https://cdn.jsdelivr.net/gh/%s/%s@main/sounds/%s", GITHUB_USER, GITHUB_REPO, name),
        string.format("https://raw.githubusercontent.com/%s/%s/main/sounds/%s", GITHUB_USER, GITHUB_REPO, name),
    }
end

-- mp3 hợp lệ bắt đầu bằng "ID3" hoặc byte sync 0xFF (tránh lưu nhầm trang lỗi 404 HTML)
local function isMp3(data)
    if type(data) ~= "string" or #data < 200 then return false end
    return data:sub(1, 3) == "ID3" or data:byte(1) == 0xFF
end

local function loadClickSound()
    if clickLoadStarted then return end
    clickLoadStarted = true
    if not (writefile and isfile and readfile and (getcustomasset or getsynasset)) then return end

    pcall(function()
        if isfolder and not isfolder("tetoMIDI") then makefolder("tetoMIDI") end
        if isfolder and not isfolder(SOUND_DIR) then makefolder(SOUND_DIR) end
    end)

    local path = SOUND_DIR .. "/" .. CLICK_FILE
    if isfile(path) then
        local okRead, data = pcall(readfile, path)
        if okRead and isMp3(data) then
            local id = getAsset(path)
            if id ~= "" then clickId = id; return end
        end
    end

    for _, url in ipairs(soundUrls(CLICK_FILE)) do
        local data = httpGetRaw(url)
        if isMp3(data) and pcall(writefile, path, data) then
            local id = getAsset(path)
            if id ~= "" then clickId = id; return end
        end
    end
end

-- Phát 1 tiếng click (tạo Sound mới mỗi lần để bấm liên tục vẫn kêu chồng được)
local function playClick()
    local snd = Instance.new("Sound")
    snd.Name = "TetoClick"
    snd.SoundId = clickId or CLICK_FALLBACK
    snd.Volume = CLICK_VOLUME
    snd.PlaybackSpeed = 0.96 + math.random() * 0.08   -- lệch nhẹ mỗi lần cho tự nhiên
    snd.Parent = SoundService
    snd:Play()
    task.delay(1.5, function() snd:Destroy() end)
end

-- Đánh dấu "input này thuộc về 1 nút / ô nhập / danh sách" -> cửa sổ không bị kéo theo khi bấm vào đó.
-- (Xem khối KÉO CỬA SỔ: kéo chỉ bắt đầu từ chỗ trống, input đã bị claim sẽ bị bỏ qua)
local UI_CLAIM = setmetatable({}, {__mode = "k"})
local function claimInput(obj)
    obj.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            UI_CLAIM[input] = true
        end
    end)
end

local FOLD_MAP = {
    [192]="a",[193]="a",[194]="a",[195]="a",[196]="a",[197]="a",[198]="ae",[199]="c",[200]="e",[201]="e",[202]="e",
    [203]="e",[204]="i",[205]="i",[206]="i",[207]="i",[208]="d",[209]="n",[210]="o",[211]="o",[212]="o",[213]="o",
    [214]="o",[216]="o",[217]="u",[218]="u",[219]="u",[220]="u",[221]="y",[222]="th",[223]="ss",[224]="a",
    [225]="a",[226]="a",[227]="a",[228]="a",[229]="a",[230]="ae",[231]="c",[232]="e",[233]="e",[234]="e",[235]="e",
    [236]="i",[237]="i",[238]="i",[239]="i",[240]="d",[241]="n",[242]="o",[243]="o",[244]="o",[245]="o",[246]="o",
    [248]="o",[249]="u",[250]="u",[251]="u",[252]="u",[253]="y",[254]="th",[255]="y",[256]="a",[257]="a",[258]="a",
    [259]="a",[260]="a",[261]="a",[262]="c",[263]="c",[264]="c",[265]="c",[266]="c",[267]="c",[268]="c",[269]="c",
    [270]="d",[271]="d",[272]="d",[273]="d",[274]="e",[275]="e",[276]="e",[277]="e",[278]="e",[279]="e",[280]="e",
    [281]="e",[282]="e",[283]="e",[284]="g",[285]="g",[286]="g",[287]="g",[288]="g",[289]="g",[290]="g",[291]="g",
    [292]="h",[293]="h",[294]="h",[295]="h",[296]="i",[297]="i",[298]="i",[299]="i",[300]="i",[301]="i",[302]="i",
    [303]="i",[304]="i",[305]="i",[306]="\u{133}",[308]="j",[309]="j",[310]="k",[311]="k",[313]="l",[314]="l",
    [315]="l",[316]="l",[317]="l",[318]="l",[319]="\u{140}",[321]="l",[322]="l",[323]="n",[324]="n",[325]="n",
    [326]="n",[327]="n",[328]="n",[330]="\u{14B}",[332]="o",[333]="o",[334]="o",[335]="o",[336]="o",[337]="o",
    [338]="oe",[339]="oe",[340]="r",[341]="r",[342]="r",[343]="r",[344]="r",[345]="r",[346]="s",[347]="s",
    [348]="s",[349]="s",[350]="s",[351]="s",[352]="s",[353]="s",[354]="t",[355]="t",[356]="t",[357]="t",[358]="t",
    [359]="t",[360]="u",[361]="u",[362]="u",[363]="u",[364]="u",[365]="u",[366]="u",[367]="u",[368]="u",[369]="u",
    [370]="u",[371]="u",[372]="w",[373]="w",[374]="y",[375]="y",[376]="y",[377]="z",[378]="z",[379]="z",[380]="z",
    [381]="z",[382]="z",[385]="\u{253}",[386]="\u{183}",[388]="\u{185}",[390]="\u{254}",[391]="\u{188}",
    [393]="\u{256}",[394]="\u{257}",[395]="\u{18C}",[398]="\u{1DD}",[399]="\u{259}",[400]="\u{25B}",
    [401]="\u{192}",[403]="\u{260}",[404]="\u{263}",[406]="\u{269}",[407]="\u{268}",[408]="\u{199}",
    [412]="\u{26F}",[413]="\u{272}",[415]="\u{275}",[416]="o",[417]="o",[418]="\u{1A3}",[420]="\u{1A5}",
    [422]="\u{280}",[423]="\u{1A8}",[425]="\u{283}",[428]="\u{1AD}",[430]="\u{288}",[431]="u",[432]="u",
    [433]="\u{28A}",[434]="\u{28B}",[435]="\u{1B4}",[437]="\u{1B6}",[439]="\u{292}",[440]="\u{1B9}",
    [444]="\u{1BD}",[452]="\u{1C6}",[453]="\u{1C6}",[455]="\u{1C9}",[456]="\u{1C9}",[458]="\u{1CC}",
    [459]="\u{1CC}",[461]="a",[462]="a",[463]="i",[464]="i",[465]="o",[466]="o",[467]="u",[468]="u",[469]="u",
    [470]="u",[471]="u",[472]="u",[473]="u",[474]="u",[475]="u",[476]="u",[478]="a",[479]="a",[480]="a",[481]="a",
    [482]="\u{1E3}",[484]="\u{1E5}",[486]="g",[487]="g",[488]="k",[489]="k",[490]="o",[491]="o",[492]="o",
    [493]="o",[494]="\u{1EF}",[496]="j",[497]="\u{1F3}",[498]="\u{1F3}",[500]="g",[501]="g",[502]="\u{195}",
    [503]="\u{1BF}",[504]="n",[505]="n",[506]="a",[507]="a",[508]="\u{1FD}",[510]="\u{1FF}",[512]="a",[513]="a",
    [514]="a",[515]="a",[516]="e",[517]="e",[518]="e",[519]="e",[520]="i",[521]="i",[522]="i",[523]="i",[524]="o",
    [525]="o",[526]="o",[527]="o",[528]="r",[529]="r",[530]="r",[531]="r",[532]="u",[533]="u",[534]="u",[535]="u",
    [536]="s",[537]="s",[538]="t",[539]="t",[540]="\u{21D}",[542]="h",[543]="h",[544]="\u{19E}",[546]="\u{223}",
    [548]="\u{225}",[550]="a",[551]="a",[552]="e",[553]="e",[554]="o",[555]="o",[556]="o",[557]="o",[558]="o",
    [559]="o",[560]="o",[561]="o",[562]="y",[563]="y",[570]="\u{2C65}",[571]="\u{23C}",[573]="\u{19A}",
    [574]="\u{2C66}",[577]="\u{242}",[579]="\u{180}",[580]="\u{289}",[581]="\u{28C}",[582]="\u{247}",
    [584]="\u{249}",[586]="\u{24B}",[588]="\u{24D}",[590]="\u{24F}",[7680]="a",[7681]="a",[7682]="b",[7683]="b",
    [7684]="b",[7685]="b",[7686]="b",[7687]="b",[7688]="c",[7689]="c",[7690]="d",[7691]="d",[7692]="d",[7693]="d",
    [7694]="d",[7695]="d",[7696]="d",[7697]="d",[7698]="d",[7699]="d",[7700]="e",[7701]="e",[7702]="e",[7703]="e",
    [7704]="e",[7705]="e",[7706]="e",[7707]="e",[7708]="e",[7709]="e",[7710]="f",[7711]="f",[7712]="g",[7713]="g",
    [7714]="h",[7715]="h",[7716]="h",[7717]="h",[7718]="h",[7719]="h",[7720]="h",[7721]="h",[7722]="h",[7723]="h",
    [7724]="i",[7725]="i",[7726]="i",[7727]="i",[7728]="k",[7729]="k",[7730]="k",[7731]="k",[7732]="k",[7733]="k",
    [7734]="l",[7735]="l",[7736]="l",[7737]="l",[7738]="l",[7739]="l",[7740]="l",[7741]="l",[7742]="m",[7743]="m",
    [7744]="m",[7745]="m",[7746]="m",[7747]="m",[7748]="n",[7749]="n",[7750]="n",[7751]="n",[7752]="n",[7753]="n",
    [7754]="n",[7755]="n",[7756]="o",[7757]="o",[7758]="o",[7759]="o",[7760]="o",[7761]="o",[7762]="o",[7763]="o",
    [7764]="p",[7765]="p",[7766]="p",[7767]="p",[7768]="r",[7769]="r",[7770]="r",[7771]="r",[7772]="r",[7773]="r",
    [7774]="r",[7775]="r",[7776]="s",[7777]="s",[7778]="s",[7779]="s",[7780]="s",[7781]="s",[7782]="s",[7783]="s",
    [7784]="s",[7785]="s",[7786]="t",[7787]="t",[7788]="t",[7789]="t",[7790]="t",[7791]="t",[7792]="t",[7793]="t",
    [7794]="u",[7795]="u",[7796]="u",[7797]="u",[7798]="u",[7799]="u",[7800]="u",[7801]="u",[7802]="u",[7803]="u",
    [7804]="v",[7805]="v",[7806]="v",[7807]="v",[7808]="w",[7809]="w",[7810]="w",[7811]="w",[7812]="w",[7813]="w",
    [7814]="w",[7815]="w",[7816]="w",[7817]="w",[7818]="x",[7819]="x",[7820]="x",[7821]="x",[7822]="y",[7823]="y",
    [7824]="z",[7825]="z",[7826]="z",[7827]="z",[7828]="z",[7829]="z",[7830]="h",[7831]="t",[7832]="w",[7833]="y",
    [7838]="ss",[7840]="a",[7841]="a",[7842]="a",[7843]="a",[7844]="a",[7845]="a",[7846]="a",[7847]="a",[7848]="a",
    [7849]="a",[7850]="a",[7851]="a",[7852]="a",[7853]="a",[7854]="a",[7855]="a",[7856]="a",[7857]="a",[7858]="a",
    [7859]="a",[7860]="a",[7861]="a",[7862]="a",[7863]="a",[7864]="e",[7865]="e",[7866]="e",[7867]="e",[7868]="e",
    [7869]="e",[7870]="e",[7871]="e",[7872]="e",[7873]="e",[7874]="e",[7875]="e",[7876]="e",[7877]="e",[7878]="e",
    [7879]="e",[7880]="i",[7881]="i",[7882]="i",[7883]="i",[7884]="o",[7885]="o",[7886]="o",[7887]="o",[7888]="o",
    [7889]="o",[7890]="o",[7891]="o",[7892]="o",[7893]="o",[7894]="o",[7895]="o",[7896]="o",[7897]="o",[7898]="o",
    [7899]="o",[7900]="o",[7901]="o",[7902]="o",[7903]="o",[7904]="o",[7905]="o",[7906]="o",[7907]="o",[7908]="u",
    [7909]="u",[7910]="u",[7911]="u",[7912]="u",[7913]="u",[7914]="u",[7915]="u",[7916]="u",[7917]="u",[7918]="u",
    [7919]="u",[7920]="u",[7921]="u",[7922]="y",[7923]="y",[7924]="y",[7925]="y",[7926]="y",[7927]="y",[7928]="y",
    [7929]="y",[7930]="\u{1EFB}",[7932]="\u{1EFD}",[7934]="\u{1EFF}",[880]="\u{371}",[882]="\u{373}",
    [886]="\u{377}",[895]="\u{3F3}",[902]="\u{3AC}",[904]="\u{3AD}",[905]="\u{3AE}",[906]="\u{3AF}",
    [908]="\u{3CC}",[910]="\u{3CD}",[911]="\u{3CE}",[913]="\u{3B1}",[914]="\u{3B2}",[915]="\u{3B3}",
    [916]="\u{3B4}",[917]="\u{3B5}",[918]="\u{3B6}",[919]="\u{3B7}",[920]="\u{3B8}",[921]="\u{3B9}",
    [922]="\u{3BA}",[923]="\u{3BB}",[924]="\u{3BC}",[925]="\u{3BD}",[926]="\u{3BE}",[927]="\u{3BF}",
    [928]="\u{3C0}",[929]="\u{3C1}",[931]="\u{3C3}",[932]="\u{3C4}",[933]="\u{3C5}",[934]="\u{3C6}",
    [935]="\u{3C7}",[936]="\u{3C8}",[937]="\u{3C9}",[938]="\u{3CA}",[939]="\u{3CB}",[975]="\u{3D7}",
    [984]="\u{3D9}",[986]="\u{3DB}",[988]="\u{3DD}",[990]="\u{3DF}",[992]="\u{3E1}",[994]="\u{3E3}",
    [996]="\u{3E5}",[998]="\u{3E7}",[1000]="\u{3E9}",[1002]="\u{3EB}",[1004]="\u{3ED}",[1006]="\u{3EF}",
    [1012]="\u{3B8}",[1015]="\u{3F8}",[1017]="\u{3F2}",[1018]="\u{3FB}",[1021]="\u{37B}",[1022]="\u{37C}",
    [1023]="\u{37D}",[1024]="\u{450}",[1025]="\u{451}",[1026]="\u{452}",[1027]="\u{453}",[1028]="\u{454}",
    [1029]="\u{455}",[1030]="\u{456}",[1031]="\u{457}",[1032]="\u{458}",[1033]="\u{459}",[1034]="\u{45A}",
    [1035]="\u{45B}",[1036]="\u{45C}",[1037]="\u{45D}",[1038]="\u{45E}",[1039]="\u{45F}",[1040]="\u{430}",
    [1041]="\u{431}",[1042]="\u{432}",[1043]="\u{433}",[1044]="\u{434}",[1045]="\u{435}",[1046]="\u{436}",
    [1047]="\u{437}",[1048]="\u{438}",[1049]="\u{439}",[1050]="\u{43A}",[1051]="\u{43B}",[1052]="\u{43C}",
    [1053]="\u{43D}",[1054]="\u{43E}",[1055]="\u{43F}",[1056]="\u{440}",[1057]="\u{441}",[1058]="\u{442}",
    [1059]="\u{443}",[1060]="\u{444}",[1061]="\u{445}",[1062]="\u{446}",[1063]="\u{447}",[1064]="\u{448}",
    [1065]="\u{449}",[1066]="\u{44A}",[1067]="\u{44B}",[1068]="\u{44C}",[1069]="\u{44D}",[1070]="\u{44E}",
    [1071]="\u{44F}",[1120]="\u{461}",[1122]="\u{463}",[1124]="\u{465}",[1126]="\u{467}",[1128]="\u{469}",
    [1130]="\u{46B}",[1132]="\u{46D}",[1134]="\u{46F}",[1136]="\u{471}",[1138]="\u{473}",[1140]="\u{475}",
    [1142]="\u{477}",[1144]="\u{479}",[1146]="\u{47B}",[1148]="\u{47D}",[1150]="\u{47F}",[1152]="\u{481}",
    [1162]="\u{48B}",[1164]="\u{48D}",[1166]="\u{48F}",[1168]="\u{491}",[1170]="\u{493}",[1172]="\u{495}",
    [1174]="\u{497}",[1176]="\u{499}",[1178]="\u{49B}",[1180]="\u{49D}",[1182]="\u{49F}",[1184]="\u{4A1}",
    [1186]="\u{4A3}",[1188]="\u{4A5}",[1190]="\u{4A7}",[1192]="\u{4A9}",[1194]="\u{4AB}",[1196]="\u{4AD}",
    [1198]="\u{4AF}",[1200]="\u{4B1}",[1202]="\u{4B3}",[1204]="\u{4B5}",[1206]="\u{4B7}",[1208]="\u{4B9}",
    [1210]="\u{4BB}",[1212]="\u{4BD}",[1214]="\u{4BF}",[1216]="\u{4CF}",[1217]="\u{4C2}",[1219]="\u{4C4}",
    [1221]="\u{4C6}",[1223]="\u{4C8}",[1225]="\u{4CA}",[1227]="\u{4CC}",[1229]="\u{4CE}",[1232]="\u{4D1}",
    [1234]="\u{4D3}",[1236]="\u{4D5}",[1238]="\u{4D7}",[1240]="\u{4D9}",[1242]="\u{4DB}",[1244]="\u{4DD}",
    [1246]="\u{4DF}",[1248]="\u{4E1}",[1250]="\u{4E3}",[1252]="\u{4E5}",[1254]="\u{4E7}",[1256]="\u{4E9}",
    [1258]="\u{4EB}",[1260]="\u{4ED}",[1262]="\u{4EF}",[1264]="\u{4F1}",[1266]="\u{4F3}",[1268]="\u{4F5}",
    [1270]="\u{4F7}",[1272]="\u{4F9}",[1274]="\u{4FB}",[1276]="\u{4FD}",[1278]="\u{4FF}",
}

-- Chuẩn hóa để tìm kiếm: hạ chữ hoa (Latin, Việt, Hy Lạp, Cyrillic), bỏ dấu (nắng → nang),
-- bỏ dấu câu ASCII. "Nắng Ấm", "nang am", "NẮNG ẤM" đều khớp nhau.
local function searchFold(text)
    text = tostring(text or "")
    local out, ok = {}, true
    ok = pcall(function()
        for _, cp in utf8.codes(text) do
            if cp < 128 then
                local c = string.char(cp):lower()
                if c:match("%w") then out[#out + 1] = c else out[#out + 1] = " " end
            elseif cp >= 0x300 and cp <= 0x36F then
                -- dấu tổ hợp (NFD): bỏ qua
            else
                out[#out + 1] = FOLD_MAP[cp] or utf8.char(cp)
            end
        end
    end)
    if not ok then return string.lower(text) end
    return (table.concat(out):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

-- Mọi từ khóa đều phải có trong tên (thứ tự tùy ý)
local function searchMatch(name, query)
    if query == "" then return true end
    local hay = " " .. name .. " "
    for word in query:gmatch("%S+") do
        if not hay:find(word, 1, true) then return false end
    end
    return true
end

-- Gắn tiếng click vào nút: kêu ngay lúc nhấn xuống (chuột hoặc chạm)
local function bindClick(btn)
    btn.MouseButton1Down:Connect(playClick)
    claimInput(btn)
end

-- ====================== DATA ======================
local CurrentPage = "custom"
local MainVisible = true

pcall(function()
    if isfolder and not isfolder("tetoMIDI") then
        makefolder("tetoMIDI")
    end
end)

-- ====================== CẤU HÌNH (lưu giữa các lần chạy) ======================
local MIDI_DIR = "tetoMIDI/midi"                 -- bỏ file .mid vào thư mục này (workspace của executor)
local CONFIG_PATH = "tetoMIDI/config.json"
local Cfg = {
    piano  = {k88 = true, sustain = false, velocity = false, noteLengths = true, loop = false, roll3d = false, file = ""},
    drums  = {noteLengths = true, loop = false, file = ""},
    guitar = {noteLengths = true, loop = false, file = ""},
    roll   = {fall = 3.0},                       -- số giây nốt rơi từ trên xuống phím
    ui     = {alpha = 0},                        -- độ trong suốt của cửa sổ (0 = rõ, 0.8 = rất trong)
    bg     = {main = ""},                        -- link ảnh nền (png/jpg) của UI chính
    custom = {name = "", script = ""},           -- tên bài + script midi2lua đang dán (lưu giữa các lần chạy)
}

pcall(function()
    if isfile and isfile(CONFIG_PATH) then
        local saved = HttpService:JSONDecode(readfile(CONFIG_PATH))
        for sec, t in pairs(saved) do
            if type(t) == "table" and Cfg[sec] then
                for k, v in pairs(t) do
                    if Cfg[sec][k] ~= nil and type(Cfg[sec][k]) == type(v) then Cfg[sec][k] = v end
                end
            end
        end
    end
end)

local cfgToken = 0
local function saveCfg()
    cfgToken = cfgToken + 1
    local mine = cfgToken
    task.delay(0.4, function()
        if mine ~= cfgToken then return end
        pcall(function()
            if isfolder and not isfolder("tetoMIDI") then makefolder("tetoMIDI") end
            writefile(CONFIG_PATH, HttpService:JSONEncode(Cfg))
        end)
    end)
end

-- ====================== INTRO (laptop gõ lệnh -> logo, tổng 7 giây) ======================
-- Timeline (giây):
--   0.00 - 0.35  nền hiện lên
--   0.35 - 1.30  nắp laptop mở
--   1.50 - 2.80  gõ "pip install tetomidi"
--   3.15 - 3.40  enter, hiện 2 dòng kết quả
--   3.80 - 4.45  laptop zoom + tan, biến thành logo
--   3.95 - 6.35  logo, tên, thanh loading
--   6.35 - 7.00  outro (flash + fade) rồi vào UI chính
local INTRO_TOTAL = 7
local INTRO_OUTRO = 0.65
local INSTALL_CMD = "pip install tetomidi"
local LAPTOP_FILL_X = 0.5    -- laptop chiếm tối đa 50% chiều ngang màn hình
local LAPTOP_FILL_Y = 0.5    -- laptop chiếm tối đa 50% chiều dọc màn hình
local LAPTOP_K_MAX  = 1.35   -- chặn trần để màn hình lớn (PC) laptop cũng không phình to

local function createIntro()
    local introGui = Instance.new("ScreenGui")
    introGui.Name = "TetoMIDI_Intro"
    introGui.IgnoreGuiInset = true
    introGui.DisplayOrder = 9999
    introGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    introGui.Parent = CoreGui

    -- Stage dùng CanvasGroup để fade toàn bộ intro cùng lúc
    local stage = Instance.new("CanvasGroup")
    stage.Size = UDim2.new(1, 0, 1, 0)
    stage.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    stage.BorderSizePixel = 0
    stage.GroupTransparency = 1
    stage.Parent = introGui

    local stageScale = Instance.new("UIScale")
    stageScale.Scale = 1
    stageScale.Parent = stage

    -- ============ PHẦN 1: LAPTOP ============
    -- Laptop thiết kế gốc 330x188, phóng theo hệ số K để lấp gần đầy màn hình
    -- Lấy kích thước màn hình THẬT từ camera (AbsoluteSize của ScreenGui trong
    -- một số executor trả về giá trị cũ/sai -> laptop bị nhỏ giữa màn hình)
    local cam0 = workspace.CurrentCamera
    local vp = (cam0 and cam0.ViewportSize) or Vector2.new(0, 0)
    if vp.X < 100 or vp.Y < 100 then
        vp = introGui.AbsoluteSize
    end
    if vp.X < 100 or vp.Y < 100 then
        vp = Vector2.new(800, 400)
    end
    local K = math.clamp(math.min(vp.X * LAPTOP_FILL_X / 330, vp.Y * LAPTOP_FILL_Y / 188), 0.6, LAPTOP_K_MAX)
    local function s(n)
        return math.floor(n * K + 0.5)
    end

    local laptop = Instance.new("CanvasGroup")
    laptop.AnchorPoint = Vector2.new(0.5, 0.5)
    laptop.Size = UDim2.new(0, s(330), 0, s(188))
    laptop.Position = UDim2.new(0.5, 0, 0.5, -32 + s(6))   -- tâm màn hình laptop trùng tâm logo
    laptop.BackgroundTransparency = 1
    laptop.BorderSizePixel = 0
    laptop.ZIndex = 1
    laptop.Parent = stage

    local laptopScale = Instance.new("UIScale")
    laptopScale.Scale = 0.88
    laptopScale.Parent = laptop

    -- Đế laptop (bàn phím)
    local base = Instance.new("Frame")
    base.AnchorPoint = Vector2.new(0.5, 1)
    base.Size = UDim2.new(0, s(330), 0, s(12))
    base.Position = UDim2.new(0.5, 0, 1, 0)
    base.BackgroundColor3 = Color3.fromRGB(190, 190, 190)
    base.BorderSizePixel = 0
    base.Parent = laptop
    Instance.new("UICorner", base).CornerRadius = UDim.new(0, s(6))

    local baseGradient = Instance.new("UIGradient")
    baseGradient.Color = ColorSequence.new(Color3.fromRGB(228, 228, 228), Color3.fromRGB(135, 135, 135))
    baseGradient.Rotation = 90
    baseGradient.Parent = base

    -- Nửa trên của đế vuông góc: lấp 2 góc trên (nắp khít sát đế, không hở 2 bên)
    local baseTop = Instance.new("Frame")
    baseTop.Size = UDim2.new(1, 0, 0, s(6))
    baseTop.Position = UDim2.new(0, 0, 0, 0)
    baseTop.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    baseTop.BorderSizePixel = 0
    baseTop.Parent = base
    local baseTopGradient = Instance.new("UIGradient")
    baseTopGradient.Color = ColorSequence.new(Color3.fromRGB(228, 228, 228), Color3.fromRGB(181, 181, 181))
    baseTopGradient.Rotation = 90
    baseTopGradient.Parent = baseTop

    -- Rãnh mở nắp ở giữa đế
    local notch = Instance.new("Frame")
    notch.AnchorPoint = Vector2.new(0.5, 0)
    notch.Size = UDim2.new(0, s(64), 0, s(3))
    notch.Position = UDim2.new(0.5, 0, 0, 0)
    notch.BackgroundColor3 = Color3.fromRGB(95, 95, 95)
    notch.BorderSizePixel = 0
    notch.Parent = base
    Instance.new("UICorner", notch).CornerRadius = UDim.new(0, s(2))

    -- Nắp laptop: neo ở mép dưới (bản lề), mở bằng cách tăng chiều cao + thu hẹp chiều rộng nhẹ
    local lid = Instance.new("Frame")
    lid.AnchorPoint = Vector2.new(0.5, 1)
    lid.Size = UDim2.new(0, s(330), 0, s(4))      -- rộng đúng bằng đế: 2 bên kín hoàn toàn
    lid.Position = UDim2.new(0.5, 0, 1, -s(12))
    lid.BackgroundColor3 = Color3.fromRGB(215, 215, 215)
    lid.BorderSizePixel = 0
    lid.ClipsDescendants = true
    lid.Parent = laptop
    Instance.new("UICorner", lid).CornerRadius = UDim.new(0, s(10))

    local lidGradient = Instance.new("UIGradient")
    lidGradient.Color = ColorSequence.new(Color3.fromRGB(232, 232, 232), Color3.fromRGB(150, 150, 150))
    lidGradient.Rotation = 90
    lidGradient.Parent = lid

    -- Dải bản lề vuông góc ở đáy nắp: bo góc chỉ còn ở phía trên, đáy nắp liền khít với đế
    local hinge = Instance.new("Frame")
    hinge.AnchorPoint = Vector2.new(0, 1)
    hinge.Size = UDim2.new(1, 0, 0, s(12))
    hinge.Position = UDim2.new(0, 0, 1, 0)
    hinge.BackgroundColor3 = Color3.fromRGB(152, 152, 152)
    hinge.BorderSizePixel = 0
    hinge.Parent = lid

    -- Camera nhỏ trên viền màn hình
    local cam = Instance.new("Frame")
    cam.AnchorPoint = Vector2.new(0.5, 0)
    cam.Size = UDim2.new(0, s(4), 0, s(4))
    cam.Position = UDim2.new(0.5, 0, 0, s(4))
    cam.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    cam.BorderSizePixel = 0
    cam.Visible = false
    cam.Parent = lid
    Instance.new("UICorner", cam).CornerRadius = UDim.new(1, 0)

    -- Màn hình đen bên trong nắp
    local screen = Instance.new("Frame")
    screen.Position = UDim2.new(0, s(8), 0, s(12))
    screen.Size = UDim2.new(1, -s(16), 1, -s(20))
    screen.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    screen.BorderSizePixel = 0
    screen.ClipsDescendants = true
    screen.Visible = false
    screen.Parent = lid
    Instance.new("UICorner", screen).CornerRadius = UDim.new(0, s(5))

    -- Terminal
    local term = Instance.new("TextLabel")
    term.Position = UDim2.new(0, s(10), 0, s(10))
    term.Size = UDim2.new(1, -s(20), 1, -s(20))
    term.BackgroundTransparency = 1
    term.Font = Enum.Font.Code
    term.TextSize = math.clamp(s(12), 10, 100)
    term.TextColor3 = Color3.fromRGB(235, 235, 235)
    term.TextXAlignment = Enum.TextXAlignment.Left
    term.TextYAlignment = Enum.TextYAlignment.Top
    term.RichText = true
    term.Text = ""
    term.Parent = screen

    -- Lớp sáng trắng phủ màn hình lúc laptop biến thành logo
    local screenFlash = Instance.new("Frame")
    screenFlash.Size = UDim2.new(1, 0, 1, 0)
    screenFlash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    screenFlash.BackgroundTransparency = 1
    screenFlash.BorderSizePixel = 0
    screenFlash.ZIndex = 2
    screenFlash.Parent = screen

    -- ============ PHẦN 2: LOGO + LOADING ============
    -- Gom tất cả vào 1 CanvasGroup để hiện ra cùng lúc khi laptop tan
    local content = Instance.new("CanvasGroup")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.GroupTransparency = 1
    content.ZIndex = 2
    content.Parent = stage

    -- Hào quang mờ phía sau logo
    local halo = Instance.new("Frame")
    halo.AnchorPoint = Vector2.new(0.5, 0.5)
    halo.Size = UDim2.new(0, 260, 0, 260)
    halo.Position = UDim2.new(0.5, 0, 0.5, -30)
    halo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    halo.BackgroundTransparency = 0.95
    halo.BorderSizePixel = 0
    halo.Parent = content
    Instance.new("UICorner", halo).CornerRadius = UDim.new(1, 0)

    -- Card chứa logo.png (nốt nhạc + phím piano)
    local logoFrame = Instance.new("Frame")
    logoFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    logoFrame.Size = UDim2.new(0, 118, 0, 118)
    logoFrame.Position = UDim2.new(0.5, 0, 0.5, -32)
    logoFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    logoFrame.BackgroundTransparency = 0.05
    logoFrame.BorderSizePixel = 0
    logoFrame.Parent = content
    Instance.new("UICorner", logoFrame).CornerRadius = UDim.new(0, 26)

    local logoStroke = Instance.new("UIStroke")
    logoStroke.Color = Color3.fromRGB(255, 255, 255)
    logoStroke.Transparency = 0.55
    logoStroke.Thickness = 1.5
    logoStroke.Parent = logoFrame

    local logoScale = Instance.new("UIScale")
    logoScale.Scale = 0.5
    logoScale.Parent = logoFrame

    local logo = Instance.new("ImageLabel")
    logo.Size = UDim2.new(1, 0, 1, 0)
    logo.Position = UDim2.new(0, 0, 0, 0)
    logo.BackgroundTransparency = 1
    logo.Image = ""
    logo.ScaleType = Enum.ScaleType.Crop
    logo.Parent = logoFrame
    Instance.new("UICorner", logo).CornerRadius = UDim.new(0, 26)

    -- Chữ dự phòng nếu ảnh tải thất bại
    local logoFallback = Instance.new("TextLabel")
    logoFallback.Size = UDim2.new(1, 0, 1, 0)
    logoFallback.BackgroundTransparency = 1
    logoFallback.Text = "♪"
    logoFallback.TextColor3 = Color3.fromRGB(255, 255, 255)
    logoFallback.Font = Enum.Font.GothamBold
    logoFallback.TextSize = 44
    logoFallback.Visible = false
    logoFallback.Parent = logoFrame

    -- Tên
    local title = Instance.new("TextLabel")
    title.AnchorPoint = Vector2.new(0.5, 0)
    title.Size = UDim2.new(0, 320, 0, 28)
    title.Position = UDim2.new(0.5, 0, 0.5, 38)
    title.BackgroundTransparency = 1
    title.Text = "TetoMIDI"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextTransparency = 1
    title.Parent = content

    -- Dòng trạng thái
    local status = Instance.new("TextLabel")
    status.AnchorPoint = Vector2.new(0.5, 0)
    status.Size = UDim2.new(0, 320, 0, 16)
    status.Position = UDim2.new(0.5, 0, 0.5, 66)
    status.BackgroundTransparency = 1
    status.Text = "loading assets..."
    status.TextColor3 = Color3.fromRGB(150, 150, 150)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextTransparency = 1
    status.Parent = content

    -- Thanh loading (gradient + shine chạy)
    local barBg = Instance.new("Frame")
    barBg.AnchorPoint = Vector2.new(0.5, 0)
    barBg.Size = UDim2.new(0, 220, 0, 5)
    barBg.Position = UDim2.new(0.5, 0, 0.5, 96)
    barBg.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
    barBg.BorderSizePixel = 0
    barBg.Parent = content
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 0, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    bar.BorderSizePixel = 0
    bar.ClipsDescendants = true
    bar.Parent = barBg
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local barGradient = Instance.new("UIGradient")
    barGradient.Color = ColorSequence.new(Color3.fromRGB(90, 90, 90), Color3.fromRGB(255, 255, 255))
    barGradient.Parent = bar

    -- Vệt sáng lướt trên thanh bar
    local shine = Instance.new("Frame")
    shine.Size = UDim2.new(1, 0, 1, 0)
    shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    shine.BorderSizePixel = 0
    shine.Parent = bar
    local shineGradient = Instance.new("UIGradient")
    shineGradient.Rotation = 20
    shineGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,    1),
        NumberSequenceKeypoint.new(0.40, 1),
        NumberSequenceKeypoint.new(0.50, 0),
        NumberSequenceKeypoint.new(0.60, 1),
        NumberSequenceKeypoint.new(1,    1),
    })
    shineGradient.Parent = shine
    shineGradient.Offset = Vector2.new(-1, 0)

    -- Viền sáng quanh thanh bar (glow nhẹ)
    local barGlow = Instance.new("UIStroke")
    barGlow.Color = Color3.fromRGB(255, 255, 255)
    barGlow.Transparency = 0.75
    barGlow.Thickness = 1
    barGlow.Parent = barBg

    local percent = Instance.new("TextLabel")
    percent.AnchorPoint = Vector2.new(0.5, 0)
    percent.Size = UDim2.new(0, 100, 0, 18)
    percent.Position = UDim2.new(0.5, 0, 0.5, 108)
    percent.BackgroundTransparency = 1
    percent.Text = "0%"
    percent.TextColor3 = Color3.fromRGB(170, 170, 170)
    percent.Font = Enum.Font.GothamMedium
    percent.TextSize = 12
    percent.TextTransparency = 1
    percent.Parent = content

    -- ============ ĐIỀU PHỐI THEO MỐC THỜI GIAN ============
    task.spawn(function()
        local t0 = os.clock()
        local function waitUntil(t)
            local d = t0 + t - os.clock()
            if d > 0 then task.wait(d) end
        end
        local function tween(obj, dur, style, dir, props)
            local tw = TweenService:Create(obj, TweenInfo.new(dur, style, dir), props)
            tw:Play()
            return tw
        end

        local QUAD, SINE, BACK, LINEAR = Enum.EasingStyle.Quad, Enum.EasingStyle.Sine, Enum.EasingStyle.Back, Enum.EasingStyle.Linear
        local OUT, IN = Enum.EasingDirection.Out, Enum.EasingDirection.In

        local introAlive = true
        local laptopAlive = true

        -- Tải ảnh chạy ngầm ngay từ giây 0 (trong lúc laptop đang diễn)
        local total = #IMAGE_FILES
        local loaded = 0
        local preloadDone = false

        local function applyLogo()
            local iconId = getImage("logo.png")
            if iconId ~= "" then
                logo.Image = iconId
                logoFallback.Visible = false
            else
                logoFallback.Visible = true
            end
        end


        task.spawn(loadClickSound)

        task.spawn(function()
            preloadImages(10, function(name)
                loaded = loaded + 1
                status.Text = string.format("loading assets... (%d/%d)", loaded, total)
            end)
            preloadDone = true
            applyLogo()
        end)

        -- Terminal: dòng lệnh + 2 dòng kết quả + prompt mới
        local typedCount = 0
        local cursorOn = true
        local lines = {}
        local PROMPT = '<font color="#8c8c8c">$</font> '
        local function render()
            local cursor = cursorOn and "_" or " "
            local out = {}
            out[1] = PROMPT .. INSTALL_CMD:sub(1, typedCount) .. ((#lines == 0) and cursor or "")
            for _, l in ipairs(lines) do
                out[#out + 1] = l
            end
            if #lines >= 2 then
                out[#out + 1] = PROMPT .. cursor
            end
            term.Text = table.concat(out, "\n")
        end

        -- 1) Nền hiện lên, laptop nhô lên nhẹ
        tween(stage, 0.35, QUAD, OUT, {GroupTransparency = 0})
        tween(laptopScale, 1.2, QUAD, OUT, {Scale = 1})

        -- 2) Mở nắp laptop
        waitUntil(0.35)
        tween(lid, 0.95, QUAD, OUT, {Size = UDim2.new(0, s(330), 0, s(176))})
        waitUntil(0.5)
        screen.Visible = true
        cam.Visible = true
        render()
        task.spawn(function()
            while laptopAlive do
                task.wait(0.45)
                cursorOn = not cursorOn
                render()
            end
        end)

        -- 3) Tự gõ "pip install tetomidi"
        waitUntil(1.5)
        local typedValue = Instance.new("NumberValue")
        typedValue.Value = 0
        typedValue.Changed:Connect(function(v)
            local n = math.floor(v + 0.5)
            if n ~= typedCount then
                typedCount = n
                cursorOn = true
                render()
            end
        end)
        tween(typedValue, 1.3, LINEAR, OUT, {Value = #INSTALL_CMD})

        -- 4) Enter -> kết quả cài đặt
        waitUntil(3.15)
        typedCount = #INSTALL_CMD
        lines[1] = '<font color="#8c8c8c">Collecting tetomidi</font>'
        render()
        waitUntil(3.4)
        lines[2] = 'Successfully installed tetomidi'
        render()

        -- 5) Laptop biến thành intro: màn hình sáng lên, zoom vào rồi tan
        waitUntil(3.8)
        tween(screenFlash, 0.25, QUAD, OUT, {BackgroundTransparency = 0.55})
        tween(laptopScale, 0.65, QUAD, IN, {Scale = 2.2})
        task.delay(0.2, function()
            tween(laptop, 0.45, QUAD, IN, {GroupTransparency = 1})
        end)

        -- Logo bật lên đúng chỗ màn hình laptop vừa tan
        waitUntil(3.95)
        if not preloadDone then
            logoFallback.Visible = true
        end
        tween(content, 0.45, QUAD, OUT, {GroupTransparency = 0})
        tween(logoScale, 0.6, BACK, OUT, {Scale = 1})

        -- Hiệu ứng nền chạy song song: halo thở + logo lơ lửng + shine lướt
        task.spawn(function()
            local t = 0
            while introAlive do
                t = t + task.wait()
                local pulse = math.sin(t * 2) * 0.5 + 0.5
                halo.Size = UDim2.new(0, 250 + pulse * 22, 0, 250 + pulse * 22)
                halo.BackgroundTransparency = 0.96 - pulse * 0.035
                logoFrame.Position = UDim2.new(0.5, 0, 0.5, -32 + math.sin(t * 1.4) * 4)
            end
        end)
        task.spawn(function()
            while introAlive do
                shineGradient.Offset = Vector2.new(-1, 0)
                local tw = TweenService:Create(shineGradient, TweenInfo.new(1.1, Enum.EasingStyle.Linear), {Offset = Vector2.new(1, 0)})
                tw:Play()
                tw.Completed:Wait()
            end
        end)

        waitUntil(4.1)
        tween(title, 0.4, QUAD, OUT, {TextTransparency = 0})

        -- % mượt bằng NumberValue: chạy 0 -> 100 trong khoảng 4.2s -> 6.05s
        waitUntil(4.2)
        tween(status, 0.35, QUAD, OUT, {TextTransparency = 0})
        tween(percent, 0.35, QUAD, OUT, {TextTransparency = 0})

        local percentValue = Instance.new("NumberValue")
        percentValue.Value = 0
        percentValue.Changed:Connect(function(v)
            local p = math.clamp(v / 100, 0, 1)
            bar.Size = UDim2.new(p, 0, 1, 0)
            percent.Text = math.floor(v + 0.5) .. "%"
        end)
        tween(percentValue, 1.85, SINE, OUT, {Value = 100})

        -- Dọn laptop khi đã tan hẳn
        waitUntil(4.5)
        laptopAlive = false
        laptop:Destroy()

        -- 6) Chờ tải ảnh xong (thường đã xong từ lâu), rồi "ready!"
        waitUntil(6.05)
        while not preloadDone do
            task.wait()
        end
        status.Text = "ready!"

        -- 7) Outro: flash viền logo rồi fade + zoom nhẹ. Kết thúc đúng giây thứ 7
        waitUntil(INTRO_TOTAL - INTRO_OUTRO)
        introAlive = false
        tween(logoStroke, 0.15, QUAD, OUT, {Transparency = 0})
        tween(barGlow, 0.15, QUAD, OUT, {Transparency = 0.3})
        task.wait(0.15)
        tween(stage, 0.5, QUAD, IN, {GroupTransparency = 1})
        tween(stageScale, 0.5, QUAD, IN, {Scale = 1.05})
        task.wait(0.5)
        introGui:Destroy()
        createMainUI()
    end)
end

-- ====================== UI HELPERS (LIQUID GLASS) ======================
local WHITE = Color3.fromRGB(255, 255, 255)
local GLASS_TINT = Color3.fromRGB(24, 28, 40)    -- nền kính xanh đen nhạt
local GLASS_WHITE = Color3.fromRGB(235, 240, 255) -- kính sáng (nút, hàng bài hát)
local BLUR_SIZE = 16                              -- độ mờ phông game phía sau popup (0 = tắt blur)

local function gray(v)
    return Color3.fromRGB(v, v, v)
end

local function round(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius or UDim.new(0, 8)
    c.Parent = obj
    return c
end

local function mkGradient(parent, rotation, transparency)
    local g = Instance.new("UIGradient")
    g.Rotation = rotation or 0
    g.Transparency = transparency
    g.Parent = parent
    return g
end

-- Viền kính: sáng ở góc trên-trái, mờ ở giữa, sáng lại nhẹ ở góc dưới-phải
local RIM_SEQ = NumberSequence.new({
    NumberSequenceKeypoint.new(0,    0.10),
    NumberSequenceKeypoint.new(0.30, 0.70),
    NumberSequenceKeypoint.new(0.70, 0.85),
    NumberSequenceKeypoint.new(1,    0.30),
})

local function makeRim(parent, thickness, extraT)
    local rim = Instance.new("UIStroke")
    rim.Name = "Rim"
    rim.Color = WHITE
    rim.Thickness = thickness or 1.2
    rim.Transparency = extraT or 0
    rim.Parent = parent
    mkGradient(rim, 40, RIM_SEQ)
    return rim
end

-- Biến một Frame/Button thành kính lỏng:
--   nền mờ + sheen (ánh phản chiếu cong) + vạch sáng mép trên + viền sáng gradient
-- opts: tint, alpha (BackgroundTransparency), shine (0 = tắt sheen), rim (false = bỏ viền),
--       rimThickness, rimT (độ mờ thêm của viền)
local function glassify(obj, radius, opts)
    opts = opts or {}
    local shine = opts.shine or 1
    local alpha = opts.alpha or 0.5

    obj.BackgroundColor3 = opts.tint or GLASS_TINT
    obj.BackgroundTransparency = alpha
    obj.BorderSizePixel = 0
    obj:SetAttribute("Base", alpha)
    if radius then round(obj, radius) end

    if shine > 0 then
        -- Sheen: sáng ở trên, tan dần xuống giữa, hắt lại nhẹ ở đáy
        local sheen = Instance.new("Frame")
        sheen.Name = "Sheen"
        sheen.Size = UDim2.new(1, 0, 1, 0)
        sheen.BackgroundColor3 = WHITE
        sheen.BorderSizePixel = 0
        sheen.Parent = obj
        if radius then round(sheen, radius) end
        mkGradient(sheen, 90, NumberSequence.new({
            NumberSequenceKeypoint.new(0,    1 - 0.30 * shine),
            NumberSequenceKeypoint.new(0.45, 1 - 0.07 * shine),
            NumberSequenceKeypoint.new(0.55, 1 - 0.02 * shine),
            NumberSequenceKeypoint.new(1,    1 - 0.10 * shine),
        }))

        -- Vạch phản quang mảnh sát mép trên
        local edge = Instance.new("Frame")
        edge.Name = "Edge"
        edge.AnchorPoint = Vector2.new(0.5, 0)
        edge.Size = UDim2.new(0.84, 0, 0, 1)
        edge.Position = UDim2.new(0.5, 0, 0, 1)
        edge.BackgroundColor3 = WHITE
        edge.BorderSizePixel = 0
        edge.Parent = obj
        mkGradient(edge, 0, NumberSequence.new({
            NumberSequenceKeypoint.new(0,   1),
            NumberSequenceKeypoint.new(0.5, 0.3),
            NumberSequenceKeypoint.new(1,   1),
        }))
    end

    if opts.rim ~= false then
        makeRim(obj, opts.rimThickness, opts.rimT)
    end
    return obj
end

-- Bật/tắt các lớp phản chiếu (dùng cho nút điều hướng: chỉ nút đang chọn mới "nổi" kính)
local function glassLayers(obj, on)
    local sheen = obj:FindFirstChild("Sheen")
    local edge = obj:FindFirstChild("Edge")
    local rim = obj:FindFirstChild("Rim")
    if sheen then sheen.Visible = on end
    if edge then edge.Visible = on end
    if rim then rim.Enabled = on end
end

-- Đổi độ trong suốt gốc của kính (hover sẽ sáng hơn 0.1 so với gốc này)
local function setGlassBase(obj, alpha)
    obj:SetAttribute("Base", alpha)
    TweenService:Create(obj, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundTransparency = alpha}):Play()
end

-- Hover: kính sáng lên khi rê chuột vào
local function hoverGlass(hit, frame)
    hit.MouseEnter:Connect(function()
        local base = frame:GetAttribute("Base") or 0.5
        TweenService:Create(frame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundTransparency = math.max(0, base - 0.1)}):Play()
    end)
    hit.MouseLeave:Connect(function()
        local base = frame:GetAttribute("Base") or 0.5
        TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = base}):Play()
    end)
end

-- Chữ trắng có viền tối rất nhẹ để luôn đọc được trên nền kính
local function softText(label)
    label.TextStrokeColor3 = gray(0)
    label.TextStrokeTransparency = 0.82
end

-- Nút/ô nhập dạng viên thuốc bằng kính. strong = true cho nút hành động chính.
-- (chữ phải nằm ở object con riêng, không gắn vào chính viên thuốc)
local function makePill(parent, size, position, strong)
    local f = Instance.new("Frame")
    f.Size = size
    f.Position = position
    f.Parent = parent
    glassify(f, UDim.new(1, 0), {
        tint = GLASS_WHITE,
        alpha = strong and 0.72 or 0.86,
        shine = strong and 1.2 or 0.9,
    })
    return f
end

-- Hiệu ứng nhấn nút: co nhẹ (0.9) rồi bật lại bằng UIScale
local function pressAnim(pill)
    local scale = pill:FindFirstChildOfClass("UIScale")
    if not scale then
        scale = Instance.new("UIScale")
        scale.Parent = pill
    end
    scale.Scale = 1
    TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.9}):Play()
    task.delay(0.08, function()
        TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    end)
end

-- Blur phông game phía sau popup: đây là thứ làm kính "mờ thật"
-- (BlurEffect chỉ làm mờ thế giới 3D, không làm mờ GUI nên chữ và nút vẫn nét)
local blurFx = nil
local function setBlur(on)
    if BLUR_SIZE <= 0 then return end
    pcall(function()
        if not blurFx then
            blurFx = Lighting:FindFirstChild("TetoGlassBlur")
            if not blurFx then
                blurFx = Instance.new("BlurEffect")
                blurFx.Name = "TetoGlassBlur"
                blurFx.Size = 0
                blurFx.Parent = Lighting
            end
        end
        TweenService:Create(blurFx, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {Size = on and BLUR_SIZE or 0}):Play()
    end)
end

-- Kích thước cửa sổ (vừa cho mobile, không quá to)
local SIDEBAR_W = 132

-- ====================== MAIN UI ======================
function createMainUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "TetoMIDI_v2"
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui

    -- ========== TOAST (thông báo tiếng Anh, kính mờ) ==========
    local toast = Instance.new("CanvasGroup")
    toast.Name = "Toast"
    toast.AnchorPoint = Vector2.new(0.5, 1)
    toast.Size = UDim2.new(0, 160, 0, 32)
    toast.Position = UDim2.new(0.5, 0, 1, 40)
    toast.GroupTransparency = 1
    toast.ZIndex = 100
    toast.Parent = gui
    glassify(toast, UDim.new(1, 0), {alpha = 0.3, shine = 1, rimT = 1})
    local toastRim = toast:FindFirstChild("Rim")

    local toastLabel = Instance.new("TextLabel")
    toastLabel.Size = UDim2.new(1, 0, 1, 0)
    toastLabel.BackgroundTransparency = 1
    toastLabel.Text = ""
    toastLabel.TextColor3 = WHITE
    toastLabel.Font = Enum.Font.GothamMedium
    toastLabel.TextSize = 13
    toastLabel.ZIndex = 101
    toastLabel.Parent = toast
    softText(toastLabel)

    local toastToken = 0
    local function showToast(text, duration)
        toastToken = toastToken + 1
        local mine = toastToken

        local w = 160
        pcall(function()
            w = TextService:GetTextSize(text, 13, Enum.Font.GothamMedium, Vector2.new(600, 40)).X + 36
        end)
        toast.Size = UDim2.new(0, w, 0, 32)
        toastLabel.Text = text

        -- Bắt đầu từ dưới, trượt lên
        toast.Position = UDim2.new(0.5, 0, 1, 30)
        local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(toast, info, {Position = UDim2.new(0.5, 0, 1, -16), GroupTransparency = 0}):Play()
        if toastRim then TweenService:Create(toastRim, info, {Transparency = 0}):Play() end

        task.delay(duration or 1.9, function()
            if mine ~= toastToken then return end -- đã có thông báo mới hơn
            local out = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            TweenService:Create(toast, out, {Position = UDim2.new(0.5, 0, 1, 30), GroupTransparency = 1}):Play()
            if toastRim then TweenService:Create(toastRim, out, {Transparency = 1}):Play() end
        end)
    end

    -- ========== FLOATING BUBBLE (real image) ==========
    local bubble = Instance.new("ImageButton")
    bubble.Name = "TetoBubble"
    bubble.Size = UDim2.new(0, 48, 0, 48)
    bubble.Position = UDim2.new(1, -70, 0.5, -24)
    bubble.AutoButtonColor = false
    bubble.Image = getImage("logo.png")
    bubble.ScaleType = Enum.ScaleType.Fit
    bubble.Parent = gui

    if bubble.Image == "" then
        local bubbleFallback = Instance.new("TextLabel")
        bubbleFallback.Size = UDim2.new(1, 0, 1, 0)
        bubbleFallback.BackgroundTransparency = 1
        bubbleFallback.Text = "♪"
        bubbleFallback.TextColor3 = WHITE
        bubbleFallback.Font = Enum.Font.GothamBold
        bubbleFallback.TextSize = 24
        bubbleFallback.Active = false
        bubbleFallback.Parent = bubble
    end
    glassify(bubble, UDim.new(1, 0), {alpha = 0.3, shine = 1.2, rimThickness = 1.6})
    local bubbleStroke = bubble:FindFirstChild("Rim")

    bubble.MouseEnter:Connect(function()
        TweenService:Create(bubble, TweenInfo.new(0.18), {Size = UDim2.new(0, 54, 0, 54)}):Play()
        TweenService:Create(bubbleStroke, TweenInfo.new(0.18), {Thickness = 2.4}):Play()
    end)
    bubble.MouseLeave:Connect(function()
        TweenService:Create(bubble, TweenInfo.new(0.18), {Size = UDim2.new(0, 48, 0, 48)}):Play()
        TweenService:Create(bubbleStroke, TweenInfo.new(0.18), {Thickness = 1.6}):Play()
    end)

    local bubbleDragging, bubbleDragStart, bubbleStartPos, bubbleMoved = false, nil, nil, false

    bubble.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            bubbleDragging = true
            bubbleMoved = false
            bubbleDragStart = input.Position
            bubbleStartPos = bubble.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    bubbleDragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if bubbleDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - bubbleDragStart
            if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
                bubbleMoved = true
            end
            bubble.Position = UDim2.new(
                bubbleStartPos.X.Scale, bubbleStartPos.X.Offset + delta.X,
                bubbleStartPos.Y.Scale, bubbleStartPos.Y.Offset + delta.Y
            )
        end
    end)

    -- ========== MAIN FRAME ==========
    -- Co theo màn hình nhưng bị chặn trong khoảng 330x210 → 470x290
    -- (điện thoại ngang ~ 460x260, PC cũng không phình to)
    -- CanvasGroup để fade toàn bộ nội dung popup cùng lúc
    local main = Instance.new("CanvasGroup")
    main.Name = "Main"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.Size = UDim2.new(0.7, 0, 0.8, 0)
    main.BackgroundTransparency = 1
    main.BorderSizePixel = 0
    main.Active = true
    main.ClipsDescendants = true
    main.Visible = false
    main.GroupTransparency = 1
    main.Parent = gui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 20)
    mainCorner.Parent = main

    -- Lớp kính nền (nằm dưới cùng): nền mờ + sheen + vạch phản quang
    local glassBase = Instance.new("Frame")
    glassBase.Name = "GlassBase"
    glassBase.Size = UDim2.new(1, 0, 1, 0)
    glassBase.Parent = main
    glassify(glassBase, nil, {alpha = 0.34, shine = 1.3, rim = false})

    -- Lớp bắt chuột nằm DƯỚI cùng: bấm/kéo vào bất kỳ chỗ trống nào của cửa sổ đều di chuyển được
    -- (nút, ô nhập, danh sách cuộn nằm trên lớp này nên vẫn hoạt động bình thường)
    local dragLayer = Instance.new("Frame")
    dragLayer.Name = "DragLayer"
    dragLayer.Size = UDim2.new(1, 0, 1, 0)
    dragLayer.BackgroundTransparency = 1
    dragLayer.BorderSizePixel = 0
    dragLayer.Active = true
    dragLayer.Parent = main

    local mainScale = Instance.new("UIScale")
    mainScale.Scale = 0.85
    mainScale.Parent = main

    local sizeLimit = Instance.new("UISizeConstraint")
    sizeLimit.MinSize = Vector2.new(380, 280)
    sizeLimit.MaxSize = Vector2.new(680, 430)
    sizeLimit.Parent = main

    -- Viền kính sáng gradient (hiện dần khi mở popup)
    local mainStroke = makeRim(main, 1.5, 1)

    -- Vệt sáng chéo lướt qua mặt kính định kỳ (lớp trên cùng, không chặn chuột)
    local glare = Instance.new("Frame")
    glare.Name = "Glare"
    glare.AnchorPoint = Vector2.new(0.5, 0.5)
    glare.Size = UDim2.new(0.26, 0, 1.9, 0)
    glare.Position = UDim2.new(-0.3, 0, 0.5, 0)
    glare.Rotation = 18
    glare.BackgroundColor3 = WHITE
    glare.BorderSizePixel = 0
    glare.ZIndex = 5
    glare.Parent = main
    mkGradient(glare, 0, NumberSequence.new({
        NumberSequenceKeypoint.new(0,   1),
        NumberSequenceKeypoint.new(0.5, 0.9),
        NumberSequenceKeypoint.new(1,   1),
    }))
    task.spawn(function()
        while gui.Parent do
            task.wait(4.5)
            if MainVisible then
                glare.Position = UDim2.new(-0.3, 0, 0.5, 0)
                TweenService:Create(glare, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = UDim2.new(1.3, 0, 0.5, 0)}):Play()
            end
        end
    end)

    -- Mở/đóng popup bằng tween (scale + fade) thay vì bật Visible đột ngột
    local openTween, closeTween
    local function openMain()
        MainVisible = true
        setBlur(true)
        TweenService:Create(mainStroke, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
        if closeTween then closeTween:Cancel() end
        main.Visible = true
        mainScale.Scale = 0.85
        main.GroupTransparency = 1
        TweenService:Create(mainScale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        openTween = TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = Cfg.ui.alpha})
        openTween:Play()
    end

    local function closeMain()
        MainVisible = false
        setBlur(false)
        TweenService:Create(mainStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
        if openTween then openTween:Cancel() end
        TweenService:Create(mainScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.9}):Play()
        closeTween = TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1})
        closeTween:Play()
        closeTween.Completed:Connect(function()
            if not MainVisible then main.Visible = false end
        end)
    end

    -- Bật/tắt bằng bubble
    bubble.MouseButton1Click:Connect(function()
        if bubbleMoved then return end
        playClick()
        if MainVisible then closeMain() else openMain() end
    end)

    -- ===== SIDEBAR (đen → xám) =====
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, 0)
    sidebar.Active = true
    sidebar.Parent = main
    glassify(sidebar, nil, {tint = Color3.fromRGB(6, 8, 14), alpha = 0.5, shine = 0.7, rim = false})

    -- Đường chia mảnh giữa sidebar và nội dung
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.AnchorPoint = Vector2.new(1, 0)
    divider.Size = UDim2.new(0, 1, 1, 0)
    divider.Position = UDim2.new(1, 0, 0, 0)
    divider.BackgroundColor3 = WHITE
    divider.BackgroundTransparency = 0.82
    divider.BorderSizePixel = 0
    divider.Parent = sidebar

    -- ===== KÉO CỬA SỔ =====
    -- Kéo được từ: lớp nền (chỗ trống), sidebar, vùng nội dung, logo + tên.
    -- Có ngưỡng 4px để bấm nút không bị xê dịch; tự chặn không cho cửa sổ trôi ra ngoài màn hình.
    local function viewportSize()
        local cam = workspace.CurrentCamera
        local vp = (cam and cam.ViewportSize) or Vector2.new(0, 0)
        if vp.X < 100 or vp.Y < 100 then vp = gui.AbsoluteSize end
        if vp.X < 100 or vp.Y < 100 then vp = Vector2.new(800, 400) end
        return vp
    end

    local winDrag = nil   -- {start = Vector3, center = Vector2, moved = bool}
    local winRef = main   -- cửa sổ đang kéo: khung lớn (main) hoặc mini

    -- Cửa sổ cố định ở giữa màn hình (không kéo đi mọi hướng). Đặt true nếu muốn kéo lại.
    local WINDOW_DRAGGABLE = true
    local function beginWindowDrag(input)
        if not WINDOW_DRAGGABLE then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if winDrag then return end
        winDrag = {
            target = winRef,
            input = input,
            start = input.Position,
            center = winRef.AbsolutePosition + winRef.AbsoluteSize / 2,
            moved = false,
        }
    end

    local function bindWindowDrag(obj)
        obj.InputBegan:Connect(beginWindowDrag)
    end

    bindWindowDrag(dragLayer)
    bindWindowDrag(sidebar)
    bindWindowDrag(main)   -- vùng còn lại của cửa sổ (nhãn, roll, khung trống) cũng kéo được

    UserInputService.InputChanged:Connect(function(input)
        if not winDrag then return end
        local t = input.UserInputType
        if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
        -- cảm ứng nhiều ngón: chỉ theo dõi đúng ngón đã bắt đầu kéo
        if t == Enum.UserInputType.Touch and winDrag.input.UserInputType ~= Enum.UserInputType.Touch then return end
        -- bấm vào nút / ô nhập / danh sách / thanh tua: không kéo cửa sổ
        if UI_CLAIM[winDrag.input] then winDrag = nil; return end
        if winDrag.target ~= winRef then winDrag = nil; return end

        local delta = input.Position - winDrag.start
        if not winDrag.moved then
            if math.abs(delta.X) < 4 and math.abs(delta.Y) < 4 then return end
            winDrag.moved = true
        end

        local vp = viewportSize()
        local half = winRef.AbsoluteSize / 2
        local keep = 60   -- luôn chừa lại ít nhất 60px của cửa sổ trong màn hình
        local cx = math.clamp(winDrag.center.X + delta.X, keep - half.X, vp.X - keep + half.X)
        local cy = math.clamp(winDrag.center.Y + delta.Y, keep - half.Y, vp.Y - keep + half.Y)
        winRef.Position = UDim2.new(0, cx, 0, cy)
    end)

    UserInputService.InputEnded:Connect(function(input)
        if not winDrag then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or (t == Enum.UserInputType.Touch and winDrag.input.UserInputType == Enum.UserInputType.Touch) then
            winDrag = nil
        end
    end)

    -- Logo + tên
    local headerLogo = Instance.new("ImageLabel")
    headerLogo.Size = UDim2.new(0, 26, 0, 26)
    headerLogo.Position = UDim2.new(0, 8, 0, 10)
    headerLogo.BackgroundTransparency = 1
    headerLogo.Image = getImage("logo.png")
    headerLogo.ScaleType = Enum.ScaleType.Fit
    headerLogo.Parent = sidebar
    round(headerLogo, UDim.new(0, 5))

    local logoTitle = Instance.new("TextLabel")
    logoTitle.Size = UDim2.new(1, -44, 0, 26)
    logoTitle.Position = UDim2.new(0, 40, 0, 10)
    logoTitle.BackgroundTransparency = 1
    logoTitle.Text = "tetoMIDI v2.3"
    logoTitle.TextColor3 = WHITE
    logoTitle.Font = Enum.Font.GothamBold
    logoTitle.TextSize = 12
    logoTitle.TextXAlignment = Enum.TextXAlignment.Left
    logoTitle.Parent = sidebar
    softText(logoTitle)

    -- Nút điều hướng
    local navButtons = {}
    local updatePages -- khai báo trước, gán ở dưới

    local function makeNavBtn(text, iconName, y, page)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -16, 0, 32)
        btn.Position = UDim2.new(0, 8, 0, y)
        btn.BackgroundColor3 = WHITE
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.Parent = sidebar
        glassify(btn, UDim.new(0, 10), {tint = GLASS_WHITE, alpha = 1, shine = 0.9, rimT = 0.2})
        glassLayers(btn, false)      -- chỉ nút đang chọn mới nổi lớp kính (xem updatePages)
        hoverGlass(btn, btn)
        bindClick(btn)

        local iconId = getImage(iconName)
        if iconId ~= "" then
            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.new(0, 22, 0, 22)
            icon.Position = UDim2.new(0, 6, 0.5, -11)
            icon.BackgroundTransparency = 1
            icon.Image = iconId
            icon.ScaleType = Enum.ScaleType.Fit
            icon.Parent = btn
            round(icon, UDim.new(0, 5))
        end

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -36, 1, 0)
        label.Position = UDim2.new(0, 34, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = WHITE
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = btn
        softText(label)

        btn.MouseButton1Click:Connect(function()
            pressAnim(btn)
            CurrentPage = page
            updatePages()
        end)

        navButtons[page] = btn
        return btn
    end

    makeNavBtn("piano player", "piano.png", 46, "player")
    makeNavBtn("custom song", "hub.png", 82, "custom")

    -- Nút Discord (dưới cùng sidebar): bấm = copy link + thông báo
    local discordBtn = Instance.new("TextButton")
    discordBtn.Name = "Discord"
    discordBtn.AnchorPoint = Vector2.new(0, 1)
    discordBtn.Size = UDim2.new(1, -16, 0, 32)
    discordBtn.Position = UDim2.new(0, 8, 1, -10)
    discordBtn.BackgroundColor3 = WHITE
    discordBtn.BackgroundTransparency = 0.9
    discordBtn.Text = ""
    discordBtn.AutoButtonColor = false
    discordBtn.BorderSizePixel = 0
    discordBtn.Parent = sidebar
    glassify(discordBtn, UDim.new(0, 10), {tint = GLASS_WHITE, alpha = 0.88, shine = 0.9, rimT = 0.2})
    hoverGlass(discordBtn, discordBtn)
    bindClick(discordBtn)

    local discordIconId = getImage("discord.png")
    if discordIconId ~= "" then
        local dIcon = Instance.new("ImageLabel")
        dIcon.Size = UDim2.new(0, 22, 0, 22)
        dIcon.Position = UDim2.new(0, 6, 0.5, -11)
        dIcon.BackgroundTransparency = 1
        dIcon.Image = discordIconId
        dIcon.ScaleType = Enum.ScaleType.Fit
        dIcon.Parent = discordBtn
    end

    local discordLabel = Instance.new("TextLabel")
    discordLabel.Size = UDim2.new(1, -36, 1, 0)
    discordLabel.Position = UDim2.new(0, discordIconId ~= "" and 34 or 12, 0, 0)
    discordLabel.BackgroundTransparency = 1
    discordLabel.Text = "discord"
    discordLabel.TextColor3 = WHITE
    discordLabel.Font = Enum.Font.GothamMedium
    discordLabel.TextSize = 13
    discordLabel.TextXAlignment = Enum.TextXAlignment.Left
    discordLabel.Parent = discordBtn
    softText(discordLabel)

    discordBtn.MouseButton1Click:Connect(function()
        local setclip = setclipboard or toclipboard or (syn and syn.write_clipboard) or (Clipboard and Clipboard.set)
        local copied = false
        if setclip then
            copied = pcall(setclip, DISCORD_LINK)
        end
        if copied then
            showToast("Discord link copied")
        else
            showToast("Can't copy - " .. DISCORD_LINK)
            print("[tetoMIDI] Discord: " .. DISCORD_LINK)
        end
    end)

    -- ===== THANH TIÊU ĐỀ (nút mini / console nằm bên phải, tạo ở cuối) =====
    local HEADER_H = 30
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Position = UDim2.new(0, SIDEBAR_W, 0, 0)
    header.Size = UDim2.new(1, -SIDEBAR_W, 0, HEADER_H)
    header.BackgroundTransparency = 1
    header.BorderSizePixel = 0
    header.Active = true
    header.Parent = main
    bindWindowDrag(header)

    -- ===== CONTENT =====
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -SIDEBAR_W, 1, -HEADER_H)
    content.Position = UDim2.new(0, SIDEBAR_W, 0, HEADER_H)
    content.BackgroundTransparency = 1
    content.Parent = main
    bindWindowDrag(content)

    -- ===== NÚT CHỮ DÙNG CHUNG =====
    local function makeTextButton(parent, text, size, font)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 1, 0)
        b.BackgroundTransparency = 1
        b.Text = text
        b.TextColor3 = WHITE
        b.Font = font or Enum.Font.GothamBold
        b.TextSize = size or 12
        b.AutoButtonColor = false
        b.Parent = parent
        softText(b)
        return b
    end

    -- ===== ẢNH NỀN CHO UI CHÍNH (png / jpg link) =====
    -- Tải ảnh từ link, lưu vào tetoMIDI/bg (mở lại game không cần tải lại).
    local BG_DIR = "tetoMIDI/bg"
    local bgImage = Instance.new("ImageLabel")
    bgImage.Name = "MainBackground"
    bgImage.Size = UDim2.new(1, 0, 1, 0)
    bgImage.BackgroundTransparency = 1
    bgImage.ScaleType = Enum.ScaleType.Crop
    bgImage.ZIndex = 0
    bgImage.Visible = false
    bgImage.Parent = main
    round(bgImage, UDim.new(0, 14))

    local function isJpg(data)
        return type(data) == "string" and #data > 100 and data:byte(1) == 0xFF and data:byte(2) == 0xD8
    end

    local function setMainBackground(id)
        bgImage.Image = id
        bgImage.Visible = (id ~= "")
    end

    local function loadBackground(_, url)
        url = (tostring(url or ""):gsub("%s+", ""))
        if url == "" then
            Cfg.bg.main = ""
            saveCfg()
            setMainBackground("")
            return true
        end
        if not url:match("^https?://") then return false, "link must start with http(s)" end
        if not (writefile and isfile and (getcustomasset or getsynasset)) then
            return false, "this executor can't load images"
        end
        local data = httpGetRaw(url)
        local ext = nil
        if isPng(data) then ext = "png" elseif isJpg(data) then ext = "jpg" end
        if not ext then return false, "not a png/jpg link" end
        if #data > 5 * 1024 * 1024 then return false, "image is over 5 MB" end
        pcall(function()
            if isfolder and not isfolder("tetoMIDI") then makefolder("tetoMIDI") end
            if isfolder and not isfolder(BG_DIR) then makefolder(BG_DIR) end
        end)
        local path = BG_DIR .. "/main." .. ext
        if not pcall(writefile, path, data) then return false, "can't save the image" end
        local id = getAsset(path)
        if id == "" then return false, "can't load the image" end
        setMainBackground(id)
        Cfg.bg.main = url
        saveCfg()
        return true
    end

    -- Khi mở lại game: dùng ảnh đã lưu trong tetoMIDI/bg
    if Cfg.bg.main ~= nil and Cfg.bg.main ~= "" then
        for _, ext in ipairs({"png", "jpg"}) do
            local path = BG_DIR .. "/main." .. ext
            local exists = false
            pcall(function() exists = (isfile and isfile(path)) or false end)
            if exists then
                local id = getAsset(path)
                if id ~= "" then setMainBackground(id); break end
            end
        end
    end

    -- ===== CÀI ĐẶT (icon bánh răng ở sidebar) =====
    local settingsPage = Instance.new("ScrollingFrame")
    settingsPage.Name = "SettingsPage"
    settingsPage.Size = UDim2.new(1, 0, 1, 0)
    settingsPage.BackgroundTransparency = 1
    settingsPage.BorderSizePixel = 0
    settingsPage.ScrollBarThickness = 3
    settingsPage.ScrollBarImageColor3 = gray(190)
    settingsPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
    settingsPage.CanvasSize = UDim2.new(0, 0, 0, 0)
    settingsPage.Visible = false
    settingsPage.Parent = content
    claimInput(settingsPage)
    local settingsLayout = Instance.new("UIListLayout")
    settingsLayout.Padding = UDim.new(0, 8)
    settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    settingsLayout.Parent = settingsPage
    local settingsPad = Instance.new("UIPadding")
    settingsPad.PaddingLeft = UDim.new(0, 14)
    settingsPad.PaddingRight = UDim.new(0, 14)
    settingsPad.PaddingTop = UDim.new(0, 12)
    settingsPad.PaddingBottom = UDim.new(0, 12)
    settingsPad.Parent = settingsPage

    local settingsOrder = 0
    local function nextOrder()
        settingsOrder = settingsOrder + 1
        return settingsOrder
    end

    local function settingsTitle(text)
        local t = Instance.new("TextLabel")
        t.LayoutOrder = nextOrder()
        t.Size = UDim2.new(1, 0, 0, 24)
        t.BackgroundTransparency = 1
        t.Text = text
        t.TextColor3 = WHITE
        t.Font = Enum.Font.GothamBold
        t.TextSize = 14
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = settingsPage
        softText(t)
    end

    -- Hàng: nhãn | [-] giá trị [+]
    local function stepperRow(text, valueText, onStep)
        local row = Instance.new("Frame")
        row.LayoutOrder = nextOrder()
        row.Size = UDim2.new(1, 0, 0, 30)
        row.BackgroundTransparency = 1
        row.Parent = settingsPage

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -150, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = WHITE
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row
        softText(lbl)

        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0, 44, 1, 0)
        val.Position = UDim2.new(1, -92, 0, 0)
        val.BackgroundTransparency = 1
        val.Text = valueText()
        val.TextColor3 = WHITE
        val.Font = Enum.Font.GothamBold
        val.TextSize = 13
        val.Parent = row
        softText(val)

        local function stepBtn(x, sign)
            local pill = makePill(row, UDim2.new(0, 30, 0, 26), UDim2.new(1, x, 0.5, -13))
            local b = makeTextButton(pill, sign < 0 and "-" or "+", 15, Enum.Font.GothamBold)
            hoverGlass(b, pill)
            bindClick(b)
            b.MouseButton1Click:Connect(function()
                pressAnim(pill)
                onStep(sign)
                val.Text = valueText()
            end)
        end
        stepBtn(-124, -1)
        stepBtn(-30, 1)
        return row
    end

    -- Hàng: nhãn | [nút bật/tắt]
    local function toggleRow(text, isOn, onToggle)
        local row = Instance.new("Frame")
        row.LayoutOrder = nextOrder()
        row.Size = UDim2.new(1, 0, 0, 30)
        row.BackgroundTransparency = 1
        row.Parent = settingsPage

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -90, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = WHITE
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row
        softText(lbl)

        local pill = makePill(row, UDim2.new(0, 64, 0, 26), UDim2.new(1, -64, 0.5, -13), isOn())
        local b = makeTextButton(pill, isOn() and "on" or "off", 13, Enum.Font.GothamBold)
        hoverGlass(b, pill)
        bindClick(b)
        b.MouseButton1Click:Connect(function()
            pressAnim(pill)
            onToggle()
            b.Text = isOn() and "on" or "off"
        end)
    end

    -- Ô link ảnh nền cho 1 trang (piano / drums / guitar)
    local function backgroundRow(mode, label)
        local row = Instance.new("Frame")
        row.LayoutOrder = nextOrder()
        row.Size = UDim2.new(1, 0, 0, 62)
        row.BackgroundTransparency = 1
        row.Parent = settingsPage

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = WHITE
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row
        softText(lbl)

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, 0, 0, 26)
        box.Position = UDim2.new(0, 0, 0, 22)
        box.BackgroundColor3 = WHITE
        box.BackgroundTransparency = 0.9
        box.BorderSizePixel = 0
        box.Text = Cfg.bg[mode] or ""
        box.PlaceholderText = "https://...png or .jpg"
        box.PlaceholderColor3 = gray(205)
        box.TextColor3 = WHITE
        box.Font = Enum.Font.GothamMedium
        box.TextSize = 12
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.ClearTextOnFocus = false
        box.TextTruncate = Enum.TextTruncate.AtEnd
        box.Parent = row
        claimInput(box)

        local applyPill = makePill(row, UDim2.new(0, 70, 0, 22), UDim2.new(0, 0, 0, 40))
        local applyB = makeTextButton(applyPill, "apply", 12, Enum.Font.GothamMedium)
        hoverGlass(applyB, applyPill)
        bindClick(applyB)
        applyB.MouseButton1Click:Connect(function()
            pressAnim(applyPill)
            task.spawn(function()
                local ok, err = loadBackground(mode, box.Text)
                showToast(ok and "Background applied" or ("Background: " .. tostring(err)), 2.5)
            end)
        end)

        local clearPill = makePill(row, UDim2.new(0, 70, 0, 22), UDim2.new(0, 78, 0, 40))
        local clearB = makeTextButton(clearPill, "clear", 12, Enum.Font.GothamMedium)
        hoverGlass(clearB, clearPill)
        bindClick(clearB)
        clearB.MouseButton1Click:Connect(function()
            pressAnim(clearPill)
            task.spawn(function()
                local ok, err = loadBackground(mode, "")
                box.Text = ""
                showToast(ok and "Background removed" or ("Background: " .. tostring(err)), 2.5)
            end)
        end)
    end

    settingsTitle("window")
    stepperRow("transparency", function() return string.format("%d%%", math.floor(Cfg.ui.alpha * 100 + 0.5)) end,
        function(sign)
            Cfg.ui.alpha = math.clamp(math.floor((Cfg.ui.alpha + sign * 0.1) * 10 + 0.5) / 10, 0, 0.8)
            if MainVisible then main.GroupTransparency = Cfg.ui.alpha end
            saveCfg()
        end)

    settingsTitle("main ui background (png / jpg link)")
    backgroundRow("main", "main ui")

    settingsTitle("custom song")
    do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 36)
        row.BackgroundTransparency = 1
        row.Parent = settingsPage

        local holder = makePill(row, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -110, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "stop playing song"
        lbl.TextColor3 = WHITE
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = holder
        softText(lbl)

        local stopBtn = Instance.new("TextButton")
        stopBtn.Size = UDim2.new(0, 84, 0, 26)
        stopBtn.Position = UDim2.new(1, -92, 0.5, -13)
        stopBtn.BackgroundTransparency = 1
        stopBtn.Text = "stop"
        stopBtn.TextColor3 = WHITE
        stopBtn.Font = Enum.Font.GothamMedium
        stopBtn.TextSize = 12
        stopBtn.AutoButtonColor = false
        stopBtn.Parent = holder
        softText(stopBtn)
        bindClick(stopBtn)
        stopBtn.MouseButton1Click:Connect(function()
            pressAnim(holder)
            _G.TETOMIDI_STOP = true
            showToast("stopped", 1.5)
        end)
    end

    -- Nút icon bánh răng trên sidebar
    makeNavBtn("settings", "gear.png", 190, "settings")

    -- ===== TRANG CUSTOM SONG =====
    -- Đặt tên bài, dán script midi2lua tự chế, bấm run. Script được lưu vào thư mục "custom song".
    local CUSTOM_DIR = "custom song"
    local customPage = Instance.new("Frame")
    customPage.Name = "CustomPage"
    customPage.Size = UDim2.new(1, 0, 1, 0)
    customPage.BackgroundTransparency = 1
    customPage.Visible = false
    customPage.Parent = content

    local customTitle = Instance.new("TextLabel")
    customTitle.Size = UDim2.new(1, -24, 0, 24)
    customTitle.Position = UDim2.new(0, 12, 0, 10)
    customTitle.BackgroundTransparency = 1
    customTitle.Text = "custom song"
    customTitle.TextColor3 = WHITE
    customTitle.Font = Enum.Font.GothamBold
    customTitle.TextSize = 15
    customTitle.TextXAlignment = Enum.TextXAlignment.Left
    customTitle.Parent = customPage
    softText(customTitle)

    local namePill = Instance.new("Frame")
    namePill.Size = UDim2.new(1, -24, 0, 28)
    namePill.Position = UDim2.new(0, 12, 0, 42)
    namePill.BackgroundTransparency = 1
    namePill.Parent = customPage
    glassify(namePill, UDim.new(0, 12), {tint = GLASS_WHITE, alpha = 0.86, shine = 0.9})
    local nameBox = Instance.new("TextBox")
    nameBox.Size = UDim2.new(1, -20, 1, 0)
    nameBox.Position = UDim2.new(0, 10, 0, 0)
    nameBox.BackgroundTransparency = 1
    nameBox.Text = ""
    nameBox.PlaceholderText = "song name"
    nameBox.PlaceholderColor3 = gray(205)
    nameBox.TextColor3 = WHITE
    nameBox.Font = Enum.Font.GothamMedium
    nameBox.TextSize = 13
    nameBox.TextXAlignment = Enum.TextXAlignment.Left
    nameBox.ClearTextOnFocus = false
    nameBox.Parent = namePill
    claimInput(nameBox)

    local scriptPill = Instance.new("Frame")
    scriptPill.Size = UDim2.new(1, -24, 1, -120)
    scriptPill.Position = UDim2.new(0, 12, 0, 80)
    scriptPill.BackgroundTransparency = 1
    scriptPill.Parent = customPage
    glassify(scriptPill, UDim.new(0, 16), {tint = GLASS_WHITE, alpha = 0.86, shine = 0.9})
    local scriptScroll = Instance.new("ScrollingFrame")
    scriptScroll.Size = UDim2.new(1, -12, 1, -12)
    scriptScroll.Position = UDim2.new(0, 6, 0, 6)
    scriptScroll.BackgroundTransparency = 1
    scriptScroll.BorderSizePixel = 0
    scriptScroll.ScrollBarThickness = 3
    scriptScroll.ScrollBarImageColor3 = gray(190)
    scriptScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scriptScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scriptScroll.Parent = scriptPill
    claimInput(scriptScroll)

    local scriptBox = Instance.new("TextBox")
    scriptBox.Size = UDim2.new(1, -10, 0, 0)
    scriptBox.AutomaticSize = Enum.AutomaticSize.Y
    scriptBox.BackgroundTransparency = 1
    scriptBox.Text = ""
    scriptBox.PlaceholderText = "paste midi2lua script here"
    scriptBox.PlaceholderColor3 = gray(205)
    scriptBox.TextColor3 = WHITE
    scriptBox.Font = Enum.Font.Gotham
    scriptBox.TextSize = 12
    scriptBox.TextXAlignment = Enum.TextXAlignment.Left
    scriptBox.TextYAlignment = Enum.TextYAlignment.Top
    scriptBox.TextWrapped = true
    scriptBox.MultiLine = true
    scriptBox.ClearTextOnFocus = false
    scriptBox.Parent = scriptScroll
    claimInput(scriptBox)

    nameBox.Text = Cfg.custom.name or ""
    scriptBox.Text = Cfg.custom.script or ""
    nameBox:GetPropertyChangedSignal("Text"):Connect(function()
        Cfg.custom.name = nameBox.Text
        saveCfg()
    end)
    scriptBox:GetPropertyChangedSignal("Text"):Connect(function()
        Cfg.custom.script = scriptBox.Text
        saveCfg()
    end)

    local function customName()
        local n = tostring(nameBox.Text):gsub("[^%w_%- ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if n == "" then n = "untitled" end
        return n
    end

    local function saveCustomScript(name, src)
        pcall(function()
            if isfolder and not isfolder(CUSTOM_DIR) then makefolder(CUSTOM_DIR) end
            if writefile then writefile(CUSTOM_DIR .. "/" .. name .. ".lua", src) end
        end)
    end

    local function customBtn(x, text, onClick)
        local pill = makePill(customPage, UDim2.new(0, 80, 0, 28), UDim2.new(0, x, 1, -36))
        local b = makeTextButton(pill, text, 12, Enum.Font.GothamMedium)
        hoverGlass(b, pill)
        bindClick(b)
        b.MouseButton1Click:Connect(function()
            pressAnim(pill)
            onClick()
        end)
        return pill
    end

    customBtn(12, "run", function()
        local src = scriptBox.Text
        if src:match("^%s*$") then showToast("paste a script first", 2) return end
        local name = customName()
        saveCustomScript(name, src)
        local fn, err = loadstring(src)
        if not fn then showToast("script error: " .. tostring(err), 3) return end
        showToast("running " .. name, 2)
        task.spawn(function()
            local ok, runErr = pcall(fn)
            if not ok then showToast("run error: " .. tostring(runErr), 3) end
        end)
    end)

    customBtn(100, "save", function()
        local src = scriptBox.Text
        if src:match("^%s*$") then showToast("paste a script first", 2) return end
        local name = customName()
        saveCustomScript(name, src)
        showToast("saved to custom song/" .. name .. ".lua", 2.5)
    end)

    customBtn(188, "clear", function()
        scriptBox.Text = ""
        showToast("script cleared", 2)
    end)

    -- ===== TRANG PIANO PLAYER (danh sách bài trong custom song) =====
    local playerPage = Instance.new("ScrollingFrame")
    playerPage.Name = "PlayerPage"
    playerPage.Size = UDim2.new(1, 0, 1, 0)
    playerPage.BackgroundTransparency = 1
    playerPage.BorderSizePixel = 0
    playerPage.ScrollBarThickness = 3
    playerPage.ScrollBarImageColor3 = gray(190)
    playerPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
    playerPage.CanvasSize = UDim2.new(0, 0, 0, 0)
    playerPage.Visible = false
    playerPage.Parent = content
    claimInput(playerPage)

    local playerLayout = Instance.new("UIListLayout")
    playerLayout.Padding = UDim.new(0, 8)
    playerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    playerLayout.Parent = playerPage

    local playerPad = Instance.new("UIPadding")
    playerPad.PaddingTop = UDim.new(0, 12)
    playerPad.PaddingLeft = UDim.new(0, 12)
    playerPad.PaddingRight = UDim.new(0, 12)
    playerPad.PaddingBottom = UDim.new(0, 12)
    playerPad.Parent = playerPage

    local playerTitle = Instance.new("TextLabel")
    playerTitle.Size = UDim2.new(1, 0, 0, 24)
    playerTitle.BackgroundTransparency = 1
    playerTitle.Text = "piano player"
    playerTitle.TextColor3 = WHITE
    playerTitle.Font = Enum.Font.GothamBold
    playerTitle.TextSize = 15
    playerTitle.TextXAlignment = Enum.TextXAlignment.Left
    playerTitle.LayoutOrder = 0
    playerTitle.Parent = playerPage
    softText(playerTitle)

    local refreshList
    local function songNames()
        local names = {}
        pcall(function()
            if not (listfiles and isfolder and isfolder(CUSTOM_DIR)) then return end
            for _, path in ipairs(listfiles(CUSTOM_DIR)) do
                local fname = tostring(path):match("([^/\\]+)$")
                if fname and fname:match("%.lua$") then
                    table.insert(names, (fname:gsub("%.lua$", "")))
                end
            end
        end)
        table.sort(names)
        return names
    end

    local function playSong(name)
        local path = CUSTOM_DIR .. "/" .. name .. ".lua"
        local okRead, src = pcall(readfile, path)
        if not okRead or type(src) ~= "string" then
            showToast("cannot read " .. name, 2.5)
            return
        end
        local fn, err = loadstring(src)
        if not fn then
            showToast("script error: " .. tostring(err), 3)
            return
        end
        _G.TETOMIDI_STOP = false
        -- kiểm tra nhanh: script tự chứa thì phải có UI riêng; script loadstring gist thì bỏ qua
        if not src:find("loadstring(game:HttpGet", 1, true) and not src:find("TetoMIDI_Song", 1, true) then
            showToast("old script: no song ui, convert again", 3)
        else
            showToast("running " .. name, 2)
        end
        task.spawn(function()
            local ok, runErr = pcall(fn)
            if not ok then showToast("run error: " .. tostring(runErr), 3) end
        end)
    end

    local function deleteSong(name)
        local path = CUSTOM_DIR .. "/" .. name .. ".lua"
        if not delfile then
            showToast("this executor can't delete files", 2.5)
            return
        end
        local ok = pcall(delfile, path)
        showToast(ok and ("deleted " .. name) or ("delete failed: " .. name), 2)
        refreshList()
    end

    local function rowBtn(parent, text, x, onClick)
        local holder = makePill(parent, UDim2.new(0, 64, 0, 28), UDim2.new(1, x, 0.5, -14))
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 1, 0)
        b.BackgroundTransparency = 1
        b.Text = text
        b.TextColor3 = WHITE
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 12
        b.AutoButtonColor = false
        b.Parent = holder
        softText(b)
        hoverGlass(b, holder)
        bindClick(b)
        b.MouseButton1Click:Connect(function()
            pressAnim(holder)
            onClick()
        end)
    end

    local function songRow(name, order)
        local row = Instance.new("Frame")
        row.Name = "SongRow"
        row.Size = UDim2.new(1, 0, 0, 42)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        row.Parent = playerPage

        local pill = makePill(row, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -160, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = WHITE
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Parent = pill
        softText(lbl)

        rowBtn(pill, "play", -140, function() playSong(name) end)
        rowBtn(pill, "delete", -70, function() deleteSong(name) end)
    end

    refreshList = function()
        for _, child in ipairs(playerPage:GetChildren()) do
            if child.Name == "SongRow" then child:Destroy() end
        end
        local names = songNames()
        if #names == 0 then
            local empty = Instance.new("TextLabel")
            empty.Name = "SongRow"
            empty.Size = UDim2.new(1, 0, 0, 40)
            empty.BackgroundTransparency = 1
            empty.Text = "no songs yet. paste a script in custom song and press save."
            empty.TextColor3 = gray(190)
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 12
            empty.TextWrapped = true
            empty.LayoutOrder = 1
            empty.Parent = playerPage
            return
        end
        for i, name in ipairs(names) do
            songRow(name, i)
        end
    end

    -- ===== CHUYỂN TRANG =====
    updatePages = function()
        customPage.Visible = (CurrentPage == "custom")
        settingsPage.Visible = (CurrentPage == "settings")
        playerPage.Visible = (CurrentPage == "player")
        if CurrentPage == "player" then refreshList() end
        for page, btn in pairs(navButtons) do
            local active = (page == CurrentPage)
            glassLayers(btn, active)
            setGlassBase(btn, active and 0.8 or 1)
        end
    end

    updatePages()

    -- Popup tự bật với hiệu ứng mượt ngay sau intro
    task.delay(0.05, openMain)
end

-- Start
createIntro()
