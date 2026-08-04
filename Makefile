DK := docker
DKC_CMD := compose
DKC := $(DK) $(DKC_CMD)
APP := $(DK) $(DKC_CMD) exec app bash -c

.PHONY: help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

ci: ## CI/CD
	$(MAKE) composer-validate
	$(MAKE) symfony-requirements

composer-validate: ## Validate composer.json and composer.lock
	$(APP) "composer validate"

composer-install: ## Install composer dependencies
	$(APP) "composer install --no-interaction --optimize-autoloader"

symfony-requirements: ## Check Symfony requirements
	$(APP) "php -v"
	$(APP) "cd /var/www/html && php bin/console about"

init-dev: ## Initialise configuration
	$(APP) /var/www/html/install_docker_dev.sh

up: ## Up all your containers
	$(DKC) pull
	$(DKC) build --pull --force-rm  --no-cache
	$(DKC) up -d --remove-orphans
	$(DKC) ps

%:
	@:

