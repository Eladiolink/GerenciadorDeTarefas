package com.example.TaskService.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/task")
public class TaskController {

    /**
     * Endpoint protegido usado para validar o token JWT recebido pelo servico.
     */
    @GetMapping("/ping")
    public String ping() {
        return "pong task";
    }
}
