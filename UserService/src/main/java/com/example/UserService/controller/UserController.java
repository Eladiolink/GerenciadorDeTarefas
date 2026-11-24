package com.example.UserService.controller;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/user")
public class UserController {

    @GetMapping("/ping")
    public String hello() {
        return "pong ls  rs noq";
    }

    /**
     * Endpoint protegido usado para validar o token JWT recebido pelo servico.
     */
    @GetMapping("/me")
    public Map<String, Object> me(@AuthenticationPrincipal Jwt jwt) {
        return Map.of(
                "username", jwt.getSubject(),
                "userId", jwt.getClaim("userId"),
                "roles", jwt.getClaimAsStringList("roles")
        );
    }
}
