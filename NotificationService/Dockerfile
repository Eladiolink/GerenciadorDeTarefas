# syntax=docker/dockerfile:1

# ---------- Build ----------
FROM maven:3.10.0-eclipse-temurin-25-noble AS build

WORKDIR /workspace

# Copia o pom primeiro para aproveitar o cache das dependencias
COPY pom.xml .
RUN mvn -B -ntp dependency:go-offline

# Copia o codigo e gera o jar executavel
COPY src ./src
RUN mvn -B -ntp clean package -DskipTests

# ---------- Runtime ----------
FROM eclipse-temurin:25-jre-noble

# Usuario sem privilegios para executar a aplicacao
RUN useradd --create-home --uid 1001 appuser

WORKDIR /app
COPY --from=build --chown=appuser:appuser /workspace/target/*.jar app.jar

USER appuser

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
