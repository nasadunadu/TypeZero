use crate::models::{LexiconCategory, LexiconEntry};
use once_cell::sync::Lazy;
use parking_lot::RwLock;
use pinyin::ToPinyin;
use regex::Regex;
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};

/// Zero-dependency Mandarin Pinyin + Fuzzy Accent Skeleton normalizer.
/// Enables <0.5ms homophone & southern/northern accent fuzzy recall
/// (`zh/z`, `ch/c`, `sh/s`, `ing/in`, `eng/en`, `ang/an`, `ong/un`, `n/l`).
pub struct PhoneticIndexer;

impl PhoneticIndexer {
    pub fn syllables(text: &str) -> Vec<String> {
        if text.is_empty() {
            return Vec::new();
        }
        let mut out = Vec::new();
        let mut ascii_buf = String::new();

        for ch in text.chars() {
            if let Some(py) = ch.to_pinyin() {
                if !ascii_buf.is_empty() {
                    out.push(std::mem::take(&mut ascii_buf));
                }
                let plain = py.plain().to_ascii_lowercase();
                if !plain.is_empty() {
                    out.push(plain);
                }
            } else if ch.is_ascii_alphanumeric() {
                ascii_buf.push(ch.to_ascii_lowercase());
            } else if !ascii_buf.is_empty() {
                out.push(std::mem::take(&mut ascii_buf));
            }
        }
        if !ascii_buf.is_empty() {
            out.push(ascii_buf);
        }
        out
    }

    pub fn normalize(text: &str) -> String {
        Self::syllables(text).concat()
    }

    /// Accent-tolerant fuzzy phonetic skeleton:
    /// collapses `zh/ch/sh -> z/c/s`, syllable-initial `l -> n`,
    /// and trailing `ing/eng/ang/ong -> in/en/an/un`.
    pub fn fuzzy_skeleton(text: &str) -> String {
        let syls = Self::syllables(text);
        if syls.is_empty() {
            return String::new();
        }
        let mut out = String::new();
        for s in syls {
            let mut v = if let Some(rest) = s.strip_prefix("zh") {
                format!("z{rest}")
            } else if let Some(rest) = s.strip_prefix("ch") {
                format!("c{rest}")
            } else if let Some(rest) = s.strip_prefix("sh") {
                format!("s{rest}")
            } else if let Some(rest) = s.strip_prefix('l') {
                format!("n{rest}")
            } else {
                s
            };

            if let Some(stem) = v.strip_suffix("ing") {
                v = format!("{stem}in");
            } else if let Some(stem) = v.strip_suffix("eng") {
                v = format!("{stem}en");
            } else if let Some(stem) = v.strip_suffix("ang") {
                v = format!("{stem}an");
            } else if let Some(stem) = v.strip_suffix("ong") {
                v = format!("{stem}un");
            }
            out.push_str(&v);
        }
        out
    }
}

static DISPOSABLE_RE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"^(?:[vV]?\d+(?:[.\-]\d+)*|\d+[年月日时分秒天周月个次项%]?)$").unwrap()
});
static HOTWORD_ACRONYM_RE: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"(?:^|[^A-Za-z])([A-Z]{2,10}|[A-Z][A-Za-z0-9.\-]{2,15})(?:[^A-Za-z]|$)").unwrap());
static BOLD_ENTITY_RE: Lazy<Regex> = Lazy::new(|| Regex::new(r"\*\*([^*]{2,16})\*\*").unwrap());
static CODE_ENTITY_RE: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"`([A-Za-z0-9_\-\.]{2,20})`").unwrap());
static CAMEL_ENTITY_RE: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"\b([A-Z][A-Za-z0-9]{2,15})\b").unwrap());

const COMMON_WORDS: &[&str] = &[
    "今天", "明天", "昨天", "现在", "刚才", "马上", "以后", "之前", "时候", "时间", "可以",
    "没有", "不是", "好的", "没问题", "什么", "怎么", "为什么", "应该", "需要", "因为", "所以",
    "但是", "如果", "然后", "不过", "另外", "还有", "而且", "或者", "这个", "那个", "这些", "那些",
    "这样", "那样", "这里", "那里", "自己", "大家", "一下", "一起", "一直", "一定", "一点", "一般",
    "已经", "还是", "就是", "只是", "知道", "觉得", "希望", "看看", "意思", "问题", "地方", "东西",
    "事情", "工作",
];

const CJK_GRAMMAR_PARTICLES: &str =
    "的得地了着过是我你他她它们在有和与跟让把被给对向从到去来就都也还又再很太更最不没别这那哪";

const COMMON_CAPITALIZED_STARTERS: &[&str] = &[
    "the", "this", "that", "these", "those", "when", "what", "where", "which", "while", "with",
    "from", "into", "over", "after", "before", "under", "about", "there", "their",
];

pub struct PersonalLexiconStore {
    entries: RwLock<Vec<LexiconEntry>>,
    storage_path: PathBuf,
}

impl PersonalLexiconStore {
    pub fn new(custom_storage_path: Option<PathBuf>) -> Self {
        let storage_path = custom_storage_path.unwrap_or_else(|| {
            let base = dirs::data_dir().unwrap_or_else(|| PathBuf::from("."));
            let dir = base.join("TypeZero");
            let _ = fs::create_dir_all(&dir);
            dir.join("lexicon.json")
        });
        let store = Self {
            entries: RwLock::new(Vec::new()),
            storage_path,
        };
        store.load();
        store
    }

    fn seed_defaults() -> Vec<LexiconEntry> {
        vec![
            LexiconEntry::new(
                "DeepSeek",
                vec!["迪普西克".into(), "deep seek".into()],
                PhoneticIndexer::normalize("DeepSeek"),
                LexiconCategory::Project,
                5,
            ),
            LexiconEntry::new(
                "TypeZero",
                vec!["type zero".into(), "太普零".into()],
                PhoneticIndexer::normalize("TypeZero"),
                LexiconCategory::Project,
                5,
            ),
        ]
    }

    pub fn load(&self) {
        if !self.storage_path.exists() {
            *self.entries.write() = Self::seed_defaults();
            self.save();
            return;
        }

        let Ok(bytes) = fs::read(&self.storage_path) else {
            *self.entries.write() = Self::seed_defaults();
            return;
        };
        if bytes.is_empty() {
            *self.entries.write() = Self::seed_defaults();
            self.save();
            return;
        }

        if let Ok(raw_items) = serde_json::from_slice::<Vec<serde_json::Value>>(&bytes) {
            let mut valid = Vec::with_capacity(raw_items.len());
            for val in raw_items {
                if let Ok(mut entry) = serde_json::from_value::<LexiconEntry>(val) {
                    entry.term = entry.term.trim().to_string();
                    if !entry.term.is_empty() {
                        if entry.phonetic_key.is_empty() {
                            entry.phonetic_key = PhoneticIndexer::normalize(&entry.term);
                        }
                        valid.push(entry);
                    }
                }
            }
            if !valid.is_empty() {
                *self.entries.write() = valid;
                return;
            }
        }

        // Preserve unreadable file as backup before falling back in memory
        if let Some(parent) = self.storage_path.parent() {
            let _ = fs::write(parent.join("lexicon.corrupt.bak.json"), &bytes);
        }
        *self.entries.write() = Self::seed_defaults();
    }

    pub fn save(&self) {
        let snapshot = self.entries.read().clone();
        if let Some(parent) = self.storage_path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        if let Ok(data) = serde_json::to_vec_pretty(&snapshot) {
            let tmp = self.storage_path.with_extension("json.tmp");
            if fs::write(&tmp, &data).is_ok() {
                let _ = fs::rename(&tmp, &self.storage_path);
            } else {
                let _ = fs::write(&self.storage_path, &data);
            }
        }
    }

    pub fn entries(&self) -> Vec<LexiconEntry> {
        self.entries.read().clone()
    }

    pub fn upsert(
        &self,
        term: &str,
        aliases: Vec<String>,
        category: LexiconCategory,
        weight: i32,
    ) {
        let clean_term = term.trim().to_string();
        if clean_term.chars().count() < 2 {
            return;
        }
        let clean_aliases: Vec<String> = aliases
            .into_iter()
            .map(|a| a.trim().to_string())
            .filter(|a| !a.is_empty() && !a.eq_ignore_ascii_case(&clean_term))
            .collect();

        {
            let mut entries = self.entries.write();
            if let Some(existing) = entries
                .iter_mut()
                .find(|e| e.term.eq_ignore_ascii_case(&clean_term))
            {
                let mut merged: HashSet<String> = existing.aliases.iter().cloned().collect();
                for a in clean_aliases {
                    merged.insert(a);
                }
                let mut sorted: Vec<String> = merged.into_iter().collect();
                sorted.sort();
                existing.aliases = sorted;
                existing.weight = existing.weight.max(weight);
                existing.phonetic_key = PhoneticIndexer::normalize(&clean_term);
            } else {
                let phonetic = PhoneticIndexer::normalize(&clean_term);
                entries.insert(
                    0,
                    LexiconEntry::new(clean_term, clean_aliases, phonetic, category, weight),
                );
            }
        }
        self.save();
    }

    pub fn bulk_upsert(&self, new_items: Vec<(String, Vec<String>, LexiconCategory)>) -> usize {
        let mut added = 0usize;
        {
            let mut entries = self.entries.write();
            for (term, aliases, category) in new_items {
                let clean = term.trim().to_string();
                let char_len = clean.chars().count();
                if !(2..=36).contains(&char_len) {
                    continue;
                }
                if let Some(existing) = entries
                    .iter_mut()
                    .find(|e| e.term.eq_ignore_ascii_case(&clean))
                {
                    let mut merged: HashSet<String> = existing.aliases.iter().cloned().collect();
                    for a in aliases {
                        let t = a.trim().to_string();
                        if !t.is_empty() && !t.eq_ignore_ascii_case(&clean) {
                            merged.insert(t);
                        }
                    }
                    let mut sorted: Vec<String> = merged.into_iter().collect();
                    sorted.sort();
                    existing.aliases = sorted;
                    existing.weight += 1;
                } else {
                    let phonetic = PhoneticIndexer::normalize(&clean);
                    entries.push(LexiconEntry::new(clean, aliases, phonetic, category, 2));
                    added += 1;
                }
            }
            entries.sort_by(|a, b| b.weight.cmp(&a.weight));
        }
        self.save();
        added
    }

    pub fn remove(&self, id: &str) {
        {
            let mut entries = self.entries.write();
            entries.retain(|e| e.id != id);
        }
        self.save();
    }

    pub fn remove_batch(&self, ids: &HashSet<String>) {
        if ids.is_empty() {
            return;
        }
        {
            let mut entries = self.entries.write();
            entries.retain(|e| !ids.contains(&e.id));
        }
        self.save();
    }

    /// Updates an existing entry in-place; if renamed to match another existing entry,
    /// automatically merges aliases into the target entry, preserves old wrong term as alias, and deduplicates!
    pub fn update_entry(
        &self,
        id: &str,
        new_term: &str,
        new_aliases: Vec<String>,
        new_category: LexiconCategory,
        new_weight: i32,
    ) {
        let clean_term = new_term.trim().to_string();
        if clean_term.is_empty() {
            return;
        }

        {
            let mut entries = self.entries.write();
            let Some(source_idx) = entries.iter().position(|e| e.id == id) else {
                return;
            };
            let old_term = entries[source_idx].term.clone();
            let mut cleaned_aliases: Vec<String> = new_aliases
                .into_iter()
                .map(|a| a.trim().to_string())
                .filter(|a| !a.is_empty() && !a.eq_ignore_ascii_case(&clean_term))
                .collect();

            if !old_term.eq_ignore_ascii_case(&clean_term) && old_term.chars().count() >= 2 {
                if !cleaned_aliases
                    .iter()
                    .any(|a| a.eq_ignore_ascii_case(&old_term))
                {
                    cleaned_aliases.insert(0, old_term);
                }
            }

            if let Some(collision_idx) = entries
                .iter()
                .position(|e| e.id != id && e.term.eq_ignore_ascii_case(&clean_term))
            {
                let mut combined: HashSet<String> =
                    entries[collision_idx].aliases.iter().cloned().collect();
                for a in cleaned_aliases {
                    if !a.eq_ignore_ascii_case(&clean_term) {
                        combined.insert(a);
                    }
                }
                let mut sorted: Vec<String> = combined.into_iter().collect();
                sorted.sort();
                entries[collision_idx].aliases = sorted;
                entries[collision_idx].category = new_category;
                entries[collision_idx].weight = entries[collision_idx].weight.max(new_weight);
                entries[collision_idx].phonetic_key = PhoneticIndexer::normalize(&clean_term);
                entries.remove(source_idx);
            } else {
                let mut dedup: HashSet<String> = cleaned_aliases.into_iter().collect();
                dedup.retain(|a| !a.eq_ignore_ascii_case(&clean_term));
                let mut sorted: Vec<String> = dedup.into_iter().collect();
                sorted.sort();
                entries[source_idx].term = clean_term.clone();
                entries[source_idx].aliases = sorted;
                entries[source_idx].category = new_category;
                entries[source_idx].weight = new_weight;
                entries[source_idx].phonetic_key = PhoneticIndexer::normalize(&clean_term);
            }
        }
        self.save();
    }

    pub fn is_common_or_disposable_auto_learn_term(term: &str) -> bool {
        let trimmed = term.trim();
        if trimmed.chars().count() < 2 {
            return true;
        }
        if trimmed.contains('/') || trimmed.contains('\\') || trimmed.contains("://") {
            return true;
        }
        if DISPOSABLE_RE.is_match(trimmed) {
            return true;
        }
        COMMON_WORDS.contains(&trimmed)
    }

    /// Extracts clean word-level user corrections (1–10 chars) across single-line & multi-paragraph (`\n`) edits.
    pub fn learn_from_manual_edit_if_applicable(
        &self,
        injected_text: &str,
        edited_box_value: &str,
    ) -> Option<(String, String)> {
        let orig = injected_text.trim();
        let edited = edited_box_value.trim();
        if orig.chars().count() < 3 || edited.chars().count() < 3 || orig == edited {
            return None;
        }

        let orig_lines: Vec<&str> = orig
            .lines()
            .map(str::trim)
            .filter(|l| l.chars().count() >= 3)
            .collect();
        let edited_lines: Vec<&str> = edited
            .lines()
            .map(str::trim)
            .filter(|l| l.chars().count() >= 3)
            .collect();

        for o_line in &orig_lines {
            if edited_lines.contains(o_line) {
                continue;
            }
            for e_line in &edited_lines {
                if let Some((wrong, corrected)) =
                    Self::extract_single_word_replacement(o_line, e_line)
                {
                    if Self::is_common_or_disposable_auto_learn_term(&corrected) {
                        continue;
                    }
                    self.upsert(
                        &corrected,
                        vec![wrong.clone()],
                        LexiconCategory::AutoLearned,
                        8,
                    );
                    return Some((wrong, corrected));
                }
            }
        }
        None
    }

    /// Permanently learns when user highlights a wrong word/phrase and uses voice rewrite.
    pub fn learn_from_selection_rewrite(
        &self,
        selected_text: &str,
        rewritten_text: &str,
    ) -> Option<(String, String)> {
        let wrong = selected_text.trim();
        let right = rewritten_text.trim();
        if wrong.is_empty() || right.is_empty() || wrong == right {
            return None;
        }
        let has_stopper = |s: &str| {
            s.chars()
                .any(|c| "，。！？；：,.;!?\n".contains(c))
        };

        let wrong_len = wrong.chars().count();
        let right_len = right.chars().count();
        if (1..=12).contains(&wrong_len)
            && (2..=16).contains(&right_len)
            && !has_stopper(wrong)
            && !has_stopper(right)
        {
            self.upsert(right, vec![wrong.to_string()], LexiconCategory::AutoLearned, 9);
            return Some((wrong.to_string(), right.to_string()));
        }

        if let Some((w, r)) = self.learn_from_manual_edit_if_applicable(wrong, right) {
            self.upsert(&r, vec![w.clone()], LexiconCategory::AutoLearned, 9);
            return Some((w, r));
        }
        None
    }

    fn extract_single_word_replacement(
        orig_line: &str,
        edited_line: &str,
    ) -> Option<(String, String)> {
        let orig_chars: Vec<char> = orig_line.chars().collect();
        let mut cand_chars: Vec<char> = edited_line.chars().collect();

        if cand_chars.len() > orig_chars.len() + 6 {
            let anchor_len = orig_chars.len().min(4);
            let head_anchor: String = orig_chars[..anchor_len].iter().collect();
            if let Some(byte_idx) = edited_line.rfind(&head_anchor) {
                cand_chars = edited_line[byte_idx..].chars().collect();
            } else {
                let keep = cand_chars.len().min(orig_chars.len() + 6);
                cand_chars = cand_chars[cand_chars.len() - keep..].to_vec();
            }
        }

        if cand_chars.len().abs_diff(orig_chars.len()) > 8 {
            return None;
        }

        let min_len = orig_chars.len().min(cand_chars.len());
        let mut prefix = 0usize;
        while prefix < min_len && orig_chars[prefix] == cand_chars[prefix] {
            prefix += 1;
        }
        let mut suffix = 0usize;
        while suffix < (min_len - prefix)
            && orig_chars[orig_chars.len() - 1 - suffix]
                == cand_chars[cand_chars.len() - 1 - suffix]
        {
            suffix += 1;
        }

        let required_common = ((orig_chars.len() as f64) * 0.58) as usize;
        if prefix + suffix < required_common.max(2) {
            return None;
        }

        let edit_end_b = cand_chars.len() - suffix;
        // Snap single-character edits outward to whole ASCII tokens or adjacent non-particle CJK characters
        // (e.g. "让星合跟进" -> "让星河跟进": raw diff is "合"->"河", expands left across "星" -> "星合"->"星河"!).
        if edit_end_b > prefix {
            let mut snap_start = prefix;
            let mut snap_end = edit_end_b;

            // Expand across contiguous ASCII alphanumeric tokens
            if cand_chars[snap_start].is_ascii_alphanumeric() {
                while snap_start > 0 && cand_chars[snap_start - 1].is_ascii_alphanumeric() {
                    snap_start -= 1;
                }
                while snap_end < cand_chars.len() && cand_chars[snap_end].is_ascii_alphanumeric() {
                    snap_end += 1;
                }
            } else if snap_end - snap_start == 1 {
                // Single CJK char edit: prefer merging with an adjacent non-particle CJK neighbor to recover 2-char names!
                let is_non_particle_cjk = |c: char| {
                    ('\u{4E00}'..='\u{9FA5}').contains(&c) && !CJK_GRAMMAR_PARTICLES.contains(c)
                };
                if snap_start > 0 && is_non_particle_cjk(cand_chars[snap_start - 1]) {
                    snap_start -= 1;
                } else if snap_end < cand_chars.len() && is_non_particle_cjk(cand_chars[snap_end]) {
                    snap_end += 1;
                }
            }

            prefix = prefix.min(snap_start);
            suffix = suffix.min(cand_chars.len().saturating_sub(snap_end));
        }

        let trim_chars: &[char] = &[
            ' ', '\t', '\r', '\n', '，', '。', '！', '？', '；', '：', '、', '“', '”', '‘', '’',
            '"', '\'', '(', ')', '（', '）',
        ];
        if prefix > orig_chars.len().saturating_sub(suffix)
            || prefix > cand_chars.len().saturating_sub(suffix)
        {
            return None;
        }
        let wrong_slice: String = orig_chars[prefix..orig_chars.len() - suffix]
            .iter()
            .collect::<String>()
            .trim_matches(trim_chars)
            .to_string();
        let right_slice: String = cand_chars[prefix..cand_chars.len() - suffix]
            .iter()
            .collect::<String>()
            .trim_matches(trim_chars)
            .to_string();

        let has_forbidden = |s: &str| s.chars().any(|c| "，。！？；：\n".contains(c));
        let w_len = wrong_slice.chars().count();
        let r_len = right_slice.chars().count();
        if (1..=10).contains(&w_len)
            && (2..=16).contains(&r_len)
            && wrong_slice != right_slice
            && !has_forbidden(&wrong_slice)
            && !has_forbidden(&right_slice)
        {
            Some((wrong_slice, right_slice))
        } else {
            None
        }
    }

    pub fn top_acoustic_contextual_strings(&self, context_hint: &str, limit: usize) -> Vec<String> {
        let entries = self.entries.read();
        Self::rank_hotwords(&entries, context_hint, limit)
    }

    pub fn rank_hotwords(entries: &[LexiconEntry], context_hint: &str, limit: usize) -> Vec<String> {
        let mut result = Vec::new();
        let mut seen_lower = HashSet::new();

        let append_unique = |result: &mut Vec<String>, seen_lower: &mut HashSet<String>, raw_word: &str| {
            let w = raw_word.trim();
            let len = w.chars().count();
            if !(2..=24).contains(&len) {
                return;
            }
            let lower = w.to_lowercase();
            if seen_lower.contains(&lower) || COMMON_CAPITALIZED_STARTERS.contains(&lower.as_str()) {
                return;
            }
            seen_lower.insert(lower);
            result.push(w.to_string());
        };

        if !context_hint.is_empty() {
            for cap in HOTWORD_ACRONYM_RE.captures_iter(context_hint).take(12) {
                if let Some(m) = cap.get(1) {
                    append_unique(&mut result, &mut seen_lower, m.as_str());
                }
            }
        }

        let hint_lower = context_hint.to_lowercase();
        let mut ranked: Vec<&LexiconEntry> = entries.iter().collect();
        ranked.sort_by(|lhs, rhs| {
            let l_ctx = if !hint_lower.is_empty() && hint_lower.contains(&lhs.term.to_lowercase()) {
                100
            } else {
                0
            };
            let r_ctx = if !hint_lower.is_empty() && hint_lower.contains(&rhs.term.to_lowercase()) {
                100
            } else {
                0
            };
            let l_score = l_ctx + lhs.weight * 10 + (lhs.hit_count * 2).min(35);
            let r_score = r_ctx + rhs.weight * 10 + (rhs.hit_count * 2).min(35);
            r_score.cmp(&l_score)
        });

        for item in ranked {
            if result.len() >= limit {
                break;
            }
            append_unique(&mut result, &mut seen_lower, &item.term);
        }
        result
    }

    pub fn record_term_hits(&self, matched: &[LexiconEntry]) {
        if matched.is_empty() {
            return;
        }
        let ids: HashSet<&str> = matched.iter().map(|e| e.id.as_str()).collect();
        let mut changed = false;
        {
            let mut entries = self.entries.write();
            for entry in entries.iter_mut() {
                if ids.contains(entry.id.as_str()) {
                    entry.hit_count += 1;
                    changed = true;
                }
            }
        }
        if changed {
            self.save();
        }
    }

    /// Dual-Pool Sub-millisecond Recall (Pinned Core + Fuzzy Accent Skeleton Dynamic Match).
    pub fn recall_relevant_terms(
        &self,
        raw_transcript: &str,
        active_window_title: &str,
        limit: usize,
    ) -> Vec<LexiconEntry> {
        let entries = self.entries.read();
        if raw_transcript.is_empty() || entries.is_empty() {
            return Vec::new();
        }
        let raw_lower = raw_transcript.to_lowercase();
        let utterance_phonetic = PhoneticIndexer::normalize(raw_transcript);
        let utterance_fuzzy = PhoneticIndexer::fuzzy_skeleton(raw_transcript);
        let window_lower = active_window_title.to_lowercase();

        let mut scored: Vec<(&LexiconEntry, i32)> = Vec::with_capacity(entries.len().min(64));

        for entry in entries.iter() {
            let mut score = 0i32;

            if raw_lower.contains(&entry.term.to_lowercase()) {
                score += 85;
            }
            for alias in &entry.aliases {
                if alias.is_empty() {
                    continue;
                }
                if raw_lower.contains(&alias.to_lowercase()) {
                    score += 140;
                } else {
                    let alias_fuzzy = PhoneticIndexer::fuzzy_skeleton(alias);
                    if alias_fuzzy.len() >= 3 && utterance_fuzzy.contains(&alias_fuzzy) {
                        score += 105;
                    }
                }
            }

            let entry_fuzzy = PhoneticIndexer::fuzzy_skeleton(&entry.term);
            if entry.phonetic_key.len() >= 4 && utterance_phonetic.contains(&entry.phonetic_key) {
                score += 110;
            } else if entry_fuzzy.len() >= 4 && utterance_fuzzy.contains(&entry_fuzzy) {
                score += 98;
            } else if entry_fuzzy.len() >= 6 {
                let prefix_len = (entry_fuzzy.len() - 2).max(4);
                let prefix_key = &entry_fuzzy[..prefix_len];
                if utterance_fuzzy.contains(prefix_key) {
                    score += 58;
                }
            }

            if !window_lower.is_empty() && window_lower.contains(&entry.term.to_lowercase()) {
                score += 70;
            }

            if score > 0 {
                scored.push((entry, score + (entry.weight * 4).min(40)));
            }
        }

        scored.sort_by(|a, b| b.1.cmp(&a.1));
        let dynamic_cap = limit.saturating_sub(10).max(12);
        let mut selected: Vec<LexiconEntry> = scored
            .into_iter()
            .take(dynamic_cap)
            .map(|(e, _)| e.clone())
            .collect();
        let mut existing_ids: HashSet<String> = selected.iter().map(|e| e.id.clone()).collect();

        let mut pinned_core: Vec<&LexiconEntry> =
            entries.iter().filter(|e| e.weight >= 9).collect();
        pinned_core.sort_by(|a, b| b.weight.cmp(&a.weight));
        for core in pinned_core.into_iter().take(12) {
            if selected.len() >= limit {
                break;
            }
            if existing_ids.insert(core.id.clone()) {
                selected.push(core.clone());
            }
        }

        if selected.len() < 10 {
            let mut by_weight: Vec<&LexiconEntry> = entries.iter().collect();
            by_weight.sort_by(|a, b| b.weight.cmp(&a.weight));
            for top in by_weight {
                if selected.len() >= 10 {
                    break;
                }
                if existing_ids.insert(top.id.clone()) {
                    selected.push(top.clone());
                }
            }
        }
        selected
    }

    /// Scans a local folder of Markdown / TXT / CSV notes to extract recurring proper nouns.
    pub fn import_from_markdown_folder(&self, folder: &Path, max_entries: usize) -> usize {
        let mut term_freq: HashMap<String, usize> = HashMap::new();
        let mut file_count = 0usize;
        Self::walk_notes_dir(folder, &mut term_freq, &mut file_count);

        let mut items: Vec<(String, usize)> = term_freq
            .into_iter()
            .filter(|(_, count)| *count >= 2)
            .collect();
        items.sort_by(|a, b| b.1.cmp(&a.1));

        let picked = items
            .into_iter()
            .take(max_entries)
            .map(|(term, _)| (term, Vec::new(), LexiconCategory::Memo))
            .collect();
        self.bulk_upsert(picked)
    }

    fn walk_notes_dir(dir: &Path, freq: &mut HashMap<String, usize>, file_count: &mut usize) {
        if *file_count > 400 {
            return;
        }
        let Ok(read_dir) = fs::read_dir(dir) else {
            return;
        };
        for entry in read_dir.flatten() {
            if *file_count > 400 {
                break;
            }
            let path = entry.path();
            if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                if name.starts_with('.') {
                    continue;
                }
            }
            if path.is_dir() {
                Self::walk_notes_dir(&path, freq, file_count);
            } else if path.is_file() {
                let ext = path
                    .extension()
                    .and_then(|e| e.to_str())
                    .unwrap_or("")
                    .to_lowercase();
                if matches!(ext.as_str(), "md" | "txt" | "csv") {
                    *file_count += 1;
                    if let Ok(content) = fs::read_to_string(&path) {
                        for entity in Self::extract_entities_from_note(&content) {
                            *freq.entry(entity).or_insert(0) += 1;
                        }
                    }
                }
            }
        }
    }

    /// Read-only Windows Chrome / Edge browser history proper-noun importer.
    /// Dynamically loads Windows' built-in `winsqlite3.dll` (present on every Win10/11 PC) — zero C build dependency!
    pub fn import_from_local_browser_history(&self, max_entries: usize) -> usize {
        let titles = Self::read_browser_history_titles();
        if titles.is_empty() {
            return 0;
        }

        let stop_words: HashSet<&str> = [
            "Google",
            "Search",
            "GitHub",
            "YouTube",
            "bilibili",
            "哔哩哔哩",
            "知乎",
            "百度",
            "必应",
            "Bing",
            "Microsoft",
            "首页",
            "登录",
            "管理",
            "控制台",
            "文档",
            "搜索",
            "官网",
            "Home",
            "Dashboard",
            "Login",
        ]
        .into_iter()
        .collect();

        let mut token_counts: HashMap<String, usize> = HashMap::new();
        for title in titles {
            for candidate in Self::extract_clean_entities_from_title(&title) {
                if !stop_words.contains(candidate.as_str()) {
                    *token_counts.entry(candidate).or_insert(0) += 1;
                }
            }
        }

        let mut sorted: Vec<(String, usize)> = token_counts
            .into_iter()
            .filter(|(_, c)| *c >= 2)
            .collect();
        sorted.sort_by(|a, b| b.1.cmp(&a.1));

        let picked = sorted
            .into_iter()
            .take(max_entries)
            .map(|(term, _)| (term, Vec::new(), LexiconCategory::Browser))
            .collect();
        self.bulk_upsert(picked)
    }

    #[cfg(target_os = "windows")]
    fn read_browser_history_titles() -> Vec<String> {
        use std::ffi::{CStr, CString};
        use std::os::raw::{c_char, c_int, c_void};

        let Some(local_app_data) = dirs::data_local_dir() else {
            return Vec::new();
        };
        let candidates = [
            local_app_data.join(r"Microsoft\Edge\User Data\Default\History"),
            local_app_data.join(r"Google\Chrome\User Data\Default\History"),
            local_app_data.join(r"BraveSoftware\Brave-Browser\User Data\Default\History"),
        ];
        let Some(source) = candidates.into_iter().find(|p| p.exists()) else {
            return Vec::new();
        };

        let temp_copy =
            std::env::temp_dir().join(format!("tz_hist_{}.sqlite", uuid::Uuid::new_v4()));
        if fs::copy(&source, &temp_copy).is_err() {
            return Vec::new();
        }

        let mut titles = Vec::new();
        unsafe {
            if let Ok(lib) = libloading::Library::new("winsqlite3.dll") {
                type OpenV2 = unsafe extern "C" fn(
                    *const c_char,
                    *mut *mut c_void,
                    c_int,
                    *const c_char,
                ) -> c_int;
                type PrepareV2 = unsafe extern "C" fn(
                    *mut c_void,
                    *const c_char,
                    c_int,
                    *mut *mut c_void,
                    *mut *const c_char,
                ) -> c_int;
                type Step = unsafe extern "C" fn(*mut c_void) -> c_int;
                type ColumnText = unsafe extern "C" fn(*mut c_void, c_int) -> *const u8;
                type Finalize = unsafe extern "C" fn(*mut c_void) -> c_int;
                type Close = unsafe extern "C" fn(*mut c_void) -> c_int;

                if let (
                    Ok(open_v2),
                    Ok(prepare_v2),
                    Ok(step),
                    Ok(col_text),
                    Ok(finalize),
                    Ok(close),
                ) = (
                    lib.get::<OpenV2>(b"sqlite3_open_v2\0"),
                    lib.get::<PrepareV2>(b"sqlite3_prepare_v2\0"),
                    lib.get::<Step>(b"sqlite3_step\0"),
                    lib.get::<ColumnText>(b"sqlite3_column_text\0"),
                    lib.get::<Finalize>(b"sqlite3_finalize\0"),
                    lib.get::<Close>(b"sqlite3_close\0"),
                ) {
                    if let Ok(c_path) = CString::new(temp_copy.to_string_lossy().as_ref()) {
                        let mut db: *mut c_void = std::ptr::null_mut();
                        const SQLITE_OK: c_int = 0;
                        const SQLITE_OPEN_READONLY: c_int = 1;
                        const SQLITE_ROW: c_int = 100;
                        if open_v2(c_path.as_ptr(), &mut db, SQLITE_OPEN_READONLY, std::ptr::null())
                            == SQLITE_OK
                            && !db.is_null()
                        {
                            let sql = CString::new(
                                "SELECT title FROM urls WHERE title IS NOT NULL AND visit_count >= 2 ORDER BY visit_count DESC, last_visit_time DESC LIMIT 500;",
                            )
                            .unwrap();
                            let mut stmt: *mut c_void = std::ptr::null_mut();
                            if prepare_v2(db, sql.as_ptr(), -1, &mut stmt, std::ptr::null_mut())
                                == SQLITE_OK
                                && !stmt.is_null()
                            {
                                while step(stmt) == SQLITE_ROW {
                                    let ptr = col_text(stmt, 0);
                                    if !ptr.is_null() {
                                        if let Ok(s) = CStr::from_ptr(ptr as *const c_char).to_str()
                                        {
                                            titles.push(s.to_string());
                                        }
                                    }
                                }
                                finalize(stmt);
                            }
                            close(db);
                        }
                    }
                }
            }
        }
        let _ = fs::remove_file(&temp_copy);
        titles
    }

    #[cfg(not(target_os = "windows"))]
    fn read_browser_history_titles() -> Vec<String> {
        Vec::new()
    }

    fn extract_clean_entities_from_title(title: &str) -> Vec<String> {
        title
            .split(|c: char| " -|—·•:：/()（）[]【】".contains(c))
            .map(str::trim)
            .filter(|s| {
                let len = s.chars().count();
                (2..=18).contains(&len)
            })
            .map(ToString::to_string)
            .collect()
    }

    fn extract_entities_from_note(text: &str) -> Vec<String> {
        let mut found = Vec::new();
        for re in [&*BOLD_ENTITY_RE, &*CODE_ENTITY_RE, &*CAMEL_ENTITY_RE] {
            for cap in re.captures_iter(text).take(120) {
                if let Some(m) = cap.get(1) {
                    let token = m.as_str().trim();
                    let len = token.chars().count();
                    if (2..=18).contains(&len) {
                        found.push(token.to_string());
                    }
                }
            }
        }
        found
    }
}
