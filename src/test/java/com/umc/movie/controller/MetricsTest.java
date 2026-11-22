package com.umc.movie.controller;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.actuate.observability.AutoConfigureObservability;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// 2주차 관측: Alloy 가 토큰 없이 긁어가는 /actuator/prometheus 가 열려 있고, 응답 시간이 히스토그램 버킷으로 나오는지 확인
// src/test/resources/application.yml 이 운영 설정을 통째로 대체하므로 관측 설정은 여기서 직접 준다
@SpringBootTest(properties = {
        "management.endpoints.web.exposure.include=health,prometheus",
        "management.metrics.distribution.percentiles-histogram.http.server.requests=true"
})
@AutoConfigureMockMvc
@AutoConfigureObservability // 테스트에서는 메트릭 수집이 기본으로 꺼져 있어서 켠다
class MetricsTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @DisplayName("/actuator/prometheus 는 로그인 없이 열리고 http 요청 시간 히스토그램을 노출한다")
    void exposesPrometheusHistogram() throws Exception {
        mockMvc.perform(get("/health")); // 먼저 요청을 하나 보내 지표가 생기게 한다

        mockMvc.perform(get("/actuator/prometheus"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("http_server_requests_seconds_bucket")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("hikaricp_connections_max")));
    }
}
