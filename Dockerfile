FROM maven:3.9.0-eclipse-temurin-17 AS build
WORKDIR /app

COPY . .

RUN mvn --batch-mode clean package -DskipTests

FROM eclipse-temurin:17-jre
WORKDIR /app

COPY --from=build /app/target/demoapp-1.0.0.jar ./demoapp.jar

EXPOSE 8080

# JVM options: faster startup & nicer container memory handling
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-jar", "demoapp.jar"]




