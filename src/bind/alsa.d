/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2025
License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)
*/

extern(C):

//
// TYPES
//
alias c_enum = int; // TODO: Can we know for sure that this is the size of an enum in C?
alias snd_pcm_stream_t = c_enum;
alias snd_pcm_type_t = c_enum;
alias snd_pcm_state_t = c_enum;
alias snd_pcm_access_t = c_enum;
alias snd_pcm_format_t = c_enum;

struct snd_pcm_t;
struct snd_pcm_hw_params_t;
struct snd_pcm_sw_params_t;
struct snd_config_t;
struct snd_pcm_info_t;
struct snd_pcm_status_t;
struct snd_htimestamp_t;

enum{
    SND_PCM_STREAM_PLAYBACK = 0,
    /** Capture stream */
    SND_PCM_STREAM_CAPTURE,
    SND_PCM_STREAM_LAST = SND_PCM_STREAM_CAPTURE
}

enum{
    /** Non blocking mode (flag for open mode) \hideinitializer */
    SND_PCM_NONBLOCK		= 0x00000001,
    /** Async notification (flag for open mode) \hideinitializer */
    SND_PCM_ASYNC			= 0x00000002,
    /** In an abort state (internal, not allowed for open) */
    SND_PCM_ABORT			= 0x00008000,
    /** Disable automatic (but not forced!) rate resamplinig */
    SND_PCM_NO_AUTO_RESAMPLE	= 0x00010000,
    /** Disable automatic (but not forced!) channel conversion */
    SND_PCM_NO_AUTO_CHANNELS	= 0x00020000,
    /** Disable automatic (but not forced!) format conversion */
    SND_PCM_NO_AUTO_FORMAT		= 0x00040000,
    /** Disable soft volume control */
    SND_PCM_NO_SOFTVOL		    = 0x00080000,
}

enum{
    /** mmap access with simple interleaved channels */
    SND_PCM_ACCESS_MMAP_INTERLEAVED = 0,
    /** mmap access with simple non interleaved channels */
    SND_PCM_ACCESS_MMAP_NONINTERLEAVED,
    /** mmap access with complex placement */
    SND_PCM_ACCESS_MMAP_COMPLEX,
    /** snd_pcm_readi/snd_pcm_writei access */
    SND_PCM_ACCESS_RW_INTERLEAVED,
    /** snd_pcm_readn/snd_pcm_writen access */
    SND_PCM_ACCESS_RW_NONINTERLEAVED,
    SND_PCM_ACCESS_LAST = SND_PCM_ACCESS_RW_NONINTERLEAVED
}

enum{
    /** Unknown */
    SND_PCM_FORMAT_UNKNOWN = -1,
    /** Signed 8 bit */
    SND_PCM_FORMAT_S8 = 0,
    /** Unsigned 8 bit */
    SND_PCM_FORMAT_U8,
    /** Signed 16 bit Little Endian */
    SND_PCM_FORMAT_S16_LE,
    /** Signed 16 bit Big Endian */
    SND_PCM_FORMAT_S16_BE,
    /** Unsigned 16 bit Little Endian */
    SND_PCM_FORMAT_U16_LE,
    /** Unsigned 16 bit Big Endian */
    SND_PCM_FORMAT_U16_BE,
    /** Signed 24 bit Little Endian using low three bytes in 32-bit word */
    SND_PCM_FORMAT_S24_LE,
    /** Signed 24 bit Big Endian using low three bytes in 32-bit word */
    SND_PCM_FORMAT_S24_BE,
    /** Unsigned 24 bit Little Endian using low three bytes in 32-bit word */
    SND_PCM_FORMAT_U24_LE,
    /** Unsigned 24 bit Big Endian using low three bytes in 32-bit word */
    SND_PCM_FORMAT_U24_BE,
    /** Signed 32 bit Little Endian */
    SND_PCM_FORMAT_S32_LE,
    /** Signed 32 bit Big Endian */
    SND_PCM_FORMAT_S32_BE,
    /** Unsigned 32 bit Little Endian */
    SND_PCM_FORMAT_U32_LE,
    /** Unsigned 32 bit Big Endian */
    SND_PCM_FORMAT_U32_BE,
    /** Float 32 bit Little Endian, Range -1.0 to 1.0 */
    SND_PCM_FORMAT_FLOAT_LE,
    /** Float 32 bit Big Endian, Range -1.0 to 1.0 */
    SND_PCM_FORMAT_FLOAT_BE,
    /** Float 64 bit Little Endian, Range -1.0 to 1.0 */
    SND_PCM_FORMAT_FLOAT64_LE,
    /** Float 64 bit Big Endian, Range -1.0 to 1.0 */
    SND_PCM_FORMAT_FLOAT64_BE,
    /** IEC-958 Little Endian */
    SND_PCM_FORMAT_IEC958_SUBFRAME_LE,
    /** IEC-958 Big Endian */
    SND_PCM_FORMAT_IEC958_SUBFRAME_BE,
    /** Mu-Law */
    SND_PCM_FORMAT_MU_LAW,
    /** A-Law */
    SND_PCM_FORMAT_A_LAW,
    /** Ima-ADPCM */
    SND_PCM_FORMAT_IMA_ADPCM,
    /** MPEG */
    SND_PCM_FORMAT_MPEG,
    /** GSM */
    SND_PCM_FORMAT_GSM,
    /** Signed 20bit Little Endian in 4bytes format, LSB justified */
    SND_PCM_FORMAT_S20_LE,
    /** Signed 20bit Big Endian in 4bytes format, LSB justified */
    SND_PCM_FORMAT_S20_BE,
    /** Unsigned 20bit Little Endian in 4bytes format, LSB justified */
    SND_PCM_FORMAT_U20_LE,
    /** Unsigned 20bit Big Endian in 4bytes format, LSB justified */
    SND_PCM_FORMAT_U20_BE,
    /** Special */
    SND_PCM_FORMAT_SPECIAL = 31,
    /** Signed 24bit Little Endian in 3bytes format */
    SND_PCM_FORMAT_S24_3LE = 32,
    /** Signed 24bit Big Endian in 3bytes format */
    SND_PCM_FORMAT_S24_3BE,
    /** Unsigned 24bit Little Endian in 3bytes format */
    SND_PCM_FORMAT_U24_3LE,
    /** Unsigned 24bit Big Endian in 3bytes format */
    SND_PCM_FORMAT_U24_3BE,
    /** Signed 20bit Little Endian in 3bytes format */
    SND_PCM_FORMAT_S20_3LE,
    /** Signed 20bit Big Endian in 3bytes format */
    SND_PCM_FORMAT_S20_3BE,
    /** Unsigned 20bit Little Endian in 3bytes format */
    SND_PCM_FORMAT_U20_3LE,
    /** Unsigned 20bit Big Endian in 3bytes format */
    SND_PCM_FORMAT_U20_3BE,
    /** Signed 18bit Little Endian in 3bytes format */
    SND_PCM_FORMAT_S18_3LE,
    /** Signed 18bit Big Endian in 3bytes format */
    SND_PCM_FORMAT_S18_3BE,
    /** Unsigned 18bit Little Endian in 3bytes format */
    SND_PCM_FORMAT_U18_3LE,
    /** Unsigned 18bit Big Endian in 3bytes format */
    SND_PCM_FORMAT_U18_3BE,
    /* G.723 (ADPCM) 24 kbit/s, 8 samples in 3 bytes */
    SND_PCM_FORMAT_G723_24,
    /* G.723 (ADPCM) 24 kbit/s, 1 sample in 1 byte */
    SND_PCM_FORMAT_G723_24_1B,
    /* G.723 (ADPCM) 40 kbit/s, 8 samples in 3 bytes */
    SND_PCM_FORMAT_G723_40,
    /* G.723 (ADPCM) 40 kbit/s, 1 sample in 1 byte */
    SND_PCM_FORMAT_G723_40_1B,
    /* Direct Stream Digital (DSD) in 1-byte samples (x8) */
    SND_PCM_FORMAT_DSD_U8,
    /* Direct Stream Digital (DSD) in 2-byte samples (x16) */
    SND_PCM_FORMAT_DSD_U16_LE,
    /* Direct Stream Digital (DSD) in 4-byte samples (x32) */
    SND_PCM_FORMAT_DSD_U32_LE,
    /* Direct Stream Digital (DSD) in 2-byte samples (x16) */
    SND_PCM_FORMAT_DSD_U16_BE,
    /* Direct Stream Digital (DSD) in 4-byte samples (x32) */
    SND_PCM_FORMAT_DSD_U32_BE,
    SND_PCM_FORMAT_LAST = SND_PCM_FORMAT_DSD_U32_BE,
}

version(LittleEndian){
    enum{
        /** Signed 16 bit CPU endian */
        SND_PCM_FORMAT_S16 = SND_PCM_FORMAT_S16_LE,
        /** Unsigned 16 bit CPU endian */
        SND_PCM_FORMAT_U16 = SND_PCM_FORMAT_U16_LE,
        /** Signed 24 bit CPU endian */
        SND_PCM_FORMAT_S24 = SND_PCM_FORMAT_S24_LE,
        /** Unsigned 24 bit CPU endian */
        SND_PCM_FORMAT_U24 = SND_PCM_FORMAT_U24_LE,
        /** Signed 32 bit CPU endian */
        SND_PCM_FORMAT_S32 = SND_PCM_FORMAT_S32_LE,
        /** Unsigned 32 bit CPU endian */
        SND_PCM_FORMAT_U32 = SND_PCM_FORMAT_U32_LE,
        /** Float 32 bit CPU endian */
        SND_PCM_FORMAT_FLOAT = SND_PCM_FORMAT_FLOAT_LE,
        /** Float 64 bit CPU endian */
        SND_PCM_FORMAT_FLOAT64 = SND_PCM_FORMAT_FLOAT64_LE,
        /** IEC-958 CPU Endian */
        SND_PCM_FORMAT_IEC958_SUBFRAME = SND_PCM_FORMAT_IEC958_SUBFRAME_LE,
        /** Signed 20bit in 4bytes format, LSB justified, CPU Endian */
        SND_PCM_FORMAT_S20 = SND_PCM_FORMAT_S20_LE,
        /** Unsigned 20bit in 4bytes format, LSB justified, CPU Endian */
        SND_PCM_FORMAT_U20 = SND_PCM_FORMAT_U20_LE,
    }
}
else version(BigEndian){
    enum{
        /** Signed 16 bit CPU endian */
        SND_PCM_FORMAT_S16 = SND_PCM_FORMAT_S16_BE,
        /** Unsigned 16 bit CPU endian */
        SND_PCM_FORMAT_U16 = SND_PCM_FORMAT_U16_BE,
        /** Signed 24 bit CPU endian */
        SND_PCM_FORMAT_S24 = SND_PCM_FORMAT_S24_BE,
        /** Unsigned 24 bit CPU endian */
        SND_PCM_FORMAT_U24 = SND_PCM_FORMAT_U24_BE,
        /** Signed 32 bit CPU endian */
        SND_PCM_FORMAT_S32 = SND_PCM_FORMAT_S32_BE,
        /** Unsigned 32 bit CPU endian */
        SND_PCM_FORMAT_U32 = SND_PCM_FORMAT_U32_BE,
        /** Float 32 bit CPU endian */
        SND_PCM_FORMAT_FLOAT = SND_PCM_FORMAT_FLOAT_BE,
        /** Float 64 bit CPU endian */
        SND_PCM_FORMAT_FLOAT64 = SND_PCM_FORMAT_FLOAT64_BE,
        /** IEC-958 CPU Endian */
        SND_PCM_FORMAT_IEC958_SUBFRAME = SND_PCM_FORMAT_IEC958_SUBFRAME_BE,
        /** Signed 20bit in 4bytes format, LSB justified, CPU Endian */
        SND_PCM_FORMAT_S20 = SND_PCM_FORMAT_S20_BE,
        /** Unsigned 20bit in 4bytes format, LSB justified, CPU Endian */
        SND_PCM_FORMAT_U20 = SND_PCM_FORMAT_U20_BE,
    }
}
else{
    static assert(0);
}


// NOTE: alsa/pcm.h defines snd_pcm_uframes_t as an unsigned long and snd_pcm_sframes_t as a long.
// We convert to the appropriate D types below. A list of D types and how they compare to C/C++
// can be found here:
// https://wiki.dlang.org/D_binding_for_C
version(X86){
    alias snd_pcm_sframes_t = int;
    alias snd_pcm_uframes_t = uint;
}
version(X86_64){
    alias snd_pcm_sframes_t = long;
    alias snd_pcm_uframes_t = ulong;
}

int snd_pcm_open(snd_pcm_t **pcm, const char *name,
    snd_pcm_stream_t stream, int mode);
int snd_pcm_open_lconf(snd_pcm_t **pcm, const char *name,
               snd_pcm_stream_t stream, int mode,
               snd_config_t *lconf);
int snd_pcm_open_fallback(snd_pcm_t **pcm, snd_config_t *root,
              const char *name, const char *orig_name,
              snd_pcm_stream_t stream, int mode);

int snd_pcm_close(snd_pcm_t *pcm);
const(char)* snd_pcm_name(snd_pcm_t *pcm);
snd_pcm_type_t snd_pcm_type(snd_pcm_t *pcm);
snd_pcm_stream_t snd_pcm_stream(snd_pcm_t *pcm);
//int snd_pcm_poll_descriptors_count(snd_pcm_t *pcm);
//int snd_pcm_poll_descriptors(snd_pcm_t *pcm, struct pollfd *pfds, unsigned int space);
//int snd_pcm_poll_descriptors_revents(snd_pcm_t *pcm, struct pollfd *pfds, unsigned int nfds, unsigned short *revents);
//int snd_pcm_nonblock(snd_pcm_t *pcm, int nonblock);
//int snd_pcm_abort(snd_pcm_t *pcm) { pragma(inline, true); return snd_pcm_nonblock(pcm, 2); }
//int snd_async_add_pcm_handler(snd_async_handler_t **handler, snd_pcm_t *pcm,
                  //snd_async_callback_t callback, void *private_data);
//snd_pcm_t *snd_async_handler_get_pcm(snd_async_handler_t *handler);
int snd_pcm_info(snd_pcm_t *pcm, snd_pcm_info_t *info);
int snd_pcm_hw_params_current(snd_pcm_t *pcm, snd_pcm_hw_params_t *params);
int snd_pcm_hw_params(snd_pcm_t *pcm, snd_pcm_hw_params_t *params);
int snd_pcm_hw_free(snd_pcm_t *pcm);
int snd_pcm_sw_params_current(snd_pcm_t *pcm, snd_pcm_sw_params_t *params);
int snd_pcm_sw_params(snd_pcm_t *pcm, snd_pcm_sw_params_t *params);
int snd_pcm_prepare(snd_pcm_t *pcm);
int snd_pcm_reset(snd_pcm_t *pcm);
int snd_pcm_status(snd_pcm_t *pcm, snd_pcm_status_t *status);
int snd_pcm_start(snd_pcm_t *pcm);
//int snd_pcm_drop(snd_pcm_t *pcm);
//int snd_pcm_drain(snd_pcm_t *pcm);
//int snd_pcm_pause(snd_pcm_t *pcm, int enable);
//snd_pcm_state_t snd_pcm_state(snd_pcm_t *pcm);
int snd_pcm_hwsync(snd_pcm_t *pcm);
int snd_pcm_delay(snd_pcm_t *pcm, snd_pcm_sframes_t *delayp);
//int snd_pcm_resume(snd_pcm_t *pcm);
//int snd_pcm_htimestamp(snd_pcm_t *pcm, snd_pcm_uframes_t *avail, snd_htimestamp_t *tstamp);
snd_pcm_sframes_t snd_pcm_avail(snd_pcm_t *pcm);
snd_pcm_sframes_t snd_pcm_avail_update(snd_pcm_t *pcm);
int snd_pcm_avail_delay(snd_pcm_t *pcm, snd_pcm_sframes_t *availp, snd_pcm_sframes_t *delayp);
//snd_pcm_sframes_t snd_pcm_rewindable(snd_pcm_t *pcm);
//snd_pcm_sframes_t snd_pcm_rewind(snd_pcm_t *pcm, snd_pcm_uframes_t frames);
//snd_pcm_sframes_t snd_pcm_forwardable(snd_pcm_t *pcm);
//snd_pcm_sframes_t snd_pcm_forward(snd_pcm_t *pcm, snd_pcm_uframes_t frames);
snd_pcm_sframes_t snd_pcm_writei(snd_pcm_t *pcm, const void *buffer, snd_pcm_uframes_t size);
//snd_pcm_sframes_t snd_pcm_readi(snd_pcm_t *pcm, void *buffer, snd_pcm_uframes_t size);
//snd_pcm_sframes_t snd_pcm_writen(snd_pcm_t *pcm, void **bufs, snd_pcm_uframes_t size);
//snd_pcm_sframes_t snd_pcm_readn(snd_pcm_t *pcm, void **bufs, snd_pcm_uframes_t size);
int snd_pcm_wait(snd_pcm_t *pcm, int timeout);
int snd_pcm_drop(snd_pcm_t *pcm);

int snd_pcm_link(snd_pcm_t *pcm1, snd_pcm_t *pcm2);
int snd_pcm_unlink(snd_pcm_t *pcm);
const(char)* snd_strerror(int errnum);
int snd_pcm_recover(snd_pcm_t *pcm, int err, int silent);

int snd_pcm_hw_params_malloc(snd_pcm_hw_params_t **ptr);
void snd_pcm_hw_params_free(snd_pcm_hw_params_t *obj);
int snd_pcm_hw_params_any(snd_pcm_t *pcm, snd_pcm_hw_params_t *params);
int snd_pcm_hw_params_set_rate_resample(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, uint val);
int snd_pcm_hw_params_set_access(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, snd_pcm_access_t _access);
int snd_pcm_hw_params_set_format(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, snd_pcm_format_t val);
int snd_pcm_hw_params_set_channels(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, uint val);
int snd_pcm_hw_params_set_rate(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, uint val, int dir);
int snd_pcm_hw_params_set_buffer_size(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, snd_pcm_uframes_t val);
int snd_pcm_hw_params_set_period_size_near(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, snd_pcm_uframes_t *val, int *dir);
int snd_pcm_hw_params_set_periods(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, uint val, int dir);
int snd_pcm_hw_params_set_periods_near(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, uint *val, int *dir);
int snd_pcm_avail_delay(snd_pcm_t *pcm, snd_pcm_sframes_t *availp, snd_pcm_sframes_t *delayp);

int snd_pcm_hw_params_get_period_size(const snd_pcm_hw_params_t *params, snd_pcm_uframes_t *frames, int *dir);

int snd_pcm_sw_params_set_avail_min(snd_pcm_t *pcm, snd_pcm_sw_params_t *params, snd_pcm_uframes_t val);
int snd_pcm_sw_params_malloc(snd_pcm_sw_params_t **ptr);
void snd_pcm_sw_params_free(snd_pcm_sw_params_t *obj);
int snd_pcm_sw_params_current(snd_pcm_t *pcm, snd_pcm_sw_params_t *params);
int snd_pcm_sw_params(snd_pcm_t *pcm, snd_pcm_sw_params_t *params);
int snd_pcm_sw_params_set_start_threshold(snd_pcm_t *pcm, snd_pcm_sw_params_t *params, snd_pcm_uframes_t val);
