package com.umc.movie.controller;

import io.swagger.v3.oas.annotations.Hidden;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

// ALB 타겟 그룹 헬스체크용. 인증 없이 200만 돌려준다.
@Hidden // 인프라용 헬스체크라서 API 문서에는 나타내지 않는다
@RestController
public class HealthController {
    @GetMapping("/health")
    public String health() {
        return "ok";
    }
}
