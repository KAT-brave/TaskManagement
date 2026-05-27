import { useState } from 'react';
import { createCard } from '../api/cardApi';

export default function CreateCardForm({ listId, onCreated }) {
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  function reset() {
    setTitle('');
    setDescription('');
    setDueDate('');
    setError(null);
    setOpen(false);
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!title.trim()) return;
    setSubmitting(true);
    setError(null);
    try {
      await createCard({
        title: title.trim(),
        description: description.trim() || null,
        dueDate: dueDate || null,
        listId,
      });
      reset();
      onCreated();
    } catch {
      setError('登録に失敗しました。もう一度お試しください。');
    } finally {
      setSubmitting(false);
    }
  }

  if (!open) {
    return (
      <button className="add-card-btn" onClick={() => setOpen(true)}>
        + カードを追加
      </button>
    );
  }

  return (
    <form className="create-card-form" onSubmit={handleSubmit}>
      <input
        className="create-card-input"
        type="text"
        placeholder="タイトル（必須）"
        value={title}
        onChange={e => setTitle(e.target.value)}
        autoFocus
      />
      <textarea
        className="create-card-textarea"
        placeholder="説明（任意）"
        value={description}
        onChange={e => setDescription(e.target.value)}
        rows={2}
      />
      <input
        className="create-card-input"
        type="date"
        value={dueDate}
        onChange={e => setDueDate(e.target.value)}
      />
      {error && <p className="create-card-error">{error}</p>}
      <div className="create-card-actions">
        <button
          className="btn-primary"
          type="submit"
          disabled={submitting || !title.trim()}
        >
          {submitting ? '登録中...' : '追加'}
        </button>
        <button className="btn-secondary" type="button" onClick={reset}>
          キャンセル
        </button>
      </div>
    </form>
  );
}
