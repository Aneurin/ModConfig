ModConfig = {}

--[[
    Handling messages sent by this mod:

    function OnMsg.UIReady()
        Sent once the game's UI has loaded and is ready to query or modify.

    function OnMsg.ModConfigReady()
        Sent once ModConfig has finished loading and it's safe to start using.

    function OnMsg.ModConfigChanged(mod_id, option_id, value, old_value, token)
        Sent whenever any mod option is changed.
        The 'token' parameter matches the token given to ModConfig:Set(). The intention here is to
        make it easier for you to filter messages you shouldn't be responding to; if you set an
        option yourself you might want to pass in a token so that your handler can check for it and
        ignore the message.
--]]

-- Register a name and (optionally) a description for this mod. This is required for options to be
-- shown in the config dialog, but it's not required just to store data.
--
-- @param mod_id - The internal name of this mod
-- @param mod_name - The name of this mod as presented to the user. This may be a translatable tuple
--                   like T{12345, "Mod Name"}. If unset, defaults to mod_id.
-- @param mod_desc - The description for this mod as presented to the user.This may be a
--                   translatable tuple like T{12345, "Mod Description"}. If unset, defaults to an
--                   empty string.
function ModConfig:RegisterMod(mod_id, mod_name, mod_desc)
    mod_name = mod_name or mod_id
    mod_desc = mod_desc or ""
    if not self.registry then self.registry = {} end
    self.registry[mod_id] = {name = mod_name, desc = mod_desc}
end

-- Register a name and a description for a mod option. An option does not need to be registered in
-- order to use Get() and Set(), however only registered options will be included in the settings
-- dialog.
--
-- @param mod_id - The internal name of this mod
-- @param option_id - The internal name of this option. This does not need to be globally unique, so
--                    different mods can have options with the same name.
-- @param option_params - A table describing the parameter of this option. Keys are:
--                        name - The name of this option as presented to the user. This may be a
--                               translatable tuple like T{12345, "Option Name"}. If unset, defaults
--                               to option_id.
--                        desc - The description for this option as presented to the user.This may
--                               be a translatable tuple like T{12345, "Option Description"}. If
--                               unset, defaults to an empty string.
--                        order - The order in which the option will be shown. If unset, defaults to
--                                1. Options with the same order will be ordered alphabetically by
--                                name.
--                        type - The type of variable this option controls. Currently 'boolean',
--                               'enum', and 'number' are supported. In the future this is likely to
--                               be extended to other options such as an input slider. If unset,
--                               defaults to 'boolean'.
--                        values - When type is 'enum', this defines the possible values for the
--                                 option, and the label shown to the user.
--                                 Example: values = {
--                                                      {value = 1, label = "Option 1"},
--                                                      {value = "foo", label = T{12345, "Foo"}},
--                                                      {value = true, label = "Always"}
--                                                   }
--                        min, max - When type is 'number', these are used to set the minimum and
--                                   maximum allowed values. If unset, no limits are enforced.
--                        step - When type is 'number', this is used to set how much the value will
--                               change when clicking the +/- buttons. If unset, defaults to 1.
--                        default - The value to use if the user hasn't set the option.
function ModConfig:RegisterOption(mod_id, option_id, option_params)
    option_params = option_params or {}
    option_params.name = option_params.name or option_id
    option_params.order = option_params.order or 1
    if not option_params.default then
        -- It makes sense to have a built-in fallback default for booleans and numbers.
        if option_params.type == "boolean" then
            option_params.default = false
        elseif option_params.type == "number" then
            option_params.default = 0
        end
    end
    if not (self.registry and self.registry[mod_id]) then
        self:RegisterMod(mod_id)
    end
    local options = self.registry[mod_id].options or {}
    options[option_id] = option_params
    self.registry[mod_id].options = options
end

-- Set an option's value, then save. Sends the "ModConfigChanged" message when complete.
--
-- @param mod_id
-- @param option_id
-- @param value
-- @param token - An optional arbitrary variable you might want to pass in. The intention here is to
--                make it easier for you to filter messages you shouldn't be responding to; if you
--                set an option yourself you might want to pass in a token so that your
--                ModConfigChanged() handler can check for it and ignore the message.
--
-- @return The new value of the option
function ModConfig:Set(mod_id, option_id, value, token)
    local old_value = self:Get(mod_id, option_id)
    if value ~= old_value then
        if not self.data then self.data = {} end
        if not self.data[mod_id] then self.data[mod_id] = {} end
        self.data[mod_id][option_id] = value
        self:Save()
        Msg("ModConfigChanged", mod_id, option_id, value, old_value, token)
    end
    return value
end

-- Toggle a boolean value
--
-- @param mod_id
-- @param option_id
-- @param token - As per Set()
--
-- @return The new value if the option is a boolean, else nil
function ModConfig:Toggle(mod_id, option_id, token)
    local mod_options = self.registry and self.registry[mod_id] and self.registry[mod_id].options
    local option_params = mod_options and mod_options[option_id]
    if option_params and option_params.type and option_params.type == 'boolean' then
        return self:Set(mod_id, option_id, not self:Get(mod_id, option_id), token)
    else
        return nil
    end
end

-- Revert an option to its default value.
--
-- @param mod_id
-- @param option_id
-- @param token - As per Set()
--
-- @return The default setting of the option if defined, else nil
function ModConfig:Revert(mod_id, option_id, token)
    local default = self:GetDefault(mod_id, option_id)
    if default ~= nil then
        self:Set(mod_id, option_id, default, token)
    end
    return default
end

-- Get the default value of an option.
--
-- @param mod_id
-- @param option_id
--
-- @return The default setting of the option if defined, else nil
function ModConfig:GetDefault(mod_id, option_id)
    local mod_options = self.registry and self.registry[mod_id] and self.registry[mod_id].options
    return mod_options and mod_options[option_id] and mod_options[option_id].default
end

-- Get the current or default value of an option.
--
-- @param mod_id
-- @param option_id
--
-- @return The current setting of the option if set, else the default if defined, else nil
function ModConfig:Get(mod_id, option_id)
    local mod_data = self.data and self.data[mod_id]
    return mod_data and mod_data[option_id] or self:GetDefault(mod_id, option_id)
end

-- Load previously saved settings from disk.
function ModConfig:Load()
    local file_path = "AppData/ModConfig.data"
    local err, file_content = AsyncFileToString(file_path)
    if err then
        self.data = {}
    else
        err, data = LuaCodeToTuple(file_content)
        if not err then self.data = data end
    end
    if not self.registry then self.registry = {} end
end

-- Save all of the current settings to disk.
function ModConfig:Save()
    local file_path = "AppData/ModConfig.data"
    local mod_data = self.data or {}
    AsyncFileDelete(file_path..".bak")
    AsyncCopyFile(file_path, file_path..".bak")
    AsyncFileDelete(file_path)
    AsyncStringToFile(file_path, ValueToLuaCode(mod_data))
end

----------------------------------------------------------------------------------------------------
-- Nothing below this line constitutes part of this mod's API.

-- Randomly generated number to start counting from, to generate IDs for translatable strings
ModConfig.StringIdBase = 76827146

function ModConfig.ModDir()
    return debug.getinfo(2, "S").source:sub(2, -16)
end

function OnMsg.Autorun()
    ModConfig:Load()
    Msg("ModConfigReady")
end

function OnMsg.UIReady()
    local main_menu = XTemplates.XIGMenu
    local i, j, k = ModConfig.FindInMenu(main_menu, "idActionOpenModConfig")
    if i > 0 then
        -- Our action is already in there somewhere
        return
    end
    -- We want to put our menu entry after 'OPTIONS'
    i, j, k = ModConfig.FindInMenu(main_menu, "idOptions")
    local menu_entry = PlaceObj("XTemplateAction", {
        "ActionId", "idActionOpenModConfig",
        "ActionName", T{ModConfig.StringIdBase + 3, "MOD OPTIONS"},
        "ActionToolbar", "mainmenu",
        --"OnActionEffect", "mode",
        "OnAction", function(self, host)
            ModConfig.OpenDialog()
            host:Close()
        end
    })
    if k then
        table.insert(main_menu[i][j], k + 1, menu_entry)
    elseif j then
        table.insert(main_menu[i], j + 1, menu_entry)
    elseif i then
        table.insert(main_menu, i + 1, menu_entry)
    else
        -- There's something fishy here, but this is the right place at the moment for an unmodded
        -- game, so it makes the best fallback I can think of
        table.insert(main_menu[1][4], 6, menu_entry)
    end
end

-- Determine whether we need to show/hide the scroll bar when the UI scale changes
function OnMsg.SafeAreaMarginsChanged()
    local interface = GetInGameInterface()
    if interface.idModConfigDlg then
        interface.idModConfigDlg.idScroll:ShowHide()
    end
end

function ModConfig.FindInMenu(menu, id)
    local i, j, k
    for i in pairs(menu) do
        if type(menu[i]) == "table" then
            if menu[i].ActionId and menu[i].ActionId == id then
                return i, 0, 0
            end
            for j in pairs(menu[i]) do
                if type(menu[i][j]) == "table" then
                    if menu[i][j].ActionId and menu[i][j].ActionId == id then
                        return i, j, 0
                    end
                    for k in pairs(menu[i][j]) do
                        if type(menu[i][j][k]) == "table" and
                            menu[i][j][k].ActionId and menu[i][j][k].ActionId == id then
                            return i, j, k
                        end
                    end
                end
            end
        end
    end
    return 0, 0, 0
end

function ModConfig.CloseDialog()
    GetInGameInterface().idModConfigDlg:delete()
end

function ModConfig.OpenDialog()
    local interface = GetInGameInterface()
    if not interface.idModConfigDlg then
        ModConfig:CreateModConfigDialog()
    end
    interface.idModConfigDlg:SetVisible(true)
    -- In order for the scroll bar to know whether it needs to be shown, it needs to be able to
    -- compare its content size with its actual size, and those values aren't calculated until
    -- render time.
    CreateRealTimeThread(function()
        WaitMsg("OnRender")
        interface.idModConfigDlg.idScroll:ShowHide()
    end)
end

-- There are some parts of this mod that I think are good enough to be worth copying. This is not
-- one of those parts. This is an ugly mess that happens to work. Do not use this as an example of
-- the right way to create a dialogue box.
function ModConfig:CreateModConfigDialog()
    local interface = GetInGameInterface()
    if interface.idModConfigDlg then
        interface.idModConfigDlg:delete()
    end
    local this_mod_dir = ModConfig:ModDir()

    -- Create the base dialog
    local dlg = XDialog:new({
        Id = "idModConfigDlg",
        HAlign = "center",
        VAlign = "center",
        MinWidth = 400,
        MaxWidth = 800,
        MaxHeight = 800,
        Margins = box(0, 30, 0, 100),
        BorderColor = RGB(83, 129, 187),
        BorderWidth = 1,
        Padding = box(-2, 0, 0, 0),
        LayoutMethod = "VList",
        HandleMouse = true,
    }, interface)
    dlg:SetVisible(false)
    local win = XWindow:new({
        Dock = "box",
    }, dlg)
    XImage:new({
        Image = "UI/Infopanel/pad_2.tga",
        ImageFit = "stretch",
    }, win)
    XFrame:new({
        Image = this_mod_dir.."UI/watermark_tilable.tga",
        TileFrame = true,
    }, win)

    -- Add the title
    local title = XFrame:new({
        Image = "UI/Infopanel/title.tga",
        Margins = box(2, 0, 2, 2),
    }, dlg)
    XText:new({
        Margins = box(0, 0, 0, 0),
        Padding = box(2, 8, 2, 8),
        HAlign = "stretch",
        VAlign = "center",
        TextHAlign = "center",
        TextFont = "InfopanelTitle",
        TextColor = RGB(244, 228, 117),
        RolloverTextColor = RGB(244, 228, 117),
        Translate = true
    }, title):SetText(T{ModConfig.StringIdBase, "Mod Options"})

    -- Create a container to house a scrollable area (in case the options don't all fit on one
    -- screen) and its associated scrollbar. These two elements need to be siblings to work
    -- correctly, and the scrollbar will fill the height of its container, which is why they need
    -- this wrapper.
    local scroll_container = XWindow:new({
    }, dlg)
    local content = XContentTemplateScrollArea:new({
        Id = "idList",
        LayoutMethod = "VList",
        Background = RGBA(0, 0, 0, 0),
        FocusedBackground = RGBA(0, 0, 0, 0),
        RolloverBackground = RGBA(0, 0, 0, 0),
        Padding = box(0, 0, 0, 0),
        Margins = box(0, -2, 0, 45),
        VScroll = "idScroll",
    }, scroll_container)

    -- Intro text
    if self.registry and next(self.registry) ~= nil then
        XText:new({
            Padding = box(5, 2, 5, 2),
            VAlign = "center",
            TextAlign = "center",
            --TextFont = "InfopanelText",
            TextColor = RGB(233, 242, 255),
            RolloverTextColor = RGB(233, 242, 255),
            Translate = true
        }, content):SetText(T{ModConfig.StringIdBase + 1,
                "Mouse over options to see a description of what they mean."})
    end

    -- The options themselves
    self:AddAllModSettingsToDialog(content)
    XScrollBar:new({
        Id = "idScroll",
        Dock = "right",
        BorderWidth = 0,
        Background = RGBA(0, 20, 40, 100),
        ScrollColor = RGBA(83, 129, 187, 127),
        BorderColor = RGB(83, 129, 187),
        Margins = box(0, -2, 0, 45),
        MinWidth = 20,
        MaxWidth = 20,
        Horizontal = false,
        Target = "idList",
        ShowHide = function(self) self:SetVisible(self.Max > self.PageSize) end
    }, scroll_container)

    -- All the rest is creating the close button
    local close_button = XTextButton:new({
        Id = "idCloseButton",
        Dock = "bottom",
        Margins = box(-25, 0, 0, -1),
        Padding = box(25, 0, 0, 0),
        MaxHeight = 45,
        Background = RGBA(0, 0, 0, 0),
        FocusedBackground = RGBA(0, 0, 0, 0),
        RolloverBackground = RGBA(0, 0, 0, 0),
        PressedBackground = RGBA(0, 0, 0, 0),
        MouseCursor = "UI/Cursors/Rollover.tga",
        RelativeFocusOrder = "new-line",
        HandleMouse = true,
        FXMouseIn = "PopupChoiceHover",
        FXPress = "PopupChoiceClick",
        OnSetRollover = function(self, rollover)
            CreateRealTimeThread(function()
                if self.window_state ~= "destroying" then
                    self.rollover = rollover
                    self.idCloseButtonIcon:SetRollover(rollover)
                    self.idRollover2:SetVisible(rollover)
                    local b = self.idRollover2.box
                    self.idRollover2:AddInterpolation({
                        type = const.intRect,
                        duration = self.idRollover2:GetFadeInTime(),
                        startRect = b,
                        endRect = sizebox(b:minx(), b:miny(), 40, b:sizey()),
                        flags = const.intfInverse,
                        autoremove = true
                    })
                end
            end)
        end,
    }, dlg)
    close_button.OnPress = ModConfig.CloseDialog
    XImage:new({
        Id = "idRollover2",
        ZOrder = 0,
        Margins = box(0, 0, 0, -6),
        Dock = "box",
        FadeInTime = 150,
        Image = "UI/Common/message_choice_shine.tga",
        ImageFit = "stretch",
    }, close_button):SetVisible(false)
    local button_icon = XImage:new({
        Id = "idCloseButtonIcon",
        ZOrder = 2,
        Margins = box(-25, 0, 0, 0),
        Shape = "InHHex",
        Dock = "left",
        MinWidth = 50,
        MinHeight = 43,
        MaxWidth = 50,
        MaxHeight = 43,
        Image = "UI/Icons/message_ok.tga",
        ImageFit = "smallest",
    }, close_button)
    XImage:new({
        Id = "idRollover",
        Margins = box(-3, -3, -3, -3),
        Dock = "box",
        Image = "UI/Common/Hex_small_shine_2.tga",
        ImageFit = "smallest",
    }, button_icon):SetVisible(false)
    XText:new({
        Padding = box(10, 0, 2, 0),
        HAlign = "left",
        VAlign = "center",
        TextFont = "HexChoice",
        TextColor = RGB(254, 237, 122),
        RolloverTextColor = RGB(255, 255, 255),
        Translate = true,
        CalcTextColor = function(self)
            return self.parent.rollover and self.RolloverTextColor or self.TextColor
        end,
    }, close_button):SetText(T{1011, "Close"})
end

function ModConfig:AddAllModSettingsToDialog(parent)
    if not self.registry or next(self.registry) == nil then
        XText:new({
            Margins = box(0, 0, 0, 0),
            Padding = box(8, 2, 2, 8),
            HAlign = "center",
            TextColor = RGB(255, 255, 255),
            RolloverTextColor = RGB(255, 255, 255),
            Background = RGBA(0, 0, 0, 0),
            Translate = true
        }, parent):SetText(T{ModConfig.StringIdBase + 2,
            "There are no mods currently active which use this settings dialogue."})
    else
        local sortable = {}
        for mod_id, mod_registry in pairs(self.registry) do
            sortable[#sortable + 1] = {id = mod_id, name = mod_registry.name}
        end
        TSort(sortable, "name")
        for _, id_and_name in ipairs(sortable) do
            ModConfig:AddModSettingsToDialog(parent, id_and_name.id, self.registry[id_and_name.id])
        end
    end
end

function ModConfig:AddModSettingsToDialog(parent, mod_id, mod_registry)
    local mod_name = mod_registry.name
    local mod_desc = mod_registry.desc
    local section_header = XFrame:new({
        Image = "UI/Infopanel/section.tga",
        Margins = box(2, 0, 2, 2),
        RolloverTemplate = "Rollover",
        RolloverAnchor = "bottom",
        RolloverTextColor = RGB(244, 228, 117),
    }, parent)
    XText:new({
        Margins = box(0, 0, 0, 0),
        Padding = box(2, 8, 2, 8),
        VAlign = "center",
        TextHAlign = "center",
        TextFont = "InfopanelTitle",
        TextColor = RGB(244, 228, 117),
        RolloverTextColor = RGB(244, 228, 117),
        Translate = true
    }, section_header):SetText(mod_name)
    if mod_desc and mod_desc ~= "" then
        section_header:SetRolloverTitle(mod_name)
        section_header:SetRolloverText(mod_desc)
    end
    local sortable = {}
    for option_id, option_params in pairs(mod_registry.options) do
        sortable[#sortable + 1] = {
            id = option_id,
            name = option_params.name,
            order = option_params.order
        }
    end
    -- TSort() appears to be a stable sort, so to sort by "order, name" we can sort by name and then
    -- resort the result by order.
    TSort(sortable, "name")
    TSort(sortable, "order")
    for _, sorted_option_params in ipairs(sortable) do
        local option_id = sorted_option_params.id
        local option_params = mod_registry.options[option_id]
        local option_section = XFrame:new({
            LayoutMethod = "Grid",
            Margins = box(2, 2, 2, 2),
            Background = RGBA(0, 0, 0, 0),
            RolloverTemplate = "Rollover",
            RolloverAnchor = "bottom",
            RolloverTextColor = RGB(244, 228, 117),
        }, parent)
        if option_params.desc and option_params.desc ~= "" then
            option_section:SetRolloverTitle(T{option_params.name, UICity})
            option_section:SetRolloverText(T{option_params.desc, UICity})
        end
        XText:new({
            Id = "idLabel",
            Margins = box(0, 0, 0, 0),
            Padding = box(8, 2, 2, 2),
            VAlign = "center",
            TextHAlign = "left",
            TextColor = RGB(255, 255, 255),
            RolloverTextColor = RGB(255, 255, 255),
            Background = RGBA(0, 0, 0, 0),
            Translate = true
        }, option_section):SetText(option_params.name)
        ModConfig:AddOptionControl(option_section, mod_id, option_id)
    end
end

DefineClass.XModConfigToggleButton = {
    __parents = {
        "XToggleButton"
    },
    properties = {
        {
            category = "Image",
            id = "DisabledImage",
            editor = "text",
            default = "UI/Icons/traits_approve_disable.tga",
        },
        {
            category = "Image",
            id = "EnabledImage",
            editor = "text",
            default = "UI/Icons/traits_approve.tga",
        },
        {
            category = "Params",
            id = "ModId",
            editor = "text",
            default = "",
        },
        {
            category = "Params",
            id = "OptionId",
            editor = "text",
            default = "",
        },
    },
    HAlign = "right",
    VAlign = "center",
    Background = RGBA(0, 0, 0, 0),
    RolloverBackground = RGBA(0, 0, 0, 0),
    PressedBackground = RGBA(0, 0, 0, 0),
    MouseCursor = "UI/Cursors/Rollover.tga",
}
function XModConfigToggleButton:Init()
    self.idIcon.ImageFit = "height"
    self:SetToggled(ModConfig:Get(self.ModId, self.OptionId))
end
function XModConfigToggleButton:OnChange(toggled)
    self.idIcon:SetImage(toggled and self.EnabledImage or self.DisabledImage)
    ModConfig:Set(self.ModId, self.OptionId, toggled)
end


DefineClass.XModConfigEnum = {
    __parents = {
        "XPageScroll",
    },
    properties = {
        {
            category = "Params",
            id = "ModId",
            editor = "text",
            default = "",
        },
        {
            category = "Params",
            id = "OptionId",
            editor = "text",
            default = "",
        },
        {
            category = "Params",
            id = "OptionValues",
            editor = "table",
            default = {},
        },
    },
    visible = true,
}

function XModConfigEnum:Init()
    self.parent.idLabel:SetMargins(box(0, 0, self.MinWidth, 0))
    local current_value = ModConfig:Get(self.ModId, self.OptionId)
    local value_index = 1
    for i, option in ipairs(self.OptionValues) do
        if option.value == current_value then
            value_index = i
            break
        end
    end
    self:SetPage(value_index, false)
end

function XModConfigEnum:SetPage(page, update)
    if update == nil then update = true end
    self.current_page = page
    self.idPage:SetText(self.OptionValues[page].label)
    if update then
        ModConfig:Set(self.ModId, self.OptionId, self.OptionValues[page].value)
    end
end

function XModConfigEnum:NextPage()
    local next_page = self.current_page + 1
    if next_page > #self.OptionValues then
        next_page = 1
    end
    self:SetPage(next_page)
end

function XModConfigEnum:PreviousPage()
    local next_page = self.current_page - 1
    if next_page < 1 then
        next_page = #self.OptionValues
    end
    self:SetPage(next_page)
end

DefineClass.XModConfigNumberInput = {
    __parents = {
        "XWindow",
    },
    properties = {
        {
            category = "Params",
            id = "ModId",
            editor = "text",
            default = "",
        },
        {
            category = "Params",
            id = "OptionId",
            editor = "text",
            default = "",
        },
        {
            category = "Params",
            id = "OptionName",
            editor = "text",
            default = "",
        },
        {
            category = "Params",
            id = "Min",
            editor = "number",
            default = nil,
        },
        {
            category = "Params",
            id = "Max",
            editor = "number",
            default = nil,
        },
        {
            category = "Params",
            id = "Step",
            editor = "number",
            default = 1,
        },
    },
    HAlign = "right",
    LayoutMethod = "HList",
}

function XModConfigNumberInput:Init()
    self.idRemove = XTextButton:new({
        Id = "idRemove",
        HAlign = "left",
        VAlign = "center",
        MouseCursor = "UI/Cursors/Rollover.tga",
        FXMouseIn = "RocketRemoveCargoHover",
        RepeatStart = 300,
        RepeatInterval = 150,
        OnPress =  function(self) self.parent:Remove() end,
        Image = "UI/Infopanel/arrow_remove.tga",
        ColumnsUse = "abcc",
        RolloverTemplate = "Rollover",
    }, self)
    self.idAmount = XText:new({
        Id = "idAmount",
        Padding = box(2, 2, 5, 2),
        HAlign = "right",
        VAlign = "center",
        MinWidth = 60,
        MaxWidth = 70,
        TextFont = "PGResource",
        TextColor = RGBA(255, 248, 233, 255),
        RolloverTextColor = RGBA(255, 255, 255, 255),
        WordWrap = false,
        TextHAlign = "right",
        TextVAlign = "center",
    }, self)
    self.idAdd = XTextButton:new({
        Id = "idAdd",
        HAlign = "right",
        VAlign = "center",
        MouseCursor = "UI/Cursors/Rollover.tga",
        FXMouseIn = "RocketRemoveCargoHover",
        RepeatStart = 300,
        RepeatInterval = 300,
        OnPress =  function(self) self.parent:Add() end,
        Image = "UI/Infopanel/arrow_add.tga",
        ColumnsUse = "abcc",
        RolloverTemplate = "Rollover",
    }, self)
    local AddRemoveRolloverHint = T{
        ModConfig.StringIdBase + 4,
        "<em><click></em> x<step><newline>"..
        "<em><shift> + <click></em> x<step10><newline>"..
        "<em><control> + <click></em> x<step100>",
        click = "<image "..MouseButtonImagesInText.MouseL..">",
        shift = ShortcutKeysToText({VKStrNames[const.vkShift]}),
        control = ShortcutKeysToText({VKStrNames[const.vkControl]}),
        step = self.Step,
        step10 = self.Step * 10,
        step100 = self.Step * 100,
    }
    self.idRemove:SetRolloverTitle(self.OptionName)
    self.idAdd:SetRolloverTitle(self.OptionName)
    self.idRemove:SetRolloverText(self.OptionDesc or T{
        ModConfig.StringIdBase + 5,
        "<center>Decrease"
    })
    self.idAdd:SetRolloverText(self.OptionDesc or T{
        ModConfig.StringIdBase + 6,
        "<center>Increase"
    })
    self.idRemove:SetRolloverHint(AddRemoveRolloverHint)
    self.idAdd:SetRolloverHint(AddRemoveRolloverHint)
    self:Set(ModConfig:Get(self.ModId, self.OptionId))
end

function XModConfigNumberInput:Set(value)
    if type(value) ~= "number" then value = 0 end
    if self.Min ~= nil and value < self.Min then
        value = self.Min
    elseif self.Max ~= nil and value > self.Max then
        value = self.Max
    end
    self.current_value = value
    if value == self.Min then
        self.idRemove:SetVisible(false)
    else
        self.idRemove:SetVisible(true)
    end
    if value == self.Max then
        self.idAdd:SetVisible(false)
    else
        self.idAdd:SetVisible(true)
    end
    self.idAmount:SetText(LocaleInt(self.current_value))
    ModConfig:Set(self.ModId, self.OptionId, value)
end

function XModConfigNumberInput:Remove()
    local step = self.Step
    if terminal.IsKeyPressed(const.vkShift) then
        step = step * 10
    elseif terminal.IsKeyPressed(const.vkControl) then
        step = step * 100
    end
    self:Set(self.current_value - step)
end

function XModConfigNumberInput:Add()
    local step = self.Step
    if terminal.IsKeyPressed(const.vkShift) then
        step = step * 10
    elseif terminal.IsKeyPressed(const.vkControl) then
        step = step * 100
    end
    self:Set(self.current_value + step)
end


function ModConfig:AddOptionControl(parent, mod_id, option_id)
    local option_params = self.registry[mod_id].options[option_id]

    if not option_params.type then
        option_params.type = 'boolean'
    end
    if option_params.type == 'boolean' then
        XModConfigToggleButton:new({
            Id = option_id,
            ModId = mod_id,
            OptionId = option_id,
            MaxHeight = 35,
        }, parent)
    elseif option_params.type == 'enum' then
        XModConfigEnum:new({
            Id = option_id,
            ModId = mod_id,
            OptionId = option_id,
            OptionValues = option_params.values,
            MaxHeight = 35,
        }, parent)
    elseif option_params.type == 'number' then
        XModConfigNumberInput:new({
            Id = option_id,
            ModId = mod_id,
            OptionId = option_id,
            OptionName = option_params.name,
            OptionDesc = option_params.desc,
            Max = option_params.max,
            Min = option_params.min,
            Step = option_params.step or 1,
            MaxHeight = 35,
        }, parent)
    end
end

----------------------------------------------------------------------------------------------------

-- The following three functions are intended to simplify the job of knowing when it's safe to start
-- inserting new items into the UI, by firing a "UIReady" message. They use the "g_UIReady" global
-- to record when this message has been sent, in order to make it possible to include the same code
-- in multiple mods without ending up with the message sent multiple times.
if _G.g_UIReady == nil then
    -- Check _G explicitly, to avoid the "Attempt to use an undefined global 'g_UIReady'" error
    g_UIReady = false
end
function OnMsg.LoadGame()
    if not g_UIReady then
        -- This seems a little ridiculous, but it's the only way I've found to
        -- trigger when the UI is ready after loading a game
        CreateGameTimeThread(function()
            while true do
                WaitMsg("OnRender")
                if GetXDialog("HUD") then
                    if not g_UIReady then
                        g_UIReady = true
                        Msg("UIReady")
                    end
                    break
                end
            end
        end)
    end
end
function OnMsg.NewMapLoaded()
    if not g_UIReady then
        g_UIReady = true
        Msg("UIReady")
    end
end
-- If we change maps (via loading or returning to the main menu and stating a new game) then the UI
-- will be rebuilt, so we need to allow UIReady to fire again when the time comes.
function OnMsg.DoneMap()
    g_UIReady = false
end
