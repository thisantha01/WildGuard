package com.wildguard.backend.modules.teammates.uc03_community;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.security.Principal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/community-reports")
@RequiredArgsConstructor
public class CommunityReportController {
    private final CommunityReportService service;
    @GetMapping @PreAuthorize("hasAnyRole('LIAISON','VILLAGER')")
    public List<Map<String,Object>> reports(Principal principal) { return service.reports(principal.getName(), principalRoleIsLiaison()); }
    private boolean principalRoleIsLiaison() { return org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication().getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_LIAISON")); }
    @PostMapping @PreAuthorize("hasAnyRole('VILLAGER','LIAISON')")
    public ResponseEntity<Map<String,Object>> submit(@RequestBody Map<String,Object> body, Principal principal) { return ResponseEntity.ok(service.saveReport(body, principal.getName())); }
    @PatchMapping("/{id}/status") @PreAuthorize("hasRole('LIAISON')")
    public ResponseEntity<Map<String,Object>> status(@PathVariable String id, @RequestBody Map<String,Object> body, Principal principal) { body.put("id",id); return ResponseEntity.ok(service.saveReport(body, principal.getName())); }
    @PutMapping("/{id}/dispatch") @PreAuthorize("hasRole('LIAISON')")
    public ResponseEntity<Map<String,Object>> dispatch(@PathVariable String id, @RequestBody Map<String,Object> body, Principal principal) { body.put("id",id); body.put("status","IN_PROGRESS"); return ResponseEntity.ok(service.saveReport(body, principal.getName())); }
    @PostMapping("/{id}/publish-alert") @PreAuthorize("hasRole('LIAISON')")
    public ResponseEntity<Map<String,Object>> publish(@PathVariable String id, @RequestBody Map<String,Object> body) { body.put("id",body.getOrDefault("id","alert-"+id)); return ResponseEntity.ok(service.saveAlert(body)); }
    @GetMapping("/alerts") @PreAuthorize("hasAnyRole('LIAISON','VILLAGER')")
    public List<Map<String,Object>> alerts() { return service.alerts(); }
    @PostMapping("/alerts") @PreAuthorize("hasRole('LIAISON')")
    public ResponseEntity<Map<String,Object>> broadcast(@RequestBody Map<String,Object> body) { return ResponseEntity.ok(service.saveAlert(body)); }
}
