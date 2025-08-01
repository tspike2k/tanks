/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

import logging;
import memory;
import math : min;

// TODO:
// The only reason we use sound IDs is so the user can stop looping soudn effects. Perhaps it
// would be better to have a different mechanism for looping sounds. For instance, we could
// have a function loop_sound(...) that only continues playing if the function is called each
// frame. If it's not called on a game frame, the sound is marked for removal and only plays
// a small number of frames after that, fading out. The issue is we still need to know which
// sounds maps to which function call. Multiple entities may want to loop the same sound.
// Maybe there's a better way.
alias Sound_ID = uint;
enum  Null_Sound_ID = 0;

enum {
    Sound_Flag_Looped     = (1 << 0),
};

struct Sound{
    // Samples are stored interleaved for each channel. So the length of the sound in audio
    // frames is samples.length/channels.
    uint    channels;
    short[] samples;
};

// TODO: Should we take stereo pan as a parameter? Or perhaps a vector?
Sound_ID play_sfx(Sound* source, uint flags, float volume, float pitch = 1.0f){
    Sound_ID result = Null_Sound_ID;
    if(g_has_audio){
        Playing_Sound* sound;
        if(g_sounds_free_list){
            sound = g_sounds_free_list;
            g_sounds_free_list = g_sounds_free_list.next;
            clear_to_zero(*sound);
        }
        else{
            sound = alloc_type!Playing_Sound(g_allocator);
        }

        result = g_next_sound_id++;

        sound.id         = result;
        sound.samples    = source.samples;
        sound.channels   = source.channels;
        sound.flags      = flags;
        sound.volume     = volume;
        sound.pitch      = pitch;
        sound.just_added = true;
        g_playing_sounds.insert(g_playing_sounds.top, sound);
    }
    return result;
}

// TODO: Ideally this would be done using a seperate thread?
void audio_update(){
    if(g_has_audio){
        push_frame(g_allocator.scratch);
        scope(exit) pop_frame(g_allocator.scratch);

        Audio_Write_Info info = audio_write_begin();
        auto mixer_samples    = alloc_array!short(g_allocator.scratch, info.samples_to_write);

        float master_volume = 0.25f; // TODO: Using this as the max volume prevents the audio from glitching. Is there a better way to handle that?
        auto channels = g_channels_count;

        foreach(ref sound; g_playing_sounds.iterate()){
            if(!sound.just_added){
                sound.play_cursor_in_frames += info.frames_to_advance;
            }
            else
                sound.just_added = false;

            bool reached_end = sound.play_cursor_in_frames * sound.channels >= sound.samples.length;
            if(!reached_end || sound.flags & Sound_Flag_Looped){
                size_t samples_cursor   = sound.play_cursor_in_frames * sound.channels;
                size_t samples_to_write = mixer_samples.length;
                size_t samples_written  = 0;

                // TODO: Handle different source and dest channel configurations
                assert(channels == 2);
                assert(sound.channels == 1);
                while(samples_written < samples_to_write){
                    auto to_write_this_pass = min(samples_to_write / channels, sound.samples.length - samples_cursor);
                    auto source = sound.samples[samples_cursor .. samples_cursor + to_write_this_pass];
                    foreach(sample_index, sample_value; source){
                        short value = cast(short)(sound.volume*master_volume*cast(float)sample_value);

                        mixer_samples[samples_written++] += value;
                        mixer_samples[samples_written++] += value;
                    }

                    samples_cursor = 0;
                    if(!(sound.flags & Sound_Flag_Looped))
                        break;
                }
            }
            else{
                // The sound has finished playing
                g_playing_sounds.remove(sound);
                sound.next = g_sounds_free_list;
                g_sounds_free_list = sound;
            }
        }

        audio_write_end(mixer_samples);
    }
}

private:

struct Audio_Write_Info{
    uint   channels;
    size_t frames_to_advance;
    size_t samples_to_write;
}

struct Playing_Sound{
    Playing_Sound* next;
    Playing_Sound* prev;

    Sound_ID id;
    uint     flags;
    bool     just_added;
    uint     play_cursor_in_frames;
    uint     frames_until_stopped;

    float    pitch;
    float    volume;
    uint     channels;
    short[]  samples;
}

__gshared Allocator*         g_allocator;
__gshared bool               g_has_audio;
__gshared uint               g_channels_count;
__gshared size_t             g_buffer_size_in_frames;
__gshared List!Playing_Sound g_playing_sounds;
__gshared Playing_Sound*     g_sounds_free_list;
__gshared Sound_ID           g_next_sound_id;

version(linux){
    /*
    As far as I can tell, Alsa is the lowest level API for audio output availible in Linux userland.
    It's supported by the kernel itself, so it should be availible on everything but the most exotic
    custom Linux builds.

    Aside from the very combersone setup functions, one of the biggest differences between Alsa and
    other audio APIs (like Direct Sound on Windows) is that you are not given direct access
    to the audio buffer. Yes, kernel drivers maintain read and write cursors, but that isn't
    exposed by the API. This creates a challenge for video game programmers, as it's common to
    write several game frames of audio ahead. If the simulation runs as intended, those samples
    written in advance are overwritten before they are played so as to be more accurate to the state
    of the game. If the simulation were to hang, the audio samples written ahead of time would be
    played as normal, preventing crackling or popping audio.

    This strategy is difficult to employ using Alsa. This is because audio samples submitted to Alsa
    cannot be overwritten. As such, any samples submitted to Alsa will be considered having been
    "played" by this library. To get low-latency audio, the buffer used by Alsa must be quite small.
    To write samples ahead of time, a secondary buffer must be allocated and written to, with
    a dedicated audio thread pushing samples from this buffer when space becomes availible. The
    number of samples pushed needs to be summed up until the next call to audio_write_begin, which
    should lock the audio thread. The samples_to_advance value should be set to this sum and the
    samples counter should be reset. That is the plan for the future of this library. For now, you
    can only write audio that gets submitted directly to the Alsa audio buffer.

    In ALSA, a unit of sound is called a "fame." 1 frame == sizeof(short)*channels_count.
    In our codebase, the term "audio frame" will be used with this meaning. The word "sample" will
    be used to refer to the data that makes up only a single channel of an audio frame.
    Source:
    https://www.alsa-project.org/wiki/FramesPeriods
    */
    pragma(lib, "asound");
    private{
        import bind.alsa;

        __gshared snd_pcm_t* g_pcm_handle;
        __gshared size_t     g_samples_written_prev;
    }

    public bool audio_init(uint frames_per_sec, uint channels_count, Allocator* allocator){
        bool handle_error(string msg, int error_code){
            if(error_code < 0){
                log_error("{0}: {1}\n", msg, snd_strerror(error_code));
                if(g_pcm_handle) snd_pcm_close(g_pcm_handle);
                g_pcm_handle = null;
                return true;
            }
            else
                return false;
        }

        snd_pcm_sw_params_t* swparams;
        snd_pcm_hw_params_t* hwparams;

        g_has_audio = false;
        g_allocator = allocator;
        g_samples_written_prev = 0;
        g_channels_count = channels_count;
        g_playing_sounds.make();

        // TODO: Device name should be user configurable. We could do this through an INI file,
        // but that would be tricky to pass to this function, unless it was still in text form.
        // We could use getenv. Decide how to handle this.
        const char* device_name = "default";
        uint frame_size_in_bytes = (cast(uint)short.sizeof)*channels_count;
        g_buffer_size_in_frames = (frames_per_sec / 60)*4; // Three game frames of audio latency

        int err;
        err = snd_pcm_open(&g_pcm_handle, device_name, SND_PCM_STREAM_PLAYBACK, SND_PCM_NONBLOCK);
        if(handle_error("ALSA unable to open PCM handle", err)) return false;

        err = snd_pcm_hw_params_malloc(&hwparams);
        if(handle_error("ALSA unable to allocate hw params", err)) return false;
        scope(exit) snd_pcm_hw_params_free(hwparams);

        err = snd_pcm_hw_params_any(g_pcm_handle, hwparams);
        if(handle_error("ALSA unable to get hw params", err)) return false;

        err = snd_pcm_hw_params_set_access(g_pcm_handle, hwparams, SND_PCM_ACCESS_RW_INTERLEAVED);
        if(handle_error("ALSA unable to set access with hw params", err)) return false;

        err = snd_pcm_hw_params_set_format(g_pcm_handle, hwparams, SND_PCM_FORMAT_S16_LE);
        if(handle_error("ALSA unable to set format with hw params", err)) return false;

        err = snd_pcm_hw_params_set_channels(g_pcm_handle, hwparams, channels_count);
        if(handle_error("ALSA unable to set channels with hw params", err)) return false;

        err = snd_pcm_hw_params_set_rate(g_pcm_handle, hwparams, frames_per_sec, 0);
        if(handle_error("ALSA unable to set rate with hw params", err)) return false;

        err = snd_pcm_hw_params_set_buffer_size(g_pcm_handle, hwparams, g_buffer_size_in_frames);
        if(handle_error("ALSA unable to set buffer size with hw params", err)) return false;

        // NOTE: The period seems to decide a) how often the sound card will signal the application that a segment of the audio buffer has been read and b) what chunk (or chunks?)
        // of the audio buffer can be written to at a given time. If this is too low (say 1 period per buffer) the ring buffer could empty before we are signalled there's room in the buffer.
        uint target_periods = 8; // NOTE: Use an even number to divide the buffer into even periods. Probably not needed, Jack seems to prefer 3 periods per buffer.
        uint periods = target_periods;
        err = snd_pcm_hw_params_set_periods_near(g_pcm_handle, hwparams, &periods, null);
        if(handle_error("ALSA unable to set periods with hw params", err)) return false;

        if(periods != target_periods){
            log("ALSA set periods to {0} instead of target periods of {1}.\n", periods, target_periods);
        }

        err = snd_pcm_hw_params(g_pcm_handle, hwparams);
        if(handle_error("ALSA unable to submit hw params", err)) return false;

        snd_pcm_uframes_t period_size;
        snd_pcm_hw_params_get_period_size(hwparams, &period_size, null);
        if(handle_error("ALSA unable to query period size", err)) return false;

        snd_pcm_sw_params_malloc(&swparams);
        err = snd_pcm_sw_params_current(g_pcm_handle, swparams);
        if(handle_error("ALSA unable to get sw params", err)) return false;
        scope(exit) snd_pcm_sw_params_free(swparams);

        // NOTE: According to the following source, set_avail_min should be set to the period size:
        // https://alsa.opensrc.org/HowTo_Asynchronous_Playback
        // SDL2 sets avail_min to the number of samples (not sample frames, though). Miniaudio sets it to the period size.
        err = snd_pcm_sw_params_set_avail_min(g_pcm_handle, swparams, period_size);
        if(handle_error("ALSA unable to set avail_min with sw params", err)) return false;

        err = snd_pcm_sw_params_set_start_threshold(g_pcm_handle, swparams, 1);
        if(handle_error("ALSA unable to start threshold with sw params", err)) return false;

        err = snd_pcm_sw_params(g_pcm_handle, swparams);
        if(handle_error("ALSA unable to submit sw params", err)) return false;

        snd_pcm_prepare(g_pcm_handle);

        g_has_audio = true;
        return true;
    }

    Audio_Write_Info audio_write_begin(){
        auto avail = get_frames_avail();

        Audio_Write_Info result;
        result.channels = g_channels_count;
        result.frames_to_advance = g_samples_written_prev / g_channels_count;
        result.samples_to_write = avail * g_channels_count;

        return result;
    }

    private uint get_frames_avail(){
        uint result = 0; // TODO: Why is this a uint rather than a size_t?

        if(g_pcm_handle){
            snd_pcm_sframes_t avail = snd_pcm_avail_update(g_pcm_handle);
            if(avail < 0){
                // NOTE: snd_pcm_avail can return -32 (-EPIPE). The way to recover from this is by calling
                // snd_pcm_prepare(). See here for (a little) more info:
                // https://ferryzhou.wordpress.com/2012/02/23/alsa-broken-pipe/
                int err = cast(int)avail;
                if(err == -32){
                    log("ALSA buffer underrun (-EPIPE). Consider increasing the output buffer size.\n");

                    snd_pcm_prepare(g_pcm_handle);
                    result = cast(uint)g_buffer_size_in_frames;
                }
                else if (avail < 0){
                    log("ALSA recovering from error: {0}\n", snd_strerror(err));
                    snd_pcm_recover(g_pcm_handle, err, 0);
                    result = cast(uint)g_buffer_size_in_frames;
                }
            }
            else{
                result = cast(uint)avail;
            }
        }
        assert(result <= g_buffer_size_in_frames); // Sanity check.

        return result;
    }

    void audio_write_end(short[] samples){
        g_samples_written_prev = cast(uint)samples.length;

        if(samples.length > 0){
            uint channels = g_channels_count;
            size_t frames_to_write = samples.length / channels;
            snd_pcm_sframes_t frames_written = snd_pcm_writei(g_pcm_handle, samples.ptr, frames_to_write);
            if(frames_written < 0){
                int err = cast(int)frames_written;
                log("Buffer underrun in ALSA.\n"); // TODO: Does this REALLY mean a buffer underrun?
                snd_pcm_recover(g_pcm_handle, err, 0);
            }
            else {
                size_t samples_written = frames_written*channels;
                if(frames_written != frames_to_write){
                    log("Short write in ALSA: wrote {0} of {1} samples\n", samples_written, samples.length);
                }
            }
        }
    }
} // version(linux)

