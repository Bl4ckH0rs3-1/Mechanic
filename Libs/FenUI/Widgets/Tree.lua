--------------------------------------------------------------------------------
-- FenUI - Tree Widget
--
-- A hierarchical tree view with selection support.
--------------------------------------------------------------------------------

local WidgetMixin = {}

function WidgetMixin:Init(config)
    self.config = config or {}
    self.nodes = {}
    self.pool = {}
    self.selectedNode = nil

    -- Use standard FenUI Layout as the base
    local layout = FenUI:CreateLayout(self, {
        background = "surfacePanel",
        border = "Inset",
        padding = 0,
    })
    layout:SetAllPoints()
    self.layout = layout

    -- Scroll Frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)
    self.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(content)
    self.content = content

    -- Sync width
    scrollFrame:SetScript("OnSizeChanged", function(_, w, h)
        content:SetWidth(w)
    end)

    if self.config.data then
        self:SetData(self.config.data)
    end
end

function WidgetMixin:GetNodeButton()
    local btn = table.remove(self.pool)
    if not btn then
        btn = CreateFrame("Button", nil, self.content)
        btn:SetHeight(20)
        btn:SetNormalFontObject("GameFontHighlightSmall")
        btn:SetHighlightTexture("Interface\\Buttons\\UI-ListItems-Highlight")
        btn:GetHighlightTexture():SetAlpha(0.2)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.text:SetPoint("LEFT", 4, 0)
        btn.text:SetPoint("RIGHT", -4, 0)
        btn.text:SetJustifyH("LEFT")

        btn:SetScript("OnClick", function()
            self:SelectNode(btn.nodeData)
        end)
    end
    btn:Show()
    return btn
end

function WidgetMixin:SetData(data)
    self:Clear()
    self.data = data
    self:Render()
end

function WidgetMixin:Clear()
    for _, btn in ipairs(self.nodes) do
        btn:Hide()
        table.insert(self.pool, btn)
    end
    wipe(self.nodes)
end

function WidgetMixin:Render()
    if not self.data then return end

    local yOffset = 0
    local function RenderLevel(items, level)
        for _, item in ipairs(items) do
            local btn = self:GetNodeButton()
            btn:SetPoint("TOPLEFT", level * 12, -yOffset)
            btn:SetPoint("TOPRIGHT", 0, -yOffset)
            
            local U = FenUI.Utils
            btn.text:SetText(U and U:SanitizeText(item.text) or (item.text == true and tostring(item.value) or item.text))
            btn.nodeData = item
            
            table.insert(self.nodes, btn)
            yOffset = yOffset + 20

            if item.children and #item.children > 0 then
                RenderLevel(item.children, level + 1)
            end
        end
    end

    RenderLevel(self.data, 0)
    self.content:SetHeight(yOffset)
end

function WidgetMixin:SelectNode(nodeData)
    self.selectedNode = nodeData
    if self.config.onSelect then
        self.config.onSelect(nodeData.value, nodeData)
    end
    
    -- Visual highlight
    for _, btn in ipairs(self.nodes) do
        if btn.nodeData == nodeData then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end
end

-- Factory function
function FenUI:CreateTree(parent, config)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(config.width or 200, config.height or 300)
    
    FenUI.Mixin(frame, WidgetMixin)
    frame:Init(config)
    
    return frame
end

