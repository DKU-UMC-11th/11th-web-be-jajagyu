package com.umc.movie.config;

import com.umc.movie.interceptor.AuthInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
@RequiredArgsConstructor
public class WebConfig implements WebMvcConfigurer {

    private final AuthInterceptor authInterceptor;

    // 5주차 CORS 설정. 토큰을 Authorization 헤더로 보내므로 OPTIONS(사전 요청)도 허용한다.
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**") // 모든 경로에 대해
                .allowedOrigins("http://localhost:5173") // 이 출처에서 오는 요청만 허용
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
                        "/error"                // 스프링이 내부적으로 쓰는 경로
                );
    }
}
