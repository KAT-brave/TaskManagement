import { useState } from 'react';
import { useSortable } from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import EditCardModal from './EditCardModal';

const PRIORITY_BADGE = {
  high:   '🔴 高',
  medium: '🟡 中',
  low:    '🟢 低',
};

export default function CardItem({ card, onUpdated }) {
  const [editing, setEditing] = useState(false);

  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: `card-${card.id}`,
    data: { type: 'card', card },
  });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.4 : 1,
  };

  const due = card.dueDate
    ? new Date(card.dueDate).toLocaleDateString('ja-JP')
    : null;

  return (
    <>
      <div
        ref={setNodeRef}
        style={style}
        className="card-item"
        {...attributes}
        {...listeners}
        onClick={() => setEditing(true)}
      >
        <div className="card-info">
          <div className="card-title-row">
            <span className="card-title-text">{card.title}</span>
            {card.priority && (
              <span className="priority-badge">{PRIORITY_BADGE[card.priority]}</span>
            )}
          </div>
          {card.description && (
            <span className="card-meta">{card.description}</span>
          )}
          {due && <span className="card-meta">期限: {due}</span>}
        </div>
      </div>
      {editing && (
        <EditCardModal
          card={card}
          onUpdated={onUpdated}
          onClose={() => setEditing(false)}
        />
      )}
    </>
  );
}
