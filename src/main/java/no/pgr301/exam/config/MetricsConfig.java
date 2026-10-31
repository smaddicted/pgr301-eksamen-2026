package no.pgr301.exam.config;

import io.micrometer.cloudwatch2.CloudWatchConfig;
import io.micrometer.cloudwatch2.CloudWatchMeterRegistry;
import io.micrometer.core.instrument.Clock;
import io.micrometer.core.instrument.config.MeterFilter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.cloudwatch.CloudWatchAsyncClient;

import java.time.Duration;
import java.util.List;

@Configuration
public class MetricsConfig {

    // Bare metrikker med disse prefiksene sendes til CloudWatch. Hver metrikk koster penger,
    // og Spring Boot registrerer over hundre som standard.
    private static final List<String> ALLOWED_PREFIXES = List.of(
            "wishifai.",
            "http.server.requests",
            "jvm.memory.used",
            "jvm.gc.pause",
            "process.cpu.usage"
    );

    @Bean
    public CloudWatchAsyncClient cloudWatchAsyncClient(@Value("${aws.region}") String region) {
        return CloudWatchAsyncClient.builder().region(Region.of(region)).build();
    }

    @Bean
    public CloudWatchConfig cloudWatchConfig(@Value("${app.metrics.namespace}") String namespace) {
        return new CloudWatchConfig() {
            @Override
            public String get(String key) {
                return null;
            }

            @Override
            public String namespace() {
                // Tom namespace ble avvist av CloudWatch ("The parameter Namespace is required")
                return namespace;
            }

            @Override
            public Duration step() {
                return Duration.ofMinutes(1);
            }
        };
    }

    @Bean
    public CloudWatchMeterRegistry cloudWatchMeterRegistry(CloudWatchConfig config,
                                                           CloudWatchAsyncClient client) {
        return new CloudWatchMeterRegistry(config, Clock.SYSTEM, client);
    }

    @Bean
    public MeterFilter cloudWatchAllowList() {
        return MeterFilter.denyUnless(id -> ALLOWED_PREFIXES.stream().anyMatch(id.getName()::startsWith));
    }
}
