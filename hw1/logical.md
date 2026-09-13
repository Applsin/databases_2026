# Логическая модель

## User
| Поле | Тип | Ограничение |
|---|---|---|
| user_id | SERIAL | PK |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| full_name | VARCHAR(150) | NOT NULL |
| role | VARCHAR(20) | CHECK (student/teacher/admin) |
| created_at | TIMESTAMP | DEFAULT NOW() |

## Course
| Поле | Тип | Ограничение |
|---|---|---|
| course_id | SERIAL | PK |
| teacher_id | INTEGER | FK → User.user_id |
| title | VARCHAR(200) | NOT NULL |
| description | TEXT | |
| price | DECIMAL(10,2) | CHECK (price >= 0) |
| is_published | BOOLEAN | DEFAULT FALSE |
| created_at | TIMESTAMP | DEFAULT NOW() |

## Lesson
| Поле | Тип | Ограничение |
|---|---|---|
| lesson_id | SERIAL | PK |
| course_id | INTEGER | FK → Course.course_id |
| title | VARCHAR(200) | NOT NULL |
| content | TEXT | |
| position | INTEGER | CHECK (position > 0) |
| duration_minutes | INTEGER | CHECK > 0 |

## Enrollment
| Поле | Тип | Ограничение |
|---|---|---|
| enrollment_id | SERIAL | PK |
| student_id | INTEGER | FK → User.user_id |
| course_id | INTEGER | FK → Course.course_id |
| enrolled_at | TIMESTAMP | DEFAULT NOW() |
| completed_at | TIMESTAMP | |
| progress_percent | INTEGER | CHECK (0–100) |
| attempt | INTEGER | CHECK (attempt > 0) |

## Review
| Поле | Тип | Ограничение |
|---|---|---|
| review_id | SERIAL | PK |
| student_id | INTEGER | FK → User.user_id |
| course_id | INTEGER | FK → Course.course_id |
| rating | INTEGER | CHECK (1–5) |
| comment | TEXT | |
| is_moderated | BOOLEAN | DEFAULT FALSE |
| created_at | TIMESTAMP | DEFAULT NOW() |