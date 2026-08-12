"""Django REST API for managing books backed by PostgreSQL."""
from decimal import Decimal, InvalidOperation
import json

from django.db import connection
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

BOOK_COLUMNS = ("id", "title", "author", "year", "price")


def _json_response(data, status=200):
    return JsonResponse(data, status=status, safe=False, json_dumps_params={"ensure_ascii": False})


def _book_from_row(row):
    book = dict(zip(BOOK_COLUMNS, row))
    book["price"] = float(book["price"])
    return book


def _parse_body(request):
    try:
        return json.loads(request.body or b"{}")
    except json.JSONDecodeError as exc:
        raise ValueError("Invalid JSON body") from exc


def _clean_payload(data, current=None):
    title = data.get("title", current["title"] if current else "")
    author = data.get("author", current["author"] if current else "")
    year = data.get("year", current["year"] if current else 2000)
    price = data.get("price", current["price"] if current else 0)

    try:
        year = int(year)
    except (TypeError, ValueError) as exc:
        raise ValueError("year must be a number") from exc

    try:
        price = Decimal(str(price))
    except (InvalidOperation, TypeError, ValueError) as exc:
        raise ValueError("price must be a number") from exc

    return {
        "title": str(title).strip(),
        "author": str(author).strip(),
        "year": year,
        "price": price,
    }


def _fetch_book(pk):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT id, title, author, year, price FROM books WHERE id = %s",
            [pk],
        )
        row = cursor.fetchone()

    return _book_from_row(row) if row else None


@csrf_exempt
@require_http_methods(["GET", "POST"])
def book_list(request):
    if request.method == "GET":
        with connection.cursor() as cursor:
            cursor.execute("SELECT id, title, author, year, price FROM books ORDER BY id")
            books = [_book_from_row(row) for row in cursor.fetchall()]

        return _json_response(books)

    if request.method == "POST":
        try:
            payload = _clean_payload(_parse_body(request))
        except ValueError as exc:
            return _json_response({"error": str(exc)}, status=400)

        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO books (title, author, year, price)
                VALUES (%s, %s, %s, %s)
                RETURNING id, title, author, year, price
                """,
                [payload["title"], payload["author"], payload["year"], payload["price"]],
            )
            book = _book_from_row(cursor.fetchone())

        return _json_response(book, status=201)


@csrf_exempt
@require_http_methods(["GET", "PUT", "DELETE"])
def book_detail(request, pk):
    book = _fetch_book(pk)
    if not book:
        return _json_response({"error": "Book not found"}, status=404)

    if request.method == "GET":
        return _json_response(book)

    if request.method == "PUT":
        try:
            payload = _clean_payload(_parse_body(request), current=book)
        except ValueError as exc:
            return _json_response({"error": str(exc)}, status=400)

        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE books
                SET title = %s, author = %s, year = %s, price = %s
                WHERE id = %s
                RETURNING id, title, author, year, price
                """,
                [
                    payload["title"],
                    payload["author"],
                    payload["year"],
                    payload["price"],
                    pk,
                ],
            )
            updated_book = _book_from_row(cursor.fetchone())

        return _json_response(updated_book)

    if request.method == "DELETE":
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM books WHERE id = %s", [pk])

        return _json_response({"message": "Deleted"}, status=200)
