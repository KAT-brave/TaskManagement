package com.taskmanagement.service;

import com.taskmanagement.dto.CardResponse;
import com.taskmanagement.repository.CardRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class CardService {

    private final CardRepository cardRepository;

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
}
