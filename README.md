# RabbitMQ Lab — Transactional Outbox, воркеры, DLQ

![RabbitMQ](rabbitmq.png)

> **26.09.2026 — методичка вычитана и исправлена.** Что найдено и что поправлено — в [fixes/rabbitmq.md](https://github.com/meeymirita/lab-fixes/blob/main/rabbitmq.md) репозитория `lab-fixes`.

**Статус: ✅ выполнена (все 3 сессии).**
**Сложность: высокая.** Нужен уверенный Laravel/PHP (транзакции, Artisan-команды, очереди хотя бы на уровне концепции), базовые транзакции SQL, Docker Compose «запустить и посмотреть логи».

## О чём

Асинхронная обработка заказов интернет-магазина через очереди, с упором на паттерны надёжной доставки — то, что в реальных системах спасает от потери и дублирования сообщений.

## Стек

Laravel 13 (PHP 8.4) + PostgreSQL 16 + RabbitMQ (Management UI) + Mailpit, всё в Docker Compose.

## Архитектура

HTTP-запрос создаёт заказ и **сразу** пишет "записку" о событии в таблицу `outbox_messages` — в той же транзакции БД (паттерн **Transactional Outbox**, чтобы не потерять событие, если публикация в брокер упадёт). Отдельный процесс `outbox-relay` забирает записки и публикует их в exchange `orders.topic`. Дальше три независимых воркера (`order-worker`, `email-worker`, `analytics-worker`) разбирают свои копии сообщения из очередей: резервируют склад, шлют письмо, пишут в аналитику.

## Что пройдено

- Хопы 1–8: путь заказа от HTTP до БД, шаг за шагом, с точками наблюдения (`dd()`, логи, RabbitMQ UI)
- Что происходит, когда не хватает товара на складе
- **Идемпотентный consumer**: таблица `processed_messages` защищает от повторной обработки при redelivery
- Competing consumers + **prefetch** (`basic_qos`) — честное распределение нагрузки vs эффект "воркера-заложника" при большом prefetch
- Crash-тесты: `docker compose kill` (грубое убийство) и падение **после коммита, но до `ack`** — на практике пойман баг с `SIGKILL` на PID 1 в контейнере (ядро Linux его игнорирует), заменён на `exit()`
- **Retry с TTL → DLX** для писем: `email.retry.1/2/3` (10с/30с/300с) → `email.dlx` → назад в `email.queue` или в `email.dlq` после исчерпания попыток
- Читатель DLQ (`worker:failed-email`) — ручной разбор "мёртвых" сообщений
- Сравнение с нативными Laravel Queue Jobs (`$tries`/`$backoff`/`failed_jobs`) на том же RabbitMQ — чтобы почувствовать, где ручной AMQP-слой даёт то, чего нет из коробки (идемпотентность, publisher confirms, чужие consumer'ы не на Laravel)
- **Priority queues** (`x-max-priority`) с backlog — почему приоритет виден только при накопленной очереди
- **Fanout** (`lab:broadcast` / `worker:broadcast`) — широковещание всем подписчикам через `system.broadcast`, в отличие от topic-маршрутизации остального проекта

## Где что искать

Полная методичка со всеми шагами, объяснениями и заданиями — в [`docs/RabbitMQ_Lab_Plan_v1_pro_max.html`](docs/RabbitMQ_Lab_Plan_v1_pro_max.html) (открывается в браузере).

- рабочий код всех воркеров и команд — `laravel-app/app/Console/Commands/`
- пошаговый разбор пути заказа (хопы, точки наблюдения, что смотреть в БД/UI/логах) — [`docs/order-path-explained.md`](docs/order-path-explained.md)
- ответы на все 18 вопросов для самопроверки, привязанные к коду проекта — [`docs/self-check-answers.md`](docs/self-check-answers.md)
- подборка справочных материалов по темам лабы — [`docs/rabbit.md`](docs/rabbit.md)

---

Часть сборного репозитория лабораторных работ — [submodule-group-lab](https://github.com/meeymirita/submodule-group-lab).
