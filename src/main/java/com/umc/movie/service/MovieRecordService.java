package com.umc.movie.service;

import com.umc.movie.dto.CreateMovieRecordRequest;
import com.umc.movie.dto.FavoriteResponse;
import com.umc.movie.dto.MovieRecordResponse;
import com.umc.movie.dto.RatingResponse;
import com.umc.movie.entity.Favorite;
import com.umc.movie.entity.Member;
import com.umc.movie.entity.Rating;
import com.umc.movie.exception.ApiException;
import com.umc.movie.repository.FavoriteRepository;
import com.umc.movie.repository.MemberRepository;
import com.umc.movie.repository.RatingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.SQLException;

@Service
@RequiredArgsConstructor
public class MovieRecordService {

    private final MemberRepository memberRepository;
    private final RatingRepository ratingRepository;
    private final FavoriteRepository favoriteRepository;

    // RatingService.create()와 FavoriteService.create()를 연달아 부르면 트랜잭션이 따로 갈 수 있다.
    // 그래서 이 메서드 하나에 @Transactional을 걸어 평점 저장과 즐겨찾기 저장을 한 묶음으로 처리한다.
    // 중간에 런타임 예외가 밖으로 나가면 먼저 저장한 평점도 rollback 된다.
    //
    // 3주차: 쿼리 5번(회원 조회, 평점 중복 확인, 즐겨찾기 중복 확인, 평점 저장, 즐겨찾기 저장)을 2번(저장 2번)으로 줄였다.
    //  - 회원 조회: getReferenceById 는 쿼리 없이 FK 값만 들고 있는 껍데기를 준다. 없는 회원이면 INSERT 의 FK 가 거절한다.
    //  - 평점/즐겨찾기 중복 확인: (member_id, movie_id) UNIQUE 제약이 이미 막고 있다. 거절당하면 그때 409 로 바꾼다.
    // 읽기 쿼리를 지워도 되는 이유는 DB 제약이 같은 일을 하기 때문이다. 제약이 없는 스키마라면 이 최적화를 쓰면 안 된다.
    @Transactional
    public MovieRecordResponse create(Long memberId, CreateMovieRecordRequest request) {
        Member member = memberRepository.getReferenceById(memberId);

        Rating savedRating;
        try {
            savedRating = ratingRepository.saveAndFlush(Rating.builder()
                    .member(member)
                    .movieId(request.movieId())
                    .score(request.score())
                    .comment(request.comment())
                    .build());
        } catch (DataIntegrityViolationException e) {
            if (isForeignKeyViolation(e)) {
                throw new ApiException(HttpStatus.NOT_FOUND, "MEMBER404_1", "해당 회원을 찾을 수 없습니다.");
            }
            if (isDuplicate(e)) {
                throw new ApiException(HttpStatus.CONFLICT, "RATING409_1", "이미 이 영화에 평점을 남기셨습니다.");
            }
            throw e;
        }

        FavoriteResponse favoriteResponse = null;
        if (request.addToFavorites()) {
            try {
                Favorite savedFavorite = favoriteRepository.saveAndFlush(Favorite.builder()
                        .member(member)
                        .movieId(request.movieId())
                        .build());
                favoriteResponse = FavoriteResponse.from(savedFavorite);
            } catch (DataIntegrityViolationException e) {
                if (isDuplicate(e)) {
                    throw new ApiException(HttpStatus.CONFLICT, "FAVORITE409_1", "이미 이 영화를 즐겨찾기하셨습니다.");
                }
                throw e;
            }
        }

        return new MovieRecordResponse(RatingResponse.from(savedRating), favoriteResponse);
    }

    // 제약 이름은 DB 마다 다르다(MySQL 은 스키마 파일의 이름, 테스트용 H2 는 자동 생성 이름). 그래서 이름 대신 SQLSTATE/에러 코드로 구분한다.
    private static boolean isDuplicate(Throwable e) {
        SQLException sql = rootSql(e);
        return sql != null && (sql.getErrorCode() == 1062 || "23505".equals(sql.getSQLState()));
    }

    private static boolean isForeignKeyViolation(Throwable e) {
        SQLException sql = rootSql(e);
        return sql != null && (sql.getErrorCode() == 1452 || "23506".equals(sql.getSQLState()));
    }

    private static SQLException rootSql(Throwable e) {
        SQLException found = null;
        for (Throwable t = e; t != null; t = t.getCause()) {
            if (t instanceof SQLException sql) {
                found = sql;
            }
        }
        return found;
    }
}
