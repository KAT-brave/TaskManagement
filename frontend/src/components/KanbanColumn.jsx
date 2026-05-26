import CardItem from './CardItem';

export default function KanbanColumn({ listName, cards }) {
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
    </div>
  );
}
