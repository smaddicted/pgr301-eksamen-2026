# PGR301 Eksamen 2026 — wishif.ai

<img alt="Wishifai" src="media/wishifai_banner.png">

Wishifai — en Oslo-basert startup — skal en gang for alle løse problemet med julegave- og bursdagsønsker, og strevet med å finne riktige gaver til familie, barn og venner.
Bare last opp et bilde av en stue, et barnerom eller garasjen til bestefar — Wishifai finner noe som passer. Prosjektet er naturligvis "vibe-kodet" av
solo-grunderen, og han trenger nå sårt å få orden på utviklingsprosessen før han lanserer i desember 2026.

Han har selv skrevet en Spring Boot-applikasjon som tar imot et bilde, laster det opp til S3, og bruker AWS Rekognition til å finne ut
hva slags objekter som finnes på bildet. Dette mates inn i en AWS Bedrock-prompt, som igjen genererer en liste med mulige gaveønsker som kan passe.

Din oppgave er å gjøre løsningen produksjonsklar: containerisere, deploye med Terraform, overvåke og sikre.

### Litt om Rekognition og Bedrock

**AWS Rekognition** er en ferdigtrent "computer vision"-tjeneste. Du sender inn et bilde, og får tilbake en liste med labels — f.eks. `Sofa (98%)`, `Lamp (87%)`, `Child (72%)` — pluss tekst, ansikter og objekter den gjenkjenner. Wishifai bruker labelene som input til neste steg.

**AWS Bedrock** er AWS sin administrerte tjeneste for store språkmodeller (Claude, Llama, Titan m.fl.). Wishifai bygger en prompt av Rekognition-labelene ("foreslå gaver basert på disse objektene i rommet …") og lar en LLM via Bedrock generere selve gavelisten. Bedrock er altså det som gjør tjenesten "AI-drevet" — og samtidig ikke-deterministisk, kostnadsvariabel og vanskelig å teste tradisjonelt. Det er temaer dere kommer tilbake til i oppgave 3 og 4.


## Krav til levering i Wiseflow

- Opprett et **nytt** GitHub-repository (ikke fork). Kopier inn innholdet herfra.
- For å unngå at andre studenter ser din besvarelse, kan du gjerne jobbe i et privat repository. Gjør repositoryet offentlig rett før innleveringsfristen.
- Flere oppgaver gir rom for egne valg — begrunn valgene dine og besvar oppgavene i en fil du kaller `README_SVAR.md` i ditt eget repo.
- Lever repo-URL som PDF/TXT i Wiseflow.

## Utviklingsmiljø

Hele eksamen er løsbar i et **GitHub Codespace**, slik dere er vant til fra lab-ene.

Dette repoet inneholder en ferdig `.devcontainer/`-konfigurasjon med alle verktøyene som trengs forhåndsinstallert: Java 21, Maven, Docker, AWS CLI og Terraform. Hvis du vil bruke Codespaces kan du kopiere filen fra `.devcontainer`-mappen i dette repoet til ditt eget.

Dere må selv konfigurere Codespaces med AWS nøkler som vanlig.


## Vurdering

| Oppgave | Poeng |
|---------|-------|
| 1 Container og CI | 20 |
| 2 ECS Express og IaC | 25 |
| 3 Observability | 20 |
| 4 Drøfteoppgave | 15 |
| **Totalt** | **80** |

Hvis du velger å ikke besvare en oppgave, nevn det i `README_SVAR.md`.

## Før du starter

Før du går videre bør du teste at Spring Boot-applikasjonen fungerer som forventet.

Start applikasjonen, og send inn et bilde med `curl` fra en annen terminal (fra repo-rot). Eksempelet under fungerer på Mac, Linux og i Codespaces:

```
curl -F "image=@samples/sample_image.png" http://localhost:8080/api/analyze
```

Som respons på et bilde får du et JSON-objekt som inneholder gaveønsker og begrunnelse for valgene som er gjort.
NB.  Før du har gjort oppgave 3 får du feilmeldinger fra Spring Boot applikasjonen. 

### Oppgave 1 — Container og CI (20p)

I denne oppgaven skal dere gjøre kodebasen klar for et større utviklingsteam, og sørge for at gode DevOps-praksiser blir fulgt.


#### 1A — Containerisér Spring Boot-applikasjonen

Dere skal lage en multi-stage `Dockerfile` for Spring Boot-applikasjonen. Grunderen har hittil deployet ved å zippe JAR-filen og scp-e den opp til en EC2-instans fra MacBooken sin. Det er dagens-gang-i-staur-territorium — vi skal gjøre dette ordentlig.

Multi-stage build betyr at build-verktøyene (Maven, JDK, kildekode) ikke henger med inn i det endelige imaget. Resultatet er mindre, raskere, og eksponerer færre avhengigheter enn nødvendig.

Leveranser: `Dockerfile`, `docker run …`-kommando som sensor kan kjøre for å starte en container som lytter på localhost:9999.

#### 1B — CI-pipeline

Dere skal sette opp en GitHub Actions-workflow som bygger Wishifai Spring Boot-containeren og publiserer den til **ECR**. ECR brukes senere i oppgave 2 når tjenesten skal kjøre på AWS; Docker Hub gjør det enkelt for sensor å trekke og teste imaget lokalt.

Workflowen skal **kun kjøre ved push til `main`**.

Dere velger selv en fornuftig tagging-strategi. `latest` alene er ikke tilstrekkelig — commit-SHA, versjon, eller tilsvarende må være med slik at det er mulig å spore hva som faktisk kjører hvor. Begrunn valget kort i `README_SVAR.md`. Aksessnøkler skal ligge som GitHub Secrets, ikke i workflow-filen! (Please!)

ECR-repoet kan opprettes manuelt med CLI eller i AWS Console, altså - trenger ikke gjøres i pipeline.

Leveranser: workflow-fil i repo, lenke til grønn kjøring, begrunnelse av tagging-strategi i `README_SVAR.md`.

### Oppgave 2 — ECS Express med Terraform (25p)

Grunderen har så langt kjørt applikasjonen på en EC2-instans han manuelt setter opp i konsollen. Når én utvikler blir fem, holder ikke dét lenger — infrastrukturen må være kode, revisjonskontrollert, og mulig å gjenskape fra scratch.

I denne oppgaven skal dere flytte tjenesten over på **ECS Express**, Amazons forenklede container-tjeneste som gir dere "serverløse" containere og lastbalansering uten alt det manuelle oppsettet av nettverk og infrastruktur.

Nyttige referanser:
- AWS ECS Express Mode (konsepter, defaults, hva som opprettes): <https://docs.aws.amazon.com/AmazonECS/latest/developerguide/express-service-overview.html>
- Terraform-ressursen: <https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_express_gateway_service>

#### 2A — Infrastruktur for tjenesten

Lag Terraform-kode for **minst** en ECS Express tjeneste og S3 bucket for lagring av bilder for din applikasjon. 

All Terraform-kode skal ligge i en mappe `infra/` i repoet. Tjenesten skal eksponere et offentlig endepunkt sensor kan teste. Bruk variabler for det som skal kunne endres (region, kandidatnummer, image-tag), og eksponér nyttige verdier via `outputs` — minimum selve URL-en.

**IAM-roller:** For å unngå rolleksplosjon i klassens AWS-konto, bruk de eksisterende rollene nedenfor i stedet for å opprette nye. Begge finnes allerede i kontoen og kan refereres direkte:

- **Execution role:** `arn:aws:iam::244530008913:role/ecsTaskExecutionRole`
- **Infrastructure role:** `arn:aws:iam::244530008913:role/service-role/ecsInfrastructureRoleForExpressServices`

For at tjenesten faktisk skal kunne kalle Rekognition, Bedrock og S3 trenger task-en en egen **task role** (ikke task execution role). Opprett én slik rolle i Terraform, suffikset med kandidatnummer, med nødvendige tillatelser.

Hvis dere ser i `application.properties` så leser applikasjonen en miljø-variabel som heter S3_BUCKET. Denne bestemmer bucket-navn for opplasting av bilder. Pass på at denne verdien automatisk blir satt i Terraform koden.  

Leveranser: Terraform-kode i `infra/`, offentlig URL til tjenesten.

#### 2B — Remote state

Terraform-state skal lagres i en **S3 backend**, ikke lokalt. Dette er grunnlaget for at flere utviklere kan jobbe mot samme infrastruktur uten å overskrive hverandre.

Bruk den delte bucketen **`pgr301-terraform-state`** i klassens AWS-konto. Velg et filnavn som gir unikhet pr. kandidat, f.eks. `wishifai/<kandidatnummer>/terraform.tfstate`. Dokumentér valgt nøkkel i `README_SVAR.md`.

Leveranser: `backend`-konfigurasjon i Terraform-koden som peker på `pgr301-terraform-state`.

#### 2C — GitHub Actions-job for Terraform

Dere skal utvide workflow-filen fra oppgave 1B med en ny job som kjører Terraform. Jobben skal ligge i **samme workflow-fil** som container-byggejobben, og skal være **avhengig av** (`needs:`) jobben som bygger og publiserer containeren. Rekkefølgen må altså være: først bygg og push image til ECR, deretter kjør Terraform mot den nye image-taggen.

Terraform-jobben skal minst kjøre `terraform init` og `terraform apply` mot `infra/`-mappen. AWS-credentials skal hentes fra GitHub Secrets på samme måte som i 1B.

Pipelinen skal også feile dersom Terraform-koden ikke er riktig formatert.

Begrunn kort i `README_SVAR.md` hvorfor det er fornuftig at Terraform kjører *etter* container-build, og ikke parallelt eller før.

Leveranser: oppdatert workflow-fil med to jobs i riktig rekkefølge, lenke til grønn kjøring.

### Oppgave 3 — Observability (20p)

Grunderen oppdaget nylig at tjenesten svarer veldig langsomt — og er redd for at dette skal være en deal-breaker for potensielle investorer. Det blir derfor din jobb å finne ut hvor tiden blir av.

#### 3A — Metrikker i applikasjonen

Dere skal instrumentere Spring Boot-applikasjonen med **Micrometer** og eksportere metrikkene til CloudWatch.

Applikasjonen har allerede nødvendige biblioteker på classpath (`micrometer-registry-cloudwatch2` + AWS CloudWatch SDK) og en ferdig `MetricsConfig`-klasse som wirer opp `CloudWatchMeterRegistry`. Dere trenger altså ikke sette opp selve CloudWatch-koblingen — fokus skal være på å *bruke* Micrometer til å måle det som er relevant.

Det er lov å utvide applikasjonen med mer funksjonalitet dersom det er hensiktsmessig for å illustrere bruk av metrikker.

Som et minimum skal følgende måles og publiseres som egne metrikker:

- Tiden det tar å kjøre **Rekognition**-kallet
- Tiden det tar å kjøre **Bedrock**-kallet
- Minst én **business-metrikk** — noe som sier noe om bruken av tjenesten, ikke bare teknisk helse. Eksempler: antall gaveforslag generert, antall bilder analysert pr. kategori (stue/barnerom/garasje), gjennomsnittlig antall forslag pr. prompt. Dere velger selv — begrunn valget.

I tillegg står dere fritt til å legge til flere metrikker (`Counter`, `Gauge`, `DistributionSummary`) der det gir reell innsikt.

Beskriv kort i `README_SVAR.md` hvilke metrikker dere valgte og hvorfor.

#### 3B — Dashboard og alarm

Dashboard og alarm skal defineres som kode i `infra/`. Dashbordet skal gi et helhetlig bilde av tjenesten og skal vise en **miks av tre typer metrikker**:

- **Business:** minst én av dine egne business-metrikker fra 3A
- **Infrastruktur:** metrikker fra ECS Express (f.eks. CPU-utilization, memory-utilization, running task count)
- **Applikasjon:** metrikker eksponert via Spring Boot Actuator (f.eks. JVM memory, HTTP request-latency, GC-tid)

Minst én CloudWatch Alarm skal være knyttet til en av dine egne metrikker.

Leveranser: Terraform-kode, screenshot av eller navn på dashboard med reelle data, kort begrunnelse av metrikkene og kort begrunnelse av alarmen (hva den varsler på og hvorfor).

### Oppgave 4 — Drøfteoppgave (15p)

En LLM kan generere anbefalinger som er upassende, misvisende eller potensielt skadelige, selv om applikasjonen fungerer teknisk som forventet. Wishifai kan for eksempel foreslå farlige eller aldersupassende gaver.

Konsekvensene av slike feil er selvfølgelig ikke veldig alvorlig i en gaveønskeapplikasjon. Situasjonen ville imidlertid vært annerledes dersom applikasjonen ga medisinske eller juridiske råd, der feilaktige svar kan få alvorlige konsekvenser. Tenkt en bank der kunderådgivere bruker AI, og at feil råd fører til økonomisk tap for kunden!

Drøft hvordan bruk av generativ AI påvirker DevOps-praksiser knyttet til områdene testing, kontinuerlig leveranse og overvåking. Hvordan bør disse praksisene tilpasses applikasjonens risikonivå for å sikre ansvarlig bruk av AI?

Besvarelsen skal være på **300–500 ord**.

Noen vinkler du kan bruke som utgangspunkt (du trenger ikke dekke alle):

- **Testing:** Hvordan må man tenke annerledes om test når output er ikke-deterministisk? Hva slags tester gir mening (f.eks. eval-sets, snapshot/regresjon, "LLM-as-judge", stikkprøver), og hvor passer de i pipelinen?
- **Kontinuerlig leveranse:** Hva "deployer" man egentlig når prompt, modellversjon og systemprompt kan endres uavhengig av koden? Hvordan versjonere og rulle tilbake prompts/modeller? Når bør man bruke feature flags, canary eller A/B?
- **Overvåking:** Hvilke signaler er viktige utover latency og feilrater — f.eks. token-forbruk/kostnad, andel refusals, lengde på svar, drift i input/output over tid? Hvordan oppdager man kvalitetsregresjon i produksjon?
- **Risiko og ansvar:** Hvordan skalerer disse praksisene med konsekvensene av feil (gaveliste vs. medisinsk/juridisk rådgivning)? Hva bør være "gates" før prod, og hva kan man leve med å oppdage i prod?
- **Menneske-i-loopen:** Når holder automatiserte tester, og når må mennesker inn (review av prompt-endringer, godkjenning av modellbytte, håndtering av rapporterte feil)?
- **Egen besvarelse:** Bruk gjerne konkrete eksempler fra din egen Wishifai-løsning (f.eks. hva din CloudWatch-alarm fra oppgave 3 ikke fanger opp).

---

Lykke til og ha det moro!


