package com.example.UserService.service;

import com.example.UserService.entity.User;
import com.example.UserService.dto.LoginRequest;
import com.example.UserService.dto.RegisterRequest;
import com.example.UserService.dto.TokenResponse;
import com.example.UserService.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    @Transactional
    public TokenResponse register(RegisterRequest request) {
        String username = validateUsername(request.username());
        validatePassword(request.password());

        if (userRepository.existsByUsername(username)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Username ja cadastrado");
        }

        User user = new User();
        user.setUsername(username);
        user.setPassword(passwordEncoder.encode(request.password()));
        userRepository.save(user);

        return jwtService.generateToken(user);
    }

    @Transactional(readOnly = true)
    public TokenResponse login(LoginRequest request) {
        if (request.username() == null || request.password() == null) {
            throw unauthorized();
        }

        User user = userRepository.findByUsername(request.username().trim())
                .orElseThrow(this::unauthorized);

        if (!passwordEncoder.matches(request.password(), user.getPassword())) {
            throw unauthorized();
        }

        return jwtService.generateToken(user);
    }

    private String validateUsername(String username) {
        if (username == null || username.isBlank() || username.trim().length() > 50) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Username invalido");
        }
        return username.trim();
    }

    private void validatePassword(String password) {
        if (password == null || password.length() < 6) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "A senha deve ter pelo menos 6 caracteres");
        }
    }

    private ResponseStatusException unauthorized() {
        return new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Usuario ou senha invalidos");
    }
}
