# Google Cloud Build and Skaffold Quick Demo

This repository contains a simple example of how to use [Google Cloud Build](https://cloud.google.com/cloud-build/) and [Skaffold](https://skaffold.dev/docs/).

## Installation

### Option 1: Running locally with “Docker for Desktop” and Skaffold

> 💡 Recommended if you're planning to develop the application.

1. Install tools to run a Kubernetes cluster locally:

   - kubectl (can be installed via `gcloud components install kubectl`)
   - Docker for Desktop (Mac/Windows): It provides Kubernetes support as [noted here](https://docs.docker.com/docker-for-mac/kubernetes/).
   - [skaffold](https://github.com/GoogleContainerTools/skaffold/#installation)
     (ensure version ≥v0.20)

2. Launch “Docker for Desktop”. Go to Preferences:
   - choose **Enable Kubernetes**,
   - set CPUs to at least **3**, and Memory to at least **4.0** GiB

3. Run `kubectl get nodes` to verify you're connected to “Kubernetes on Docker”.

4. Run `skaffold run`. This will build and deploy the application. If you need to rebuild the images
   automatically as you refactor the code, run the `skaffold dev` command.

5. Run `kubectl get pods` to verify the Pods are ready and running. The
   application frontend should be available at **http://localhost:8000** on your
   machine.

### Option 2: Running on Google Kubernetes Engine (GKE) with Skaffold

> 💡  Recommended for demos and making it available publicly.

1. Install tools specified in the previous section (Docker, kubectl, skaffold)

2. Create a Google Kubernetes Engine cluster and make sure `kubectl` is pointing to the cluster.

  ```bash
  export REGION="us-east4"
  # enable services
  gcloud services enable container.googleapis.com
  gcloud services enable cloudbuild.googleapis.com
  # create cluster
  gcloud container clusters create gcb --enable-autoupgrade --num-nodes 2 --zone ${REGION}-c
  # confirm cluster is up by querying the nodes
  kubectl get nodes
  ```

3. Enable Artifact Registry (AR) on your GCP project and configure the `docker` CLI to authenticate to AR:
	
  ```bash
  export REPO_NAME="demo"
  gcloud services enable artifactregistry.googleapis.com
  gcloud -q artifacts repositories create $(REPO_NAME) \
      --repository-format docker --location $(REGION)
  gcloud -q auth configure-docker $(REGION)-docker.pkg.dev
  ```

4. In the root of this repository, run:
	
  ```bash
  export PROJECT_ID=$(gcloud -q config get-value project)
  export FULL_REPO_NAME=${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/flask
	skaffold run --default-repo=${FULL_REPO_NAME}
  ```
  
   This command:
   - builds the container images
   - pushes them to AR
   - applies the `./k8s-manifests` deploying the application to Kubernetes.
  
   **Troubleshooting:** If you get "No space left on device" error on Google Cloud Shell, you can build the images on Google Cloud Build: [Enable the Cloud BuildAPI](https://console.cloud.google.com/flows/enableapi?apiid=cloudbuild.googleapis.com), then run `skaffold run -p gcb  --default-repo=${FULL_REPO_NAME}` instead.
  
5.  Find the IP address of your application, then visit the application on your browser to confirm installation: `kubectl get service flask-svc`

    **Troubleshooting:** A Kubernetes bug (will be fixed in 1.12) combined with a Skaffold [bug](https://github.com/GoogleContainerTools/skaffold/issues/887)causes load balancer to not to work even after getting an IP address. If you are seeing this, run `kubectl get service flask-svc -o=yaml | kubectl apply -f-`to trigger load balancer reconfiguration.

### Option 3: Using Google Cloud Build with Triggers on Cloud Source Repository

We can also create a trigger on a source code repository to kick off a build every time there is a commit. So let's create a trigger. In the console go to **Cloud Build** -> **Triggers** -> **Add Trigger**. Then select the source of **Cloud Source Repository**:

![Add_Trigger](https://storage.googleapis.com/gweb-cloudblog-publish/images/gcp-CSR_19og8.max-800x800.PNG)

Next choose your repo, and laslty configure the trigger to read the steps from the **cloudbuild.yaml** file which has all the steps to complete.

![Trigger_Config](https://storage.googleapis.com/gweb-cloudblog-publish/images/gcp-CSR_293i4.max-1200x1200.PNG)

If you are using another kubernetes cluster don't forget to add the [substitution variables](https://cloud.google.com/cloud-build/docs/configuring-builds/substitute-variable-values). This would have a similar build process to this:

![pipeline-flow](https://cloud.google.com/kubernetes-engine/images/gitops-tutorial-pipeline-architecture.svg)

Now make a change, and push to your repository:

```bash
git add .
git commit -m "Update file"
git push origin main
# if you made the trigger depend on tags, run the following
git tag v1.1
git push --tags
```

The trigger will kick off a build and you can check out the logs:

```bash
> gcloud builds list --limit 1
ID                                    CREATE_TIME                DURATION  SOURCE               IMAGES                                 STATUS
688fbdbc-2adf-492e-833a-501609598c4b  2019-02-10T23:32:05+00:00  42S       skaffold-gcb@master  gcr.io/gcp-project/flask (+1 more)  SUCCESS
```

If it's successful, check out the logs:

```bash
> gcloud builds log $(gcloud builds list --limit 1 --format "value(id)") | grep -E "Finished|Starting|DONE"
Starting Step #0 - "Pull-docker-image"
Finished Step #0 - "Pull-docker-image"
Starting Step #1 - "Build-Docker-Image"
Finished Step #1 - "Build-Docker-Image"
Starting Step #2 - "Push-the-Docker-Image-to-AR"
Finished Step #2 - "Push-the-Docker-Image-to-AR"
Starting Step #3 - "Rename-image-hash"
Finished Step #3 - "Rename-image-hash"
Starting Step #4 - "Update-K8S"
Finished Step #4 - "Update-K8S"
DONE
```