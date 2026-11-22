use crate::core::lexicon::PhoneticIndexer;
use crate::models::{
    ActiveScreenContext, DictationMode, FormattingStyle, LLMConfig, LLMProviderOption, LexiconEntry,
};
use futures_util::StreamExt;
use once_cell::sync::Lazy;
use regex::Regex;
use reqwest::Client;
use serde_json::{json, Value};
use std::collections::HashSet;
use std::time::{Duration, Instant};

// 100% STATIC System Prompts (exact v0.4.10 parity so DeepSeek KV Prefix Cache hits on every call!)
const STRUCTURED_STATIC_SYSTEM_PROMPT: &str = r#"你是顶级 AI 语音输入法的意图级文字整理与排版引擎（深度对齐 Typeless 核心策略）。读取 <scene>、<preceding_text>（输入框光标前已有文字）、<lexicon> 与 <raw_speech>，直接输出本次新增正文的整理结果：

1. 【语气硬保真·反过度编辑·中途反悔折叠·同音错词直改】：**绝不改变原句语气与人味**——原文为疑问、反问、商量确认或担忧推测（如“会不会…”“对不对”“是不是”）时，必须保留问句语气和全角问号 `？`。保留态度词（句首的“好/好的/对/没问题/确实”），**严禁把口语洗成冷冰冰的公文腔，严禁脑补原话未提及的幻觉内容**。彻底清理无意义卡壳与口癖（`嗯/啊/呃/那个/就是说/然后呢/的话呢/对吧`），遇到**中途反悔/自我纠正**（如“周三开会……不对，改周四下午 3 点”“前面那个算了，直接看最后这条”）时，**直接折叠删掉废弃前文，只保留最终意图**。面对长句绕弯或破碎从句，自然理顺语序使其通顺，**严禁删减任何独有的原因解释、约束条件、举例或程度修饰**。遇到明显不通顺的同音/近音错词（如「现成」实为「场景/线程」、「Su」实为「SEO」），结合 `<recent_context>`、`<preceding_text>` 与 `<lexicon>` **果断直接替换为正确词语——绝对禁止输出括号批注（如 `现成（场景）`）**！
2. 【数字阿拉伯化（现代键盘 ITN）】：序号、列举、数量、时间、时长、比例一律转阿拉伯数字（“一二三四”->“1、2、3、4”或“1234”，“第一个”->“第 1 个”，“两三个”->“2~3 个”，“四点半”->“4 点半”）。固定成语与叠词副词严格保留汉字（“一起、一直、一定、一下、一点、一般、一卡一卡、一点一点、一个字一个字”禁转数字）。
3. 【语义自然分段与结构化列点（告别文字墙）】：
   - **按语义层次自然分段（黄金节奏：每段约 2~3 句、50~85 字）**：不要把长口述糊成一整坨！只要总字数超过 **65 字** 且存在清晰的**语义层次切换**（如「现状/背景 → 原因/判断 → 诉求/行动」、「观点 A → 转折/补充/但是/另外 → 观点 B」、「现象描述 → 优化建议」），就在层次边界处用单个换行（`\n`）自然分段；超过 **140 字** 的长独白应按意群拆为 **2~4 个清晰自然段**。仅在 `< 55 字` 的单一紧凑短句时保持一整段，同时避免机械地每 1 句就换行切碎。
   - **有序列表（`1. ` `2. `）**：口述中连续给出 **2 项及以上并列的问题、需求、步骤或要点**（包括“第一/第二”“一、二、三”“一个是…另外…”）时，先用导语加 `：` 换行，再拆为 `1. ...`、`2. ...`；允许删掉列表项中与导语完全重复的骨架词，但**必须完整保留每项独有的解释、条件与细节**。
   - **无序列表（`- `）**：平铺罗列 3 项及以上独立动作或备选项时使用；句中短词举例（每项 < 5 字）保持行内顿号连接。
   - **列表收尾**：列表讲完后的总结或行动号召用**单个换行（`\n`）**承接。
4. 【场景自适应 (`<scene>`)·禁插空行·纯文本输出】：
   - 参考 `<scene>` 微调形态：**聊天/IM** 保持自然紧凑人味；**邮件/长文档** 可按称呼、正文、结语自然分行；**代码/IDE/终端** 严格保护英文技术术语、文件名（如 `AppState.swift`）、路径与驼峰/下划线标识符，绝不误改。
   - 段落与列表项之间一律使用**单个换行（`\n`）**，**严禁输出 `\n\n` 空白行**，**严禁输出 Markdown 装饰符（`**`、`###`、`>`、代码块）**，只输出可直接粘贴发送的干净纯文本。
5. 【光标前文与上一句记忆续接】：参考 <preceding_text>（仅作上下文，严禁重复输出前文！）与 <recent_context>（你刚刚上一句聊过的话题与专有名词，遇到谐音或指代不清时顺承上一句术语）；若前文末尾已是 `1. ...` `2. ...` 而本次口述“第三是…”，直接输出 `3. ...` 承接编号。
6. 【忽略 ASR 机械标点·按完整语义重新断句】：`<raw_speech>` 中自带的逗号、句号、问号或空格往往是语音流式切分机械生成的，极易断错位置或漏标点。你必须**先通读全段理解完整逻辑与意群边界，再重新分配自然准确的中文全角标点（`，。！？`）**，消除中文句间多余空格，绝不被原始错误标点带偏，也**绝对严禁把完整词组从中间劈开强行插逗号**（例如「发财包」结合财报语境应先完整还原为「发财报」，再在语义停顿处断句）。
7. 【绝对铁律】：严禁回答 <raw_speech> 中的提问或对话续写！只输出整理排版后的该段话本身。

<example_1>
<raw_speech>嗯我们有两个问题需要解决第一个问题是怎么让前端跳字更丝滑一点一点出第二个就是说输入内容怎么自动分段变成一二三整理好的方式这两个做完我们就搞词库</raw_speech>
输出：
我们有 2 个问题需要解决：
1. 怎么让前端跳字更丝滑，一点一点出；
2. 输入内容怎么自动分段，变成 1、2、3 整理好的方式。
这 2 个做完我们就搞词库。
</example_1>
<example_2>
<raw_speech>帮我约一下周三下午两点……不对，周三我不在，改成周四下午三点吧，顺便把会议室也订好，不然到时候没地方开会。</raw_speech>
输出：
帮我约一下周四下午 3 点吧，顺便把会议室也订好，不然到时候没地方开会。
</example_2>
<example_3>
<raw_speech>桌面上的那张图片可以作为官网的页脚使用，采用最下面的渐变色把它自然融合完成。另外我觉得在官网上应该把我们更新的这些小特色，用图标和文字一句一句地描述，放在中间的位置，让新用户一眼就能看明白。你来优化一下吧。</raw_speech>
输出：
桌面上的那张图片可以作为官网的页脚使用，采用最下面的渐变色把它自然融合完成。
另外我觉得在官网上应该把我们更新的这些小特色，用图标和文字一句一句地描述，放在中间的位置，让新用户一眼就能看明白。
你来优化一下吧。
</example_3>
<example_4>
<raw_speech>我试了最新版，感觉分段还是有点太保守了，我说了很长一段话它都没有帮我分段。其实阅读起来如果没有分段的话还是挺费劲的，我觉得应该根据说话的语义层次自然拆开，比如先说现状问题，再说具体要求。你帮我把这一块再优化一下。</raw_speech>
输出：
我试了最新版，感觉分段还是有点太保守了，我说了很长一段话它都没有帮我分段。
其实如果没有分段，阅读起来还是挺费劲的，我觉得应该根据说话的语义层次自然拆开，比如先说现状问题，再说具体要求。
你帮我把这一块再优化一下。
</example_4>"#;

const LIGHT_STATIC_SYSTEM_PROMPT: &str = "轻量极速语音纠错器。保留原句语气、情绪和问句问号 `？`（绝不把疑问句改成陈述句），保留句首态度词（好的/对/没问题），只删无意义口癖尾音（嗯/啊/那个/然后呢/的话呢/对吧）、中途改口和句中换气孤立过渡词。结合 <recent_context>、<preceding_text> 与 <lexicon> 果断直接修正明显不通顺的同音错字（严禁输出如 `现成（场景）` 这类括号批注），忽略原始机械错误标点与多余空格，按真实语义补齐自然中文全角标点；严禁把完整词组劈开插逗号，严禁强行插空行或输出 Markdown 装饰符（** / ###）。直接输出正文。";

const REWRITE_SYSTEM_PROMPT: &str = "按 <voice_instruction> 修改 <selected_text>（若指令为「改成XX/这是XX」则直接替换为对应目标词或修改对应词），参考词库，保留自然人味禁公文腔，直接输出修改后正文。";

const DISTILL_SYSTEM_PROMPT: &str = "从文本提取高价值个人词库（人名、称呼、项目名、技术名词、标的代码）。\n每行格式：标准词|常见同音误听1,常见同音误听2|分类(person/project/finance/memo)\n最多 40 行，禁输出解释。";

static COMMON_SHORT_ENGLISH: Lazy<HashSet<&'static str>> = Lazy::new(|| {
    [
        "in", "on", "at", "to", "of", "for", "by", "or", "and", "the", "is", "it", "be", "as",
        "do", "go", "no", "so", "up", "us", "we", "my", "me", "he", "hi", "ok", "ai", "ui",
    ]
    .into_iter()
    .collect()
});

static PERCENT_RE: Lazy<Regex> = Lazy::new(|| Regex::new(r"百分之(\d+(?:\.\d+)?)").unwrap());
static MULTI_NEWLINE_RE: Lazy<Regex> = Lazy::new(|| Regex::new(r"[ \t]*\n{2,}[ \t]*").unwrap());
static MD_BOLD_RE: Lazy<Regex> = Lazy::new(|| Regex::new(r"\*\*([^\n*]{1,80})\*\*").unwrap());
static MD_HEADING_RE: Lazy<Regex> = Lazy::new(|| Regex::new(r"(?m)^#{1,4}[ \t]+").unwrap());
static CJK_Q_RE: Lazy<Regex> = Lazy::new(|| Regex::new(r"([\u{4e00}-\u{9fa5}])\s*\?").unwrap());
static CJK_BANG_RE: Lazy<Regex> = Lazy::new(|| Regex::new(r"([\u{4e00}-\u{9fa5}])\s*!").unwrap());
static PANGU_CJK_ASCII_RE: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"([\u{4e00}-\u{9fa5}])([A-Za-z0-9$¥%])").unwrap());
static PANGU_ASCII_CJK_RE: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"([A-Za-z0-9%])([\u{4e00}-\u{9fa5}])").unwrap());

#[derive(Debug, Clone)]
pub struct PolishResult {
    pub text: String,
    pub latency_ms: u64,
    pub used_fast_path: bool,
}

#[derive(Debug, Clone)]
pub struct BenchmarkResult {
    pub ttft_ms: u64,
    pub total_ms: u64,
    pub sample_output: String,
}

pub struct PolishEngine {
    proxy_client: Client,
    direct_client: Client,
}

impl Default for PolishEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl PolishEngine {
    pub fn new() -> Self {
        let proxy_client = Client::builder()
            .connect_timeout(Duration::from_secs(6))
            .timeout(Duration::from_secs(12))
            .pool_max_idle_per_host(6)
            .build()
            .unwrap_or_else(|_| Client::new());

        let direct_client = Client::builder()
            .no_proxy()
            .connect_timeout(Duration::from_secs(6))
            .timeout(Duration::from_secs(12))
            .pool_max_idle_per_host(6)
            .build()
            .unwrap_or_else(|_| Client::new());

        Self {
            proxy_client,
            direct_client,
        }
    }

    pub fn should_use_direct_connection(base_url: &str) -> bool {
        let u = base_url.to_lowercase();
        const DIRECT_HOSTS: &[&str] = &[
            "deepseek.com",
            "volces.com",
            "volcengine.com",
            "aliyuncs.com",
            "siliconflow.cn",
            "bigmodel.cn",
            "moonshot.cn",
            "minimax.chat",
            "minimaxi.com",
            "localhost",
            "127.0.0.1",
            "0.0.0.0",
        ];
        DIRECT_HOSTS.iter().any(|h| u.contains(h))
    }

    fn client_for(&self, base_url: &str) -> &Client {
        if Self::should_use_direct_connection(base_url) {
            &self.direct_client
        } else {
            &self.proxy_client
        }
    }

    pub fn is_keyless_local_endpoint(base_url: &str) -> bool {
        let u = base_url.to_lowercase();
        u.contains("localhost") || u.contains("127.0.0.1") || u.contains("0.0.0.0")
    }

    pub fn is_anthropic_endpoint(base_url: &str) -> bool {
        let u = base_url.trim().to_lowercase();
        u.contains("anthropic.com") || u.ends_with("/messages")
    }

    pub fn normalize_anthropic_messages_endpoint(base_url: &str) -> String {
        let clean = base_url.trim().trim_end_matches('/');
        if clean.ends_with("/messages") {
            clean.to_string()
        } else {
            format!("{clean}/messages")
        }
    }

    pub fn normalize_chat_completions_endpoint(base_url: &str) -> String {
        let mut clean = base_url.trim().trim_end_matches('/').to_string();
        if let Some(stripped) = clean.strip_suffix("/responses") {
            clean = stripped.to_string();
        }
        if clean.ends_with("/chat/completions") {
            clean
        } else {
            format!("{clean}/chat/completions")
        }
    }

    /// Pre-warms TCP/TLS keep-alive socket the moment dictation begins.
    pub fn prewarm_connection(&self, base_url: &str, api_key: &str) {
        let trimmed = base_url.trim().trim_end_matches('/').to_string();
        if trimmed.is_empty() {
            return;
        }
        let client = self.client_for(&trimmed).clone();
        let key = api_key.trim().to_string();
        tokio::spawn(async move {
            let url = format!("{trimmed}/models");
            let mut req = client.get(&url).timeout(Duration::from_secs(3));
            if !key.is_empty() {
                if Self::is_anthropic_endpoint(&trimmed) {
                    req = req
                        .header("x-api-key", &key)
                        .header("anthropic-version", "2023-06-01");
                } else {
                    req = req.header("Authorization", format!("Bearer {key}"));
                }
            }
            let _ = req.send().await;
        });
    }

    pub fn apply_instant_local_dictionary(
        raw: &str,
        entries: &[LexiconEntry],
        context: &ActiveScreenContext,
        config: &LLMConfig,
        strip_period: bool,
    ) -> String {
        if raw.is_empty() {
            return String::new();
        }
        let mut fixed = raw
            .replace("另起一行", "\n")
            .replace("新起一段", "\n\n");

        for item in entries.iter().take(200) {
            let mut sorted_aliases: Vec<&str> = item
                .aliases
                .iter()
                .map(String::as_str)
                .filter(|a| a.chars().count() >= 2)
                .collect();
            sorted_aliases.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()));

            for alias in sorted_aliases {
                let is_short_pure_ascii = alias.len() <= 5
                    && alias
                        .chars()
                        .all(|c| c.is_ascii() && (c.is_ascii_alphabetic() || c == ' '));
                if !is_short_pure_ascii {
                    fixed = replace_case_insensitive(&fixed, alias, &item.term);
                } else if !COMMON_SHORT_ENGLISH.contains(alias.to_lowercase().as_str()) {
                    // Word-boundary-safe replacement: fixes standalone "Su" / "s Su" -> "SEO"
                    // without ever touching "Summary" or "Supabase"!
                    fixed = replace_ascii_word_boundary_ci(&fixed, alias, &item.term);
                }
            }
        }

        if strip_period {
            fixed = Self::apply_post_formatting_rules(&fixed, context, config);
        }
        fixed
    }

    /// Deterministic check for whether a spoken sentence is clean enough to skip Pass-2 LLM (`0ms` direct paste!).
    pub fn can_bypass_cloud_polish(
        locally_fixed: &str,
        recalled_terms: &[LexiconEntry],
        formatting_style: FormattingStyle,
        is_high_accuracy_local_asr: bool,
        is_punctuated_cloud_asr: bool,
    ) -> bool {
        let trimmed = locally_fixed.trim();
        if trimmed.is_empty() {
            return true;
        }

        const MUST_POLISH_MARKERS: &[&str] = &[
            "嗯", "啊", "呃", "额", "那个", "就是", "然后呢", "怎么说", "不对", "不是", "重说",
            "算了", "改成", "改为", "其实", "更正", "我是说", "第一", "第二", "第三", "首先",
            "其次", "两件事", "三件事", "几个问题", "两点", "三点", "百分之", "一二三",
        ];
        if Self::contains_stutter_repetition(trimmed)
            || MUST_POLISH_MARKERS.iter().any(|m| trimmed.contains(m))
        {
            return false;
        }

        let utt_fuzzy = PhoneticIndexer::fuzzy_skeleton(trimmed);
        let lower_trimmed = trimmed.to_lowercase();
        for entry in recalled_terms {
            let entry_fuzzy = PhoneticIndexer::fuzzy_skeleton(&entry.term);
            if entry_fuzzy.len() >= 4
                && utt_fuzzy.contains(&entry_fuzzy)
                && !lower_trimmed.contains(&entry.term.to_lowercase())
            {
                return false;
            }
        }

        let fast_max_chars = if is_punctuated_cloud_asr {
            28
        } else if formatting_style == FormattingStyle::Structured {
            6
        } else if is_high_accuracy_local_asr {
            20
        } else {
            5
        };
        trimmed.chars().count() <= fast_max_chars
    }

    pub async fn polish<F>(
        &self,
        raw_transcript: &str,
        mode: DictationMode,
        screen_context: &ActiveScreenContext,
        recalled_terms: &[LexiconEntry],
        recent_outputs: &[String],
        config: &LLMConfig,
        api_key: &str,
        is_high_accuracy_local_asr: bool,
        is_punctuated_cloud_asr: bool,
        mut on_stream_chunk: Option<F>,
    ) -> PolishResult
    where
        F: FnMut(String, bool) + Send,
    {
        let start = Instant::now();
        let cleaned_raw = raw_transcript.trim();
        if cleaned_raw.is_empty() {
            return PolishResult {
                text: String::new(),
                latency_ms: 0,
                used_fast_path: true,
            };
        }

        let locally_fixed = Self::apply_instant_local_dictionary(
            cleaned_raw,
            recalled_terms,
            screen_context,
            config,
            false,
        );

        let clean_key = api_key.trim();
        if mode == DictationMode::Dictate
            && (config.formatting_style == FormattingStyle::VerbatimLocal
                || (clean_key.is_empty() && !Self::is_keyless_local_endpoint(&config.base_url)))
        {
            let out = Self::apply_post_formatting_rules(&locally_fixed, screen_context, config);
            return PolishResult {
                text: out,
                latency_ms: 0,
                used_fast_path: true,
            };
        }

        if mode == DictationMode::Dictate
            && config.enable_fast_bypass_for_short_phrases
            && Self::can_bypass_cloud_polish(
                &locally_fixed,
                recalled_terms,
                config.formatting_style,
                is_high_accuracy_local_asr,
                is_punctuated_cloud_asr,
            )
        {
            let out = Self::apply_post_formatting_rules(&locally_fixed, screen_context, config);
            return PolishResult {
                text: out,
                latency_ms: start.elapsed().as_millis() as u64,
                used_fast_path: true,
            };
        }

        let glossary_block = if recalled_terms.is_empty() {
            "无".to_string()
        } else {
            recalled_terms
                .iter()
                .map(|entry| {
                    if entry.aliases.is_empty() {
                        entry.term.clone()
                    } else {
                        let sample: Vec<&str> =
                            entry.aliases.iter().take(4).map(String::as_str).collect();
                        format!("{}(误听:{})", entry.term, sample.join("/"))
                    }
                })
                .collect::<Vec<_>>()
                .join("；")
        };

        let preceding_snippet = screen_context.preceding_text.trim();
        let preceding_tag = if preceding_snippet.is_empty() {
            "无".to_string()
        } else {
            tail_chars(preceding_snippet, 120)
        };

        let recent_joined = recent_outputs
            .iter()
            .map(|s| s.replace('\n', " ").trim().to_string())
            .filter(|s| !s.is_empty())
            .rev()
            .take(2)
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .collect::<Vec<_>>()
            .join(" ｜ ");
        let recent_tag = if recent_joined.is_empty() {
            "无".to_string()
        } else {
            tail_chars(&recent_joined, 110)
        };

        let (system_prompt, user_content) = match mode {
            DictationMode::Dictate => {
                let sys = if config.formatting_style == FormattingStyle::Structured {
                    STRUCTURED_STATIC_SYSTEM_PROMPT
                } else {
                    LIGHT_STATIC_SYSTEM_PROMPT
                };
                let user = format!(
                    "<scene>{}</scene>\n<recent_context>{}</recent_context>\n<preceding_text>{}</preceding_text>\n<lexicon>{}</lexicon>\n<raw_speech>{}</raw_speech>",
                    screen_context.tone_profile().as_str(),
                    recent_tag,
                    preceding_tag,
                    glossary_block,
                    locally_fixed
                );
                (sys, user)
            }
            DictationMode::RewriteSelection => {
                let user = format!(
                    "<recent_context>{}</recent_context>\n<lexicon>{}</lexicon>\n<selected_text>{}</selected_text>\n<voice_instruction>{}</voice_instruction>",
                    recent_tag,
                    glossary_block,
                    screen_context.selected_text,
                    locally_fixed
                );
                (REWRITE_SYSTEM_PROMPT, user)
            }
        };

        let max_tokens = (locally_fixed.chars().count() * 2).max(180);
        match self
            .call_chat_completions_sse(
                &config.base_url,
                &config.model_name,
                clean_key,
                system_prompt,
                &user_content,
                max_tokens,
                config,
                &mut on_stream_chunk,
            )
            .await
        {
            Ok((result, first_token_ms)) => {
                let formatted =
                    Self::apply_post_formatting_rules(&result, screen_context, config);
                let total_ms = start.elapsed().as_millis() as u64;
                PolishResult {
                    text: if formatted.is_empty() {
                        locally_fixed
                    } else {
                        formatted
                    },
                    latency_ms: if first_token_ms > 0 {
                        first_token_ms
                    } else {
                        total_ms
                    },
                    used_fast_path: false,
                }
            }
            Err(_) => PolishResult {
                text: Self::apply_post_formatting_rules(&locally_fixed, screen_context, config),
                latency_ms: start.elapsed().as_millis() as u64,
                used_fast_path: true,
            },
        }
    }

    pub async fn benchmark_latency(
        &self,
        config: &LLMConfig,
        api_key: &str,
    ) -> Result<BenchmarkResult, String> {
        let clean_key = api_key.trim();
        if clean_key.is_empty() && !Self::is_keyless_local_endpoint(&config.base_url) {
            return Err("当前勾选模型尚未填入 API Key，请先粘贴密钥并点击「保存」".to_string());
        }
        self.prewarm_connection(&config.base_url, clean_key);
        tokio::time::sleep(Duration::from_millis(160)).await;

        let total_start = Instant::now();
        let mut no_cb: Option<fn(String, bool)> = None;
        let (sample_output, ttft) = self
            .call_chat_completions_sse(
                &config.base_url,
                &config.model_name,
                clean_key,
                STRUCTURED_STATIC_SYSTEM_PROMPT,
                "<scene>AI提问与笔记</scene>\n<lexicon>无</lexicon>\n<raw_speech>嗯那个帮我记两件事第一明天下午两点不对改四点同步进度第二测一下豆包极速接口</raw_speech>",
                120,
                config,
                &mut no_cb,
            )
            .await?;
        let total_ms = total_start.elapsed().as_millis() as u64;
        Ok(BenchmarkResult {
            ttft_ms: if ttft > 0 { ttft } else { total_ms },
            total_ms,
            sample_output,
        })
    }

    pub async fn distill_terms_from_raw_corpus(
        &self,
        corpus_text: &str,
        config: &LLMConfig,
        api_key: &str,
    ) -> Result<Vec<(String, Vec<String>, crate::models::LexiconCategory)>, String> {
        let clean_key = api_key.trim();
        if clean_key.is_empty() && !Self::is_keyless_local_endpoint(&config.base_url) {
            return Err("请先在设置页填入大模型 API Key".to_string());
        }
        let clipped: String = corpus_text.chars().take(12_000).collect();
        let mut no_cb: Option<fn(String, bool)> = None;
        let (raw_out, _) = self
            .call_chat_completions_sse(
                &config.base_url,
                &config.model_name,
                clean_key,
                DISTILL_SYSTEM_PROMPT,
                &clipped,
                1200,
                config,
                &mut no_cb,
            )
            .await?;

        let mut parsed = Vec::new();
        for line in raw_out.lines() {
            let cols: Vec<&str> = line.split('|').map(str::trim).collect();
            if cols.is_empty() || cols[0].chars().count() < 2 {
                continue;
            }
            let term = cols[0].to_string();
            let aliases: Vec<String> = if cols.len() >= 2 {
                cols[1]
                    .split([',', '，'])
                    .map(str::trim)
                    .filter(|s| !s.is_empty())
                    .map(ToString::to_string)
                    .collect()
            } else {
                Vec::new()
            };
            let cat_str = cols.get(2).map(|s| s.to_lowercase()).unwrap_or_default();
            let cat = if cat_str.contains("person") {
                crate::models::LexiconCategory::Person
            } else if cat_str.contains("finance") {
                crate::models::LexiconCategory::Finance
            } else if cat_str.contains("project") {
                crate::models::LexiconCategory::Project
            } else {
                crate::models::LexiconCategory::Memo
            };
            parsed.push((term, aliases, cat));
        }
        Ok(parsed)
    }

    /// Builds provider-accurate OpenAI-compatible JSON payload for DeepSeek, Volcengine Doubao,
    /// OpenAI GPT-4.1 / GPT-5 / o-series, Google Gemini 2.5 / 3.x / 4.x, DashScope Qwen, and Custom/Ollama.
    pub fn build_openai_compatible_payload(
        endpoint: &str,
        model: &str,
        system_prompt: &str,
        user_content: &str,
        max_tokens: usize,
        stream: bool,
    ) -> Value {
        let lower_model = model.to_lowercase();
        let lower_endpoint = endpoint.to_lowercase();
        let lower_combined = format!("{lower_model} {lower_endpoint}");

        let mut map = serde_json::Map::new();
        map.insert("model".into(), json!(model));
        map.insert("stream".into(), json!(stream));
        map.insert(
            "messages".into(),
            json!([
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_content}
            ]),
        );

        let is_openai_reasoning = lower_model.starts_with("gpt-5")
            || lower_model.starts_with("o1")
            || lower_model.starts_with("o3")
            || lower_model.starts_with("o4");

        if is_openai_reasoning {
            map.insert("max_completion_tokens".into(), json!(max_tokens));
            if lower_model.starts_with("gpt-5") {
                map.insert("reasoning_effort".into(), json!("minimal"));
            }
        } else {
            map.insert("max_tokens".into(), json!(max_tokens));
            if lower_combined.contains("deepseek")
                || lower_combined.contains("volces.com")
                || lower_combined.contains("doubao")
                || lower_model.starts_with("ep-")
            {
                map.insert("thinking".into(), json!({"type": "disabled"}));
            } else if lower_endpoint.contains("generativelanguage.googleapis.com")
                || lower_model.starts_with("gemini-")
            {
                if lower_model.contains("2.5-flash") {
                    map.insert("reasoning_effort".into(), json!("none"));
                } else if lower_model.starts_with("gemini-3") || lower_model.starts_with("gemini-4")
                {
                    map.insert("reasoning_effort".into(), json!("minimal"));
                }
                map.insert("temperature".into(), json!(0.1));
            } else {
                map.insert("temperature".into(), json!(0.1));
            }
        }

        Value::Object(map)
    }

    async fn call_chat_completions_sse<F>(
        &self,
        base_url: &str,
        model: &str,
        api_key: &str,
        system_prompt: &str,
        user_content: &str,
        max_tokens: usize,
        config: &LLMConfig,
        on_stream_chunk: &mut Option<F>,
    ) -> Result<(String, u64), String>
    where
        F: FnMut(String, bool) + Send,
    {
        if config.selected_provider == LLMProviderOption::Anthropic
            || Self::is_anthropic_endpoint(base_url)
        {
            return self
                .call_anthropic_messages_sse(
                    base_url,
                    model,
                    api_key,
                    system_prompt,
                    user_content,
                    max_tokens,
                    config.enable_pangu_spacing,
                    on_stream_chunk,
                )
                .await;
        }

        let start = Instant::now();
        let endpoint = Self::normalize_chat_completions_endpoint(base_url);
        let client = self.client_for(base_url);

        let mut payload = Self::build_openai_compatible_payload(
            &endpoint,
            model,
            system_prompt,
            user_content,
            max_tokens,
            true,
        );

        let send_once = |body: &Value| {
            let mut req = client
                .post(&endpoint)
                .header("Content-Type", "application/json")
                .header("Accept", "text/event-stream");
            if !api_key.is_empty() {
                req = req.header("Authorization", format!("Bearer {api_key}"));
            }
            req.json(body).send()
        };

        let mut resp = send_once(&payload)
            .await
            .map_err(|e| format!("网络请求失败：{e}"))?;

        if resp.status().as_u16() == 400
            && (payload.get("thinking").is_some() || payload.get("reasoning_effort").is_some())
        {
            if let Some(obj) = payload.as_object_mut() {
                obj.remove("thinking");
                obj.remove("reasoning_effort");
                if !obj.contains_key("max_completion_tokens") {
                    obj.insert("temperature".into(), json!(0.1));
                }
            }
            resp = send_once(&payload)
                .await
                .map_err(|e| format!("网络重试失败：{e}"))?;
        }

        if !resp.status().is_success() {
            let code = resp.status().as_u16();
            return Err(format!(
                "接口返回 HTTP {code}（请核对当前服务商 API Key 与模型 ID {model} 是否匹配）"
            ));
        }

        let mut accumulated = String::new();
        let mut is_first = true;
        let mut ttft_ms = 0u64;
        let mut line_buf = String::new();
        let mut stream = resp.bytes_stream();

        while let Some(chunk_res) = stream.next().await {
            let bytes = chunk_res.map_err(|e| format!("SSE 流中断：{e}"))?;
            line_buf.push_str(&String::from_utf8_lossy(&bytes));

            while let Some(nl_pos) = line_buf.find('\n') {
                let raw_line = line_buf[..nl_pos].trim().to_string();
                line_buf.drain(..=nl_pos);

                let Some(data_part) = raw_line.strip_prefix("data:") else {
                    continue;
                };
                let data_str = data_part.trim();
                if data_str == "[DONE]" {
                    return Ok((accumulated.trim().to_string(), ttft_ms));
                }
                let Ok(obj) = serde_json::from_str::<Value>(data_str) else {
                    continue;
                };
                let Some(token) = obj
                    .pointer("/choices/0/delta/content")
                    .and_then(|v| v.as_str())
                else {
                    continue;
                };
                if token.is_empty() {
                    continue;
                }

                let spaced = Self::clean_and_space_stream_token(
                    token,
                    &accumulated,
                    config.enable_pangu_spacing,
                );
                if spaced.is_empty() {
                    continue;
                }
                accumulated.push_str(&spaced);
                if is_first {
                    ttft_ms = start.elapsed().as_millis() as u64;
                    if let Some(cb) = on_stream_chunk.as_mut() {
                        cb(spaced, true);
                    }
                    is_first = false;
                } else if let Some(cb) = on_stream_chunk.as_mut() {
                    cb(spaced, false);
                }
            }
        }

        Ok((accumulated.trim().to_string(), ttft_ms))
    }

    async fn call_anthropic_messages_sse<F>(
        &self,
        base_url: &str,
        model: &str,
        api_key: &str,
        system_prompt: &str,
        user_content: &str,
        max_tokens: usize,
        enable_pangu_spacing: bool,
        on_stream_chunk: &mut Option<F>,
    ) -> Result<(String, u64), String>
    where
        F: FnMut(String, bool) + Send,
    {
        let start = Instant::now();
        let endpoint = Self::normalize_anthropic_messages_endpoint(base_url);
        let client = self.client_for(base_url);

        let payload = json!({
            "model": model,
            "max_tokens": max_tokens.max(256),
            "temperature": 0.1,
            "stream": true,
            "system": system_prompt,
            "messages": [
                {"role": "user", "content": user_content}
            ]
        });

        let mut req = client
            .post(&endpoint)
            .header("Content-Type", "application/json")
            .header("Accept", "text/event-stream")
            .header("anthropic-version", "2023-06-01");
        if !api_key.is_empty() {
            req = req.header("x-api-key", api_key);
        }

        let resp = req
            .json(&payload)
            .send()
            .await
            .map_err(|e| format!("Anthropic 请求失败：{e}"))?;
        if !resp.status().is_success() {
            let code = resp.status().as_u16();
            return Err(format!(
                "Anthropic 接口返回 HTTP {code}（请核对 Claude API Key 与模型 ID {model}）"
            ));
        }

        let mut accumulated = String::new();
        let mut is_first = true;
        let mut ttft_ms = 0u64;
        let mut line_buf = String::new();
        let mut stream = resp.bytes_stream();

        while let Some(chunk_res) = stream.next().await {
            let bytes = chunk_res.map_err(|e| format!("Anthropic SSE 中断：{e}"))?;
            line_buf.push_str(&String::from_utf8_lossy(&bytes));

            while let Some(nl_pos) = line_buf.find('\n') {
                let raw_line = line_buf[..nl_pos].trim().to_string();
                line_buf.drain(..=nl_pos);

                let Some(data_part) = raw_line.strip_prefix("data:") else {
                    continue;
                };
                let Ok(obj) = serde_json::from_str::<Value>(data_part.trim()) else {
                    continue;
                };
                if obj.get("type").and_then(|v| v.as_str()) != Some("content_block_delta") {
                    continue;
                }
                let Some(token) = obj.pointer("/delta/text").and_then(|v| v.as_str()) else {
                    continue;
                };
                if token.is_empty() {
                    continue;
                }

                let spaced =
                    Self::clean_and_space_stream_token(token, &accumulated, enable_pangu_spacing);
                if spaced.is_empty() {
                    continue;
                }
                accumulated.push_str(&spaced);
                if is_first {
                    ttft_ms = start.elapsed().as_millis() as u64;
                    if let Some(cb) = on_stream_chunk.as_mut() {
                        cb(spaced, true);
                    }
                    is_first = false;
                } else if let Some(cb) = on_stream_chunk.as_mut() {
                    cb(spaced, false);
                }
            }
        }

        Ok((accumulated.trim().to_string(), ttft_ms))
    }

    fn clean_and_space_stream_token(
        token: &str,
        accumulated: &str,
        enable_pangu_spacing: bool,
    ) -> String {
        let clean = token
            .replace("<raw_speech>", "")
            .replace("</raw_speech>", "");
        if clean.is_empty() {
            return String::new();
        }
        if enable_pangu_spacing {
            if let (Some(last_c), Some(first_c)) = (accumulated.chars().last(), clean.chars().next())
            {
                let is_cjk = |c: char| ('\u{4E00}'..='\u{9FA5}').contains(&c);
                let last_is_cjk = is_cjk(last_c);
                let first_is_ascii_alnum = first_c.is_ascii_alphanumeric();
                let last_is_ascii_alnum = last_c.is_ascii_alphanumeric() || last_c == '%';
                let first_is_cjk = is_cjk(first_c);
                if (last_is_cjk && first_is_ascii_alnum) || (last_is_ascii_alnum && first_is_cjk) {
                    return format!(" {clean}");
                }
            }
        }
        clean
    }

    /// Deterministic 0ms CJK-Latin Pangu Spacing + Spoken Percentage ITN + Clean Punctuation + IM Trailing Period Rule.
    pub fn apply_post_formatting_rules(
        text: &str,
        context: &ActiveScreenContext,
        config: &LLMConfig,
    ) -> String {
        let mut result = text.trim().to_string();
        if result.is_empty() {
            return String::new();
        }

        result = PERCENT_RE.replace_all(&result, "$1%").into_owned();
        result = MULTI_NEWLINE_RE.replace_all(&result, "\n").into_owned();

        if !context.is_code_or_terminal() {
            result = MD_BOLD_RE.replace_all(&result, "$1").into_owned();
            result = MD_HEADING_RE.replace_all(&result, "").into_owned();
            result = CJK_Q_RE.replace_all(&result, "$1？").into_owned();
            result = CJK_BANG_RE.replace_all(&result, "$1！").into_owned();
        }

        if config.enable_pangu_spacing {
            result = PANGU_CJK_ASCII_RE.replace_all(&result, "$1 $2").into_owned();
            result = PANGU_ASCII_CJK_RE.replace_all(&result, "$1 $2").into_owned();
        }

        if config.strip_trailing_period_in_chat_apps
            && (context.is_instant_messaging() || context.is_strict_shell_terminal())
            && !result.contains('\n')
        {
            if let Some(stripped) = result
                .strip_suffix('。')
                .or_else(|| result.strip_suffix('.'))
            {
                result = stripped.to_string();
            }
        }
        result
    }

    fn contains_stutter_repetition(text: &str) -> bool {
        let chars: Vec<char> = text.chars().collect();
        let n = chars.len();
        for len in 2..=4 {
            if n < len * 2 {
                continue;
            }
            for i in 0..=(n - len * 2) {
                if chars[i..i + len] == chars[i + len..i + len * 2] {
                    return true;
                }
            }
        }
        false
    }
}

fn tail_chars(s: &str, max_chars: usize) -> String {
    let chars: Vec<char> = s.chars().collect();
    if chars.len() <= max_chars {
        s.to_string()
    } else {
        chars[chars.len() - max_chars..].iter().collect()
    }
}

fn replace_case_insensitive(input: &str, needle: &str, replacement: &str) -> String {
    if needle.is_empty() {
        return input.to_string();
    }
    let pattern = format!("(?i){}", regex::escape(needle));
    match Regex::new(&pattern) {
        Ok(re) => re.replace_all(input, regex::NoExpand(replacement)).into_owned(),
        Err(_) => input.to_string(),
    }
}

fn replace_ascii_word_boundary_ci(input: &str, needle: &str, replacement: &str) -> String {
    if needle.is_empty() {
        return input.to_string();
    }
    let escaped = regex::escape(needle);
    let Ok(re) = Regex::new(&format!("(?i){escaped}")) else {
        return input.to_string();
    };
    let mut out = String::with_capacity(input.len());
    let mut last_end = 0usize;

    for m in re.find_iter(input) {
        let start = m.start();
        let end = m.end();
        let prev_is_ascii_alpha = input[..start]
            .chars()
            .next_back()
            .map(|c| c.is_ascii_alphabetic())
            .unwrap_or(false);
        let next_is_ascii_alpha = input[end..]
            .chars()
            .next()
            .map(|c| c.is_ascii_alphabetic())
            .unwrap_or(false);
        if !prev_is_ascii_alpha && !next_is_ascii_alpha {
            out.push_str(&input[last_end..start]);
            out.push_str(replacement);
            last_end = end;
        }
    }
    out.push_str(&input[last_end..]);
    out
}
