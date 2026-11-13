# 1. Собрать образ
docker build -t seminar8-jupyter .

# 2. Запустить (Jupyter на localhost:8888, пароль student; PG на localhost:5432, без пароля)
docker run -d --name seminar8 \
    -p 8888:8888 \
    -v "$(pwd)/work:/home/student/work" \
    seminar8-jupyter

# 3. Открыть http://localhost:8888  (пароль: student)

# 4. Логи
docker logs -f seminar8


# Проверка доступности БД с указанными кредами
docker exec -it seminar8 bash -lc "psql 'host=localhost port=5432 dbname=demo user=postgres' -c '\dt'"