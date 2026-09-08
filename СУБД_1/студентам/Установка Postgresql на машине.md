
### 0. Установка Docker на Windows

1. Поставьте Git bash для более простой работы если у вас Windows.

#### Системные требования
- **ОС:** Windows 11 64‑бит (версия 21H2 или выше) или Windows 10 64‑бит.
- **ОЗУ:** минимум 4 ГБ (рекомендуется 8 ГБ).
- **Виртуализация:** включена в BIOS/UEFI. Рекомендуется использовать бэкенд WSL 2 (доступен на всех редакциях Windows, включая Home).

#### Пошаговая установка
1. **Скачайте установщик** с официального сайта: [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/).
2. **Запустите** скачанный файл `Docker Desktop Installer.exe`.
3. После завершения установки **перезагрузите** компьютер, если потребуется.
4. **Запустите Docker Desktop** из меню «Пуск». Дождитесь, пока в системном трее появится зелёный индикатор «Docker Engine is running».
5. **Проверьте** установку, открыв терминал (PowerShell, cmd или WSL2) и выполнив:
   ```bash
   docker --version
   ```
   Вы должны увидеть номер версии.

> **Важно:** Для работы с Docker в Windows не требуется `sudo` – все команды выполняются от имени текущего пользователя.

---

### 1. Подготовка Docker (запуск без `sudo`)

Чтобы не вводить `sudo` перед каждой командой `docker`, необходимо настроить права текущего пользователя.

**Windows (Docker Desktop)**  
Права текущего пользователя уже есть — дополнительных действий не требуется. Все команды в терминале (PowerShell, cmd, WSL2, Git Bash) выполняются без `sudo`.

**Ubuntu / Linux**  
Добавьте текущего пользователя в группу `docker` и примените изменения:

```bash
# Добавить пользователя в группу docker
sudo usermod -aG docker $USER

# Активировать изменения в текущей сессии (без выхода из системы)
newgrp docker
```

После этого закройте и откройте терминал заново. Проверьте:

```bash
docker ps
```

Если команда отработала без ошибки прав, всё готово.

Дополнительные команды docker, которые могут быть полезными:
# === Войти в консоль контейнера ===
docker exec -it <container_id> bash
# === Просмотр контейнеров ===
docker ps -a               # все контейнеры (включая остановленные)
docker ps                  # только работающие

# === Образы ===
docker images              # список образов
docker history <image>     # слои образа (укажите имя или ID)

# === Логи ===
docker logs <container>        # вывод логов (stdout/stderr)
docker logs -f <container>     # следование за логами (Ctrl+C для выхода)
docker logs --tail 50 <container>  # последние 50 строк

# === Ресурсы в реальном времени ===
docker stats               # live-статистика CPU/память/сеть/диск для всех контейнеров (Ctrl+C для выхода)

# === Дисковое пространство ===
docker system df           # общее занятое место (образы, контейнеры, тома, кеш)
docker system df -v        # детальный разбор по объектам

# === Системная информация ===
docker system info         # версия, драйвер хранилища, количество объектов
docker version             # версия клиента и сервера

# === Детальная инспекция ===
docker inspect <container|image|network|volume>   # полный JSON-вывод
docker inspect -f '{{.State.Status}}' <container> # конкретное поле (статус)

# === Процессы внутри контейнера ===
docker top <container>     # запущенные процессы (аналог ps)

# === Изменения в файловой системе ===
docker diff <container>    # добавленные/удалённые/изменённые файлы

# === Сети и тома ===
docker network ls          # список сетей
docker volume ls           # список томов
docker network inspect <network>   # детали сети
docker volume inspect <volume>     # детали тома

# === Очистка неиспользуемых ресурсов ===
docker system prune        # удалить остановленные контейнеры, сети, образы без тегов, кеш (с подтверждением)
docker system prune -a     # удалить все неиспользуемые образы (включая промежуточные)
docker volume prune        # удалить неиспользуемые тома (осторожно — данные!)
docker image prune         # только образы
docker container prune     # только контейнеры

# === Мониторинг событий (отладка) ===
docker system events       # поток событий (запуск/остановка/создание) — Ctrl+C для выхода
docker system events --filter type=container   # с фильтром по типу

# === Реестр (авторизация) ===
docker login <registry>    # проверка аутентификации
docker pull <image> --quiet # тихая загрузка без лишнего вывода
---

### 2. Запуск контейнера с постоянным хранилищем (volume)

Замените `<your_password>` на надёжный пароль. Имя базы и пользователя можно задать по своему проекту.

```bash
docker run -d \
  --name pg-homework \
  -e POSTGRES_USER=student \
  -e POSTGRES_PASSWORD=<your_password> \
  -e POSTGRES_DB=project_db \
  -v "$(pwd)/pgdata:/var/lib/postgresql/data" \
  -p 5432:5432 \
  postgres:16
```

- **Имя контейнера** – `pg-homework` (меняйте по желанию).
- **Переменные окружения** задают суперпользователя, пароль и имя БД.
- **Volume `$(pwd)/pgdata`** — сохраняет данные в папку `pgdata` на вашем компьютере (в текущей директории), даже если контейнер удалён.
- **Порт `5432`** пробрасывается на хост, к нему можно подключаться любым клиентом (DBeaver, psql и т.п.).

**ВАЖНО**: Если у вас есть файл миграции и существует volume - после пересоздания контейнера файл миграции не применится.

---

### 3. Запуск контейнера с настройками по умолчанию (минимальная конфигурация)

Для быстрого старта или тестирования можно использовать значения по умолчанию. Образ PostgreSQL **требует** только указания пароля суперпользователя, остальные параметры опциональны.

| Переменная окружения | Описание | Значение по умолчанию |
| :--- | :--- | :--- |
| `POSTGRES_USER` | Имя суперпользователя | `postgres` |
| `POSTGRES_PASSWORD` | Пароль суперпользователя | **Обязательно задать вручную** |
| `POSTGRES_DB` | Имя БД, создаваемой при первом запуске | `postgres` |
| `PGDATA` | Каталог данных внутри контейнера | `/var/lib/postgresql/data` |

**Вариант 1 – без сохранения данных (всё удалится после остановки контейнера):**
```bash
docker run -d --name pg-minimal -e POSTGRES_PASSWORD=mysecretpassword -p 5432:5432 postgres:16
```

**Вариант 2 – с сохранением данных в локальную папку (данные сохранятся после переподнятия):**

*Для Windows (PowerShell):*
```powershell
docker run -d `
  --name pg-minimal `
  -e POSTGRES_PASSWORD=mysecretpassword `
  -v "${<ваш_путь_на_машине>}/pgdata:/var/lib/postgresql/data" `
  -p 5432:5432 `
  postgres:16
```

*Для Windows (Git Bash):*
```bash
MSYS_NO_PATHCONV=1 docker run -d \
  --name pg-minimal \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -v "$(pwd)/pgdata:/var/lib/postgresql/data" \
  -p 5432:5432 \
  postgres:16
```

*Для Linux / macOS:*
```bash
docker run -d \
  --name pg-minimal \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -v "$(pwd)/pgdata:/var/lib/postgresql/data" \
  -p 5432:5432 \
  postgres:16
```

Подключение к такой БД выполняется с параметрами:
- **Хост:** `localhost`
- **Порт:** `5432`
- **База данных:** `postgres`
- **Пользователь:** `postgres`
- **Пароль:** тот, который вы задали (в примере `mysecretpassword`)

Проверить подключение можно через `psql`:
```bash

docker exec -it pg-minimal psql -U postgres 
```

---

### 4. Как войти в консоль PostgreSQL

```bash
docker exec -it pg-homework psql -U student -d project_db
# Если хотите просто войди в bash консоль внутри контейнера 
docker exec -it pg-homework  homework bash
```

После этого вы окажетесь в интерактивной оболочке `psql`.

---

### 5. Как посмотреть текущего пользователя

Внутри `psql`:

```sql
SELECT current_user;
```

Или с помощью мета-команды:

```
\conninfo
```

Список всех пользователей:

```
\du
```

---

### 6. Как примонтировать файл миграции (SQL) при старте контейнера

Любые файлы `.sql`, помещённые в каталог `/docker-entrypoint-initdb.d/` внутри контейнера, выполняются **только один раз** — при инициализации новой базы (когда каталог данных пуст). Это удобно для автоматического создания таблиц и наполнения тестовыми данными.

**Способ 1 – примонтировать отдельный SQL-файл:**

```bash
docker run -d \
  --name pg-homework \
  -e POSTGRES_USER=student \
  -e POSTGRES_PASSWORD=<your_password> \
  -e POSTGRES_DB=project_db \
  -v "$(pwd)/pgdata:/var/lib/postgresql/data" \
  -v "$(pwd)/init.sql:/docker-entrypoint-initdb.d/init.sql" \
  -p 5432:5432 \
  postgres:16
```

Файл `init.sql` должен лежать в текущей папке и содержать команды `CREATE TABLE ...`, `INSERT ...` и т.п.

**Способ 2 – примонтировать целую папку с SQL-скриптами:**

```bash
-v "$(pwd)/migrations:/docker-entrypoint-initdb.d"
```

Тогда все `.sql` файлы из папки `migrations` выполнятся в алфавитном порядке.

> **Важно:** Не подкладывайте скрипты в уже работающую БД – они не выполнятся повторно. Если нужно применить новые миграции, используйте `psql -f`.

---

### 7. Конкретный пример с готовым SQL-файлом

Допустим, у вас есть файл `init_homework.sql`

**Содержимое файла `init_homework.sql`:**

```sql
-- Таблица проектов
CREATE TABLE projects (
    project_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    start_date DATE NOT NULL,
    deadline DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'active'
        CHECK (status IN ('active', 'completed', 'on_hold')),
    created_at TIMESTAMP DEFAULT NOW(),
    CHECK (deadline >= start_date)
);

-- Таблица сотрудников
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    hire_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CHECK (hire_date <= CURRENT_DATE)
);

-- Таблица задач
CREATE TABLE tasks (
    task_id SERIAL PRIMARY KEY,
    project_id INTEGER NOT NULL,
    assignee_id INTEGER,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'new'
        CHECK (status IN ('new', 'in_progress', 'done')),
    priority VARCHAR(10) DEFAULT 'medium'
        CHECK (priority IN ('high', 'medium', 'low')),
    estimated_hours DECIMAL(5,2),
    created_date DATE DEFAULT CURRENT_DATE,
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE,
    FOREIGN KEY (assignee_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    CHECK (estimated_hours > 0)
);

-- Индексы для частых запросов
CREATE INDEX idx_tasks_project_id ON tasks(project_id);
CREATE INDEX idx_tasks_assignee_id ON tasks(assignee_id);
CREATE INDEX idx_tasks_status ON tasks(status);
```

**Запуск контейнера с автоматическим применением этого файла:**

**Вариант для Linux / macOS:**
```bash
docker run -d \
  --name pg-homework \
  -e POSTGRES_USER=student \
  -e POSTGRES_PASSWORD=strongpass \
  -e POSTGRES_DB=project_db \
  -v "$(pwd)/pgdata:/var/lib/postgresql/data" \
  -v "$(pwd)/init_homework.sql:/docker-entrypoint-initdb.d/01_init.sql" \
  -p 5432:5432 \
  postgres:16
```

**Вариант для Windows (Git Bash / MINGW64):**
В Git Bash переменная `$(pwd)` возвращает Unix-путь (например, `/c/Users/...`), который Docker Desktop часто не может прочитать, особенно если в пути есть кириллица. Чтобы это исправить, нужно отключить конвертацию путей через `MSYS_NO_PATHCONV=1` и указать прямой Windows-путь:
```bash
MSYS_NO_PATHCONV=1 docker run -d \
  --name pg-homework \
  -e POSTGRES_USER=student \
  -e POSTGRES_PASSWORD=strongpass \
  -e POSTGRES_DB=project_db \
  -v "C:/.../pgdata:/var/lib/postgresql/data" \
  -v "C:/.../init_homework.sql:/docker-entrypoint-initdb.d/01_init.sql" \
  -p 5432:5432 \
  postgres:16
```
*(Замените `C:/...` на ваш реальный путь)*

**Возможные ошибки при инициализации и где их искать:**
*   **Скрипт не выполнился, таблиц нет:** Скрипты инициализации запускаются только при пустой папке данных. Если контейнер запускался ранее, удалите папку `pgdata` на компьютере (или старый volume) и запустите контейнер заново.
*   **Docker монтирует директорию вместо файла:** В Windows (Git Bash) команда `$(pwd)` превращается в путь, который Docker не понимает, и создает внутри контейнера пустую папку `init.sql`. Решение: использовать `MSYS_NO_PATHCONV=1` и прямые Windows-пути.
*   **Опечатка или ошибка в SQL-синтаксисе:** База может инициализироваться, а скрипт упадет с ошибкой. Смотреть логи: `docker logs pg-homework` (ищите строки `ERROR: ...`).
*   **Контейнер сразу останавливается:** Проверьте логи `docker logs pg-homework`. Часто причина — нехватка прав на запись в примонтированную папку `pgdata` (особенно в Linux) или занятый порт 5432.

**Проверка, что всё применилось:**

```bash
docker exec -it pg-homework psql -U student -d project_db -c "\dt"
```

Ожидаемый вывод:

```
          List of relations
 Schema |   Name    | Type  |  Owner
--------+-----------+-------+---------
 public | employees | table | student
 public | projects  | table | student
 public | tasks     | table | student
```

Теперь можно подключаться к БД и выполнять задания семинара.

---

### 8. Полный сценарий для старта с нуля

**Для Linux / macOS:**
```bash
# 1. Создайте файл init_homework.sql с вашим DDL (см. выше)

# 2. Остановите и удалите старый контейнер (если был)
docker rm -f pg-homework

# 3. Удалите старую папку данных, чтобы применить миграции заново
rm -rf pgdata

# 4. Запустите новый контейнер с подмонтированным init_homework.sql
docker run -d \
  --name pg-homework \
  -e POSTGRES_USER=student \
  -e POSTGRES_PASSWORD=strongpass \
  -e POSTGRES_DB=project_db \
  -v "$(pwd)/pgdata:/var/lib/postgresql/data" \
  -v "$(pwd)/init_homework.sql:/docker-entrypoint-initdb.d/01_init.sql" \
  -p 5432:5432 \
  postgres:16

# 5. Подключитесь и проверьте, что таблицы созданы
docker exec -it pg-homework psql -U student -d project_db -c "\dt"
```

**Для Windows (PowerShell):** замените `$(pwd)` на `${PWD}`. Пример:

```powershell
docker run -d `
  --name pg-homework `
  -e POSTGRES_USER=student `
  -e POSTGRES_PASSWORD=strongpass `
  -e POSTGRES_DB=project_db `
  -v "${PWD}/pgdata:/var/lib/postgresql/data" `
  -v "${PWD}/init_homework.sql:/docker-entrypoint-initdb.d/01_init.sql" `
  -p 5432:5432 `
  postgres:16
```

---

### 9. Подключение DBeaver к контейнеру PostgreSQL

DBeaver — бесплатный графический клиент для работы с базами данных, поддерживает PostgreSQL.

#### Шаг 1. Убедитесь, что контейнер запущен

```bash
docker ps | grep pg-homework
```

Если контейнер не запущен, выполните:

```bash
docker start pg-homework
```

#### Шаг 2. Откройте DBeaver, создайте новое соединение

- Нажмите кнопку **«Новое соединение»** (New Database Connection) — значок вилки с плюсом в левом верхнем углу, или через меню `Database → New Database Connection`.
- В открывшемся окне выберите **PostgreSQL** и нажмите **Next >**.

#### Шаг 3. Настройте параметры подключения

В окне **«Connect to database»** заполните следующие поля:

| Поле | Значение | Примечание |
| :--- | :--- | :--- |
| **Host** | `localhost` | Если Docker запущен локально |
| **Port** | `5432` | Порт по умолчанию (проброшен из контейнера) |
| **Database** | `project_db` | Имя БД, заданное в `POSTGRES_DB` |
| **Username** | `student` | Имя пользователя, заданное в `POSTGRES_USER` |
| **Password** | `strongpass` | Пароль, заданный в `POSTGRES_PASSWORD` |

Остальные поля можно оставить по умолчанию.

#### Шаг 4. Проверьте подключение

- Нажмите кнопку **«Test Connection ...»** внизу окна.
- При первом подключении DBeaver предложит скачать драйвер PostgreSQL — согласитесь.
- Если всё верно, появится сообщение **«Connected»**.
- Нажмите **«Finish»**.

#### Шаг 5. Работа с базой

- В левой панели **«Database Navigator»** появится новое соединение `project_db`.
- Разверните `project_db → Schemas → public → Tables`, чтобы увидеть таблицы `projects`, `employees`, `tasks`.
- Можно открыть SQL-редактор (кнопка SQL в верхней панели), писать запросы и выполнять их (Ctrl+Enter).

---

### 10. Создание дампа БД (экспорт в SQL-файл)

Дамп (бэкап) нужен для сохранения структуры таблиц и данных, чтобы перенести базу на другой сервер или сохранить прогресс. Сделать это можно двумя способами: через графический интерфейс DBeaver или напрямую командой из контейнера.

#### Способ 1. Через DBeaver (графический интерфейс)

DBeaver использует встроенную утилиту `pg_dump`, но запускает её через удобный мастер.

1. **Выберите объект для бэкапа:**
   - В левой панели (Database Navigator) нажмите правой кнопкой мыши на базу данных `project_db` (для дампа всей БД) или на конкретную таблицу (например, `tasks`).
2. **Откройте мастер экспорта:**
   - В контекстном меню выберите **Tools → Backup...** (Инструменты → Резервная копия).
3. **Настройте вывод:**
   - В открывшемся окне на вкладке **Main**:
     - **Output:** выберите путь на вашем компьютере, куда сохранить файл (например, `C:\Users\User\Documents\backup.sql`).
     - **Format:** выберите `Plain` (это создаст читаемый текстовый `.sql` файл).
     - **Compression:** `None`.
4. **Выберите данные или только структуру:**
   - Перейдите на вкладку **Objects** (Объекты), убедитесь, что галочки стоят на нужных таблицах.
   - На вкладке **Options** можно выбрать:
     - `--schema-only` (сохранить только структуру таблиц без данных).
     - `--data-only` (сохранить только данные, при условии, что таблицы уже созданы).
     - Если ничего не трогать, сохранится и структура, и данные.
5. **Запустите:**
   - Нажмите **Start**. Внизу в консоли появится лог выполнения утилиты `pg_dump`, и по завершении файл окажется на вашем компьютере.

#### Способ 2. Через контейнер (командная строка)

Этот способ надежнее, так как не зависит от настроек DBeaver и операционной системы. Утилита `pg_dump` запускается прямо внутри контейнера.

**Шаг 1. Создаем дамп внутри контейнера**

Команда запускает `pg_dump` от имени пользователя `student` для базы `project_db` и сохраняет результат в файл `/tmp/dump.sql` внутри контейнера.

```bash
# Дамп всей базы данных
docker exec -t pg-homework pg_dump -U student -d project_db -f /tmp/dump.sql

# Если нужен дамп только одной таблицы (например, tasks):
docker exec -t pg-homework pg_dump -U student -d project_db -t tasks -f /tmp/tasks_dump.sql
```

**Шаг 2. Копируем файл из контейнера на локальный компьютер**

Файл создан, но он находится внутри изолированной файловой системы контейнера. Чтобы вытащить его, используем команду `docker cp`.

Для **Linux / macOS / Windows (Git Bash)**:
```bash
# Копируем в текущую папку на вашем компьютере
docker cp pg-homework:/tmp/dump.sql ./dump.sql
```

Для **Windows (CMD)**:
```cmd
docker cp pg-homework:/tmp/dump.sql dump.sql
```

Для **Windows (PowerShell)**:
В PowerShell безопаснее явно указать текущую папку через `.\`, чтобы избежать любых неоднозначностей:
```powershell
docker cp pg-homework:/tmp/dump.sql .\dump.sql
```

> **Альтернативный способ (перенаправление потока):**
> Можно сразу перенаправить поток вывода из контейнера в файл на вашем компьютере, минуя шаг копирования.
> 
> **В Linux, macOS и Git Bash** работает идеально: 
> ```bash
> docker exec -t pg-homework pg_dump -U student -d project_db > dump.sql
> ```
> 
> **В PowerShell так делать НЕЛЬЗЯ.** Оператор `>` сохраняет файлы в кодировке UTF-16LE, а PostgreSQL ждет UTF-8 (файл станет нечитаемым). Если нужно сделать это одной командой в PowerShell, используйте командлет `Out-File`:
> ```powershell
> docker exec -t pg-homework pg_dump -U student -d project_db | Out-File -Encoding utf8 dump.sql
> ```

#### Как восстановить базу из дампа (если понадобится)

Если вам нужно развернуть этот дамп в новом контейнере, просто скопируйте файл `dump.sql` в папку инициализации (как мы делали с `init_homework.sql` в шаге 7), либо выполните команду:
```bash
docker exec -i pg-homework psql -U student -d project_db < dump.sql
```
*(Предварительно таблицы в базе лучше удалить, если они уже существуют, иначе скрипт может выдать ошибки из-за дублирования).*

---

Теперь гайд полностью дополнен: вы узнаете, как установить Docker на Windows, как запустить PostgreSQL с минимальными настройками (с указанием всех значений по умолчанию), а все прежние разделы сохранены и перенумерованы.