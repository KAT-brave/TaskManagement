package com.taskmanagement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDate;

@Getter
@Setter
public class CardCreateRequest {

    @NotBlank(message = "タイトルは必須です")
    @Size(max = 255, message = "タイトルは255文字以内で入力してください")
    private String title;

    @Size(max = 1000, message = "説明は1000文字以内で入力してください")
    private String description;

    private LocalDate dueDate;

    @Pattern(regexp = "^(high|medium|low)$", message = "優先度はhigh、medium、lowのいずれかを指定してください")
    private String priority;

    @NotNull(message = "リストIDは必須です")
    private Long listId;
}
