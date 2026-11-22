package com.umc.movie.exception;

import com.umc.movie.dto.ApiResponse;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

@RestControllerAdvice
public class GlobalExceptionHandler {

    // @Valid 검증 실패: 첫 번째 위반 메시지를 400으로
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleValidation(MethodArgumentNotValidException exception) {
        String message = exception.getBindingResult().getFieldErrors().get(0).getDefaultMessage();
        return ResponseEntity.badRequest().body(ApiResponse.failure("COMMON4001", message));
    }

    // JSON이 깨졌거나 타입이 안 맞을 때 (예: score에 "abc")
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiResponse<Void>> handleNotReadable(HttpMessageNotReadableException exception) {
        return ResponseEntity.badRequest().body(ApiResponse.failure("COMMON4002", "요청 본문 형식이 올바르지 않습니다."));
    }

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ApiResponse<Void>> handleApi(ApiException exception) {
        return ResponseEntity.status(exception.getStatus())
                .body(ApiResponse.failure(exception.getCode(), exception.getMessage()));
    }

    // 사전 중복 체크를 통과했어도 동시 요청이면 DB UNIQUE가 마지막에 막는다. 같은 형식의 409로 바꿔준다.
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ApiResponse<Void>> handleDataIntegrity(DataIntegrityViolationException exception) {
        String cause = String.valueOf(exception.getMostSpecificCause().getMessage());
        ApiResponse<Void> body;
        if (cause.contains("uk_rating_member_movie")) {
            body = ApiResponse.failure("RATING409_1","이미 이 영화에 평점을 남기셨습니다.");
        } else if (cause.contains("member.email")) {
            body = ApiResponse.failure("MEMBER4091", "이미 사용 중인 이메일입니다.");
        } else if (cause.contains("member.nickname")) {
            body = ApiResponse.failure("MEMBER4092", "이미 사용 중인 닉네임입니다.");
        } else {
            body = ApiResponse.failure("COMMON4091", "이미 존재하는 데이터입니다.");
        }
        return ResponseEntity.status(HttpStatus.CONFLICT).body(body);
    }

    // 5주차 조회 API의 404/400도 같은 형식으로
    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<ApiResponse<Void>> handleResponseStatus(ResponseStatusException exception) {
        int status = exception.getStatusCode().value();
        return ResponseEntity.status(status)
                .body(ApiResponse.failure("COMMON" + status, exception.getReason()));
    }
}
