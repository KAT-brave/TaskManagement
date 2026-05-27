package com.taskmanagement.dto;

import lombok.Getter;
import lombok.Setter;
import java.time.LocalDate;

@Getter
@Setter
public class CardCreateRequest {
    private String title;
    private String description;
    private LocalDate dueDate;
    private Long listId;
}
