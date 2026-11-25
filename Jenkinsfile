
pipeline {
    agent any

    environment {
        IMAGE  = 'securedev-app'
        TAG    = "${env.BUILD_NUMBER}"
        APP    = 'securedev-app-ci'
        // Docker DIND para prueba de despliegue
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

        stage('Test - Pruebas unitarias') {
            steps {
                sh '''
                    docker run --rm -e SECRET_KEY=test-ci $IMAGE:$TAG python -c "
import app as m
c = m.create_app(database_path='/tmp/test.db').test_client()
assert c.get('/health').status_code == 200,      'health != 200'
assert c.get('/health').get_json() == {'status': 'ok'}, 'health payload'
assert c.get('/login').status_code == 200,       'login != 200'
assert c.get('/').status_code == 302,            'index sin sesion no redirige'
print('Pruebas unitarias OK')
"
                '''
            }
        }

        stage('SAST - Bandit (código)') {
            steps {
                sh '''
                    bandit -r app.py -f html -o bandit_report.html || true
                    bandit -r app.py || true
                '''
            }
        }

        stage('SCA - pip-audit (dependencias)') {
            steps {
                sh '''
                    if [ -f Pipfile.lock ]; then
                        pipenv requirements > requirements.ci.txt 2>/dev/null || pipenv lock -r > requirements.ci.txt
                        REQ=requirements.ci.txt
                    else
                        REQ=requirements.txt
                    fi
                    pip-audit -r "$REQ" -f json -o pip_audit_report.json || true
                    pip-audit -r "$REQ" || true
                '''
            }
        }

        stage('Deploy - Contenedor') {
            steps {
                sh '''
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
                    zap.sh -cmd -port 8090 -quickurl $TARGET -quickprogress \
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
