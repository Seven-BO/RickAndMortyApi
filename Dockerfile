# Dockerfile para Rick and Morty API - Spring Boot 3.0 + Java 17

# Etapa 1: Build
FROM eclipse-temurin:17-jdk-alpine AS build

# Instalar Maven
RUN apk add --no-cache maven

# Establecer directorio de trabajo
WORKDIR /app

# Copiar archivos de configuración Maven primero (para aprovechar cache de Docker)
COPY pom.xml .

# Descargar dependencias (se cachea si pom.xml no cambia)
RUN mvn dependency:go-offline -B

# Copiar código fuente
COPY src ./src

# Construir la aplicación
RUN mvn clean package -DskipTests

# Etapa 2: Runtime
FROM eclipse-temurin:17-jre-alpine

# Instalar curl para healthchecks
RUN apk add --no-cache curl

# Crear usuario no privilegiado para seguridad
RUN addgroup -g 1001 -S rickmorty && \
    adduser -u 1001 -S rickmorty -G rickmorty

# Establecer directorio de trabajo
WORKDIR /app

# Copiar el JAR generado desde la etapa de build
COPY --from=build /app/target/RickAndMorty-v1.jar rick-morty-api.jar

# Cambiar propietario del archivo
RUN chown rickmorty:rickmorty rick-morty-api.jar

# Cambiar a usuario no privilegiado
USER rickmorty

# Exponer puerto 8085 (según application.properties)
EXPOSE 8085

# Variables de entorno para JVM optimizadas para microservicio
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseG1GC -XX:+UseContainerSupport -Djava.security.egd=file:/dev/./urandom"

# Configurar Spring profiles
ENV SPRING_PROFILES_ACTIVE="production"

# Labels para metadata
LABEL description="Rick and Morty API - Spring Boot 3.0"
LABEL version="1.0"

# Healthcheck específico para la aplicación
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8085/character || exit 1

# Comando de inicio
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar rick-morty-api.jar"]