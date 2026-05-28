import { useState } from 'react';
import { updateCard, deleteCard } from '../api/cardApi';

const PRIORITY_OPTIONS = [
  { value: 'high',   label: '🔴 高' },
  { value: 'medium', label: '🟡 中' },
  { value: 'low',    label: '🟢 低' },
];

export default function EditCardModal({ card, onUpdated, onClose }) {
  const [title, setTitle] = useState(card.title ?? '');
  const [description, setDescription] = useState(card.description ?? '');
  const [dueDate, setDueDate] = useState(card.dueDate ?? '');
  const [priority, setPriority] = useState(card.priority ?? '');
  const [submitting, setSubmitting] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!title.trim()) return;
    setSubmitting(true);
    setError(null);
    try {
      await updateCard(card.id, {
        title: title.trim(),
        description: description.trim() || null,
        dueDate: dueDate || null,
        priority: priority || null,
      });
      onUpdated();
      onClose();
    } catch {
      setError('更新に失敗しました。もう一度お試しください。');
    } finally {
      setSubmitting(false);
    }
  }

  async function handleDelete() {
    setDeleting(true);
    setError(null);
    try {
      await deleteCard(card.id);
      onUpdated();
      onClose();
    } catch {
      setError('削除に失敗しました。もう一度お試しください。');
      setDeleting(false);
      setConfirmDelete(false);
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h3>カードを編集</h3>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="modal-field">
            <label className="modal-label">タイトル</label>
            <input
              className="create-card-input"
              type="text"
              value={title}
              onChange={e => setTitle(e.target.value)}
              autoFocus
            />
          </div>
          <div className="modal-field">
            <label className="modal-label">説明</label>
            <textarea
              className="create-card-textarea"
              value={description}
              onChange={e => setDescription(e.target.value)}
              rows={3}
            />
          </div>
          <div className="modal-field">
            <label className="modal-label">期限日</label>
            <input
              className="create-card-input"
              type="date"
              value={dueDate}
              onChange={e => setDueDate(e.target.value)}
            />
          </div>
          <div className="modal-field">
            <label className="modal-label">優先度</label>
            <select
              className="create-card-input"
              value={priority}
              onChange={e => setPriority(e.target.value)}
            >
              <option value="">未設定</option>
              {PRIORITY_OPTIONS.map(opt => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </select>
          </div>
          {error && <p className="create-card-error">{error}</p>}
          <div className="create-card-actions">
            <button
              className="btn-primary"
              type="submit"
              disabled={submitting || deleting || !title.trim()}
            >
              {submitting ? '保存中...' : '保存'}
            </button>
            <button className="btn-secondary" type="button" onClick={onClose} disabled={submitting || deleting}>
              キャンセル
            </button>
          </div>
        </form>

        <div className="modal-divider" />

        {confirmDelete ? (
          <div className="delete-confirm">
            <p className="delete-confirm-text">本当に削除しますか？この操作は元に戻せません。</p>
            <div className="create-card-actions">
              <button className="btn-danger" onClick={handleDelete} disabled={deleting}>
                {deleting ? '削除中...' : '削除する'}
              </button>
              <button className="btn-secondary" onClick={() => setConfirmDelete(false)} disabled={deleting}>
                戻る
              </button>
            </div>
          </div>
        ) : (
          <button className="btn-delete-trigger" onClick={() => setConfirmDelete(true)}>
            🗑 このカードを削除
          </button>
        )}
      </div>
    </div>
  );
}
