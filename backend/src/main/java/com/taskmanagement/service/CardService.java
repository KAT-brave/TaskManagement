package com.taskmanagement.service;

import com.taskmanagement.dto.CardCreateRequest;
import com.taskmanagement.dto.CardResponse;
import com.taskmanagement.entity.Card;
import com.taskmanagement.entity.TaskList;
import com.taskmanagement.repository.CardRepository;
import com.taskmanagement.repository.TaskListRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class CardService {

    private final CardRepository cardRepository;
    private final TaskListRepository taskListRepository;

    public List<CardResponse> findAll() {
        return cardRepository.findAll().stream()
                .map(CardResponse::new)
                .toList();
    }

    public CardResponse findById(Long id) {
        return cardRepository.findById(id)
                .map(CardResponse::new)
                .orElseThrow(() -> new IllegalArgumentException("Card not found: " + id));
    }

    public CardResponse create(CardCreateRequest req) {
        TaskList list = taskListRepository.findById(req.getListId())
                .orElseThrow(() -> new IllegalArgumentException("List not found: " + req.getListId()));

        int nextPosition = cardRepository.findByListId(req.getListId()).size() + 1;

        Card card = new Card();
        card.setTitle(req.getTitle());
        card.setDescription(req.getDescription());
        card.setDueDate(req.getDueDate());
        card.setList(list);
        card.setPosition(nextPosition);
        card.setCreatedAt(LocalDateTime.now());
        card.setUpdatedAt(LocalDateTime.now());

        Card saved = cardRepository.save(card);
        return new CardResponse(saved);
    }
}
