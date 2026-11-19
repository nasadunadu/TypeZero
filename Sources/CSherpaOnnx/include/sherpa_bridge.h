#ifndef SHERPA_BRIDGE_H
#define SHERPA_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct TZ_SenseVoiceHandle TZ_SenseVoiceHandle;

TZ_SenseVoiceHandle *tz_sensevoice_create(const char *model_path,
                                          const char *tokens_path,
                                          int32_t num_threads);

/// Transcribes mono float PCM samples [-1, 1]. Caller must free returned string with tz_sensevoice_free_string().
char *tz_sensevoice_transcribe(TZ_SenseVoiceHandle *handle,
                               const float *samples,
                               int32_t num_samples,
                               int32_t sample_rate);

void tz_sensevoice_free_string(char *str);

void tz_sensevoice_destroy(TZ_SenseVoiceHandle *handle);

#ifdef __cplusplus
}
#endif

#endif
