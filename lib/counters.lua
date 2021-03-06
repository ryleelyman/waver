counters = {}

function counters.init()
    counters.ui = metro.init(counters.screenminder,1/15)
    counters.ui.frame = 1
    counters.ui.fps = 15
    counters.ui:start()

    counters.transport = metro.init(counters.sceneminder,1/15)
    counters.transport.frame = 1
    counters.transport:start()
end

function counters.screenminder()
    if counters.ui ~= nil and fn.playing() then
        counters.ui.frame = counters.ui.frame + 1
    end
    fn.dirty_screen(true)
end

function counters.sceneminder()
    if counters.transport ~= nil then
        counters.transport.frame = counters.transport.frame + 1
    end
    for _, track in ipairs(tracks) do
        if track.waiting_for_samples > 0 and callback_inactive then
            track:buffer_render()
            if not init_active then
                fn.dirty_scene(true)
            end
        end
    end
    if init_active then
        local finished = true
        for _, track in ipairs(tracks) do
            if track.waiting_for_samples > 0 then
                finished = false
            end
        end
        if finished then
            init_active = false
            fn.dirty_scene(true)
        end
    end
    if scratch_track.waiting_for_samples > 0 and callback_inactive then
        scratch_track:buffer_render()
        fn.dirty_scene(true)
    end
end

function counters.redraw_clock()
    while true do
        if fn.dirty_screen() and not selecting then
            redraw()
            fn.dirty_screen(false)
        end
        if fn.dirty_scene() then
            redraw_scene()
            if playhead > location then
                fn.dirty_scene(false)
            end
        end
        clock.sleep(1 / counters.ui.fps)
    end
end

return counters
