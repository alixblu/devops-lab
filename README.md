# Book Manager

Simple CRUD app — **Django** backend + **React** frontend.

## Quick Start

```bash
# Backend
cd backend
uv run python manage.py runserver    # http://localhost:8000

# Frontend (new terminal)
cd frontend
npm install
npm run dev                          # http://localhost:5173
```

## API

| Method | Endpoint         | Action      |
|--------|------------------|-------------|
| GET    | `/api/books/`    | List all    |
| POST   | `/api/books/`    | Create      |
| GET    | `/api/books/<id>/` | Read      |
| PUT    | `/api/books/<id>/` | Update    |
| DELETE | `/api/books/<id>/` | Delete    |
