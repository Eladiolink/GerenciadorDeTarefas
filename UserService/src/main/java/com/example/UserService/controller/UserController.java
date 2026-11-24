package com.example.UserService.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class UserController {

    @GetMapping("/ping")
    public String hello(){
        return "pong ls noq";
    }
}
