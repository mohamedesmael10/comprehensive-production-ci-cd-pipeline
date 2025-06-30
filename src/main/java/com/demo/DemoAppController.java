package com.demo;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class DemoAppController {

    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("message", "Welcome to your simple Maven‑Java app!");
        return "index";
    }

    @GetMapping("/error")
    public String error() {
        return "error";
    }
}

