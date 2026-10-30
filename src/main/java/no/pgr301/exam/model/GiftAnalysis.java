package no.pgr301.exam.model;

import java.util.List;

public record GiftAnalysis(
        String roomAnalysis,
        String recipientProfile,
        List<GiftSuggestion> suggestions
) {
}
