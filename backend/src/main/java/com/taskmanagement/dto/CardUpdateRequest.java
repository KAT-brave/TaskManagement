package com.taskmanagement.dto;

import lombok.Getter;
import lombok.Setter;
import java.time.LocalDate;

@Getter
@Setter
public class CardUpdateRequest {
    private String title;
    private String description;
    private LocalDate dueDate;
    private String priority;
    private Integer position;
    private Long listId;
}
