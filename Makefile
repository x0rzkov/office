REPO=malice-plugins/office
ORG=malice
NAME=office
CATEGORY=document
VERSION=$(shell cat VERSION)
MALWARE?=tests/malware
EXTRACT?=/malware/tests/dump
MALICE_SCANID?=

all: build size tag test_all

.PHONY: build
build:
	cd $(VERSION); docker build -t $(ORG)/$(NAME):$(VERSION) .

.PHONY: size
size:
	sed -i.bu 's/docker%20image-.*-blue/docker%20image-$(shell docker images --format "{{.Size}}" $(ORG)/$(NAME):$(VERSION)| cut -d' ' -f1)-blue/' README.md

.PHONY: tag
tag:
	docker tag $(ORG)/$(NAME):$(VERSION) $(ORG)/$(NAME):latest

.PHONY: tags
tags:
	docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" $(ORG)/$(NAME)

.PHONY: ssh
ssh:
	@docker run --init -it --rm -v $(PWD):/malware --entrypoint=sh $(ORG)/$(NAME):$(VERSION)

.PHONY: tar
tar:
	docker save $(ORG)/$(NAME):$(VERSION) -o $(NAME).tar

.PHONY: start_elasticsearch
start_elasticsearch:
ifeq ("$(shell docker inspect -f {{.State.Running}} elasticsearch)", "true")
	@echo "===> elasticsearch already running"
else
	@echo "===> Starting elasticsearch"
	@docker rm -f elasticsearch || true
	@docker run --init -d --name elasticsearch -p 9200:9200 malice/elasticsearch:6.3; sleep 10
endif

.PHONY: malware
malware:
ifeq (,$(wildcard $(MALWARE)))
	wget https://github.com/maliceio/malice-av/raw/master/samples/befb88b89c2eb401900a68e9f5b78764203f2b48264fcc3f7121bf04a57fd408 -O $(MALWARE)
	cd tests; echo "TEST" > not.malware
endif

.PHONY: test_all
test_all: test test_elastic test_markdown test_web

.PHONY: test
test: malware
	@echo "===> ${NAME} --help"
	@docker run --rm $(ORG)/$(NAME):$(VERSION); sleep 10
	@echo "===> ${NAME} malware test"
	@docker run --rm -v $(PWD):/malware $(ORG)/$(NAME):$(VERSION) scan -vvvv -d --output $(EXTRACT) $(MALWARE) | jq . > docs/results.json
	@cat docs/results.json | jq .

.PHONY: test_elastic
test_elastic: start_elasticsearch malware
	@echo "===> ${NAME} test_elastic found"
	docker run --rm --link elasticsearch -e MALICE_ELASTICSEARCH=elasticsearch -v $(PWD):/malware $(ORG)/$(NAME):$(VERSION) scan -vvvv -d --output $(EXTRACT) $(MALWARE)
	# @echo "===> ${NAME} test_elastic NOT found"
	# docker run --rm --link elasticsearch -e MALICE_ELASTICSEARCH=elasticsearch $(ORG)/$(NAME):$(VERSION) -V --api ${MALICE_VT_API} lookup $(MISSING_HASH)
	http localhost:9200/malice/_search | jq . > docs/elastic.json

.PHONY: test_markdown
test_markdown: test_elastic
	@echo "===> ${NAME} test_markdown"
	# http localhost:9200/malice/_search query:=@docs/query.json | jq . > docs/elastic.json
	cat docs/elastic.json | jq -r '.hits.hits[] ._source.plugins.${CATEGORY}.${NAME}.markdown' > docs/SAMPLE.md

.PHONY: test_malice
test_malice:
	@echo "===> $(ORG)/$(NAME):$(VERSION) testing with running malice elasticsearch DB (update existing sample)"
	@docker run --rm -e MALICE_SCANID=$(MALICE_SCANID) -e MALICE_ELASTICSEARCH=elasticsearch --link malice-elastic:elasticsearch -v $(PWD):/malware $(ORG)/$(NAME):$(VERSION) scan -t -vvvv $(MALWARE)

.PHONY: test_web
test_web: malware stop
	@echo "===> Starting web service"
	@docker run -d --name $(NAME)-web -p 3993:3993 $(ORG)/$(NAME):$(VERSION) web
	sleep 10; http -f localhost:3993/scan malware@tests/hw2.exe
	@echo "===> Stopping web service"
	@docker logs $(NAME)-web
	@docker rm -f $(NAME)-web

.PHONY: run
run: stop ## Run docker container
	@docker run --init -d --name $(NAME) -p 9200:9200 $(ORG)/$(NAME):$(VERSION)

.PHONY: stop
stop: ## Kill running docker containers
	@docker rm -f $(NAME) || true

.PHONY: circle
circle: ci-size
	@sed -i.bu 's/docker%20image-.*-blue/docker%20image-$(shell cat .circleci/SIZE)-blue/' README.md
	@echo "===> Image size is: $(shell cat .circleci/SIZE)"

ci-build:
	@echo "===> Getting CircleCI build number"
	@http https://circleci.com/api/v1.1/project/github/${REPO} | jq '.[0].build_num' > .circleci/build_num

ci-size: ci-build
	@echo "===> Getting image build size from CircleCI"
	@http "$(shell http https://circleci.com/api/v1.1/project/github/${REPO}/$(shell cat .circleci/build_num)/artifacts${CIRCLE_TOKEN} | jq '.[].url')" > .circleci/SIZE

clean: clean_pyc ## Clean docker image and stop all running containers
	docker-clean stop
	docker rmi $(ORG)/$(NAME):$(VERSION) || true
	docker rmi $(ORG)/$(NAME):dev || true
	rm $(MALWARE) || true
	rm README.md.bu || true

## Clean all compiled python files
clean_pyc:
	find . -name "*.pyc" -exec rm -f {} \;
	rm *.log || true
	rm test/dump/* || true

# Absolutely awesome: http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help: Makefile
	@echo
	@echo " Choose a command run in "$(PROJECTNAME)":"
	@echo
	@sed -n 's/^##//p' $< | column -t -s ':' |  sed -e 's/^/ /'
	@echo

.DEFAULT_GOAL := all