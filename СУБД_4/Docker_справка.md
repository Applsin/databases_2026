# Docker: полное руководство для студентов

## Содержание

1. [Введение: зачем нужен Docker](#1-введение-зачем-нужен-docker)
2. [Теоретическая основа: ОС, виртуализация и контейнеризация](#2-теоретическая-основа-ос-виртуализация-и-контейнеризация)
3. [Основные компоненты операционной системы](#3-основные-компоненты-операционной-системы)
4. [Виртуализация vs контейнеризация](#4-виртуализация-vs-контейнеризация)
5. [Docker: основные сущности и архитектура](#5-docker-основные-сущности-и-архитектура)
6. [Альтернативы Docker в 2026 году](#6-альтернативы-docker-в-2026-году)
7. [Структура Dockerfile и сборка образа](#7-структура-dockerfile-и-сборка-образа)
8. [Практика: запуск контейнера PostgreSQL 16](#8-практика-запуск-контейнера-postgresql-16)
9. [Инспекция контейнера: порты, логи, ресурсы](#9-инспекция-контейнера-порты-логи-ресурсы)
10. [Справочник основных команд Docker](#10-справочник-основных-команд-docker)
11. [Docker Compose: многоконтейнерные приложения](#11-docker-compose-многоконтейнерные-приложения)
12. [Docker Networking: сети](#12-docker-networking-сети)
13. [Docker Volumes: тома и постоянное хранилище](#13-docker-volumes-тома-и-постоянное-хранилище)
14. [Работа с реестрами: Docker Hub и GHCR](#14-работа-с-реестрами-docker-hub-и-ghcr)
15. [Docker vs Kubernetes](#15-docker-vs-kubernetes)
16. [Best practices для Dockerfile](#16-best-practices-для-dockerfile)
17. [Безопасность и гигиена](#17-безопасность-и-гигиена)
18. [Troubleshooting: типичные проблемы](#18-troubleshooting-типичные-проблемы)
19. [Практические лабораторные работы](#19-практические-лабораторные-работы)
20. [Глоссарий](#20-глоссарий)
21. [Итог](#21-итог)

---

## 1. Введение

**Docker** — платформа, которая упаковывает приложение и все его зависимости в контейнер, чтобы оно одинаково работало везде: на локальном ноутбуке разработчика, на тестовом стенде и в production.

**Традиционные проблемы, которые решает Docker:**
- Несогласованность окружений между dev, test и production.
- Конфликты зависимостей между проектами.
- Медленное развёртывание и масштабирование.

**Преимущества контейнеризации:**
- **Согласованность** — одно и то же окружение везде.
- **Изоляция** — приложения не мешают друг другу.
- **Портативность** — запускается везде, где есть Docker.
- **Эффективность** — лёгкие, стартуют за секунды.
- **Масштабируемость** — легко реплицировать.

**Когда использовать контейнеры:**
- Единообразные dev-окружения для команды.
- Доставка микросервисов с явными зависимостями.
- Воспроизводимые CI-сборки и тесты.

---

## 2. Теоретическая основа: ОС, виртуализация и контейнеризация

### 2.1. Что такое контейнеризация

До Docker приложения часто работали в **виртуальных машинах (ВМ)**. Каждая ВМ включала:
- **Полноценную** операционную систему.
- Все необходимые библиотеки и зависимости.
- Само приложение.

Это делало ВМ ресурсоёмкими, медленно стартующими и сложными в управлении.

**Контейнеризация** — более лёгкая альтернатива. Вместо запуска полноценной ОС для каждого экземпляра контейнеры:
- **Делять между собой ядро хостовой ОС**.
- Изолируют приложения и их зависимости.
- Стартуют быстрее (секунды вместо минут).
- Используют меньше ресурсов.

**Ключевые механизмы ядра Linux, лежащие в основе контейнеризации:**
- **Isolation (namespaces)** — Linux namespaces изолируют PID (ID процесса), сеть, mounts, hostname, IPC и пользователей, так что процессы «думают», что у них своя ОС.
- **Resource control (cgroups)** — cgroups ограничивают CPU, память и I/O и делят между контейнерами тактовое время.
- **Immutability (immutability)** — Образы контентно-адресуемы; если известен digest (хеш от содержимого) образа, все его копии идентичны.

---

## 3. Основные компоненты операционной системы

Операционная система (ОС) — посредник между аппаратным обеспечением и прикладными программами. Она управляет ресурсами, обеспечивает изоляцию и предоставляет удобный интерфейс для взаимодействия с железом.

**Ядро (kernel) и пространство пользователя (user space).**
Ядро — привилегированная часть ОС, работающая в режиме супервизора. Оно управляет памятью, процессами, устройствами и сетевым стеком. Пользовательские программы работают в непривилегированном режиме и обращаются к ядру через **системные вызовы** (system calls). Такое разделение защищает систему от сбоев приложений.

**Процессы и потоки.**
Процесс — экземпляр выполняемой программы с собственным адресным пространством, дескрипторами файлов и состоянием. Поток — единица выполнения внутри процесса, разделяющая с ним память. Ядро планирует потоки на процессоре, обеспечивая многозадачность.

**Управление памятью.**
Ядро выделяет каждому процессу виртуальное адресное пространство, которое через **MMU** (Memory Management Unit) отображается на физическую память. Это даёт изоляцию и позволяет использовать больше памяти, чем есть физически (swap, страничная подкачка). Виртуальная память делится на страницы; ядро отслеживает их расположение.

**Файловые системы и монтирование.**
Файловая система определяет способ хранения и доступа к данным на носителях. Ядро предоставляет единое дерево каталогов, в которое монтируются различные ФС (ext4, XFS, tmpfs, сетевые). Монтирование — это подключение ФС к определённой точке дерева.

**Пространства имён (namespaces) и cgroups.**
Это ключевые механизмы ядра Linux, лежащие в основе контейнеризации:
- **Namespaces** изолируют глобальные ресурсы: PID (процессы), NET (сеть), MNT (точки монтирования), UTS (hostname), IPC, USER. Процессы в разных namespace не видят друг друга.
- **cgroups** (control groups) ограничивают и учитывают потребление ресурсов: CPU, память, дисковый ввод-вывод, сеть.

Именно эти два механизма позволяют **запускать процессы в изолированном окружении, не создавая полноценную виртуальную машину** (основа контейнеризации).

---

## 4. Виртуализация vs контейнеризация

### 4.1. Виртуализация

Создаётся виртуальная машина (ВМ), которая эмулирует физическое оборудование. Гипервизор (KVM, VMware, Xen) распределяет ресурсы между ВМ. Каждая ВМ содержит **гостевую ОС** со своим ядром. Это обеспечивает максимальную изоляцию, но требует значительных накладных расходов: память для гостевой ОС, время на загрузку, дублирование драйверов.

### 4.2. Контейнеризация

Контейнер — это изолированный процесс (или группа процессов), использующий **общее ядро** хост-ОС. Изоляция достигается через namespaces и cgroups. Контейнер не содержит гостевой ОС, только приложение и его зависимости. Это даёт лёгкость, быстрый старт (секунды), низкое потребление ресурсов и плотную упаковку. Однако уровень изоляции ниже: ядро общее, поэтому уязвимость ядра может затронуть все контейнеры.

### 4.3. Сравнительная таблица

| Критерий | Виртуализация (ВМ) | Контейнеризация |
|---|---|---|
| Изоляция | Полная, на уровне железа | На уровне процессов (namespaces/cgroups) |
| Гостевая ОС | Есть, со своим ядром | Нет, используется ядро хоста |
| Время запуска | Десятки секунд – минуты | Секунды и менее |
| Потребление памяти | Высокое (ОС + приложение) | Низкое (только приложение) |
| Плотность на хосте | Несколько ВМ | Десятки–сотни контейнеров |
| Безопасность | Выше, но гипервизор — цель атак | Ниже, общее ядро — риск |
| Переносимость | Зависит от гипервизора | Высокая, OCI-стандарт |
| Типичное применение | Разные ОС, жёсткая изоляция | Микросервисы, CI/CD, масштабирование |

### 4.4. Как Docker работает на высоком уровне

1. **Build.** Docker читает `Dockerfile`, отправляет контекст и создаёт образ (набор слоёв + конфигурация).
2. **Store.** Образы тегируются (`repo:tag`) и опционально пушатся в registry. Один и тот же образ может иметь несколько тегов (как версия приложения)
3. **Run.** Docker создаёт тонкий writable-слой поверх образа и запускает процесс контейнера с настроенными переменными окружения, монтированиями и сетью.
4. **Share/scale.** Тот же образ запускается везде, где есть runtime (локально, CI, узлы Kubernetes, облачные ВМ).

### 4.5. Image vs Container на практике

- **Image** — артефакт времени сборки; версионируется тегами (`1.0`, `2024-05-01`, `sha256:...`), подписывается, сканируется, пушится в репозиторий (хранилище образов).
- **Container** — runtime-инстанс; смотрим логи, статистику, сети и тома; убиваем или перезапускаем, не трогая образ.

Image - exe-шник, container - запущенная из .exe программа, если проводить аналогии.
---

## 5. Docker: основные сущности и архитектура

Docker — платформа для сборки, доставки и запуска контейнеров. Относится к категории **application container** (контейнеры приложений).

### 5.1. Основные сущности

| Сущность | Что это |
|---|---|
| **Image (образ)** | Неизменяемый шаблон: ФС + метаданные (команды запуска, порты). Состоит из слоёв. |
| **Container (контейнер)** | Запущенный экземпляр образа с writable-слоем поверх. |
| **Volume (том)** | **Постоянное хранилище**, управляемое Docker. **Переживает удаление** контейнера. |
| **Bind mount** | Монтирование директории/файла с хост-машины внутрь контейнера. |
| **Network (сеть)** | Изолированная сеть для связи контейнеров. |
| **Dockerfile** | Текстовый файл с инструкциями для сборки образа. |
| **Registry** | Хранилище образов (Docker Hub, GitHub Container Registry и т.д.). |

### 5.2. Архитектура Docker (клиент-сервер)

```
┌──────────────┐         ┌──────────────────┐
│ Docker Client│ ──────> │  Docker Daemon   │
│  (CLI/GUI)   │         │  (Docker Engine) │
└──────────────┘         └──────────────────┘
                                  │
                         ┌────────┴────────┐
                         │                 │
                    ┌────▼────┐      ┌────▼────┐
                    │ Images  │      │Registry │
                    └────┬────┘      └─────────┘
                         │
                    ┌────▼────────┐
                    │ Containers  │
                    └─────────────┘
```

**Компоненты:**

1. **Docker Client** (`docker` command) — интерфейс для взаимодействия с Docker, отправляет команды демону. Примеры: `docker run`, `docker build`.
2. **Docker Daemon** (`dockerd`) — ядро, работающее на хосте. Управляет образами, контейнерами, сетями, томами. Слушает запросы Docker API.
3. **Docker Images** — хранятся локально или в реестрах. Строятся слоями. Неизменяемы (изменения создают новый слой).
4. **Docker Containers** — запущенные инстансы с собственным пространством процессов, сетевым интерфейсом, файловой системой (слои образа + writable-слой).
5. **Docker Registry** — хранит и распространяет образы. Docker Hub (публичный), приватные реестры (GHCR, ECR, ACR).

### 5.3. Слои образа (Image Layers)

Образы строятся слоями:

```
┌─────────────────────────┐
│ App Code (Layer 4)      │  ← Ваше приложение
├─────────────────────────┤
│ Dependencies (Layer 3)  │  ← pip install, npm install
├─────────────────────────┤
│ Runtime (Layer 2)       │  ← Python, Node.js
├─────────────────────────┤
│ Base OS (Layer 1)       │  ← Ubuntu, Alpine
└─────────────────────────┘
```

**Преимущества слоёв:**
- **Переиспользование:** общие слои разделяются между образами, не нужно заново скачивать, дублировать на машине. Экономия места.
- **Эффективность:** только изменённые слои скачиваются/хранятся.
- **Кеширование:** быстрее сборка, если слои не менялись.

### 5.4. Именование образов

Формат: `registry/repository:tag`

Примеры:
- `nginx:latest` — официальный nginx, последняя версия.
- `python:3.11-slim` — официальный Python 3.11, slim-вариант.
- `username/myapp:v1.0` — кастомный образ с тегом версии.
- `ghcr.io/user/app:prod` — образ из GitHub Container Registry.

### 5.5. Жизненный цикл контейнера

```
Created → Running → Paused → Stopped → Removed
            ↓         ↓         ↓
          Restart   Resume    Restart
```

**Характеристики контейнера:**
- **Изолирован:** собственное пространство процессов, сеть, ФС.
- **Эфемерен:** по умолчанию данные теряются при остановке.
- **Лёгок:** разделяет ядро хоста, стартует за секунды.
- **Stateless:** best practice — держать контейнеры без состояния.

---

## 6. Альтернативы Docker в 2026 году

| Инструмент | Особенность |
|---|---|
| **Podman** | Демонless, rootless по умолчанию, OCI-совместим, поддержка pods. Бинарно совместим с образами Docker. |
| **containerd** | Минималистичный runtime, часто используется как движок внутри Kubernetes. |
| **CRI-O** | Runtime, оптимизированный под Kubernetes CRI. |
| **LXC / LXD** | System containers — «лёгкие ВМ» с init-системой и полноценным пользовательским пространством. |
| **Colima** | Лёгкая замена Docker Desktop для macOS/Linux, использует Lima + QEMU, CLI полностью совместим с Docker. |
| **Rancher Desktop** | Open-source управление контейнерами с выбором dockerd или containerd. |

> **Важно:** Docker Engine остаётся open-source (Apache 2.0), но Docker Desktop с 2024 года требует платной лицензии для команд. Podman Desktop — полностью бесплатен и open-source.

---

## 7. Структура Dockerfile и сборка образа

Dockerfile — скрипт, читаемый сверху вниз. Каждая инструкция создаёт слой (кроме `FROM`, `ARG`, `ENV` и т.п.).

### 7.1. Основные инструкции

| Инструкция | Назначение | Пример |
|---|---|---|
| `FROM` | Базовый образ (обязательно первая инструкция) | `FROM python:3.11-slim` |
| `WORKDIR` | Рабочая директория внутри контейнера | `WORKDIR /app` |
| `COPY` | Копировать файлы с хоста в образ | `COPY . .` |
| `ADD` | Копировать файлы (с поддержкой URL/tar) | `ADD file.tar.gz /app` |
| `RUN` | Выполнить команду при сборке | `RUN pip install flask` |
| `CMD` | Команда по умолчанию при запуске контейнера | `CMD ["python", "app.py"]` |
| `ENTRYPOINT` | Точка входа (не перезаписывается аргументами `docker run`) | `ENTRYPOINT ["python"]` |
| `EXPOSE` | Документировать порт | `EXPOSE 8000` |
| `ENV` | Задать переменную окружения | `ENV DEBUG=1` |
| `ARG` | Build-time переменные | `ARG VERSION=1.0` |
| `VOLUME` | Создать точку монтирования | `VOLUME /data` |
| `USER` | Задать пользователя (аналог пользователя ОС, например, может иметь права на выполнение) | `USER appuser` |
| `LABEL` | Метаданные | `LABEL version="1.0"` |
| `HEALTHCHECK` | Проверка здоровья контейнера, актуальна для docker compose. На основе успешного healthcheck одного контейнера можно триггерить поднятие другого | `HEALTHCHECK CMD curl -f http://localhost/` |

### 7.2. Пример Dockerfile (Python-приложение)

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["python", "app.py"]
```

### 7.3. Пример полного Dockerfile

```dockerfile
# Base image
FROM python:3.11-slim

# Metadata
LABEL maintainer="you@example.com"
LABEL version="1.0"

# Set working directory
WORKDIR /app

# Copy files
COPY requirements.txt .
COPY . .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose port
EXPOSE 8000

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Define entrypoint
CMD ["python", "app.py"]
```

### 7.4. Сборка образа

```bash
docker build -t myapp:1.0 .
```

Флаг `-t` задаёт имя и тег, `.` — контекст сборки (директория с Dockerfile).

**Команда в разборе:**
- `docker build` — собрать образ.
- `-t hello-docker:v1` — тегировать его name:version.
- `.` — использовать текущую директорию как контекст сборки (где лежит Dockerfile).

**Что происходит при сборке:**
1. Скачивается базовый образ Python.
2. Устанавливается рабочая директория.
3. Копируется `app.py`.
4. Устанавливаются метаданные (EXPOSE, CMD).

### 7.5. Пример приложения на Python (минимальный HTTP-сервер)

**`app.py`:**
```python
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        response = {"message": "Hello from Docker!"}
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8000), Handler)
    print("Server running on port 8000")
    server.serve_forever()
```

**`Dockerfile`:**
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY app.py .
EXPOSE 8000
CMD ["python", "app.py"]
```

**Сборка и проверка:**
```bash
docker build -t myapp:v1.0 .
docker images
```

---

## 8. Практика: запуск контейнера PostgreSQL 16

### 8.1. Минимальный запуск

Образ PostgreSQL требует только `POSTGRES_PASSWORD`:

```bash
docker run -d --name pg-dev -e POSTGRES_PASSWORD=secret -p 5432:5432 postgres:16
```

| Переменная | По умолчанию |
|---|---|
| `POSTGRES_USER` | `postgres` |
| `POSTGRES_PASSWORD` | **обязательна** |
| `POSTGRES_DB` | `postgres` (имя БД = имя пользователя) |
| `PGDATA` | `/var/lib/postgresql/data` |

### 8.2. Постоянное хранилище (named volume)

```bash
docker run -d \
  --name pg-homework \
  -e POSTGRES_USER=student \
  -e POSTGRES_PASSWORD=strongpass \
  -e POSTGRES_DB=project_db \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16
```

- **Имя контейнера** — `pg-homework` (меняйте по желанию).
- **Переменные окружения** задают суперпользователя, пароль и имя БД.
- **Volume `pgdata`** — создаётся Docker автоматически и переживает удаление контейнера.
- **Порт `5432`** пробрасывается на хост, к нему можно подключаться любым клиентом (DBeaver, psql и т.п.).

### 8.3. Монтирование локальной директории (bind mount)

```bash
docker run -d \
  --name pg-bind \
  -e POSTGRES_PASSWORD=secret \
  -v "$(pwd)/pgdata:/var/lib/postgresql/data" \
  -p 5432:5432 \
  postgres:16
```

### 8.4. Монтирование отдельного файла

Например, `postgresql.conf`:

```bash
docker run -d \
  --name pg-config \
  -e POSTGRES_PASSWORD=secret \
  -v "$(pwd)/my-postgresql.conf:/etc/postgresql/postgresql.conf" \
  postgres:16 -c config_file=/etc/postgresql/postgresql.conf
```

### 8.5. Проверка работы

```bash
# Проверить, что контейнер запущен
docker ps

# Посмотреть логи
docker logs pg-homework

# Подключиться к БД (если установлен psql)
psql -h localhost -p 5432 -U student -d project_db
```

---

## 9. Исследование контейнера: порты, логи, ресурсы

| Что нужно | Команда |
|---|---|
| **Порты** | `docker port <container>` — проброшенные порты (по которым можно обращаться в контейнер) |
| **Логи** | `docker logs <container>` — stdout/stderr |
| | `docker logs -f <container>` — следить за логами в реальном времени (Ctrl+C для выхода) |
| | `docker logs --tail 50 <container>` — последние 50 строк логов |
| **Ресурсы** | `docker stats` — live CPU/RAM/сеть/диск по всем контейнерам |
| | `docker stats <container>` — только по одному |
| **Процессы** | `docker top <container>` — аналог `ps` внутри |
| **Детали** | `docker inspect <container>` — полный JSON |
| | `docker inspect -f '{{.State.Status}}' <container>` — конкретное поле |
| **Изменения ФС** | `docker diff <container>` — добавленные/удалённые файлы |

**Примеры:**

```bash
# Войти в консоль контейнера
docker exec -it <container_id> bash

# Просмотр контейнеров
docker ps -a               # все контейнеры (включая остановленные)
docker ps                  # только работающие

# Образы
docker images              # список образов
docker history <image>     # слои образа (укажите имя или ID)

# Логи
docker logs <container>        # вывод логов (stdout/stderr)
docker logs -f <container>     # следование за логами
docker logs --tail 50 <container>  # последние 50 строк

# Ресурсы в реальном времени
docker stats               # live-статистика

# Дисковое пространство
docker system df           # общее занятое место
docker system df -v        # детальный разбор по объектам

# Системная информация
docker system info         # версия, драйвер хранилища, количество объектов
docker version             # версия клиента и сервера

# Детальная инспекция
docker inspect <container|image|network|volume>   # полный JSON-вывод
docker inspect -f '{{.State.Status}}' <container> # конкретное поле (статус)

# Процессы внутри контейнера
docker top <container>     # запущенные процессы (аналог ps)

# Изменения в файловой системе
docker diff <container>    # добавленные/удалённые/изменённые файлы
```

---

## 10. Справочник основных команд Docker

### 10.1. Образы

```bash
docker images                  # список образов
docker pull <image>            # скачать образ
docker build -t name:tag .     # собрать образ
docker history <image>         # слои образа
docker tag src dst             # тегировать образ
docker push image              # запушить в registry
docker pull image              # скачать из registry
docker rmi <image>             # удалить образ
docker inspect <image>         # детали образа
```

### 10.2. Контейнеры

```bash
docker ps                      # работающие
docker ps -a                   # все (включая остановленные)
docker run image               # создать и запустить контейнер
docker run -d <image>          # запустить в фоне
docker run -it <image> bash    # интерактивно с shell
docker run -d -p 8080:8000 --name myapp myapp:v1.0  # с портами и именем
docker exec -it <container> bash   # войти в работающий
docker exec myapp ls -la       # выполнить одну команду
docker stop <container>        # остановить
docker start <container>       # запустить остановленный
docker restart <container>     # перезапустить
docker rm <container>          # удалить (только остановленный)
docker rm -f <container>       # удалить принудительно
docker logs <container>        # посмотреть логи
docker logs -f <container>     # следить за логами
docker top <container>         # процессы
docker stats <container>       # ресурсы
docker inspect <container>     # детали
docker port <container>        # порты
docker diff <container>        # изменения ФС
```

**Основные опции `docker run`:**

```bash
-d              # Запустить в фоне (detached)
-p 8080:80      # Пробросить порт host:container
--name web      # Дать имя контейнеру
-e VAR=value    # Задать переменную окружения
-v /host:/cont  # Смонтировать том
--rm            # Удалить контейнер после остановки
-it             # Интерактивный терминал
--network net   # Подключить к сети
--restart always # Политика перезапуска
```

### 10.3. Очистка

```bash
docker system df               # общее занятое место
docker system prune            # удалить остановленные контейнеры, сети, dangling-образы
docker system prune -a         # + все неиспользуемые образы
docker volume prune            # неиспользуемые тома (осторожно — данные!)
docker image prune             # только образы
docker image prune -a          # все неиспользуемые образы
docker container prune         # только контейнеры
docker system prune -a --volumes # очистить всё
```

### 10.4. Сети и тома

```bash
docker network ls              # список сетей
docker volume ls               # список томов
docker network inspect <net>   # детали сети
docker volume inspect <vol>    # путь к тому на хосте
docker network create mynet    # создать сеть
docker network connect mynet container1  # подключить контейнер
docker network disconnect mynet container1
docker network rm mynet        # удалить сеть
docker volume create mydata    # создать том
docker volume rm mydata        # удалить том
```

### 10.5. Системная информация

```bash
docker version                 # версии клиента и сервера
docker system info             # драйвер хранилища, количество объектов
docker system events           # поток событий в реальном времени
docker system events --filter type=container   # с фильтром по типу
```

### 10.6. Реестр (авторизация)

```bash
docker login <registry>    # проверка аутентификации
docker logout              # выход
docker pull <image> --quiet # тихая загрузка без лишнего вывода
docker search nginx        # поиск на Docker Hub
```

---

## 11. Docker Compose: многоконтейнерные приложения

### 11.1. Что такое Docker Compose

**Docker Compose** — инструмент для запуска и управления **несколькими Docker-контейнерами** как единым приложением. Вместо ручного запуска каждого контейнера вы описываете все сервисы в файле `docker-compose.yml`.

**Когда использовать:**
- Многоконтейнерные приложения (app + database + cache).
- Локальные среды разработки.
- Тестовые окружения.

### 11.2. Основные команды

```bash
docker compose up              # запустить сервисы (сборка при необходимости)
docker compose up -d           # запустить в фоне
docker compose build           # собрать образы
docker compose stop            # остановить сервисы
docker compose down            # остановить и удалить контейнеры
docker compose down -v         # + удалить тома
docker compose ps              # статус сервисов
docker compose logs            # логи всех сервисов
docker compose logs -f web     # следить за логами сервиса
docker compose exec web bash   # войти в контейнер сервиса
docker compose restart web     # перезапустить сервис
docker compose up -d --scale web=3  # масштабировать сервис
```

### 11.3. Пример `docker-compose.yml` для PostgreSQL 16

```yaml
services: - перечисление контейнеров, которые участвуют в compose
  postgres: - конкретный контейнер, который будет в compose называться postgres (можно как угодно назвать)
    image: postgres:16-alpine
    container_name: my-postgres
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: mypassword
      POSTGRES_DB: company_db
    ports:
      - "5432:5432"
    volumes:
      - ./init:/docker-entrypoint-initdb.d:ro
      - ./postgres-data:/var/lib/postgresql/data
    restart: unless-stopped
```

**Разбор конфигурации:**
- `image: postgres:16-alpine` — лёгкий образ на Alpine Linux.
- `ports: "5432:5432"` — проброс порта на хост.
- `./postgres-data:/var/lib/postgresql/data` — bind mount: данные сохраняются в локальной папке проекта.
- `./init:/docker-entrypoint-initdb.d:ro` — директория с SQL-скриптами, которые выполнятся **только при первом запуске** с пустым `PGDATA`.
- `restart: unless-stopped` — автоматический перезапуск при сбое.

**Запуск:**
```bash
docker compose up -d
```

Через несколько секунд PostgreSQL будет доступен на `localhost:5432`. Для остановки с сохранением данных — `docker compose down`. Для полного сброса (включая данные) — удалите папку `postgres-data/` и запустите снова.

### 11.4. Расширенный пример Compose-стека

```yaml
version: '3.8'

services:
  # Web application
  web:
    build: ./app
    ports:
      - "8080:8000"
    environment:
      - DEBUG=1
      - DB_HOST=db
    depends_on: - триггер запуска web. Начнет стартовать ПОСЛЕ успешных healthcheck db и redis
      - db
      - redis
    volumes:
      - ./app:/app
    networks: - чтобы сервисы могли общаться друг с другом они должны быть в одной сети или у сетей должен быть доступ друг к другу
      - app-network

  # Database
  db:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD=secret
      - POSTGRES_DB=myapp
    volumes:
      - db-data:/var/lib/postgresql/data
    networks: - чтобы сервисы могли общаться друг с другом они должны быть в одной сети или у сетей должен быть доступ друг к другу
      - app-network

  # Cache
  redis:
    image: redis:7-alpine
    networks: - чтобы сервисы могли общаться друг с другом они должны быть в одной сети или у сетей должен быть доступ друг к другу
      - app-network

volumes:
  db-data:

networks:
  app-network:
    driver: bridge
```

### 11.5. Преимущества Docker Compose

- **Упрощённое управление:** одна команда для запуска/остановки всего.
- **Конфигурация как код:** версионируемый YAML-файл.
- **Согласованность окружения:** одинаковый setup для всей команды.
- **Зависимости сервисов:** контроль порядка запуска.
- **Сетевая изоляция:** автоматическое создание сетей.

---

## 12. Docker Networking: сети

### 12.1. Что такое Docker Networking

Docker Networking обеспечивает механизмы для:
- **Связи между контейнерами**.
- **Связи контейнеров с хостом**.
- **Связи контейнеров с внешними сетями**.

### 12.2. Типы сетей

1. **Bridge** (по умолчанию)
   - Изолированная сеть на хосте.
   - Контейнеры могут общаться друг с другом.
   - Нужно публиковать порты для доступа с хоста.

2. **Host**
   - Контейнер использует сеть хоста напрямую.
   - Нет сетевой изоляции.
   - Лучшая производительность.

3. **None**
   - Нет сетей.
   - Полная изоляция.

4. **Custom Bridge**
   - Пользовательская bridge-сеть.
   - Автоматическое DNS-разрешение по имени контейнера.
   - Лучшая изоляция.

### 12.3. Команды для работы с сетями

```bash
# Список сетей
docker network ls

# Создать сеть
docker network create mynetwork

# Инспекция сети
docker network inspect mynetwork

# Подключить контейнер к сети
docker network connect mynetwork container1

# Отключить контейнер
docker network disconnect mynetwork container1

# Удалить сеть
docker network rm mynetwork

# Запустить контейнер в конкретной сети
docker run -d --network mynetwork --name web nginx
```

### 12.4. Связь контейнеров

**Внутри одной сети:**
```bash
# Создать сеть
docker network create app-net

# Запустить БД
docker run -d --name db --network app-net postgres

# Запустить приложение (может подключиться к БД по имени "db")
docker run -d --name app --network app-net myapp
```

**Публикация портов:**
```bash
# Опубликовать один порт
docker run -d -p 8080:80 nginx

# Опубликовать все EXPOSE-порты
docker run -d -P nginx

# Привязать к конкретному интерфейсу
docker run -d -p 127.0.0.1:8080:80 nginx
```

---

## 13. Docker Volumes: тома и постоянное хранилище

### 13.1. Что такое Docker Volumes

**Docker Volumes** хранят данные **вне** файловой системы контейнера, поэтому данные:
- Сохраняются при остановке или удалении контейнера.
- Могут разделяться между контейнерами.
- Управляются Docker.
- Могут быть зарезервированы и мигрированы.

### 13.2. Типы томов

1. **Named Volumes** (управляются Docker)
   ```bash
   docker volume create mydata
   docker run -v mydata:/app/data myapp
   ```

2. **Bind Mounts** (директория на хосте)
   ```bash
   docker run -v /host/path:/container/path myapp
   ```

3. **tmpfs Mounts** (только в памяти)
   ```bash
   docker run --tmpfs /app/temp myapp
   ```

### 13.3. Команды для работы с томами

```bash
# Создать том
docker volume create mydata

# Список томов
docker volume ls

# Инспекция тома
docker volume inspect mydata

# Удалить том
docker volume rm mydata

# Удалить все неиспользуемые тома
docker volume prune

# Запустить с томом
docker run -v mydata:/data nginx
```

### 13.4. Volume vs Bind Mount

| Характеристика | Named Volume | Bind Mount |
|---|---|---|
| **Расположение** | Управляется Docker | Вы указываете путь хоста |
| **Портируемость** | Портируемый между системами | Зависит от хоста |
| **Применение** | Базы данных, постоянные данные | Разработка, исходный код |
| **Резервная копия** | Легче бэкапить | Ручной бэкап |
| **Синтаксис** | `-v mydata:/path` | `-v /host/path:/path` |

### 13.5. Примеры использования

**Для персистентности БД:**
```bash
docker run -d \
  --name postgres \
  -v pgdata:/var/lib/postgresql/data \
  postgres:15
```

**Для разработки (bind mount):**
```bash
docker run -d \
  --name devapp \
  -v $(pwd):/app \
  -p 8080:8000 \
  myapp
```

**Разделение данных между контейнерами:**
```bash
# Создать том
docker volume create shared-data

# Контейнер 1 пишет данные
docker run -v shared-data:/data writer-app

# Контейнер 2 читает данные
docker run -v shared-data:/data:ro reader-app
```

---

## 14. Работа с реестрами: Docker Hub и GHCR

### 14.1. Что такое Docker Hub

**Docker Hub** — официальный облачный реестр Docker, где разработчики:
- **Хранят** образы Docker.
- **Делятся** образами публично или приватно.
- **Скачивают** готовые образы.

Это как GitHub, только для Docker-образов.

### 14.2. Типы реестров

1. **Публичные реестры:**
   - Docker Hub (hub.docker.com).
   - GitHub Container Registry (ghcr.io).
   - Quay.io.

2. **Приватные реестры:**
   - Docker Hub (private repos).
   - AWS ECR (Elastic Container Registry).
   - Azure ACR (Azure Container Registry).
   - Google GCR (Google Container Registry).
   - Self-hosted (Docker Registry).

### 14.3. Полный workflow: build → tag → push → pull

**Шаг 1. Логин**
```bash
docker login
```
Введите ваше Docker Hub username и пароль.

**Шаг 2. Тегирование образа**

Формат: `username/repository:tag`

```bash
docker tag myapp:v1.0 YOUR_USERNAME/myapp:v1.0
docker tag myapp:v1.0 YOUR_USERNAME/myapp:latest
```

**Зачем два тега?**
- `v1.0` — конкретная версия для контроля версий.
- `latest` — соглашение для последней версии.

**Шаг 3. Пуш в реестр**
```bash
docker push YOUR_USERNAME/myapp:v1.0
docker push YOUR_USERNAME/myapp:latest
```

**Шаг 4. Проверка на Docker Hub**
1. Откройте https://hub.docker.com.
2. Войдите и проверьте «Repositories».
3. Вы должны увидеть свой образ!

**Шаг 5. Скачивание и запуск**
```bash
# Удалить локальные копии
docker rmi YOUR_USERNAME/myapp:v1.0
docker rmi YOUR_USERNAME/myapp:latest

# Скачать из реестра
docker pull YOUR_USERNAME/myapp:latest

# Запустить скачанный образ
docker run -d -p 8080:8000 YOUR_USERNAME/myapp:latest
```

### 14.4. Альтернатива: GitHub Container Registry

**Логин:**
```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

**Тегирование:**
```bash
docker tag myapp:v1.0 ghcr.io/YOUR_USERNAME/myapp:v1.0
```

**Пуш:**
```bash
docker push ghcr.io/YOUR_USERNAME/myapp:v1.0
```

### 14.5. Именование для других реестров

```bash
# Docker Hub
docker tag myapp:v1 username/myapp:v1
docker push username/myapp:v1

# GitHub Container Registry
docker tag myapp:v1 ghcr.io/username/myapp:v1
docker push ghcr.io/username/myapp:v1

# AWS ECR
docker tag myapp:v1 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:v1
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:v1
```

### 14.6. Ключевые моменты

-  Нужно тегировать в формате `username/repo:tag` для пуша.
-  Используйте `latest` для текущей стабильной версии.
-  Слои разделяются между образами (эффективное хранилище).
-  Любой может скачать ваши публичные образы.
-  Приватные репозитории требуют аутентификации для скачивания.

---

## 15. Docker vs Kubernetes

### 15.1. Docker

**Что это:**
- Платформа для сборки, упаковки и запуска приложений в контейнерах.
- Предоставляет Docker Engine для запуска контейнеров.
- Включает Docker Hub для обмена образами.

**Фокус:**
- Создание и управление отдельными контейнерами.
- Управление контейнерами на одном хосте.
- Простые многоконтейнерные приложения (Docker Compose).

**Лучше всего для:**
- Сред разработки.
- Однонодовых деплойментов.
- Небольших приложений.
- Изучения контейнеризации.

### 15.2. Kubernetes

**Что это:**
- Система оркестрации контейнеров.
- Управляет, масштабирует и автоматизирует развёртывание контейнеров.
- Работает с Docker-контейнерами (и другими, например containerd).

**Фокус:**
- Многохостовой оркестрации контейнеров.
- Крупномасштабных распределённых приложений.
- Production-нагрузок.
- Самовосстановления и авто-масштабирования.

**Лучше всего для:**
- Production-сред.
- Микросервисных архитектур.
- Многонодовых кластеров.
- Корпоративных приложений.

**Ключевые фичи:**
- Балансировка нагрузки.
- Service discovery.
- Авто-масштабирование (горизонтальное и вертикальное).
- Rolling updates и rollback.
- Самовосстановление (перезапуск упавших контейнеров).
- Управление секретами и конфигурацией.
- Оркестрация хранилищ.

### 15.3. Сравнительная таблица

| Характеристика | Docker | Kubernetes |
|---|---|---|
| **Назначение** | Собрать и запустить контейнеры | Оркестрировать контейнеры в масштабе |
| **Область** | Один хост (в основном) | Многохостовой кластер |
| **Сложность** | Простой, легко учить | Сложный, крутая кривая обучения |
| **Масштабирование** | Вручную или базовый compose | Автоматическое, интеллектуальное |
| **High Availability** | Ограниченная | Встроенная |
| **Балансировка нагрузки** | Вручную | Автоматическая |
| **Health Checks** | Базовые | Продвинутые с авто-перезапуском |
| **Обновления** | Вручную | Rolling updates, zero-downtime |
| **Применение** | Dev, малые приложения | Production, большие приложения |

### 15.4. Они работают вместе!

Docker и Kubernetes **дополняют** друг друга, а не конкурируют:

```
Developer → Docker (Build) → Docker Image → Kubernetes (Deploy & Manage)
```

**Типичный workflow:**
1. **Разработка** с Docker локально.
2. **Сборка** образов с Docker.
3. **Пуш** в реестр (Docker Hub и т.д.).
4. **Деплой** в Kubernetes-кластер.
5. Kubernetes **управляет** контейнерами в масштабе.


NOTE: Kubernetes РАБОТАЕТ НЕ ТОЛЬКО С docker images. Он поддерживает другие типы контейнеров тоже. 
---

## 16. Best practices для Dockerfile

### 16.1. Используйте конкретные теги базовых образов

```dockerfile
FROM python:3.11-slim  # Хорошо
FROM python            # Плохо (использует latest, непредсказуемо)
```

### 16.2. Минимизируйте количество слоёв

```dockerfile
# Хорошо - один слой
RUN apt-get update && apt-get install -y \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Плохо - несколько слоёв
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y vim
```

### 16.3. Упорядочивайте инструкции по частоте изменений (сверху вниз)

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .      # Копируем зависимости первыми
RUN pip install -r requirements.txt  # Устанавливаем (кешируется, если requirements не изменился)
COPY . .                     # Копируем код приложения последним (меняется часто)
```

### 16.4. Используйте .dockerignore

```
__pycache__
*.pyc
.git
.env
node_modules
npm-debug.log
*.md
```

### 16.5. Запускайте от непривилегированного пользователя (меньше уязвимостей, за которые вас полюбит ИБ)

```dockerfile
RUN useradd -m appuser
USER appuser
```

Или через `adduser`:

```dockerfile
RUN adduser --disabled-password appuser
USER appuser
```

### 16.6. Multi-stage builds для уменьшения размера

```dockerfile
FROM node:18-alpine AS builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY . .
EXPOSE 3000
USER node
CMD ["node", "server.js"]
```

**Сравнение размеров:**
```bash
docker build -f Dockerfile.optimized -t custom-app:v1.0-optimized .
docker images | grep custom-app
```

### 16.7. Добавляйте healthcheck, это нужно для чейнинга создания контейнеров

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))" - Ожидаем что пинг конкретнго URL у сервиса вернет именно "200 ОК"
```

---

## 17. Безопасность и гигиена

- **Используйте минимальные базы** (`alpine`, `distroless`), когда возможно.
- **Пиньте версии** и **избегайте запуска от root** внутри контейнера.
- **Держите секреты вне образов:** передавайте через env, Openbao, Vault.
- **Регулярно чистите** неиспользуемые образы и контейнеры (`docker system prune`) для экономии диска.
- **Сканируйте образы** на уязвимости (Trivy, Clair, Docker Scout).
- **Подписывайте образы** (Docker Content Trust, cosign).
- **Ограничивайте ресурсы** через `--memory`, `--cpus`.
- **Не монтируйте docker.sock** в контейнеры без необходимости — это даёт доступ к хосту.
- **Используйте rootless-режим** (Podman, Docker rootless).

---

## 18. Troubleshooting: типичные проблемы

### 18.1. Порт уже занят

```bash
# Использовать другой хост-порт
docker run -p 8081:8000 myapp
```

### 18.2. Permission denied

```bash
# Linux: добавить пользователя в группу docker
sudo usermod -aG docker $USER
# Выйти и войти снова
```

### 18.3. Контейнер сразу завершается

```bash
docker logs container-name  # Проверить логи на ошибки
```

### 18.4. Проблемы с кешем сборки

```bash
docker build --no-cache -t myapp .
```

### 18.5. Не удаётся подключиться к Docker daemon

```bash
# Убедиться, что Docker Desktop/Engine запущен
sudo systemctl start docker  # Linux
```

### 18.6. Контейнер не останавливается

```bash
# Принудительная остановка
docker kill myapp
```

### 18.7. Удалить все остановленные контейнеры

```bash
docker container prune
```

### 18.8. Удалить все неиспользуемые образы

```bash
docker image prune -a
```

### 18.9. Посмотреть использование диска

```bash
docker system df
```

### 18.10. Очистить всё

```bash
docker system prune -a --volumes
```

---

## Полный workflow Build → Run → Push

**Шаги:**

1. **Создайте простое веб-приложение** (любой язык).
2. **Напишите Dockerfile** для контейнеризации.
3. **Соберите образ** с правильными тегами.
4. **Запустите и протестируйте** контейнер.
5. **Запушьте в Docker Hub** или GHCR.
6. **Создайте docker-compose.yml** с приложением + БД.
7. **Задокументируйте** в README.

**Пример полного workflow:**

```bash
# 1. Создать приложение
mkdir my-app && cd my-app
# (создайте файлы приложения)

# 2. Создать Dockerfile
# (напишите Dockerfile)

# 3. Собрать
docker build -t my-app:1.0 .

# 4. Тест локально
docker run -d -p 8080:8080 --name test-app my-app:1.0
curl http://localhost:8080

# 5. Тегировать для реестра
docker tag my-app:1.0 YOUR_USERNAME/my-app:1.0
docker tag my-app:1.0 YOUR_USERNAME/my-app:latest

# 6. Пуш
docker login
docker push YOUR_USERNAME/my-app:1.0
docker push YOUR_USERNAME/my-app:latest

# 7. Создать compose-файл
# (создайте docker-compose.yml)

# 8. Тест compose-стека
docker compose up -d
docker compose ps
docker compose logs

# 9. Cleanup
docker compose down -v
docker rm -f test-app
```

**Сводка ключевых команд:**

| Задача | Команда |
|---|---|
| **Собрать образ** | `docker build -t name:tag .` |
| **Запустить контейнер** | `docker run -d -p 8080:80 --name app image` |
| **Список контейнеров** | `docker ps` или `docker ps -a` |
| **Просмотр логов** | `docker logs app` |
| **Выполнить команду** | `docker exec -it app sh` |
| **Остановить контейнер** | `docker stop app` |
| **Удалить контейнер** | `docker rm app` |
| **Тегировать образ** | `docker tag image user/image:tag` |
| **Пуш образа** | `docker push user/image:tag` |
| **Запустить compose** | `docker compose up -d` |
| **Остановить compose** | `docker compose down` |

---

## 20. Глоссарий

### 20.1. Термины операционных систем

| Термин | Определение |
|---|---|
| **Ядро (kernel)** | Привилегированная часть ОС, управляющая ресурсами и предоставляющая системные вызовы. |
| **Пространство пользователя (user space)** | Режим выполнения приложений без прямого доступа к железу. |
| **Системный вызов (syscall)** | Интерфейс для запроса услуг ядра из пользовательского пространства. |
| **Процесс** | Экземпляр программы с собственным адресным пространством и ресурсами. |
| **Поток (thread)** | Единица выполнения внутри процесса, разделяющая память. |
| **Виртуальная память** | Абстракция, дающая каждому процессу изолированное адресное пространство. |
| **MMU** | Аппаратный блок, транслирующий виртуальные адреса в физические. |
| **Файловая система** | Способ организации данных на носителе (ext4, XFS, NTFS). |
| **Монтирование** | Подключение файловой системы к точке в общем дереве каталогов. |
| **Namespace** | Механизм изоляции глобальных ресурсов (PID, NET, MNT, UTS, IPC, USER). |
| **cgroup** | Механизм ограничения и учёта потребления ресурсов (CPU, память, I/O). |
| **Гипервизор** | ПО, создающее и управляющее виртуальными машинами. |
| **Гостевая ОС** | ОС, работающая внутри виртуальной машины. |
| **Union filesystem** | ФС, объединяющая несколько слоёв в единое дерево (overlayfs, AUFS). |

### 20.2. Термины Docker и контейнеризации

| Термин | Определение |
|---|---|
| **Контейнер** | Изолированный процесс, использующий ядро хоста и упакованный с зависимостями. |
| **Образ (image)** | Неизменяемый шаблон для создания контейнеров, состоящий из слоёв. |
| **Слой (layer)** | Промежуточное изменение файловой системы, кэшируемое при сборке. |
| **Dockerfile** | Файл с инструкциями для сборки образа. |
| **Реестр (registry)** | Хранилище образов (Docker Hub, GHCR, приватный registry). |
| **Том (volume)** | Постоянное хранилище, управляемое Docker, для сохранения данных. |
| **Bind mount** | Монтирование файла или директории с хоста в контейнер. |
| **Сеть Docker** | Виртуальная сеть для связи контейнеров (bridge, host, overlay). |
| **Docker Compose** | Инструмент для описания и запуска многоконтейнерных приложений через YAML. |
| **Docker Engine** | Клиент-серверное ПО для сборки и запуска контейнеров. |
| **Podman** | Альтернативный движок контейнеров без демона, с rootless-режимом. |
| **OCI** | Open Container Initiative — стандарты на образы и runtime. |
| **Rootless** | Запуск контейнеров от непривилегированного пользователя. |
| **Detached mode** | Режим запуска контейнера в фоне (`-d`). |
| **Healthcheck** | Проверка работоспособности контейнера. |
| **Multi-stage build** | Сборка образа в несколько этапов для уменьшения размера. |
| **Registry** | Хранилище образов. |
| **Digest** | Контентно-адресуемый хеш образа (sha256). |
| **Tag** | Метка версии образа (`latest`, `v1.0`). |

---

## 21. Итог

**Ключевые выводы:**

1. **Контейнеризация** эффективно изолирует приложения, используя общее ядро ОС.
2. **Docker** делает контейнеры простыми в сборке, запуске и обмене.
3. **Образы** — шаблоны; **контейнеры** — запущенные инстансы.
4. **Dockerfile** определяет, как собрать образ.
5. **Реестры** хранят и распространяют образы.
6. **Docker Compose** управляет многоконтейнерными приложениями.
7. **Тома** сохраняют данные вне жизненного цикла контейнера.
8. **Сети** обеспечивают связь контейнеров.
9. **Kubernetes** оркестрирует Docker-контейнеры в масштабе.
10. В 2026 году экосистема предлагает зрелые open-source альтернативы (Podman, containerd, LXC).
