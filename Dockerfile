# Etapa 1: Build
FROM eclipse-temurin:17-jdk-alpine AS build

# Instalar Maven y las herramientas de depuración (file, unzip)
RUN apk add --no-cache maven file unzip

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

# Muestra el contenido del directorio target/ para verificar el JAR generado
RUN echo "--- DEBUG: Contenido de /app/target/ en la etapa de build ---" && ls -lh /app/target/
# Intenta ejecutar el JAR para ver si es un ejecutable de Spring Boot (puede fallar si no es un JAR final)
RUN echo "--- DEBUG: Probando si RickAndMorty-v1.jar es directamente ejecutable en la etapa de build ---" && \
    java -jar /app/target/RickAndMorty-v1.jar --help || echo "DEBUG: El JAR no es directamente ejecutable en la etapa de build, esto es normal si es el JAR original antes de repackage."


# Etapa 2: Runtime
FROM eclipse-temurin:17-jre-alpine

# Instalar curl para healthchecks (unzip ya lo instalaste en la etapa 1)
RUN apk add --no-cache curl

# Crear usuario no privilegiado para seguridad
RUN addgroup -g 1001 -S rickmorty && \
    adduser -u 1001 -S rickmorty -G rickmorty

# Establecer directorio de trabajo
WORKDIR /app

# Copiar el JAR generado desde la etapa de build con su nombre exacto
# Según tu pom.xml, el JAR se llama 'RickAndMorty-v1.jar'
COPY --from=build /app/target/RickAndMorty-v1.jar rick-morty-api.jar

# Muestra el contenido del directorio de trabajo después de copiar el JAR
RUN echo "--- DEBUG: Contenido de /app/ en la etapa de runtime después de COPY ---" && ls -lh /app/
# Descomprime el JAR y busca la clase principal para confirmar que está allí
RUN echo "--- DEBUG: Verificando el contenido del JAR copiado (buscando RickAndMortyApplication.class) ---" && \
    unzip -l rick-morty-api.jar | grep "RickAndMortyApplication.class" || echo "DEBUG: Clase RickAndMortyApplication.class NO encontrada en el JAR."

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