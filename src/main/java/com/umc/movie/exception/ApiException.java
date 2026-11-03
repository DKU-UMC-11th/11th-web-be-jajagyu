package com.umc.movie.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

// 서비스에서 "이 상태코드 + 이 code + 이 메시지"로 실패시키고 싶을 때 던진다.
@Getter
public class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String code;

    public ApiException(HttpStatus status, String code, String message) {
        super(message);
        this.status = status;
        this.code = code;
    }
}
