// Pipeline CI/CD seguro — OCY1102 EV3
// Etapas: Build -> SAST (Bandit) -> SCA (pip-audit) -> Deploy -> DAST (OWASP ZAP)
// Las herramientas de seguridad ya vienen instaladas en la imagen de Jenkins.
// Docker se ejecuta contra el daemon DinD (DOCKER_HOST ya configurado en el contenedor).
pipeline {
    agent any

    environment {
        IMAGE  = 'securedev-app'
        TAG    = "${env.BUILD_NUMBER}"
        APP    = 'securedev-app-ci'
        // El contenedor publica 8000 en el DinD (alias de red 'docker'),
        // por lo que desde el controlador Jenkins se alcanza en http://docker:8000
        TARGET = 'http://docker:8000'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {

        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Build - Imagen Docker') {
            steps {
                sh 'docker build -t $IMAGE:$TAG .'
            }
        }

        stage('SAST - Bandit (código)') {
            steps {
                sh '''
                    echo "===== Análisis estático con Bandit ====="
                    bandit -r app.py -f html -o bandit_report.html || true
                    bandit -r app.py || true
                '''
            }
        }

        stage('SCA - pip-audit (dependencias)') {
            steps {
                sh '''
                    echo "===== Auditoría de dependencias con pip-audit ====="
                    if [ -f Pipfile.lock ]; then
                        pipenv requirements > requirements.ci.txt 2>/dev/null || pipenv lock -r > requirements.ci.txt
                        REQ=requirements.ci.txt
                    else
                        REQ=requirements.txt
                    fi
                    echo "Auditando: $REQ"
                    pip-audit -r "$REQ" -f json -o pip_audit_report.json || true
                    pip-audit -r "$REQ" || true
                '''
            }
        }

        stage('Deploy - Contenedor') {
            steps {
                sh '''
                    echo "===== Despliegue del contenedor ====="
                    docker rm -f $APP || true
                    docker run -d --name $APP -p 8000:8000 \
                        -e HOST=0.0.0.0 -e SECRET_KEY=ci-pipeline-secret-$BUILD_NUMBER \
                        $IMAGE:$TAG
                    echo "Esperando readiness de la app..."
                    for i in $(seq 1 30); do
                        if curl -sf $TARGET/health >/dev/null 2>&1; then echo "App arriba"; break; fi
                        sleep 2
                    done
                '''
            }
        }

        stage('DAST - OWASP ZAP (app en ejecución)') {
            steps {
                sh '''
                    echo "===== Escaneo dinámico con OWASP ZAP ====="
                    zap.sh -cmd -quickurl $TARGET -quickprogress \
                        -quickout $WORKSPACE/zap_report.html || true
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'bandit_report.html, pip_audit_report.json, zap_report.html, requirements.ci.txt',
                             allowEmptyArchive: true
            sh 'docker rm -f $APP || true'
        }
    }
}
