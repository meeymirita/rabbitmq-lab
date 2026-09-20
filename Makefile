APP_DIR := laravel-app

install-laravel:
	cd $(APP_DIR) && composer create-project --prefer-dist laravel/laravel .

env-prepare:
	cd $(APP_DIR) && cp -n .env.example .env

install:
	cd $(APP_DIR) && composer install

prepare:
	cd $(APP_DIR) && php artisan key:generate && php artisan migrate:fresh

up:
	cd $(APP_DIR) && docker compose up -d --build