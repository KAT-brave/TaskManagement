import { useCallback, useEffect, useState } from 'react';
import {
  DndContext,
  PointerSensor,
  useSensor,
  useSensors,
  DragOverlay,
  closestCorners,
} from '@dnd-kit/core';
import { arrayMove } from '@dnd-kit/sortable';
import { fetchCards, updateCard } from '../api/cardApi';
import KanbanColumn from '../components/KanbanColumn';
import CardItem from '../components/CardItem';

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
  const [activeCard, setActiveCard] = useState(null);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } })
  );

  const loadCards = useCallback(() => {
    return fetchCards().then(data => {
      const sorted = [...data].sort((a, b) => a.position - b.position);
      setColumns(groupByList(sorted));
    }).catch(err => setError(err.message));
  }, []);

  useEffect(() => {
    loadCards().finally(() => setLoading(false));
  }, [loadCards]);

  function findColumn(cardDndId) {
    const cardId = Number(String(cardDndId).replace('card-', ''));
    return columns.find(col => col.cards.some(c => c.id === cardId));
  }

  function handleDragStart(event) {
    const cardId = Number(String(event.active.id).replace('card-', ''));
    const col = columns.find(col => col.cards.some(c => c.id === cardId));
    setActiveCard(col?.cards.find(c => c.id === cardId) ?? null);
  }

  async function handleDragEnd(event) {
    const { active, over } = event;
    setActiveCard(null);
    if (!over || active.id === over.id) return;

    const activeId = String(active.id);
    const overId = String(over.id);
    const activeCol = findColumn(activeId);
    if (!activeCol) return;

    const overIsCard = overId.startsWith('card-');
    const overCol = overIsCard
      ? findColumn(overId)
      : columns.find(col => `list-${col.listId}` === overId);
    if (!overCol) return;

    const activeCardId = Number(activeId.replace('card-', ''));

    if (activeCol.listName === overCol.listName) {
      const oldIndex = activeCol.cards.findIndex(c => c.id === activeCardId);
      const newIndex = overIsCard
        ? overCol.cards.findIndex(c => c.id === Number(overId.replace('card-', '')))
        : overCol.cards.length - 1;
      if (oldIndex === newIndex) return;

      const reordered = arrayMove(activeCol.cards, oldIndex, newIndex);
      setColumns(prev => prev.map(col =>
        col.listName === activeCol.listName ? { ...col, cards: reordered } : col
      ));
      await Promise.all(reordered.map((card, i) => updateCard(card.id, { position: i + 1 })));
    } else {
      const movingCard = activeCol.cards.find(c => c.id === activeCardId);
      const newActiveCards = activeCol.cards.filter(c => c.id !== activeCardId);
      const insertIndex = overIsCard
        ? overCol.cards.findIndex(c => c.id === Number(overId.replace('card-', '')))
        : overCol.cards.length;
      const newOverCards = [...overCol.cards];
      newOverCards.splice(insertIndex, 0, { ...movingCard, listId: overCol.listId, listName: overCol.listName });

      setColumns(prev => prev.map(col => {
        if (col.listName === activeCol.listName) return { ...col, cards: newActiveCards };
        if (col.listName === overCol.listName) return { ...col, cards: newOverCards };
        return col;
      }));

      await updateCard(movingCard.id, { listId: overCol.listId, position: insertIndex + 1 });
      await Promise.all(newActiveCards.map((card, i) => updateCard(card.id, { position: i + 1 })));
      await Promise.all(newOverCards.map((card, i) => updateCard(card.id, { position: i + 1 })));
    }
  }

  if (loading) return <div className="status-message">読み込み中...</div>;
  if (error) return <div className="status-message error">エラー: {error}</div>;

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCorners}
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
    >
      <div className="board-wrapper">
        <div className="lists-container">
          {columns.map(col => (
            <KanbanColumn
              key={col.listName}
              listName={col.listName}
              listId={col.listId}
              cards={col.cards}
              onCardCreated={loadCards}
              onCardUpdated={loadCards}
            />
          ))}
        </div>
      </div>
      <DragOverlay>
        {activeCard && <CardItem card={activeCard} onUpdated={() => {}} />}
      </DragOverlay>
    </DndContext>
  );
}
