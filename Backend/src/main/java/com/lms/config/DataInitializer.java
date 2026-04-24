package com.lms.config;

import com.lms.model.User;
import com.lms.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.Arrays;

@Component
public class DataInitializer implements CommandLineRunner {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
        if (userRepository.findByUserName("admin") == null) {
            User admin = new User();
            admin.setUserName("admin");
            admin.setEmail("admin@learnflow.com");
            admin.setAge(0);
            admin.setPassword(passwordEncoder.encode("admin123"));
            admin.setCreatedAt(LocalDateTime.now());
            admin.setRoles(Arrays.asList("USER", "ADMIN", "INSTRUCTOR"));
            userRepository.save(admin);
            System.out.println("==> Default admin user created (username: admin, password: admin123)");
        } else {
            System.out.println("==> Admin user already exists, skipping.");
        }
    }
}
