package com.wildlife.uc02.service.api;
import com.wildlife.uc02.dto.SyncBatchRequest;
import com.wildlife.uc02.dto.SyncBatchResponse;
/** Processes offline ranger sync batches with idempotency. */
public interface SyncService {
    SyncBatchResponse process(SyncBatchRequest request, String rangerId);
}