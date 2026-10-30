package no.pgr301.exam.model;

import java.util.List;

public record AnalyzeResponse(
        String s3Key,
        List<String> labels,
        String roomAnalysis,
        String recipientProfile,
        List<GiftSuggestion> suggestions,
        String timestamp
) {
}
