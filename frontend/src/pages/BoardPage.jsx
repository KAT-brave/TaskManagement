import { useEffect, useState } from 'react';
import { fetchCards } from '../api/cardApi';
import KanbanColumn from '../components/KanbanColumn';

function groupByList(cards) {
  const order = [];
  const map = {};
  for (const card of cards) {
    if (!map[card.listName]) {
      map[card.listName] = [];
      order.push(card.listName);
    }
    map[card.listName].push(card);
  }
  return order.map(name => ({ listName: name, cards: map[name] }));
}

export default function BoardPage() {
  const [columns, setColumns] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchCards()
      .then(data => {
        const sorted = [...data].sort((a, b) => a.position - b.position);
        setColumns(groupByList(sorted));
      })
      .catch(err => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <div className="status-message">読み込み中...</div>;
  if (error) return <div className="status-message error">エラー: {error}</div>;

  return (
    <div className="board-wrapper">
      <div className="lists-container">
        {columns.map(col => (
          <KanbanColumn
            key={col.listName}
            listName={col.listName}
            cards={col.cards}
          />
        ))}
      </div>
    </div>
  );
}
