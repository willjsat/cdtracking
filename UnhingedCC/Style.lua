local _, U = ...
local S = {}; U.Style = S
S.texture = 'Interface\\Buttons\\WHITE8X8'
S.bg = {.065,.058,.047,1}
S.panel = {.095,.090,.080,1}
S.border = {.23,.23,.22,1}
S.accent = {.55,.48,.28,1}
S.gold = {1,.82,0,1}
S.text = {.94,.92,.87,1}
S.muted = {.58,.56,.51,1}
S.header = {.035,.032,.027,1}
S.sidebar = {.075,.070,.062,1}
S.section = {.13,.115,.085,1}
S.selected = {.19,.19,.18,1}
S.tableHeader = {.16,.16,.15,1}
S.tableText = {1,.98,.92,1}
S.borders, S.fonts = {}, {}
local pixelToUI=1
function S.Pixel(f)
    -- Blizzard's PixelUtil uses 768 / physical screen height, not one UI unit.
    if GetPhysicalScreenSize then
        local _,height=GetPhysicalScreenSize()
        if height and height>0 then pixelToUI=768/height end
    end
    return pixelToUI/f:GetEffectiveScale()
end
function S.Fill(f,color)
    f:SetBackdrop({bgFile=S.texture})
    f:SetBackdropColor(unpack(color or S.panel))
    S.borders[f]=nil
    if f.borderLines then for _,line in ipairs(f.borderLines) do line:Hide() end end
end
local function sizeBorder(f)
    local lines,p=f.borderLines,S.Pixel(f)
    lines[1]:SetHeight(p); lines[2]:SetHeight(p)
    lines[3]:SetWidth(p); lines[4]:SetWidth(p)
end
function S.Border(f,color)
    if not f.borderLines then
        f.borderLines={}
        for i=1,4 do
            local line=f:CreateTexture(nil,'OVERLAY'); line:SetSnapToPixelGrid(true); line:SetTexelSnappingBias(0); f.borderLines[i]=line
        end
        local lines=f.borderLines
        lines[1]:SetPoint('TOPLEFT'); lines[1]:SetPoint('TOPRIGHT')
        lines[2]:SetPoint('BOTTOMLEFT'); lines[2]:SetPoint('BOTTOMRIGHT')
        lines[3]:SetPoint('TOPLEFT'); lines[3]:SetPoint('BOTTOMLEFT')
        lines[4]:SetPoint('TOPRIGHT'); lines[4]:SetPoint('BOTTOMRIGHT')
    end
    S.borders[f]=true; f.lineColor=color or S.border
    sizeBorder(f)
    for _,line in ipairs(f.borderLines) do line:SetColorTexture(unpack(f.lineColor)); line:Show() end
end
function S.Panel(f,color,border) S.Fill(f,color); S.Border(f,border) end
function S.RefreshBorders() for f in pairs(S.borders) do sizeBorder(f) end end
function S.Font(region,fallback,title)
    fallback=fallback or 'GameFontHighlightSmall'
    title=not not (title or fallback:find('Large') or fallback:find('Huge'))
    local previous=S.fonts[region]
    local source=_G[fallback] or GameFontNormal
    region:SetFontObject(_G[fallback] or fallback)
    local basePath,baseSize,flags
    -- SetFontObject can retain a widget's local SetFont overrides. Read the
    -- shared FontObject, never the already-enlarged widget, on redraw.
    if source and source.GetFont then
        basePath,baseSize,flags=source:GetFont()
    elseif previous and previous.fallback==fallback then
        basePath,baseSize,flags=previous.basePath,previous.baseSize,previous.flags
    else
        basePath,baseSize,flags=region:GetFont()
    end
    S.fonts[region]={fallback=fallback,title=title,basePath=basePath,baseSize=baseSize,flags=flags}
    local size=(baseSize or 11)+(title and 0 or 2)
    local path
    if EllesmereUI and type(EllesmereUI.GetFontPath)=='function' then
        local ok,value=pcall(EllesmereUI.GetFontPath)
        if ok and type(value)=='string' and value~='' then path=value end
    end
    if not path and GameFontNormal and GameFontNormal.GetFont then path=GameFontNormal:GetFont() end
    if not path then path=STANDARD_TEXT_FONT or basePath end
    if type(path)=='string' and path~='' then
        local ok,result=pcall(region.SetFont,region,path,size,flags or '')
        if not ok or result==false then
            region:SetFontObject(_G[fallback] or fallback)
            if basePath then pcall(region.SetFont,region,basePath,size,flags or '') end
        end
    end
end
function S.RefreshFonts()
    for region,font in pairs(S.fonts) do S.Font(region,font.fallback,font.title) end
end
function S.Button(f)
    S.Panel(f)
    if not f.caption then
        f.caption=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
        f.caption:SetPoint('CENTER'); f:SetFontString(f.caption)
    end
    S.Font(f.caption); f.caption:SetTextColor(unpack(S.text))
    f:SetScript('OnEnter',function(self) S.Panel(self,{.15,.14,.12,1},S.accent); self.caption:SetTextColor(unpack(S.gold)) end)
    f:SetScript('OnLeave',function(self) S.Panel(self,self.selected and S.selected or nil,S.border); self.caption:SetTextColor(unpack(S.text)) end)
end
function S.Input(f)
    S.Panel(f,{.025,.024,.021,1}); S.Font(f); f:SetTextInsets(8,8,0,0)
end
function S.Scroll(parent)
    local f=CreateFrame('ScrollFrame',nil,parent)
    f:EnableMouseWheel(true)
    f:SetScript('OnMouseWheel',function(self,delta)
        self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*42)))
    end)
    return f
end
function S.TitleBar(owner,text)
    owner:SetMovable(true)
    local bar=CreateFrame('Frame',nil,owner,'BackdropTemplate')
    bar:SetPoint('TOPLEFT'); bar:SetSize(owner:GetWidth(),30); S.Fill(bar,S.header)
    bar:EnableMouse(true); bar:RegisterForDrag('LeftButton')
    bar:SetScript('OnDragStart',function() owner:StartMoving() end)
    bar:SetScript('OnDragStop',function() owner:StopMovingOrSizing() end)
    bar.title=bar:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); S.Font(bar.title,nil,true)
    bar.title:SetPoint('CENTER'); bar.title:SetTextColor(unpack(S.gold)); bar.title:SetText(text)
    local close=CreateFrame('Button',nil,bar,'BackdropTemplate'); close:SetSize(40,30); close:SetPoint('TOPRIGHT')
    S.Button(close); close:SetText('X'); S.Fill(close,{.55,.08,.13,1})
    close:SetScript('OnEnter',function(self) S.Fill(self,{.8,.12,.18,1}) end)
    close:SetScript('OnLeave',function(self) S.Fill(self,{.55,.08,.13,1}) end)
    close:SetScript('OnClick',function() owner:Hide() end)
    bar.close=close; owner.titleBar=bar
    return bar
end
