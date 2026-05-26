export default function CardItem({ card }) {
  const due = card.dueDate
    ? new Date(card.dueDate).toLocaleDateString('ja-JP')
    : null;

  return (
    <div className="card-item">
      <div className="card-info">
        <span className="card-title-text">{card.title}</span>
        {card.description && (
          <span className="card-meta">{card.description}</span>
        )}
        {due && <span className="card-meta">期限: {due}</span>}
      </div>
    </div>
  );
}
