# Учебный репозиторий студента

Замените эту шапку до первой защиты.

- Студент: Фамилия Имя
- Группа: 
- Профиль: `prb` или `sii`
- Тема: код темы из паспорта, например seller
- Дисциплина: Б1.В.11 API-технологии, 09.03.03

Это заготовка, а не сданная работа. `/health` отвечает. Учебная команда на верном теле возвращает `not_implemented`: свои маршруты студент ставит по паспорту темы.

## Запуск

```text
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
set PYTHONPATH=.
uvicorn src.app.main:app --reload
```

На Linux и macOS вместо `set PYTHONPATH=.` используют `export PYTHONPATH=.`, а окружение активируют через `source .venv/bin/activate`.

Проверка:

```text
pytest
curl http://127.0.0.1:8000/health
```

Swagger: <http://127.0.0.1:8000/docs>

Мок-сервер по своему OpenAPI, нужен в ПР № 3, пока настоящего сервиса нет (требуется Node.js):

```text
npx @stoplight/prism-cli@5 mock openapi/openapi.yaml
```

Мок слушает порт 4010. В `postman/collection.json` адрес вынесен в переменную `baseUrl`: в ПР № 3 это `http://127.0.0.1:4010`, с ПР № 5 — `http://127.0.0.1:8000`.

Контейнер, когда дойдёте до ПР № 10:

```text
docker compose up --build
```

## Что уже есть

| Маршрут | Сейчас |
|---|---|
| GET `/health` | 200 |
| POST `/api/v1/commands` | 422 на плохом теле, 501 на хорошем |
| GET `/api/v1/commands/{id}` | 404 |

Образец выдуманной таблицы лежит в `data/sales_sample.csv`; свой файл для ПР № 7 кладут рядом. Ключей в репозитории нет.

## Куда складывать работы

Каталог `work/` повторяет плейбуки курса. В каждом файле замените статус и допишите решение. Условия плейбуков не копируют сюда.

| Работа | Каталог | Статус |
|---|---|---|
| ПР № 1 | [work/pb-01](work/pb-01/README.md) | не начато |
| ПР № 2 | [work/pb-02](work/pb-02/README.md) | не начато |
| ПР № 3 | [work/pb-03](work/pb-03/README.md) | не начато |
| ПР № 4 | [work/pb-04](work/pb-04/README.md) | не начато |
| ПР № 5 | [work/pb-05](work/pb-05/README.md) | не начато |
| ПР № 6 | [work/pb-06](work/pb-06/README.md) | не начато |
| ПР № 7 | [work/pb-07](work/pb-07/README.md) | не начато |
| ПР № 8 | [work/pb-08](work/pb-08/README.md) | не начато |
| ПР № 9 | [work/pb-09](work/pb-09/README.md) | не начато |
| ПР № 10 | [work/pb-10](work/pb-10/README.md) | не начато |
| ПР № 11 | [work/pb-11](work/pb-11/README.md) | не начато |
| ПР № 12 | [work/pb-12](work/pb-12/README.md) | не начато |
| Кейс № 1 | [work/case-01](work/case-01/README.md) | не начато |
| Кейс № 2 | [work/case-02](work/case-02/README.md) | не начато |
| Кейс № 3 | [work/case-03](work/case-03/README.md) | не начато |
| Кейс № 4 | [work/case-04](work/case-04/README.md) | не начато |
| Контрольная № 1 | [work/kr-01](work/kr-01/README.md) | не начато |
| Контрольная № 2 | [work/kr-02](work/kr-02/README.md) | не начато |
| Контрольная № 3 | [work/kr-03](work/kr-03/README.md) | не начато |

Статусы: `не начато`, `в работе`, `готово к защите`, `защищено`.
