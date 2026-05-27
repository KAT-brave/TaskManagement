package com.taskmanagement.dto;

import com.taskmanagement.entity.Card;
import lombok.Getter;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter
public class CardResponse {

    private final Long id;
    private final String title;
    private final String description;
    private final LocalDate dueDate;
    private final Integer position;
    private final String priority;
    private final Long listId;
    private final String listName;
    private final LocalDateTime createdAt;
    private final LocalDateTime updatedAt;

    public CardResponse(Card card) {
        this.id = card.getId();
        this.title = card.getTitle();
        this.description = card.getDescription();
        this.dueDate = card.getDueDate();
        this.position = card.getPosition();
        this.priority = card.getPriority();
        this.listId = card.getList().getId();
        this.listName = card.getList().getName();
        this.createdAt = card.getCreatedAt();
        this.updatedAt = card.getUpdatedAt();
    }
}
