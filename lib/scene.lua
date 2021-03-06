scene = {} 

require("math")

function scene.init()
    softcut.reset()
    softcut.buffer_clear()
    audio.level_cut(1)
    for i = 1, 2 do
        softcut.enable(i, 1)
        softcut.level(i, 1)
        softcut.play(i, 0)
        softcut.rec(i,0)
        softcut.rate(i, 1)
        softcut.loop_start(i, loop_start)
        softcut.loop_end(i, loop_end)
        softcut.loop(i, 1)
        softcut.fade_time(i, 0.02)
        softcut.level_slew_time(i, 0.01)
        softcut.rate_slew_time(i, 0.01)
        softcut.rec_level(i, 0)
        softcut.pre_level(i, 1)
        softcut.position(i, 0)
        softcut.buffer(i, i)
    end
    for i = 3, 6 do
        softcut.enable(i, 0)
    end
    playhead, location = 0, 0
    softcut.phase_quant(1, 1/15)
    softcut.event_phase(function(voice, position)
        if voice == 1 then
            if fn.playing() then
                playhead = position
            end
            if fn.looping() and loop_start <= position and position <= loop_end then
                for i = 1, 2 do
                    softcut.loop_start(i, loop_start)
                    softcut.loop_end(i, loop_end)
                end
            else
                for i = 1, 2 do
                    softcut.loop_start(i, 0)
                    softcut.loop_end(i, track_length)
                end
            end
        end
    end)
    softcut.poll_start_phase()
    is_playing = false
    is_looping = true
end

function scene:song_view(start, dur)
    softcut.buffer_clear_region(start, dur, 0, 0)
    for _, track in ipairs(tracks) do
        local theta = math.pi/4 * (track.pan + 1)
        local left = track.mute * track.level * math.cos(theta)
        local right = track.mute * track.level * math.sin(theta)
        softcut.buffer_read_mono(track.file, start, start, dur, 1, 1, 1, left)
        softcut.buffer_read_mono(track.file, start, start, dur, 1, 2, 1, right)
    end
    softcut.pan(1,-1)
    softcut.pan(2,1)
end

function scene:track_view(start, dur)
    softcut.buffer_clear_region(start, dur, 0, 0)
    local track = tracks[fn.active_track()]
    softcut.buffer_read_mono(track.file, start, start, dur, 1, 1, 0, track.mute * track.level)
    if scratch_track.file ~= "" then
        softcut.buffer_read_mono(scratch_track.file, start, start, dur, 1, 2, 0, scratch_track.level)
    end
    softcut.pan(1,track.pan)
    softcut.pan(2,track.pan)
    scratch_track.pan = track.pan
end

function scene:render()
    if active_page == 0 then
        if not is_playing then
            self:song_view(0,-1)
        else
            if playhead <= location then
                if fn.looping() and location >= loop_end then
                    location = 0
                else
                    self:song_view(location, -1)
                end
            elseif location == 0 then
                self:song_view(0,-1)
            else
                self:song_view(0,location)
            end
        end
    elseif active_page == 1 then
        if not is_playing then
            self:track_view(0,-1)
        else
            if playhead <= location then
                if fn.looping() and location >= loop_end then
                    location = 0
                else
                    self:track_view(location,-1)
                end
            elseif location == 0 then
                self:song_view(0,-1)
            else
                self:track_view(0,location)
            end
        end
    end
end

function scene:record_arm(bool)
    rec_armed = bool
    if fn.playing() then
        softcut.rec(2, bool and 1 or 0)
    end
    audio.level_adc_cut(bool and 1 or 0)
    softcut.level_input_cut(1, 2, bool and 1 or 0)
    softcut.level_input_cut(2, 2, bool and 1 or 0)
    softcut.rec_level(2, bool and 1 or 0)
    if not bool then
        scratch_track:rec()
    end
end

return scene
