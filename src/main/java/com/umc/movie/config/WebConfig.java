package com.umc.movie.config;

import com.umc.movie.interceptor.AuthInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

@Configuration
@RequiredArgsConstructor
public class WebConfig implements WebMvcConfigurer {

    private final AuthInterceptor authInterceptor;

    // 배포된 프론트 주소. 환경 변수 FRONTEND_ORIGIN 으로 전달하고, 쉼표로 여러 개를 적을 수 있다.
    @Value("${frontend.origin:}")
    private String frontendOrigin;

    // 5주차 CORS 설정. 토큰을 Authorization 헤더로 보내므로 OPTIONS(사전 요청)도 허용한다.
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        // 로컬 개발 주소(5173: Vite, 3000: Next.js)는 계속 허용하고, 운영 프론트 주소를 더한다.
        List<String> origins = new ArrayList<>(List.of("http://localhost:5173", "http://localhost:3000"));
        Arrays.stream(frontendOrigin.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isEmpty())
                .forEach(origins::add);

        registry.addMapping("/**") // 모든 경로에 대해
                .allowedOrigins(origins.toArray(String[]::new)) // 이 출처에서 오는 요청만 허용
                .allowedMethods("GET", "POST", "PATCH", "DELETE", "OPTIONS")
                .allowedHeaders("*");
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(authInterceptor)
                // 일단 모든 경로를 잠그고
                .addPathPatterns("/**")
                // 로그인 없이도 써야 하는 경로만 예외로 연다. (새 API를 깜빡해도 잠긴 채로 남는다)
                .excludePathPatterns(
                        "/auth/**",             // 로그인
                        "/members",             // 회원가입 (POST /members)
                        "/members/nickname/**", // 닉네임 중복 체크
                        "/members/email/**",    // 이메일 중복 체크
                        "/members/*/ratings",   // 유저별 평점 조회 (누구나 볼 수 있는 목록)
                        "/health",              // ALB 헬스체크
                        "/actuator/**",         // Alloy 가 지표를 긁어가는 경로(로그인 토큰 없이)
                        "/swagger-ui.html",     // Swagger UI로 보내주는 주소
                        "/swagger-ui/**",       // Swagger UI 화면
                        "/v3/api-docs/**",      // Swagger UI가 읽어가는 API 문서(JSON)
                        "/error"                // 스프링이 내부적으로 쓰는 경로
                );
    }
}
