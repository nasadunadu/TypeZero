import React, { useMemo, useState } from "react";
import { FolderPlus, Globe, Pencil, Search, Trash2, X } from "lucide-react";
import {
  LEXICON_CATEGORIES,
  type AppSnapshot,
  type LexiconCategory,
  type LexiconEntry,
} from "../types";

interface Props {
  snapshot: AppSnapshot;
  onUpsert: (term: string, aliases: string[], cat: LexiconCategory, weight: number) => Promise<void>;
  onUpdate: (
    id: string,
    newTerm: string,
    newAliases: string[],
    cat: LexiconCategory,
    weight: number,
  ) => Promise<void>;
  onRemove: (id: string) => Promise<void>;
  onRemoveBatch: (ids: string[]) => Promise<void>;
  onBulkLines: (raw: string, cat: LexiconCategory) => Promise<void>;
  onDistillCorpus: (raw: string) => Promise<void>;
  onImportFolder: () => Promise<void>;
  onImportBrowsers: () => Promise<void>;
}

const FILTER_CATS: LexiconCategory[] = ["人名/称呼", "项目/技术", "纪要/备忘", "纠错自学习"];

export const DictionarySection: React.FC<Props> = ({
  snapshot,
  onUpsert,
  onUpdate,
  onRemove,
  onRemoveBatch,
  onBulkLines,
  onDistillCorpus,
  onImportFolder,
  onImportBrowsers,
}) => {
  const [rawCorpus, setRawCorpus] = useState("");
  const [isDistilling, setIsDistilling] = useState(false);

  const [newTerm, setNewTerm] = useState("");
  const [newAliases, setNewAliases] = useState("");
  const [newCategory, setNewCategory] = useState<LexiconCategory>("人名/称呼");

  const [categoryFilter, setCategoryFilter] = useState<LexiconCategory | null>(null);
  const [search, setSearch] = useState("");

  const [editingId, setEditingId] = useState<string | null>(null);
  const [editTerm, setEditTerm] = useState("");
  const [editAliases, setEditAliases] = useState("");
  const [editCategory, setEditCategory] = useState<LexiconCategory>("人名/称呼");
  const [editPinned, setEditPinned] = useState(false);

  const [batchMode, setBatchMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return snapshot.lexicon.filter((e) => {
      if (categoryFilter && e.category !== categoryFilter) return false;
      if (!q) return true;
      return (
        e.term.toLowerCase().includes(q) ||
        e.phoneticKey.toLowerCase().includes(q) ||
        e.aliases.some((a) => a.toLowerCase().includes(q))
      );
    });
  }, [snapshot.lexicon, categoryFilter, search]);

  const parseAliases = (raw: string): string[] =>
    raw
      .split(/[,，/、;；]/)
      .map((s) => s.trim())
      .filter(Boolean);

  const beginEdit = (item: LexiconEntry) => {
    setEditingId(item.id);
    setEditTerm(item.term);
    setEditAliases(item.aliases.join("，"));
    setEditCategory(item.category);
    setEditPinned(item.weight >= 9);
  };

  const commitEdit = async (id: string) => {
    await onUpdate(id, editTerm, parseAliases(editAliases), editCategory, editPinned ? 10 : 7);
    setEditingId(null);
  };

  const handleAddSingle = async () => {
    if (!newTerm.trim()) return;
    await onUpsert(newTerm.trim(), parseAliases(newAliases), newCategory, 8);
    setNewTerm("");
    setNewAliases("");
  };

  const handleDistill = async () => {
    if (!rawCorpus.trim() || isDistilling) return;
    setIsDistilling(true);
    try {
      await onDistillCorpus(rawCorpus);
      setRawCorpus("");
    } finally {
      setIsDistilling(false);
    }
  };

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
      <header className="editorial-header">
        <div className="editorial-header-top">
          <h1 className="editorial-title">个人专属词库</h1>
          <span className="editorial-badge">
            FUZZY PHONETIC INDEX · {snapshot.lexicon.length} TERMS
          </span>
        </div>
        <div className="editorial-sub">
          <span className="editorial-sub-bar" />
          <span>模糊声韵骨架 0.5ms 极速近音召回 ｜ 点击任意词条即可原地修改标准词、编辑误听映射或一键删除</span>
        </div>
        <div className="editorial-rule" />
      </header>

      {/* AI Corpus Distiller & Importers */}
      <section className="card" style={{ display: "flex", flexDirection: "column", gap: 11, padding: 16 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{ fontSize: 14, fontWeight: 600 }}>会议纪要与名单智能提纯器</span>
          <div style={{ marginLeft: "auto", display: "flex", gap: 8 }}>
            <button
              type="button"
              className="btn btn-secondary btn-compact"
              onClick={() => void onImportFolder()}
            >
              <FolderPlus size={12} />
              <span>扫描本地纪要目录</span>
            </button>
            <button
              type="button"
              className="btn btn-secondary btn-compact"
              onClick={() => void onImportBrowsers()}
            >
              <Globe size={12} />
              <span>提取 Edge / Chrome 高频词</span>
            </button>
          </div>
        </div>

        <textarea
          className="textarea"
          rows={3}
          placeholder="在此粘贴会议纪要片段、PRD 文档或人名列表，可按行直接入库或交由大模型自动提纯专有名词与同音误听词…"
          value={rawCorpus}
          onChange={(e) => setRawCorpus(e.target.value)}
        />

        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{ fontSize: 11.5, color: "var(--ink-muted)" }}>
            所有词条仅加密/本地存储于 %APPDATA%\TypeZero，绝不上传或污染代码仓库
          </span>
          <div style={{ marginLeft: "auto", display: "flex", gap: 8 }}>
            <button
              type="button"
              className="btn btn-secondary btn-compact"
              disabled={!rawCorpus.trim()}
              onClick={async () => {
                await onBulkLines(rawCorpus, newCategory);
                setRawCorpus("");
              }}
            >
              按行直接导入
            </button>
            <button
              type="button"
              className="btn btn-primary btn-compact"
              disabled={!rawCorpus.trim() || isDistilling}
              onClick={() => void handleDistill()}
            >
              {isDistilling ? "智能提纯中…" : "AI 自动提纯专有词"}
            </button>
          </div>
        </div>
      </section>

      {/* Quick Add Single Entry */}
      <section className="card" style={{ display: "flex", alignItems: "center", gap: 9, padding: 13 }}>
        <input
          className="input"
          placeholder="新增标准词（人名 / 产品 / 术语）"
          value={newTerm}
          onChange={(e) => setNewTerm(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") void handleAddSingle();
          }}
        />
        <input
          className="input"
          placeholder="常见误听词，逗号分隔（可选）"
          value={newAliases}
          onChange={(e) => setNewAliases(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") void handleAddSingle();
          }}
        />
        <select
          className="select"
          style={{ width: 132, flexShrink: 0 }}
          value={newCategory}
          onChange={(e) => setNewCategory(e.target.value as LexiconCategory)}
        >
          {LEXICON_CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
        <button type="button" className="btn btn-primary" onClick={() => void handleAddSingle()}>
          添加词条
        </button>
      </section>

      {/* Filter Pills + Search */}
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 7, flexWrap: "wrap" }}>
          <button
            type="button"
            className="pill-badge"
            style={{
              cursor: "pointer",
              border: "none",
              padding: "5px 11px",
              fontSize: 11.5,
              background: categoryFilter === null ? "var(--violet)" : "rgba(234,230,219,0.75)",
              color: categoryFilter === null ? "#fff" : "var(--ink-secondary)",
            }}
            onClick={() => setCategoryFilter(null)}
          >
            全部 ({snapshot.lexicon.length})
          </button>

          {FILTER_CATS.map((cat) => {
            const count = snapshot.lexicon.filter((e) => e.category === cat).length;
            if (count === 0 && categoryFilter !== cat) return null;
            const active = categoryFilter === cat;
            return (
              <button
                key={cat}
                type="button"
                className="pill-badge"
                style={{
                  cursor: "pointer",
                  border: "none",
                  padding: "5px 11px",
                  fontSize: 11.5,
                  background: active ? "var(--violet)" : "rgba(234,230,219,0.75)",
                  color: active ? "#fff" : "var(--ink-secondary)",
                }}
                onClick={() => setCategoryFilter(active ? null : cat)}
              >
                {cat} ({count})
              </button>
            );
          })}

          <div style={{ marginLeft: "auto", display: "flex", gap: 8 }}>
            {batchMode && selectedIds.size > 0 && (
              <button
                type="button"
                className="btn btn-danger btn-compact"
                onClick={async () => {
                  await onRemoveBatch(Array.from(selectedIds));
                  setSelectedIds(new Set());
                }}
              >
                <Trash2 size={12} />
                <span>删除已选 ({selectedIds.size})</span>
              </button>
            )}
            <button
              type="button"
              className="btn btn-secondary btn-compact"
              onClick={() => {
                setBatchMode((b) => !b);
                setSelectedIds(new Set());
              }}
            >
              {batchMode ? "完成批量清理" : "批量选择删除"}
            </button>
          </div>
        </div>

        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 8,
            background: "var(--card-bg)",
            border: "1px solid var(--hairline)",
            borderRadius: 9,
            padding: "7px 12px",
          }}
        >
          <Search size={13} style={{ color: "var(--ink-muted)" }} />
          <input
            style={{
              flex: 1,
              border: "none",
              outline: "none",
              background: "transparent",
              fontSize: 13,
            }}
            placeholder="搜索词条、误听词或拼音（如 deepseek / zhangwei / mcp）…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button
              type="button"
              style={{ border: "none", background: "transparent", cursor: "pointer", color: "var(--ink-muted)" }}
              onClick={() => setSearch("")}
            >
              <X size={13} />
            </button>
          )}
        </div>
      </div>

      {/* Editable Lexicon List */}
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        {filtered.map((item) =>
          editingId === item.id ? (
            <div
              key={item.id}
              style={{
                padding: 15,
                borderRadius: 12,
                background: "rgba(236, 233, 251, 0.65)",
                border: "1.2px solid rgba(90, 70, 232, 0.45)",
                display: "flex",
                flexDirection: "column",
                gap: 11,
              }}
            >
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <span style={{ fontSize: 12, fontWeight: 700, color: "var(--violet)" }}>
                  ● 编辑词条映射
                </span>
                <label style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12, cursor: "pointer" }}>
                  <input
                    type="checkbox"
                    checked={editPinned}
                    onChange={(e) => setEditPinned(e.target.checked)}
                  />
                  <span>★ 核心常驻置顶（100% 随句预热）</span>
                </label>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "190px 1fr 125px", gap: 10 }}>
                <div>
                  <div style={{ fontSize: 11, color: "var(--ink-secondary)", marginBottom: 4 }}>正确标准词</div>
                  <input
                    className="input input-compact"
                    value={editTerm}
                    onChange={(e) => setEditTerm(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") void commitEdit(item.id);
                    }}
                  />
                </div>
                <div>
                  <div style={{ fontSize: 11, color: "var(--ink-secondary)", marginBottom: 4 }}>
                    常见误听词（逗号或斜杠分隔，改标准词会自动记住旧错词）
                  </div>
                  <input
                    className="input input-compact"
                    value={editAliases}
                    onChange={(e) => setEditAliases(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") void commitEdit(item.id);
                    }}
                  />
                </div>
                <div>
                  <div style={{ fontSize: 11, color: "var(--ink-secondary)", marginBottom: 4 }}>所属分类</div>
                  <select
                    className="select input-compact"
                    value={editCategory}
                    onChange={(e) => setEditCategory(e.target.value as LexiconCategory)}
                  >
                    {LEXICON_CATEGORIES.map((c) => (
                      <option key={c} value={c}>
                        {c}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <button
                  type="button"
                  className="btn btn-danger btn-compact"
                  onClick={async () => {
                    setEditingId(null);
                    await onRemove(item.id);
                  }}
                >
                  <Trash2 size={11} />
                  <span>删除此词</span>
                </button>
                <div style={{ marginLeft: "auto", display: "flex", gap: 8 }}>
                  <button
                    type="button"
                    className="btn btn-secondary btn-compact"
                    onClick={() => setEditingId(null)}
                  >
                    取消
                  </button>
                  <button
                    type="button"
                    className="btn btn-primary btn-compact"
                    onClick={() => void commitEdit(item.id)}
                  >
                    保存修改
                  </button>
                </div>
              </div>
            </div>
          ) : (
            <div
              key={item.id}
              onClick={() => (batchMode ? toggleSelect(item.id) : beginEdit(item))}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 9,
                padding: "9px 14px",
                background: "var(--card-bg)",
                border: "1px solid var(--hairline)",
                borderRadius: 11,
                cursor: "pointer",
              }}
            >
              {batchMode && (
                <input
                  type="checkbox"
                  checked={selectedIds.has(item.id)}
                  onChange={() => toggleSelect(item.id)}
                  onClick={(e) => e.stopPropagation()}
                />
              )}

              <span style={{ fontSize: 14, fontWeight: 600 }}>{item.term}</span>

              {item.weight >= 9 && (
                <span className="pill-badge pill-warn" style={{ fontSize: 10 }}>
                  ★ 常驻
                </span>
              )}

              <span
                style={{
                  fontFamily: "var(--font-mono)",
                  fontSize: 11,
                  color: "var(--ink-muted)",
                }}
              >
                {item.phoneticKey}
              </span>

              <div style={{ display: "flex", gap: 4, flexWrap: "wrap" }}>
                {item.aliases.slice(0, 4).map((al) => (
                  <span
                    key={al}
                    style={{
                      fontSize: 11,
                      fontWeight: 500,
                      color: "var(--violet)",
                      background: "var(--lilac-tint)",
                      padding: "2px 6.5px",
                      borderRadius: 5,
                    }}
                  >
                    {al}
                  </span>
                ))}
                {item.aliases.length > 4 && (
                  <span style={{ fontFamily: "var(--font-mono)", fontSize: 10.5, color: "var(--ink-muted)" }}>
                    +{item.aliases.length - 4}
                  </span>
                )}
              </div>

              <div style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 6 }}>
                <span
                  style={{
                    fontSize: 10.5,
                    color: "var(--ink-secondary)",
                    background: "var(--soft-well)",
                    padding: "2.5px 8px",
                    borderRadius: 99,
                  }}
                >
                  {item.category}
                </span>
                <button
                  type="button"
                  className="btn btn-secondary btn-compact"
                  onClick={(e) => {
                    e.stopPropagation();
                    beginEdit(item);
                  }}
                  title="编辑"
                >
                  <Pencil size={11} />
                </button>
                <button
                  type="button"
                  className="btn btn-danger btn-compact"
                  onClick={(e) => {
                    e.stopPropagation();
                    void onRemove(item.id);
                  }}
                  title="删除"
                >
                  <Trash2 size={11} />
                </button>
              </div>
            </div>
          ),
        )}
      </div>
    </div>
  );
};
