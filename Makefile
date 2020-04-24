APP_NAME := BenstalkEnv
APP_ENV_NAME := benstalk-app-env
AWS_REGION_NAME := ap-southeast-1
APP_S3_BUCKET_NAME := s3bucket

GIT_TAG := $(shell git describe --tags --always --abbrev=0)
PKG_VERISON := "$(APP_NAME)-$(GIT_TAG).zip"
VERSION_LABEL := $(APP_NAME)-$(GIT_TAG)

.PHONY: all coverage infection integration test lint fix help push

check-composer:
ifeq (, $(shell command composer))
	$(error You must have the composer command installed, run 'brew install composer' and rerun this command)
endif

all: check-composer lint fix pull-config build push

coverage: vendor ## Runs PHPUnit with coverage
	@vendor/bin/phpunit --coverage-text

lint: vendor ## Lint all PHP files in a given folder
	@vendor/bin/php-cs-fixer fix --config=.php_cs -vvv --ansi --diff

test: vendor ## Runs PHPUnit
	@vendor/bin/phpunit 

test-integration: test coverage ##Unit/Integration Tests & Coverage

build: # build package
	@zip -r $(PKG_VERISON) ./ -x *.git*, *.ebextensions* 

push: #push to S3
	@aws s3 cp $(PKG_VERISON) s3://$(APP_S3_BUCKET_NAME)/

create-application-version:
	@aws elasticbeanstalk create-application-version \
        --application-name $(APP_NAME) \
        --source-bundle S3Bucket="$(APP_S3_BUCKET_NAME)",S3Key="$(PKG_VERISON)" \
        --version-label "$(VERSION_LABEL)" \
        --description "$(VERSION_LABEL)"


deploy: #Deploy new App Version to Staging
	@aws elasticbeanstalk update-environment --environment-name $(APP_ENV_NAME) --version-label "$(VERSION_LABEL)"

      
vendor: composer.json composer.lock ## Run composer install
	@sudo composer self-update
	@composer validate
	@composer install

help: ## Display this help screen
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
