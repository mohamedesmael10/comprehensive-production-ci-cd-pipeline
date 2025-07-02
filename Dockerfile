FROM maven:3.9.0-eclipse-temurin-17 AS build

WORKDIR /app

COPY pom.xml .
COPY src ./src


RUN mvn --batch-mode clean package -DskipTests


FROM eclipse-temurin:17-jdk

WORKDIR /app

COPY --from=build /app/target/demoapp-1.0.0.jar ./demoapp.jar

EXPOSE 8080

# JVM options: faster startup & nicer container memory handling
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar demoapp.jar"]

