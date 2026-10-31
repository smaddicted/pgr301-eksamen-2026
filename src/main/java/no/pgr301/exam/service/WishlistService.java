package no.pgr301.exam.service;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.DistributionSummary;
import io.micrometer.core.instrument.MeterRegistry;
import no.pgr301.exam.model.AnalyzeResponse;
import no.pgr301.exam.model.GiftAnalysis;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;

@Service
public class WishlistService {

    private final S3Service s3;
    private final RekognitionService rekognition;
    private final BedrockService bedrock;
    private final MeterRegistry registry;
    private final DistributionSummary suggestionsPerAnalysis;

    public WishlistService(S3Service s3, RekognitionService rekognition, BedrockService bedrock,
                           MeterRegistry registry) {
        this.s3 = s3;
        this.rekognition = rekognition;
        this.bedrock = bedrock;
        this.registry = registry;
        this.suggestionsPerAnalysis = DistributionSummary.builder("wishifai.suggestions.per.analysis")
                .description("Antall gaveforslag per analyserte bilde")
                .register(registry);
    }

    public AnalyzeResponse process(byte[] bytes, String filename, String contentType) {
        String s3Key = s3.upload(bytes, filename, contentType);
        List<String> labels = rekognition.detectLabels(bytes);
        GiftAnalysis analysis = bedrock.suggestGifts(labels);

        // Business-metrikker: hva slags rom brukerne laster opp, og hvor mange forslag de får
        Counter.builder("wishifai.images.analyzed")
                .description("Antall analyserte bilder per romtype")
                .tag("room", roomCategory(labels))
                .register(registry)
                .increment();
        suggestionsPerAnalysis.record(analysis.suggestions() == null ? 0 : analysis.suggestions().size());

        return new AnalyzeResponse(
                s3Key,
                labels,
                analysis.roomAnalysis(),
                analysis.recipientProfile(),
                analysis.suggestions(),
                Instant.now().toString()
        );
    }

    // Grov inndeling basert på Rekognition-labels. Få faste verdier holder antall
    // CloudWatch-dimensjoner nede.
    static String roomCategory(List<String> labels) {
        if (labels.stream().anyMatch(l -> List.of("Nursery", "Toy", "Crib", "Playroom", "Teddy Bear").contains(l))) {
            return "kids_room";
        }
        if (labels.stream().anyMatch(l -> List.of("Garage", "Workshop", "Tool").contains(l))) {
            return "garage";
        }
        if (labels.contains("Living Room")) {
            return "living_room";
        }
        if (labels.contains("Kitchen")) {
            return "kitchen";
        }
        return "other";
    }
}
