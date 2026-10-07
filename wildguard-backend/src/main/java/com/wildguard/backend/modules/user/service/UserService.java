package com.wildguard.backend.modules.user.service;

import com.wildguard.backend.modules.user.dto.RangerProfileResponse;
import com.wildguard.backend.modules.user.model.User;

public interface UserService {

    RangerProfileResponse getRangerProfile(String username);

    User findByUsername(String username);

    User findById(String id);
}
