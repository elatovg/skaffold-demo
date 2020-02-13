# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Make will use bash instead of sh
SHELL := /usr/bin/env bash
PROJECT_ID := $(shell gcloud config list --format "value(core.project)")

.PHONY: k8s-cluster
cluster:
	#gcloud container clusters create new-cluster --async
	gcloud -q container clusters create new-cluster \
    --num-nodes 1 --verbosity error

.PHONY: run-python
run-python:
	src/flask/app/app.py	

.PHONY: build-docker
build-docker:
	cd src/flask && docker build . -t flask
	cd -

.PHONY: run-docker
run-docker:
	docker run --rm -d --name my-flask-app -p 8000:8000 flask
	sleep 3
	curl http://localhost:8000
	docker logs my-flask-app

.PHONY: push-docker
push-docker:
	docker tag flask gcr.io/$(PROJECT_ID)/flask
	gcloud -q auth configure-docker
	docker push gcr.io/$(PROJECT_ID)/flask
	gcloud container images list

.PHONY: deploy-to-k8s
deploy-to-k8s:
	kubectx demo
	sed "s^image: flask^image: gcr.io/$(PROJECT_ID)/flask^g" \
    k8s-manifests/flask-deploy.yaml | kubectl apply -f -
	kubectl apply -f k8s-manifests/flask-svc.yaml	

.PHONY: skaffold-deploy
skaffold-deploy:
	skaffold dev -d gcr.io/$(PROJECT_ID)

.PHONY: teardown-gcp
teardown-gcp:
	gcloud -q container clusters delete new-cluster --async | true
	gcloud container images list-tags \
    gcr.io/$(PROJECT_ID)/flask \
    --format="value(tags)" | \
    xargs -I {} gcloud container images delete \
    --force-delete-tags --quiet \
    gcr.io/$(PROJECT_ID)/flask:{}


.PHONY: teardown-docker
teardown-docker:
	docker stop `docker ps -q` | true
	docker rm `docker ps -a -q` | true
	docker rmi -f `docker images -q flask` | true
	docker rmi -f `docker images -q gcr.io/$(PROJECT_ID)/flask` | true


.PHONY: teardown-k8s
teardown-k8s:
	kubectx demo
	kubectl delete -f k8s-manifests/ | true

.PHONY: teardown
teardown:
	gcloud -q container clusters delete new-cluster --async | true
	gcloud container images list-tags \
    gcr.io/$(PROJECT_ID)/flask \
    --format="value(tags)" | \
    xargs -I {} gcloud container images delete \
    --force-delete-tags --quiet \
    gcr.io/$(PROJECT_ID)/flask:{} | true
	docker stop `docker ps -q` | true
	docker rm -f `docker ps -a -q` | true
	docker rmi -f `docker images -q flask` | true
	docker rmi -f `docker images -q gcr.io/$(PROJECT_ID)/flask` | true
	kubectx demo
	kubectl delete -f k8s-manifests/ | true
