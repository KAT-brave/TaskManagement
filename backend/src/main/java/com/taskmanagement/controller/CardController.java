package com.taskmanagement.controller;

import com.taskmanagement.dto.CardCreateRequest;
import com.taskmanagement.dto.CardResponse;
import com.taskmanagement.service.CardService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/cards")
@RequiredArgsConstructor
public class CardController {

    private final CardService cardService;

    @GetMapping
    public List<CardResponse> getAll() {
        return cardService.findAll();
    }

    @GetMapping("/{id}")
    public CardResponse getById(@PathVariable Long id) {
        return cardService.findById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CardResponse create(@RequestBody CardCreateRequest req) {
        return cardService.create(req);
    }
}
