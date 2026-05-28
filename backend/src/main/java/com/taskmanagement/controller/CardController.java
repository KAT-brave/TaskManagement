package com.taskmanagement.controller;

import com.taskmanagement.dto.CardCreateRequest;
import com.taskmanagement.dto.CardUpdateRequest;
import com.taskmanagement.dto.CardResponse;
import com.taskmanagement.service.CardService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

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
    public CardResponse create(@RequestBody @Valid CardCreateRequest req) {
        return cardService.create(req);
    }

    @PutMapping("/{id}")
    public CardResponse update(@PathVariable Long id, @RequestBody @Valid CardUpdateRequest req) {
        return cardService.update(id, req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        cardService.delete(id);
    }
}
