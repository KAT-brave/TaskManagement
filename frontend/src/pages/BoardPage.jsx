import { useEffect, useState } from 'react';
import { fetchCards } from '../api/cardApi';
import KanbanColumn from '../components/KanbanColumn';

function groupByList(cards) {
  const order = [];
  const map = {};
  for (const card of cards) {
    if (!map[card.listName]) {
      map[card.listName] = { listId: card.listId, cards: [] };
      order.push(card.listName);
    }
    map[card.listName].cards.push(card);
  }
  return order.map(name => ({ listName: name, listId: map[name].listId, cards: map[name].cards }));
}

export default function BoardPage() {
  const [columns, setColumns] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  function loadCards() {
    return fetchCards()
      .then(data => {
        const sorted = [...data].sort((a, b) => a.position - b.position);
        setColumns(groupByList(sorted));
      })
      .catch(err => setError(err.message));
  }

  useEffect(() => {
    loadCards().finally(() => setLoading(false));
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
            listId={col.listId}
            cards={col.cards}
            onCardCreated={loadCards}
          />
        ))}
      </div>
    </div>
  );
}
