import { useDroppable } from '@dnd-kit/core';
import { SortableContext, verticalListSortingStrategy } from '@dnd-kit/sortable';
import CardItem from './CardItem';
import CreateCardForm from './CreateCardForm';

export default function KanbanColumn({ listName, listId, cards, onCardCreated, onCardUpdated }) {
  const { setNodeRef } = useDroppable({ id: `list-${listId}` });

  const cardIds = cards.map(c => `card-${c.id}`);

  return (
    <div className="list-column">
      <div className="list-header">
        <h3>{listName}</h3>
        <span className="card-meta">{cards.length}</span>
      </div>
      <SortableContext items={cardIds} strategy={verticalListSortingStrategy}>
        <div className="cards-list" ref={setNodeRef}>
          {cards.map(card => (
            <CardItem key={card.id} card={card} onUpdated={onCardUpdated} />
          ))}
        </div>
      </SortableContext>
      <CreateCardForm listId={listId} onCreated={onCardCreated} />
    </div>
  );
}
