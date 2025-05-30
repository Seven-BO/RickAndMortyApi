pipeline {
    agent any

    environment {
        PROJECT_NAME = 'RickAndMorty'
        DOCKER_IMAGE = 'rickandmorty-api'
        DOCKER_TAG = "${BUILD_NUMBER}"
        CONTAINER_NAME = 'rickandmorty-api'
        APP_PORT = '8085'
        ARTIFACT_VERSION = 'v1'

        SONAR_PROJECT_KEY = 'RickAndMorty'
        SONAR_PROJECT_NAME = 'RickAndMorty'
    }

    tools {
        maven 'default'
        jdk 'default'
    }

    stages {
        stage('🔄 Checkout') {
            steps {
                echo '📥 Clonando repositorio...'
                checkout scm

                script {
                    env.GIT_COMMIT_MSG = sh(script: 'git log -1 --pretty=%B', returnStdout: true).trim()
                    env.GIT_AUTHOR = sh(script: 'git log -1 --pretty=%an', returnStdout: true).trim()
                }

                echo "📝 Commit: ${env.GIT_COMMIT_MSG}"
                echo "👤 Autor: ${env.GIT_AUTHOR}"
            }
        }

        stage('🧹 Clean and Build Application') {
            steps {
                echo '🧹 Limpiando y construyendo aplicación...'
                sh 'mvn clean package install -DskipTests'

                echo '🎯 Renombrando JAR generado a app.jar'
                sh '''
                    JAR_PATH=$(find target -name "*.jar" | grep -v "original" | head -n 1)
                    echo "JAR encontrado: $JAR_PATH"
                    mv "$JAR_PATH" target/app.jar
                '''

                echo '📦 Verificando contenido del JAR'
                sh 'jar tf target/app.jar | grep Application || true'
                sh 'unzip -p target/app.jar META-INF/MANIFEST.MF | grep Main || true'
            }
        }

        stage('🔍 Static Code Analysis - SonarQube') {
            steps {
                echo '🔍 Ejecutando análisis estático con SonarQube...'
                script {
                    withSonarQubeEnv('SonarQube') {
                        sh """
                            mvn sonar:sonar \\
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \\
                                -Dsonar.projectName='${SONAR_PROJECT_NAME}' \\
                                -Dsonar.projectVersion=${ARTIFACT_VERSION}-${BUILD_NUMBER} \\
                                -Dsonar.sources=src/main/java \\
                                -Dsonar.tests=src/test/java \\
                                -Dsonar.java.binaries=target/classes \\
                                -Dsonar.junit.reportPaths=target/surefire-reports
                        """
                    }
                }
            }
        }

        stage('🐳 Build Docker Image') {
            steps {
                echo '🐳 Construyendo imagen Docker...'
                script {
                    sh "docker stop ${CONTAINER_NAME} || true"
                    sh "docker rm ${CONTAINER_NAME} || true"

                    def dockerImage = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                    sh "docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest"

                    echo "✅ Imagen construida: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                }
            }
        }

        stage('🔍 Docker Image Security Scan') {
            steps {
                echo '🔍 Escaneando imagen Docker...'
                script {
                    try {
                        sh "docker scout cves ${DOCKER_IMAGE}:${DOCKER_TAG} || echo 'Docker Scout no disponible, continuando...'"
                    } catch (Exception e) {
                        echo "⚠️ Escaneo de seguridad no disponible: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('🚀 Deploy Container') {
            steps {
                echo '🚀 Desplegando contenedor Docker...'
                script {
                    sh "docker stop ${CONTAINER_NAME} || true"
                    sh "docker rm ${CONTAINER_NAME} || true"

                    sh """
                        docker run -d \\
                            --name ${CONTAINER_NAME} \\
                            --restart unless-stopped \\
                            -p ${APP_PORT}:${APP_PORT} \\
                            -e SPRING_PROFILES_ACTIVE=dev \\
                            -e JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseG1GC -XX:+UseContainerSupport" \\
                            ${DOCKER_IMAGE}:${DOCKER_TAG}
                    """

                    echo "✅ Contenedor desplegado: ${CONTAINER_NAME} (puerto ${APP_PORT} mapeado al host)"
                }
            }
        }
    }

    post {
        always {
            echo '🧹 Limpieza post-pipeline...'
            cleanWs()

            script {
                try {
                    sh "docker logs ${CONTAINER_NAME} --tail 50"
                } catch (Exception e) {
                    echo "No se pudieron obtener logs del contenedor"
                }
            }
        }

        success {
            echo '🎉 Pipeline ejecutado exitosamente!'
        }

        failure {
            echo '❌ Pipeline falló!'
            script {
                try {
                    sh "docker stop ${CONTAINER_NAME} || true"
                    sh "docker rm ${CONTAINER_NAME} || true"
                } catch (Exception e) {
                    echo "Error durante cleanup: ${e.getMessage()}"
                }
            }
        }

        unstable {
            echo '⚠️ Pipeline inestable - algunos tests fallaron'
        }
    }
}
