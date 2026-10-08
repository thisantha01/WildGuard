package com.wildlife.uc02.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.Components;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;

/**
 * Spring Configuration for UC02 - Monitor Sensor Feeds & Trigger Proximity Geofence Alerts.
 * Provides system Clock for testable time handling, ObjectMapper, and OpenAPI documentation.
 */
@Configuration
public class Uc02Config {

    @Bean
    @ConditionalOnMissingBean(Clock.class)
    public Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    @ConditionalOnMissingBean(ObjectMapper.class)
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.registerModule(new JavaTimeModule());
        mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        return mapper;
    }

    @Bean
    public OpenAPI uc02OpenAPI() {
        final String securitySchemeName = "bearerAuth";
        return new OpenAPI()
                .info(new Info()
                        .title("WildGuard UC02 - Sensor Feed Monitoring & Geofence Proximity Alert System")
                        .description("Department of Wildlife Conservation (DWC) Sri Lanka API for tracking elephant telemetry collars, detecting geofence breaches, automated ranger dispatch, and field reports.")
                        .version("1.0.0")
                        .contact(new Contact().name("SE3070 Wildlife Engineering Team").email("dwc@wildguard.gov.lk"))
                        .license(new License().name("Apache 2.0").url("https://springdoc.org")))
                .addSecurityItem(new SecurityRequirement().addList(securitySchemeName))
                .components(new Components()
                        .addSecuritySchemes(securitySchemeName,
                                new SecurityScheme()
                                        .name(securitySchemeName)
                                        .type(SecurityScheme.Type.HTTP)
                                        .scheme("bearer")
                                        .bearerFormat("JWT")));
    }
}
