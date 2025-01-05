local bp_base_name = "Blueprint Brush"

local bp_format = "^" .. bp_base_name .. " %((%a+)%) %[(%d+)%]"

local bp_line_name = "Line"
local bp_corner_rh_name = "Right"
local bp_corner_lh_name = "Left"

local bb_kind = {
    line = 'line',
    corner_rh = 'corner_rh',
    corner_lh = 'corner_lh'
}

local bbkind_name_rev = {
    [bp_line_name] = bb_kind.line,
    [bp_corner_lh_name] = bb_kind.corner_lh,
    [bp_corner_rh_name] = bb_kind.corner_rh,
}

local bbkind_name = {
    [bb_kind.line] = bp_line_name,
    [bb_kind.corner_lh] = bp_corner_lh_name,
    [bb_kind.corner_rh] = bp_corner_rh_name,
}


--[[

example bb_settings table

bb_settings = {
    entity_name = 'transport-belt',
    width = 8,
    kind = 'line'
}

--]]

local function decode_bb_settings(bpstack)
    local label = bpstack.label
    local _, _, kind, width = string.find(label, bp_format);
    local bbs = {
        entity_name = bpstack.get_blueprint_entities()[1].name,
        width = tonumber(width),
        kind = bbkind_name_rev[kind],
    }
    if bpstack.get_blueprint_entities()[1].quality ~= nil then
        bbs.quality = bpstack.get_blueprint_entities()[1].quality
    else
        bbs.quality = nil
    end

    return bbs
end

local function write_label(bb_settings)
    return string.format(bp_base_name .. " (%s) [%d]", bbkind_name[bb_settings.kind], bb_settings.width)
end

local function is_blueprint_bb(label)
    if string.find(label, '^' .. bp_base_name) then
        return true
    else
        return false
    end
end

local function is_player_holding_bbbp(player)
    if player.cursor_stack.valid_for_read and player.cursor_stack.is_blueprint then
        if is_blueprint_bb(player.cursor_stack.label) then
            return true
        end
    end

    return false
end

local function isturn(x, y)
    return y <= x
end

local function genblueprintstring(blueprint_table)
    local json = helpers.table_to_json(blueprint_table)
    log(json)
    return '0'..helpers.encode_string(json)
end

local function generate_entity_bp(entity_name, number, position, direction, quality)
    local ebp = {
        entity_number = number,
        name = entity_name,
        position = position,
    }

    if direction ~= nil then
        ebp.direction = direction
    end

    log(quality)
    if quality ~= nil then
        ebp.quality = quality
    end

    return ebp
end

local function generate_entities_line(entity_name, width, quality)
    local tbl = {}
    for x = 1, width do
        table.insert(tbl, generate_entity_bp(entity_name, x, {
            x = x,
            y = 0
        }, nil, quality));
    end
    return tbl
end

local function generate_bp_entities(entities, icon_signal, label, quality)
    local signal_struct = {
        name = icon_signal
    }

    if quality ~= nil then
        signal_struct.quality = quality
    end

    return {
        blueprint = {
            icons = {
                {
                    signal = signal_struct,
                    index = 1
                }
            },
            entities = entities,
            item = 'blueprint',
            label = label,
            version = 562949955256321, -- i dont know if this is actually what I want here but I don't know what this is for and this is the same in all my blueprints
        }
    }
end

local function generate_line_brush_bp(entity_name, width, quality)
    return generate_bp_entities(generate_entities_line(entity_name, width, quality), entity_name, write_label({
        kind = bb_kind.line,
        width = width
    }), quality)
end

local function generate_corner_rh_brush_bp(entity_name, width, quality)
    local entities = {}
    for x = 1, width do
        for y = 1, width do
            if isturn(x, y) then
                table.insert(entities, generate_entity_bp(entity_name, (x - 1) * width + y, {
                    x = x,
                    y = y,
                }, defines.direction.east, quality))
            else
                table.insert(entities, generate_entity_bp(entity_name, (x - 1) * width + y, {
                    x = x,
                    y = y,
                }, nil, quality))
            end
        end
    end

    return generate_bp_entities(entities, entity_name, write_label({
        kind = bb_kind.corner_rh,
        width = width,
    }), quality)
end

local function generate_corner_lh_brush_bp(entity_name, width, quality)
    local entities = {}
    for x = 1, width do
        for y = 1, width do
            if isturn(1 + width - x, y) then
                table.insert(entities, generate_entity_bp(entity_name, (x - 1) * width + y, {
                    x = x,
                    y = y,
                }, defines.direction.west, quality))
            else
                table.insert(entities, generate_entity_bp(entity_name, (x - 1) * width + y, {
                    x = x,
                    y = y,
                }, nil, quality))
            end
        end
    end

    return generate_bp_entities(entities, entity_name, write_label({
        kind = bb_kind.corner_lh,
        width = width,
    }), quality)
end

local function set_player_cursor_bp(player, bptable)
    player.clear_cursor()
    local bpstr = genblueprintstring(bptable)
    player.cursor_stack.import_stack(bpstr)
    player.cursor_stack_temporary = true
end

local function is_player_holding_belt(player)
    return player.cursor_stack.valid_for_read and player.cursor_stack.prototype.place_result ~= nil and player.cursor_stack.prototype.place_result.type == 'transport-belt'
end

local function is_player_holding_belt_ghost(player)
    return player.cursor_ghost ~= nil and player.cursor_ghost.name.place_result ~= nil and player.cursor_ghost.name.place_result.type == 'transport-belt'
end

local function player_cycle_bp(player)
    if is_player_holding_bbbp(player) then
        local bb_settings = decode_bb_settings(player.cursor_stack)
        if bb_settings.kind == bb_kind.line then
            local bptable = generate_corner_rh_brush_bp(bb_settings.entity_name, bb_settings.width, bb_settings.quality)
            set_player_cursor_bp(player, bptable)
        elseif bb_settings.kind == bb_kind.corner_rh then
            local bptable = generate_corner_lh_brush_bp(bb_settings.entity_name, bb_settings.width, bb_settings.quality)
            set_player_cursor_bp(player, bptable)
        else
            local bptable = generate_line_brush_bp(bb_settings.entity_name, bb_settings.width, bb_settings.quality)
            set_player_cursor_bp(player, bptable)
        end
    end
end

local function player_cycle_down_beltbrush(player)
    if is_player_holding_bbbp(player) then
        local bb_settings = decode_bb_settings(player.cursor_stack)
        if bb_settings.width > 2 then
            if bb_settings.kind == bb_kind.line then
                set_player_cursor_bp(player, generate_line_brush_bp(bb_settings.entity_name, bb_settings.width - 1, bb_settings.quality))
            elseif bb_settings.kind == bb_kind.corner_lh then
                set_player_cursor_bp(player, generate_corner_lh_brush_bp(bb_settings.entity_name, bb_settings.width - 1, bb_settings.quality))
            else
                set_player_cursor_bp(player, generate_corner_rh_brush_bp(bb_settings.entity_name, bb_settings.width - 1, bb_settings.quality))
            end
        elseif bb_settings.width == 2 then -- become belt
            player.clear_cursor()
            player.cursor_stack_temporary = false
            player.pipette_entity(bb_settings.entity_name)
        else
            player.clear_cursor()
        end
    end
end

local function player_cycle_up_beltbrush(player)
    if is_player_holding_bbbp(player) then
        local bb_settings = decode_bb_settings(player.cursor_stack)
        if bb_settings.kind == bb_kind.line then
            set_player_cursor_bp(player, generate_line_brush_bp(bb_settings.entity_name, bb_settings.width + 1, bb_settings.quality))
        elseif bb_settings.kind == bb_kind.corner_lh then
            set_player_cursor_bp(player, generate_corner_lh_brush_bp(bb_settings.entity_name, bb_settings.width + 1, bb_settings.quality))
        else
            set_player_cursor_bp(player, generate_corner_rh_brush_bp(bb_settings.entity_name, bb_settings.width + 1, bb_settings.quality))
        end
    elseif is_player_holding_belt(player) then
        set_player_cursor_bp(player, generate_line_brush_bp(player.cursor_stack.prototype.place_result.name, 2, player.cursor_stack.quality.name))
    elseif is_player_holding_belt_ghost(player) then
        set_player_cursor_bp(player, generate_line_brush_bp(player.cursor_ghost.name.name, 2, player.cursor_ghost.quality.name))
    end
end

script.on_event("beltbrush-cycle-corners", function(event)
    player_cycle_bp(game.players[event.player_index])
end)

script.on_event("beltbrush-line-longer", function(event)
    player_cycle_up_beltbrush(game.players[event.player_index])
end)

script.on_event("beltbrush-line-shorter", function(event)
    player_cycle_down_beltbrush(game.players[event.player_index])
end)
