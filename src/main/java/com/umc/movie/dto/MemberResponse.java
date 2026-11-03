package com.umc.movie.dto;

// password는 일부러 넣지 않는다.
public record MemberResponse(
        Long memberId,
        String email,
        String nickname
) {}
