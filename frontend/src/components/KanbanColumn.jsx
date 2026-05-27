import CardItem from './CardItem';
import CreateCardForm from './CreateCardForm';

export default function KanbanColumn({ listName, listId, cards, onCardCreated }) {
  return (
    <div className="list-column">
      <div className="list-header">
        <h3>{listName}</h3>
        <span className="card-meta">{cards.length}</span>
      </div>
      <div className="cards-list">
        {cards.map(card => (
          <CardItem key={card.id} card={card} />
        ))}
      </div>
      <CreateCardForm listId={listId} onCreated={onCardCreated} />
    </div>
  );
}
