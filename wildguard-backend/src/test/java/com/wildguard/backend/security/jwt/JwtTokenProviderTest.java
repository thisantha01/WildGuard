package com.wildguard.backend.security.jwt;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("JwtTokenProvider Unit Tests")
class JwtTokenProviderTest {

    private JwtTokenProvider tokenProvider;
    private final String testSecret = "404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970";
    private final long testExpiration = 3600000L; // 1 hour

    @BeforeEach
    void setUp() {
        tokenProvider = new JwtTokenProvider();
        ReflectionTestUtils.setField(tokenProvider, "jwtSecret", testSecret);
        ReflectionTestUtils.setField(tokenProvider, "jwtExpirationMs", testExpiration);
    }

    @Test
    @DisplayName("Should successfully generate, extract username, and validate token")
    void generateAndValidateToken_Success() {
        String token = tokenProvider.generateTokenForUser("ranger_amila", "ROLE_RANGER");

        assertNotNull(token);
        assertTrue(tokenProvider.validateToken(token));
        assertEquals("ranger_amila", tokenProvider.getUsernameFromJwt(token));
        assertEquals(testExpiration, tokenProvider.getExpirationMs());
    }

    @Test
    @DisplayName("Should return false when token is invalid or malformed")
    void validateToken_Malformed_ReturnsFalse() {
        assertFalse(tokenProvider.validateToken("invalid.jwt.token"));
    }

    @Test
    @DisplayName("Should return false when token is null or empty")
    void validateToken_Empty_ReturnsFalse() {
        assertFalse(tokenProvider.validateToken(""));
    }
}
