parameters = {}

function parameters.init()
    params:add_separator(" ~ w a v e r ~ ")

    params:add_trigger("save", "save track")
    params:set_action("save", function(_)
        textentry.enter(tracks.save, "song", "filename")
    end)

    params:add {
        type = "number",
        id   = "tempo",
        name = "tempo",
        min  = 20,
        max  = 400,
        default = 120,
        action = function(_) fn.dirty_screen(true) end,
    }

    params:add {
        type = "number",
        id   = "beats",
        name = "beats per bar",
        min  = 1,
        max  = 16,
        default = 4,
        action = function(_) fn.dirty_screen(true) end,
    }

    params:add_separator(" ! w a r n i n g ! ")

    params:add_trigger("clearall", "clear all tracks")
    params:set_action("clearall", function(_)
        tracks.clear_all()
    end)
end

return parameters
