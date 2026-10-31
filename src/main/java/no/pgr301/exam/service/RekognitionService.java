package no.pgr301.exam.service;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.services.rekognition.RekognitionClient;
import software.amazon.awssdk.services.rekognition.model.DetectLabelsRequest;
import software.amazon.awssdk.services.rekognition.model.DetectLabelsResponse;
import software.amazon.awssdk.services.rekognition.model.Image;
import software.amazon.awssdk.services.rekognition.model.Label;

import java.util.List;

@Service
public class RekognitionService {

    private final RekognitionClient client;
    private final Timer detectLabelsTimer;

    public RekognitionService(RekognitionClient client, MeterRegistry registry) {
        this.client = client;
        this.detectLabelsTimer = Timer.builder("wishifai.rekognition.duration")
                .description("Tid brukt på DetectLabels-kallet mot Rekognition")
                .register(registry);
    }

    public List<String> detectLabels(byte[] bytes) {
        // record() måler tiden også når kallet kaster en exception
        DetectLabelsResponse resp = detectLabelsTimer.record(() -> client.detectLabels(DetectLabelsRequest.builder()
                .image(Image.builder().bytes(SdkBytes.fromByteArray(bytes)).build())
                .maxLabels(20)
                .minConfidence(70f)
                .build()));

        return resp.labels().stream().map(Label::name).toList();
    }
}
