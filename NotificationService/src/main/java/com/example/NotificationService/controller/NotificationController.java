package com.example.NotificationService.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/notification")
public class NotificationController {

    /**
     * Endpoint protegido usado para validar o token JWT recebido pelo servico.
     */
    @GetMapping("/ping")
    public String ping() {
        return "pong notification";
    }
}
