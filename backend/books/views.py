"""
Django REST API for managing books.
Mock data is loaded on startup so no database setup is needed.
"""
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
import json
import re

# ── In-memory mock data ─────────────────────────────────────────────
_next_id = 11
_books = [
    {"id": 1,  "title": "The Great Gatsby",          "author": "F. Scott Fitzgerald", "year": 1925, "price": 12.99},
    {"id": 2,  "title": "1984",                      "author": "George Orwell",       "year": 1949, "price": 10.49},
    {"id": 3,  "title": "To Kill a Mockingbird",     "author": "Harper Lee",          "year": 1960, "price": 14.99},
    {"id": 4,  "title": "Pride and Prejudice",       "author": "Jane Austen",         "year": 1813, "price": 9.99},
    {"id": 5,  "title": "The Catcher in the Rye",    "author": "J.D. Salinger",       "year": 1951, "price": 11.49},
    {"id": 6,  "title": "Moby-Dick",                 "author": "Herman Melville",     "year": 1851, "price": 13.99},
    {"id": 7,  "title": "War and Peace",             "author": "Leo Tolstoy",         "year": 1869, "price": 16.99},
    {"id": 8,  "title": "The Odyssey",               "author": "Homer",               "year": 1800, "price": 8.99},
    {"id": 9,  "title": "Crime and Punishment",      "author": "Fyodor Dostoevsky",   "year": 1866, "price": 12.49},
    {"id": 10, "title": "Brave New World",           "author": "Aldous Huxley",       "year": 1932, "price": 11.99},
]


def _json_response(data, status=200):
    return JsonResponse(data, status=status, safe=False, json_dumps_params={"ensure_ascii": False})


# ── GET /api/books/  ── list all ────────────────────────────────────
@csrf_exempt
def book_list(request):
    if request.method == "GET":
        return _json_response(_books)

    if request.method == "POST":
        global _next_id
        body = json.loads(request.body)
        book = {
            "id": _next_id,
            "title":  body.get("title", ""),
            "author": body.get("author", ""),
            "year":   body.get("year", 2000),
            "price":  body.get("price", 0.0),
        }
        _next_id += 1
        _books.append(book)
        return _json_response(book, status=201)


# ── GET / PUT / DELETE  /api/books/<id>/ ────────────────────────────
@csrf_exempt
def book_detail(request, pk):
    book = next((b for b in _books if b["id"] == int(pk)), None)
    if not book:
        return _json_response({"error": "Book not found"}, status=404)

    if request.method == "GET":
        return _json_response(book)

    if request.method == "PUT":
        body = json.loads(request.body)
        book["title"]  = body.get("title", book["title"])
        book["author"] = body.get("author", book["author"])
        book["year"]   = body.get("year", book["year"])
        book["price"]  = body.get("price", book["price"])
        return _json_response(book)

    if request.method == "DELETE":
        _books[:] = [b for b in _books if b["id"] != int(pk)]
        return _json_response({"message": "Deleted"}, status=200)
