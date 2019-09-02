IMAGE_NAME=terrassa
APP_NAME=terrassa
IMAGE_PORT=80
HOST_PORT=80
HUGO_SITE=exampleSite
HUGO_BASE_URL=https://danielkvist.github.io/terrassa/

hugo-build:
	cd ./$(HUGO_SITE) && hugo
hugo-build-min:
	cd ./$(HUGO_SITE) && hugo --minify
hugo-build-deploy:
	cd ./$(HUGO_SITE) && hugo --minify --baseURL="$(HUGO_BASE_URL)"
hugo-server:
	cd ./$(HUGO_SITE) && hugo server -w
hugo-server-draft:
	cd ./$(HUGO_SITE) && hugo server -w -D
hugo-clean:
	cd ./$(HUGO_SITE) && rm -rf ./public
docker:
	docker image build --build-arg HUGO_SITE=$(HUGO_SITE) --build-arg EXPOSE=$(IMAGE_PORT) -t $(IMAGE_NAME) .
docker-nc:
	docker image build --build-arg HUGO_SITE=$(HUGO_SITE) --build-arg EXPOSE=$(IMAGE_PORT) --no-cache -t $(IMAGE_NAME) .
docker-run:
	docker container run -d -p $(IMAGE_PORT):$(HOST_PORT) --name $(APP_NAME) $(IMAGE_NAME)
docker-stop:
	docker container stop $(APP_NAME)
docker-rm:
	docker container rm $(APP_NAME)
dev: hugo-server-draft
build: huo-build-deploy
check: hugo-build-min docker-nc docker-run
clean: docker-stop docker-rm hugo-clean