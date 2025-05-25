# Etapa 1: Build
FROM eclipse-temurin:17-jdk-alpine AS build

RUN apk add --no-cache maven file unzip

WORKDIR /app

COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src ./src

RUN mvn clean package -DskipTests

# DEBUG: Verifica contenido del target
RUN echo "--- DEBUG: Contenido de /app/target/ ---" && ls -lh /app/target/
RUN echo "--- DEBUG: Probando si app.jar es ejecutable ---" && \
    java -jar /app/target/app.jar --help || echo "DEBUG: JAR aún no es ejecutable."

# Etapa 2: Runtime
FROM eclipse-temurin:17-jre-alpine

RUN apk add --no-cache curl

RUN addgroup -g 1001 -S rickmorty && \
    adduser -u 1001 -S rickmorty -G rickmorty

WORKDIR /app

COPY --from=build /app/target/app.jar app.jar

RUN echo "--- DEBUG: Contenido en runtime ---" && ls -lh /app/
RUN echo "--- DEBUG: Buscando clase principal ---" && \
    unzip -l app.jar | grep "RickAndMortyApplication.class" || echo "Clase no encontrada."

RUN chown rickmorty:rickmorty app.jar

USER rickmorty

EXPOSE 8085

ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseG1GC -XX:+UseContainerSupport -Djava.security.egd=file:/dev/./urandom"
ENV SPRING_PROFILES_ACTIVE="production"

LABEL description="Rick and Morty API - Spring Boot 3.0"
LABEL version="1.0"

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8085/character || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
