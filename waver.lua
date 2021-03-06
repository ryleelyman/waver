-- waver
--
-- assemble tracks from TAPE
-- into a song.
--
-- @alanza llllllll.co/t/waver
-- v0.2.5
--    ▼ instructions below ▼
--
-- E1 scrolls the window
-- E2 zooms in and out
-- E3 selects the active track
-- K1 + E1 scrolls playhead
-- K1 + E2 scrolls loop start
-- K1 + E3 scrolls loop end
-- K2 toggles playback
-- K3 toggles looping
--
-- SONG VIEW
-- long K1 saves track
-- K1 + K3 enters track view
-- K1 + K2 "undo" to track view
--
-- TRACK VIEW
-- long K1 loads sample
-- long K2 cuts at loop marker
-- long K3 pastes at playhead
-- K2 + E2 adjusts level
-- K2 + E3 adjusts pan
-- K1 + K2 "discard" to song view
-- K1 + K3 "commit" to song view
-- K1 + K2 + K3 arm recording

include("waver/lib/includes")

function init()
    init_active = true
    loop_start = 0
    loop_end = 30
    active_page = 0
    rec_armed = false
    scene.init()
    num_tracks = 4
    parameters.init()
    track_length = 5*60
    fn.init()
    active_track, active_scratch_track = 1, false
    page.init()
    tracks.init()
    counters.init()
    redraw_clock_id = clock.run(counters.redraw_clock)
    keys, key_counter = {0,0,0}, {{}, {}, {}}
    ignore_k2_off, ignore_k3_off = false, false
    selecting = false
    last_active, last_level = 1, 1
end

function enc(n,d)
    if init_active then return end
    if n == 1 then
        if keys[1] == 1 then
            -- cancel long press counter for K1
            if key_counter[1] then
                clock.cancel(key_counter[1])
            end
            -- K1 + E1 scrolls playhead
            local value = playhead + (window_length*d)/32
            local min = 0
            local max = track_length
            playhead = util.clamp(value, min, max)
            for i = 1, 2 do
                if not fn.playing() then
                    softcut.play(i, 1)
                end
                softcut.position(i, playhead)
                if not fn.playing() then
                    softcut.play(i, 0)
                end
            end
            fn.dirty_screen(true)
        elseif keys[1] == 0 then
            -- E1 scrolls window
            local value = window_start + (window_length*d)/64
            local min = 0
            local max = track_length - window_length
            window_start = util.clamp(value, min, max)
            fn.dirty_screen(true)
        end
    elseif n == 2 then
        if keys[1] == 1 then
            -- cancel long press counter for K1
            if key_counter[1] then
                clock.cancel(key_counter[1])
            end
            -- K1 + E2 scrolls loop marker start
            local value = loop_start + (window_length*d/64)
            local min = 0
            local max = loop_end
            loop_start = util.clamp(value, min, max)
            fn.dirty_screen(true)
        elseif keys[2] == 1 then
            -- cancel long press counter for K2
            if key_counter[2] then
                clock.cancel(key_counter[2])
            end
            if active_page == 1 then
                -- Track View K2 + E2 adjusts track level
                ignore_k2_off = true
                if not fn.scratch_track_active() then
                    params:delta("track_level_" .. fn.active_track(), d)
                else
                    params:delta("scratch_level", d)
                end
            end
        else
            -- E2 zooms in and out
            local value = window_length - 0.1*window_length*d
            local min = 1
            local max = track_length
            window_length = util.clamp(value, min, max)
            min = 0
            max = track_length - window_length
            window_start = util.clamp(window_start, min, max)
            fn.dirty_screen(true)
        end
    elseif n == 3 then
        if keys[1] == 1 then
            -- cancel long press counter for K1
            if key_counter[1] then
                clock.cancel(key_counter[1])
            end
            -- K1 + K3 scrolls loop end
            local value = loop_end + (window_length*d)/64
            local min = loop_start
            local max = track_length
            loop_end = util.clamp(value, min, max)
            fn.dirty_screen(true)
        elseif keys[2] == 1 then
            -- cancel long press counter for K2
            if key_counter[2] then
                clock.cancel(key_counter[2])
            end
            if active_page == 1 then
                -- Track View K2 + E3 adjusts track pan
                ignore_k2_off = true
                params:delta("track_pan_" .. fn.active_track(), d)
                for i = 1, 2 do
                    softcut.pan(i, tracks[fn.active_track()].pan)
                end
                scratch_track.pan = tracks[fn.active_track()].pan
            end
        else
            if active_page == 1 then
                -- Track View E3 scrolls between the active track and scratch track
                local value = (fn.scratch_track_active() and 1 or 0) + d
                local min = 0
                local max = 1
                fn.scratch_track_active(util.clamp(value, min, max) == 1)
                fn.dirty_screen(true)
            elseif active_page == 0 then
                -- Song view E3 scrolls active track
                local value = fn.active_track() + d
                local min = 1
                local max = num_tracks
                fn.active_track(util.clamp(value,min,max))
                fn.dirty_screen(true)
            end
        end
    end
end

function key(n,z)
    if init_active then return end
    keys[n] = z
    if z == 1 then
        -- start long-press counter
        key_counter[n] = clock.run(long_press, n)
    elseif z == 0 then -- detect short press
        if key_counter[n] then
            clock.cancel(key_counter[n])
        end
        if n == 2 then
            if ignore_k2_off then
                ignore_k2_off = false
            elseif keys[1] == 1 then
                -- stop long press counter for K1
                if key_counter[1] then
                    clock.cancel(key_counter[1])
                end
                if active_page == 1 then
                    -- Track View K1 + K2 exits to song view, discarding changes
                    scratch_track:reset()
                    active_page = 0
                elseif active_page == 0 then
                    -- Song View K1 + K2 enters track view as "undo"
                    scratch_track:undo()
                    active_page = 1
                    fn.dirty_scene(true)
                end
            elseif keys[1] == 0 then
                -- short K2 toggles playback
                fn.toggle_playback()
                if not fn.playing() then fn.dirty_scene(true) end
            end
        elseif n == 3 then
            if ignore_k3_off then
                ignore_k3_off = false
            elseif keys[1] == 1 then
                -- stop long press counter for K1
                if key_counter[1] then
                    clock.cancel(key_counter[1])
                end
                if active_page == 1 then
                    if keys[2] == 1 then
                        -- stop long press counter for K2
                        if key_counter[2] then
                            clock.cancel(key_counter[2])
                        end
                        -- Track View K1 + K2 + K3 arms recording
                        ignore_k2_off = true
                        scene:record_arm(true)
                    else
                        -- Track View K1 + K3 exits to song view, saving changes
                        scratch_track:commit()
                        active_page = 0
                        fn.dirty_scene(true)
                    end
                elseif active_page == 0 then
                    -- Song View K1 + K3 enters track view
                    scratch_track:reset()
                    active_page = 1
                end
            elseif keys[1] == 0 then
                -- short K3 toggles looping
                if fn.looping() then
                    fn.looping(false)
                else 
                    fn.looping(true)
                end
            end
        end
    end
end

function long_press(n)
    -- a second is a long press
    clock.sleep(1)
    key_counter[n] = nil
    if n == 1 then
        if active_page == 0 then
            -- Song View Long K1 enters menu
            keys[1] = 0
            fn.playing(false)
            selecting = true
            textentry.enter(tracks.save, "song", "filename")
        elseif active_page == 1 then
            -- Track View Long K1 loads sample.
            keys[1] = 0
            fileselect.enter(_path.dust, function(file)
                scratch_track:load(file)
                selecting = false
            end)
            selecting = true
        end
    elseif n == 2 then
        if active_page == 1 then
            scratch_track:cut()
            ignore_k2_off = true
        end
    elseif n == 3 then
        if active_page == 1 then
            scratch_track:paste()
            ignore_k3_off = true
        end
    end
end

function redraw()
    if not fn.dirty_screen() then return end
    page:render()
    fn.dirty_screen(false)
end

function redraw_scene()
    if not fn.dirty_scene() then return end
    scene:render()
    fn.dirty_scene(false)
end

function cleanup()
    clock.cancel(redraw_clock_id)
    metro.free_all()
    softcut.poll_stop_phase()
end
