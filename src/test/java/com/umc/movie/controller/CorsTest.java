package com.umc.movie.controller;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// 운영 프론트 주소는 코드가 아니라 환경 변수(FRONTEND_ORIGIN → frontend.origin)로 전달된다.
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "frontend.origin=https://umcine.vercel.app")
class CorsTest {

    @Autowired
    private MockMvc mockMvc;

    private org.springframework.test.web.servlet.ResultActions preflight(String origin) throws Exception {
        return mockMvc.perform(options("/favorites")
                .header(HttpHeaders.ORIGIN, origin)
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST")
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS, "authorization,content-type"));
    }

    @Test
    @DisplayName("환경 변수로 지정한 운영 프론트 주소의 사전 요청(OPTIONS)은 허용된다")
    void allowsConfiguredFrontendOrigin() throws Exception {
        preflight("https://umcine.vercel.app")
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "https://umcine.vercel.app"));
    }

    @Test
    @DisplayName("로컬 개발 주소(localhost:3000)도 계속 허용된다")
    void stillAllowsLocalOrigin() throws Exception {
        preflight("http://localhost:3000")
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "http://localhost:3000"));
    }

    @Test
    @DisplayName("허용하지 않은 주소의 사전 요청은 403으로 거절된다")
    void rejectsUnknownOrigin() throws Exception {
        preflight("https://evil.example.com")
                .andExpect(status().isForbidden());
    }
}
