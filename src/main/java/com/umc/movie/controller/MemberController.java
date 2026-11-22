package com.umc.movie.controller;

import com.umc.movie.config.SwaggerConfig;
import com.umc.movie.dto.ApiResponse;
import com.umc.movie.dto.EmailCheckResponse;
import com.umc.movie.dto.MemberInfoResponse;
import com.umc.movie.dto.MemberResponse;
import com.umc.movie.dto.MemberUpdateRequest;
import com.umc.movie.dto.NicknameCheckResponse;
import com.umc.movie.dto.SignUpRequest;
import com.umc.movie.interceptor.AuthInterceptor;
import com.umc.movie.service.MemberService;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/members")
@Tag(name = "회원", description = "회원가입, 중복 확인, 내 정보 API")
public class MemberController {

    private final MemberService memberService;

    // 선택 미션: 닉네임은 2~12자가 아니면 available을 판단하기 전에 400
    @Operation(summary = "닉네임 중복 확인", description = "사용할 수 있는 닉네임인지 확인합니다. 토큰이 필요 없는 공개 API입니다.")
    @GetMapping("/nickname/{nickname}")
    public NicknameCheckResponse checkNickname(
            @PathVariable("nickname") @Size(min = 2, max = 12) String nickname) {
        return memberService.checkNickname(nickname);
    }

    // 선택 미션: 이메일 형식이 아니면 400
    @Operation(summary = "이메일 중복 확인", description = "사용할 수 있는 이메일인지 확인합니다. 토큰이 필요 없는 공개 API입니다.")
    @GetMapping("/email/{email}")
    public EmailCheckResponse checkEmail(@PathVariable("email") @Email String email) {
        return memberService.checkEmail(email);
    }

    @Operation(
            summary = "회원가입",
            description = "이메일, 비밀번호, 닉네임으로 회원을 등록합니다. 토큰이 없어도 호출할 수 있는 공개 API입니다."
    )
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "회원가입 성공 (COMMON201)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "요청 값 검증 실패 (COMMON4001)", content = @Content),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "이미 사용 중인 이메일 (MEMBER4091) 또는 닉네임 (MEMBER4092)", content = @Content)
    })
    @PostMapping
    public ResponseEntity<ApiResponse<MemberResponse>> signUp(@Valid @RequestBody SignUpRequest request) {
        MemberResponse response = memberService.signUp(request);
        return ResponseEntity.status(201).body(ApiResponse.created("회원가입에 성공했습니다.", response));
    }

    // 인터셉터가 request에 담아둔 memberId를 꺼내 쓴다. URL 어디에도 누구의 정보인지 적지 않는다.
    @Operation(summary = "내 정보 조회", description = "토큰의 주인인 회원의 정보를 조회합니다. 토큰이 필요합니다.")
    @SecurityRequirement(name = SwaggerConfig.BEARER_AUTH)
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "조회 성공 (COMMON200)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "토큰이 없거나(AUTH401_2) 유효하지 않거나(AUTH401_3) 만료됨(AUTH401_4)", content = @Content),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "토큰의 회원이 존재하지 않음 (MEMBER404_1)", content = @Content)
    })
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<MemberInfoResponse>> getMyInfo(
            @Parameter(hidden = true) @RequestAttribute(AuthInterceptor.MEMBER_ID) Long memberId) {
        return ResponseEntity.ok(ApiResponse.ok("회원 정보를 조회했습니다.", memberService.getMyInfo(memberId)));
    }

    @Operation(summary = "내 정보 수정", description = "토큰의 주인인 회원의 닉네임을 수정합니다. 토큰이 필요합니다.")
    @SecurityRequirement(name = SwaggerConfig.BEARER_AUTH)
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "수정 성공 (COMMON200)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "요청 값 검증 실패 (COMMON4001)", content = @Content),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "토큰이 없거나(AUTH401_2) 유효하지 않거나(AUTH401_3) 만료됨(AUTH401_4)", content = @Content),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "이미 사용 중인 닉네임 (MEMBER409_1)", content = @Content)
    })
    @PatchMapping("/me")
    public ResponseEntity<ApiResponse<MemberInfoResponse>> updateMyInfo(
            @Parameter(hidden = true) @RequestAttribute(AuthInterceptor.MEMBER_ID) Long memberId,
            @Valid @RequestBody MemberUpdateRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("회원 정보를 수정했습니다.", memberService.updateMyInfo(memberId, request)));
    }
}
