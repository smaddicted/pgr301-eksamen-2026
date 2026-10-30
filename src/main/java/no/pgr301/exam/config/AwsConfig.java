package no.pgr301.exam.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;
import software.amazon.awssdk.services.rekognition.RekognitionClient;
import software.amazon.awssdk.services.s3.S3Client;

@Configuration
public class AwsConfig {

    @Bean
    public S3Client s3Client(@Value("${aws.region}") String region) {
        return S3Client.builder().region(Region.of(region)).build();
    }

    @Bean
    public RekognitionClient rekognitionClient(@Value("${aws.region}") String region) {
        return RekognitionClient.builder().region(Region.of(region)).build();
    }

    @Bean
    public BedrockRuntimeClient bedrockRuntimeClient(@Value("${aws.region}") String region) {
        return BedrockRuntimeClient.builder().region(Region.of(region)).build();
    }
}
