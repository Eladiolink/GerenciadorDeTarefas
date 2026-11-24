package com.example.UserService.dto;

public record TokenResponse(String accessToken, String tokenType, long expiresIn) {
}
