# Copyright 2021 Google LLC
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
ZONE = us-east4-c
REGION = us-east4
REPO_NAME = demo
FULL_REPO_NAME = $(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(REPO_NAME)/flask

.PHONY: k8s-cluster
cluster:
	#gcloud container clusters create new-cluster --async
	gcloud -q container clusters create demo \
    --num-nodes 2 --verbosity error --zone $(ZONE)
	kubectx demo=.

.PHONY: repo
repo:
	gcloud -q artifacts repositories create $(REPO_NAME) \
    --repository-format docker --location $(REGION)

.PHONY: run-python
run-python:
	src/flask/app/app.py	

.PHONY: build-docker
build-docker:
	cd src/flask && docker build . -t flask
	cd ../..
	docker images -q flask

.PHONY: run-docker
run-docker:
	docker run --rm -d --name my-flask-app -p 8000:8000 flask
	sleep 3
	curl http://localhost:8000
	docker logs -f my-flask-app

.PHONY: push-docker
push-docker:
	docker tag flask $(FULL_REPO_NAME)
	gcloud -q auth configure-docker $(REGION)-docker.pkg.dev
	docker push $(FULL_REPO_NAME)
	gcloud artifacts docker images list \
	  $(FULL_REPO_NAME) --filter flask

.PHONY: deploy-to-k8s
deploy-to-k8s:
	kubectx demo
	sed -i "" "s^newName: flask^newName: $(FULL_REPO_NAME)^g" \
      k8s-manifests/kustomization.yaml
	kubectl apply -k k8s-manifests/

.PHONY: prep-for-git
prep-for-git:
	sed -i "" "s^newName: .*^newName: flask^g" \
      k8s-manifests/kustomization.yaml

.PHONY: git-push-tags
git-push-tags:
	git tag v1.1
	git push --tags

.PHONY: git-del-tags
git-del-tags:
	git tag -d v1.1
	git push origin :refs/tags/v1.1

.PHONY: skaffold-deploy
skaffold-deploy:
	skaffold dev -d gcr.io/$(PROJECT_ID)

.PHONY: teardown-gcp
teardown-gcp:
	gcloud -q container clusters delete demo --zone $(ZONE) --async | true
	gcloud -q artifacts repositories delete $(REPO_NAME) --location $(REGION)

.PHONY: teardown-docker
teardown-docker:
	#docker stop `docker ps -q` | true
	#docker rm `docker ps -a -q` | true
	docker stop my-flask-app | true
	docker rm my-flask-app | true
	docker rmi -f `docker images -q flask` | true
	docker rmi -f `docker images -q $(FULL_REPO_NAME)` | true

.PHONY: teardown-k8s
teardown-k8s:
	kubectx demo
	kubectl delete -f k8s-manifests/ | true

.PHONY: teardown
teardown:
	kubectx demo
	kubectl delete -f k8s-manifests/ | true
	gcloud -q container clusters delete demo --zone $(ZONE) --async | true
	gcloud -q artifacts repositories delete $(REPO_NAME) --location $(REGION) 
	docker stop `docker ps -q` | true
	docker rm -f `docker ps -a -q` | true
	docker rmi -f `docker images -q flask` | true
	docker rmi -f `docker images -q $(FULL_REPO_NAME)` | true
	git tag -d v1.1
	git push origin :refs/tags/v1.1
