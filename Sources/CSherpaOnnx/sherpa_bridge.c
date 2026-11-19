#include "sherpa_bridge.h"
#include "../c-api-internal/c-api.h"
#include <stdlib.h>
#include <string.h>

struct TZ_SenseVoiceHandle {
    const SherpaOnnxOfflineRecognizer *recognizer;
};

TZ_SenseVoiceHandle *tz_sensevoice_create(const char *model_path,
                                          const char *tokens_path,
                                          int32_t num_threads) {
    if (!model_path || !tokens_path) {
        return NULL;
    }

    SherpaOnnxOfflineRecognizerConfig config;
    memset(&config, 0, sizeof(config));

    config.feat_config.sample_rate = 16000;
    config.feat_config.feature_dim = 80;

    config.model_config.sense_voice.model = model_path;
    // Lock Mandarin acoustic prior ("zh" still natively decodes mixed English BPE tokens in SenseVoice!)
    // Prevents short 1-2s clips from drifting into Cantonese/Japanese phoneme priors under "auto".
    config.model_config.sense_voice.language = "zh";
    config.model_config.sense_voice.use_itn = 1;
    config.model_config.tokens = tokens_path;
    config.model_config.num_threads = num_threads > 0 ? num_threads : 4;
    config.model_config.debug = 0;
    config.model_config.provider = "cpu";

    config.decoding_method = "greedy_search";

    const SherpaOnnxOfflineRecognizer *rec = SherpaOnnxCreateOfflineRecognizer(&config);
    if (!rec) {
        return NULL;
    }

    TZ_SenseVoiceHandle *h = (TZ_SenseVoiceHandle *)calloc(1, sizeof(TZ_SenseVoiceHandle));
    if (!h) {
        SherpaOnnxDestroyOfflineRecognizer(rec);
        return NULL;
    }
    h->recognizer = rec;
    return h;
}

char *tz_sensevoice_transcribe(TZ_SenseVoiceHandle *handle,
                               const float *samples,
                               int32_t num_samples,
                               int32_t sample_rate) {
    if (!handle || !handle->recognizer || !samples || num_samples <= 0) {
        return strdup("");
    }

    const SherpaOnnxOfflineStream *stream = SherpaOnnxCreateOfflineStream(handle->recognizer);
    if (!stream) {
        return strdup("");
    }

    SherpaOnnxAcceptWaveformOffline(stream, sample_rate, samples, num_samples);
    SherpaOnnxDecodeOfflineStream(handle->recognizer, stream);

    const SherpaOnnxOfflineRecognizerResult *result = SherpaOnnxGetOfflineStreamResult(stream);
    char *out = NULL;
    if (result && result->text) {
        out = strdup(result->text);
    } else {
        out = strdup("");
    }

    if (result) {
        SherpaOnnxDestroyOfflineRecognizerResult(result);
    }
    SherpaOnnxDestroyOfflineStream(stream);
    return out;
}

void tz_sensevoice_free_string(char *str) {
    if (str) {
        free(str);
    }
}

void tz_sensevoice_destroy(TZ_SenseVoiceHandle *handle) {
    if (!handle) return;
    if (handle->recognizer) {
        SherpaOnnxDestroyOfflineRecognizer(handle->recognizer);
    }
    free(handle);
}
