package com.umc.movie.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.umc.movie.dto.CreateMovieRecordRequest;
import com.umc.movie.entity.Favorite;
import com.umc.movie.entity.Member;
import com.umc.movie.repository.FavoriteRepository;
import com.umc.movie.repository.MemberRepository;
import com.umc.movie.repository.RatingRepository;
import com.umc.movie.util.JwtUtil;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// 3주차: 읽기 쿼리를 지우고 DB 의 FK/UNIQUE 제약에 맡겼으므로, 제약이 거절했을 때 예전과 같은 응답이 나가는지 확인한다.
// 예외가 난 트랜잭션이 테스트 트랜잭션에 묶이면 롤백 여부를 확인할 수 없어서 @Transactional 을 쓰지 않고, 이메일을 매번 다르게 만든다.
@SpringBootTest
@AutoConfigureMockMvc
class MovieRecordApiTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;
    @Autowired private MemberRepository memberRepository;
    @Autowired private RatingRepository ratingRepository;
    @Autowired private FavoriteRepository favoriteRepository;
    @Autowired private JwtUtil jwtUtil;

    private Member member;
    private String authorization;

    @BeforeEach
    void setUp() {
        String tag = UUID.randomUUID().toString().substring(0, 8);
        member = memberRepository.save(Member.builder()
                .email(tag + "@umc.com").password("$2a$10$abcdefghijklmnopqrstuv").nickname("u" + tag.substring(0, 6)).build());
        authorization = "Bearer " + jwtUtil.createAccessToken(member.getMemberId(), member.getEmail());
    }

    // 트랜잭션 롤백에 기대지 않으므로, 다른 테스트의 개수 검증(count)을 깨뜨리지 않게 직접 지운다.
    @AfterEach
    void cleanUp() {
        ratingRepository.deleteAll();
        favoriteRepository.deleteAll();
        memberRepository.delete(member);
    }

    private ResultActions record(String bearer, long movieId, boolean favorite) throws Exception {
        return mockMvc.perform(post("/movie-records")
                .header(HttpHeaders.AUTHORIZATION, bearer)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new CreateMovieRecordRequest(movieId, 5, "최고", favorite))));
    }

    @Test
    @DisplayName("평점과 즐겨찾기를 한 번에 저장하면 201과 두 결과를 응답한다")
    void createsRatingAndFavorite() throws Exception {
        record(authorization, 550L, true)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.result.rating.movieId").value(550))
                .andExpect(jsonPath("$.result.favorite.movieId").value(550));
    }

    @Test
    @DisplayName("같은 영화에 다시 남기면 409 RATING409_1 (UNIQUE 제약이 막는다)")
    void duplicateRatingIs409() throws Exception {
        record(authorization, 550L, true).andExpect(status().isCreated());

        record(authorization, 550L, true)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("RATING409_1"));
    }

    @Test
    @DisplayName("즐겨찾기만 이미 있으면 409 FAVORITE409_1 이고 먼저 저장한 평점도 되돌려진다")
    void duplicateFavoriteRollsBackRating() throws Exception {
        favoriteRepository.save(Favorite.builder().member(member).movieId(603L).build());

        record(authorization, 603L, true)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("FAVORITE409_1"));

        assertThat(ratingRepository.existsByMember_MemberIdAndMovieId(member.getMemberId(), 603L)).isFalse();
    }

    @Test
    @DisplayName("없는 회원의 토큰이면 404 MEMBER404_1 (FK 제약이 막는다)")
    void unknownMemberIs404() throws Exception {
        String ghost = "Bearer " + jwtUtil.createAccessToken(999_999_999L, "ghost@umc.com");

        record(ghost, 550L, false)
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("MEMBER404_1"));
    }
}
